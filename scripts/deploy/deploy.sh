#!/bin/bash
# Full deployment script for Pro-Mata Infrastructure
# Updated for new envs/ structure and AWS deployment

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
REQUESTED_ENVIRONMENT="${1:-dev}"
ENVIRONMENT="dev"  # Force dev environment for now
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Fix for GitHub Actions path duplication - more robust approach
if [[ "$GITHUB_ACTIONS" == "true" ]]; then
    # In GitHub Actions, the workspace is /home/runner/work/{repo}/{repo}
    # We need to find the actual project root
    if [[ "$SCRIPT_DIR" == *"/infrastructure/infrastructure/"* ]]; then
        # Remove the duplicate infrastructure path
        PROJECT_ROOT="${SCRIPT_DIR%/infrastructure/scripts/deploy}"
    else
        # Fallback to pwd
        PROJECT_ROOT="$(pwd)"
    fi
else
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

# Debug logging
echo "=== PATH DEBUGGING ==="
echo "GITHUB_ACTIONS: $GITHUB_ACTIONS"
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "PROJECT_ROOT: $PROJECT_ROOT"
echo "PWD: $(pwd)"
echo "Current directory contents:"
ls -la
echo "Project root contents:"
ls -la "$PROJECT_ROOT" 2>/dev/null || echo "Cannot list PROJECT_ROOT"
echo "Terraform directory check:"
ls -la "$PROJECT_ROOT/terraform" 2>/dev/null || echo "Cannot find terraform directory"
echo "=== END DEBUGGING ==="

ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"
TF_DIR="$PROJECT_ROOT/terraform/deployments/$ENVIRONMENT"

# Additional path validation and fallback
echo "=== PATH VALIDATION ==="
echo "ENV_DIR: $ENV_DIR"
echo "TF_DIR: $TF_DIR"

if [[ ! -d "$TF_DIR" ]]; then
    warn "Terraform directory not found at expected location: $TF_DIR"
    # Try alternative paths in GitHub Actions
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        # Try removing one level of infrastructure
        ALT_TF_DIR="${TF_DIR%/infrastructure/terraform/deployments/$ENVIRONMENT}/terraform/deployments/$ENVIRONMENT"
        echo "Trying alternative path: $ALT_TF_DIR"
        if [[ -d "$ALT_TF_DIR" ]]; then
            TF_DIR="$ALT_TF_DIR"
            PROJECT_ROOT="${ALT_TF_DIR%/terraform/deployments/$ENVIRONMENT}"
            ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"
            success "Found terraform directory at alternative path: $TF_DIR"
        else
            # Try looking from current working directory
            CWD_TF_DIR="$(pwd)/terraform/deployments/$ENVIRONMENT"
            echo "Trying CWD path: $CWD_TF_DIR"
            if [[ -d "$CWD_TF_DIR" ]]; then
                TF_DIR="$CWD_TF_DIR"
                PROJECT_ROOT="$(pwd)"
                ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"
                success "Found terraform directory from CWD: $TF_DIR"
            fi
        fi
    fi
fi

echo "Final paths:"
echo "PROJECT_ROOT: $PROJECT_ROOT"
echo "ENV_DIR: $ENV_DIR"
echo "TF_DIR: $TF_DIR"
echo "=== END VALIDATION ==="

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Validate environment
validate_environment() {
    if [[ "$REQUESTED_ENVIRONMENT" != "dev" ]]; then
        warn "Requested environment '$REQUESTED_ENVIRONMENT' is not yet configured"
        warn "Forcing deployment to 'dev' environment instead"
    fi
    
    log "Validating environment: $ENVIRONMENT"
    log "Project root: $PROJECT_ROOT"
    log "Environment dir: $ENV_DIR"
    log "Terraform dir: $TF_DIR"
    
    # Debug: List what's actually available
    log "Listing terraform directory structure:"
    if [[ -d "$PROJECT_ROOT/terraform" ]]; then
        find "$PROJECT_ROOT/terraform" -type d -name "*dev*" | head -5 || true
        log "Contents of terraform directory:"
        ls -la "$PROJECT_ROOT/terraform/" || true
        if [[ -d "$PROJECT_ROOT/terraform/deployments" ]]; then
            log "Contents of terraform/deployments:"
            ls -la "$PROJECT_ROOT/terraform/deployments/" || true
        fi
    else
        error "Terraform directory not found at: $PROJECT_ROOT/terraform"
    fi
    
    case "$ENVIRONMENT" in
        dev)
            log "Valid environment: $ENVIRONMENT"
            ;;
        *)
            error "Environment must be: dev"
            exit 1
            ;;
    esac
    
    if [[ ! -d "$ENV_DIR" ]]; then
        error "Environment directory not found: $ENV_DIR"
        log "Available environments:"
        ls -la "$PROJECT_ROOT/envs/" || true
        exit 1
    fi
    
    if [[ ! -f "$ENV_DIR/terraform.tfvars" ]]; then
        error "Terraform variables file not found: $ENV_DIR/terraform.tfvars"
        log "Contents of $ENV_DIR:"
        ls -la "$ENV_DIR/" || true
        exit 1
    fi
    
    if [[ ! -d "$TF_DIR" ]]; then
        error "Terraform deployment directory not found: $TF_DIR"
        exit 1
    fi
    
    success "Environment validation passed"
}

