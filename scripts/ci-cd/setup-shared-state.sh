#!/bin/bash
# Setup shared Terraform state for multi-repo CI/CD integration
set -euo pipefail

ENV=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "🔧 Setting up shared Terraform state for $ENV environment..."
echo "============================================================="

# Source environment variables
if [ -f "$PROJECT_ROOT/envs/$ENV/.env" ]; then
    source "$PROJECT_ROOT/envs/$ENV/.env"
else
    echo "❌ Environment file not found: $PROJECT_ROOT/envs/$ENV/.env"
    exit 1
fi

# Backend configuration
BACKEND_DIR="$PROJECT_ROOT/terraform/backends"
BACKEND_FILE="$BACKEND_DIR/${ENV}-backend.hcl"

# Create backend directory if it doesn't exist
mkdir -p "$BACKEND_DIR"

echo "📝 Creating backend configuration for $ENV..."

# Create backend HCL file
cat > "$BACKEND_FILE" << EOF
# Terraform Backend Configuration for $ENV Environment
# Auto-generated - do not edit manually
# Generated: $(date)

resource_group_name  = "rg-promata-tfstate"
storage_account_name = "promatatfstate$ENV"
container_name       = "tfstate"
key                  = "$ENV.terraform.tfstate"

# Enable state locking
use_msi              = true
subscription_id      = "$AZURE_SUBSCRIPTION_ID"
EOF

echo "✅ Backend configuration created: $BACKEND_FILE"

# Update main Terraform configuration to use backend
TF_MAIN="$PROJECT_ROOT/terraform/deployments/$ENV/backend.tf"

cat > "$TF_MAIN" << EOF
# Terraform Backend Configuration for $ENV Environment
# This file enables shared state for CI/CD across multiple repositories
# Generated: $(date)

terraform {
  backend "azurerm" {
    # Backend configuration loaded from backend.hcl
    # Run: terraform init -backend-config=../../backends/${ENV}-backend.hcl
  }
}
EOF

echo "✅ Terraform backend file updated: $TF_MAIN"

# Create GitHub workflow template for other repositories
WORKFLOW_DIR="$PROJECT_ROOT/.github/workflows"
mkdir -p "$WORKFLOW_DIR"

cat > "$WORKFLOW_DIR/infrastructure-trigger-${ENV}.yml" << 'EOF'
# GitHub Workflow to trigger infrastructure deployment
# This can be copied to other repositories in the organization
name: Trigger Infrastructure Deployment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - prod
      
  # Trigger on main branch changes (optional)
  push:
    branches: [ main ]
    paths: 
      - 'infrastructure/**'
      - '.github/workflows/infrastructure-trigger-*.yml'

env:
  ENVIRONMENT: ${{ github.event.inputs.environment || 'dev' }}

jobs:
  trigger-infrastructure:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout Infrastructure Repository
        uses: actions/checkout@v4
        with:
          repository: your-org/infrastructure  # Change to your infrastructure repo
          token: ${{ secrets.GITHUB_TOKEN }}
          path: infrastructure
      
      - name: Setup Azure CLI
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ~1.8.0
      
      - name: Setup Ansible
        run: |
          pip install ansible
          ansible-galaxy install -r infrastructure/ansible/requirements.yml || echo "No requirements file"
      
      - name: Setup Vault Password
        run: |
          echo "${{ secrets.ANSIBLE_VAULT_PASSWORD }}" > infrastructure/.vault_password
          chmod 600 infrastructure/.vault_password
      
      - name: Deploy Infrastructure
        working-directory: infrastructure
        run: |
          echo "🚀 Deploying $ENVIRONMENT environment with IP preservation..."
          make deploy-automated ENV=$ENVIRONMENT
      
      - name: Validate Deployment
        working-directory: infrastructure
        run: |
          echo "🔍 Validating deployment..."
          make validate ENV=$ENVIRONMENT
      
      - name: Notify Success
        if: success()
        run: |
          echo "✅ Infrastructure deployment completed successfully for $ENVIRONMENT"
      
      - name: Notify Failure  
        if: failure()
        run: |
          echo "❌ Infrastructure deployment failed for $ENVIRONMENT"
          exit 1
EOF

echo "✅ GitHub workflow template created: $WORKFLOW_DIR/infrastructure-trigger-${ENV}.yml"

# Create CI/CD integration documentation
cat > "$PROJECT_ROOT/CI-CD-INTEGRATION.md" << 'EOF'
# CI/CD Integration Guide

## 🚀 Multi-Repository CI/CD Setup

This infrastructure repository is designed to be triggered by other repositories in your organization.

### Setup for Other Repositories

1. **Copy the workflow file** `..github/workflows/infrastructure-trigger-dev.yml` to your application repositories

2. **Set up repository secrets** in each repository:
   ```
   AZURE_CREDENTIALS - Azure service principal JSON
   ANSIBLE_VAULT_PASSWORD - Password for encrypted secrets
   GITHUB_TOKEN - Token with access to infrastructure repo
   ```

3. **Configure the workflow** by updating:
   ```yaml
   repository: your-org/infrastructure  # Change to your infrastructure repo name
   ```

### Triggering Deployment

**Manual Trigger:**
- Go to Actions tab in your repository
- Select "Trigger Infrastructure Deployment"
- Choose environment (dev/prod)
- Click "Run workflow"

**Automatic Trigger:**
- Push to main branch with infrastructure changes
- Workflow runs automatically

### State Management

- **Shared Terraform State**: All deployments use Azure Storage backend
- **IP Preservation**: IPs are automatically imported and preserved
- **Multi-repo Safe**: Multiple repositories can trigger safely
- **Environment Isolation**: Each environment has separate state

### Local Development

You can still run deployments locally:

```bash
# Quick deployment
make dev-deploy

# Full deployment with IP preservation  
make deploy-automated ENV=dev

# Just Terraform
make deploy-terraform ENV=dev

# Just application stack
make deploy-ansible ENV=dev
```

### Secrets Management

Use the simple vault system:

```bash
# First time setup
./scripts/vault/vault-easy.sh setup

# Initialize environment secrets
./scripts/vault/vault-easy.sh init-dev
./scripts/vault/vault-easy.sh init-prod

# Edit secrets
./scripts/vault/vault-easy.sh edit envs/dev/secrets/all.yml
```

### Maintenance

```bash
# Clean deprecated files
make cleanup-deprecated

# Full maintenance cycle
make maintenance ENV=dev

# Import existing IPs (first time)
./scripts/terraform/import-existing-ips.sh dev
```
EOF

echo "✅ CI/CD integration documentation created: CI-CD-INTEGRATION.md"

# Update .gitignore to exclude sensitive files
GITIGNORE="$PROJECT_ROOT/.gitignore"
echo "" >> "$GITIGNORE"
echo "# Vault and CI/CD sensitive files" >> "$GITIGNORE"
echo ".vault_password" >> "$GITIGNORE"
echo "*.vault_password" >> "$GITIGNORE"
echo ".terraform/" >> "$GITIGNORE"
echo "terraform.tfstate*" >> "$GITIGNORE"
echo ".env.local" >> "$GITIGNORE"

echo "✅ Updated .gitignore with sensitive file patterns"

# Create simple validation script
cat > "$PROJECT_ROOT/scripts/ci-cd/validate-setup.sh" << 'EOF'
#!/bin/bash
# Validate CI/CD setup
set -euo pipefail

ENV=${1:-dev}
PROJECT_ROOT="$(dirname "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")")"

echo "🔍 Validating CI/CD setup for $ENV..."

# Check required files
REQUIRED_FILES=(
    "terraform/backends/${ENV}-backend.hcl"
    "terraform/deployments/$ENV/backend.tf"
    "envs/$ENV/.env"
    "scripts/vault/vault-easy.sh"
    "scripts/terraform/import-existing-ips.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file - MISSING"
        exit 1
    fi
done

echo "✅ All required files present"
echo "🚀 CI/CD setup is ready!"
EOF

chmod +x "$PROJECT_ROOT/scripts/ci-cd/validate-setup.sh"

echo ""
echo "✅ Shared Terraform state setup completed!"
echo ""
echo "📋 Summary of changes:"
echo "  🗂️  Backend configuration: terraform/backends/${ENV}-backend.hcl"
echo "  🔧 Terraform backend file: terraform/deployments/$ENV/backend.tf"
echo "  🚀 GitHub workflow template: .github/workflows/infrastructure-trigger-${ENV}.yml"
echo "  📖 CI/CD documentation: CI-CD-INTEGRATION.md"
echo "  🔍 Validation script: scripts/ci-cd/validate-setup.sh"
echo ""
echo "🎯 Next steps:"
echo "  1. Copy workflow to other repositories"
echo "  2. Set up repository secrets (AZURE_CREDENTIALS, ANSIBLE_VAULT_PASSWORD)"
echo "  3. Test deployment: make deploy-automated ENV=$ENV"
echo "  4. Validate setup: ./scripts/ci-cd/validate-setup.sh $ENV"