# 🛡️ Container-Based Virtual Firewall Lab

A comprehensive Docker-based lab environment demonstrating network security concepts including firewall rules, traffic filtering, and DDoS protection.

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
- **Server Container**: Employee Management System (Flask app)
- **Firewall Container**: Network gateway with filtering and DDoS protection
- **Client Container**: Internal network client for testing
- **Attacker Container**: Simulates external threats

The firewall sits between clients and the server, intercepting and filtering all traffic based on configurable rules.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Internal Network (172.20.0.0/16)         │
│                                                              │
│  ┌──────────┐         ┌───────────┐         ┌──────────┐  │
│  │  Client  │────────▶│ Firewall  │────────▶│  Server  │  │
│  │172.20.0.4│         │172.20.0.2 │         │172.20.0.3│  │
│  └──────────┘         │           │         └──────────┘  │
│                       │ Dashboard │                        │
│                       │ Port 8080 │                        │
│                       └─────┬─────┘                        │
│                             │                              │
│                       ┌─────▼─────┐                        │
   │                       │ Attacker  │                        │
   │                       │ (external)│                        │
│                       └───────────┘                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                               │
                               │
┌──────────────────────────────▼──────────────────────────────┐
│              External Network (172.21.0.0/16)               │
│                                                              │
│                       ┌───────────┐                         │
│                       │ Attacker  │                         │
│                       │172.21.0.10│                         │
│                       └───────────┘                         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## ✨ Features

### 1. IP Address Filtering
- Block specific IP addresses
- Whitelist trusted IPs
- Real-time rule application
- Dynamic management through dashboard

### 2. MAC Address Filtering
- Block devices by MAC address
- Prevent MAC spoofing attempts
- Layer 2 security

### 3. Port Filtering
- **SSH (Port 22)**: Blocked by default
- **HTTP (Port 80)**: Allowed
- **HTTPS (Port 443)**: Allowed
- **Custom Ports**: Configurable

### 4. DDoS Protection
- **Connection Rate Limiting**: Max 20 connections/minute per IP
- **SYN Flood Protection**: Rate limiting on SYN packets
- **Concurrent Connection Limiting**: Max 10 concurrent connections per IP
- **ICMP Flood Protection**: Ping rate limiting
- **Automatic Detection**: Dashboard alerts for suspicious activity

### 5. Interactive Dashboard
- Real-time traffic monitoring
- Add/remove IP and MAC filters
- View blocked/allowed requests
- DDoS attack alerts
- Traffic statistics and analytics

### 6. Employee Management System
- Full CRUD operations
- RESTful API
- Web interface
- Sample data included

## 🔧 Prerequisites

- Docker Engine (20.10+)
- Docker Compose (2.0+)
- At least 2GB free RAM
- Linux host (recommended) or Docker Desktop

## 📦 Installation

### 1. Clone or Navigate to Project Directory

```bash
cd "/home/abdullah/Study/container based virtual firewall"
```

### 2. Verify Project Structure

```bash
tree -L 2
```

Expected structure:
```
.
├── docker-compose.yml
├── server/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── firewall/
│   ├── Dockerfile
│   ├── dashboard.py
│   ├── proxy.py
│   ├── firewall.sh
│   ├── start.sh
│   └── requirements.txt
├── client/
│   └── Dockerfile
├── attacker/
│   └── Dockerfile
└── README.md
```

### 3. Build and Start Containers

```bash
# Build all containers
docker-compose build

# Start the environment
docker-compose up -d

# Check container status
docker-compose ps
```

### 4. Verify Services

```bash
# Check firewall logs
docker logs firewall

# Check server logs
docker logs server

# Verify all containers are running
docker ps
```

## 🚀 Usage

### Access Points

1. **Firewall Dashboard**: http://localhost:8080
   - Monitor traffic
   - Manage firewall rules
   - View statistics

2. **Server (via Firewall)**: http://localhost:5000
   - Employee Management System
   - Proxied through firewall

3. **Server (Direct - for testing)**: http://localhost:5001
   - Bypasses firewall
   - For comparison testing

### Container Access

```bash
# Access client container
docker exec -it client bash

# Access firewall container
docker exec -it firewall bash

# Access server container
docker exec -it server bash

# Access attacker container
docker exec -it attacker bash
```

## 🧪 Demonstrations

### Demo 1: IP Address Filtering

