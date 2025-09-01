#!/bin/bash
# Pro-Mata Docker Swarm Management Script

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV=${2:-dev}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"; }

# Load environment configuration
load_env() {
    if [[ -f "$PROJECT_ROOT/envs/$ENV/.env.$ENV" ]]; then
        source "$PROJECT_ROOT/envs/$ENV/.env.$ENV"
    else
        error "Environment file not found: $PROJECT_ROOT/envs/$ENV/.env.$ENV"
    fi
}

# Function to check cluster health
health_check() {
    local manager_ip=${MANAGER_IP}
    
    log "🏥 Executando health check do cluster..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << 'EOSSH'
        set -e
        
        echo "🖥️  Status dos Nodes:"
        docker node ls
        
        echo ""
        echo "⚙️  Status dos Serviços:"
        docker service ls
        
        echo ""
        echo "🔍 Serviços com problemas:"
        FAILED_SERVICES=$(docker service ls --filter "replicas!=0/0" --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}" | grep "0/")
        
        if [[ -n "$FAILED_SERVICES" ]]; then
            echo "$FAILED_SERVICES"
            echo ""
            echo "📋 Detalhes dos serviços com falha:"
            for service in $(echo "$FAILED_SERVICES" | awk '{print $1}' | tail -n +2); do
                echo "--- $service ---"
                docker service ps $service | head -5
                echo ""
            done
        else
            echo "✅ Todos os serviços estão saudáveis!"
        fi
        
        echo ""
        echo "💾 Uso de recursos:"
        echo "CPU Usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -10
        
        echo ""
        echo "🌐 Status das Networks:"
        docker network ls --filter driver=overlay
        
        echo ""
        echo "💾 Status dos Volumes:"
        docker volume ls | grep promata || echo "Nenhum volume Pro-Mata encontrado"
EOSSH
    
    log "✅ Health check completado!"
}

# Function to scale services
scale_services() {
    local manager_ip=${MANAGER_IP}
    local service=$1
    local replicas=$2
    
    log "📈 Escalando serviço $service para $replicas réplicas..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << EOSSH
        set -e
        
        if docker service ls | grep -q promata_$service; then
            docker service scale promata_$service=$replicas
            echo "✅ Serviço promata_$service escalado para $replicas réplicas"
            
            # Wait for scaling to complete
            echo "⏳ Aguardando scaling completar..."
            sleep 30
            
            echo "📊 Status atual:"
            docker service ps promata_$service
        else
            echo "❌ Serviço promata_$service não encontrado"
            echo "📋 Serviços disponíveis:"
            docker service ls --filter name=promata
        fi
EOSSH
    
    log "✅ Scaling completado!"
}

# Function to update services
update_services() {
    local manager_ip=${MANAGER_IP}
    local service=$1
    local image=$2
    
    log "🔄 Atualizando serviço $service com imagem $image..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << EOSSH
        set -e
        
        if docker service ls | grep -q promata_$service; then
            docker service update --image $image promata_$service
            echo "✅ Serviço promata_$service atualizado com imagem $image"
            
            # Monitor update progress
            echo "⏳ Monitorando progresso da atualização..."
            sleep 15
            
            echo "📊 Status da atualização:"
            docker service ps promata_$service | head -10
        else
            echo "❌ Serviço promata_$service não encontrado"
        fi
EOSSH
    
    log "✅ Update completado!"
}

# Function to show logs
show_logs() {
    local manager_ip=${MANAGER_IP}
    local service=$1
    local lines=${2:-100}
    
    log "📋 Mostrando logs do serviço $service..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << EOSSH
        set -e
        
        if docker service ls | grep -q promata_$service; then
            echo "📋 Últimas $lines linhas do log de promata_$service:"
            docker service logs --tail $lines promata_$service
        else
            echo "❌ Serviço promata_$service não encontrado"
            echo "📋 Serviços disponíveis:"
            docker service ls --filter name=promata
        fi
EOSSH
}

# Function to restart services
restart_service() {
    local manager_ip=${MANAGER_IP}
    local service=$1
    
    log "🔄 Reiniciando serviço $service..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << EOSSH
        set -e
        
        if docker service ls | grep -q promata_$service; then
            # Force update to restart
            docker service update --force promata_$service
            echo "✅ Serviço promata_$service reiniciado"
            
            echo "⏳ Aguardando reinicialização..."
            sleep 30
            
            echo "📊 Status atual:"
            docker service ps promata_$service | head -5
        else
            echo "❌ Serviço promata_$service não encontrado"
        fi
EOSSH
    
    log "✅ Restart completado!"
}

