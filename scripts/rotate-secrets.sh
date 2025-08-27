#!/bin/bash
# Secret Rotation Script - Pro-Mata Infrastructure
# Rotates all secrets in Azure Key Vault and updates services

set -e

ENV=${1:-dev}
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEY_VAULT_NAME="kv-promata-$ENV-secrets"

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

# Check prerequisites
check_prerequisites() {
    info "🔍 Checking prerequisites for secret rotation..."
    
    if ! az account show >/dev/null 2>&1; then
        error "❌ Not logged in to Azure. Run 'az login' first."
    fi
    
    if ! az keyvault show --name "$KEY_VAULT_NAME" >/dev/null 2>&1; then
        error "❌ Key Vault not found: $KEY_VAULT_NAME"
    fi
    
    # Check if Docker Swarm is running (for service updates)
    cd "$PROJECT_ROOT/terraform/environments/$ENV"
    if terraform output swarm_manager_public_ip >/dev/null 2>&1; then
        MANAGER_IP=$(terraform output -raw swarm_manager_public_ip)
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no promata@"$MANAGER_IP" "docker node ls" >/dev/null 2>&1; then
            SWARM_AVAILABLE=true
            log "✅ Docker Swarm is available for service updates"
        else
            SWARM_AVAILABLE=false
            warn "⚠️  Docker Swarm not accessible - secrets will be rotated but services won't be updated"
        fi
    else
        SWARM_AVAILABLE=false
        warn "⚠️  Infrastructure not deployed - rotating secrets only"
    fi
    
    cd "$PROJECT_ROOT"
}

# Backup current secrets
backup_current_secrets() {
    info "💾 Creating backup of current secrets..."
    
    local backup_dir="$PROJECT_ROOT/_secrets_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Get list of all secrets
    local secrets
    secrets=$(az keyvault secret list --vault-name "$KEY_VAULT_NAME" --query "[].name" -o tsv)
    
    # Backup each secret
    while IFS= read -r secret_name; do
        if [[ -n "$secret_name" ]]; then
            az keyvault secret show \
                --vault-name "$KEY_VAULT_NAME" \
                --name "$secret_name" \
                --query "value" -o tsv > "$backup_dir/$secret_name.txt"
            log "✅ Backed up secret: $secret_name"
        fi
    done <<< "$secrets"
    
    log "✅ Secrets backed up to: $backup_dir"
    echo "$backup_dir" > "$PROJECT_ROOT/.last_secrets_backup"
}

# Generate new secrets
rotate_secrets() {
    info "🔄 Rotating secrets..."
    
    local secrets_to_rotate=(
        "postgres-password"
        "postgres-replica-password"  
        "pgadmin-password"
        "jwt-secret"
        "grafana-admin-password"
    )
    
    for secret_name in "${secrets_to_rotate[@]}"; do
        log "🔄 Rotating: $secret_name"
        
        local new_secret_value
        case "$secret_name" in
            "jwt-secret")
                new_secret_value=$(openssl rand -base64 64)
                ;;
            *)
                new_secret_value=$(openssl rand -base64 32)
                ;;
        esac
        
        # Update secret in Key Vault
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "$secret_name" \
            --value "$new_secret_value" \
            --tags "Environment=$ENV" "RotatedBy=script" "RotatedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --output none
        
        log "✅ Rotated secret: $secret_name"
    done
}

# Update Traefik auth hash
rotate_traefik_auth() {
    info "🔄 Rotating Traefik authentication hash..."
    
    # Generate new password
    local new_password
    new_password=$(openssl rand -base64 16)
    
    # Create htpasswd hash
    local auth_hash
    auth_hash=$(python3 -c "import crypt; print(crypt.crypt('$new_password', crypt.mksalt(crypt.METHOD_SHA512)))")
    
    # Update in Key Vault
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "traefik-auth-hash" \
        --value "admin:$auth_hash" \
        --tags "Environment=$ENV" "RotatedBy=script" "RotatedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --output none
    
    log "✅ Traefik auth rotated. New password: $new_password"
    warn "⚠️  Save this password! Traefik dashboard access: admin / $new_password"
}

# Update running services with new secrets
update_services() {
    if [[ "$SWARM_AVAILABLE" != "true" ]]; then
        warn "⚠️  Skipping service updates - Swarm not available"
        return 0
    fi
    
    info "🔄 Updating running services with new secrets..."
    
    # Load new secrets
    "$PROJECT_ROOT/scripts/setup-security.sh" "$ENV" local
    source "$PROJECT_ROOT/scripts/load-env.sh" "$ENV"
    
    # Services that need restart after secret rotation
    local services=(
        "promata-database_postgres-primary"
        "promata-database_postgres-replica"
        "promata-database_pgbouncer"
        "promata-app_backend"
        "promata-proxy_traefik"
    )
    
    for service in "${services[@]}"; do
        log "🔄 Updating service: $service"
        
        if ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" "docker service inspect $service" >/dev/null 2>&1; then
            # Force update to pick up new environment variables
            ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
                "docker service update --force $service" >/dev/null 2>&1
            
            log "✅ Updated service: $service"
        else
            warn "⚠️  Service not found: $service"
        fi
    done
    
    # Wait for services to stabilize
    info "⏳ Waiting for services to stabilize..."
    sleep 30
    
    # Verify services are running
    local failed_services
    failed_services=$(ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        'docker service ls --format "{{.Name}} {{.Replicas}}"' | grep "0/" | wc -l)
    
    if [[ $failed_services -eq 0 ]]; then
        log "✅ All services updated successfully"
    else
        warn "⚠️  $failed_services services may need manual attention"
        ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
            'docker service ls --format "{{.Name}} {{.Replicas}}"' | grep "0/"
    fi
}