#### Block an IP Address

1. Open Firewall Dashboard: http://localhost:8080
2. In "Block IP Address" section, enter: `172.20.0.5`
3. Click "Block IP"
4. From attacker container, try to access server:
   ```bash
   docker exec -it attacker curl http://firewall:5000/
   # Should timeout or be rejected
   ```

#### Verify in Dashboard
- Check "Blocked IPs" list
- See denied requests in traffic log

#### Unblock IP
1. Find IP in "Blocked IPs" list
2. Click "Unblock"
3. Test access again - should work

### Demo 2: MAC Address Filtering

#### Get MAC Address
```bash
# From attacker container
docker exec -it attacker ip link show
# Look for "link/ether" - note the MAC address
```

#### Block MAC Address
1. In dashboard, go to "Block MAC Address"
2. Enter the MAC address (format: `02:42:ac:14:00:05`)
3. Click "Block MAC"
4. Try accessing from that container - should be blocked

### Demo 3: Port Filtering

#### Test SSH Block (Port 22)
```bash
# From client container
docker exec -it client bash

# Try to connect to server on SSH port
nc -zv server 22
# Should fail - port blocked by firewall
```

#### Test HTTP Allow (Port 80)
```bash
# HTTP should work
curl -I http://firewall:5000/
# Should receive 200 OK
```

### Demo 4: DDoS Attack Prevention

#### Scenario 1: High-Rate Attack
```bash
# From attacker container
docker exec -it attacker bash

# Launch DDoS simulation
ddos_attack http://firewall:5000/ 10 50
# 10 threads, 50 requests each = 500 total requests
```

**Expected Behavior:**
- First 20 requests per minute: Allowed
- Subsequent requests: Blocked (rate limit exceeded)
- Dashboard shows DDoS alert
- IP appears in "DDoS ALERT" section

#### Scenario 2: SYN Flood Attack
```bash
# From attacker
docker exec -it attacker bash

# SYN flood simulation (requires root)
hping3 -S --flood -p 5000 172.20.0.2
```

**Expected Behavior:**
- Firewall drops excessive SYN packets
- Normal legitimate connections still work
- See dropped packets in firewall logs

#### Scenario 3: Slow Concurrent Connections
```bash
# Open multiple connections simultaneously
for i in {1..15}; do
  curl http://firewall:5000/ &
done
```

**Expected Behavior:**
- First 10 connections: Processed
- Connections 11-15: Rejected (concurrent limit)
- Dashboard shows the activity

### Demo 5: Normal Client Access

```bash
# From client container
docker exec -it client bash

# View available commands
info

# Access Employee Management System
curl http://firewall:5000/

# Get employees via API
curl http://firewall:5000/api/employees

# Add new employee
curl -X POST http://firewall:5000/api/employees \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "position": "Tester",
    "department": "QA",
    "salary": 55000,
    "email": "test@company.com"
  }'
```

**Expected Behavior:**
- All requests logged in dashboard
- Employee data returned successfully
- Normal traffic patterns observed

## 🧑‍🏫 Testing Scenarios for Demonstration

### Scenario 1: Complete Workflow Demo

```bash
# Terminal 1: Monitor Dashboard
# Open browser: http://localhost:8080

# Terminal 2: Legitimate Client
docker exec -it client bash
curl http://firewall:5000/api/employees

# Terminal 3: Attacker
docker exec -it attacker bash
ddos_attack http://firewall:5000/ 5 30

# Observe in Dashboard:
# - Client requests: Allowed (green)
# - Attacker requests: Initially allowed, then blocked
# - DDoS alert triggered
# - Statistics updated
```

### Scenario 2: Progressive Blocking

```bash
# Step 1: Allow all traffic
# Access from attacker works

# Step 2: Block attacker IP
# Add 172.20.0.5 to blocked IPs in dashboard

# Step 3: Verify block
docker exec -it attacker curl http://firewall:5000/
# Should timeout

# Step 4: Client still works
docker exec -it client curl http://firewall:5000/
# Should work fine
```

### Scenario 3: Port-Based Filtering

```bash
# From client container
docker exec -it client bash

# Test blocked SSH port
echo "Testing SSH (should fail):"
nc -zv server 22

# Test allowed HTTP port
echo "Testing HTTP (should work):"
curl -I http://firewall:5000/

# Try custom port (blocked by default)
echo "Testing custom port 8888 (should fail):"
nc -zv server 8888
```

