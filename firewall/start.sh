#!/bin/bash

# Start firewall rules in background
echo "Starting firewall initialization..."
/app/firewall.sh &

# Wait a moment for firewall to initialize
sleep 2

# Start the dashboard first (provides in-memory storage API)
echo "Starting dashboard..."
python /app/dashboard.py &

# Wait for dashboard to be ready
sleep 3

# Start the proxy server (sends logs to dashboard API)
echo "Starting proxy server..."
python /app/proxy.py &

# Start iptables log monitor (captures blocked connections)
echo "Starting iptables monitor..."
/app/iptables_monitor.sh &

# Start DDoS monitoring (reads from dashboard API)
echo "Starting DDoS monitor..."
/app/ddos_monitor.sh

