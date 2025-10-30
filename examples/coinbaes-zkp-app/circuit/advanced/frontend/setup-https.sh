#!/bin/bash

# Setup self-signed SSL certificate for testing

echo "================================================"
echo "🔐 Setting up HTTPS for Coinbase ZKP Frontend"
echo "================================================"
echo ""

# Create certificates directory
mkdir -p certs

# Generate self-signed certificate
echo "📜 Generating self-signed SSL certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout certs/nginx-selfsigned.key \
    -out certs/nginx-selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

if [ $? -eq 0 ]; then
    echo "✅ Certificate generated successfully"
    echo ""
    echo "📁 Certificate files:"
    echo "   - certs/nginx-selfsigned.key"
    echo "   - certs/nginx-selfsigned.crt"
    echo ""
    echo "⚠️  Note: This is a self-signed certificate for testing only."
    echo "   Browsers will show a security warning."
    echo ""
    echo "🔧 Next steps:"
    echo "   1. Update docker-compose.yml to mount certificates"
    echo "   2. Update nginx.conf to use HTTPS"
    echo "   3. Rebuild: docker-compose up -d --build"
else
    echo "❌ Failed to generate certificate"
    exit 1
fi
