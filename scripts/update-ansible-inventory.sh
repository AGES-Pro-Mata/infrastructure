#!/bin/bash
# Update Ansible inventory with latest Terraform outputs
# This script extracts IP addresses and SSH keys from Terraform and updates Ansible variables

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVIRONMENT="${1:-dev}"
TF_DIR="$PROJECT_ROOT/terraform/deployments/$ENVIRONMENT"
ANSIBLE_VARS_FILE="$PROJECT_ROOT/ansible/inventory/$ENVIRONMENT/group_vars/ansible_group_vars.yml"

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if Terraform state exists
if [[ ! -d "$TF_DIR" ]]; then
    error "Terraform directory not found: $TF_DIR"
    exit 1
fi

# Check if Ansible variables file exists
if [[ ! -f "$ANSIBLE_VARS_FILE" ]]; then
    error "Ansible variables file not found: $ANSIBLE_VARS_FILE"
    exit 1
fi

log "🔄 Updating Ansible inventory with Terraform outputs..."

cd "$TF_DIR"

# Extract IP addresses from Terraform outputs
log "Extracting IP addresses from Terraform..."

MANAGER_PUBLIC_IP=$(terraform output swarm_manager_public_ip 2>/dev/null || echo "")
MANAGER_PRIVATE_IP=$(terraform output swarm_manager_private_ip 2>/dev/null || echo "")
WORKER_PUBLIC_IP=$(terraform output swarm_worker_public_ip 2>/dev/null || echo "")
WORKER_PRIVATE_IP=$(terraform output swarm_worker_private_ip 2>/dev/null || echo "")

# Validate that we got the IP addresses
if [[ -z "$MANAGER_PUBLIC_IP" || -z "$MANAGER_PRIVATE_IP" || -z "$WORKER_PUBLIC_IP" || -z "$WORKER_PRIVATE_IP" ]]; then
    error "Failed to extract IP addresses from Terraform outputs"
    echo "Manager Public IP: $MANAGER_PUBLIC_IP"
    echo "Manager Private IP: $MANAGER_PRIVATE_IP"
    echo "Worker Public IP: $WORKER_PUBLIC_IP"
    echo "Worker Private IP: $WORKER_PRIVATE_IP"
    exit 1
fi

log "Found IP addresses:"
echo "  Manager Public: $MANAGER_PUBLIC_IP"
echo "  Manager Private: $MANAGER_PRIVATE_IP"
echo "  Worker Public: $WORKER_PUBLIC_IP"
echo "  Worker Private: $WORKER_PRIVATE_IP"

# Update Ansible variables file
log "Updating Ansible variables file..."

# Create backup
cp "$ANSIBLE_VARS_FILE" "${ANSIBLE_VARS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Update the IP addresses in the Ansible variables file
sed -i "s/manager_public_ip:.*/manager_public_ip: \"$MANAGER_PUBLIC_IP\"/" "$ANSIBLE_VARS_FILE"
sed -i "s/manager_private_ip:.*/manager_private_ip: \"$MANAGER_PRIVATE_IP\"/" "$ANSIBLE_VARS_FILE"
sed -i "s/worker_public_ip:.*/worker_public_ip: \"$WORKER_PUBLIC_IP\"/" "$ANSIBLE_VARS_FILE"
sed -i "s/worker_private_ip:.*/worker_private_ip: \"$WORKER_PRIVATE_IP\"/" "$ANSIBLE_VARS_FILE"

# Verify the updates
if grep -q "$MANAGER_PUBLIC_IP" "$ANSIBLE_VARS_FILE"; then
    success "Ansible variables updated successfully"
else
    error "Failed to update Ansible variables"
    exit 1
fi

log "✅ Ansible inventory updated with latest Terraform outputs"
echo ""
echo "Updated variables:"
echo "  manager_public_ip: $MANAGER_PUBLIC_IP"
echo "  manager_private_ip: $MANAGER_PRIVATE_IP"
echo "  worker_public_ip: $WORKER_PUBLIC_IP"
echo "  worker_private_ip: $WORKER_PRIVATE_IP"
echo ""
echo "You can now run Ansible playbooks with the updated inventory."
