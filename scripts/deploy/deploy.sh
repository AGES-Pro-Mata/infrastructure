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

# Logging functions (defined early for use throughout script)
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

# Fix for GitHub Actions path duplication - more robust approach
if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
    # In GitHub Actions, the workspace is /home/runner/work/{repo}/{repo}
    CURRENT_DIR="$(pwd)"
    log "Current directory in GitHub Actions: $CURRENT_DIR"
    log "Script directory: $SCRIPT_DIR"
    
    # Check if we're in the duplicated path structure
    if [[ "$CURRENT_DIR" == *"/infrastructure/infrastructure" ]]; then
        # We're in the duplicated structure, use the inner infrastructure directory
        PROJECT_ROOT="$CURRENT_DIR"
        log "Using current directory as project root (inner infrastructure): $PROJECT_ROOT"
    elif [[ "$CURRENT_DIR" == *"/infrastructure" ]] && [[ ! "$CURRENT_DIR" == *"/infrastructure/infrastructure" ]]; then
        # We're in the correct infrastructure directory
        PROJECT_ROOT="$CURRENT_DIR"
        log "Using current directory as project root: $PROJECT_ROOT"
    else
        # Try to find infrastructure directory
        if [[ -d "$CURRENT_DIR/infrastructure" ]]; then
            PROJECT_ROOT="$CURRENT_DIR/infrastructure"
            log "Found infrastructure subdirectory: $PROJECT_ROOT"
        else
            # Fallback to script-based detection
            PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
            log "Using script-based detection: $PROJECT_ROOT"
        fi
    fi
else
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"
TF_DIR="$PROJECT_ROOT/terraform/deployments/$ENVIRONMENT"

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
        log "✅ Terraform directory found at: $PROJECT_ROOT/terraform"
        log "Contents of terraform directory:"
        ls -la "$PROJECT_ROOT/terraform/" || true
        if [[ -d "$PROJECT_ROOT/terraform/deployments" ]]; then
            log "✅ Deployments directory found"
            log "Contents of terraform/deployments:"
            ls -la "$PROJECT_ROOT/terraform/deployments/" || true
            if [[ -d "$PROJECT_ROOT/terraform/deployments/dev" ]]; then
                log "✅ Dev deployment directory found"
                log "Contents of terraform/deployments/dev:"
                ls -la "$PROJECT_ROOT/terraform/deployments/dev/" || true
            else
                error "❌ Dev deployment directory not found: $PROJECT_ROOT/terraform/deployments/dev"
            fi
        else
            error "❌ Deployments directory not found: $PROJECT_ROOT/terraform/deployments"
        fi
    else
        error "❌ Terraform directory not found at: $PROJECT_ROOT/terraform"
        log "Available directories in project root:"
        ls -la "$PROJECT_ROOT/" || true
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
    
    # Extract and save SSH keys after successful deployment
    extract_ssh_keys
}

# Extract and save SSH keys from Terraform outputs
extract_ssh_keys() {
    log "🔑 Extracting SSH keys from Terraform outputs..."
    
    # Create SSH keys directory in project root
    local keys_dir="$PROJECT_ROOT/ssh-keys"
    mkdir -p "$keys_dir"
    
    cd "$TF_DIR"
    
    # Extract private key
    if terraform output -json ssh_private_key &>/dev/null; then
        log "Extracting SSH private key..."
        terraform output ssh_private_key > "$keys_dir/${ENVIRONMENT}-ssh-key"
        chmod 600 "$keys_dir/${ENVIRONMENT}-ssh-key"
        success "SSH private key saved to: $keys_dir/${ENVIRONMENT}-ssh-key"
    else
        warn "SSH private key not found in Terraform outputs"
    fi
    
    # Extract public key
    if terraform output -json ssh_public_key &>/dev/null; then
        log "Extracting SSH public key..."
        terraform output ssh_public_key > "$keys_dir/${ENVIRONMENT}-ssh-key.pub"
        chmod 644 "$keys_dir/${ENVIRONMENT}-ssh-key.pub"
        success "SSH public key saved to: $keys_dir/${ENVIRONMENT}-ssh-key.pub"
    else
        warn "SSH public key not found in Terraform outputs"
    fi
    
    # Create SSH config file for easy access
    create_ssh_config "$keys_dir"
    
    # Create setup script for SSH access
    create_ssh_setup_script "$keys_dir"
    
    success "SSH keys extraction completed"
}

