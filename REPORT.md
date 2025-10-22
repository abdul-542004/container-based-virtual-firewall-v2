# Academic Report: Container-Based Virtual Firewall Lab

## 1. Introduction

Firewalls are network security systems that monitor and control traffic based on predetermined security policies. Traditional firewalls operate at network and transport layers (L3/L4) using technologies such as packet filtering, stateful inspection, and NAT. Modern environments also employ application-aware controls (L7) to add visibility and policy context.

A virtual firewall is a software-based firewall that runs on general-purpose compute instead of dedicated hardware. It can be deployed as a virtual machine, process, or container, providing flexible placement and elastic scaling.

This lab implements a container-based virtual firewall placed between an internal network and a protected server. The firewall acts as the default gateway for all clients and the server, enforcing policy via Linux iptables and providing a live dashboard. The server is not directly exposed to the host or external networks; all access traverses the firewall.


## 2. Literature Review

Prior to containerized approaches, common strategies included:

- Hardware appliances: Purpose-built firewall devices offering high throughput and mature features. Drawbacks include cost, physical placement constraints, coarse multi-tenancy, and slower change cycles.
- Host-based firewalls: Local OS firewalls (e.g., Windows Firewall, iptables/ufw on Linux) applied per host. While flexible, they can be inconsistent across fleets, harder to centrally monitor, and don’t naturally segment networks.
- Virtual-machine-based firewalls: Software firewalls packaged as VMs. These improve flexibility over hardware but tend to be heavier in resource consumption, slower to spin up, and less granular for micro-segmentation.
- SDN/NFV and cloud-native security groups: Network overlays and policy constructs (e.g., AWS Security Groups) that filter traffic in virtualized fabrics. Powerful at scale, but can be provider-specific and abstracted away from kernel-level behavior.

Container-based virtual firewalls bring several advantages:

- Lightweight deployment and fast iteration, aligned with container lifecycle
- Easy multi-network attachment for east–west and north–south control
- Fine-grained, code-defined policies with reproducible builds
- Composability with additional services (proxy, telemetry, dashboards)

Limitations to consider:

- Persistence of state: in-memory telemetry can be ephemeral without external storage
- Performance ceilings compared to specialized hardware at very high throughputs
- Operational complexity if policy is split across layers (L3–L7) without clear ownership


## 3. Experimental Setup

### 3.1 Objectives

Demonstrate a firewall that:

- Allows only internal network clients to access a REST API on the server
- Restricts SSH access to the server to the admin client only
- Detects and mitigates an internal DDoS attempt by blocking the attacker’s MAC
- Blocks all traffic originating from the external network

### 3.2 Topology

Three Docker bridge networks are used:

- Internal: 172.20.0.0/16 (client, admin-client, internal-attacker)
- Server:   172.30.0.0/16 (server)
- External: 172.21.0.0/16 (attacker)

The firewall container connects to all three and is the default gateway for both the internal clients and the server. The host exposes only the firewall’s dashboard (8080), proxied API (5000), and firewall SSH (host:2222 → firewall:22). The server exposes no host ports.

### 3.3 Tools and components

- Docker and docker-compose for orchestration
- Linux iptables for packet filtering and NAT
- Flask for the API server (`server/app.py`) and the firewall dashboard (`firewall/dashboard.py`)
- A lightweight HTTP proxy (`firewall/proxy.py`) for logging and simple L7 control
- Shell scripts for initialization and monitoring:
	- `firewall/firewall.sh` (iptables policy)
	- `firewall/ddos_monitor.sh` (request-rate analysis and MAC blocking)
	- `firewall/iptables_monitor.sh` (counter-based event reporting)
	- `firewall/start.sh` (service orchestration)
- Minimal client images for internal, admin, and attacker roles

### 3.4 Server application

The server implements a RESTful Employee Management API with CRUD endpoints. It also runs an SSH daemon for the access-control demonstration. The server’s default route points to the firewall on the server subnet, ensuring return traffic traverses the firewall.


## 4. Methodology and Implementation

### 4.1 Gateway enforcement and NAT

The firewall enables IP forwarding and programs iptables policies:

