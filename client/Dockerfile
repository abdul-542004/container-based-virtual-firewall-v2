FROM alpine:3.18

# Install essential networking tools
RUN apk add --no-cache \
    curl \
    iputils \
    iproute2 \
    netcat-openbsd \
    && rm -rf /var/cache/apk/*

# Create a simple test script
RUN mkdir -p /usr/local/bin && \
    echo '#!/bin/sh' > /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    echo 'echo "Client Container - Network Testing Tools"' >> /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "Available commands:"' >> /usr/local/bin/info && \
    echo 'echo "  curl http://firewall:5000/          - Access server through firewall"' >> /usr/local/bin/info && \
    echo 'echo "  curl http://firewall:5000/api/employees  - Get employees via firewall"' >> /usr/local/bin/info && \
    echo 'echo "  ping firewall                       - Ping firewall"' >> /usr/local/bin/info && \
    echo 'echo "  ping server                         - Ping server (blocked)"' >> /usr/local/bin/info && \
    echo 'echo "  ip addr                             - Show IP configuration"' >> /usr/local/bin/info && \
    echo 'echo "  ip route                            - Show routing table"' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "Container IP: $(hostname -i)"' >> /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    chmod +x /usr/local/bin/info

WORKDIR /root

CMD ["/bin/sh", "-c", "/usr/local/bin/info && tail -f /dev/null"]