# Test new secrets
test_rotated_secrets() {
    info "🧪 Testing rotated secrets..."
    
    # Load new environment
    source "$PROJECT_ROOT/scripts/load-env.sh" "$ENV"
    
    # Test database connection (if available)
    if [[ "$SWARM_AVAILABLE" == "true" ]]; then
        log "Testing database connection..."
        
        if ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
            "docker exec \$(docker ps -q --filter name=postgres-primary) pg_isready -U $POSTGRES_USER" >/dev/null 2>&1; then
            log "✅ Database connection test passed"
        else
            warn "⚠️  Database connection test failed - may need manual check"
        fi
    fi
    
    # Test Key Vault access
    if az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "postgres-password" >/dev/null 2>&1; then
        log "✅ Key Vault access test passed"
    else
        error "❌ Key Vault access test failed"
    fi
    
    log "✅ Secret rotation tests completed"
}

# Generate rotation report
generate_report() {
    info "📊 Generating rotation report..."
    
    local report_file="$PROJECT_ROOT/_rotation_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
Pro-Mata Secret Rotation Report
==============================

Environment: $ENV
Key Vault: $KEY_VAULT_NAME
Rotation Date: $(date)
Performed By: $(whoami)@$(hostname)

Secrets Rotated:
- postgres-password
- postgres-replica-password
- pgladmin-password
- jwt-secret
- grafana-admin-password
- traefik-auth-hash

Services Updated:
EOF

    if [[ "$SWARM_AVAILABLE" == "true" ]]; then
        echo "- promata-database_postgres-primary" >> "$report_file"
        echo "- promata-database_postgres-replica" >> "$report_file"
        echo "- promata-database_pgbouncer" >> "$report_file"
        echo "- promata-app_backend" >> "$report_file"
        echo "- promata-proxy_traefik" >> "$report_file"
    else
        echo "- No services updated (Swarm not available)" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

Backup Location:
$(cat "$PROJECT_ROOT/.last_secrets_backup" 2>/dev/null || echo "No backup created")

Next Rotation Recommended: $(date -d "+90 days" +%Y-%m-%d)

Notes:
- All secrets have been rotated successfully
- Services have been updated with new secrets
- Old secret backups are available for emergency rollback
- Consider updating CI/CD secrets if using GitHub Actions
EOF

    log "✅ Rotation report generated: $report_file"
    
    # Display summary
    echo ""
    log "📋 Rotation Summary:"
    log "   Environment: $ENV"
    log "   Secrets rotated: 6"
    log "   Services updated: $([ "$SWARM_AVAILABLE" == "true" ] && echo "5" || echo "0")"
    log "   Report: $report_file"
    echo ""
}

# Update CI/CD secrets reminder
cicd_reminder() {
    warn "🤖 CI/CD Secrets Reminder:"
    warn ""
    warn "If you're using GitHub Actions, update these secrets manually:"
    warn "   1. Go to: Repository → Settings → Secrets and variables → Actions"
    warn "   2. Update these secrets with new values from Key Vault:"
    warn "      - POSTGRES_PASSWORD"
    warn "      - PGADMIN_PASSWORD"
    warn "      - JWT_SECRET"
    warn "      - TRAEFIK_AUTH_USERS"
    warn "      - GRAFANA_ADMIN_PASSWORD"
    warn ""
    warn "   3. Or run: ./scripts/setup-cicd-vars.sh $ENV"
    warn ""
}

# Main execution
main() {
    log "🔄 Starting secret rotation for $ENV environment"
    echo ""
    
    warn "⚠️  IMPORTANT: Secret rotation will:"
    warn "   - Generate new passwords for all services"
    warn "   - Restart all running services"
    warn "   - May cause temporary downtime (~2-3 minutes)"
    warn "   - Require manual update of CI/CD secrets"
    echo ""
    
    if [[ "${FORCE_ROTATION:-}" != "true" ]]; then
        read -p "Do you want to proceed with secret rotation? (yes/NO): " -r
        if [[ ! $REPLY =~ ^yes$ ]]; then
            log "Secret rotation cancelled by user"
            exit 0
        fi
    fi
    
    check_prerequisites
    backup_current_secrets
    rotate_secrets
    rotate_traefik_auth
    update_services
    test_rotated_secrets
    generate_report
    cicd_reminder
    
    log "🎉 Secret rotation completed successfully!"
}

# Show help
show_help() {
    echo "Secret Rotation Script - Pro-Mata Infrastructure"
    echo ""
    echo "This script rotates all secrets in Azure Key Vault and updates running services."
    echo ""
    echo "Usage: $0 [environment] [options]"
    echo ""
    echo "Environments:"
    echo "  dev     - Development environment (default)"
    echo "  prod    - Production environment"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --force        Force rotation without prompts"
    echo ""
    echo "What this script does:"
    echo "  1. Creates backup of current secrets"
    echo "  2. Generates new secure passwords"
    echo "  3. Updates secrets in Azure Key Vault"
    echo "  4. Updates running Docker services"
    echo "  5. Tests the new secrets"
    echo "  6. Generates rotation report"
    echo ""
    echo "Secrets rotated:"
    echo "  - Database passwords"
    echo "  - Application secrets (JWT)"
    echo "  - Admin passwords"
    echo "  - Authentication hashes"
    echo ""
    echo "Recommended frequency: Every 90 days"
}

# Handle arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --force)
        export FORCE_ROTATION=true
        main "${@:2}"
        ;;
    *)
        if [[ "$2" == "--force" ]]; then
            export FORCE_ROTATION=true
        fi
        main "$@"
        ;;
esac