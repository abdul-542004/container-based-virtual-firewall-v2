#!/bin/bash

echo "=================================================="
echo "Initializing Firewall Rules"
echo "=================================================="

# Define network configuration FIRST
INTERNAL_NETWORK="172.20.0.0/16"
SERVER_NETWORK="${SERVER_NETWORK:-172.30.0.0/16}"
EXTERNAL_NETWORK="${EXTERNAL_NETWORK:-172.21.0.0/16}"
SERVER_IP="${SERVER_IP:-172.30.0.3}"
ADMIN_CLIENT_IP="${ADMIN_CLIENT_IP:-172.20.0.5}"
FIREWALL_IP="172.20.0.2"

echo "Network Configuration:"
echo "  Internal Network: $INTERNAL_NETWORK"
echo "  Server Network:   $SERVER_NETWORK"
echo "  External Network: $EXTERNAL_NETWORK"
echo "  Server IP: $SERVER_IP"
echo "  Firewall IP: $FIREWALL_IP"
echo "  Admin Client IP: $ADMIN_CLIENT_IP"
echo ""

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "✓ IP forwarding enabled"

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
echo "✓ Existing rules flushed"

# Set default policies
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
echo "✓ Default policies set"

# Block external network from INPUT chain FIRST (before any other rules)
iptables -A INPUT -s $EXTERNAL_NETWORK -p tcp -m multiport --dports 8080,5000 -j LOG --log-prefix "FW-BLOCK-EXT-INPUT: " --log-level 4
iptables -A INPUT -s $EXTERNAL_NETWORK -p tcp -m multiport --dports 8080,5000 -j REJECT --reject-with tcp-reset
echo "✓ External network INPUT blocking configured"

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
echo "✓ Loopback traffic allowed"

# Allow established and related connections (but external network blocks should prevent NEW connections)
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
echo "✓ Established connections allowed"

# ============================================
# 1. IP FILTERING - Allow internal network only
# ============================================
echo ""
echo "Configuring IP Filtering..."

# Allow all traffic within internal network
iptables -A FORWARD -s $INTERNAL_NETWORK -d $INTERNAL_NETWORK -j ACCEPT
echo "✓ Internal network traffic allowed ($INTERNAL_NETWORK)"

# Block all traffic from external network in FORWARD chain
iptables -A FORWARD -s $EXTERNAL_NETWORK -j LOG --log-prefix "FW-BLOCK-EXTERNAL: " --log-level 4
iptables -A FORWARD -s $EXTERNAL_NETWORK -j DROP
echo "✓ External network FORWARD traffic blocked"

# Allow dashboard and proxy ports from internal network and host
iptables -A INPUT -s $INTERNAL_NETWORK -p tcp -m multiport --dports 8080,5000 -j ACCEPT
iptables -A INPUT -s $SERVER_NETWORK -p tcp -m multiport --dports 8080,5000 -j ACCEPT
# Allow from Docker host networks
iptables -A INPUT -p tcp -m multiport --dports 8080,5000 -m conntrack --ctstate NEW -s 172.17.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 8080,5000 -m conntrack --ctstate NEW -s 172.18.0.0/16 -j ACCEPT
echo "✓ Dashboard (8080) and proxy (5000) accessible from allowed networks"

# ============================================
# 2. PORT FILTERING - SSH only from admin client
# ============================================
echo ""
echo "Configuring Port Filtering..."

# Allow SSH only from admin client to server
iptables -A FORWARD -p tcp -s $ADMIN_CLIENT_IP -d $SERVER_IP --dport 22 -j ACCEPT
echo "✓ SSH allowed from admin client ($ADMIN_CLIENT_IP) to server"

# Block SSH from all other clients
iptables -A FORWARD -p tcp ! -s $ADMIN_CLIENT_IP -d $SERVER_IP --dport 22 -j LOG --log-prefix "FW-BLOCK-SSH: " --log-level 4
iptables -A FORWARD -p tcp ! -s $ADMIN_CLIENT_IP -d $SERVER_IP --dport 22 -j REJECT --reject-with tcp-reset
echo "✓ SSH blocked for non-admin clients"

# Allow HTTP/HTTPS traffic
iptables -A FORWARD -p tcp -s $INTERNAL_NETWORK -m multiport --dports 80,443,5000 -j ACCEPT
echo "✓ HTTP/HTTPS traffic allowed within internal network"

# ============================================
# 3. DDoS PROTECTION
# ============================================
echo ""
echo "Configuring DDoS Protection..."

