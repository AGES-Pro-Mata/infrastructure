#!/bin/bash
# Update Stacks Script - Pro-Mata Infrastructure

set -e

ENV=${1:-dev}
SERVICE=${2:-all}
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
error() { echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }

# Load environment
ENV_FILE="$PROJECT_ROOT/environments/$ENV/.env.$ENV"
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    error "Environment file not found: $ENV_FILE"
fi

# Update specific service
update_service() {
    local service_name="$1"
    local image="$2"
    
    log "🔄 Updating service: $service_name"
    
    if docker service inspect "$service_name" >/dev/null 2>&1; then
        if [[ -n "$image" ]]; then
            docker service update --image "$image" "$service_name"
        else
            docker service update --force "$service_name"
        fi
        log "✅ Service updated: $service_name"
    else
        warn "⚠️  Service not found: $service_name"
    fi
}

# Wait for service to be ready
wait_for_service() {
    local service="$1"
    local timeout="${2:-60}"
    local count=0
    
    log "⏳ Waiting for service to be ready: $service"
    
    while [[ $count -lt $timeout ]]; do
        local running_tasks
        running_tasks=$(docker service ps "$service" --filter "desired-state=running" --format "{{.CurrentState}}" | grep -c "Running" || echo "0")
        local desired_replicas
        desired_replicas=$(docker service inspect "$service" --format "{{.Spec.Mode.Replicated.Replicas}}" 2>/dev/null || echo "1")
        
        if [[ "$running_tasks" -eq "$desired_replicas" ]]; then
            log "✅ Service ready: $service ($running_tasks/$desired_replicas replicas)"
            return 0
        fi
        
        sleep 5
        ((count+=5))
        echo -n "."
    done
    
    error "❌ Service not ready after ${timeout}s: $service"
}

# Rolling update with health checks
rolling_update() {
    local service="$1"
    local image="$2"
    
    log "🔄 Performing rolling update: $service"
    
    # Configure rolling update
    docker service update \
        --update-parallelism 1 \
        --update-delay 30s \
        --update-failure-action rollback \
        --update-monitor 60s \
        --rollback-parallelism 1 \
        --rollback-delay 30s \
        --image "$image" \
        "$service" || error "Rolling update failed for $service"
    
    wait_for_service "$service" 180
}

# Update application services
update_applications() {
    info "📦 Updating application services..."
    
    # Update frontend
    if [[ "$SERVICE" == "all" ]] || [[ "$SERVICE" == "frontend" ]]; then
        rolling_update "promata-app_frontend" "$FRONTEND_IMAGE"
    fi
    
    # Update backend  
    if [[ "$SERVICE" == "all" ]] || [[ "$SERVICE" == "backend" ]]; then
        rolling_update "promata-app_backend" "$BACKEND_IMAGE"
    fi
}

# Update proxy services
update_proxy() {
    info "🌐 Updating proxy services..."
    
    if [[ "$SERVICE" == "all" ]] || [[ "$SERVICE" == "proxy" ]]; then
        update_service "promata-proxy_traefik"
        wait_for_service "promata-proxy_traefik" 60
        
        # Update DuckDNS
        update_service "promata-proxy_duckdns-updater"
    fi
}

# Update database services
update_database() {
    info "🗄️  Updating database services..."
    
    if [[ "$SERVICE" == "all" ]] || [[ "$SERVICE" == "database" ]]; then
        warn "⚠️  Database updates require special care. Skipping automatic update."
        warn "   To update database manually:"
        warn "   1. Backup: make backup"
        warn "   2. Update PgBouncer: docker service update promata-database_pgbouncer"
        warn "   3. Update replica: docker service update promata-database_postgres-replica"
        warn "   4. Update primary: docker service update promata-database_postgres-primary"
        warn "   5. Verify: make health"
    fi
}

