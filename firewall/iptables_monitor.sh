#!/bin/bash

# iptables Log Monitor - Captures blocked connections and logs them to dashboard
# Monitors iptables counters to detect blocked traffic

echo "=================================================="
echo "iptables Counter Monitor Service"
echo "=================================================="

DASHBOARD_URL="http://localhost:8080"
CHECK_INTERVAL=3

echo "Configuration:"
echo "  • Dashboard API: $DASHBOARD_URL"
echo "  • Check Interval: ${CHECK_INTERVAL}s"
echo "  • Monitoring: iptables packet counters"
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

echo "Starting iptables counter monitoring..."
echo ""

# Store previous packet counts
declare -A prev_counts

# Function to log blocked attempt to dashboard
log_blocked_attempt() {
    local reason=$1
    local count=$2
    local path=$3
    
    # Default path if not provided
    if [ -z "$path" ]; then
        path="/blocked"
    fi
    
    # Create log entry
    local log_entry=$(cat <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "client_ip": "External Network",
    "method": "BLOCKED",
    "path": "$path",
    "status": 403,
    "blocked": true,
    "reason": "$reason ($count packets)"
}
EOF
)
    
    # Send to dashboard
    curl -s -X POST "$DASHBOARD_URL/api/log" \
        -H "Content-Type: application/json" \
        -d "$log_entry" >/dev/null 2>&1
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $reason - $count packets blocked - $path"
}

# Main monitoring loop
while true; do
    # Get iptables counters
    output=$(iptables -L FORWARD -v -n 2>/dev/null)
    
    # Check for external network blocks
    ext_block=$(echo "$output" | grep "FW-BLOCK-EXTERNAL" | awk '{print $1}')
    if [ -n "$ext_block" ] && [ "$ext_block" != "0" ]; then
        key="ext_block"
        if [ "${prev_counts[$key]}" != "$ext_block" ]; then
            diff=$((ext_block - ${prev_counts[$key]:-0}))
            [ $diff -gt 0 ] && log_blocked_attempt "External network blocked" "$diff" "/proxy (external IP)"
            prev_counts[$key]=$ext_block
        fi
    fi
    
    # Check for SSH blocks
    ssh_block=$(echo "$output" | grep "FW-BLOCK-SSH" | awk '{print $1}')
    if [ -n "$ssh_block" ] && [ "$ssh_block" != "0" ]; then
        key="ssh_block"
        if [ "${prev_counts[$key]}" != "$ssh_block" ]; then
            diff=$((ssh_block - ${prev_counts[$key]:-0}))
            [ $diff -gt 0 ] && log_blocked_attempt "SSH access denied (not admin)" "$diff" "/ssh:22"
            prev_counts[$key]=$ssh_block
        fi
    fi
    
    # Check for MAC blocks
    mac_output=$(iptables -L BLOCKED_MACS -v -n 2>/dev/null)
    mac_block=$(echo "$mac_output" | grep "FW-BLOCK-MAC" | awk '{print $1}')
    if [ -n "$mac_block" ] && [ "$mac_block" != "0" ]; then
        key="mac_block"
        if [ "${prev_counts[$key]}" != "$mac_block" ]; then
            diff=$((mac_block - ${prev_counts[$key]:-0}))
            [ $diff -gt 0 ] && log_blocked_attempt "MAC address blocked (DDoS)" "$diff" "/proxy (MAC blocked)"
            prev_counts[$key]=$mac_block
        fi
    fi
    
    # Check for rate limit blocks
    rate_block=$(echo "$output" | grep "FW-DDOS-RATE" | awk '{print $1}')
    if [ -n "$rate_block" ] && [ "$rate_block" != "0" ]; then
        key="rate_block"
        if [ "${prev_counts[$key]}" != "$rate_block" ]; then
            diff=$((rate_block - ${prev_counts[$key]:-0}))
            [ $diff -gt 0 ] && log_blocked_attempt "Rate limit exceeded" "$diff" "/proxy (rate limited)"
            prev_counts[$key]=$rate_block
        fi
    fi
    
    # Check for SYN flood blocks
    syn_block=$(echo "$output" | grep "FW-DDOS-SYN" | awk '{print $1}')
    if [ -n "$syn_block" ] && [ "$syn_block" != "0" ]; then
        key="syn_block"
        if [ "${prev_counts[$key]}" != "$syn_block" ]; then
            diff=$((syn_block - ${prev_counts[$key]:-0}))
            [ $diff -gt 0 ] && log_blocked_attempt "SYN flood protection" "$diff" "/proxy (SYN flood)"
            prev_counts[$key]=$syn_block
        fi
    fi
    
    # Check for connection limit blocks
    conn_block=$(echo "$output" | grep "FW-DDOS-CONNLIMIT" | awk '{print $1}')
    if [ -n "$conn_block" ] && [ "$conn_block" != "0" ]; then
        key="conn_block"
        if [ "${prev_counts[$key]}" != "$conn_block" ]; then
            diff=$((conn_block - ${prev_counts[$key]:-0}))
            [ $diff -gt 0 ] && log_blocked_attempt "Connection limit exceeded" "$diff" "/proxy (too many connections)"
            prev_counts[$key]=$conn_block
        fi
    fi
    
    # Check for ICMP flood blocks
    icmp_block=$(echo "$output" | grep "FW-DDOS-ICMP" | awk '{print $1}')
    if [ -n "$icmp_block" ] && [ "$icmp_block" != "0" ]; then
        key="icmp_block"
        if [ "${prev_counts[$key]}" != "$icmp_block" ]; then
            diff=$((icmp_block - ${prev_counts[$key]:-0}))
            [ $diff -gt 0 ] && log_blocked_attempt "ICMP flood protection" "$diff" "/ping (ICMP flood)"
            prev_counts[$key]=$icmp_block
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