# Create SSH config file for easy VM access
create_ssh_config() {
    local keys_dir="$1"
    local ssh_config="$keys_dir/ssh-config"
    
    log "Creating SSH config file..."
    
    cat > "$ssh_config" << EOF
# SSH Config for ${ENVIRONMENT} environment
# Generated on $(date)
# Usage: ssh -F $ssh_config manager-${ENVIRONMENT}
#        ssh -F $ssh_config worker-${ENVIRONMENT}

Host manager-${ENVIRONMENT}
    HostName $(terraform output swarm_manager_public_ip 2>/dev/null || echo "IP_NOT_FOUND")
    User ubuntu
    IdentityFile $keys_dir/${ENVIRONMENT}-ssh-key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host worker-${ENVIRONMENT}
    HostName $(terraform output swarm_worker_public_ip 2>/dev/null || echo "IP_NOT_FOUND")
    User ubuntu
    IdentityFile $keys_dir/${ENVIRONMENT}-ssh-key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host swarm-${ENVIRONMENT}
    HostName $(terraform output swarm_manager_public_ip 2>/dev/null || echo "IP_NOT_FOUND")
    User ubuntu
    IdentityFile $keys_dir/${ENVIRONMENT}-ssh-key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    
    success "SSH config created: $ssh_config"
}

