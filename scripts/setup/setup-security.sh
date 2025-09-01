#!/bin/bash
# Security Setup Script - Pro-Mata Infrastructure
# Configures secure secret management for both local development and CI/CD

set -e

ENV=${1:-dev}
MODE=${2:-local}  # local, ci, or setup

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY_VAULT_NAME="kv-promata-$ENV-secrets"
RESOURCE_GROUP="rg-promata-$ENV"

# Check dependencies
check_dependencies() {
    info "🔍 Checking required tools..."
    
    local missing_tools=()
    
    if ! command -v az >/dev/null 2>&1; then
        missing_tools+=("azure-cli")
    fi
    
    if ! command -v ansible-vault >/dev/null 2>&1; then
        missing_tools+=("ansible")
    fi
    
    if ! command -v gpg >/dev/null 2>&1; then
        missing_tools+=("gpg")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
    fi
    
    log "✅ All required tools available"
}

# Setup Azure Key Vault for shared secrets
setup_azure_key_vault() {
    info "🔐 Setting up Azure Key Vault for secrets..."
    
    # Check if Key Vault already exists
    if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
        log "✅ Key Vault already exists: $KEY_VAULT_NAME"
    else
        log "Creating Key Vault: $KEY_VAULT_NAME"
        
        az keyvault create \
            --name "$KEY_VAULT_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --location "East US 2" \
            --sku Standard \
            --enabled-for-template-deployment true \
            --enabled-for-disk-encryption true \
            --tags "Project=ProMata" "Environment=$ENV" "Purpose=SecretManagement" \
            --output none
        
        log "✅ Key Vault created successfully"
    fi
    
    # Set access policy for current user
    local current_user_id
    current_user_id=$(az account show --query user.name -o tsv)
    
    az keyvault set-policy \
        --name "$KEY_VAULT_NAME" \
        --upn "$current_user_id" \
        --secret-permissions all \
        --output none
    
    log "✅ Access policy configured for: $current_user_id"
}

# Generate secure secrets if they don't exist
generate_secrets() {
    info "🎲 Generating secure secrets..."
    
    local secrets_to_generate=(
        "postgres-password"
        "postgres-replica-password"
        "pgadmin-password"
        "jwt-secret"
        "grafana-admin-password"
        "traefik-auth-hash"
    )
    
    for secret_name in "${secrets_to_generate[@]}"; do
        # Check if secret already exists in Key Vault
        if az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$secret_name" >/dev/null 2>&1; then
            log "✅ Secret exists: $secret_name"
        else
            local secret_value
            case "$secret_name" in
                "traefik-auth-hash")
                    # Use TRAEFIK_ADMIN_PASSWORD env var if set, otherwise generate a random password
                    local admin_password="${TRAEFIK_ADMIN_PASSWORD:-$(openssl rand -base64 16)}"
                    if [ -z "${TRAEFIK_ADMIN_PASSWORD}" ]; then
                        warn "No TRAEFIK_ADMIN_PASSWORD provided. Generated random password for Traefik admin: ${admin_password}"
                    fi
                    secret_value=$(python3 -c "import crypt; print(crypt.crypt('${admin_password}', crypt.mksalt(crypt.METHOD_SHA512)))")
                    secret_value="admin:$secret_value"
                    ;;
                "jwt-secret")
                    secret_value=$(openssl rand -base64 64)
                    ;;
                *)
                    secret_value=$(openssl rand -base64 32)
                    ;;
            esac
            
            az keyvault secret set \
                --vault-name "$KEY_VAULT_NAME" \
                --name "$secret_name" \
                --value "$secret_value" \
                --tags "Environment=$ENV" "GeneratedBy=script" \
                --output none
            
            log "✅ Generated secret: $secret_name"
        fi
    done
}

