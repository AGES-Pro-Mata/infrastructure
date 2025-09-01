#!/bin/bash
# Pro-Mata Docker Swarm Multi-Node Setup Script

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV=${1:-dev}

# Load environment configuration
if [[ -f "$PROJECT_ROOT/envs/$ENV/.env.$ENV" ]]; then
    source "$PROJECT_ROOT/envs/$ENV/.env.$ENV"
else
    echo "❌ Environment file not found: $PROJECT_ROOT/envs/$ENV/.env.$ENV"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Function to initialize Docker Swarm
init_swarm() {
    local manager_ip=$1
    
    log "🚀 Inicializando Docker Swarm no manager node..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << 'EOSSH'
        set -e
        
        # Get manager IP
        MANAGER_IP=$(hostname -I | awk '{print $1}')
        
        # Initialize Swarm if not already initialized
        if ! docker info | grep -q "Swarm: active"; then
            echo "🔧 Inicializando Swarm..."
            docker swarm init --advertise-addr $MANAGER_IP
        else
            echo "✅ Swarm já está inicializado"
        fi
        
        # Get join tokens
        WORKER_TOKEN=$(docker swarm join-token worker -q)
        MANAGER_TOKEN=$(docker swarm join-token manager -q)
        
        # Save tokens to files for later use
        echo $WORKER_TOKEN > /tmp/worker-token
        echo $MANAGER_TOKEN > /tmp/manager-token
        echo $MANAGER_IP > /tmp/manager-ip
        
        echo "✅ Swarm inicializado no IP: $MANAGER_IP"
        echo "🔑 Worker token: $WORKER_TOKEN"
EOSSH
    
    log "✅ Docker Swarm inicializado com sucesso!"
}

# Function to join worker nodes
join_workers() {
    local manager_ip=$1
    shift
    local worker_ips=("$@")
    
    log "👥 Adicionando worker nodes ao Swarm..."
    
    # Get worker token from manager
    WORKER_TOKEN=$(ssh ubuntu@$manager_ip "cat /tmp/worker-token")
    
    for worker_ip in "${worker_ips[@]}"; do
        log "🔗 Conectando worker: $worker_ip"
        
        ssh -o StrictHostKeyChecking=no ubuntu@$worker_ip << EOSSH
            set -e
            
            # Check if already part of swarm
            if docker info | grep -q "Swarm: active"; then
                echo "✅ Node já faz parte do Swarm"
            else
                echo "🔗 Conectando ao Swarm..."
                docker swarm join --token $WORKER_TOKEN $manager_ip:2377
                echo "✅ Worker conectado com sucesso!"
            fi
EOSSH
    done
    
    log "✅ Todos os workers conectados ao Swarm!"
}

