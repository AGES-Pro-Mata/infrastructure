#!/bin/bash
# Standalone SSH Setup Script for Pro-Mata Infrastructure
# This script extracts SSH keys from deployed infrastructure and sets up access

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
ENVIRONMENT="${1:-dev}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"
TF_DIR="$PROJECT_ROOT/terraform/deployments/$ENVIRONMENT"
KEYS_DIR="$PROJECT_ROOT/ssh-keys"

# Functions
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
validate_setup() {
    log "Validating environment: $ENVIRONMENT"
    
    if [[ ! -d "$ENV_DIR" ]]; then
        error "Environment directory not found: $ENV_DIR"
        exit 1
    fi
    
    if [[ ! -d "$TF_DIR" ]]; then
        error "Terraform deployment directory not found: $TF_DIR"
        exit 1
    fi
    
    # Check if Terraform state exists
    if [[ ! -f "$TF_DIR/terraform.tfstate" ]]; then
        error "Terraform state file not found. Has infrastructure been deployed?"
        error "Expected: $TF_DIR/terraform.tfstate"
        exit 1
    fi
    
    success "Environment validation passed"
}

# Extract SSH keys from Terraform
extract_ssh_keys() {
    log "🔑 Extracting SSH keys from Terraform outputs..."
    
    # Create SSH keys directory
    mkdir -p "$KEYS_DIR"
    
    cd "$TF_DIR"
    
    # Extract private key
    if terraform output -json ssh_private_key &>/dev/null; then
        log "Extracting SSH private key..."
        terraform output -json ssh_private_key | jq -r '.value' > "$KEYS_DIR/${ENVIRONMENT}-ssh-key"
        chmod 600 "$KEYS_DIR/${ENVIRONMENT}-ssh-key"
        success "SSH private key saved to: $KEYS_DIR/${ENVIRONMENT}-ssh-key"
    else
        error "SSH private key not found in Terraform outputs"
        exit 1
    fi
    
    # Extract public key
    if terraform output -json ssh_public_key &>/dev/null; then
        log "Extracting SSH public key..."
        terraform output -json ssh_public_key | jq -r '.value' > "$KEYS_DIR/${ENVIRONMENT}-ssh-key.pub"
        chmod 644 "$KEYS_DIR/${ENVIRONMENT}-ssh-key.pub"
        success "SSH public key saved to: $KEYS_DIR/${ENVIRONMENT}-ssh-key.pub"
    else
        warn "SSH public key not found in Terraform outputs"
    fi
}

# Create SSH config file
create_ssh_config() {
    log "Creating SSH config file..."
    
    cd "$TF_DIR"
    
    cat > "$KEYS_DIR/ssh-config" << EOF
# SSH Config for ${ENVIRONMENT} environment
# Generated on $(date)
# Usage: ssh -F $KEYS_DIR/ssh-config manager-${ENVIRONMENT}
#        ssh -F $KEYS_DIR/ssh-config worker-${ENVIRONMENT}

Host manager-${ENVIRONMENT}
    HostName $(terraform output -json swarm_manager_public_ip 2>/dev/null | jq -r '.value' 2>/dev/null || echo "IP_NOT_FOUND")
    User ubuntu
    IdentityFile $KEYS_DIR/${ENVIRONMENT}-ssh-key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host worker-${ENVIRONMENT}
    HostName $(terraform output -json swarm_worker_public_ip 2>/dev/null | jq -r '.value' 2>/dev/null || echo "IP_NOT_FOUND")
    User ubuntu
    IdentityFile $KEYS_DIR/${ENVIRONMENT}-ssh-key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host swarm-${ENVIRONMENT}
    HostName $(terraform output -json swarm_manager_public_ip 2>/dev/null | jq -r '.value' 2>/dev/null || echo "IP_NOT_FOUND")
    User ubuntu
    IdentityFile $KEYS_DIR/${ENVIRONMENT}-ssh-key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    
    success "SSH config created: $KEYS_DIR/ssh-config"
}

# Setup SSH access
setup_ssh_access() {
    local key_file="$KEYS_DIR/${ENVIRONMENT}-ssh-key"
    
    log "🔐 Setting up SSH access..."
    
    # Start SSH agent if not running
    if [[ -z "${SSH_AGENT_PID:-}" ]]; then
        log "Starting SSH agent..."
        eval "$(ssh-agent -s)"
    fi
    
    # Add key to SSH agent
    log "Adding SSH key to agent..."
    if ssh-add "$key_file"; then
        success "SSH key added to agent successfully"
    else
        error "Failed to add SSH key to agent"
        exit 1
    fi
}

# Create setup script for future use
create_setup_script() {
    log "Creating reusable setup script..."
    
    cat > "$KEYS_DIR/setup-ssh.sh" << EOF
#!/bin/bash
# SSH Setup Script for Pro-Mata Infrastructure
# Generated on $(date)

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
EOF
    
    chmod +x "$KEYS_DIR/setup-ssh.sh"
    success "Setup script created: $KEYS_DIR/setup-ssh.sh"
}

# Test SSH connections
test_connections() {
    log "🧪 Testing SSH connections..."
    
    local config_file="$KEYS_DIR/ssh-config"
    
    echo "Testing manager connection..."
    if ssh -F "$config_file" -o ConnectTimeout=10 "manager-${ENVIRONMENT}" "echo '✅ Manager VM: OK' && uptime" 2>/dev/null; then
        success "Manager VM connection successful"
    else
        warn "Manager VM connection failed"
    fi
    
    echo "Testing worker connection..."
    if ssh -F "$config_file" -o ConnectTimeout=10 "worker-${ENVIRONMENT}" "echo '✅ Worker VM: OK' && uptime" 2>/dev/null; then
        success "Worker VM connection successful"
    else
        warn "Worker VM connection failed"
    fi
}

# Main function
main() {
    echo -e "${BLUE}🚀 Pro-Mata SSH Setup for ${ENVIRONMENT} Environment${NC}"
    echo "==============================================="
    
    validate_setup
    extract_ssh_keys
    create_ssh_config
    create_setup_script
    setup_ssh_access
    test_connections
    
    echo ""
    success "SSH setup completed successfully!"
    echo ""
    echo -e "${GREEN}📋 Summary:${NC}"
    echo "SSH Keys Location: $KEYS_DIR/"
    echo "SSH Config File:   $KEYS_DIR/ssh-config"
    echo "Setup Script:      $KEYS_DIR/setup-ssh.sh"
    echo ""
    echo -e "${GREEN}🔗 Quick Connect:${NC}"
    echo "ssh -F $KEYS_DIR/ssh-config manager-${ENVIRONMENT}"
    echo "ssh -F $KEYS_DIR/ssh-config worker-${ENVIRONMENT}"
    echo ""
    echo -e "${YELLOW}💡 Tip: For persistent access, add this to your ~/.bashrc or ~/.zshrc:${NC}"
    echo "eval \"\$(ssh-agent -s)\""
    echo "ssh-add $KEYS_DIR/${ENVIRONMENT}-ssh-key"
}

# Execute main function
main "$@"
