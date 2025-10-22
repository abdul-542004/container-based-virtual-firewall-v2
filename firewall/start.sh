#!/bin/bash

# Ensure logs and data directories have proper permissions
mkdir -p /app/logs /app/data
chmod 777 /app/logs /app/data

# Create empty files if they don't exist
touch /app/data/blocked_macs.txt 2>/dev/null || true
touch /app/logs/requests.jsonl 2>/dev/null || true
chmod 666 /app/data/blocked_macs.txt 2>/dev/null || true
chmod 666 /app/logs/requests.jsonl 2>/dev/null || true

# Start firewall rules in background
echo "Starting firewall initialization..."
/app/firewall.sh &

# Wait a moment for firewall to initialize
sleep 2

# Start DDoS monitoring and auto-blocking in background
echo "Starting DDoS monitor..."
/app/ddos_monitor.sh &

# Start the proxy server
echo "Starting proxy server..."
python /app/proxy.py &

# Start the dashboard
echo "Starting dashboard..."
python /app/dashboard.py
