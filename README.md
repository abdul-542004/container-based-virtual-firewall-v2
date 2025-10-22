
# Container-Based Virtual Firewall Lab

This project is a hands-on lab that demonstrates a container-based virtual firewall placed between an internal network of clients and a protected application server. It showcases network segmentation, kernel-level packet filtering with iptables, DDoS detection and mitigation, MAC-based blocking, and a real-time monitoring dashboard.

The server is not exposed to the outside world. All access goes through the firewall container, which enforces security policy and provides visibility.


## What you get

- A multi-network Docker topology with an internal LAN, an external segment, and a server subnet
- A firewall container that acts as the default gateway and security control point
- Kernel-level enforcement using iptables (IP filtering, port filtering, rate limiting, and MAC blocking)
- A Python proxy that forwards HTTP to the server and logs traffic to a dashboard
- A live dashboard with stats, traffic logs, and auto-blocking indicators
- Four client roles for realistic demos:
	- client (internal)
	- admin-client (internal, the only node allowed to SSH to server)
	- internal-attacker (internal, used to simulate DDoS)
	- attacker (external, blocked by design)


## Topology and networks

```
Internal network (172.20.0.0/16)
	- client            172.20.0.4  → default gw 172.20.0.2 (firewall)
	- admin-client      172.20.0.5  → default gw 172.20.0.2
	- internal-attacker 172.20.0.6  → default gw 172.20.0.2

Server network (172.30.0.0/16)
	- server            172.30.0.3  → default gw 172.30.0.2 (firewall)

External network (172.21.0.0/16)
	- attacker          172.21.0.10

Firewall container
	- internal iface:   172.20.0.2
	- server iface:     172.30.0.2
	- external iface:   172.21.0.2

Exposed on host:
	- Dashboard: http://localhost:8080
	- Proxied API: http://localhost:5000
	- Firewall SSH: host:2222 → firewall:22
```

All internal clients and the server have their default gateway set to the firewall, ensuring that no one can bypass it. The server has no host port mappings; it is reachable only through the firewall.


## Components

- Firewall (`firewall/`)
	- `firewall.sh`: iptables policy. Enables IP forwarding, sets default policies, implements IP and port filtering, DDoS protection (rate limiting, SYN flood limits, connection limits, ICMP limits), NAT, and hooks for MAC-based blocking.
	- `proxy.py`: a simple HTTP reverse proxy to the server. Logs every request to the dashboard and denies requests from blocked MACs.
	- `dashboard.py`: Flask app providing a live dashboard and small API for in-memory logs and blocked MACs.
	- `iptables_monitor.sh`: watches iptables counters and posts notable blocked events to the dashboard.
	- `ddos_monitor.sh`: analyzes recent request rates via the dashboard API; if a client exceeds thresholds, it adds an iptables MAC block and records it in the dashboard set.
	- `start.sh`: boots firewall services in order (iptables → dashboard → proxy → monitors).

- Server (`server/`)
	- `app.py`: a RESTful Employee Management API (CRUD) served by Flask.
	- SSH enabled only for demonstration of permitted admin access via the firewall.

- Clients
	- `client/`: minimal internal client with curl/ping/netcat.
	- `admin-client/`: internal client with SSH client; the only node allowed to reach server:22 through the firewall.
	- `internal-attacker/`: internal client with a DDoS simulation script.
	- `attacker/`: external client for negative tests; cannot reach the protected API.

- Orchestration
	- `docker-compose.yml`: defines three Docker bridge networks and the five services with fixed IPs and per-network routing through the firewall.
	- `demo.sh`: an automated end-to-end demonstration script.
	- `start-lab.sh`, `stop-lab.sh`: convenience scripts to bring the stack up/down.


## Security policy (enforced mostly by iptables)

1) IP filtering
- Allow traffic originating from the internal network (172.20.0.0/16)
- Drop traffic from the external network (172.21.0.0/16)

2) Port filtering
- Only admin-client (172.20.0.5) may reach server:22 (SSH)
- HTTP API (port 5000) is reachable by internal clients through the firewall’s proxy

