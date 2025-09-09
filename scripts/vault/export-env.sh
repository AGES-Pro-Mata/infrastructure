#!/bin/bash

# Export Ansible Vault secrets as environment variables
# Usage: source ./scripts/vault/export-env.sh <environment>
# Or: eval $(./scripts/vault/export-env.sh <environment>)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="${1:-dev}"
VAULT_FILE="$PROJECT_ROOT/envs/$ENV/secrets/vault.yml"
CONFIG_FILE="$PROJECT_ROOT/envs/$ENV/config.yml"

if [[ ! -f "$VAULT_FILE" ]]; then
    echo "❌ Vault file not found: $VAULT_FILE" >&2
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/.vault_password" ]]; then
    echo "❌ Vault password file not found: $PROJECT_ROOT/.vault_password" >&2
    echo "Run: ./scripts/vault/vault-easy.sh setup" >&2
    exit 1
fi

# Function to decrypt and parse vault secrets
decrypt_vault() {
    cd "$PROJECT_ROOT"
    ansible-vault decrypt "$VAULT_FILE" --vault-password-file .vault_password --output=-
}

# Function to convert YAML key-value to export statements
yaml_to_env() {
    # Parse YAML and convert to environment variables
    # Skip comments and empty lines
    grep -E '^[a-zA-Z_][a-zA-Z0-9_]*:' | \
    sed 's/: */=/' | \
    sed 's/"//g' | \
    sed 's/^/export /' | \
    # Convert to uppercase for environment variables
    awk -F= '{print "export " toupper($1) "=" $2}'
}

# Function to export config variables (non-sensitive)
export_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "# === Configuration Variables ==="
        # Parse config.yml and export as environment variables
        grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\s*=' "$CONFIG_FILE" | \
        sed 's/ *= */=/' | \
        sed 's/"//g' | \
        awk -F= '{print "export " toupper($1) "=" $2}' || true
        echo
    fi
}

# Function to create a comprehensive .env file
create_env_file() {
    local env_file="$PROJECT_ROOT/.env.$ENV"
    
    echo "# === Pro-Mata $ENV Environment Variables ===" > "$env_file"
    echo "# Generated on: $(date)" >> "$env_file"
    echo "# Usage: source .env.$ENV" >> "$env_file"
    echo "" >> "$env_file"
    
    # Add config variables
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "# === Configuration Variables ===" >> "$env_file"
        grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\s*=' "$CONFIG_FILE" | \
        sed 's/ *= */=/' | \
        sed 's/"//g' | \
        awk -F= '{print toupper($1) "=" $2}' >> "$env_file" || true
        echo "" >> "$env_file"
    fi
    
    # Add vault secrets
    echo "# === Vault Secrets ===" >> "$env_file"
    decrypt_vault | yaml_to_env | sed 's/^export //' >> "$env_file"
    
    echo "✅ Created environment file: $env_file"
    echo "📝 To use: source $env_file"
    echo "⚠️  Remember: This file contains secrets, keep it secure!"
}

# Main execution
case "${2:-export}" in
    "export")
        echo "# === Pro-Mata $ENV Environment Variables ==="
        echo "# Generated on: $(date)"
        echo
        
        # Export config variables
        export_config
        
        # Export vault secrets
        echo "# === Vault Secrets ==="
        decrypt_vault | yaml_to_env
        ;;
    "file")
        create_env_file
        ;;
    "docker")
        # Create Docker-compatible env file (no export statements)
        local docker_env="$PROJECT_ROOT/.env.$ENV.docker"
        echo "# === Pro-Mata $ENV Docker Environment ===" > "$docker_env"
        echo "# Generated on: $(date)" >> "$docker_env"
        echo "" >> "$docker_env"
        
        # Add config variables
        if [[ -f "$CONFIG_FILE" ]]; then
            grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\s*=' "$CONFIG_FILE" | \
            sed 's/ *= */=/' | \
            sed 's/"//g' | \
            awk -F= '{print toupper($1) "=" $2}' >> "$docker_env" || true
            echo "" >> "$docker_env"
        fi
        
        # Add vault secrets (no export prefix)
        decrypt_vault | yaml_to_env | sed 's/^export //' >> "$docker_env"
        
        echo "✅ Created Docker env file: $docker_env"
        echo "📝 To use with Docker: docker-compose --env-file $docker_env up"
        ;;
    "ci")
        # Create CI/CD compatible format
        echo "# === CI/CD Environment Variables ==="
        echo "# Add these to your CI/CD secrets:"
        echo
        decrypt_vault | yaml_to_env | sed 's/^export //' | \
        awk -F= '{printf "%-30s %s\n", $1":", $2}'
        ;;
    *)
        echo "Usage: $0 <environment> [export|file|docker|ci]"
        echo "  export (default): Output export statements"
        echo "  file:            Create .env file"
        echo "  docker:          Create Docker-compatible env file"
        echo "  ci:              Create CI/CD compatible format"
        exit 1
        ;;
esac