#!/bin/bash
# Terraform State Migration Script - Pro-Mata Infrastructure
# Migrates local state to Azure remote backend

set -e

ENV=${1:-dev}
SCRIPT_DIR="$(dirname "$0")"
TERRAFORM_DIR="$SCRIPT_DIR/environments/$ENV"

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

# Check if running from correct directory
check_directory() {
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        error "Terraform directory not found: $TERRAFORM_DIR"
    fi
    
    cd "$TERRAFORM_DIR" || error "Failed to change to Terraform directory"
}

# Check if local state exists
check_local_state() {
    info "🔍 Checking for existing local state..."
    
    if [[ -f "terraform.tfstate" ]]; then
        log "✅ Local state file found: terraform.tfstate"
        
        # Check if state contains resources
        local resource_count
        resource_count=$(terraform state list 2>/dev/null | wc -l || echo "0")
        
        if [[ $resource_count -gt 0 ]]; then
            log "📊 Local state contains $resource_count resources"
            return 0
        else
            log "ℹ️  Local state file is empty"
            return 1
        fi
    else
        log "ℹ️  No local state file found"
        return 1
    fi
}

# Check if backend configuration exists
check_backend_config() {
    info "🔍 Checking backend configuration..."
    
    if [[ -f "backend.tf" ]]; then
        log "✅ Backend configuration found"
        return 0
    else
        warn "⚠️  Backend configuration not found"
        warn "   Run './backend-setup.sh' first to create Azure backend"
        return 1
    fi
}

# Backup local state
backup_local_state() {
    info "💾 Creating backup of local state..."
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="terraform.tfstate.backup_$timestamp"
    
    cp terraform.tfstate "$backup_file"
    log "✅ Local state backed up to: $backup_file"
}

# Migrate state to remote backend
migrate_state() {
    info "🚀 Migrating state to Azure backend..."
    
    # Initialize with backend configuration
    log "Initializing Terraform with Azure backend..."
    
    # This will prompt for migration confirmation
    if terraform init; then
        log "✅ State migration completed successfully"
        
        # Verify migration
        if terraform state list >/dev/null 2>&1; then
            log "✅ Remote state verified - migration successful"
            
            # Clean up local state files
            cleanup_local_files
        else
            error "❌ Remote state verification failed"
        fi
    else
        error "❌ State migration failed"
    fi
}

# Cleanup local state files after successful migration
cleanup_local_files() {
    info "🧹 Cleaning up local state files..."
    
    read -p "Migration successful. Remove local state files? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Keep backups but remove active local state
        if [[ -f "terraform.tfstate" ]]; then
            rm terraform.tfstate
            log "✅ Local state file removed"
        fi
        
        if [[ -f "terraform.tfstate.backup" ]]; then
            rm terraform.tfstate.backup
            log "✅ Local backup file removed" 
        fi
        
        log "ℹ️  Timestamped backups preserved for safety"
    else
        warn "⚠️  Local state files preserved (you can remove them manually later)"
    fi
}

# Verify remote backend is working
verify_remote_backend() {
    info "✅ Verifying remote backend functionality..."
    
    # Test basic operations
    if terraform state list >/dev/null 2>&1; then
        log "✅ State listing works"
    else
        error "❌ Cannot list state from remote backend"
    fi
    
    # Test plan operation
    if terraform plan -detailed-exitcode >/dev/null 2>&1; then
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            log "✅ No changes needed - infrastructure matches state"
        elif [[ $exit_code -eq 2 ]]; then
            log "✅ Plan operation successful (changes detected)"
        else
            error "❌ Plan operation failed"
        fi
    else
        warn "⚠️  Plan operation had issues (check configuration)"
    fi
    
    log "✅ Remote backend verification completed"
}

# Show migration summary
show_summary() {
    info "📊 State Migration Summary"
    echo ""
    
    log "🎯 Migration Details:"
    log "   Environment: $ENV"
    log "   Backend Type: Azure Storage"
    log "   State Location: Remote (Azure)"
    log "   Migration Time: $(date)"
    echo ""
    
    # Show backend configuration
    if [[ -f "backend.tf" ]]; then
        log "🔧 Backend Configuration:"
        grep -E "(resource_group_name|storage_account_name|container_name|key)" backend.tf | sed 's/^/   /'
    fi
    echo ""
    
    log "🚀 Next Steps:"
    log "   ✅ State is now stored remotely in Azure"
    log "   ✅ Multiple developers can access the same state"
    log "   ✅ State is protected with versioning and soft delete"
    log "   ✅ 'terraform destroy' will work from any machine with Azure access"
    echo ""
    
    warn "💡 Important Notes:"
    warn "   - Always use 'terraform init' when working from a new machine"
    warn "   - Ensure Azure CLI is authenticated before Terraform operations"
    warn "   - The backend storage account contains sensitive state data"
}

# Interactive migration process
interactive_migration() {
    log "🤖 Interactive State Migration Process"
    echo ""
    
    warn "⚠️  IMPORTANT: This process will migrate your Terraform state to Azure."
    warn "   - Your local state will be uploaded to Azure Storage"
    warn "   - A backup will be created before migration"
    warn "   - The process is normally safe but backups are recommended"
    echo ""
    
    read -p "Do you want to proceed with state migration? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Migration cancelled by user"
        exit 0
    fi
    
    # Perform migration steps
    backup_local_state
    migrate_state
    verify_remote_backend
    show_summary
}

# Force migration without prompts
force_migration() {
    log "🚀 Force migration mode enabled"
    
    backup_local_state
    migrate_state
    verify_remote_backend
    
    # Auto-cleanup in force mode
    if [[ -f "terraform.tfstate" ]]; then
        rm terraform.tfstate terraform.tfstate.backup 2>/dev/null || true
        log "✅ Local state files cleaned up"
    fi
    
    show_summary
}

# Main execution
main() {
    log "🚀 Starting Terraform state migration for $ENV environment"
    
    check_directory
    
    # Check if backend is configured
    if ! check_backend_config; then
        error "Backend not configured. Run './backend-setup.sh' first."
    fi
    
    # Check if there's local state to migrate
    if ! check_local_state; then
        log "✅ No local state to migrate - proceeding with backend initialization"
        terraform init
        log "🎉 Backend initialization completed"
        exit 0
    fi
    
    # Proceed with migration
    if [[ "${FORCE_MIGRATION:-false}" == "true" ]]; then
        force_migration
    else
        interactive_migration
    fi
    
    log "🎉 State migration completed successfully!"
}

# Show help
show_help() {
    echo "Terraform State Migration Script - Pro-Mata Infrastructure"
    echo ""
    echo "This script migrates local Terraform state to Azure remote backend."
    echo ""
    echo "Usage: $0 [environment] [options]"
    echo ""
    echo "Environments:"
    echo "  dev     - Development environment (default)"
    echo "  prod    - Production environment"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --force        Force migration without prompts"
    echo ""
    echo "Prerequisites:"
    echo "  1. Run './backend-setup.sh' to create Azure backend"
    echo "  2. Ensure Azure CLI is authenticated"
    echo "  3. Have appropriate permissions to the subscription"
    echo ""
    echo "What this script does:"
    echo "  1. Checks for existing local state"
    echo "  2. Creates a backup of local state"  
    echo "  3. Migrates state to Azure Storage"
    echo "  4. Verifies the migration"
    echo "  5. Optionally cleans up local files"
}

# Handle arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --force)
        export FORCE_MIGRATION=true
        main "${@:2}"
        ;;
    *)
        if [[ "$2" == "--force" ]]; then
            export FORCE_MIGRATION=true
        fi
        main "$@"
        ;;
esac