# Create environment file template (without secrets)
create_env_template() {
    info "📝 Creating secure environment template..."
    
    local env_template="$PROJECT_ROOT/environments/$ENV/.env.$ENV.template"
    
    cat > "$env_template" << 'EOF'
# Pro-Mata Development Environment Configuration - SECURE TEMPLATE
# This file contains NO SECRETS and is safe to commit to Git

# === AZURE CONFIGURATION ===
AZURE_SUBSCRIPTION_ID=your-subscription-id-here
AZURE_RESOURCE_GROUP=rg-promata-dev
AZURE_LOCATION=East US 2

# === DOMAIN & DNS CONFIGURATION ===
DOMAIN_NAME=dev.promata.com.br
CLOUDFLARE_ZONE_ID=promata.com.br
# CLOUDFLARE_API_TOKEN loaded from: Azure Key Vault OR local .env.secrets

# === APPLICATION CONFIGURATION ===
ENVIRONMENT=development
BACKEND_IMAGE=norohim/pro-mata-backend-dev:latest
FRONTEND_IMAGE=norohim/pro-mata-frontend-dev:latest
BACKEND_VERSION=latest
FRONTEND_VERSION=latest
FRONTEND_REPLICAS=2
BACKEND_REPLICAS=2

# === DATABASE CONFIGURATION ===
POSTGRES_DB=promata_dev
POSTGRES_USER=promata
# POSTGRES_PASSWORD loaded from: Azure Key Vault
# POSTGRES_REPLICA_PASSWORD loaded from: Azure Key Vault

# === PGBOUNCER CONFIGURATION ===
PGBOUNCER_POOL_MODE=session
PGBOUNCER_POOL_SIZE=20
PGBOUNCER_MAX_CLIENT_CONN=100

# === PGADMIN CONFIGURATION ===
PGADMIN_EMAIL=admin@promata.dev
# PGADMIN_PASSWORD loaded from: Azure Key Vault

# === TRAEFIK CONFIGURATION ===
TRAEFIK_API_DASHBOARD=true
TRAEFIK_LOG_LEVEL=INFO
ACME_EMAIL=admin@promata.dev
# TRAEFIK_AUTH_USERS loaded from: Azure Key Vault

# === JWT CONFIGURATION ===
# JWT_SECRET loaded from: Azure Key Vault
JWT_EXPIRES_IN=1h

# === MONITORING CONFIGURATION ===
# GRAFANA_ADMIN_PASSWORD loaded from: Azure Key Vault
PROMETHEUS_RETENTION=15d

# === SSH CONFIGURATION ===
# TF_VAR_ssh_public_key loaded from: ~/.ssh/id_rsa.pub OR Azure Key Vault

# === DEVELOPMENT SETTINGS ===
DEBUG=true
NODE_ENV=development
LOG_LEVEL=debug
CORS_ORIGINS=https://dev.promata.com.br,http://localhost:3000

# === BACKUP CONFIGURATION ===
BACKUP_ENABLED=true
BACKUP_RETENTION_DAYS=7
EOF

    log "✅ Environment template created (NO SECRETS)"
}

# Load secrets from Azure Key Vault
load_secrets_from_keyvault() {
    info "🔐 Loading secrets from Azure Key Vault..."
    
    local secrets_file="$PROJECT_ROOT/environments/$ENV/.env.secrets"
    
    # Create secrets file with proper permissions
    touch "$secrets_file"
    chmod 600 "$secrets_file"
    
    cat > "$secrets_file" << EOF
# SECRETS FILE - DO NOT COMMIT TO GIT
# Generated automatically from Azure Key Vault
# File: $secrets_file
# Generated: $(date)

# Database secrets
POSTGRES_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "postgres-password" --query value -o tsv)
POSTGRES_REPLICA_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "postgres-replica-password" --query value -o tsv)
PGADMIN_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "pgadmin-password" --query value -o tsv)

# Application secrets
JWT_SECRET=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "jwt-secret" --query value -o tsv)

# Infrastructure secrets
TRAEFIK_AUTH_USERS=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "traefik-auth-hash" --query value -o tsv)
GRAFANA_ADMIN_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "grafana-admin-password" --query value -o tsv)

# SSH Key
TF_VAR_ssh_public_key=$(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "SSH_KEY_NOT_FOUND")

