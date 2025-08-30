#!/bin/bash

# Docker Hub Webhook Setup Script for Pro-Mata Infrastructure
# This script helps configure Docker Hub webhooks to trigger automatic deployments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="AGES-Pro-Mata/infrastructure"
WEBHOOK_ENDPOINT="https://api.github.com/repos/${GITHUB_REPO}/dispatches"

# Docker Hub repositories to monitor
BACKEND_REPO="norohim/pro-mata-backend-dev"
FRONTEND_REPO="norohim/pro-mata-frontend-dev"

print_header() {
    echo -e "${BLUE}🐳 Docker Hub Webhook Setup for Pro-Mata${NC}"
    echo -e "${BLUE}======================================${NC}\n"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_dependencies() {
    print_info "Checking dependencies..."
    
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed"
        exit 1
    fi
    
    print_success "Dependencies check passed"
}

generate_webhook_payload() {
    local repo_name=$1
    
    cat << EOF
{
  "name": "github-webhook-${repo_name//\//-}",
  "webhookurl": "https://api.github.com/repos/${GITHUB_REPO}/dispatches"
}
EOF
}

setup_github_webhook_handler() {
    print_info "Setting up GitHub webhook handler..."
    
    # Create a simple webhook handler script
    cat > scripts/handle-docker-webhook.sh << 'EOF'
#!/bin/bash

# GitHub webhook handler for Docker Hub
# This script processes Docker Hub webhooks and triggers GitHub Actions

PAYLOAD_FILE="${1:-/dev/stdin}"

# Extract repository and tag information
REPO_NAME=$(jq -r '.repository.repo_name' < "$PAYLOAD_FILE")
PUSHED_TAG=$(jq -r '.push_data.tag' < "$PAYLOAD_FILE")
PUSHER=$(jq -r '.push_data.pusher' < "$PAYLOAD_FILE")

echo "Received Docker Hub webhook:"
echo "  Repository: $REPO_NAME"
echo "  Tag: $PUSHED_TAG"
echo "  Pusher: $PUSHER"

# Trigger GitHub Actions via repository dispatch
if [[ "$REPO_NAME" =~ pro-mata-.+-dev$ ]] && [[ "$PUSHED_TAG" == "latest" ]]; then
    echo "Triggering deployment for dev environment..."
    
    curl -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${GITHUB_REPO}/dispatches" \
        -d "{
            \"event_type\": \"docker-hub-webhook\",
            \"client_payload\": {
                \"repository\": {
                    \"repo_name\": \"$REPO_NAME\"
                },
                \"push_data\": {
                    \"tag\": \"$PUSHED_TAG\",
                    \"pusher\": \"$PUSHER\"
                }
            }
        }"
else
    echo "Webhook ignored - not a dev image with latest tag"
fi
EOF
    
    chmod +x scripts/handle-docker-webhook.sh
    print_success "GitHub webhook handler created"
}

print_instructions() {
    print_info "Docker Hub Webhook Configuration Instructions"
    echo ""
    echo -e "${YELLOW}📋 Manual Setup Required:${NC}"
    echo ""
    echo "1. 🔐 Log into Docker Hub (https://hub.docker.com)"
    echo ""
    echo "2. 📦 For each repository, configure webhooks:"
    echo ""
    echo -e "   ${GREEN}Backend Repository:${NC} $BACKEND_REPO"
    echo "   - Go to: https://hub.docker.com/r/$BACKEND_REPO/webhooks"
    echo "   - Click 'Create Webhook'"
    echo "   - Webhook name: github-webhook-backend-dev"
    echo -e "   - Webhook URL: ${BLUE}$WEBHOOK_ENDPOINT${NC}"
    echo ""
    echo -e "   ${GREEN}Frontend Repository:${NC} $FRONTEND_REPO"
    echo "   - Go to: https://hub.docker.com/r/$FRONTEND_REPO/webhooks"
    echo "   - Click 'Create Webhook'"
    echo "   - Webhook name: github-webhook-frontend-dev"
    echo -e "   - Webhook URL: ${BLUE}$WEBHOOK_ENDPOINT${NC}"
    echo ""
    echo "3. 🔑 GitHub Token Requirements:"
    echo "   - The webhook will use GitHub repository dispatch"
    echo "   - Ensure your GitHub token has 'repo' permissions"
    echo "   - The token should be accessible to GitHub Actions"
    echo ""
    echo "4. 🧪 Test the webhook:"
    echo "   - Push a new 'latest' tag to either dev repository"
    echo "   - Check GitHub Actions for automatic deployment trigger"
    echo ""
    echo -e "${GREEN}📄 Webhook Payload Format:${NC}"
    echo "The webhook will send a JSON payload like this:"
    echo ""
    cat << 'EOF'
{
  "callback_url": "https://registry.hub.docker.com/u/norohim/pro-mata-backend-dev/hook/...",
  "push_data": {
    "images": [...],
    "pushed_at": 1630000000,
    "pusher": "username",
    "tag": "latest"
  },
  "repository": {
    "comment_count": 0,
    "date_created": 1630000000,
    "description": "Pro-Mata Backend Development",
    "dockerfile": "...",
    "full_description": "...",
    "is_official": false,
    "is_private": false,
    "is_trusted": false,
    "name": "pro-mata-backend-dev",
    "namespace": "norohim",
    "owner": "norohim",
    "repo_name": "norohim/pro-mata-backend-dev",
    "repo_url": "https://hub.docker.com/r/norohim/pro-mata-backend-dev",
    "star_count": 0,
    "status": "Active"
  }
}
EOF
    echo ""
}

