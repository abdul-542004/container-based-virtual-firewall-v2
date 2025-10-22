#!/bin/bash

# DDoS Detection and MAC Blocking Script
# Monitors request logs via API and automatically blocks MAC addresses of attackers

echo "=================================================="
echo "DDoS Detection and MAC Blocking Service"
echo "=================================================="

DASHBOARD_URL="http://localhost:8080"
CHECK_INTERVAL=2   # Check every 2 seconds for faster response
THRESHOLD=20       # Requests per minute threshold

echo "Configuration:"
echo "  • Dashboard API: $DASHBOARD_URL"
echo "  • Threshold: $THRESHOLD requests/minute"
echo "  • Check Interval: ${CHECK_INTERVAL}s"
echo "=================================================="
echo ""

# Wait for dashboard to be ready
echo "Waiting for dashboard to start..."
for i in {1..30}; do
    if curl -s "$DASHBOARD_URL/api/stats" >/dev/null 2>&1; then
        echo "✓ Dashboard is ready"
        break
    fi
    sleep 1
done

# Function to get MAC address from IP
get_mac_from_ip() {
    local ip=$1
    # Use ARP to find MAC address
    mac=$(arp -n "$ip" 2>/dev/null | grep "$ip" | awk '{print $3}')
    if [ -z "$mac" ] || [ "$mac" = "<incomplete>" ]; then
        # Try to ping once to populate ARP table
        ping -c 1 -W 1 "$ip" >/dev/null 2>&1
        sleep 0.5
        mac=$(arp -n "$ip" 2>/dev/null | grep "$ip" | awk '{print $3}')
    fi
    echo "$mac"
}

# Function to check if MAC is already blocked
is_mac_blocked() {
    local mac=$1
    # Query dashboard API
    blocked_macs=$(curl -s "$DASHBOARD_URL/api/blocked_macs" | grep -o '"'"$mac"'"' 2>/dev/null)
    [ -n "$blocked_macs" ]
}

# Function to block MAC address
block_mac() {
    local ip=$1
    local mac=$2
    local count=$3
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DDoS DETECTED from $ip (MAC: $mac) - $count requests/min"
    
    # Check if already blocked
    if is_mac_blocked "$mac"; then
        echo "  → MAC already blocked: $mac"
        return
    fi
    
    # Add to blocked MACs via API
    curl -s -X POST "$DASHBOARD_URL/api/block_mac" \
        -H "Content-Type: application/json" \
        -d "{\"mac\":\"$mac\"}" >/dev/null 2>&1
    echo "  → Added to blocked MACs: $mac"
    
    # Apply iptables rule immediately
    iptables -I BLOCKED_MACS 1 -m mac --mac-source "$mac" -j LOG --log-prefix "FW-BLOCK-MAC: " --log-level 4
    iptables -I BLOCKED_MACS 2 -m mac --mac-source "$mac" -j DROP
    echo "  → iptables rule applied"
    
    # Log to system
    logger -t ddos-blocker "Blocked MAC $mac (IP: $ip) for DDoS attack ($count req/min)"
}

# Main monitoring loop
echo "Starting DDoS monitoring..."
echo ""

while true; do
    # Get recent logs from last minute (not stats)
    logs=$(curl -s "$DASHBOARD_URL/api/logs?minutes=1" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$logs" ]; then
        # Count requests per IP from the logs
        ip_counts=$(echo "$logs" | grep -o '"client_ip":"[^"]*"' | cut -d'"' -f4 | sort | uniq -c | sort -rn)
        
        # Check each IP
        while read -r count ip; do
            # Skip if empty or invalid
            [ -z "$ip" ] || [ -z "$count" ] && continue
            
            # Only check internal network IPs (potential internal attackers)
            if [[ "$ip" =~ ^172\.20\. ]] && [ "$count" -gt "$THRESHOLD" ]; then
                # Get MAC address
                mac=$(get_mac_from_ip "$ip")
                
                if [ -n "$mac" ] && [ "$mac" != "<incomplete>" ]; then
                    block_mac "$ip" "$mac" "$count"
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cannot get MAC for $ip (${count} req/min)"
                fi
            fi
        done <<< "$ip_counts"
    fi
    
    # Wait before next check
    sleep "$CHECK_INTERVAL"
done
