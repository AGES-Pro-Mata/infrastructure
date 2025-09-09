#!/bin/bash

# Convert Ansible Vault secrets to GitHub Actions secrets format
# Usage: ./vault-to-github-secrets.sh <environment>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="${1:-dev}"
VAULT_FILE="$PROJECT_ROOT/envs/$ENV/secrets/vault.yml"

if [[ ! -f "$VAULT_FILE" ]]; then
    echo "❌ Vault file not found: $VAULT_FILE" >&2
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/.vault_password" ]]; then
    echo "❌ Vault password file not found: $PROJECT_ROOT/.vault_password" >&2
    echo "Run: ./scripts/vault/vault-easy.sh setup" >&2
    exit 1
fi

echo "🔐 GitHub Actions Secrets for $ENV environment"
echo "=============================================="
echo
echo "Add these secrets to your GitHub repository:"
echo "Repository → Settings → Secrets and variables → Actions"
echo

# Decrypt and format for GitHub
cd "$PROJECT_ROOT"
ansible-vault decrypt "$VAULT_FILE" --vault-password-file .vault_password --output=- | \
grep -E '^[a-zA-Z_][a-zA-Z0-9_]*:' | \
sed 's/: */=/' | \
sed 's/"//g' | \
awk -F= '{
    key = toupper($1)
    value = $2
    printf "%-35s %s\n", key":", value
}'

echo
echo "⚠️  IMPORTANT:"
echo "   1. Never commit these secrets to your repository"
echo "   2. Use organization secrets for shared values"
echo "   3. Consider using environment-specific secrets"
echo "   4. Rotate secrets regularly"