- INPUT/OUTPUT/FORWARD default policies with explicit allows and drops
- FORWARD policies to allow internal traffic and drop external sources
- Port filtering: allow server:22 only from admin-client’s IP; reject others
- DNAT rules: firewall:5000 → server:5000, firewall:22 → server:22
- MASQUERADE rules for internal/server egress as needed

This design forces all flows through the firewall for both directions (client→server and server→client), enabling consistent policy enforcement.

### 4.2 DDoS detection and MAC blocking

Two mechanisms cooperate:

- iptables limits at L3/L4: connection rate limits, SYN flood limits, concurrent connection caps, and ICMP rate limits
- Application-driven analytics at L7: `proxy.py` logs requests to the dashboard; `ddos_monitor.sh` evaluates recent request rates via the dashboard API. If a source exceeds thresholds, the script resolves the MAC (via ARP), inserts `BLOCKED_MACS` rules (LOG + DROP), and records the MAC in the dashboard’s in-memory set. The proxy consults this set to deny further L7 requests from the MAC as well.

### 4.3 Telemetry and dashboard

The dashboard maintains an in-memory ring buffer of recent requests and a set of blocked MACs. It exposes simple JSON endpoints for stats, logs, and blocked MACs, and renders a live HTML dashboard for visualization and demonstration.


## 5. Demonstration Scenarios (Results)

1) IP filtering
- Internal client successfully queries `GET /api/employees` via the firewall proxy.
- External attacker cannot reach the proxied API at firewall:5000; drops are visible in counters.

2) Port filtering (SSH)
- `admin-client` can connect to server:22 (validated via netcat or SSH test).
- Regular `client` and `internal-attacker` cannot reach server:22; attempts are logged as blocked.

3) Normal API operations
- Internal clients can list, create, update, and delete employees through the firewall; telemetry appears on the dashboard.

4) DDoS detection and mitigation
- The internal attacker launches a burst of requests (e.g., 10 threads × 100 requests).
- The dashboard shows an elevated rate and DDoS alerts; `ddos_monitor.sh` auto-inserts MAC-based drop rules.
- Subsequent requests from the attacker’s MAC are denied at both iptables (L2 match) and proxy (L7 consult) layers.

Empirical observation in the lab confirms the intended behavior across these scenarios.


## 6. Discussion

This container-based approach demonstrates that a practical, enforceable security perimeter can be created entirely within a Docker topology:

- By making the firewall the default gateway, policy becomes unavoidable for data paths.
- iptables remains a powerful, transparent enforcement engine for L3/L4 concerns.
- Light L7 assist (proxy + dashboard) adds visibility and enables rapid heuristics for DDoS-like behavior without replacing kernel enforcement.

Tradeoffs include the ephemeral nature of dashboard state and limits to absolute performance. In production, persistent logging, external metrics, and configuration management would complement this design.


## 7. Limitations

- Dashboard and block lists are in-memory; they reset on firewall restart.
- The DDoS detector uses basic thresholds and naive ARP-based MAC resolution (sufficient in a single L2 domain but not robust across routed domains).
- No TLS termination is included in this lab for simplicity.
- Static addressing is used for clarity; dynamic environments would require service discovery or automation.


## 8. Future Work

- Persist telemetry and blocked indicators (e.g., to a database or SIEM)
- Add authenticated, auditable admin endpoints for policy changes and unblocking
- Integrate metrics exporters (Prometheus) and dashboards (Grafana)
- Add TLS termination and mTLS for intra-network services
- Explore eBPF/XDP for higher-performance filtering where appropriate


## 9. Conclusion

The lab demonstrates an end-to-end containerized firewall that enforces core network and port policies, mitigates basic DDoS behavior, and provides live visibility—all without exposing the protected server directly to the host. It highlights how container-native constructs, combined with kernel-level controls, can deliver an effective and teachable security architecture.


## References

1) Cheswick, Bellovin, and Rubin. Firewalls and Internet Security (classic concepts).
2) Linux iptables documentation (Netfilter project).
3) Docker networking documentation (bridge networks and multi-network containers).
4) OWASP Cheat Sheets (rate limiting and denial-of-service considerations).
