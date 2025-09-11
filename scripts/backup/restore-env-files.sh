#!/bin/bash

# Restore environment files from Azure Storage
# Usage: ./scripts/backup/restore-env-files.sh <environment> [timestamp]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="${1:-dev}"
TIMESTAMP="${2:-}"

# Azure Storage Configuration
STORAGE_ACCOUNT="promatadevterraform"
RESOURCE_GROUP="rg-promata-terraform-dev"
CONTAINER_NAME="environment-files"

echo "📥 Restoring environment files for $ENV from Azure Storage..."

# Get storage account key
echo "🔑 Getting storage account key..."
STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --query '[0].value' \
    --output tsv)

cd "$PROJECT_ROOT"

if [[ -z "$TIMESTAMP" ]]; then
    echo "🔍 Available backups for $ENV:"
    az storage blob list \
        --container-name "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --prefix "$ENV/" \
        --output table \
        --query '[?!contains(name, `manifests/`)].{Name:name, LastModified:properties.lastModified, Size:properties.contentLength}'
    
    echo ""
    echo "🔄 To restore specific timestamp, run:"
    echo "   ./scripts/backup/restore-env-files.sh $ENV <timestamp>"
    echo ""
    echo "💡 Available timestamps:"
    az storage blob list \
        --container-name "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --prefix "$ENV/" \
        --output tsv \
        --query '[?!contains(name, `manifests/`)].name' | \
    sed 's|.*/||' | sed 's/_.*$//' | sort -u
    exit 0
fi

echo "📋 Restoring files with timestamp: $TIMESTAMP"

# Files to restore
declare -a FILES_TO_RESTORE=(
    ".env.$ENV"
    ".env.$ENV.yml"
    "config.yml:envs/$ENV/config.yml"
    "hosts.yml:envs/$ENV/hosts.yml"
)

for file_mapping in "${FILES_TO_RESTORE[@]}"; do
    if [[ "$file_mapping" == *":"* ]]; then
        # Split source:destination
        blob_filename="${file_mapping%%:*}"
        local_path="${file_mapping##*:}"
    else
        # Same name for both
        blob_filename="$file_mapping"
        local_path="$file_mapping"
    fi
    
    blob_name="$ENV/${TIMESTAMP}_${blob_filename}"
    
    echo "📥 Downloading $blob_name -> $local_path"
    
    # Create directory if needed
    mkdir -p "$(dirname "$local_path")"
    
    # Download the file
    if az storage blob download \
        --container-name "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --name "$blob_name" \
        --file "$local_path" \
        --output none 2>/dev/null; then
        echo "✅ Restored: $local_path"
    else
        echo "⚠️  File not found in backup, skipping: $blob_name"
    fi
done

# Download the manifest if it exists
MANIFEST_NAME="$ENV/manifests/${TIMESTAMP}_deployment-manifest.json"
if az storage blob download \
    --container-name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --name "$MANIFEST_NAME" \
    --file "/tmp/restored-manifest-${ENV}-${TIMESTAMP}.json" \
    --output none 2>/dev/null; then
    
    echo ""
    echo "📋 Deployment manifest restored to: /tmp/restored-manifest-${ENV}-${TIMESTAMP}.json"
    echo "🔍 Manifest contents:"
    cat "/tmp/restored-manifest-${ENV}-${TIMESTAMP}.json" | jq . 2>/dev/null || cat "/tmp/restored-manifest-${ENV}-${TIMESTAMP}.json"
fi

echo ""
echo "✅ Environment files restore completed!"
echo "🏷️  Environment: $ENV"
echo "⏰ Timestamp: $TIMESTAMP"
echo ""
echo "⚠️  Remember to:"
echo "   1. Verify the restored files are correct"
echo "   2. Source the .env file if needed: source .env.$ENV"
echo "   3. Check vault password file exists: .vault_password"