# Container Based Virtual Firewall

## INTRODUCTION

A firewall is a security control that monitors and filters network traffic based on a defined policy. Operating primarily at layers 3–4 (and sometimes higher), it evaluates packet attributes (IP, port, protocol, connection state) and decides whether to allow, reject, or drop traffic.

A virtual firewall is a software-based firewall that runs on virtualized infrastructure rather than a dedicated hardware appliance. It provides comparable packet filtering and stateful inspection capabilities with improved flexibility, automation, and cost efficiency.

A container-based virtual firewall packages the firewall logic and its management plane inside a container. It leverages Linux network namespaces and iptables/conntrack for dataplane control, and can expose a lightweight dashboard/API for runtime rule management. In this project, the firewall container sits between an internal client and an internal server, mediating traffic and enforcing:
- IP and MAC address filtering
- Port-based access control
- DDoS protections (rate limiting, SYN flood mitigation, concurrent connection limits, ICMP throttling)
- Real-time monitoring via a dashboard

This approach demonstrates a modern, reproducible, and portable security control that’s easy to spin up, test, and extend.

## LITERATURE REVIEW

Before containerized approaches became common, several strategies were typically used to deploy firewalls in lab and production environments:

1) Hardware Network Firewalls (Perimeter Appliances)
- Dedicated appliances at the network edge (e.g., between corporate LAN and the Internet).
- Strengths: high throughput, vendor support, specialized ASICs, mature features.
- Drawbacks: expensive, slower to provision/change, limited environment parity for dev/test, coarse-grained segmentation, difficult to replicate at scale for experiments.

2) Host-Based Firewalls on Bare Metal/VMs
- OS-native controls like Linux iptables/nftables or Windows Firewall, configured per host.
- Strengths: zero extra hardware, close to workload, flexible.
- Drawbacks: configuration drift across many hosts, limited centralized visibility, harder to orchestrate consistently, environment coupling to host lifecycle.

3) VM-Based Virtual Appliances
- Full virtual machines running firewall distributions (e.g., pfSense/OPNsense) or vendor virtual editions.
- Strengths: close to hardware firewall feature parity, familiar operational model, fits virtualized datacenters.
- Drawbacks: heavy (full OS per instance), slower boot and scale operations, higher resource overhead, more complex image management compared to containers.

4) SDN/NFV and Microsegmentation (Pre-Container Era to Cloud-Native)
- Network function virtualization moved firewalling into software overlays; SDN enabled central policy control; microsegmentation restricted east–west traffic.
- Strengths: policy-driven, programmable, scalable.
- Drawbacks: complex control planes, heavier platforms to deploy/operate; not trivial for small labs or lightweight demos.

Why a container-based firewall for labs and demos?
- Lightweight and fast: seconds to build/start; easy to tear down.
- Reproducible: Dockerfiles and Compose capture the entire environment.
- Isolated yet realistic: distinct network namespaces and bridge networks emulate multi-subnet topologies.
- Easy iteration: change code/policy, rebuild, and observe impact immediately.

Trade-offs in container-based designs
- Not a replacement for enterprise-grade perimeter devices in high-throughput networks.
- Requires careful capability management (NET_ADMIN/NET_RAW) and privilege scoping.
- By default, focuses on L3/L4; application-layer protections would require additional proxies/IDS/IPS components.

## EXPERIMENTAL SETUP

### Architecture Overview

Two Docker bridge networks emulate internal and external segments. The firewall container is dual-homed and forwards/filters traffic between them and to the protected server.

```
┌─────────────────────────────────────────────────────────────┐
│                    Internal Network (172.20.0.0/16)         │
│                                                             │
│  ┌──────────┐      ┌───────────┐      ┌──────────┐          │
│  │  Client  │ ───▶ │ Firewall  │ ───▶ │  Server  │          │
│  │172.20.0.4│      │172.20.0.2 │      │172.20.0.3│          │
│  └──────────┘      │ Dashboard │                           │
│                    │ Port 8080 │                           │
│                    └─────┬─────┘                           │
│                          │                                 │
│                    ┌─────▼─────┐                           │
│                    │ Attacker  │  (external testing only)  │
│                    └───────────┘                           │
└─────────────────────────────────────────────────────────────┘
                             │
┌────────────────────────────▼───────────────────────────────┐
│               External Network (172.21.0.0/16)             │
│                      Attacker: 172.21.0.10                 │
└────────────────────────────────────────────────────────────┘
```

- Internal network (bridge): 172.20.0.0/16
  - firewall: 172.20.0.2
  - server:   172.20.0.3 (Flask app)
  - client:   172.20.0.4
- External network (bridge): 172.21.0.0/16
  - firewall: 172.21.0.2
  - attacker: 172.21.0.10

