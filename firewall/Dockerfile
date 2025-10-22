FROM python:3.11-slim

WORKDIR /app

# Install required packages
RUN apt-get update && apt-get install -y \
    iptables \
    iproute2 \
    net-tools \
    iputils-ping \
    curl \
    tcpdump \
    conntrack \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Create necessary directories
RUN mkdir -p /app/logs /app/data

# Make scripts executable
RUN chmod +x /app/firewall.sh /app/ddos_monitor.sh /app/start.sh

# Expose ports
EXPOSE 8080 5000 22

# Start script
CMD ["/app/start.sh"]
