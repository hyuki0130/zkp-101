# Docker Deployment Guide

## Prerequisites

- Docker installed
- Docker Compose installed (optional, but recommended)

## Quick Start

### Option 1: Using Docker Compose (Recommended)

```bash
# Build and start the container in detached mode
docker-compose up -d --build

# Check container status
docker-compose ps

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```

### Option 2: Using Docker directly

```bash
# Build the image
docker build -t coinbase-zkp-advanced-frontend .

# Run the container in detached mode
docker run -d \
  --name coinbase-zkp-advanced-frontend \
  -p 8080:80 \
  --restart unless-stopped \
  coinbase-zkp-advanced-frontend

# Check container status
docker ps

# View logs
docker logs -f coinbase-zkp-advanced-frontend

# Stop and remove the container
docker stop coinbase-zkp-advanced-frontend
docker rm coinbase-zkp-advanced-frontend
```

## Access the Application

Once the container is running, access the application at:

```
http://localhost:8080
```

## Health Check

Check the health status:

```bash
curl http://localhost:8080/health
```

## Container Management

### View logs
```bash
# Docker Compose
docker-compose logs -f

# Docker
docker logs -f coinbase-zkp-advanced-frontend
```

### Restart container
```bash
# Docker Compose
docker-compose restart

# Docker
docker restart coinbase-zkp-advanced-frontend
```

### Stop container
```bash
# Docker Compose
docker-compose stop

# Docker
docker stop coinbase-zkp-advanced-frontend
```

### Start container
```bash
# Docker Compose
docker-compose start

# Docker
docker start coinbase-zkp-advanced-frontend
```

### Remove container and image
```bash
# Docker Compose
docker-compose down --rmi all

# Docker
docker stop coinbase-zkp-advanced-frontend
docker rm coinbase-zkp-advanced-frontend
docker rmi coinbase-zkp-advanced-frontend
```

## Configuration

### Port Mapping

Default port mapping is `8080:80`. To change the external port, modify:

**docker-compose.yml:**
```yaml
ports:
  - "YOUR_PORT:80"  # Change YOUR_PORT to desired port
```

**Docker command:**
```bash
docker run -d -p YOUR_PORT:80 ...
```

### Environment Variables

Currently no environment variables are required. If needed, add them in:

**docker-compose.yml:**
```yaml
environment:
  - VAR_NAME=value
```

**Docker command:**
```bash
docker run -d -e VAR_NAME=value ...
```

## Build Information

### Multi-stage Build

The Dockerfile uses a multi-stage build:

1. **Builder stage**: Installs dependencies and builds the application using Vite
2. **Production stage**: Serves the built files using nginx

### Image Size Optimization

- Uses Alpine Linux (minimal size)
- Multi-stage build (only production files included)
- Gzip compression enabled
- Static assets cached

## Troubleshooting

### Container won't start

Check logs:
```bash
docker-compose logs
# or
docker logs coinbase-zkp-advanced-frontend
```

### Port already in use

Change the port in docker-compose.yml or use a different port:
```bash
docker-compose down
# Edit docker-compose.yml ports section
docker-compose up -d
```

### Build fails

Ensure you're in the correct directory:
```bash
cd /path/to/coinbaes-zkp-app/circuit/advanced/frontend
```

Clean build:
```bash
docker-compose down --rmi all
docker-compose up -d --build
```

### Application not loading

1. Check if container is running:
   ```bash
   docker-compose ps
   ```

2. Check health endpoint:
   ```bash
   curl http://localhost:8080/health
   ```

3. Check nginx logs:
   ```bash
   docker-compose logs
   ```

## Production Deployment

For production deployment, consider:

1. **SSL/TLS**: Use a reverse proxy (e.g., nginx, Caddy) for HTTPS
2. **Domain**: Configure your domain DNS to point to the server
3. **Firewall**: Open port 80/443 and close unnecessary ports
4. **Monitoring**: Set up monitoring and alerting
5. **Backups**: Regular backups of configuration files

Example with Caddy reverse proxy:

```Caddyfile
your-domain.com {
    reverse_proxy localhost:8080
}
```

## Security Notes

- The application includes security headers (CSP, COOP, COEP)
- WASM and SharedArrayBuffer require specific headers (already configured)
- Static files are cached with appropriate headers
- Health check endpoint doesn't log access
