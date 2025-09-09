#!/bin/bash
# Terraform State Retrieval and Output Extraction Script
# Handles remote Azure backend and extracts outputs for Ansible
# Usage: ./retrieve-terraform-state.sh [environment]

set -euo pipefail

# Configuration
ENV=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TERRAFORM_DIR="$PROJECT_ROOT/iac/deployments/$ENV"
OUTPUT_DIR="$PROJECT_ROOT/cac/inventory/$ENV"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }

# Check if Terraform directory exists
check_terraform_dir() {
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        error "Terraform directory not found: $TERRAFORM_DIR"
    fi
    
    if [[ ! -f "$TERRAFORM_DIR/main.tf" ]]; then
        error "Terraform configuration not found in: $TERRAFORM_DIR"
    fi
}

# Initialize Terraform if needed
init_terraform() {
    info "🔧 Checking Terraform initialization..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if .terraform directory exists
    if [[ ! -d ".terraform" ]]; then
        log "Initializing Terraform..."
        terraform init || error "Failed to initialize Terraform"
    else
        log "✅ Terraform already initialized"
    fi
}

# Refresh and retrieve outputs
get_terraform_outputs() {
    info "📊 Retrieving Terraform outputs..."
    
    cd "$TERRAFORM_DIR"
    
    # Refresh state first (safe operation)
    log "Refreshing Terraform state..."
    terraform refresh --auto-approve || warn "State refresh failed, continuing with existing state"
    
    # Check if state has resources
    if ! terraform show >/dev/null 2>&1; then
        error "No Terraform state found or state is empty. Please deploy infrastructure first."
    fi
    
    # Get outputs as JSON
    log "Extracting outputs..."
    if ! terraform output -json > /tmp/terraform-outputs-$ENV.json; then
        error "Failed to extract Terraform outputs"
    fi
    
    log "✅ Outputs extracted to: /tmp/terraform-outputs-$ENV.json"
}

# Generate Ansible inventory from outputs
generate_ansible_inventory() {
    info "🔧 Generating Ansible inventory..."
    
    local outputs_file="/tmp/terraform-outputs-$ENV.json"
    
    if [[ ! -f "$outputs_file" ]]; then
        error "Outputs file not found: $outputs_file"
    fi
    
    # Extract key values using jq
    if ! command -v jq >/dev/null 2>&1; then
        error "jq is required but not installed. Please install jq."
    fi
    
    # Parse outputs
    local manager_public_ip=$(jq -r '.swarm_manager_public_ip.value // .manager_public_ip.value // empty' "$outputs_file")
    local manager_private_ip=$(jq -r '.swarm_manager_private_ip.value // .manager_private_ip.value // empty' "$outputs_file")
    local worker_public_ip=$(jq -r '.swarm_worker_public_ip.value // .worker_public_ip.value // empty' "$outputs_file")
    local worker_private_ip=$(jq -r '.swarm_worker_private_ip.value // .worker_private_ip.value // empty' "$outputs_file")
    local ssh_private_key=$(jq -r '.ssh_private_key.value // empty' "$outputs_file")
    local domain_name=$(jq -r '.domain_name.value // empty' "$outputs_file")
    
    # Validate required outputs
    if [[ -z "$manager_public_ip" ]]; then
        error "Manager public IP not found in Terraform outputs"
    fi
    
    if [[ -z "$manager_private_ip" ]]; then
        error "Manager private IP not found in Terraform outputs"
    fi
    
    log "Manager Public IP: $manager_public_ip"
    log "Manager Private IP: $manager_private_ip"
    
    # Setup SSH key if available
    local ssh_key_file=""
    if [[ -n "$ssh_private_key" && "$ssh_private_key" != "null" ]]; then
        local ssh_key_dir="$PROJECT_ROOT/.ssh"
        ssh_key_file="$ssh_key_dir/promata-$ENV"
        
        mkdir -p "$ssh_key_dir"
        echo "$ssh_private_key" > "$ssh_key_file"
        chmod 600 "$ssh_key_file"
        
        log "🔑 SSH key saved to: $ssh_key_file"
    else
        warn "No SSH private key found in outputs, using default SSH configuration"
        ssh_key_file="~/.ssh/id_rsa"
    fi
    
    # Set domain name
    if [[ -z "$domain_name" || "$domain_name" == "null" ]]; then
        domain_name="${manager_public_ip}.nip.io"
        log "Using default domain: $domain_name"
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Generate inventory file
    local inventory_file="$OUTPUT_DIR/hosts.yml"
    
    cat > "$inventory_file" << EOF
# Generated Ansible Inventory for Pro-Mata $ENV Environment
# Auto-generated from Terraform outputs - do not edit manually
# Generated: $(date)
---
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: "$ssh_key_file"
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    env: $ENV
    domain_name: "$domain_name"
    manager_public_ip: "$manager_public_ip"
    manager_private_ip: "$manager_private_ip"
EOF

    # Add worker if available
    if [[ -n "$worker_public_ip" && "$worker_public_ip" != "null" ]]; then
        cat >> "$inventory_file" << EOF
    worker_public_ip: "$worker_public_ip"
    worker_private_ip: "$worker_private_ip"
EOF
    fi

    cat >> "$inventory_file" << EOF
  
  children:
    promata_$ENV:
      children:
        managers:
          hosts:
            swarm-manager:
              ansible_host: "$manager_public_ip"
              private_ip: "$manager_private_ip"
              node_role: manager
EOF

    # Add workers section
    if [[ -n "$worker_public_ip" && "$worker_public_ip" != "null" ]]; then
        cat >> "$inventory_file" << EOF
              
        workers:
          hosts:
            swarm-worker:
              ansible_host: "$worker_public_ip"
              private_ip: "$worker_private_ip"
              node_role: worker
              ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -q ubuntu@$manager_public_ip"'
EOF
    else
        cat >> "$inventory_file" << EOF
              
        workers:
          hosts: {}
EOF
    fi
    
    log "✅ Ansible inventory generated: $inventory_file"
}

