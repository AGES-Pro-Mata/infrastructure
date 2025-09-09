#!/bin/bash
# Simple Ansible Vault Management - No complexity, just works!
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
VAULT_PASSWORD_FILE="$PROJECT_ROOT/.vault_password"

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Simple Ansible Vault Manager${NC}"
echo "=================================="

# Function to setup vault password
setup_vault_password() {
    if [ ! -f "$VAULT_PASSWORD_FILE" ]; then
        echo -e "${YELLOW}📋 First time setup - creating vault password...${NC}"
        echo "Enter a password for your Ansible Vault (remember this!):"
        read -s vault_password
        echo "$vault_password" > "$VAULT_PASSWORD_FILE"
        chmod 600 "$VAULT_PASSWORD_FILE"
        echo -e "${GREEN}✅ Vault password saved to $VAULT_PASSWORD_FILE${NC}"
        echo -e "${YELLOW}💡 Keep this file secure and backed up!${NC}"
    fi
}

# Function to show help
show_help() {
    echo ""
    echo "🚀 Usage: $0 <command> [args]"
    echo ""
    echo "📋 Available Commands:"
    echo "  help                    - Show this help"
    echo "  setup                   - First time setup (creates password)"
    echo "  encrypt <file>          - Encrypt a file with vault"
    echo "  decrypt <file>          - Decrypt a file (temporary view)"
    echo "  edit <file>            - Edit encrypted file"
    echo "  create <file>          - Create new encrypted file"
    echo "  view <file>            - View encrypted file content"
    echo "  change-password        - Change vault password"
    echo ""
    echo "📁 Quick Templates:"
    echo "  init-dev               - Initialize dev environment secrets"
    echo "  init-prod              - Initialize prod environment secrets"
    echo ""
    echo "🔍 Examples:"
    echo "  $0 encrypt envs/dev/secrets/passwords.yml"
    echo "  $0 edit envs/dev/secrets/all.yml"
    echo "  $0 view envs/prod/secrets/all.yml"
}

# Function to ensure vault password exists
ensure_vault_password() {
    if [ ! -f "$VAULT_PASSWORD_FILE" ]; then
        echo -e "${RED}❌ Vault password not found!${NC}"
        echo -e "${YELLOW}Run: $0 setup${NC}"
        exit 1
    fi
}

# Function to create template secrets file
create_template() {
    local env="$1"
    local file="$2"
    
    cat > "$file" << EOF
# Encrypted secrets for $env environment
# Edit with: ./scripts/vault/vault-easy.sh edit $file

# === DATABASE SECRETS ===
postgres_password: "change_me_secure_password_$env"
postgres_replica_password: "change_me_replica_password_$env"

# === APPLICATION SECRETS ===  
jwt_secret: "change_me_jwt_secret_$env_$(date +%s)"
api_key: "change_me_api_key_$env"

# === AUTHENTICATION SECRETS ===
admin_password: "change_me_admin_password_$env"
grafana_admin_password: "change_me_grafana_password_$env"
pgadmin_password: "change_me_pgadmin_password_$env"

# === CLOUDFLARE SECRETS ===
cloudflare_api_token: "change_me_cloudflare_token"

# === BACKUP SECRETS ===
backup_encryption_key: "change_me_backup_key_$env"

# === CI/CD SECRETS ===
github_token: "change_me_github_token"
docker_registry_password: "change_me_docker_password"
EOF
}

# Main command handling
command="${1:-help}"

