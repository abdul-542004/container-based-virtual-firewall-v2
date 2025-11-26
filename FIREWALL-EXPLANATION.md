# Firewall Configuration Script - Detailed Explanation

This document provides a comprehensive line-by-line explanation of the `firewall.sh` script, including all iptables concepts, flags, chains, rules, and tables.

## Table of Contents
- [Overview](#overview)
- [Network Configuration](#network-configuration)
- [IPTables Basics](#iptables-basics)
- [Script Breakdown](#script-breakdown)
- [Rule Details](#rule-details)

---

## Overview

The `firewall.sh` script sets up a comprehensive Linux firewall using iptables. It implements:
- IP filtering
- Port filtering
- DDoS protection
- MAC address filtering
- Network Address Translation (NAT)
- Logging

---

## Network Configuration

### Lines 1-23: Initial Setup and Network Variables

```bash
#!/bin/bash
```
**Shebang**: Specifies that this script should be executed using the Bash shell.

```bash
INTERNAL_NETWORK="172.20.0.0/16"
SERVER_NETWORK="${SERVER_NETWORK:-172.30.0.0/16}"
EXTERNAL_NETWORK="${EXTERNAL_NETWORK:-172.21.0.0/16}"
SERVER_IP="${SERVER_IP:-172.30.0.3}"
ADMIN_CLIENT_IP="${ADMIN_CLIENT_IP:-172.20.0.5}"
FIREWALL_IP="172.20.0.2"
```

**Network Variables**:
- `INTERNAL_NETWORK`: Trusted internal network (172.20.0.0/16 = 65,536 addresses)
- `SERVER_NETWORK`: Network where the server resides
- `EXTERNAL_NETWORK`: Untrusted external network
- `SERVER_IP`: IP address of the protected server
- `ADMIN_CLIENT_IP`: IP address of the administrator's client
- `FIREWALL_IP`: IP address of the firewall itself

**Syntax**: `${VAR:-default}` means "use environment variable VAR, or use 'default' if VAR is not set"

---

## IPTables Basics

### What is iptables?

**iptables** is a Linux firewall utility that controls network traffic by filtering packets based on rules organized in:
- **Tables**: Different categories of packet processing
- **Chains**: Lists of rules that packets traverse
- **Rules**: Individual conditions and actions

### Tables

1. **filter** (default): For general packet filtering
2. **nat**: For Network Address Translation
3. **mangle**: For specialized packet alteration

### Built-in Chains

#### Filter Table Chains:
- **INPUT**: Packets destined for the firewall itself
- **FORWARD**: Packets passing through the firewall to another destination
- **OUTPUT**: Packets originating from the firewall

#### NAT Table Chains:
- **PREROUTING**: Alter packets before routing decisions
- **POSTROUTING**: Alter packets after routing decisions
- **OUTPUT**: NAT for locally generated packets

### Common Targets (Actions)

- **ACCEPT**: Allow the packet
- **DROP**: Silently discard the packet
- **REJECT**: Discard and send error response
- **LOG**: Log the packet (doesn't stop processing)
- **MASQUERADE**: Dynamic source NAT
- **DNAT**: Destination NAT (port forwarding)

---

## Script Breakdown

### Lines 25-27: Enable IP Forwarding

```bash
echo 1 > /proc/sys/net/ipv4/ip_forward
```

**Purpose**: Enables the Linux kernel to forward packets between network interfaces.
- Required for the firewall to act as a router
- Without this, packets cannot pass through the firewall
- `0` = disabled, `1` = enabled

---

### Lines 29-35: Flush Existing Rules

```bash
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
```

**Flags**:
- `-F` (--flush): Delete all rules in all chains
- `-X` (--delete-chain): Delete user-defined chains
- `-t` (--table): Specify which table to operate on

**Purpose**: Clean slate - removes all existing firewall rules before applying new ones.

**Tables Cleared**:
1. `filter` (default table - when `-t` is omitted)
2. `nat` (Network Address Translation table)
3. `mangle` (Packet alteration table)

---

### Lines 37-41: Set Default Policies

```bash
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
```

**Flag**:
- `-P` (--policy): Set the default policy for a chain

**Policies Set**:
1. `INPUT ACCEPT`: By default, accept packets destined for the firewall
2. `FORWARD DROP`: By default, drop packets passing through (security-first approach)
3. `OUTPUT ACCEPT`: Allow packets originating from the firewall

**Security Note**: FORWARD is set to DROP, so only explicitly allowed traffic can pass through.

---

### Lines 43-46: Block External Network INPUT

```bash
iptables -A INPUT -s $EXTERNAL_NETWORK -p tcp -m multiport --dports 8080,5000 -j LOG --log-prefix "FW-BLOCK-EXT-INPUT: " --log-level 4
iptables -A INPUT -s $EXTERNAL_NETWORK -p tcp -m multiport --dports 8080,5000 -j REJECT --reject-with tcp-reset
```

**Flags**:
- `-A` (--append): Add rule to end of chain
- `-s` (--source): Source IP address/network
- `-p` (--protocol): Protocol (tcp, udp, icmp, all)
- `-m` (--match): Load extension module
- `--dports`: Destination ports (requires multiport module)
- `-j` (--jump): Target/action to perform
- `--log-prefix`: Add prefix to log messages
- `--log-level`: Syslog level (4 = warning)
- `--reject-with`: Type of REJECT message to send

**Purpose**: 
1. First rule: LOG attempts from external network to access dashboard (8080) and proxy (5000)
2. Second rule: REJECT these connections with TCP reset

**Module**: `multiport` allows matching multiple ports in one rule (more efficient than multiple rules)

**Reject Type**: `tcp-reset` sends a TCP RST packet, cleanly closing the connection attempt

---

### Lines 48-51: Allow Loopback

```bash
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
```

**Flags**:
- `-i` (--in-interface): Input network interface
- `-o` (--out-interface): Output network interface

**Purpose**: Allow all traffic on the loopback interface (lo)
- Loopback (127.0.0.1) is used for local inter-process communication
- Essential for many applications to function properly

---

### Lines 53-56: Allow Established Connections

```bash
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```

**Module**: `state` - Connection tracking module

**Connection States**:
- **ESTABLISHED**: Packet belongs to an existing connection
- **RELATED**: Packet starts a new connection but is related to an existing one (e.g., FTP data connection)
- **NEW**: Packet starts a new connection (not matched here)
- **INVALID**: Packet doesn't match any known connection

**Purpose**: Allow return traffic for connections that were initiated and approved
- Enables two-way communication
- More efficient than matching every response packet

---

## Rule Details

### Section 1: IP Filtering (Lines 58-78)

#### Allow Internal Network Traffic

```bash
iptables -A FORWARD -s $INTERNAL_NETWORK -d $INTERNAL_NETWORK -j ACCEPT
```

**Flags**:
- `-d` (--destination): Destination IP address/network

**Purpose**: Allow all traffic between hosts in the internal network
- Internal hosts can communicate freely with each other

---

#### Block External Network

```bash
iptables -A FORWARD -s $EXTERNAL_NETWORK -j LOG --log-prefix "FW-BLOCK-EXTERNAL: " --log-level 4
iptables -A FORWARD -s $EXTERNAL_NETWORK -j DROP
```

**Purpose**: 
1. Log all packets from external network
2. Drop all packets from external network in FORWARD chain

**Security**: Two-layer defense - external network blocked in both INPUT and FORWARD chains

---

#### Allow Dashboard and Proxy Access

```bash
iptables -A INPUT -s $INTERNAL_NETWORK -p tcp -m multiport --dports 8080,5000 -j ACCEPT
iptables -A INPUT -s $SERVER_NETWORK -p tcp -m multiport --dports 8080,5000 -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 8080,5000 -m conntrack --ctstate NEW -s 172.17.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 8080,5000 -m conntrack --ctstate NEW -s 172.18.0.0/16 -j ACCEPT
```

**Module**: `conntrack` - Enhanced connection tracking

**Flag**:
- `--ctstate`: Connection tracking state (similar to `--state`)

**Purpose**: Allow access to:
- Port 8080: Firewall dashboard
- Port 5000: Proxy service

**Allowed Sources**:
1. Internal network (172.20.0.0/16)
2. Server network (172.30.0.0/16)
3. Docker bridge networks (172.17.0.0/16, 172.18.0.0/16)

**NEW State**: Only NEW connections need explicit rules; ESTABLISHED/RELATED already allowed

---

### Section 2: Port Filtering (Lines 80-98)

#### Allow SSH from Admin Only

```bash
iptables -A FORWARD -p tcp -s $ADMIN_CLIENT_IP -d $SERVER_IP --dport 22 -j ACCEPT
```

**Flag**:
- `--dport` (--destination-port): Destination port

**Purpose**: Allow SSH (port 22) only from admin client to server
- Implements principle of least privilege
- Reduces attack surface

---

#### Block SSH from Others

```bash
iptables -A FORWARD -p tcp ! -s $ADMIN_CLIENT_IP -d $SERVER_IP --dport 22 -j LOG --log-prefix "FW-BLOCK-SSH: " --log-level 4
iptables -A FORWARD -p tcp ! -s $ADMIN_CLIENT_IP -d $SERVER_IP --dport 22 -j REJECT --reject-with tcp-reset
```

**Flag**:
- `!` (negation operator): Matches everything EXCEPT the specified condition

**Purpose**: 
1. Log SSH attempts from non-admin sources
2. Reject them with TCP reset

**Security**: Explicit deny rule with logging for security monitoring

---

#### Allow HTTP/HTTPS

```bash
iptables -A FORWARD -p tcp -s $INTERNAL_NETWORK -m multiport --dports 80,443,5000 -j ACCEPT
```

**Ports**:
- 80: HTTP
- 443: HTTPS
- 5000: Application proxy

**Purpose**: Allow web traffic from internal network

---

### Section 3: DDoS Protection (Lines 100-124)

#### Connection Rate Limiting

```bash
iptables -A FORWARD -p tcp --syn -m recent --name conn_rate --set
iptables -A FORWARD -p tcp --syn -m recent --name conn_rate --update --seconds 60 --hitcount 21 -j LOG --log-prefix "FW-DDOS-RATE: " --log-level 4
iptables -A FORWARD -p tcp --syn -m recent --name conn_rate --update --seconds 60 --hitcount 21 -j DROP
```

**Module**: `recent` - Track IP addresses

**Flag**:
- `--syn`: Match TCP SYN packets (connection initiation)

**Recent Module Options**:
- `--name`: Name of the tracking list
- `--set`: Add source IP to the list
- `--update`: Update last-seen time and check conditions
- `--seconds`: Time window
- `--hitcount`: Number of packets threshold

**Logic**:
1. First rule: Track all SYN packets by source IP
2. Second rule: If same IP sends 21+ SYN packets in 60 seconds, log it
3. Third rule: Drop the packet

**Purpose**: Limit new connections to 20 per minute per IP address
- Prevents connection exhaustion attacks
- Legitimate users rarely exceed this limit

---

#### SYN Flood Protection

```bash
iptables -A FORWARD -p tcp --syn -m limit --limit 15/s --limit-burst 30 -j ACCEPT
iptables -A FORWARD -p tcp --syn -j LOG --log-prefix "FW-DDOS-SYN: " --log-level 4
iptables -A FORWARD -p tcp --syn -j DROP
```

**Module**: `limit` - Rate limiting

**Limit Module Options**:
- `--limit`: Average rate (per second, minute, hour, day)
- `--limit-burst`: Maximum burst before limiting kicks in

**Logic**:
1. Accept up to 15 SYN packets/second
2. Allow burst of 30 packets (handles legitimate traffic spikes)
3. Log excessive SYN packets
4. Drop excessive SYN packets

**Purpose**: Protect against SYN flood attacks
- SYN flood: Attacker sends many SYN packets without completing handshake
- Exhausts server's connection queue

---

#### Connection Limit per IP

```bash
iptables -A FORWARD -p tcp --syn -m connlimit --connlimit-above 15 --connlimit-mask 32 -j LOG --log-prefix "FW-DDOS-CONNLIMIT: " --log-level 4
iptables -A FORWARD -p tcp --syn -m connlimit --connlimit-above 15 --connlimit-mask 32 -j REJECT --reject-with tcp-reset
```

**Module**: `connlimit` - Limit concurrent connections

**Connlimit Module Options**:
- `--connlimit-above`: Maximum number of connections
- `--connlimit-mask`: Network mask for grouping IPs (32 = individual IP)

**Purpose**: Limit each IP to 15 concurrent connections
- Prevents single IP from consuming all connection slots
- Mask 32 = per IP; mask 24 = per /24 subnet

---

#### ICMP Flood Protection

```bash
iptables -A FORWARD -p icmp --icmp-type echo-request -m limit --limit 2/s --limit-burst 5 -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-request -j LOG --log-prefix "FW-DDOS-ICMP: " --log-level 4
iptables -A FORWARD -p icmp --icmp-type echo-request -j DROP
```

**Flag**:
- `--icmp-type`: Type of ICMP message

**ICMP Types**:
- `echo-request`: Ping request (ICMP type 8)

**Purpose**: Rate limit ping requests
- Allow 2 pings per second with burst of 5
- Prevents ping flood (ICMP flood) attacks
- Still allows legitimate ping for diagnostics

---

### Section 4: MAC Filtering (Lines 126-142)

```bash
iptables -N BLOCKED_MACS 2>/dev/null || iptables -F BLOCKED_MACS
```

**Flag**:
- `-N` (--new-chain): Create new user-defined chain

**Shell Operators**:
- `2>/dev/null`: Redirect stderr to null (suppress error if chain exists)
- `||`: Logical OR - if first command fails, run second command

**Purpose**: Create custom chain named BLOCKED_MACS
- If chain already exists (error), flush it instead

---

```bash
iptables -A FORWARD -j BLOCKED_MACS
iptables -A INPUT -j BLOCKED_MACS
```

**Purpose**: Jump to BLOCKED_MACS chain for inspection
- Packets traverse BLOCKED_MACS chain before continuing
- MACs added to this chain dynamically via API
- If no match, packet returns to original chain

**Dynamic Filtering**: Rules added/removed at runtime without restarting firewall

---

### Section 5: NAT Configuration (Lines 144-163)

#### Enable Masquerading for Internal Network

```bash
iptables -t nat -A POSTROUTING -s $INTERNAL_NETWORK -j MASQUERADE
```

**Table**: `nat` - Network Address Translation table

**Chain**: `POSTROUTING` - Modify packets after routing decision

**Target**: `MASQUERADE` - Dynamic source NAT

**Purpose**: Allow internal network to access internet
- Rewrites source IP to firewall's external IP
- Like home router NAT
- Dynamic because it adapts to changing firewall IP

**How it works**:
1. Internal host (172.20.0.10) sends packet to internet
2. Firewall changes source IP to its own external IP
3. Internet responds to firewall
4. Firewall translates back to 172.20.0.10

---

#### Port Forwarding - HTTP

```bash
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 5000 -j DNAT --to-destination $SERVER_IP:5000
```

**Chain**: `PREROUTING` - Modify packets before routing

**Target**: `DNAT` - Destination NAT

**Flag**:
- `--to-destination`: New destination IP:port

**Purpose**: Forward external port 5000 to server's port 5000
- Incoming traffic to firewall:5000 → server:5000
- Allows external access to internal server

---

#### Port Forwarding - SSH

```bash
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 22 -j DNAT --to-destination $SERVER_IP:22
```

**Purpose**: Forward SSH traffic to server
- Combined with filter rules, only admin can use this
- NAT forwards traffic; filter rules control access

---

#### Masquerade Server Network

```bash
iptables -t nat -A POSTROUTING -s $SERVER_NETWORK -j MASQUERADE
```

**Purpose**: Enable NAT for server network
- Server can access external resources
- Source IP is rewritten to firewall's IP

---

### Section 6: Logging (Lines 165-174)

```bash
iptables -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "FW-DROP: " --log-level 4
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "FW-INPUT-DROP: " --log-level 4
```

**Purpose**: Log dropped packets (those not matched by earlier rules)
- Rate limited to 5 per minute to prevent log flooding
- Logs go to /var/log/kern.log or /var/log/messages

**Why Rate Limit**: During attacks, thousands of packets might be dropped per second
- Logging all would fill disk and slow system
- 5/min provides samples for analysis

---

### Lines 176-206: Summary and Keep-Alive

```bash
tail -f /dev/null
```

**Purpose**: Keep script running indefinitely
- Firewall rules persist while script is running
- `-f`: Follow file (wait for data)
- `/dev/null`: Never produces data
- Result: Script waits forever, keeping container alive

---

## IPTables Packet Flow

### Incoming Packet Destined for Firewall:
```
Network → PREROUTING (nat) → INPUT (filter) → Local Process
```

### Packet Being Forwarded Through Firewall:
```
Network → PREROUTING (nat) → FORWARD (filter) → POSTROUTING (nat) → Network
```

### Packet Originating from Firewall:
```
Local Process → OUTPUT (filter, nat) → POSTROUTING (nat) → Network
```

---

## Rule Processing Order

Rules are processed **top-to-bottom** in each chain:
1. First matching rule is applied (unless target is LOG)
2. If no rule matches, default policy applies
3. LOG target doesn't stop processing - packet continues

**Example**:
```bash
iptables -A INPUT -p tcp --dport 80 -j LOG    # Logs packet, continues
iptables -A INPUT -p tcp --dport 80 -j ACCEPT # Then accepts it
```

---

## Important Concepts

### Connection Tracking

Linux kernel tracks connections in a state table:
- Allows stateful firewall (context-aware)
- More efficient than checking every packet
- Enables "allow return traffic" rules

### Match Extensions (`-m`)

Modules that provide additional matching criteria:
- `state/conntrack`: Connection tracking
- `recent`: Track IP addresses over time
- `limit`: Rate limiting
- `multiport`: Match multiple ports
- `connlimit`: Limit connections per IP

### Chains

**Built-in Chains**: Created by iptables (INPUT, FORWARD, OUTPUT)

**User-defined Chains**: Created by administrator (BLOCKED_MACS)
- Organize rules logically
- Reusable rule sets
- More efficient processing

### Tables

**Filter Table** (default):
- General packet filtering
- Chains: INPUT, FORWARD, OUTPUT

**NAT Table**:
- Modify IP addresses/ports
- Chains: PREROUTING, POSTROUTING, OUTPUT

**Mangle Table**:
- Modify packet headers (TTL, TOS, etc.)
- Less commonly used

---

## Security Architecture

This firewall implements **defense in depth**:

1. **Network Segmentation**: Separate internal, external, and server networks
2. **Least Privilege**: Only necessary ports/IPs allowed
3. **Rate Limiting**: Multiple DDoS protection mechanisms
4. **Logging**: Audit trail for security analysis
5. **Stateful Inspection**: Connection tracking for context
6. **Dynamic Filtering**: MAC addresses blocked in real-time

---

## Performance Considerations

### Rule Ordering

Rules are checked sequentially, so:
- Put frequently matched rules first
- Put ESTABLISHED/RELATED rules early (most traffic)
- Rate limiting prevents excessive rule checking

### Connection Tracking

- Memory overhead for state table
- Scales to thousands of connections
- Can be tuned via `/proc/sys/net/netfilter/`

### Logging

- Rate limited to prevent log flooding
- I/O overhead when logging
- Use judiciously in production

---

## Common Flags Reference

| Flag | Long Form | Description |
|------|-----------|-------------|
| `-A` | `--append` | Add rule to end of chain |
| `-I` | `--insert` | Insert rule at position |
| `-D` | `--delete` | Delete rule |
| `-F` | `--flush` | Delete all rules |
| `-L` | `--list` | List rules |
| `-N` | `--new-chain` | Create chain |
| `-X` | `--delete-chain` | Delete chain |
| `-P` | `--policy` | Set default policy |
| `-t` | `--table` | Specify table |
| `-p` | `--protocol` | Protocol (tcp/udp/icmp) |
| `-s` | `--source` | Source IP/network |
| `-d` | `--destination` | Destination IP/network |
| `-i` | `--in-interface` | Input interface |
| `-o` | `--out-interface` | Output interface |
| `-j` | `--jump` | Target/action |
| `-m` | `--match` | Match extension |
| `!` | (negation) | NOT operator |

---

## Debugging Commands

```bash
# View all rules
iptables -L -v -n

# View NAT rules
iptables -t nat -L -v -n

# View with line numbers
iptables -L --line-numbers

# Show packet/byte counters
iptables -L -v

# Watch real-time matches
watch -n 1 'iptables -L -v -n'

# View kernel logs
tail -f /var/log/kern.log | grep "FW-"
```

---

## Summary

This firewall script creates a comprehensive security solution:

✓ **IP Filtering**: Block untrusted networks
✓ **Port Filtering**: Restrict service access
✓ **DDoS Protection**: Multiple rate limiting mechanisms
✓ **MAC Filtering**: Dynamic MAC address blocking
✓ **NAT**: Enable internal→external and port forwarding
✓ **Logging**: Security monitoring and forensics

The configuration is optimized for a containerized environment with separate networks for internal clients, external threats, and protected servers.

---

**Created**: November 26, 2025
**Script Version**: firewall.sh
**Author**: Container-based Virtual Firewall Project
