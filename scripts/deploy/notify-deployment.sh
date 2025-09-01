#!/bin/bash

# Pro-Mata Infrastructure Deployment Notification Script

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Default values
WEBHOOK_URL=""
ENVIRONMENT=""
STATUS=""
BACKEND_TAG=""
FRONTEND_TAG=""
DEPLOYMENT_ID=""
MENTION_ON_FAILURE="true"

# Help function
show_help() {
    echo -e "${BLUE}Pro-Mata Infrastructure Deployment Notifier${NC}"
    echo -e "${YELLOW}Usage: $0 [OPTIONS]${NC}"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  --webhook URL           Discord webhook URL"
    echo -e "  --environment ENV       Environment (dev, staging, prod)"
    echo -e "  --status STATUS         Deployment status (success, failure)"
    echo -e "  --backend-tag TAG       Backend image tag"
    echo -e "  --frontend-tag TAG      Frontend image tag"
    echo -e "  --deployment-id ID      GitHub Actions run ID"
    echo -e "  --no-mention            Don't mention roles on failure"
    echo -e "  -h, --help              Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 --webhook \$WEBHOOK --environment prod --status success --backend-tag latest"
    echo -e "  $0 --webhook \$WEBHOOK --environment dev --status failure --frontend-tag latest"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --webhook)
            WEBHOOK_URL="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --status)
            STATUS="$2"
            shift 2
            ;;
        --backend-tag)
            BACKEND_TAG="$2"
            shift 2
            ;;
        --frontend-tag)
            FRONTEND_TAG="$2"
            shift 2
            ;;
        --deployment-id)
            DEPLOYMENT_ID="$2"
            shift 2
            ;;
        --no-mention)
            MENTION_ON_FAILURE="false"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$WEBHOOK_URL" ]] || [[ -z "$ENVIRONMENT" ]] || [[ -z "$STATUS" ]]; then
    echo -e "${RED}❌ Error: Missing required parameters${NC}"
    show_help
    exit 1
fi

# Function to get current timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Function to get environment-specific configuration
get_environment_config() {
    local env="$1"
    
    case "$env" in
        "dev")
            echo "development" "🧪" "3447003" "https://dev.promata.com.br" "https://api-dev.promata.com.br"
            ;;
        "staging")
            echo "staging" "🎭" "16776960" "https://staging.promata.com.br" "https://api-staging.promata.com.br"
            ;;
        "prod")
            echo "production" "🌟" "65280" "https://promata.com.br" "https://api.promata.com.br"
            ;;
        *)
            echo "unknown" "❓" "8421504" "https://unknown.promata.com.br" "https://api-unknown.promata.com.br"
            ;;
    esac
}

# Function to get status-specific configuration
get_status_config() {
    local status="$1"
    local env="$2"
    
    case "$status" in
        "success")
            if [[ "$env" == "prod" ]]; then
                echo "✅ SUCESSO" "65280" ""
            else
                echo "✅ Sucesso" "65280" ""
            fi
            ;;
        "failure")
            if [[ "$env" == "prod" ]] && [[ "$MENTION_ON_FAILURE" == "true" ]]; then
                echo "🚨 FALHA CRÍTICA" "16711680" "<@&1399565960922402929><@&1399580242636701726> "
            else
                echo "❌ Falha" "16711680" ""
            fi
            ;;
        *)
            echo "⚠️ Status Desconhecido" "16776960" ""
            ;;
    esac
}

# Function to build fields array
build_fields() {
    local env="$1"
    local backend_tag="$2"
    local frontend_tag="$3"
    local deployment_id="$4"
    
    fields='['
    
    # Environment field
    if [[ "$env" == "prod" ]]; then
        fields+='{
            "name": "🌟 Ambiente",
            "value": "**PRODUÇÃO**",
            "inline": true
        }'
    else
        fields+='{
            "name": "🏗️ Ambiente",
            "value": "'$(echo "$env" | tr '[:lower:]' '[:upper:]')'",
            "inline": true
        }'
    fi
    
    # Backend tag field
    if [[ -n "$backend_tag" ]]; then
        fields+=',{
            "name": "🖥️ Backend",
            "value": "`'$backend_tag'`",
            "inline": true
        }'
    fi
    
    # Frontend tag field
    if [[ -n "$frontend_tag" ]]; then
        fields+=',{
            "name": "🌐 Frontend",
            "value": "`'$frontend_tag'`",
            "inline": true
        }'
    fi
    
    # Deployment ID field
    if [[ -n "$deployment_id" ]]; then
        fields+=',{
            "name": "🔗 Execução",
            "value": "[GitHub Actions](https://github.com/$GITHUB_REPOSITORY/actions/runs/'$deployment_id')",
            "inline": true
        }'
    fi
    
    # Infrastructure version field
    fields+=',{
        "name": "🏗️ Versão da Infra",
        "value": "`latest-'"$(date +%m%d)"'`",
        "inline": true
    }'
    
    # Timestamp field
    fields+=',{
        "name": "⏰ Timestamp",
        "value": "'$(date -u +"%Y-%m-%d %H:%M:%S UTC")'",
        "inline": true
    }'
    
    fields+=']'
    echo "$fields"
}