# Deploy Terraform infrastructure
deploy_terraform() {
    case "$ENVIRONMENT" in
        dev|staging)
            log "🔵 Deploying Azure infrastructure for $ENVIRONMENT..."
            deploy_azure_terraform
            ;;
        prod)
            log "🟢 Deploying AWS infrastructure for $ENVIRONMENT..."
            deploy_aws_terraform
            ;;
    esac
}

# Deploy Azure infrastructure for dev/staging
deploy_azure_terraform() {
    cd "$TF_DIR"
    
    # Initialize Terraform
    log "Initializing Azure Terraform..."
    if [[ -f "../../backends/${ENVIRONMENT}-backend.hcl" ]]; then
        terraform init -backend-config="../../backends/${ENVIRONMENT}-backend.hcl"
    else
        warn "Backend config not found, using local state"
        terraform init
    fi
    
    # Plan
    log "Planning Azure Terraform deployment..."
    terraform plan -var-file="$ENV_DIR/terraform.tfvars" -out=tfplan
    
    # Apply
    log "Applying Azure Terraform changes..."
    terraform apply tfplan
    
    success "Azure Terraform deployment completed"
}

# Deploy AWS infrastructure for prod
deploy_aws_terraform() {
    cd "$TF_DIR"
    
    # Initialize Terraform
    log "Initializing AWS Terraform..."
    if [[ -f "../../backends/${ENVIRONMENT}-backend.hcl" ]]; then
        terraform init -backend-config="../../backends/${ENVIRONMENT}-backend.hcl"
    else
        warn "Backend config not found, using local state"
        terraform init
    fi
    
    # Plan
    log "Planning AWS Terraform deployment..."
    terraform plan -var-file="$ENV_DIR/terraform.tfvars" -out=tfplan
    
    # Apply
    log "Applying AWS Terraform changes..."
    terraform apply tfplan
    
    success "AWS Terraform deployment completed"
}

# Deploy with Ansible (if configured)
deploy_ansible() {
    local ansible_dir="$PROJECT_ROOT/ansible"
    local inventory_file="$ansible_dir/inventory/$ENVIRONMENT/hosts.yml"
    
    if [[ ! -d "$ansible_dir" ]]; then
        warn "Ansible directory not found, skipping Ansible deployment"
        return 0
    fi
    
    if [[ ! -f "$inventory_file" ]]; then
        warn "Ansible inventory not found: $inventory_file, skipping Ansible deployment"
        return 0
    fi
    
    log "🔧 Deploying with Ansible for $ENVIRONMENT..."
    
    # Check if vault password file exists
    local vault_file="$ENV_DIR/secrets/.vault_pass"
    local vault_args=""
    
    if [[ -f "$vault_file" ]]; then
        vault_args="--vault-password-file $vault_file"
    else
        warn "Vault password file not found, continuing without vault"
    fi
    
    # Run Ansible playbook
    ansible-playbook -i "$inventory_file" \
        -e "@$ENV_DIR/ansible-vars.yml" \
        $vault_args \
        "$ansible_dir/playbooks/deploy-complete.yml" || {
        warn "Ansible deployment failed or not configured"
    }
    
    success "Ansible deployment completed"
}

# Main deployment function
main() {
    if [[ "$REQUESTED_ENVIRONMENT" != "dev" ]]; then
        log "🌟 Starting deployment for requested environment: $REQUESTED_ENVIRONMENT (redirected to dev)"
    else
        log "🌟 Starting full deployment for environment: $ENVIRONMENT"
    fi
    
    # Final path verification
    log "🔍 Final path verification:"
    log "  Project root: $PROJECT_ROOT"
    log "  Environment dir: $ENV_DIR"
    log "  Terraform dir: $TF_DIR"
    
    if [[ ! -d "$TF_DIR" ]]; then
        error "❌ CRITICAL: Terraform directory still not found after all attempts: $TF_DIR"
        error "Available directories in project root:"
        ls -la "$PROJECT_ROOT/" 2>/dev/null || ls -la
        exit 1
    fi
    
    if [[ ! -d "$ENV_DIR" ]]; then
        error "❌ CRITICAL: Environment directory not found: $ENV_DIR"
        error "Available environments:"
        ls -la "$PROJECT_ROOT/envs/" 2>/dev/null || ls -la "envs/" 2>/dev/null || ls -la
        exit 1
    fi
    
    success "✅ Path verification passed"
    
    validate_environment
    deploy_terraform
    deploy_ansible
    
    success "✅ Full deployment completed for $ENVIRONMENT!"
    log "Infrastructure should be accessible according to your DNS configuration"
}

# Execute main function
main "$@" 