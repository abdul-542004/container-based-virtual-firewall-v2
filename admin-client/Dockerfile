FROM alpine:3.18

# Install essential tools including SSH client
RUN apk add --no-cache \
    openssh-client \
    curl \
    iputils \
    iproute2 \
    netcat-openbsd \
    bash \
    && rm -rf /var/cache/apk/*

# Create info script
RUN mkdir -p /usr/local/bin && \
    echo '#!/bin/bash' > /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    echo 'echo "Admin Client Container"' >> /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "This is the admin client with SSH privileges."' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "Available commands:"' >> /usr/local/bin/info && \
    echo 'echo "  curl http://firewall:5000/api/employees  - Access API via firewall"' >> /usr/local/bin/info && \
    echo 'echo "  ssh root@server                          - SSH to server (password: firewall123)"' >> /usr/local/bin/info && \
    echo 'echo "  ssh root@172.30.0.3                      - SSH to server by IP"' >> /usr/local/bin/info && \
    echo 'echo "  ping firewall                            - Test connectivity"' >> /usr/local/bin/info && \
    echo 'echo "  ip addr                                  - Show IP configuration"' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "Container IP: $(hostname -i)"' >> /usr/local/bin/info && \
    echo 'echo "MAC Address: $(ip link show eth0 | grep link/ether | awk '\''{print $2}'\'')"' >> /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    chmod +x /usr/local/bin/info

WORKDIR /root

CMD ["/bin/bash", "-c", "/usr/local/bin/info && tail -f /dev/null"]
