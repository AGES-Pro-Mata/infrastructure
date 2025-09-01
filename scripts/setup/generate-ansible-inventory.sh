#!/bin/bash
# Generate Ansible inventory from Terraform outputs
# Usage: ./generate-ansible-inventory.sh [environment]

set -euo pipefail

ENV=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/environments/$ENV/azure"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

echo "🔧 Generating Ansible inventory from Terraform outputs..."

# Check if Terraform has been applied
if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    echo "❌ Terraform state not found. Please run 'terraform apply' first."
    exit 1
fi

# Get Terraform outputs
cd "$TERRAFORM_DIR"
MANAGER_IP=$(terraform output -raw swarm_manager_public_ip)
PRIVATE_IP=$(terraform output -raw swarm_manager_private_ip)
SSH_PRIVATE_KEY=$(terraform output -raw ssh_private_key)

# Create SSH key directory and file
SSH_KEY_DIR="$PROJECT_ROOT/.ssh"
SSH_KEY_FILE="$SSH_KEY_DIR/promata-$ENV"

mkdir -p "$SSH_KEY_DIR"
echo "$SSH_PRIVATE_KEY" > "$SSH_KEY_FILE"
chmod 600 "$SSH_KEY_FILE"

echo "🔑 SSH key saved to: $SSH_KEY_FILE"

# Generate dynamic inventory
INVENTORY_FILE="$ANSIBLE_DIR/inventory/$ENV/hosts.yml"
mkdir -p "$(dirname "$INVENTORY_FILE")"

cat > "$INVENTORY_FILE" << EOF
# Generated Ansible Inventory for Pro-Mata $ENV Environment
# Auto-generated from Terraform outputs - do not edit manually
---
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: "$SSH_KEY_FILE"
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    env: $ENV
    domain_name: "${MANAGER_IP}.nip.io"
    manager_public_ip: "$MANAGER_IP"
    manager_private_ip: "$PRIVATE_IP"
  
  children:
    promata_$ENV:
      children:
        managers:
          hosts:
            swarm-manager:
              ansible_host: "$MANAGER_IP"
              private_ip: "$PRIVATE_IP"
              node_role: manager
              
        workers:
          hosts: {}
EOF

echo "✅ Ansible inventory generated: $INVENTORY_FILE"
echo "📍 Manager IP: $MANAGER_IP"
echo "🔐 SSH Key: $SSH_KEY_FILE"
echo ""
echo "Test connection with:"
echo "  ansible all -i $INVENTORY_FILE -m ping"