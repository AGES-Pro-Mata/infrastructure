#!/bin/bash
# Health Check Script - Pro-Mata Infrastructure

set -e

ENV=${1:-dev}
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }

# Load environment
ENV_FILE="$PROJECT_ROOT/envs/$ENV/.env.$ENV"
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    warn "Environment file not found: $ENV_FILE, using defaults"
    # Set default values if env file not found
    DOMAIN_NAME="${DOMAIN_NAME:-dev.promata.com.br}"
    POSTGRES_USER="${POSTGRES_USER:-promata}"
    POSTGRES_DB="${POSTGRES_DB:-promata}"
fi

# Health check functions
check_dns() {
    info "🌐 Checking DNS resolution..."
    
    if nslookup "$DOMAIN_NAME" >/dev/null 2>&1; then
        local resolved_ip
        resolved_ip=$(nslookup "$DOMAIN_NAME" 8.8.8.8 | grep -A1 'Name:' | tail -1 | awk '{print $2}' 2>/dev/null || echo "unknown")
        log "✅ DNS resolves: $DOMAIN_NAME → $resolved_ip"
    else
        error "❌ DNS resolution failed for $DOMAIN_NAME"
        return 1
    fi
}

check_docker_swarm() {
    info "🐳 Checking Docker Swarm status..."
    
    if docker node ls >/dev/null 2>&1; then
        local nodes
        nodes=$(docker node ls --format "{{.Hostname}} {{.Status}} {{.Availability}}")
        log "✅ Docker Swarm active"
        echo "$nodes" | while read -r line; do
            log "   Node: $line"
        done
    else
        error "❌ Docker Swarm not initialized or not accessible"
        return 1
    fi
}

check_services() {
    info "📦 Checking Docker services..."
    
    local services=(
        "promata-proxy_traefik"
        "promata-database_postgres-primary"
        "promata-database_pgbouncer"
        "promata-app_backend"
        "promata-app_frontend"
    )
    
    for service in "${services[@]}"; do
        if docker service ps "$service" --filter "desired-state=running" --format "{{.CurrentState}}" | grep -q "Running"; then
            local replicas
            replicas=$(docker service ls --filter name="$service" --format "{{.Replicas}}")
            log "✅ $service ($replicas)"
        else
            error "❌ $service not running"
        fi
    done
}

check_endpoints() {
    info "🔗 Checking application endpoints..."
    
    local endpoints=(
        "https://$DOMAIN_NAME/health:Frontend"
        "https://api.$DOMAIN_NAME/health:Backend API"
        "http://localhost:8080/ping:Traefik Ping"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local url="${endpoint%:*}"
        local name="${endpoint#*:}"
        
        if curl -s -f -m 10 "$url" >/dev/null 2>&1; then
            log "✅ $name ($url)"
        else
            warn "⚠️  $name not accessible ($url)"
        fi
    done
}

check_database() {
    info "🗄️  Checking database connectivity..."
    
    # Check via PgBouncer
    if docker exec -it $(docker ps -q -f name=pgbouncer) psql -h localhost -p 6432 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" >/dev/null 2>&1; then
        log "✅ Database accessible via PgBouncer"
    else
        error "❌ Database not accessible via PgBouncer"
    fi
    
    # Check primary database
    if docker exec -it $(docker ps -q -f name=postgres-primary) pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; then
        log "✅ PostgreSQL primary ready"
    else
        error "❌ PostgreSQL primary not ready"
    fi
}

check_ssl_certificates() {
    info "🔒 Checking SSL certificates..."
    
    local cert_info
    cert_info=$(echo | openssl s_client -servername "$DOMAIN_NAME" -connect "$DOMAIN_NAME":443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
    
    if [[ -n "$cert_info" ]]; then
        log "✅ SSL certificate active"
        local expire_date
        expire_date=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
        log "   Expires: $expire_date"
    else
        warn "⚠️  SSL certificate not found or not accessible"
    fi
}

check_resources() {
    info "💻 Checking system resources..."
    
    # Memory usage
    local memory_usage
    memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
    if (( $(echo "$memory_usage < 80" | bc -l) )); then
        log "✅ Memory usage: ${memory_usage}%"
    else
        warn "⚠️  High memory usage: ${memory_usage}%"
    fi
    
    # Disk usage
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 80 ]]; then
        log "✅ Disk usage: ${disk_usage}%"
    else
        warn "⚠️  High disk usage: ${disk_usage}%"
    fi
    
    # Load average
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    log "ℹ️  Load average: $load_avg"
}

generate_report() {
    info "📊 Health Check Summary"
    echo ""
    
    # Service status
    echo "Services Status:"
    docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}\t{{.Ports}}"
    echo ""
    
    # Container status
    echo "Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # Access URLs
    echo "Access URLs:"
    log "  🌐 Frontend: https://$DOMAIN_NAME"
    log "  🔧 API: https://api.$DOMAIN_NAME"
    log "  📊 Traefik: https://traefik.$DOMAIN_NAME"
    if [[ "$ENV" == "dev" ]]; then
        log "  🗄️  PgAdmin: https://pgadmin.$DOMAIN_NAME"
    fi
    echo ""
    
    # Quick stats
    local total_containers
    total_containers=$(docker ps -q | wc -l)
    local running_services
    running_services=$(docker service ls -q | wc -l)
    
    log "📈 Infrastructure Stats:"
    log "   Active containers: $total_containers"
    log "   Running services: $running_services"
    log "   Environment: $ENV"
    log "   Last check: $(date)"
}

# Main execution
main() {
    log "🏥 Starting Pro-Mata health check..."
    echo ""
    
    # Basic checks
    check_docker_swarm
    check_services
    check_dns
    check_database
    check_endpoints
    check_ssl_certificates
    check_resources
    
    echo ""
    generate_report
    
    log "🎉 Health check completed!"
}

main "$@"