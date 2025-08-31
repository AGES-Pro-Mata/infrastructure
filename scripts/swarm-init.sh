#!/bin/bash
# Docker Swarm Initialization Script - Pro-Mata Infrastructure

set -e

ENV=${1:-dev}
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"; exit 1; }

# Load environment variables
ENV_FILE="$PROJECT_ROOT/environments/$ENV/.env.$ENV"
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    error "Environment file not found: $ENV_FILE"
fi

# Get Terraform outputs
get_terraform_outputs() {
    log "📋 Getting infrastructure info from Terraform..."
    
    cd "$PROJECT_ROOT/terraform/environments/$ENV"
    
    if [[ ! -f "terraform.tfstate" ]]; then
        error "Terraform state not found. Run 'make terraform-apply' first."
    fi
    
    MANAGER_IP=$(terraform output -raw swarm_manager_public_ip)
    WORKER_IP=$(terraform output -raw swarm_worker_private_ip)
    
    log "Manager IP: $MANAGER_IP"
    log "Worker IP: $WORKER_IP"
    
    cd "$PROJECT_ROOT"
}

# Initialize swarm on manager
init_swarm() {
    log "🐳 Initializing Docker Swarm..."
    
    # Check if already initialized
    if ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" "docker node ls" >/dev/null 2>&1; then
        log "✅ Swarm already initialized"
        return 0
    fi
    
    # Initialize swarm
    log "Initializing swarm on manager..."
    ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "docker swarm init --advertise-addr $MANAGER_IP" || error "Failed to initialize swarm"
    
    log "✅ Swarm initialized successfully"
}

# Get join tokens
get_join_tokens() {
    log "🔑 Getting swarm join tokens..."
    
    WORKER_TOKEN=$(ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "docker swarm join-token worker -q")
    
    MANAGER_TOKEN=$(ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "docker swarm join-token manager -q")
    
    log "✅ Join tokens retrieved"
}

# Join worker to swarm
join_worker() {
    log "🔧 Joining worker to swarm..."
    
    # Check if worker is already part of swarm
    if ssh -o StrictHostKeyChecking=no -J promata@"$MANAGER_IP" promata@"$WORKER_IP" \
        "docker info | grep -q 'Swarm: active'" 2>/dev/null; then
        log "✅ Worker already joined to swarm"
        return 0
    fi
    
    # Join worker
    ssh -o StrictHostKeyChecking=no -J promata@"$MANAGER_IP" promata@"$WORKER_IP" \
        "docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377" || error "Failed to join worker"
    
    log "✅ Worker joined successfully"
}

# Add node labels
add_node_labels() {
    log "🏷️  Adding node labels..."
    
    # Manager labels
    ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "docker node update --label-add database.primary=true --label-add node.type=manager \$(hostname)"
    
    # Worker labels (get hostname first)
    WORKER_HOSTNAME=$(ssh -o StrictHostKeyChecking=no -J promata@"$MANAGER_IP" promata@"$WORKER_IP" "hostname")
    
    ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "docker node update --label-add database.replica=true --label-add node.type=worker $WORKER_HOSTNAME"
    
    log "✅ Node labels added"
}

# Create networks
create_networks() {
    log "🌐 Creating Docker networks..."
    
    local networks=(
        "promata_public"
        "promata_internal"
        "promata_database"
    )
    
    for network in "${networks[@]}"; do
        ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
            "docker network create --driver overlay --attachable $network || true"
        log "✅ Network: $network"
    done
}

# Verify swarm setup
verify_swarm() {
    log "✅ Verifying swarm setup..."
    
    # List nodes
    local nodes
    nodes=$(ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" "docker node ls")
    
    echo ""
    log "📊 Swarm Nodes:"
    echo "$nodes"
    echo ""
    
    # List networks
    local networks  
    networks=$(ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" "docker network ls --filter driver=overlay")
    
    log "🌐 Overlay Networks:"
    echo "$networks"
    echo ""
    
    # Node labels
    log "🏷️  Node Labels:"
    ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "docker node inspect \$(docker node ls -q) --format '{{.Description.Hostname}}: {{.Spec.Labels}}'"
    echo ""
}

# Update Ansible inventory
update_ansible_inventory() {
    log "📝 Updating Ansible inventory..."
    
    local inventory_file="$PROJECT_ROOT/ansible/inventory/$ENV/hosts.yml"
    local temp_file=$(mktemp)
    
    # Replace IP addresses in inventory
    sed -e "s/{{ manager_public_ip }}/$MANAGER_IP/g" \
        -e "s/{{ manager_private_ip }}/$MANAGER_IP/g" \
        -e "s/{{ worker_private_ip }}/$WORKER_IP/g" \
        "$inventory_file" > "$temp_file"
    
    mv "$temp_file" "$inventory_file"
    
    log "✅ Ansible inventory updated"
}

# Main execution
main() {
    log "🚀 Starting Docker Swarm initialization for $ENV environment"
    
    get_terraform_outputs
    init_swarm
    get_join_tokens
    join_worker
    add_node_labels
    create_networks
    verify_swarm
    update_ansible_inventory
    
    echo ""
    log "🎉 Docker Swarm initialization completed!"
    log "🔧 Next steps:"
    log "   1. Run: make ansible-configure"
    log "   2. Run: make stacks-deploy"
    log "   3. Run: make health"
    echo ""
    log "📡 SSH Access:"
    log "   Manager: ssh promata@$MANAGER_IP"
    log "   Worker:  ssh promata@$WORKER_IP (via manager jump)"
}

main "$@"