# Function to build links
build_links() {
    local env="$1"
    local frontend_url="$2"
    local api_url="$3"
    
    case "$env" in
        "prod")
            echo "[🌍 Website]($frontend_url) | [🔧 API]($api_url) | [📚 Docs]($api_url/docs) | [📊 Health]($api_url/health)"
            ;;
        *)
            echo "[🌐 App]($frontend_url) | [🔧 API]($api_url) | [📊 Health]($api_url/health)"
            ;;
    esac
}

# Main notification function
send_notification() {
    echo -e "${BLUE}📤 Enviando notificação de deployment...${NC}"
    
    # Get environment configuration
    read -r env_name env_emoji env_color frontend_url api_url <<< "$(get_environment_config "$ENVIRONMENT")"
    
    # Get status configuration
    read -r status_text status_color mention <<< "$(get_status_config "$STATUS" "$ENVIRONMENT")"
    
    # Build fields
    fields=$(build_fields "$ENVIRONMENT" "$BACKEND_TAG" "$FRONTEND_TAG" "$DEPLOYMENT_ID")
    
    # Build links
    links=$(build_links "$ENVIRONMENT" "$frontend_url" "$api_url")
    
    # Determine final color (use status color or environment color)
    final_color="$status_color"
    
    # Build notification title
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        title="$status_text - PRODUÇÃO Pro-Mata"
    else
        title="$status_text - $(echo "$env_name" | tr '[:lower:]' '[:upper:]') Pro-Mata"
    fi
    
    # Build description
    if [[ "$STATUS" == "success" ]]; then
        description="Deploy realizado com sucesso no ambiente $env_name"
    else
        description="Deploy falhou no ambiente $env_name - **VERIFICAÇÃO NECESSÁRIA**"
    fi
    
    # Create JSON payload
    payload=$(cat << EOF
{
    "content": "$mention",
    "embeds": [
        {
            "title": "$title",
            "description": "$description",
            "color": $final_color,
            "fields": $fields,
            "footer": {
                "text": "Pro-Mata Infrastructure Deployment System",
                "icon_url": "https://github.com/AGES-Pro-Mata.png"
            },
            "timestamp": "$(get_timestamp)"
        }
    ]
}
EOF
)
    
    # Send notification
    response=$(curl -s -w "%{http_code}" -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    http_code="${response: -3}"
    if [[ "$http_code" == "204" ]]; then
        echo -e "${GREEN}✅ Notificação enviada com sucesso${NC}"
    else
        echo -e "${RED}❌ Falha ao enviar notificação (HTTP $http_code)${NC}"
        echo "Response: ${response%???}"
        exit 1
    fi
}

# Function to log deployment info
log_deployment() {
    echo -e "${PURPLE}📋 Informações do Deployment:${NC}"
    echo -e "  Environment: ${YELLOW}$ENVIRONMENT${NC}"
    echo -e "  Status: ${YELLOW}$STATUS${NC}"
    echo -e "  Backend Tag: ${YELLOW}${BACKEND_TAG:-'não especificado'}${NC}"
    echo -e "  Frontend Tag: ${YELLOW}${FRONTEND_TAG:-'não especificado'}${NC}"
    echo -e "  Deployment ID: ${YELLOW}${DEPLOYMENT_ID:-'não especificado'}${NC}"
    echo -e "  Mention on Failure: ${YELLOW}$MENTION_ON_FAILURE${NC}"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Pro-Mata Infrastructure Deployment Notifier${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    
    log_deployment
    send_notification
    
    echo ""
    echo -e "${GREEN}✅ Processo de notificação concluído${NC}"
}

# Run main function
main "$@"
