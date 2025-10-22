# 🛡️ Container-Based Virtual Firewall Lab

A comprehensive Docker-based lab environment demonstrating advanced network security concepts including network-based firewall rules, automatic DDoS detection and blocking, and access control.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Demonstrations](#demonstrations)
- [Testing Scenarios](#testing-scenarios)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This project creates a virtual network environment with:
- **Server Container**: Employee Management REST API (Flask)
- **Firewall Container**: Network gateway with comprehensive iptables-based filtering
- **Client Container**: Regular internal network client
- **Admin Client Container**: Privileged client with SSH access
- **Internal Attacker Container**: DDoS simulation from within the network
- **External Attacker Container**: External threat simulation (blocked by default)

The firewall acts as the network gateway and enforces strict security policies using iptables, with automatic DDoS detection and MAC address blocking.

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                  Internal Network (172.20.0.0/16)                │
│                   Gateway: Firewall (172.20.0.2)                 │
│                                                                   │
│  ┌──────────┐    ┌─────────────┐    ┌──────────────┐           │
│  │  Client  │───▶│  Firewall   │───▶│   Server     │           │
│  │172.20.0.4│    │ 172.20.0.2  │    │ 172.20.0.3   │           │
│  └──────────┘    │             │    │              │           │
│                  │ - iptables  │    │ - REST API   │           │
│  ┌──────────┐    │ - DDoS Det. │    │ - SSH Server │           │
│  │  Admin   │───▶│ - Dashboard │    └──────────────┘           │
│  │172.20.0.5│    │ - Proxy     │                               │
│  └──────────┘    │             │                               │
│  (SSH allowed)   └─────┬───────┘                               │
│                        │                                        │
│  ┌──────────┐          │ Port Mappings:                        │
│  │Internal  │          │ • 8080 → Dashboard                    │
│  │ Attacker │──────────│ • 5000 → API Proxy                    │
│  │172.20.0.6│          │ • 2222 → SSH (admin only)             │
│  └──────────┘          │                                        │
│  (Gets blocked        │                                        │
│   when attacking)     │                                        │
│                       │                                        │
└───────────────────────┼────────────────────────────────────────┘
                        │
                        │ BLOCKED by IP filtering
                        │
┌───────────────────────▼────────────────────────────────────────┐
│              External Network (172.21.0.0/16)                  │
│                                                                 │
│                     ┌────────────┐                             │
│                     │  External  │                             │
│                     │  Attacker  │                             │
│                     │172.21.0.10 │                             │
│                     └────────────┘                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## ✨ Features

### 1. IP Address Filtering (iptables)
- ✅ Allow all traffic from internal network (172.20.0.0/16)
- ❌ Block all traffic from external networks
- Enforced at network layer using iptables

### 2. Port Filtering (iptables)
- **SSH (Port 22)**: Only admin client (172.20.0.5) can SSH to server
- **HTTP/HTTPS (80/443/5000)**: Allowed for all internal clients
- Other clients attempting SSH get TCP reset

### 3. DDoS Protection (iptables + monitoring)
- **Connection Rate Limiting**: Max 20 new connections per minute per IP
- **SYN Flood Protection**: Rate limited at 15/s with burst of 30
- **Concurrent Connection Limiting**: Max 15 concurrent connections per IP
- **ICMP Flood Protection**: Ping rate limited to 2/s
- All iptables-based for performance

### 4. MAC Address Filtering (Dynamic)
- **Automatic Blocking**: Internal attackers are automatically blocked by MAC address
- **DDoS Detection**: Monitor script detects excessive requests (>20/min)
- **Immediate Response**: MAC address is added to iptables block list
- **Persistent**: Blocked MACs stored in `/app/data/blocked_macs.txt`

### 5. Interactive Dashboard
- Real-time traffic monitoring
- DDoS attack alerts
- Blocked MAC addresses list
- Traffic statistics and analytics
- Network policy display

### 6. REST API Server
- Full CRUD operations for employee management
- No GUI (API-only for security)
- Accessible only through firewall
- SSH access for admin maintenance

## 🔧 Prerequisites

- Docker Engine (20.10+)
- Docker Compose (2.0+)
- At least 2GB free RAM
- Linux host (recommended)

## 📦 Installation

### 1. Navigate to Project Directory

```bash
cd "/home/abdullah/Study/container based virtual firewall"
```

### 2. Build and Start Containers

```bash
# Build all containers
docker-compose build

# Start the environment
docker-compose up -d

# Check container status
docker-compose ps
```

Expected output - all containers should be "Up":
```
NAME                STATUS              PORTS
firewall            Up                  0.0.0.0:5000->5000/tcp, 0.0.0.0:8080->8080/tcp, 0.0.0.0:2222->22/tcp
server              Up                  
client              Up                  
admin-client        Up                  
internal-attacker   Up                  
attacker            Up                  
```

### 3. Verify Firewall Rules

```bash
# Check firewall logs
docker logs firewall

# Should see:
# ✓ IP Filtering: Internal network only
# ✓ Port Filtering: SSH restricted to admin
# ✓ DDoS Protection: Rate limiting active
# ✓ MAC Filtering: Dynamic blocking enabled
```

## 🚀 Usage

### Access Points

1. **Firewall Dashboard**: http://localhost:8080
   - Monitor all traffic
   - View DDoS alerts
   - See blocked MAC addresses
   - Real-time statistics

2. **Server API (via Firewall)**: http://localhost:5000
   - Employee Management API
   - All requests logged

3. **SSH to Server (admin only)**: 
   ```bash
   ssh -p 2222 root@localhost
   # Password: firewall123
   ```

### Container Access

```bash
# Regular client
docker exec -it client sh

# Admin client (can SSH)
docker exec -it admin-client bash

# Internal attacker (has DDoS script)
docker exec -it internal-attacker bash

# External attacker (will be blocked)
docker exec -it attacker sh
```

## 🧪 Demonstrations

### Demo 1: IP Filtering - Block External Network

**Objective**: Demonstrate that external network is blocked by firewall

```bash
# Terminal 1: Access from external attacker (BLOCKED)
docker exec -it attacker sh
curl http://firewall:5000/api/employees
# Should timeout - external network blocked

# Terminal 2: Access from internal client (ALLOWED)
docker exec -it client sh
curl http://firewall:5000/api/employees
# Should work - internal network allowed
```

**Expected Result**:
- External attacker: Connection timeout
- Internal client: Successful API response
- Dashboard shows only internal traffic

### Demo 2: Port Filtering - SSH Access Control

**Objective**: Only admin client can SSH to server

```bash
# Terminal 1: Try SSH from regular client (BLOCKED)
docker exec -it client sh
ssh root@server
# Connection refused or reset

# Terminal 2: Try SSH from admin client (ALLOWED)
docker exec -it admin-client bash
ssh root@server
# Password: firewall123
# Should connect successfully
```

**Expected Result**:
- Regular client: SSH connection rejected
- Admin client: SSH login successful
- Firewall logs show "FW-BLOCK-SSH" for non-admin attempts

### Demo 3: DDoS Attack and Automatic MAC Blocking

**Objective**: Demonstrate automatic MAC blocking when DDoS is detected

```bash
# Terminal 1: Open Dashboard
# Browser: http://localhost:8080
# Keep this open to watch real-time

# Terminal 2: Perform DDoS attack from internal attacker
docker exec -it internal-attacker bash
ddos_attack http://firewall:5000/api/employees 10 100
# This sends 1000 requests rapidly (10 threads × 100 requests)

# Watch in Terminal 2:
# - Attack script shows progress
# - Initial requests succeed
# - Then requests start failing

# Watch in Dashboard (Terminal 1):
# - DDoS alert appears
# - Internal attacker IP shows high request count
# - MAC address appears in "Blocked MAC Addresses" section
# - Further requests are dropped

# Terminal 3: Verify internal attacker is blocked
docker exec -it internal-attacker bash
curl http://firewall:5000/api/employees
# Should timeout - MAC blocked
```

**Expected Result**:
1. First ~20 requests succeed
2. DDoS detection triggers (>20 req/min)
3. MAC address automatically blocked
4. All subsequent requests from that client are dropped
5. Dashboard shows blocked MAC
6. Other clients still work normally

### Demo 4: Normal Operations - REST API Usage

**Objective**: Show normal API operations from authorized clients

```bash
# Access from client container
docker exec -it client sh

# Get all employees
curl http://firewall:5000/api/employees

# Get specific employee
curl http://firewall:5000/api/employees/1

# Add new employee
curl -X POST http://firewall:5000/api/employees \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "position": "Security Engineer",
    "department": "IT",
    "salary": 85000,
    "email": "test@company.com"
  }'

# Update employee
curl -X PUT http://firewall:5000/api/employees/1 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe Updated",
    "salary": 80000
  }'

# Delete employee
curl -X DELETE http://firewall:5000/api/employees/5
```

**Expected Result**:
- All API operations work smoothly
- Requests logged in dashboard
- No DDoS alerts (normal traffic pattern)

### Demo 5: DDoS Protection Layers

**Objective**: Show multiple DDoS protection mechanisms

```bash
# Test 1: Connection Rate Limiting
docker exec -it internal-attacker bash
for i in {1..30}; do curl -s http://firewall:5000/ & done; wait
# Exceeds 20 conn/min limit - later connections dropped

# Test 2: Concurrent Connection Limit
# (Automatic - iptables enforces max 15 concurrent)

# Test 3: ICMP Flood Protection
docker exec -it client sh
ping -f firewall
# Rate limited to 2/s, excess dropped
```

## 📊 Monitoring

### View Firewall Logs

```bash
# Real-time firewall logs
docker logs -f firewall

# Request logs (JSON format)
docker exec firewall cat /app/logs/requests.jsonl

# Blocked MACs
docker exec firewall cat /app/data/blocked_macs.txt
```

### View iptables Rules

```bash
# All firewall rules
docker exec firewall iptables -L -n -v

# NAT rules
docker exec firewall iptables -t nat -L -n -v

# Blocked MACs chain
docker exec firewall iptables -L BLOCKED_MACS -n -v
```

### System Logs

```bash
# DDoS detection log
docker exec firewall grep "DDoS DETECTED" /var/log/syslog

# Blocked packets
docker exec firewall dmesg | grep "FW-"
```

## 🔍 Testing Scenarios

### Scenario 1: Complete Security Demonstration

**Step-by-step walkthrough for your teacher**

```bash
# 1. Show initial state - all clean
Open dashboard: http://localhost:8080
Show: No blocked MACs, minimal traffic

# 2. Demonstrate normal access (internal client)
docker exec -it client sh
curl http://firewall:5000/api/employees
# Works perfectly

# 3. Demonstrate external blocking
docker exec -it attacker sh
curl http://firewall:5000/api/employees
# Timeout - external network blocked

# 4. Demonstrate SSH restriction
docker exec -it client sh
ssh root@server
# Fails - not admin

docker exec -it admin-client bash
ssh root@server
# Works - admin client

# 5. Demonstrate DDoS attack and auto-blocking
docker exec -it internal-attacker bash
ddos_attack http://firewall:5000/api/employees 10 100

# Watch dashboard - MAC gets blocked automatically

# 6. Verify attacker is blocked
curl http://firewall:5000/api/employees
# Timeout - MAC blocked

# 7. Show other clients still work
docker exec -it client sh
curl http://firewall:5000/api/employees
# Still works fine
```

### Scenario 2: Firewall Rule Verification

```bash
# Show iptables rules
docker exec firewall iptables -L -n -v --line-numbers

# Key rules to highlight:
# - FORWARD chain: Internal network allowed
# - FORWARD chain: External network dropped
# - FORWARD chain: SSH only from admin client
# - FORWARD chain: Rate limiting rules
# - BLOCKED_MACS chain: MAC filtering
```

## 🛠️ Troubleshooting

### Containers Not Starting

```bash
# Check logs
docker-compose logs

# Rebuild from scratch
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### Firewall Rules Not Working

```bash
# Restart firewall container
docker-compose restart firewall

# Check if firewall script ran
docker exec firewall iptables -L -n | grep "172.20.0.0"

# Manually re-run firewall script
docker exec firewall /app/firewall.sh
```

### DDoS Detection Not Working

```bash
# Check if DDoS monitor is running
docker exec firewall ps aux | grep ddos_monitor

# Check logs
docker exec firewall cat /app/logs/requests.jsonl

# Manually check for attacks
docker exec firewall tail -f /var/log/syslog | grep "DDoS DETECTED"
```

### Cannot Access Dashboard

```bash
# Check if firewall container is running
docker ps | grep firewall

# Check port binding
docker port firewall

# Test locally
docker exec firewall curl http://localhost:8080
```

### MAC Address Not Being Blocked

```bash
# Check if attacker MAC is in ARP table
docker exec firewall arp -a

# Manually get MAC of attacker
docker exec internal-attacker ip link show eth0

# Check blocked MACs file
docker exec firewall cat /app/data/blocked_macs.txt

# Check iptables MAC rules
docker exec firewall iptables -L BLOCKED_MACS -n -v
```

## 🔄 Stopping and Cleanup

### Stop All Containers

```bash
docker-compose down
```

### Stop and Remove Volumes

```bash
docker-compose down -v
```

### Complete Cleanup

```bash
# Stop and remove everything
docker-compose down -v --rmi all

# Remove networks
docker network prune -f
```

## 📝 Key Files

### Firewall Configuration

- `firewall/firewall.sh` - Main iptables rules
- `firewall/ddos_monitor.sh` - DDoS detection and MAC blocking
- `firewall/dashboard.py` - Monitoring dashboard
- `firewall/proxy.py` - HTTP proxy with logging
- `firewall/data/blocked_macs.txt` - Blocked MAC addresses

### Server Configuration

- `server/app.py` - REST API server
- Server SSH: root/firewall123

### Attack Scripts

- `internal-attacker`: `ddos_attack` command
- Customizable threads and requests

## 🎓 Learning Objectives

After completing this lab, you will understand:

1. **Network Segmentation**
   - Internal vs external networks
   - Gateway configuration
   - Network isolation

2. **iptables Firewall Rules**
   - IP filtering
   - Port filtering
   - Connection tracking
   - Rate limiting
   - MAC filtering

3. **DDoS Protection**
   - Connection rate limiting
   - SYN flood protection
   - Concurrent connection limits
   - Automatic detection and blocking

4. **Access Control**
   - Role-based access (admin vs regular users)
   - Service-level restrictions
   - Network-layer enforcement

5. **Docker Networking**
   - Bridge networks
   - Custom gateways
   - Container isolation
   - Network policies

## 🔐 Security Concepts Demonstrated

1. **Defense in Depth**: Multiple layers of protection
2. **Least Privilege**: SSH only for admin client
3. **Network Segmentation**: Internal vs external separation
4. **Automatic Response**: MAC blocking on DDoS detection
5. **Monitoring**: Real-time dashboard and logging
6. **Stateful Inspection**: Connection tracking and rate limiting

## ⚠️ Important Notes

- **Server is NOT directly accessible**: All access must go through firewall
- **MAC blocking is automatic**: Internal attackers are detected and blocked
- **SSH is restricted**: Only admin client can SSH to server
- **External network is blocked**: External attackers cannot reach internal resources
- **Most filtering is in iptables**: For performance and security

## ⚠️ Disclaimer

This lab is for **educational purposes only**. The attack tools included should only be used in controlled environments that you own or have explicit permission to test. Unauthorized network attacks are illegal.

---

**Created for Network Security Education** 🎓🔒
