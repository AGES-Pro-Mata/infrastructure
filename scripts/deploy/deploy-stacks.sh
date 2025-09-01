#!/bin/bash
# Deploy Stacks Script - Pro-Mata Infrastructure

set -e

ENV=${1:-dev}
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STACK_DIR="$PROJECT_ROOT/docker/stacks"
ENV_DIR="$PROJECT_ROOT/environments/$ENV"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"; exit 1; }

# Load environment variables
if [[ -f "$ENV_DIR/.env.$ENV" ]]; then
    source "$ENV_DIR/.env.$ENV"
    log "Loaded environment: $ENV"
else
    error "Environment file not found: $ENV_DIR/.env.$ENV"
fi

# Required variables check
required_vars=("DOMAIN_NAME" "POSTGRES_PASSWORD" "CLOUDFLARE_API_TOKEN")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        error "Required variable $var is not set"
    fi
done

# Create Docker networks
create_networks() {
    log "Creating Docker networks..."
    
    networks=(
        "promata_public:overlay"
        "promata_internal:overlay" 
        "promata_database:overlay"
    )
    
    for network in "${networks[@]}"; do
        name="${network%:*}"
        driver="${network#*:}"
        
        if ! docker network ls | grep -q "$name"; then
            docker network create \
                --driver "$driver" \
                --attachable \
                "$name" && log "Created network: $name"
        else
            log "Network exists: $name"
        fi
    done
}

# Deploy individual stack
deploy_stack() {
    local stack_name="$1"
    local stack_file="$2"
    local deps="$3"
    
    log "Deploying stack: $stack_name"
    
    if [[ -n "$deps" ]]; then
        log "Waiting for dependencies: $deps"
        sleep 5
    fi
    
    if [[ -f "$stack_file" ]]; then
        docker stack deploy \
            --compose-file "$stack_file" \
            --with-registry-auth \
            "$stack_name" || error "Failed to deploy $stack_name"
        
        log "✅ Stack deployed: $stack_name"
    else
        error "Stack file not found: $stack_file"
    fi
}

# Wait for service to be ready
wait_for_service() {
    local service="$1"
    local timeout="${2:-60}"
    local count=0
    
    log "Waiting for service: $service"
    
    while [[ $count -lt $timeout ]]; do
        if docker service ps "$service" --filter "desired-state=running" --format "{{.CurrentState}}" | grep -q "Running"; then
            log "✅ Service ready: $service"
            return 0
        fi
        
        sleep 5
        ((count+=5))
        echo -n "."
    done
    
    error "Service not ready after ${timeout}s: $service"
}

# Main deployment sequence
main() {
    log "🚀 Starting Pro-Mata deployment ($ENV environment)"
    
    # Pre-deployment checks
    if ! docker node ls >/dev/null 2>&1; then
        error "Docker Swarm not initialized"
    fi
    
    # Create networks
    create_networks
    
    # Deploy stacks in order
    log "📦 Deploying stacks..."
    
    # 1. Proxy stack (Traefik + Cloudflare)
    deploy_stack "promata-proxy" "$STACK_DIR/proxy-stack.yml"
    wait_for_service "promata-proxy_traefik"
    
    # 2. Database stack (PostgreSQL HA + PgBouncer)
    deploy_stack "promata-database" "$STACK_DIR/database-stack.yml"
    wait_for_service "promata-database_postgres-primary"
    wait_for_service "promata-database_pgbouncer"
    
    # 3. Application stack (Frontend + Backend)
    deploy_stack "promata-app" "$STACK_DIR/app-stack.yml" "database"
    wait_for_service "promata-app_backend"
    wait_for_service "promata-app_frontend"
    
    log "✅ All stacks deployed successfully!"
    
    # Post-deployment info
    echo ""
    log "🌐 Access URLs:"
    log "  App: https://$DOMAIN_NAME"
    log "  API: https://api.$DOMAIN_NAME"
    log "  Traefik: https://traefik.$DOMAIN_NAME"
    
    if [[ "$ENV" == "dev" ]]; then
        log "  PgAdmin: https://pgadmin.$DOMAIN_NAME"
    fi
    
    echo ""
    log "📊 Service Status:"
    docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}\t{{.Ports}}"
    
    echo ""
    warn "⏰ SSL certificates may take 1-2 minutes to provision"
    warn "🔄 Run 'make health' to check service health"
}

main "$@"