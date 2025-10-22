#!/bin/bash

echo "=========================================="
echo "Container-Based Virtual Firewall Lab"
echo "Quick Start Script"
echo "=========================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running"
    echo "Please start Docker and try again"
    exit 1
fi

echo "✓ Docker is running"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Error: docker-compose is not installed"
    exit 1
fi

echo "✓ docker-compose is available"
echo ""

# Make scripts executable
echo "Making scripts executable..."
chmod +x firewall/start.sh
chmod +x firewall/firewall.sh
echo "✓ Scripts are executable"
echo ""

# Build containers
echo "Building containers (this may take a few minutes)..."
docker-compose build

if [ $? -ne 0 ]; then
    echo "❌ Error building containers"
    exit 1
fi

echo "✓ Containers built successfully"
echo ""

# Start containers
echo "Starting containers..."
docker-compose up -d

if [ $? -ne 0 ]; then
    echo "❌ Error starting containers"
    exit 1
fi

echo "✓ Containers started successfully"
echo ""

# Wait for services to be ready
echo "Waiting for services to initialize..."
sleep 10

# Check container status
echo ""
echo "Container Status:"
docker-compose ps
echo ""

# Display access information
echo "=========================================="
echo "✓ Lab Environment Ready!"
echo "=========================================="
echo ""
echo "Access Points:"
echo "  🌐 Firewall Dashboard:    http://localhost:8080"
echo "  🏢 Employee Management:   http://localhost:5000"
echo "  📊 Server Direct Access:  http://localhost:5001"
echo ""
echo "Container Access:"
echo "  docker exec -it client bash"
echo "  docker exec -it firewall bash"
echo "  docker exec -it server bash"
echo "  docker exec -it attacker bash"
echo ""
echo "Quick Tests:"
echo "  # From client container"
echo "  docker exec -it client curl http://firewall:5000/"
echo ""
echo "  # Launch DDoS attack"
echo "  docker exec -it attacker ddos_attack http://firewall:5000/ 5 20"
echo ""
echo "View Logs:"
echo "  docker logs -f firewall"
echo "  docker logs -f server"
echo ""
echo "Stop Environment:"
echo "  docker-compose down"
echo ""
echo "=========================================="
echo "Happy Testing! 🛡️"
echo "=========================================="
