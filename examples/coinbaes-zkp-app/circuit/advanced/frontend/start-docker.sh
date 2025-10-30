#!/bin/bash

# Coinbase ZKP Advanced Frontend - Docker Quick Start Script

set -e

echo "================================================"
echo "🐳 Coinbase ZKP Advanced Frontend - Docker Deploy"
echo "================================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running."
    echo "   Please start Docker daemon:"
    echo "   - macOS: open -a Docker"
    echo "   - Linux: sudo systemctl start docker"
    exit 1
fi

echo "✅ Docker is installed and running"
echo ""

# Stop and remove existing container if exists
if docker ps -a --format '{{.Names}}' | grep -q '^coinbase-zkp-advanced-frontend$'; then
    echo "🛑 Stopping existing container..."
    docker-compose down 2>/dev/null || true
    echo "✅ Existing container removed"
    echo ""
fi

# Build and start using docker-compose
echo "🔨 Building Docker image..."
docker-compose build

if [ $? -ne 0 ]; then
    echo "❌ Docker build failed!"
    exit 1
fi

echo "✅ Docker image built successfully"
echo ""

# Start container in detached mode
echo "🚀 Starting container in background..."
docker-compose up -d

if [ $? -ne 0 ]; then
    echo "❌ Failed to start container!"
    exit 1
fi

echo "✅ Container started successfully"
echo ""

# Wait a moment for container to start
sleep 2

# Check container status
echo "📊 Container Status:"
docker ps --filter name=coinbase-zkp-advanced-frontend --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Health check
echo "🏥 Running health check..."
sleep 3
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "✅ Health check passed!"
else
    echo "⚠️  Health check failed. Container may still be starting..."
fi

echo ""
echo "================================================"
echo "✅ Deployment Complete!"
echo "================================================"
echo ""
echo "📍 Application URL: http://localhost:8080"
echo ""
echo "🔧 Useful Commands:"
echo "   View logs:     docker logs -f coinbase-zkp-advanced-frontend"
echo "   Stop:          docker stop coinbase-zkp-advanced-frontend"
echo "   Start:         docker start coinbase-zkp-advanced-frontend"
echo "   Remove:        docker rm -f coinbase-zkp-advanced-frontend"
echo "   Shell access:  docker exec -it coinbase-zkp-advanced-frontend sh"
echo ""
echo "🌐 Open in browser: open http://localhost:8080"
echo ""
