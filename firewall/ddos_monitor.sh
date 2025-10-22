#!/bin/bash

# DDoS Detection and MAC Blocking Script
# Monitors request logs and automatically blocks MAC addresses of attackers

echo "=================================================="
echo "DDoS Detection and MAC Blocking Service"
echo "=================================================="

REQUESTS_LOG="/app/logs/requests.jsonl"
BLOCKED_MACS_FILE="/app/data/blocked_macs.txt"
CHECK_INTERVAL=10  # Check every 10 seconds
THRESHOLD=20       # Requests per minute threshold
TIME_WINDOW=60     # Time window in seconds

# Ensure files exist
mkdir -p /app/logs /app/data
touch "$REQUESTS_LOG" 2>/dev/null || true
touch "$BLOCKED_MACS_FILE" 2>/dev/null || true

echo "Configuration:"
echo "  • Threshold: $THRESHOLD requests/minute"
echo "  • Check Interval: ${CHECK_INTERVAL}s"
echo "  • Time Window: ${TIME_WINDOW}s"
echo "=================================================="
echo ""

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
    grep -q "^$mac$" "$BLOCKED_MACS_FILE" 2>/dev/null
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
    
    # Add to blocked MACs file
    echo "$mac" >> "$BLOCKED_MACS_FILE"
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
    # Get current timestamp
    current_time=$(date +%s)
    cutoff_time=$((current_time - TIME_WINDOW))
    
    # Process recent requests from log file
    if [ -f "$REQUESTS_LOG" ] && [ -s "$REQUESTS_LOG" ]; then
        # Extract IPs and their request counts in the time window
        temp_file=$(mktemp)
        
        # Parse JSON log and count requests per IP
        while IFS= read -r line; do
            # Extract timestamp and IP from JSON
            timestamp=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
            client_ip=$(echo "$line" | grep -o '"client_ip":"[^"]*"' | cut -d'"' -f4)
            
            # Convert timestamp to epoch
            if [ -n "$timestamp" ] && [ -n "$client_ip" ]; then
                req_time=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
                
                # Check if within time window
                if [ "$req_time" -ge "$cutoff_time" ]; then
                    echo "$client_ip"
                fi
            fi
        done < "$REQUESTS_LOG" | sort | uniq -c | sort -rn > "$temp_file"
        
        # Check each IP for threshold violation
        while read -r count ip; do
            # Skip if empty
            [ -z "$ip" ] && continue
            
            # Check if count exceeds threshold
            if [ "$count" -ge "$THRESHOLD" ]; then
                # Only block internal network IPs (potential internal attackers)
                if [[ "$ip" =~ ^172\.20\. ]]; then
                    # Get MAC address
                    mac=$(get_mac_from_ip "$ip")
                    
                    if [ -n "$mac" ] && [ "$mac" != "<incomplete>" ]; then
                        block_mac "$ip" "$mac" "$count"
                    else
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cannot get MAC for $ip (${count} req/min)"
                    fi
                fi
            fi
        done < "$temp_file"
        
        rm -f "$temp_file"
    fi
    
    # Wait before next check
    sleep "$CHECK_INTERVAL"
done
