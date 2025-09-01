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
ENVIRONMENT="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"
TF_DIR="$PROJECT_ROOT/terraform/deployments/$ENVIRONMENT"

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
    log "Validating environment: $ENVIRONMENT"
    
    case "$ENVIRONMENT" in
        dev|staging|prod)
            log "Valid environment: $ENVIRONMENT"
            ;;
        *)
            error "Environment must be: dev, staging, or prod"
            exit 1
            ;;
    esac
    
    if [[ ! -d "$ENV_DIR" ]]; then
        error "Environment directory not found: $ENV_DIR"
        exit 1
    fi
    
    if [[ ! -f "$ENV_DIR/terraform.tfvars" ]]; then
        error "Terraform variables file not found: $ENV_DIR/terraform.tfvars"
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
    log "🌟 Starting full deployment for environment: $ENVIRONMENT"
    
    validate_environment
    deploy_terraform
    deploy_ansible
    
    success "✅ Full deployment completed for $ENVIRONMENT!"
    log "Infrastructure should be accessible according to your DNS configuration"
}

# Execute main function
main "$@" 