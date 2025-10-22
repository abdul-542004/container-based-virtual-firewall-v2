# 🛡️ Firewall Demonstration Guide

## Quick Start

### 1. Start the Lab
```bash
./start-lab.sh
```

Wait for all containers to start (about 30 seconds).

### 2. Run the Automated Demo
```bash
./demo.sh
```

This will demonstrate all firewall capabilities with clear, colorful output.

## Manual Testing

### Test 1: IP Filtering

**Internal Client (Allowed):**
```bash
docker exec client curl http://firewall:5000/api/employees
```

**External Attacker (Blocked):**
```bash
docker exec attacker curl http://172.20.0.2:5000/
# Should fail - external network blocked
```

### Test 2: SSH Port Filtering

**Admin Client (Allowed):**
```bash
docker exec admin-client nc -zv 172.30.0.3 22
```

**Regular Client (Blocked):**
```bash
docker exec client nc -zv 172.30.0.3 22
# Should be rejected by firewall
```

### Test 3: DDoS Attack & MAC Blocking

**Launch DDoS Attack:**
```bash
docker exec internal-attacker ddos_attack http://firewall:5000/api/employees 10 100
```

**Check if MAC was blocked (wait ~10 seconds after attack):**
```bash
docker exec firewall cat /app/data/blocked_macs.txt
```

**Try to access after being blocked:**
```bash
docker exec internal-attacker curl http://firewall:5000/
# Should timeout or be blocked
```

### Test 4: Normal API Operations

**List Employees:**
```bash
docker exec client curl http://firewall:5000/api/employees
```

**Create Employee:**
```bash
docker exec client curl -X POST http://firewall:5000/api/employees \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","position":"Engineer","department":"IT","salary":70000,"email":"john@test.com"}'
```

**Update Employee:**
```bash
docker exec client curl -X PUT http://firewall:5000/api/employees/1 \
  -H "Content-Type: application/json" \
  -d '{"salary":80000}'
```

**Delete Employee:**
```bash
docker exec client curl -X DELETE http://firewall:5000/api/employees/1
```

## Monitoring

### Dashboard
Open in browser: **http://localhost:8080**

The dashboard shows:
- Real-time traffic logs
- DDoS alerts
- Blocked MAC addresses
- Traffic statistics

### Firewall Logs

**View iptables rules:**
```bash
docker exec firewall iptables -L -n -v
```

**View blocked MACs:**
```bash
docker exec firewall cat /app/data/blocked_macs.txt
```

**View request logs:**
```bash
docker exec firewall cat /app/logs/requests.jsonl | tail -10
```

**View system logs:**
```bash
docker logs firewall
```

## Container Access

### Get shell in any container:

```bash
docker exec -it client sh
docker exec -it admin-client bash
docker exec -it internal-attacker bash
docker exec -it server bash
docker exec -it firewall bash
docker exec -it attacker sh
```

### Get container IP and MAC:

```bash
# From inside container
ip addr show eth0
```

## Stopping the Lab

```bash
./stop-lab.sh
```

Or manually:
```bash
docker-compose down
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│         Internal Network (172.20.0.0/16)        │
│                                                  │
│  ┌────────────┐  ┌────────────┐  ┌───────────┐ │
│  │   Client   │  │Admin Client│  │  Internal │ │
│  │ 172.20.0.4 │  │ 172.20.0.5 │  │ Attacker  │ │
│  └─────┬──────┘  └─────┬──────┘  └─────┬─────┘ │
│        │                │               │       │
│        └────────────────┼───────────────┘       │
│                         │                       │
│                  ┌──────▼──────┐                │
│                  │  Firewall   │                │
│                  │ 172.20.0.2  │                │
│                  │             │                │
│                  │ iptables    │                │
│                  │ Proxy       │                │
│                  │ Dashboard   │                │
│                  └──────┬──────┘                │
│                         │                       │
│                  ┌──────▼──────┐                │
│                  │   Server    │                │
│                  │ 172.30.0.3  │                │
│                  │             │                │
│                  │ API Only    │                │
│                  │ SSH (admin) │                │
│                  └─────────────┘                │
│                                                  │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│        External Network (172.21.0.0/16)         │
│                                                  │
│                  ┌─────────────┐                 │
│                  │  Attacker   │                 │
│                  │172.21.0.10  │                 │
│                  │  (BLOCKED)  │                 │
│                  └─────────────┘                 │
│                                                  │
└─────────────────────────────────────────────────┘
```

## Firewall Rules Summary

### 1. IP Filtering
- ✅ Allow: 172.20.0.0/16 (internal network)
- ❌ Block: All other networks

### 2. Port Filtering
- ✅ SSH (22): Only from 172.20.0.5 (admin-client)
- ❌ SSH (22): Blocked from all other clients
- ✅ HTTP (5000): Allowed within internal network

### 3. DDoS Protection
- Rate limiting: Max 20 connections/minute per IP
- SYN flood protection: 15/second limit
- Connection limit: Max 15 concurrent connections per IP
- ICMP flood protection: 2 pings/second

### 4. MAC Filtering
- Automatic blocking of IPs exceeding DDoS thresholds
- MAC address extracted via ARP
- Blocked MACs stored in `/app/data/blocked_macs.txt`
- Applied via iptables BLOCKED_MACS chain

## Troubleshooting

### Containers not starting
```bash
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### Logs not showing
```bash
sudo rm -f firewall/logs/requests.jsonl
sudo touch firewall/logs/requests.jsonl
sudo chmod 666 firewall/logs/requests.jsonl
docker restart firewall
```

### Reset blocked MACs
```bash
sudo sh -c 'echo "" > firewall/data/blocked_macs.txt'
docker exec firewall iptables -F BLOCKED_MACS
docker restart firewall
```

## Educational Value

This lab demonstrates:
- Container-based networking and isolation
- iptables firewall configuration
- DDoS detection and mitigation
- MAC address filtering
- Network segmentation
- API security through proxying
- Real-time monitoring and logging