# Function to configure node labels
configure_node_labels() {
    local manager_ip=$1
    shift
    local worker_ips=("$@")
    
    log "🏷️  Configurando labels dos nodes..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << EOSSH
        set -e
        
        # Get all node IDs
        MANAGER_ID=\$(docker node ls --filter role=manager --format "{{.ID}}")
        
        # Label manager node
        docker node update --label-add database.primary=true \$MANAGER_ID
        docker node update --label-add monitoring.enabled=true \$MANAGER_ID
        
        echo "✅ Manager node labelado: database.primary=true, monitoring.enabled=true"
        
        # Label worker nodes
        WORKER_IDS=(\$(docker node ls --filter role=worker --format "{{.ID}}"))
        WORKER_COUNT=\${#WORKER_IDS[@]}
        
        if [ \$WORKER_COUNT -gt 0 ]; then
            # First worker gets database replica
            docker node update --label-add database.replica=true \${WORKER_IDS[0]}
            echo "✅ Worker 1 labelado: database.replica=true"
            
            # If more than one worker, distribute other labels
            if [ \$WORKER_COUNT -gt 1 ]; then
                docker node update --label-add database.replica=true \${WORKER_IDS[1]}
                echo "✅ Worker 2 labelado: database.replica=true"
            fi
        fi
        
        # Show final node configuration
        echo "📋 Configuração final dos nodes:"
        docker node ls
        echo ""
        echo "🏷️  Labels configuradas:"
        for node in \$(docker node ls --format "{{.ID}}"); do
            echo "Node \$node:"
            docker node inspect \$node --format "{{.Spec.Labels}}" | grep -v null || echo "  Sem labels customizadas"
        done
EOSSH
    
    log "✅ Labels dos nodes configuradas!"
}

# Function to create networks
create_networks() {
    local manager_ip=$1
    
    log "🌐 Criando networks do Swarm..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << 'EOSSH'
        set -e
        
        # Networks to create
        networks=(
            "database_tier"
            "app_tier" 
            "proxy_tier"
            "monitoring_tier"
        )
        
        for network in "${networks[@]}"; do
            if docker network ls | grep -q $network; then
                echo "✅ Network $network já existe"
            else
                docker network create --driver overlay --attachable $network
                echo "✅ Network $network criada"
            fi
        done
        
        echo "📋 Networks disponíveis:"
        docker network ls --filter driver=overlay
EOSSH
    
    log "✅ Networks criadas com sucesso!"
}

# Function to deploy secrets
deploy_secrets() {
    local manager_ip=$1
    
    log "🔐 Configurando Docker secrets..."
    
    # Create temporary secrets file
    cat > /tmp/promata-secrets << EOF
postgres_password=${POSTGRES_PASSWORD:-$(openssl rand -base64 32)}
postgres_replica_password=${POSTGRES_REPLICA_PASSWORD:-$(openssl rand -base64 32)}
jwt_secret=${JWT_SECRET:-$(openssl rand -base64 64)}
grafana_admin_password=${GRAFANA_ADMIN_PASSWORD:-$(openssl rand -base64 16)}
traefik_auth_users=${TRAEFIK_AUTH_USERS:-admin:$(openssl passwd -apr1 "admin123")}
EOF
    
    # Copy to manager and create secrets
    scp /tmp/promata-secrets ubuntu@$manager_ip:/tmp/
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << 'EOSSH'
        set -e
        
        source /tmp/promata-secrets
        
        # Create Docker secrets
        secrets=(
            "postgres_password"
            "postgres_replica_password"
            "jwt_secret"
            "grafana_admin_password"
            "traefik_auth_users"
        )
        
        for secret in "${secrets[@]}"; do
            if docker secret ls | grep -q $secret; then
                echo "✅ Secret $secret já existe"
            else
                echo "${!secret}" | docker secret create $secret -
                echo "✅ Secret $secret criado"
            fi
        done
        
        echo "📋 Secrets criados:"
        docker secret ls
EOSSH
    
    # Cleanup temp files
    rm -f /tmp/promata-secrets
    ssh ubuntu@$manager_ip "rm -f /tmp/promata-secrets"
    
    log "✅ Secrets configurados com sucesso!"
}

# Function to deploy stack
deploy_stack() {
    local manager_ip=$1
    
    log "🚀 Fazendo deploy do stack Pro-Mata..."
    
    # Copy stack file to manager
    scp "$PROJECT_ROOT/docker/stacks/promata-complete.yml" ubuntu@$manager_ip:/tmp/
    
    # Copy environment file
    scp "$PROJECT_ROOT/envs/$ENV/.env.$ENV" ubuntu@$manager_ip:/tmp/
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << EOSSH
        set -e
        
        # Load environment variables
        source /tmp/.env.$ENV
        
        # Deploy the stack
        docker stack deploy -c /tmp/promata-complete.yml promata
        
        echo "✅ Stack Pro-Mata deployed!"
        
        # Show services
        echo "📋 Serviços implantados:"
        docker service ls
        
        # Cleanup
        rm -f /tmp/promata-complete.yml /tmp/.env.$ENV
EOSSH
    
    log "✅ Stack Pro-Mata implantado com sucesso!"
}

# Function to show cluster status
show_status() {
    local manager_ip=$1
    
    log "📊 Status do cluster:"
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << 'EOSSH'
        set -e
        
        echo "🖥️  Nodes do Swarm:"
        docker node ls
        
        echo ""
        echo "⚙️  Serviços:"
        docker service ls
        
        echo ""
        echo "📊 Status detalhado dos serviços:"
        docker service ps $(docker service ls --format "{{.Name}}")
        
        echo ""
        echo "🌐 Networks:"
        docker network ls --filter driver=overlay
        
        echo ""
        echo "🔐 Secrets:"
        docker secret ls
EOSSH
}

# Main execution
main() {
    if [[ $# -lt 2 ]]; then
        echo "❌ Uso: $0 <env> <manager_ip> [worker_ip1] [worker_ip2] ..."
        echo "Exemplo: $0 dev 10.0.1.10 10.0.1.11 10.0.1.12"
        exit 1
    fi
    
    local env=$1
    local manager_ip=$2
    shift 2
    local worker_ips=("$@")
    
    log "🏗️  Iniciando configuração Docker Swarm Multi-Node para ambiente: $env"
    log "🖥️  Manager: $manager_ip"
    log "👥 Workers: ${worker_ips[*]}"
    
    # Execute setup steps
    init_swarm "$manager_ip"
    
    if [[ ${#worker_ips[@]} -gt 0 ]]; then
        join_workers "$manager_ip" "${worker_ips[@]}"
        configure_node_labels "$manager_ip" "${worker_ips[@]}"
    else
        warn "Nenhum worker node especificado - rodando em modo single-node"
    fi
    
    create_networks "$manager_ip"
    deploy_secrets "$manager_ip"
    deploy_stack "$manager_ip"
    
    log "🎉 Configuração Docker Swarm completada!"
    
    show_status "$manager_ip"
    
    log "📋 URLs de acesso:"
    log "   🌐 Frontend: https://${DOMAIN_NAME}"
    log "   🔌 API: https://api.${DOMAIN_NAME}"
    log "   🚦 Traefik: https://traefik.${DOMAIN_NAME}"
    log "   📊 Grafana: https://grafana.${DOMAIN_NAME}"
}

# Execute main function with all arguments
main "$@"