# Pre-update checks
pre_update_checks() {
    info "🔍 Pre-update checks..."
    
    # Check if swarm is healthy
    if ! docker node ls >/dev/null 2>&1; then
        error "Docker Swarm not accessible"
    fi
    
    # Check available disk space
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        error "Insufficient disk space: ${disk_usage}% used"
    fi
    
    # Check if services are running
    local failed_services
    failed_services=$(docker service ls --filter "desired-state=running" --format "{{.Name}} {{.Replicas}}" | grep "0/" | wc -l)
    if [[ $failed_services -gt 0 ]]; then
        warn "⚠️  Found $failed_services failed services before update"
        docker service ls --filter "desired-state=running" --format "{{.Name}} {{.Replicas}}" | grep "0/"
        
        read -p "Continue with update? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Update cancelled by user"
        fi
    fi
    
    log "✅ Pre-update checks passed"
}

# Post-update verification
post_update_verification() {
    info "✅ Post-update verification..."
    
    # Wait a moment for services to stabilize
    sleep 10
    
    # Check service health
    log "Checking service health..."
    local failed_services
    failed_services=$(docker service ls --format "{{.Name}} {{.Replicas}}" | grep "0/" | wc -l)
    
    if [[ $failed_services -eq 0 ]]; then
        log "✅ All services healthy"
    else
        error "❌ $failed_services services failed after update"
    fi
    
    # Test endpoints
    log "Testing application endpoints..."
    local endpoints=(
        "https://$DOMAIN_NAME/health:Frontend"
        "https://api.$DOMAIN_NAME/health:Backend"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local url="${endpoint%:*}"
        local name="${endpoint#*:}"
        
        if curl -s -f -m 10 "$url" >/dev/null 2>&1; then
            log "✅ $name responsive"
        else
            warn "⚠️  $name not responding: $url"
        fi
    done
}

# Rollback function
rollback_on_failure() {
    error "❌ Update failed, initiating rollback..."
    
    if [[ "$SERVICE" == "all" ]] || [[ "$SERVICE" == "frontend" ]]; then
        docker service rollback promata-app_frontend || true
    fi
    
    if [[ "$SERVICE" == "all" ]] || [[ "$SERVICE" == "backend" ]]; then
        docker service rollback promata-app_backend || true
    fi
    
    if [[ "$SERVICE" == "all" ]] || [[ "$SERVICE" == "proxy" ]]; then
        docker service rollback promata-proxy_traefik || true
    fi
    
    error "Rollback completed. Check service status with 'make status'"
}

# Show update summary
show_summary() {
    info "📊 Update Summary"
    echo ""
    
    log "🎯 Updated Environment: $ENV"
    log "🔧 Updated Services: $SERVICE"
    log "⏰ Update Time: $(date)"
    echo ""
    
    log "📋 Current Service Status:"
    docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}"
    echo ""
    
    log "🌐 Application URLs:"
    log "  Frontend: https://$DOMAIN_NAME"
    log "  API: https://api.$DOMAIN_NAME"
    log "  Traefik: https://traefik.$DOMAIN_NAME"
    echo ""
}

# Main execution
main() {
    log "🚀 Starting Pro-Mata services update ($ENV environment)"
    
    # Set error trap for rollback
    trap rollback_on_failure ERR
    
    pre_update_checks
    
    case "$SERVICE" in
        all)
            update_proxy
            update_applications
            ;;
        frontend|backend)
            update_applications
            ;;
        proxy)
            update_proxy
            ;;
        database)
            update_database
            ;;
        *)
            update_service "$SERVICE"
            wait_for_service "$SERVICE"
            ;;
    esac
    
    post_update_verification
    show_summary
    
    log "🎉 Update completed successfully!"
}

# Help function
show_help() {
    echo "Update Stacks Script - Pro-Mata Infrastructure"
    echo ""
    echo "Usage: $0 [environment] [service]"
    echo ""
    echo "Environments:"
    echo "  dev     - Development environment (default)"
    echo "  prod    - Production environment"
    echo ""
    echo "Services:"
    echo "  all       - Update all services (default)"
    echo "  frontend  - Update frontend only"
    echo "  backend   - Update backend only"
    echo "  proxy     - Update Traefik proxy"
    echo "  database  - Show database update instructions"
    echo "  <name>    - Update specific service by name"
    echo ""
    echo "Examples:"
    echo "  $0                    # Update all services in dev"
    echo "  $0 dev frontend       # Update frontend in dev"
    echo "  $0 prod backend       # Update backend in prod"
}

# Handle arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac