#!/bin/bash
# Simple Traefik redeploy script for server execution
# Run this directly on the Docker Swarm manager node

set -euo pipefail

echo "🔄 Redeploying Traefik with DNS-01 Challenge"
echo "==========================================="

# Check Docker access
if ! docker node ls >/dev/null 2>&1; then
    echo "❌ Cannot access Docker Swarm. Please run as user with Docker permissions"
    exit 1
fi

# Check if stack file exists
STACK_FILE="/opt/promata/stacks/dev-complete.yml"
if [ ! -f "$STACK_FILE" ]; then
    echo "❌ Stack file not found: $STACK_FILE"
    echo "Please ensure Ansible has deployed the stack files"
    exit 1
fi

echo "✅ Docker Swarm access confirmed"
echo "✅ Stack file found"

# Remove existing stack
echo "Removing existing Traefik stack..."
docker stack rm promata-dev 2>/dev/null || true

# Wait for cleanup
echo "Waiting for cleanup..."
sleep 10

# Deploy new stack
echo "Deploying updated Traefik stack..."
docker stack deploy -c $STACK_FILE promata-dev

# Wait for deployment
echo "Waiting for deployment..."
sleep 30

# Check status
echo "Checking Traefik status..."
docker service ls | grep traefik

if docker service ps promata-dev_traefik | grep -q "Running"; then
    echo "✅ Traefik redeployed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Check logs: docker service logs promata-dev_traefik"
    echo "2. Test HTTPS: https://traefik.promata.com.br"
    echo "3. Test services: https://promata.com.br"
else
    echo "❌ Deployment failed"
    echo "Check logs: docker service logs promata-dev_traefik"
    exit 1
fi