Exposed host ports
- 8080 → Firewall dashboard (http://localhost:8080)
- 5000 → Proxied server access via firewall (http://localhost:5000)
- 5001 → Direct server access (bypasses firewall) for comparison (http://localhost:5001)

### Components and Roles

- Firewall container
  - Dataplane: Linux iptables/conntrack for packet filtering, forwarding, and basic DDoS protection.
  - Control plane: Python/Flask dashboard (`dashboard.py`) and proxy (`proxy.py`) for rule management and traffic mediation.
  - Bootstraps rules via `firewall.sh`; supports periodic reload when a marker file exists.
  - Packages helpful tooling: tcpdump, iproute2, conntrack-tools.

- Server container
  - Flask Employee Management System API/UI (`server/app.py`).
  - Exposed directly on host port 5001 (bypass) and indirectly via the firewall on 5000.

- Client container
  - Internal trusted client for legitimate traffic tests.

- Attacker container
  - External host to simulate adversarial behavior (e.g., floods, high-rate requests).

### Tools and Technologies

- Container/runtime: Docker Engine with Docker Compose.
- Language/runtime: Python 3.11 (slim base image for firewall; Flask apps for dashboard/server).
- Networking: Linux bridges, namespaces, iptables, conntrack.
- Diagnostics: tcpdump, iputils-ping, net-tools, curl.
- Optional attack tooling examples: `hping3` for SYN floods (root required), simple request floods via provided scripts/loops.

### Firewall Policy Summary (from `firewall/firewall.sh`)

- Baseline
  - IP forwarding enabled; default policy: DROP on FORWARD, ACCEPT on INPUT/OUTPUT.
  - Allow loopback and established/related traffic.

- Address filtering
  - Blocklist: `/app/data/blocked_ips.txt` → DROP in INPUT and FORWARD.
  - Allowlist: `/app/data/allowed_ips.txt` → ACCEPT in FORWARD (use to bypass general constraints for trusted IPs).
  - MAC blocklist: `/app/data/blocked_macs.txt` → DROP frames from listed MACs (INPUT, FORWARD).

- Port filtering
  - SSH (22): DROP by default.
  - HTTP (80) and HTTPS (443): ACCEPT.
  - Application port (5000): ACCEPT (proxied Flask app).

- DDoS protections
  - Per-source connection rate limit: max ~20 new TCP connections/minute using `-m recent`.
  - SYN flood throttling: allow ~10/s with burst 20; excess SYNs dropped.
  - Concurrent connection cap: `--dport 5000` above 10 concurrent connections per IP → DROP.
  - ICMP echo-request: 1 per second; excess dropped.
  - Logging for dropped packets with rate limits to avoid log floods.

- Rule reload
  - If `/app/data/reload_rules` exists, the script re-execs to reapply state (dashboard can trigger this by creating the marker file).

### Data and State

- Rule lists (mounted as volumes under the firewall container)
  - `firewall/data/blocked_ips.txt`
  - `firewall/data/allowed_ips.txt`
  - `firewall/data/blocked_macs.txt`

- Logs
  - `firewall/logs/requests.jsonl` for application-layer request logs.
  - System logs for iptables drops (view via `docker logs firewall`).

### Demonstration Flow (Reproducible Experiment)

1) Build and start
   - `docker-compose build` then `docker-compose up -d`.
   - Verify services: `docker-compose ps`, `docker logs firewall`, `docker logs server`.

2) Access points
   - Dashboard: http://localhost:8080
   - Server via firewall: http://localhost:5000
   - Server direct (bypass): http://localhost:5001

3) Experiments
   - IP filtering: add attacker’s IP (172.21.0.10 is external; for internal tests use 172.20.0.x) to blocklist and validate connection denial.
   - MAC filtering: add attacker/container MAC to blocklist; verify traffic is dropped.
   - Port control: confirm SSH (22) blocked; HTTP/HTTPS allowed; custom ports denied by default.
   - DDoS scenarios:
     - High-rate requests: allow initial requests then observe rate-limit drops and alerts.
     - SYN flood: excess SYNs dropped while legitimate flows continue.
     - Concurrent connection limits: attempts above 10 active conns/IP to port 5000 are rejected.

4) Observability
   - Dashboard shows live traffic, rule state, and alerts.
   - Packet captures via tcpdump on the firewall container when deeper inspection is needed.

### Environment Summary (from `docker-compose.yml`)

- Services: server, firewall, client, attacker.
- Networks: `internal_network` (172.20.0.0/16), `external_network` (172.21.0.0/16) with custom bridge names.
- Capabilities: firewall runs privileged and with NET_ADMIN/NET_RAW to program iptables and inspect traffic.
- Images built locally from `Dockerfile`s; Python dependencies pinned (Flask, flask-cors, requests on firewall; Flask, flask-cors on server).

---

This report summarizes the rationale, prior approaches, and the complete experimental configuration for a container-based virtual firewall lab. It can be extended with evaluation results (throughput under attack, latency impact, rule update latency) and a references section if you plan to turn it into a formal paper.
