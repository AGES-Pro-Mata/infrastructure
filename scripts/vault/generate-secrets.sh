#!/bin/bash

# Generate secure secrets for vault
# Usage: ./generate-secrets.sh <environment>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="${1:-dev}"
VAULT_FILE="$PROJECT_ROOT/envs/$ENV/secrets/vault.yml"

echo "🔐 Generating secure secrets for $ENV environment..."

# Function to generate random password
generate_password() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Function to generate JWT secret
generate_jwt_secret() {
    openssl rand -hex 64
}

# Function to generate API key
generate_api_key() {
    echo "pk_$(openssl rand -hex 24)"
}

# Create the vault file with real secrets
cat > "$VAULT_FILE" << EOF
# Encrypted secrets for $ENV environment
# Edit with: ./scripts/vault/vault-easy.sh edit $VAULT_FILE

# === DATABASE SECRETS ===
postgres_password: "$(generate_password 32)"
postgres_replica_password: "$(generate_password 32)"

# === APPLICATION SECRETS ===  
jwt_secret: "$(generate_jwt_secret)"
api_key: "$(generate_api_key)"

# === AUTHENTICATION SECRETS ===
admin_password: "$(generate_password 24)"
session_secret: "$(generate_password 48)"

# === ENCRYPTION KEYS ===
encryption_key: "$(openssl rand -hex 32)"
cipher_key: "$(openssl rand -hex 16)"

# === THIRD PARTY SECRETS ===
smtp_password: "change_me_smtp_password"
redis_password: "$(generate_password 24)"

# === MONITORING SECRETS ===
grafana_admin_password: "$(generate_password 16)"
prometheus_web_config_password: "$(generate_password 16)"

# === BACKUP SECRETS ===
backup_encryption_key: "$(openssl rand -hex 32)"
s3_access_key: "change_me_s3_access_key"
s3_secret_key: "change_me_s3_secret_key"

# === WEBHOOK SECRETS ===
webhook_secret: "$(openssl rand -hex 24)"
github_webhook_secret: "$(openssl rand -hex 24)"

# === SSL/TLS SECRETS ===
ssl_private_key_password: "$(generate_password 24)"

# === UMAMI ANALYTICS ===
umami_hash_salt: "$(openssl rand -hex 16)"
umami_db_password: "$(generate_password 24)"
EOF

echo "✅ Generated secure secrets in: $VAULT_FILE"
echo "🔒 Now encrypting with Ansible Vault..."

# Encrypt the file
cd "$PROJECT_ROOT"
ansible-vault encrypt "$VAULT_FILE" --vault-password-file .vault_password

echo "✅ Vault file encrypted successfully!"
echo "📝 To edit: ./scripts/vault/vault-easy.sh edit $VAULT_FILE"
echo "👁️  To view: ./scripts/vault/vault-easy.sh view $VAULT_FILE"