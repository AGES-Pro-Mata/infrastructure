#!/bin/bash
# Script to restore captured IP addresses after Terraform deployment
set -euo pipefail

ENV=${1:-dev}

echo "🔄 Restoring preserved IP addresses for $ENV environment..."
echo "==========================================="

# New resource group and naming
NEW_RESOURCE_GROUP="rg-pro-mata-dev"
NEW_MANAGER_IP="pip-pro-mata-${ENV}-manager"
NEW_WORKER_IP="pip-pro-mata-${ENV}-worker"

# Check if preserved IPs exist
if [ -f /tmp/manager_ip.txt ]; then
    PRESERVED_MANAGER_IP=$(cat /tmp/manager_ip.txt)
    echo "🔄 Attempting to restore Manager IP: $PRESERVED_MANAGER_IP"
    
    # Try to update the public IP address (this may not be possible with Standard SKU)
    echo "⚠️ Note: Azure Standard Public IPs cannot change their address after creation"
    echo "📌 Current Manager IP will be: $(az network public-ip show --resource-group "$NEW_RESOURCE_GROUP" --name "$NEW_MANAGER_IP" --query ipAddress -o tsv 2>/dev/null || echo 'Unknown')"
    
    # Clean up temporary file
    rm -f /tmp/manager_ip.txt
fi

if [ -f /tmp/worker_ip.txt ]; then
    PRESERVED_WORKER_IP=$(cat /tmp/worker_ip.txt)
    echo "🔄 Attempting to restore Worker IP: $PRESERVED_WORKER_IP"
    
    # Try to update the public IP address (this may not be possible with Standard SKU)
    echo "⚠️ Note: Azure Standard Public IPs cannot change their address after creation"
    echo "📌 Current Worker IP will be: $(az network public-ip show --resource-group "$NEW_RESOURCE_GROUP" --name "$NEW_WORKER_IP" --query ipAddress -o tsv 2>/dev/null || echo 'Unknown')"
    
    # Clean up temporary file
    rm -f /tmp/worker_ip.txt
fi

echo "✅ IP restoration process completed"
echo "💡 If IPs have changed, update your DNS records accordingly"