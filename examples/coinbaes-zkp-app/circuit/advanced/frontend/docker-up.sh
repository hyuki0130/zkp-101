#!/bin/bash

# Coinbase ZKP Advanced Frontend - Docker Compose Up Script

set -e

echo "================================================"
echo "🚀 Starting Coinbase ZKP Advanced Frontend"
echo "================================================"
echo ""

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running."
    echo "   Please start Docker daemon first:"
    echo "   - macOS: open -a 'Rancher Desktop'"
    echo "   - Linux: sudo systemctl start docker"
    exit 1
fi

echo "✅ Docker is running"
echo ""

# Build and start
echo "🔨 Building and starting containers..."
docker-compose up -d --build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Container started successfully!"
    echo ""

    # Wait for container to be ready
    sleep 2

    # Show status
    echo "📊 Container Status:"
    docker-compose ps
    echo ""

    echo "================================================"
    echo "✅ Deployment Complete!"
    echo "================================================"
    echo ""
    echo "📍 Application URL: http://localhost:8080"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   View logs:     docker-compose logs -f"
    echo "   Stop:          docker-compose down"
    echo "   Restart:       docker-compose restart"
    echo ""
    echo "🌐 Open in browser: open http://localhost:8080"
    echo ""
else
    echo ""
    echo "❌ Failed to start container!"
    exit 1
fi