# Create setup script for SSH access
create_ssh_setup_script() {
    local keys_dir="$1"
    local setup_script="$keys_dir/setup-ssh.sh"
    
    log "Creating SSH setup script..."
    
    # Create README
    cat > "$keys_dir/README.md" << EOF
# SSH Access for Pro-Mata ${ENVIRONMENT} Infrastructure

This directory contains SSH keys and configuration for accessing your deployed VMs.

## Files

- \`${ENVIRONMENT}-ssh-key\` - Private SSH key (keep secure!)
- \`${ENVIRONMENT}-ssh-key.pub\` - Public SSH key
- \`ssh-config\` - SSH configuration file for easy access
- \`setup-ssh.sh\` - Script to set up SSH access

## Quick Setup

Run the setup script to configure SSH access:

\`\`\`bash
./setup-ssh.sh
\`\`\`

Or manually:

\`\`\`bash
# Start SSH agent
eval "\$(ssh-agent -s)"

# Add the key
ssh-add ${ENVIRONMENT}-ssh-key
\`\`\`

## Connecting to VMs

### Using SSH config (recommended):

\`\`\`bash
# Connect to manager (Docker Swarm manager)
ssh -F ssh-config manager-${ENVIRONMENT}

# Connect to worker
ssh -F ssh-config worker-${ENVIRONMENT}

# Connect to swarm (alias for manager)
ssh -F ssh-config swarm-${ENVIRONMENT}
\`\`\`

### Direct connection:

\`\`\`bash
# Manager VM
ssh ubuntu@<manager-ip>

# Worker VM  
ssh ubuntu@<worker-ip>
\`\`\`

## VM Information

Manager VM: Ubuntu 22.04 LTS
Worker VM:  Ubuntu 22.04 LTS

## Security Notes

- Keep the private key file (\`${ENVIRONMENT}-ssh-key\`) secure
- Never commit private keys to version control
- The \`.gitignore\` file excludes SSH keys from being committed

## Troubleshooting

If you get "Permission denied" errors:

1. Ensure SSH agent is running: \`eval "\$(ssh-agent -s)"\`
2. Add key to agent: \`ssh-add ${ENVIRONMENT}-ssh-key\`
3. Check key permissions: \`chmod 600 ${ENVIRONMENT}-ssh-key\`

## Getting VM IPs

If you need the current VM IPs:

\`\`\`bash
cd ../terraform/deployments/${ENVIRONMENT}
terraform output swarm_manager_public_ip
terraform output swarm_worker_public_ip
\`\`\`
EOF
    
    cat > "$setup_script" << EOF
#!/bin/bash
# SSH Setup Script for Pro-Mata Infrastructure
# This script sets up SSH access to deployed VMs

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
KEY_FILE="\$SCRIPT_DIR/${ENVIRONMENT}-ssh-key"
CONFIG_FILE="\$SCRIPT_DIR/ssh-config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\${BLUE}🔑 Setting up SSH access for Pro-Mata ${ENVIRONMENT} infrastructure...\${NC}"

# Check if key file exists
if [[ ! -f "\$KEY_FILE" ]]; then
    echo -e "\${RED}❌ SSH key file not found: \$KEY_FILE\${NC}"
    echo "Please run the deployment script first to extract SSH keys."
    exit 1
fi

# Start SSH agent if not running
if [[ -z "\${SSH_AGENT_PID:-}" ]]; then
    echo "Starting SSH agent..."
    eval "\$(ssh-agent -s)"
fi

# Add key to SSH agent
echo "Adding SSH key to agent..."
if ssh-add "\$KEY_FILE"; then
    echo -e "\${GREEN}✅ SSH key added to agent successfully\${NC}"
else
    echo -e "\${RED}❌ Failed to add SSH key to agent\${NC}"
    exit 1
fi

echo ""
echo -e "\${GREEN}✅ SSH access setup complete!\${NC}"
echo ""
echo "You can now connect to your VMs using:"
echo "  ssh -F \$CONFIG_FILE manager-${ENVIRONMENT}"
echo "  ssh -F \$CONFIG_FILE worker-${ENVIRONMENT}"
echo "  ssh -F \$CONFIG_FILE swarm-${ENVIRONMENT}"
echo ""
echo "Or directly with the IPs shown in Terraform outputs:"
echo "  ssh ubuntu@<VM_IP>"
echo ""
echo "To make this permanent, add the following to your ~/.bashrc or ~/.zshrc:"
echo "  eval \"\$(ssh-agent -s)\""
echo "  ssh-add \$HOME/path/to/your/project/ssh-keys/${ENVIRONMENT}-ssh-key"
EOF
    
    chmod +x "$setup_script"
    success "SSH setup script and documentation created"
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
    setup_ssh_access
    deploy_ansible
    
    success "✅ Full deployment completed for $ENVIRONMENT!"
    log "Infrastructure should be accessible according to your DNS configuration"
    log "SSH keys have been saved to: $PROJECT_ROOT/ssh-keys/"
    log "Run: source $PROJECT_ROOT/ssh-keys/setup-ssh.sh"
    log "Then use: ssh -F $PROJECT_ROOT/ssh-keys/ssh-config manager-dev"
}

# Setup SSH access after deployment
setup_ssh_access() {
    local keys_dir="$PROJECT_ROOT/ssh-keys"
    local key_file="$keys_dir/${ENVIRONMENT}-ssh-key"
    
    if [[ ! -f "$key_file" ]]; then
        warn "SSH key file not found, skipping SSH setup"
        return 0
    fi
    
    log "🔐 Setting up SSH access..."
    
    # Start SSH agent if not running
    if [[ -z "${SSH_AGENT_PID:-}" ]]; then
        log "Starting SSH agent..."
        eval "$(ssh-agent -s)" || {
            warn "Failed to start SSH agent"
            return 0
        }
    fi
    
    # Add key to SSH agent
    log "Adding SSH key to agent..."
    if ssh-add "$key_file" 2>/dev/null; then
        success "SSH key added to agent successfully"
    else
        warn "Failed to add SSH key to agent (may already be added)"
    fi
    
    success "SSH access setup completed"
}

# Execute main function
main "$@" 