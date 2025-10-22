#!/bin/bash

echo "=========================================="
echo "Stopping Container-Based Virtual Firewall Lab"
echo "=========================================="
echo ""

# Stop all containers
echo "Stopping containers..."
docker-compose down

if [ $? -eq 0 ]; then
    echo "✓ Containers stopped successfully"
else
    echo "❌ Error stopping containers"
    exit 1
fi

echo ""
echo "Lab environment stopped."
echo ""
echo "To completely remove all data and images:"
echo "  docker-compose down -v --rmi all"
echo ""
echo "To restart the lab:"
echo "  ./start-lab.sh"
echo ""