test_webhook_simulation() {
    print_info "Testing webhook simulation..."
    
    # Create test payload
    local test_payload=$(cat << EOF
{
  "push_data": {
    "tag": "latest",
    "pusher": "test-user"
  },
  "repository": {
    "repo_name": "$BACKEND_REPO"
  }
}
EOF
)
    
    echo "Test payload created:"
    echo "$test_payload" | jq .
    
    print_warning "To test the actual webhook, you would need to:"
    echo "1. Set up the webhook in Docker Hub"
    echo "2. Push a new 'latest' tag to trigger it"
    echo "3. Monitor GitHub Actions for the triggered workflow"
}

create_monitoring_script() {
    print_info "Creating webhook monitoring script..."
    
    cat > scripts/monitor-docker-webhooks.sh << 'EOF'
#!/bin/bash

# Monitor Docker Hub webhook activity and GitHub Actions triggers

set -euo pipefail

GITHUB_REPO="AGES-Pro-Mata/infrastructure"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Error: GITHUB_TOKEN environment variable is required"
    exit 1
fi

echo "🔍 Monitoring Docker Hub webhook activity..."
echo "Repository: $GITHUB_REPO"
echo ""

# Check recent workflow runs triggered by repository_dispatch
echo "📊 Recent Docker Hub webhook triggered deployments:"
curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_REPO/actions/runs?event=repository_dispatch" | \
    jq -r '.workflow_runs[] | select(.head_commit.message | contains("docker-hub")) | 
           "- \(.created_at) | \(.conclusion // "running") | \(.html_url)"' | \
    head -5

echo ""
echo "📈 Overall workflow statistics:"
curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_REPO/actions/runs?per_page=50" | \
    jq -r '.workflow_runs | group_by(.event) | 
           map({event: .[0].event, count: length}) | 
           .[] | "- \(.event): \(.count) runs"'

echo ""
echo "🔔 Recent repository dispatch events:"
curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_REPO/actions/runs?event=repository_dispatch" | \
    jq -r '.workflow_runs[0:3][] | 
           "- \(.created_at) | \(.name) | \(.conclusion // "running")"'
EOF
    
    chmod +x scripts/monitor-docker-webhooks.sh
    print_success "Webhook monitoring script created"
}

main() {
    print_header
    
    case "${1:-}" in
        "install")
            check_dependencies
            setup_github_webhook_handler
            create_monitoring_script
            print_instructions
            ;;
        "test")
            test_webhook_simulation
            ;;
        "monitor")
            if [[ -f "scripts/monitor-docker-webhooks.sh" ]]; then
                ./scripts/monitor-docker-webhooks.sh
            else
                print_error "Monitoring script not found. Run './setup-docker-webhooks.sh install' first"
            fi
            ;;
        "help"|"--help"|"-h"|"")
            echo "Usage: $0 [install|test|monitor|help]"
            echo ""
            echo "Commands:"
            echo "  install  - Set up webhook handlers and show configuration instructions"
            echo "  test     - Simulate webhook payload for testing"
            echo "  monitor  - Monitor webhook activity and deployments"
            echo "  help     - Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  GITHUB_TOKEN  - Required for monitoring (GitHub personal access token)"
            ;;
        *)
            print_error "Unknown command: $1"
            print_info "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
