#!/bin/bash
# Script to import existing Azure IPs into Terraform state
set -euo pipefail

ENV=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TF_DIR="$PROJECT_ROOT/iac/deployments/$ENV"

echo "🔄 Importing existing Azure IPs for $ENV environment..."
echo "==========================================="

# Check if we're in the right directory
if [ ! -f "$TF_DIR/main.tf" ]; then
    echo "❌ Terraform directory not found: $TF_DIR"
    exit 1
fi

cd "$TF_DIR"

# Source environment variables
source "../../../envs/$ENV/.env"

# Get resource group and resource names from variables
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-myproject-dev}"
PROJECT_NAME="${PROJECT_NAME:-promata}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

# Resource names following Terraform naming convention
MANAGER_IP_NAME="pip-${PROJECT_NAME}-${ENVIRONMENT}-manager"
WORKER_IP_NAME="pip-${PROJECT_NAME}-${ENVIRONMENT}-worker"

echo "📋 Environment: $ENV"
echo "📋 Resource Group: $RESOURCE_GROUP"
echo "📋 Manager IP Resource: $MANAGER_IP_NAME"
echo "📋 Worker IP Resource: $WORKER_IP_NAME"
echo ""

# Function to check if resource exists in state
resource_exists_in_state() {
    terraform state show "$1" >/dev/null 2>&1
}

# Import Manager IP if not already in state
echo "🔍 Checking Manager IP in Terraform state..."
if resource_exists_in_state "azurerm_public_ip.manager"; then
    echo "✅ Manager IP already exists in Terraform state"
else
    echo "📥 Importing Manager IP into Terraform state..."
    MANAGER_RESOURCE_ID="/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/publicIPAddresses/$MANAGER_IP_NAME"
    
    if terraform import "azurerm_public_ip.manager" "$MANAGER_RESOURCE_ID"; then
        echo "✅ Manager IP imported successfully"
    else
        echo "⚠️  Manager IP import failed - resource may not exist in Azure yet"
    fi
fi

echo ""

# Import Worker IP if not already in state
echo "🔍 Checking Worker IP in Terraform state..."
if resource_exists_in_state "azurerm_public_ip.worker"; then
    echo "✅ Worker IP already exists in Terraform state"
else
    echo "📥 Importing Worker IP into Terraform state..."
    WORKER_RESOURCE_ID="/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/publicIPAddresses/$WORKER_IP_NAME"
    
    if terraform import "azurerm_public_ip.worker" "$WORKER_RESOURCE_ID"; then
        echo "✅ Worker IP imported successfully"
    else
        echo "⚠️  Worker IP import failed - resource may not exist in Azure yet"
    fi
fi

echo ""
echo "🔄 Running terraform plan to check for changes..."
terraform plan -var-file="../../../envs/$ENV/terraform.tfvars"

echo ""
echo "✅ IP import process completed!"
echo ""
echo "📋 Next steps:"
echo "1. Review the terraform plan output above"
echo "2. If everything looks good, run: make deploy-terraform ENV=$ENV"
echo "3. Your IPs are now protected by lifecycle { prevent_destroy = true }"