## 📊 Dashboard Features

### Statistics Panel
- **Total Requests**: Count of all requests in last hour
- **Allowed Requests**: Successfully proxied requests
- **Blocked Requests**: Denied by firewall rules
- **Active Rules**: Number of blocking rules

### Traffic Log
- Real-time request monitoring
- Client IP addresses
- HTTP methods and paths
- Response status codes
- Color-coded by success/failure

### DDoS Detection
- Automatic alert when suspicious activity detected
- Shows attacking IP addresses
- Displays request rate per minute
- Visual warning banner

### Rule Management
- **Block IP**: Add IP to blacklist
- **Allow IP**: Add IP to whitelist
- **Block MAC**: Block by hardware address
- **One-click removal**: Easy rule deletion

## 🔍 Monitoring and Logs

### View Firewall Logs
```bash
# Real-time logs
docker logs -f firewall

# Traffic logs
docker exec firewall cat /app/logs/traffic.log

# Request logs (JSON)
docker exec firewall cat /app/logs/requests.jsonl
```

### View iptables Rules
```bash
# Current firewall rules
docker exec firewall iptables -L -n -v

# NAT rules
docker exec firewall iptables -t nat -L -n -v

# Connection tracking
docker exec firewall conntrack -L
```

### Monitor Network Traffic
```bash
# Capture traffic on firewall
docker exec firewall tcpdump -i any -n

# Monitor specific port
docker exec firewall tcpdump -i any port 5000 -n
```

## 🛠️ Troubleshooting

### Containers Not Starting

```bash
# Check logs
docker-compose logs

# Rebuild containers
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Firewall Rules Not Applying

```bash
# Restart firewall container
docker-compose restart firewall

# Manually reload rules
docker exec firewall /app/firewall.sh
```

### Cannot Access Dashboard

```bash
# Check firewall container status
docker ps | grep firewall

# Check port binding
docker port firewall

# Check firewall logs
docker logs firewall

# Verify port 8080 is not in use
sudo netstat -tulpn | grep 8080
```

### Network Connectivity Issues

```bash
# Check Docker networks
docker network ls
docker network inspect containerbasedvirtualfirewall_internal_network

# Test connectivity between containers
docker exec client ping -c 3 firewall
docker exec client ping -c 3 server
```

### DDoS Protection Not Working

```bash
# Verify iptables rules
docker exec firewall iptables -L -n -v | grep recent

# Check connection tracking
docker exec firewall cat /proc/sys/net/netfilter/nf_conntrack_count

# Reset firewall rules
docker exec firewall /app/firewall.sh
```

## 🔄 Stopping and Cleaning Up

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

## 📝 Configuration Files

### Blocked IPs
Location: `firewall/data/blocked_ips.txt`
```
# One IP per line
172.20.0.5
192.168.1.100
```

### Allowed IPs
Location: `firewall/data/allowed_ips.txt`
```
# One IP per line
172.20.0.4
10.0.0.1
```

### Blocked MACs
Location: `firewall/data/blocked_macs.txt`
```
# One MAC per line
02:42:ac:14:00:05
aa:bb:cc:dd:ee:ff
```

## 🎓 Learning Objectives

After completing this lab, you will understand:

1. **Firewall Fundamentals**
   - Packet filtering
   - Stateful inspection
   - Rule precedence

2. **Network Security**
   - IP and MAC filtering
   - Port-based access control
   - DDoS mitigation techniques

3. **Linux Networking**
   - iptables configuration
   - IP forwarding
   - Connection tracking

4. **Docker Networking**
   - Bridge networks
   - Container isolation
   - Network namespaces

5. **Attack Detection**
   - Identifying DDoS patterns
   - Rate limiting
   - Traffic analysis

## 📚 Additional Resources

- [iptables Tutorial](https://www.netfilter.org/documentation/)
- [Docker Networking](https://docs.docker.com/network/)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Linux Network Security](https://www.kernel.org/doc/html/latest/networking/)

## 🤝 Credits

Created for educational purposes to demonstrate container-based network security concepts.

## ⚠️ Disclaimer

This lab is for **educational purposes only**. The attack tools included should only be used in controlled environments that you own or have explicit permission to test. Unauthorized network attacks are illegal.

---

**Happy Learning! 🎓🔒**
