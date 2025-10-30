#!/bin/bash

# Coinbase ZKP Advanced Frontend - Docker Stop Script

echo "================================================"
echo "🛑 Stopping Coinbase ZKP Advanced Frontend"
echo "================================================"
echo ""

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q '^coinbase-zkp-advanced-frontend$'; then
    echo "ℹ️  Container 'coinbase-zkp-advanced-frontend' does not exist"
    exit 0
fi

# Stop container using docker-compose
echo "🛑 Stopping container..."
docker-compose down

if [ $? -eq 0 ]; then
    echo "✅ Container stopped and removed successfully"
else
    echo "❌ Failed to stop container"
    exit 1
fi

# Ask if user wants to remove the image
read -p "🗑️  Do you also want to remove the image? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose down --rmi all
    echo "✅ Image removed"
fi

echo ""
echo "✅ Done!"