case "$command" in
    "help"|"-h"|"--help")
        show_help
        ;;
        
    "setup")
        setup_vault_password
        echo -e "${GREEN}✅ Vault setup completed!${NC}"
        ;;
        
    "encrypt")
        if [ $# -lt 2 ]; then
            echo -e "${RED}❌ Usage: $0 encrypt <file>${NC}"
            exit 1
        fi
        ensure_vault_password
        file="$2"
        if [ ! -f "$file" ]; then
            echo -e "${RED}❌ File not found: $file${NC}"
            exit 1
        fi
        ansible-vault encrypt "$file" --vault-password-file="$VAULT_PASSWORD_FILE"
        echo -e "${GREEN}✅ File encrypted: $file${NC}"
        ;;
        
    "decrypt")
        if [ $# -lt 2 ]; then
            echo -e "${RED}❌ Usage: $0 decrypt <file>${NC}"
            exit 1
        fi
        ensure_vault_password
        file="$2"
        ansible-vault decrypt "$file" --vault-password-file="$VAULT_PASSWORD_FILE"
        echo -e "${GREEN}✅ File decrypted: $file${NC}"
        echo -e "${YELLOW}⚠️  Remember to encrypt again after editing!${NC}"
        ;;
        
    "edit")
        if [ $# -lt 2 ]; then
            echo -e "${RED}❌ Usage: $0 edit <file>${NC}"
            exit 1
        fi
        ensure_vault_password
        file="$2"
        ansible-vault edit "$file" --vault-password-file="$VAULT_PASSWORD_FILE"
        echo -e "${GREEN}✅ File edited and encrypted: $file${NC}"
        ;;
        
    "create")
        if [ $# -lt 2 ]; then
            echo -e "${RED}❌ Usage: $0 create <file>${NC}"
            exit 1
        fi
        ensure_vault_password
        file="$2"
        mkdir -p "$(dirname "$file")"
        ansible-vault create "$file" --vault-password-file="$VAULT_PASSWORD_FILE"
        echo -e "${GREEN}✅ New encrypted file created: $file${NC}"
        ;;
        
    "view")
        if [ $# -lt 2 ]; then
            echo -e "${RED}❌ Usage: $0 view <file>${NC}"
            exit 1
        fi
        ensure_vault_password
        file="$2"
        echo -e "${BLUE}📄 Viewing: $file${NC}"
        echo "=================================="
        ansible-vault view "$file" --vault-password-file="$VAULT_PASSWORD_FILE"
        ;;
        
    "change-password")
        ensure_vault_password
        echo "Enter new vault password:"
        read -s new_password
        echo "$new_password" > "$VAULT_PASSWORD_FILE"
        echo -e "${GREEN}✅ Vault password changed!${NC}"
        echo -e "${YELLOW}⚠️  You'll need to rekey existing vault files${NC}"
        ;;
        
    "init-dev")
        ensure_vault_password
        secrets_dir="$PROJECT_ROOT/envs/dev/secrets"
        mkdir -p "$secrets_dir"
        
        secrets_file="$secrets_dir/all.yml"
        if [ -f "$secrets_file" ]; then
            echo -e "${YELLOW}⚠️  Dev secrets file already exists: $secrets_file${NC}"
            echo "Use: $0 edit $secrets_file"
        else
            create_template "dev" "$secrets_file"
            ansible-vault encrypt "$secrets_file" --vault-password-file="$VAULT_PASSWORD_FILE"
            echo -e "${GREEN}✅ Dev secrets initialized: $secrets_file${NC}"
            echo -e "${BLUE}💡 Edit with: $0 edit $secrets_file${NC}"
        fi
        ;;
        
    "init-prod")
        ensure_vault_password
        secrets_dir="$PROJECT_ROOT/envs/prod/secrets"
        mkdir -p "$secrets_dir"
        
        secrets_file="$secrets_dir/all.yml"
        if [ -f "$secrets_file" ]; then
            echo -e "${YELLOW}⚠️  Prod secrets file already exists: $secrets_file${NC}"
            echo "Use: $0 edit $secrets_file"
        else
            create_template "prod" "$secrets_file"
            ansible-vault encrypt "$secrets_file" --vault-password-file="$VAULT_PASSWORD_FILE"
            echo -e "${GREEN}✅ Prod secrets initialized: $secrets_file${NC}"
            echo -e "${BLUE}💡 Edit with: $0 edit $secrets_file${NC}"
        fi
        ;;
        
    *)
        echo -e "${RED}❌ Unknown command: $command${NC}"
        show_help
        exit 1
        ;;
esac