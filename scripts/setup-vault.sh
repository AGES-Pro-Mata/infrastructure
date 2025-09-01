#!/bin/bash
# Setup Ansible Vault for Pro-Mata infrastructure
# Usage: ./scripts/setup-vault.sh <environment>

set -euo pipefail

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VAULT_DIR="$ROOT_DIR/ansible/inventory/$ENVIRONMENT/group_vars"
VAULT_FILE="$VAULT_DIR/vault.yml"
VAULT_PASS_FILE="$ROOT_DIR/.vault_pass"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Pro-Mata Ansible Vault Setup ===${NC}"
echo "Environment: $ENVIRONMENT"
echo "Vault file: $VAULT_FILE"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}❌ Invalid environment. Use: dev, staging, or prod${NC}"
    exit 1
fi

# Create vault directory if it doesn't exist
mkdir -p "$VAULT_DIR"

# Check if vault password file exists
if [[ ! -f "$VAULT_PASS_FILE" ]]; then
    echo -e "${YELLOW}⚠️  Vault password file not found. Creating new one...${NC}"
    
    # Generate strong password for vault
    if command -v openssl >/dev/null 2>&1; then
        VAULT_PASSWORD=$(openssl rand -base64 32)
    else
        VAULT_PASSWORD="pro_mata_vault_${ENVIRONMENT}_$(date +%Y%m%d)_$(openssl rand -hex 8)"
    fi
    
    echo "$VAULT_PASSWORD" > "$VAULT_PASS_FILE"
    chmod 600 "$VAULT_PASS_FILE"
    echo -e "${GREEN}✅ Created vault password file${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT: Save this password in a secure location!${NC}"
    echo "Vault password: $VAULT_PASSWORD"
fi

# Generate secrets for the environment
generate_secrets() {
    local env=$1
    
    case $env in
        "dev")
            POSTGRES_PASSWORD=$(openssl rand -base64 32)
            JWT_SECRET=$(openssl rand -hex 64)
            TRAEFIK_PASSWORD=$(openssl rand -base64 16)
            GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16)
            PGADMIN_PASSWORD=$(openssl rand -base64 16)
            ACME_EMAIL="devops@promata.com.br"
            DUCKDNS_TOKEN=""  # To be filled manually
            CLOUDFLARE_API_TOKEN=""  # To be filled manually
            CLOUDFLARE_ZONE_ID=""    # To be filled manually
            ;;
        "staging")
            POSTGRES_PASSWORD=$(openssl rand -base64 32)
            JWT_SECRET=$(openssl rand -hex 64)
            TRAEFIK_PASSWORD=$(openssl rand -base64 16)
            GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16)
            PGLADMIN_PASSWORD=$(openssl rand -base64 16)
            ACME_EMAIL="devops@promata.com.br"
            DUCKDNS_TOKEN=""  # To be filled manually
            CLOUDFLARE_API_TOKEN=""  # To be filled manually
            CLOUDFLARE_ZONE_ID=""    # To be filled manually
            ;;
        "prod")
            POSTGRES_PASSWORD=$(openssl rand -base64 32)
            JWT_SECRET=$(openssl rand -hex 64)
            TRAEFIK_PASSWORD=$(openssl rand -base64 20)
            GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 20)
            PGADMIN_PASSWORD=$(openssl rand -base64 20)
            ACME_EMAIL="admin@promata.com.br"
            DUCKDNS_TOKEN=""  # Not used in prod
            CLOUDFLARE_API_TOKEN=""  # To be filled manually
            CLOUDFLARE_ZONE_ID=""    # To be filled manually
            ;;
    esac
    
    # Generate bcrypt hash for Traefik basic auth
    if command -v htpasswd >/dev/null 2>&1; then
        TRAEFIK_AUTH_USERS="admin:$(htpasswd -nbB admin "$TRAEFIK_PASSWORD" | cut -d: -f2)"
    else
        # Fallback if htpasswd not available
        TRAEFIK_AUTH_USERS="admin:\$2y\$10\$placeholder_hash_replace_manually"
    fi
    
    cat > "$VAULT_FILE.tmp" <<EOF
---
# Ansible Vault for $ENVIRONMENT environment
# Created: $(date)
# WARNING: This file contains sensitive information

# Database credentials
vault_postgres_password: "$POSTGRES_PASSWORD"
vault_postgres_replica_password: "${POSTGRES_PASSWORD}_replica"

# Application secrets
vault_jwt_secret: "$JWT_SECRET"

