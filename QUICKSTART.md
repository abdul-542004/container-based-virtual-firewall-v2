# Container-Based Virtual Firewall Lab - Quick Reference

## Quick Start

```bash
# Start the lab
./start-lab.sh

# Stop the lab
./stop-lab.sh
```

## URLs

- **Dashboard**: http://localhost:8080
- **Employee Management**: http://localhost:5000

## Common Commands

### Access Containers
```bash
docker exec -it client bash       # Client container
docker exec -it firewall bash     # Firewall container  
docker exec -it server bash       # Server container
docker exec -it attacker bash     # Attacker container
```

### Test Scenarios

#### 1. Normal Access (from Client)
```bash
docker exec -it client curl http://firewall:5000/
docker exec -it client curl http://firewall:5000/api/employees
```

#### 2. DDoS Attack (from Attacker)
```bash
docker exec -it attacker ddos_attack http://firewall:5000/ 10 50
```

#### 3. View Firewall Rules
```bash
docker exec firewall iptables -L -n -v
```

#### 4. Monitor Traffic
```bash
docker logs -f firewall
docker exec firewall cat /app/logs/requests.jsonl
```

## Dashboard Actions

1. **Block IP**: Enter IP in "Block IP Address" section → Click "Block IP"
2. **Allow IP**: Enter IP in "Allow IP Address" section → Click "Allow IP"
3. **Block MAC**: Enter MAC in "Block MAC Address" section → Click "Block MAC"
4. **View Logs**: Scroll to "Recent Traffic Log" section

## Test Demonstrations

### Demo 1: IP Filtering
1. Access dashboard: http://localhost:8080
2. Block IP: `172.20.0.5` (attacker)
3. Test from attacker: `docker exec -it attacker curl http://firewall:5000/`
4. Should be blocked

### Demo 2: DDoS Protection
1. Run attack: `docker exec -it attacker ddos_attack http://firewall:5000/ 10 50`
2. Check dashboard for DDoS alert
3. See rate limiting in action

### Demo 3: Port Filtering
1. SSH blocked: `docker exec -it client nc -zv server 22` (fails)
2. HTTP allowed: `docker exec -it client curl http://firewall:5000/` (works)

## Troubleshooting

```bash
# Restart firewall
docker-compose restart firewall

# View logs
docker-compose logs firewall

# Check network
docker network inspect containerbasedvirtualfirewall_internal_network

# Rebuild everything
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## Container IPs

- **Client**: 172.20.0.4
- **Firewall (internal)**: 172.20.0.2
- **Firewall (external)**: 172.21.0.2
- **Server**: 172.30.0.3 (protected subnet)
- **Attacker**: 172.21.0.10 (external)

## Ports

- **8080**: Firewall Dashboard
- **5000**: Proxied Server Access (through firewall)
- **5001**: Direct Server Access (bypass firewall)
- **22**: SSH (BLOCKED)
- **80/443**: HTTP/HTTPS (ALLOWED)