# Cloudflare Tokens (if exists in Key Vault)
CLOUDFLARE_API_TOKEN=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "cloudflare-api-token" --query value -o tsv 2>/dev/null || echo "CLOUDFLARE_API_TOKEN_NOT_SET")
CLOUDFLARE_ZONE_ID=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "cloudflare-zone-id" --query value -o tsv 2>/dev/null || echo "CLOUDFLARE_ZONE_ID_NOT_SET")
EOF

    log "✅ Secrets loaded to: $secrets_file"
    warn "⚠️  Remember: Add .env.secrets to .gitignore!"
}

# Create secure environment loader script
create_env_loader() {
    info "🔧 Creating secure environment loader..."
    
    local loader_script="$PROJECT_ROOT/scripts/load-env.sh"
    
    cat > "$loader_script" << 'EOF'
#!/bin/bash
# Secure Environment Loader - Pro-Mata Infrastructure
# Loads environment variables from multiple sources securely

ENV=${1:-dev}
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Source files in order (later ones override earlier ones)
ENV_FILES=(
    "$PROJECT_ROOT/environments/$ENV/.env.$ENV.template"  # Base config (safe)
    "$PROJECT_ROOT/environments/$ENV/.env.secrets"       # Secrets (local)
    "$PROJECT_ROOT/environments/$ENV/.env.$ENV.local"    # Local overrides
)

load_env_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        echo "Loading: $file"
        set -a  # Export all variables
        source "$file"
        set +a
        return 0
    else
        echo "Skipping: $file (not found)"
        return 1
    fi
}

# Load environment files
echo "🔐 Loading environment for: $ENV"
for env_file in "${ENV_FILES[@]}"; do
    load_env_file "$env_file"
done

# Validate required secrets
REQUIRED_SECRETS=(
    "POSTGRES_PASSWORD"
    "JWT_SECRET"
    "CLOUDFLARE_API_TOKEN"
    "CLOUDFLARE_ZONE_ID"
    "TF_VAR_ssh_public_key"
)

missing_secrets=()
for secret in "${REQUIRED_SECRETS[@]}"; do
    if [[ -z "${!secret}" ]] || [[ "${!secret}" == *"NOT_FOUND"* ]] || [[ "${!secret}" == *"NOT_SET"* ]]; then
        missing_secrets+=("$secret")
    fi
done