# Rate limiting: Max 20 new connections per minute per IP
iptables -A FORWARD -p tcp --syn -m recent --name conn_rate --set
iptables -A FORWARD -p tcp --syn -m recent --name conn_rate --update --seconds 60 --hitcount 21 -j LOG --log-prefix "FW-DDOS-RATE: " --log-level 4
iptables -A FORWARD -p tcp --syn -m recent --name conn_rate --update --seconds 60 --hitcount 21 -j DROP
echo "✓ Connection rate limiting: 20 connections/min per IP"

# SYN flood protection
iptables -A FORWARD -p tcp --syn -m limit --limit 15/s --limit-burst 30 -j ACCEPT
iptables -A FORWARD -p tcp --syn -j LOG --log-prefix "FW-DDOS-SYN: " --log-level 4
iptables -A FORWARD -p tcp --syn -j DROP
echo "✓ SYN flood protection enabled"

# Limit concurrent connections per IP
iptables -A FORWARD -p tcp --syn -m connlimit --connlimit-above 15 --connlimit-mask 32 -j LOG --log-prefix "FW-DDOS-CONNLIMIT: " --log-level 4
iptables -A FORWARD -p tcp --syn -m connlimit --connlimit-above 15 --connlimit-mask 32 -j REJECT --reject-with tcp-reset
echo "✓ Max 15 concurrent connections per IP"

# ICMP rate limiting (ping flood protection)
iptables -A FORWARD -p icmp --icmp-type echo-request -m limit --limit 2/s --limit-burst 5 -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-request -j LOG --log-prefix "FW-DDOS-ICMP: " --log-level 4
iptables -A FORWARD -p icmp --icmp-type echo-request -j DROP
echo "✓ ICMP flood protection enabled"

# ============================================
# 4. MAC FILTERING - Will be managed dynamically
# ============================================
echo ""
echo "Configuring MAC Filtering..."

# Create a chain for blocked MACs
iptables -N BLOCKED_MACS 2>/dev/null || iptables -F BLOCKED_MACS

# MACs will be added dynamically by ddos_monitor.sh via API
# No file reading needed - all data is in-memory in dashboard

# Apply blocked MACs chain to FORWARD and INPUT (AFTER external network blocks)
iptables -A FORWARD -j BLOCKED_MACS
iptables -A INPUT -j BLOCKED_MACS
echo "✓ MAC filtering enabled (dynamic blocking active via API)"

# ============================================
# 5. NAT Configuration
# ============================================
echo ""
echo "Configuring NAT..."

# Enable NAT for internal network to access external
iptables -t nat -A POSTROUTING -s $INTERNAL_NETWORK -j MASQUERADE
echo "✓ NAT enabled for internal network"

# Forward HTTP traffic to server
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 5000 -j DNAT --to-destination $SERVER_IP:5000
echo "✓ Port forwarding: 5000 → $SERVER_IP:5000"

# Forward SSH traffic from port 22 to server (only for admin)
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 22 -j DNAT --to-destination $SERVER_IP:22
echo "✓ SSH forwarding: 22 → $SERVER_IP:22"

# Masquerade traffic sourced from server network when leaving firewall
iptables -t nat -A POSTROUTING -s $SERVER_NETWORK -j MASQUERADE
echo "✓ NAT enabled for server network"

# ============================================
# 6. Logging
# ============================================
echo ""
echo "Configuring Logging..."

# Log all dropped packets (rate limited)
iptables -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "FW-DROP: " --log-level 4
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "FW-INPUT-DROP: " --log-level 4

echo "✓ Firewall logging enabled"

# ============================================
# Summary
# ============================================
echo ""
echo "=================================================="
echo "Firewall Rules Successfully Initialized"
echo "=================================================="
echo ""
echo "Active Rules:"
echo "  ✓ IP Filtering: Internal network only"
echo "  ✓ Port Filtering: SSH restricted to admin"
echo "  ✓ DDoS Protection: Rate limiting active"
echo "  ✓ MAC Filtering: Dynamic blocking enabled via API"
echo "  ✓ NAT: Enabled for internal→external"
echo ""
echo "Monitoring:"
echo "  • Dashboard: http://localhost:8080"
echo "  • API: http://localhost:8080/api/*"
echo "  • All data stored in-memory (no files)"
echo ""
echo "=================================================="
echo "Firewall is running..."
echo "=================================================="

# Keep the script running
tail -f /dev/null
