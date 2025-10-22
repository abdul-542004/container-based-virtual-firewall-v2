FROM alpine:3.18

# Install attack tools and utilities
RUN apk add --no-cache \
    curl \
    iputils \
    nmap \
    netcat-openbsd \
    tcpdump \
    iptables \
    iproute2 \
    && rm -rf /var/cache/apk/*

# Create scripts
RUN mkdir -p /usr/local/bin

# Create DDoS simulation script
RUN echo '#!/bin/sh' > /usr/local/bin/ddos_attack && \
    echo 'echo "DDoS Simulation Script"' >> /usr/local/bin/ddos_attack && \
    echo 'echo "Usage: ddos_attack <url> [threads] [requests_per_thread]"' >> /usr/local/bin/ddos_attack && \
    echo 'echo "Example: ddos_attack http://firewall:5000/ 5 20"' >> /usr/local/bin/ddos_attack && \
    chmod +x /usr/local/bin/ddos_attack

# Create port scanning script
RUN echo '#!/bin/sh' > /usr/local/bin/port_scan && \
    echo 'echo "==========================================="' >> /usr/local/bin/port_scan && \
    echo 'echo "Port Scanning Target: $1"' >> /usr/local/bin/port_scan && \
    echo 'echo "==========================================="' >> /usr/local/bin/port_scan && \
    echo 'if [ -z "$1" ]; then' >> /usr/local/bin/port_scan && \
    echo '    echo "Usage: port_scan <target_ip>"' >> /usr/local/bin/port_scan && \
    echo '    exit 1' >> /usr/local/bin/port_scan && \
    echo 'fi' >> /usr/local/bin/port_scan && \
    echo 'nmap -p 1-1000 $1' >> /usr/local/bin/port_scan && \
    chmod +x /usr/local/bin/port_scan

# Create info script
RUN echo '#!/bin/sh' > /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    echo 'echo "Attacker Container - Security Testing Tools"' >> /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "Available attack commands:"' >> /usr/local/bin/info && \
    echo 'echo "  ddos_attack http://firewall:5000/ 10 50    - DDoS simulation"' >> /usr/local/bin/info && \
    echo 'echo "  port_scan 172.20.0.3                       - Port scan server"' >> /usr/local/bin/info && \
    echo 'echo "  nmap -sS -p 5000 172.20.0.3                - SYN scan (alternative)"' >> /usr/local/bin/info && \
    echo 'echo "  curl http://firewall:5000/                 - Normal request"' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "Network information:"' >> /usr/local/bin/info && \
    echo 'echo "  ip addr                                    - Show IP"' >> /usr/local/bin/info && \
    echo 'echo "  ip route                                   - Show routes"' >> /usr/local/bin/info && \
    echo 'echo "  ping firewall                              - Test connectivity"' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "Container IP: $(hostname -i)"' >> /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    chmod +x /usr/local/bin/info

WORKDIR /root

CMD ["/bin/sh", "-c", "/usr/local/bin/info && tail -f /dev/null"]