# Function to backup database
backup_database() {
    local manager_ip=${MANAGER_IP}
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    
    log "💾 Criando backup do banco de dados..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << EOSSH
        set -e
        
        # Find postgres primary container
        POSTGRES_CONTAINER=\$(docker ps --filter name=promata_postgres-primary --format "{{.Names}}" | head -1)
        
        if [[ -n "\$POSTGRES_CONTAINER" ]]; then
            echo "📦 Criando backup: $backup_name"
            
            # Create backup
            docker exec \$POSTGRES_CONTAINER pg_dump -U \${POSTGRES_USER:-promata} \${POSTGRES_DB:-promata_dev} > /tmp/$backup_name.sql
            
            # Compress backup
            gzip /tmp/$backup_name.sql
            
            # Move to backups volume
            docker exec \$POSTGRES_CONTAINER mkdir -p /var/lib/postgresql/backups/manual
            docker cp /tmp/$backup_name.sql.gz \$POSTGRES_CONTAINER:/var/lib/postgresql/backups/manual/
            
            echo "✅ Backup criado: /var/lib/postgresql/backups/manual/$backup_name.sql.gz"
            
            # Cleanup
            rm -f /tmp/$backup_name.sql.gz
        else
            echo "❌ Container PostgreSQL não encontrado"
        fi
EOSSH
    
    log "✅ Backup completado!"
}

# Function to show resource usage
resource_usage() {
    local manager_ip=${MANAGER_IP}
    
    log "📊 Monitoramento de recursos do cluster..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << 'EOSSH'
        set -e
        
        echo "🖥️  Nodes do Swarm e recursos:"
        for node in $(docker node ls --format "{{.Hostname}}"); do
            echo "--- Node: $node ---"
            if [[ "$node" == "$(hostname)" ]]; then
                # Local node - can get detailed stats
                echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% usado"
                echo "RAM: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
                echo "Disk: $(df -h / | awk 'NR==2 {print $5}')"
            else
                # Remote node - basic check
                echo "Status: $(docker node inspect $node --format '{{.Status.State}}')"
            fi
            echo ""
        done
        
        echo "📊 Top containers por uso de recursos:"
        docker stats --no-stream --format "table {{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | head -15
        
        echo ""
        echo "💾 Uso de volumes:"
        docker system df
EOSSH
    
    log "✅ Monitoramento completado!"
}

# Function to deploy/redeploy stack
redeploy_stack() {
    local manager_ip=${MANAGER_IP}
    
    log "🚀 Re-deployando stack Pro-Mata..."
    
    # Copy updated stack file
    scp "$PROJECT_ROOT/docker/stacks/promata-complete.yml" ubuntu@$manager_ip:/tmp/
    scp "$PROJECT_ROOT/envs/$ENV/.env.$ENV" ubuntu@$manager_ip:/tmp/
    
    ssh -o StrictHostKeyChecking=no ubuntu@$manager_ip << EOSSH
        set -e
        
        # Load environment
        source /tmp/.env.$ENV
        
        # Redeploy stack
        docker stack deploy -c /tmp/promata-complete.yml promata
        
        echo "✅ Stack re-deployed!"
        
        # Show services
        echo "📋 Serviços atualizados:"
        docker service ls --filter name=promata
        
        # Cleanup
        rm -f /tmp/promata-complete.yml /tmp/.env.$ENV
EOSSH
    
    log "✅ Re-deploy completado!"
}

# Display help
show_help() {
    cat << EOF
Pro-Mata Docker Swarm Manager

Uso: $0 <command> [env] [parameters]

Comandos disponíveis:
  health [env]                    - Health check do cluster
  scale [env] <service> <count>   - Escalar serviço
  update [env] <service> <image>  - Atualizar imagem do serviço
  logs [env] <service> [lines]    - Mostrar logs do serviço
  restart [env] <service>         - Reiniciar serviço
  backup [env]                    - Backup do banco de dados
  resources [env]                 - Monitorar recursos
  redeploy [env]                  - Re-deploy do stack completo

Exemplos:
  $0 health dev
  $0 scale dev backend 5
  $0 update dev backend norohim/pro-mata-backend-dev:latest
  $0 logs dev backend 200
  $0 restart dev frontend
  $0 backup dev
  $0 resources dev
  $0 redeploy dev

Ambientes: dev, staging, prod
EOF
}

# Main execution
main() {
    if [[ $# -lt 1 ]]; then
        show_help
        exit 1
    fi
    
    local command=$1
    
    load_env
    
    case $command in
        "health")
            health_check
            ;;
        "scale")
            if [[ $# -lt 3 ]]; then
                error "Uso: $0 scale [env] <service> <count>"
            fi
            scale_services "$3" "$4"
            ;;
        "update")
            if [[ $# -lt 4 ]]; then
                error "Uso: $0 update [env] <service> <image>"
            fi
            update_services "$3" "$4"
            ;;
        "logs")
            if [[ $# -lt 3 ]]; then
                error "Uso: $0 logs [env] <service> [lines]"
            fi
            show_logs "$3" "${4:-100}"
            ;;
        "restart")
            if [[ $# -lt 3 ]]; then
                error "Uso: $0 restart [env] <service>"
            fi
            restart_service "$3"
            ;;
        "backup")
            backup_database
            ;;
        "resources")
            resource_usage
            ;;
        "redeploy")
            redeploy_stack
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            error "Comando desconhecido: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"