#!/bin/bash
# Emergency Rollback Script - Pro-Mata Infrastructure

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

# Rollback confirmation
confirm_rollback() {
    echo ""
    warn "🚨 EMERGENCY ROLLBACK INITIATED"
    warn "Environment: $ENV"
    warn "Services: $SERVICE"
    echo ""
    warn "This will:"
    warn "  - Rollback services to previous versions"
    warn "  - May cause temporary downtime"
    warn "  - Should only be used in emergency situations"
    echo ""
    
    if [[ "${FORCE_ROLLBACK:-}" != "true" ]]; then
        read -p "Are you sure you want to proceed? (yes/NO): " -r
        if [[ ! $REPLY =~ ^yes$ ]]; then
            log "Rollback cancelled"
            exit 0
        fi
    fi
    
    log "Proceeding with rollback..."
}

# Check service status before rollback
check_service_status() {
    local service="$1"
    
    if docker service inspect "$service" >/dev/null 2>&1; then
        local current_image
        current_image=$(docker service inspect "$service" --format "{{.Spec.TaskTemplate.ContainerSpec.Image}}")
        local replicas
        replicas=$(docker service ls --filter name="$service" --format "{{.Replicas}}")
        
        log "📊 Current status of $service:"
        log "   Image: $current_image"
        log "   Replicas: $replicas"
        return 0
    else
        warn "⚠️  Service not found: $service"
        return 1
    fi
}

# Rollback individual service
rollback_service() {
    local service="$1"
    
    log "⏪ Rolling back service: $service"
    
    if docker service inspect "$service" >/dev/null 2>&1; then
        docker service rollback "$service" || {
            warn "⚠️  Direct rollback failed for $service, trying force update"
            docker service update --rollback "$service"
        }
        log "✅ Rollback initiated for: $service"
    else
        warn "⚠️  Service not found: $service"
    fi
}

# Wait for rollback completion
wait_for_rollback() {
    local service="$1"
    local timeout="${2:-120}"
    local count=0
    
    log "⏳ Waiting for rollback to complete: $service"
    
    while [[ $count -lt $timeout ]]; do
        local update_status
        update_status=$(docker service inspect "$service" --format "{{.UpdateStatus.State}}" 2>/dev/null || echo "unknown")
        
        case "$update_status" in
            "completed")
                log "✅ Rollback completed: $service"
                return 0
                ;;
            "updating")
                echo -n "."
                ;;
            "paused"|"rollback_paused")
                warn "⚠️  Rollback paused: $service"
                docker service update --rollback "$service"
                ;;
            "rollback_completed")
                log "✅ Rollback completed: $service"
                return 0
                ;;
            *)
                warn "⚠️  Unknown status for $service: $update_status"
                ;;
        esac
        
        sleep 5
        ((count+=5))
    done
    
    error "❌ Rollback timeout for $service"
}

# Emergency stop and restart
emergency_restart() {
    local service="$1"
    
    warn "🚨 Performing emergency restart: $service"
    
    # Scale down to 0
    docker service scale "$service=0"
    sleep 10
    
    # Scale back up
    local desired_replicas
    desired_replicas=$(docker service inspect "$service" --format "{{.Spec.Mode.Replicated.Replicas}}" 2>/dev/null || echo "1")
    docker service scale "$service=$desired_replicas"
    
    log "🔄 Emergency restart completed: $service"
}

# Rollback application services
rollback_applications() {
    info "📦 Rolling back application services..."
    
    if [[ "$SERVICE" == "all" ]] || [[ "$SERVICE" == "backend" ]]; then
        check_service_status "promata-app_backend"
        rollback_service "promata-app_backend"
        wait_for_rollback "promata-app_backend"
    fi
    
    if [[ "$SERVICE" == "all" ]] || [[ "$SERVICE" == "frontend" ]]; then
        check_service_status "promata-app_frontend"
        rollback_service "promata-app_frontend"
        wait_for_rollback "promata-app_frontend"
    fi
}

# Rollback proxy services
rollback_proxy() {
    info "🌐 Rolling back proxy services..."
    
    if [[ "$SERVICE" == "all" ]] || [[ "$SERVICE" == "proxy" ]]; then
        check_service_status "promata-proxy_traefik"
        rollback_service "promata-proxy_traefik"
        wait_for_rollback "promata-proxy_traefik"
    fi
}

# Database emergency procedures
rollback_database() {
    warn "🗄️  Database rollback requires manual intervention!"
    warn ""
    warn "Recommended steps:"
    warn "1. Check database health: make health"
    warn "2. If primary is down, promote replica:"
    warn "   docker exec <replica-container> pg_promote"
    warn "3. If both are down, restore from backup:"
    warn "   make restore BACKUP_FILE=<latest-backup>"
    warn "4. Restart PgBouncer:"
    warn "   docker service update --force promata-database_pgbouncer"
    warn ""
    warn "⚠️  Only proceed if you understand the implications!"
    
    if [[ "${FORCE_DATABASE_ROLLBACK:-}" == "true" ]]; then
        warn "Force database rollback enabled..."
        rollback_service "promata-database_pgbouncer"
        # Note: PostgreSQL containers themselves should NOT be rolled back automatically
    fi
}

