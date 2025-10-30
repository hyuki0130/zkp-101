#!/bin/bash

# Coinbase ZKP Advanced Frontend - Docker Compose HTTPS Start Script

set -e

echo "================================================"
echo "🔐 Starting Coinbase ZKP Frontend with HTTPS"
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

# Check if certificates exist
if [ ! -f "certs/nginx-selfsigned.crt" ] || [ ! -f "certs/nginx-selfsigned.key" ]; then
    echo "📜 SSL certificates not found. Generating..."
    ./setup-https.sh
    if [ $? -ne 0 ]; then
        echo "❌ Failed to generate certificates"
        exit 1
    fi
    echo ""
fi

echo "✅ SSL certificates found"
echo ""

# Build and start
echo "🔨 Building and starting containers with HTTPS..."
docker-compose -f docker-compose-https.yml up -d --build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Container started successfully!"
    echo ""

    # Wait for container to be ready
    sleep 2

    # Show status
    echo "📊 Container Status:"
    docker-compose -f docker-compose-https.yml ps
    echo ""

    echo "================================================"
    echo "✅ HTTPS Deployment Complete!"
    echo "================================================"
    echo ""
    echo "📍 Application URLs:"
    echo "   - HTTPS: https://localhost (or https://YOUR_IP)"
    echo "   - HTTP:  http://localhost (redirects to HTTPS)"
    echo ""
    echo "⚠️  Note: Self-signed certificate warning is normal"
    echo "   Click 'Advanced' → 'Proceed to localhost (unsafe)' in browser"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   View logs:     docker-compose -f docker-compose-https.yml logs -f"
    echo "   Stop:          docker-compose -f docker-compose-https.yml down"
    echo "   Restart:       docker-compose -f docker-compose-https.yml restart"
    echo ""
    echo "✨ Now SharedArrayBuffer (multithreading) should work!"
    echo "   Proof generation should be ~2x faster"
    echo ""
else
    echo ""
    echo "❌ Failed to start container!"
    exit 1
fi
