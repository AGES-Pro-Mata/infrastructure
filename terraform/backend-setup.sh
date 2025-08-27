#!/bin/bash
# Terraform Azure Backend Setup - Pro-Mata Infrastructure
# This script creates the Azure Storage Account for Terraform state management

set -e

# Configuration
RESOURCE_GROUP="rg-promata-terraform-state"
STORAGE_ACCOUNT="promatatfstate$(date +%s | tail -c 6)"  # Unique suffix
CONTAINER_NAME="tfstate"
LOCATION="East US 2"

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

# Check if user is logged in to Azure
check_azure_login() {
    info "🔍 Checking Azure authentication..."
    
    if ! az account show >/dev/null 2>&1; then
        error "❌ Not logged in to Azure. Run 'az login' first."
    fi
    
    local subscription_name
    subscription_name=$(az account show --query name -o tsv)
    log "✅ Authenticated to Azure subscription: $subscription_name"
}

# Create resource group for Terraform state
create_resource_group() {
    info "🏗️  Creating resource group for Terraform state..."
    
    if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
        log "✅ Resource group already exists: $RESOURCE_GROUP"
    else
        az group create \
            --name "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --tags "Purpose=TerraformState" "Project=ProMata" "ManagedBy=Script" \
            --output none
        
        log "✅ Resource group created: $RESOURCE_GROUP"
    fi
}

# Create storage account for Terraform state
create_storage_account() {
    info "💾 Creating storage account for Terraform state..."
    
    if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
        log "✅ Storage account already exists: $STORAGE_ACCOUNT"
    else
        az storage account create \
            --name "$STORAGE_ACCOUNT" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --sku Standard_LRS \
            --kind StorageV2 \
            --access-tier Hot \
            --https-only true \
            --min-tls-version TLS1_2 \
            --allow-blob-public-access false \
            --tags "Purpose=TerraformState" "Project=ProMata" \
            --output none
        
        log "✅ Storage account created: $STORAGE_ACCOUNT"
    fi
}

# Create container for state files
create_container() {
    info "📦 Creating container for Terraform state files..."
    
    # Get storage account key
    local storage_key
    storage_key=$(az storage account keys list \
        --resource-group "$RESOURCE_GROUP" \
        --account-name "$STORAGE_ACCOUNT" \
        --query '[0].value' -o tsv)
    
    # Create container
    if az storage container show \
        --name "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$storage_key" >/dev/null 2>&1; then
        log "✅ Container already exists: $CONTAINER_NAME"
    else
        az storage container create \
            --name "$CONTAINER_NAME" \
            --account-name "$STORAGE_ACCOUNT" \
            --account-key "$storage_key" \
            --public-access off \
            --output none
        
        log "✅ Container created: $CONTAINER_NAME"
    fi
}

# Enable versioning and soft delete for state protection
configure_protection() {
    info "🔒 Configuring state protection features..."
    
    # Enable versioning
    az storage account blob-service-properties update \
        --account-name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --enable-versioning true \
        --output none
    
    # Enable soft delete
    az storage account blob-service-properties update \
        --account-name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --enable-delete-retention true \
        --delete-retention-days 30 \
        --output none
    
    log "✅ Protection features enabled (versioning + 30-day soft delete)"
}

# Generate backend configuration
generate_backend_config() {
    info "📝 Generating Terraform backend configuration..."
    
    local config_file="./environments/dev/backend.tf"
    local backend_config_file="./backend-config.txt"
    
    # Create backend.tf file
    cat > "$config_file" << EOF
# Terraform Backend Configuration - Pro-Mata Infrastructure
# Generated automatically by backend-setup.sh

terraform {
  backend "azurerm" {
    resource_group_name  = "$RESOURCE_GROUP"
    storage_account_name = "$STORAGE_ACCOUNT"
    container_name       = "$CONTAINER_NAME"
    key                  = "dev/terraform.tfstate"
    use_azuread_auth     = true
  }
}
EOF

    # Create backend config for easy reference
    cat > "$backend_config_file" << EOF
# Terraform Backend Configuration - Pro-Mata Infrastructure
# Use these values for terraform init

Resource Group: $RESOURCE_GROUP
Storage Account: $STORAGE_ACCOUNT
Container: $CONTAINER_NAME
State File Key: dev/terraform.tfstate

# Commands to initialize from any machine:
terraform init \\
  -backend-config="resource_group_name=$RESOURCE_GROUP" \\
  -backend-config="storage_account_name=$STORAGE_ACCOUNT" \\
  -backend-config="container_name=$CONTAINER_NAME" \\
  -backend-config="key=dev/terraform.tfstate"

# Or simply run: terraform init (if backend.tf exists)
EOF
    
    log "✅ Backend configuration files created:"
    log "   - $config_file"
    log "   - $backend_config_file"
}