3) DDoS protection
- Per-source connection rate limit (~20 new TCP SYN/min)
- SYN flood limiting
- Concurrent connection limits per source
- ICMP echo-request rate limiting

4) MAC-based blocking
- When DDoS is detected, the attacker’s MAC is inserted into a dedicated BLOCKED_MACS chain and dropped.
- The dashboard also keeps an in-memory set of blocked MACs; the proxy consults it to reject at the application layer too.

5) NAT/Forwarding
- DNAT: firewall:5000 → server:5000, firewall:22 → server:22
- MASQUERADE for internal/server networks as needed


## Prerequisites

- Linux host with Docker and docker-compose
- Ports 8080 and 5000 free on the host


## Quick start

```bash
./start-lab.sh
```

Wait ~10–30 seconds, then:

- Dashboard: http://localhost:8080
- API via firewall: http://localhost:5000

Automated demo (optional):

```bash
./demo.sh
```


## Manual verification steps

1) IP filtering
- From internal client (allowed):
	```bash
	docker exec client curl -s http://firewall:5000/api/employees | head -n1
	```
- From external attacker (blocked):
	```bash
	docker exec attacker curl -s -m 5 http://172.20.0.2:5000/ || echo "blocked"
	```

2) SSH port filtering
- Admin client (allowed):
	```bash
	docker exec admin-client nc -zv 172.30.0.3 22 || true
	```
- Regular client (blocked):
	```bash
	docker exec client nc -zv 172.30.0.3 22 || true
	```

3) DDoS simulation and MAC block (from internal-attacker)
```bash
docker exec internal-attacker ddos_attack http://firewall:5000/api/employees 10 100
# Check blocked MACs via dashboard API
curl -s http://localhost:8080/api/blocked_macs
```

4) Inspect iptables
```bash
docker exec firewall iptables -L -n -v
docker exec firewall iptables -t nat -L -n -v
```


## How it works

- Routing: compose sets each container’s default route to the firewall’s IP on its network. The server’s default route is the firewall on the server network.
- Enforcement: `firewall.sh` programs iptables in the firewall container. The FORWARD chain enforces network and port policy. The NAT table handles DNAT/MASQUERADE.
- Telemetry: `proxy.py` logs each HTTP request to `dashboard.py` via a simple REST call; `iptables_monitor.sh` also reports notable drops based on kernel counters.
- Auto-blocking: `ddos_monitor.sh` analyzes the last minute of traffic (via dashboard API). When a source exceeds thresholds, it inserts two rules into `BLOCKED_MACS` (LOG + DROP) and records the MAC in the dashboard set.


## Troubleshooting

- Rebuild and restart cleanly:
	```bash
	docker-compose down -v
	docker-compose build --no-cache
	docker-compose up -d
	```
- Dashboard API quick checks:
	```bash
	curl -s http://localhost:8080/api/stats | jq .  # if jq is available
	curl -s http://localhost:8080/api/blocked_macs
	```
- Verify routes from a client:
	```bash
	docker exec client ip route
	docker exec client ping -c1 firewall
	docker exec client ping -c1 server    # typically blocked except via proxy
	```


## Educational value

This lab illustrates:
- Container networking and multi-bridge topologies
- Kernel-level packet filtering with iptables
- Reverse-proxying and L7 logging alongside L3/L4 policy
- DDoS detection heuristics and automated MAC-based mitigation
- The value of placing a firewall as the sole gateway for east–west and north–south traffic


## Repository map

- `docker-compose.yml` – topology and networking
- `firewall/` – iptables policy, proxy, dashboard, monitors
- `server/` – Flask CRUD API and SSH server
- `client/`, `admin-client/`, `internal-attacker/`, `attacker/` – minimal client images
- `demo.sh`, `start-lab.sh`, `stop-lab.sh` – helper scripts


## Notes

- The server has no host port mappings by design; it is only reachable through the firewall.
- The dashboard keeps logs and blocked MACs in memory; restarting the firewall will reset this state.
