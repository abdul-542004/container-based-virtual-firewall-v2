FROM python:3.11-slim

WORKDIR /app

# Install required packages including SSH server
RUN apt-get update && apt-get install -y \
    openssh-server \
    net-tools \
    iputils-ping \
    iproute2 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir -p /var/run/sshd && \
    echo 'root:firewall123' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Create startup script
RUN echo '#!/bin/bash' > /app/start_server.sh && \
    echo 'service ssh start' >> /app/start_server.sh && \
    echo 'python /app/app.py' >> /app/start_server.sh && \
    chmod +x /app/start_server.sh

# Expose ports
EXPOSE 5000 22

# Run both SSH and the application
CMD ["/app/start_server.sh"]