# Test backend access
test_backend_access() {
    info "🧪 Testing backend access..."
    
    cd "$(dirname "$0")/environments/dev" || error "Failed to change directory"
    
    # Initialize with new backend (this will prompt for migration if local state exists)
    if terraform init -input=false >/dev/null 2>&1; then
        log "✅ Backend access successful"
        
        # Test state operations
        if terraform state list >/dev/null 2>&1; then
            log "✅ State operations working"
        else
            log "ℹ️  No state found (expected for new deployment)"
        fi
    else
        warn "⚠️  Backend initialization needs manual intervention (likely state migration)"
        log "   Run 'terraform init' manually to migrate existing local state"
    fi
    
    cd - >/dev/null
}

# Display summary
display_summary() {
    info "📊 Terraform Backend Setup Complete!"
    echo ""
    log "🔧 Backend Details:"
    log "   Resource Group: $RESOURCE_GROUP"
    log "   Storage Account: $STORAGE_ACCOUNT"  
    log "   Container: $CONTAINER_NAME"
    log "   State Key: dev/terraform.tfstate"
    echo ""
    log "🌐 Features Enabled:"
    log "   ✅ Versioning (automatic state history)"
    log "   ✅ Soft Delete (30-day protection)"
    log "   ✅ HTTPS Only + TLS 1.2"
    log "   ✅ Private Access (no public blob access)"
    echo ""
    log "🚀 Next Steps:"
    log "   1. Run 'make terraform-init' to initialize with remote backend"
    log "   2. Run 'make terraform-plan' to plan your deployment"
    log "   3. State is now shared - can be accessed from any machine with Azure access"
    echo ""
    warn "💾 Important: Keep the backend-config.txt file safe for reference"
    warn "🔒 The storage account contains sensitive state data - protect access"
}

# Cleanup function for errors
cleanup_on_error() {
    error "❌ Setup failed. Cleaning up resources..."
    
    # Remove storage account if created
    az storage account delete \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --yes >/dev/null 2>&1 || true
    
    # Remove resource group if empty and created by us
    az group delete \
        --name "$RESOURCE_GROUP" \
        --yes >/dev/null 2>&1 || true
        
    exit 1
}

# Main execution
main() {
    log "🚀 Starting Terraform Azure Backend Setup..."
    
    # Set error trap
    trap cleanup_on_error ERR
    
    check_azure_login
    create_resource_group
    create_storage_account
    create_container
    configure_protection
    generate_backend_config
    test_backend_access
    display_summary
    
    log "🎉 Terraform backend setup completed successfully!"
}

# Show help
show_help() {
    echo "Terraform Azure Backend Setup - Pro-Mata Infrastructure"
    echo ""
    echo "This script creates an Azure Storage Account to store Terraform state remotely,"
    echo "allowing state to be shared across machines and teams securely."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --clean        Remove existing backend resources"
    echo ""
    echo "What this script does:"
    echo "  1. Creates a dedicated resource group for Terraform state"
    echo "  2. Creates a secure storage account with encryption"
    echo "  3. Creates a private container for state files"
    echo "  4. Enables versioning and soft delete for protection"
    echo "  5. Generates backend configuration files"
    echo ""
    echo "After running this script:"
    echo "  - Terraform state will be stored remotely in Azure"
    echo "  - Multiple developers can work with the same state"
    echo "  - State is protected with versioning and soft delete"
    echo "  - 'terraform destroy' will work from any machine"
}

# Clean up backend resources
clean_backend() {
    warn "🧹 Cleaning up Terraform backend resources..."
    
    read -p "Are you sure you want to delete the Terraform backend? This will remove ALL state history! (yes/NO): " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        log "Cleanup cancelled"
        exit 0
    fi
    
    # Delete the entire resource group (this removes everything)
    az group delete \
        --name "$RESOURCE_GROUP" \
        --yes \
        --no-wait
    
    # Remove local backend configuration
    rm -f ./environments/dev/backend.tf
    rm -f ./backend-config.txt
    
    log "✅ Backend cleanup initiated (may take a few minutes to complete)"
}

# Handle arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --clean)
        clean_backend
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac