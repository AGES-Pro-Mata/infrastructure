#!/bin/bash
# Example Configuration Script for Infrastructure Setup
# Copy this file to config.sh and customize for your organization

set -euo pipefail

# ==============================================
# BASIC PROJECT CONFIGURATION
# ==============================================

# Your project details
export PROJECT_NAME="myproject"                    # Change to your project name
export ORGANIZATION_NAME="myorg"                   # Your organization/company name
export DOCKERHUB_ORG="YOUR_DOCKERHUB_ORG"         # Your DockerHub organization

# Domain configuration (optional - set to "none" to skip DNS setup)
export DOMAIN_NAME="example.com"                   # Your domain name
export USE_CLOUDFLARE="true"                       # true/false - whether to use Cloudflare

# Azure configuration
export AZURE_LOCATION="eastus2"                    # Azure region
export AZURE_SUBSCRIPTION_ID=""                    # Your Azure subscription ID (leave empty to detect)

# ==============================================
# ENVIRONMENT SPECIFIC SETTINGS
# ==============================================

# Development environment
export DEV_VM_SIZE="Standard_B2s"                  # Small VM for dev
export DEV_REPLICAS="1"                            # 1 replica for dev

# Production environment (when ready)
export PROD_VM_SIZE="Standard_D2s_v3"              # Larger VM for prod
export PROD_REPLICAS="3"                           # Multiple replicas for prod

# ==============================================
# APPLICATION CONFIGURATION
# ==============================================

# Docker images (customize these based on your application)
export BACKEND_IMAGE_DEV="${DOCKERHUB_ORG}/${PROJECT_NAME}-backend-dev:latest"
export FRONTEND_IMAGE_DEV="${DOCKERHUB_ORG}/${PROJECT_NAME}-frontend-dev:latest"
export MIGRATION_IMAGE_DEV="${DOCKERHUB_ORG}/${PROJECT_NAME}-migration-dev:latest"

# Database configuration
export DB_NAME="${PROJECT_NAME}_dev"
export DB_USER="${PROJECT_NAME}"

# ==============================================
# SECURITY SETTINGS
# ==============================================

# Generate a strong password for Ansible Vault
export ANSIBLE_VAULT_PASSWORD="$(openssl rand -base64 32)"

# ==============================================
# CLOUDFLARE SETTINGS (if using custom domain)
# ==============================================

# Get these from your Cloudflare dashboard
export CLOUDFLARE_API_TOKEN=""                     # API token with Zone:Read, DNS:Edit permissions
export CLOUDFLARE_ZONE_ID=""                       # Zone ID for your domain

# ==============================================
# FUNCTIONS
# ==============================================

# Function to apply configuration
apply_config() {
    echo "🔧 Applying configuration for project: $PROJECT_NAME"
    
    # Update terraform.tfvars
    cat > envs/dev/terraform.tfvars << EOF
# Generated from config.sh
# $(date)

# Azure Configuration
environment = "dev"
project_name = "$PROJECT_NAME"
domain_name = "$DOMAIN_NAME"
azure_resource_group = "$PROJECT_NAME-dev-rg"
azure_location = "$AZURE_LOCATION"
vm_size = "$DEV_VM_SIZE"

# Application Images
backend_image = "$BACKEND_IMAGE_DEV"
frontend_image = "$FRONTEND_IMAGE_DEV"
migration_image = "$MIGRATION_IMAGE_DEV"

# Replicas
backend_replicas = $DEV_REPLICAS
frontend_replicas = $DEV_REPLICAS

# Database
postgres_db = "$DB_NAME"
postgres_user = "$DB_USER"

# Storage (will be made unique automatically)
storage_account_name = "${PROJECT_NAME}devstg\$(date +%s | tail -c 6)"

# Cloudflare (optional)
cloudflare_api_token = "$CLOUDFLARE_API_TOKEN"
cloudflare_zone_id = "$CLOUDFLARE_ZONE_ID"
enable_cloudflare_dns = $USE_CLOUDFLARE

# Monitoring
monitoring_enabled = true
EOF

    echo "✅ Configuration applied to envs/dev/terraform.tfvars"
    echo "✅ Ansible vault password: $ANSIBLE_VAULT_PASSWORD"
    echo ""
    echo "📋 Next steps:"
    echo "1. Review envs/dev/terraform.tfvars"
    echo "2. Set up your GitHub secrets:"
    echo "   - AZURE_CREDENTIALS"
    echo "   - AZURE_SUBSCRIPTION_ID"
    echo "   - ANSIBLE_VAULT_PASSWORD (use the generated one above)"
    echo "3. Push your changes to trigger deployment"
}

# Function to validate configuration
validate_config() {
    echo "🔍 Validating configuration..."
    
    local errors=0
    
    if [[ "$PROJECT_NAME" == "myproject" ]]; then
        echo "❌ Please change PROJECT_NAME from the default value"
        errors=$((errors + 1))
    fi
    
    if [[ "$DOCKERHUB_ORG" == "YOUR_DOCKERHUB_ORG" ]]; then
        echo "❌ Please set DOCKERHUB_ORG to your DockerHub organization"
        errors=$((errors + 1))
    fi
    
    if [[ "$USE_CLOUDFLARE" == "true" && "$DOMAIN_NAME" == "example.com" ]]; then
        echo "❌ Please set DOMAIN_NAME to your actual domain when using Cloudflare"
        errors=$((errors + 1))
    fi
    
    if [[ $errors -gt 0 ]]; then
        echo "❌ Please fix the configuration errors above"
        return 1
    fi
    
    echo "✅ Configuration validation passed"
}

# Function to show current configuration
show_config() {
    echo "📋 Current Configuration:"
    echo "Project Name: $PROJECT_NAME"
    echo "Organization: $ORGANIZATION_NAME"
    echo "DockerHub Org: $DOCKERHUB_ORG"
    echo "Domain: $DOMAIN_NAME"
    echo "Use Cloudflare: $USE_CLOUDFLARE"
    echo "Azure Location: $AZURE_LOCATION"
    echo "Dev VM Size: $DEV_VM_SIZE"
    echo ""
}

# ==============================================
# MAIN EXECUTION
# ==============================================

case "${1:-help}" in
    "apply")
        validate_config && apply_config
        ;;
    "validate")
        validate_config
        ;;
    "show")
        show_config
        ;;
    "help"|*)
        echo "🏗️ Infrastructure Configuration Script"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  apply     - Apply configuration to terraform.tfvars"
        echo "  validate  - Validate current configuration"
        echo "  show      - Show current configuration"
        echo "  help      - Show this help message"
        echo ""
        echo "Before running 'apply', customize the variables at the top of this script."
        ;;
esac