if [[ ${#missing_secrets[@]} -gt 0 ]]; then
    echo "❌ Missing required secrets: ${missing_secrets[*]}"
    echo "Run: ./scripts/setup-security.sh $ENV"
    exit 1
fi

echo "✅ Environment loaded successfully"
EOF

    chmod +x "$loader_script"
    log "✅ Environment loader created: $loader_script"
}

# Update .gitignore to protect secrets
update_gitignore() {
    info "🛡️  Updating .gitignore for security..."
    
    local gitignore_file="$PROJECT_ROOT/.gitignore"
    
    # Security-related patterns to ignore
    local security_patterns=(
        "# === SECURITY - DO NOT COMMIT ==="
        "**/.env.secrets"
        "**/.env.*.local"
        "**/terraform.tfstate*"
        "**/terraform.tfvars.local"
        "**/*.pem"
        "**/*.key"
        "**/id_rsa*"
        "**/.vault_pass"
        "**/ansible-vault-password"
        "# === END SECURITY ==="
    )
    
    # Check if security section exists
    if ! grep -q "=== SECURITY" "$gitignore_file" 2>/dev/null; then
        log "Adding security patterns to .gitignore..."
        
        echo "" >> "$gitignore_file"
        for pattern in "${security_patterns[@]}"; do
            echo "$pattern" >> "$gitignore_file"
        done
        
        log "✅ Security patterns added to .gitignore"
    else
        log "✅ Security patterns already in .gitignore"
    fi
}

# Setup CI/CD environment variables helper
setup_cicd_helper() {
    info "🤖 Creating CI/CD environment helper..."
    
    local cicd_helper="$PROJECT_ROOT/scripts/setup-cicd-vars.sh"
    
    cat > "$cicd_helper" << 'EOF'
#!/bin/bash
# CI/CD Environment Variables Helper
# Generates GitHub Secrets configuration for CI/CD pipelines

ENV=${1:-dev}
KEY_VAULT_NAME="kv-promata-$ENV-secrets"

echo "🤖 GitHub Secrets Configuration for CI/CD"
echo "Copy these to your GitHub repository secrets:"
echo ""

# Get secrets from Key Vault and format for GitHub
secrets=(
    "POSTGRES_PASSWORD"
    "POSTGRES_REPLICA_PASSWORD"
    "PGADMIN_PASSWORD"
    "JWT_SECRET"
    "TRAEFIK_AUTH_USERS"
    "GRAFANA_ADMIN_PASSWORD"
)

for secret_name in "${secrets[@]}"; do
    vault_secret_name=$(echo "$secret_name" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    secret_value=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$vault_secret_name" --query value -o tsv 2>/dev/null || echo "NOT_FOUND")
    
    if [[ "$secret_value" != "NOT_FOUND" ]]; then
        echo "$secret_name=$secret_value"
    else
        echo "# $secret_name=NOT_FOUND_IN_KEYVAULT"
    fi
done

echo ""
echo "# Additional secrets to add manually:"
echo "CLOUDFLARE_API_TOKEN=your-cloudflare-api-token"
echo "CLOUDFLARE_ZONE_ID=your-cloudflare-zone-id"
echo "AZURE_CLIENT_ID=your-service-principal-id"
echo "AZURE_CLIENT_SECRET=your-service-principal-secret"
echo "AZURE_TENANT_ID=your-tenant-id"
echo "AZURE_SUBSCRIPTION_ID=your-subscription-id"
EOF

    chmod +x "$cicd_helper"
    log "✅ CI/CD helper created: $cicd_helper"
}

# Main setup modes
setup_mode() {
    log "🛡️  Setting up secure secret management..."
    
    check_dependencies
    setup_azure_key_vault
    generate_secrets
    create_env_template
    create_env_loader
    update_gitignore
    setup_cicd_helper
    
    log "✅ Security setup completed!"
    echo ""
    warn "📋 Next Steps:"
    warn "1. Add your Cloudflare tokens to Key Vault:"
    warn "   az keyvault secret set --vault-name '$KEY_VAULT_NAME' --name 'cloudflare-api-token' --value 'your-token'"
    warn "   az keyvault secret set --vault-name '$KEY_VAULT_NAME' --name 'cloudflare-zone-id' --value 'your-zone-id'"
    warn "2. Load secrets for development:"
    warn "   source ./scripts/load-env.sh $ENV"
    warn "3. For CI/CD, run:"
    warn "   ./scripts/setup-cicd-vars.sh $ENV"
}

local_mode() {
    log "🔐 Loading secrets for local development..."
    
    if [[ ! -f "$PROJECT_ROOT/scripts/load-env.sh" ]]; then
        error "Security not setup. Run: $0 $ENV setup"
    fi
    
    load_secrets_from_keyvault
    source "$PROJECT_ROOT/scripts/load-env.sh" "$ENV"
    
    log "✅ Environment loaded for local development"
}

ci_mode() {
    log "🤖 CI/CD mode - loading from environment variables..."
    
    # In CI/CD, secrets come from GitHub Secrets
    # Just validate they exist
    local required_vars=(
        "POSTGRES_PASSWORD"
        "JWT_SECRET"
        "CLOUDFLARE_API_TOKEN"
        "CLOUDFLARE_ZONE_ID"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error "Missing CI/CD environment variables: ${missing_vars[*]}"
    fi
    
    log "✅ CI/CD environment validated"
}

# Main execution
case "$MODE" in
    setup)
        setup_mode
        ;;
    local)
        local_mode
        ;;
    ci)
        ci_mode
        ;;
    *)
        error "Usage: $0 <env> <mode>
Modes:
  setup  - Initial security setup (Azure Key Vault + templates)
  local  - Load secrets for local development
  ci     - Validate CI/CD environment"
        ;;
esac