# Generate group vars
generate_group_vars() {
    info "📝 Generating group variables..."
    
    local outputs_file="/tmp/terraform-outputs-$ENV.json"
    local group_vars_dir="$OUTPUT_DIR/group_vars"
    local all_vars_file="$group_vars_dir/all.yml"
    
    mkdir -p "$group_vars_dir"
    
    # Extract additional variables
    local resource_group=$(jq -r '.resource_group_name.value // empty' "$outputs_file")
    local storage_account=$(jq -r '.storage_account_name.value // empty' "$outputs_file")
    
    cat > "$all_vars_file" << EOF
# Group Variables for Pro-Mata $ENV Environment
# Auto-generated from Terraform outputs
# Generated: $(date)
---
# Environment Configuration
environment: $ENV
project_name: promata

# Domain Configuration
domain_name: "{{ domain_name }}"

# Infrastructure Details
resource_group_name: "${resource_group:-""}"
storage_account_name: "${storage_account:-""}"

# Docker Swarm Configuration
swarm_manager_ip: "{{ manager_public_ip }}"
swarm_manager_private_ip: "{{ manager_private_ip }}"

# Application Configuration
app_version: latest
docker_compose_version: "v2.20.2"

# Stack Environment Variables
stack_environment:
  ENVIRONMENT: "$ENV"
  DOMAIN_NAME: "{{ domain_name }}"
  MANAGER_IP: "{{ manager_public_ip }}"
  POSTGRES_DB: "promata_$ENV"
  POSTGRES_USER: promata
  TRAEFIK_LOG_LEVEL: INFO
  ACME_EMAIL: "admin@{{ domain_name }}"

# Monitoring Configuration
monitoring_enabled: true
backup_enabled: true

# Security Configuration
ssl_enabled: true
firewall_enabled: true
EOF
    
    log "✅ Group variables generated: $all_vars_file"
}

# Test connectivity
test_connectivity() {
    info "🔍 Testing connectivity to infrastructure..."
    
    local inventory_file="$OUTPUT_DIR/hosts.yml"
    
    if [[ ! -f "$inventory_file" ]]; then
        error "Inventory file not found: $inventory_file"
    fi
    
    # Test with ansible ping
    if command -v ansible >/dev/null 2>&1; then
        log "Testing Ansible connectivity..."
        if ansible all -i "$inventory_file" -m ping --one-line; then
            log "✅ Ansible connectivity test passed"
        else
            warn "⚠️ Ansible connectivity test failed - check SSH configuration"
        fi
    else
        warn "Ansible not installed, skipping connectivity test"
    fi
}

# Show summary
show_summary() {
    info "📊 State Retrieval Summary"
    echo ""
    log "🎯 Environment: $ENV"
    log "📁 Terraform Directory: $TERRAFORM_DIR"
    log "📁 Ansible Directory: $OUTPUT_DIR"
    echo ""
    
    if [[ -f "$OUTPUT_DIR/hosts.yml" ]]; then
        log "📋 Generated Files:"
        log "   - Inventory: $OUTPUT_DIR/hosts.yml"
        log "   - Group Vars: $OUTPUT_DIR/group_vars/all.yml"
        echo ""
        
        log "🚀 Next Steps:"
        log "   1. Test connectivity: ansible all -i $OUTPUT_DIR/hosts.yml -m ping"
        log "   2. Run playbook: ansible-playbook -i $OUTPUT_DIR/hosts.yml ansible/playbooks/site.yml"
        log "   3. Or use Makefile: make deploy-ansible ENV=$ENV"
    fi
    
    echo ""
}

# Main execution
main() {
    log "🚀 Starting Terraform state retrieval for $ENV environment"
    
    check_terraform_dir
    init_terraform
    get_terraform_outputs
    generate_ansible_inventory
    generate_group_vars
    test_connectivity
    show_summary
    
    log "🎉 State retrieval completed successfully!"
}

# Handle arguments
case "${1:-}" in
    -h|--help)
        echo "Terraform State Retrieval Script"
        echo "Usage: $0 [environment]"
        echo "Environments: dev, staging, prod"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