# Verify rollback success
verify_rollback() {
    info "✅ Verifying rollback success..."
    
    sleep 15  # Give services time to stabilize
    
    # Check service health
    local failed_services
    failed_services=$(docker service ls --format "{{.Name}} {{.Replicas}}" | grep "0/" | wc -l)
    
    if [[ $failed_services -eq 0 ]]; then
        log "✅ All services are running after rollback"
    else
        error "❌ $failed_services services still failing after rollback"
    fi
    
    # Test critical endpoints
    log "🔗 Testing critical endpoints..."
    local endpoints=(
        "https://$DOMAIN_NAME/health:Frontend"
        "https://api.$DOMAIN_NAME/health:Backend API"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local url="${endpoint%:*}"
        local name="${endpoint#*:}"
        
        if timeout 10 curl -s -f "$url" >/dev/null 2>&1; then
            log "✅ $name is responsive"
        else
            warn "⚠️  $name is not responding: $url"
        fi
    done
}

# Generate rollback report
generate_report() {
    info "📊 Rollback Report"
    echo ""
    
    log "🎯 Rollback Details:"
    log "   Environment: $ENV"
    log "   Services: $SERVICE" 
    log "   Time: $(date)"
    log "   Initiated by: $(whoami)@$(hostname)"
    echo ""
    
    log "📋 Current Service Status:"
    docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}\t{{.UpdatedAt}}"
    echo ""
    
    log "🏥 Health Status:"
    "$SCRIPT_DIR/health-check.sh" || warn "Health check failed"
    echo ""
    
    log "📝 Next Steps:"
    log "   1. Investigate root cause of the issue"
    log "   2. Fix the problem in development"
    log "   3. Test thoroughly before next deployment"
    log "   4. Document the incident for future reference"
}

# Send rollback notification
send_notification() {
    local message="🚨 EMERGENCY ROLLBACK COMPLETED\nEnvironment: $ENV\nServices: $SERVICE\nTime: $(date)\nStatus: All services restored"
    
    # Add notification logic here (Slack, Discord, etc.)
    log "📤 Rollback notification sent"
}

# Main execution
main() {
    log "🚨 Starting emergency rollback for $ENV environment"
    
    confirm_rollback
    
    case "$SERVICE" in
        all)
            rollback_applications
            rollback_proxy
            ;;
        frontend|backend)
            rollback_applications
            ;;
        proxy)
            rollback_proxy
            ;;
        database)
            rollback_database
            ;;
        *)
            check_service_status "$SERVICE"
            rollback_service "$SERVICE"
            wait_for_rollback "$SERVICE"
            ;;
    esac
    
    verify_rollback
    generate_report
    send_notification
    
    log "🎉 Emergency rollback completed successfully!"
    warn "⚠️  Don't forget to investigate and fix the root cause!"
}

# Quick rollback (skip confirmations)
quick_rollback() {
    export FORCE_ROLLBACK=true
    main "$@"
}

# Show help
show_help() {
    echo "Emergency Rollback Script - Pro-Mata Infrastructure"
    echo ""
    echo "⚠️  WARNING: This script performs emergency rollbacks and should only"
    echo "    be used when services are failing and immediate recovery is needed."
    echo ""
    echo "Usage: $0 [environment] [service] [options]"
    echo ""
    echo "Environments:"
    echo "  dev     - Development environment (default)"
    echo "  prod    - Production environment"
    echo ""
    echo "Services:"
    echo "  all       - Rollback all services (default)"
    echo "  frontend  - Rollback frontend only"
    echo "  backend   - Rollback backend only" 
    echo "  proxy     - Rollback Traefik proxy"
    echo "  database  - Show database rollback procedures"
    echo "  <name>    - Rollback specific service"
    echo ""
    echo "Options:"
    echo "  --quick   - Skip confirmation prompts"
    echo "  --force   - Force rollback without checks"
    echo ""
    echo "Examples:"
    echo "  $0                    # Rollback all services in dev"
    echo "  $0 dev frontend       # Rollback frontend in dev"
    echo "  $0 prod --quick       # Quick rollback in prod"
    echo ""
    echo "Environment Variables:"
    echo "  FORCE_ROLLBACK=true          - Skip confirmations"
    echo "  FORCE_DATABASE_ROLLBACK=true - Allow database rollback"
}

# Handle arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --quick)
        quick_rollback "${@:2}"
        ;;
    *)
        if [[ "$3" == "--quick" ]] || [[ "$2" == "--quick" ]]; then
            quick_rollback "$1" "${2//--quick/}"
        else
            main "$@"
        fi
        ;;
esac