# Service credentials
vault_traefik_password: "$TRAEFIK_PASSWORD"
vault_traefik_auth_users: "$TRAEFIK_AUTH_USERS"
vault_grafana_admin_password: "$GRAFANA_ADMIN_PASSWORD"
vault_pgadmin_password: "$PGADMIN_PASSWORD"

# SSL/TLS configuration
vault_acme_email: "$ACME_EMAIL"

# External services
vault_duckdns_token: "$DUCKDNS_TOKEN"
vault_cloudflare_api_token: "$CLOUDFLARE_API_TOKEN"
vault_cloudflare_zone_id: "$CLOUDFLARE_ZONE_ID"

# Backup encryption
vault_backup_encryption_key: "$(openssl rand -base64 32)"

# Monitoring
vault_prometheus_basic_auth_password: "$(openssl rand -base64 16)"

# Custom application secrets (add as needed)
vault_api_key: "$(openssl rand -hex 32)"
vault_webhook_secret: "$(openssl rand -hex 24)"
EOF
    
    echo -e "${GREEN}✅ Generated secrets for $ENVIRONMENT environment${NC}"
}

# Create vault file if it doesn't exist
if [[ -f "$VAULT_FILE" ]]; then
    echo -e "${YELLOW}⚠️  Vault file already exists. Create backup? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        cp "$VAULT_FILE" "$VAULT_FILE.backup-$(date +%Y%m%d-%H%M%S)"
        echo -e "${GREEN}✅ Backup created${NC}"
    fi
else
    echo -e "${GREEN}Creating new vault file...${NC}"
    generate_secrets "$ENVIRONMENT"
    
    # Encrypt the vault file
    ansible-vault encrypt "$VAULT_FILE.tmp" --vault-password-file "$VAULT_PASS_FILE"
    mv "$VAULT_FILE.tmp" "$VAULT_FILE"
    
    echo -e "${GREEN}✅ Vault file created and encrypted${NC}"
fi

# Create vault management aliases
cat > "$ROOT_DIR/.vault_aliases" <<EOF
# Ansible Vault aliases for Pro-Mata
# Source this file: source .vault_aliases

alias vault-edit-$ENVIRONMENT='ansible-vault edit ansible/inventory/$ENVIRONMENT/group_vars/vault.yml --vault-password-file .vault_pass'
alias vault-view-$ENVIRONMENT='ansible-vault view ansible/inventory/$ENVIRONMENT/group_vars/vault.yml --vault-password-file .vault_pass'
alias vault-decrypt-$ENVIRONMENT='ansible-vault decrypt ansible/inventory/$ENVIRONMENT/group_vars/vault.yml --vault-password-file .vault_pass'
alias vault-encrypt-$ENVIRONMENT='ansible-vault encrypt ansible/inventory/$ENVIRONMENT/group_vars/vault.yml --vault-password-file .vault_pass'

# Common vault operations
alias vault-create='ansible-vault create --vault-password-file .vault_pass'
alias vault-rekey='ansible-vault rekey --vault-password-file .vault_pass'
EOF

echo -e "${GREEN}✅ Created vault aliases. Source them with: source .vault_aliases${NC}"

# Create .gitignore entries
if [[ ! -f "$ROOT_DIR/.gitignore" ]]; then
    touch "$ROOT_DIR/.gitignore"
fi

# Add vault password file to gitignore if not already there
if ! grep -q "\.vault_pass" "$ROOT_DIR/.gitignore"; then
    echo ".vault_pass" >> "$ROOT_DIR/.gitignore"
    echo -e "${GREEN}✅ Added .vault_pass to .gitignore${NC}"
fi

# Add temporary files to gitignore
if ! grep -q "vault\.yml\.tmp" "$ROOT_DIR/.gitignore"; then
    echo "vault.yml.tmp" >> "$ROOT_DIR/.gitignore"
fi

echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "Next steps:"
echo "1. Edit vault to add missing credentials:"
echo "   ansible-vault edit ansible/inventory/$ENVIRONMENT/group_vars/vault.yml --vault-password-file .vault_pass"
echo ""
echo "2. Add these environment variables to CI/CD:"
echo "   - ANSIBLE_VAULT_PASSWORD (content of .vault_pass file)"
echo ""
echo "3. Update your deployment scripts to use vault variables"
echo ""
echo "4. Test vault access:"
echo "   ansible-vault view ansible/inventory/$ENVIRONMENT/group_vars/vault.yml --vault-password-file .vault_pass"
echo ""
echo -e "${YELLOW}⚠️  Remember to securely store the vault password!${NC}"