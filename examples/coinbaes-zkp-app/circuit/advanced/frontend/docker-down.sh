#!/bin/bash

# Coinbase ZKP Advanced Frontend - Docker Compose Down Script

echo "================================================"
echo "🛑 Stopping Coinbase ZKP Advanced Frontend"
echo "================================================"
echo ""

# Check if container exists
if ! docker-compose ps | grep -q 'coinbase-zkp-advanced-frontend'; then
    echo "ℹ️  No containers are running"
    exit 0
fi

# Stop and remove containers
echo "🛑 Stopping containers..."
docker-compose down

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Containers stopped and removed successfully"
    echo ""

    # Ask if user wants to remove images
    read -p "🗑️  Do you want to remove the Docker images? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing images..."
        docker-compose down --rmi all --volumes
        echo "✅ Images and volumes removed"
    fi
else
    echo ""
    echo "❌ Failed to stop containers"
    exit 1
fi

echo ""
echo "✅ Done!"
echo ""
