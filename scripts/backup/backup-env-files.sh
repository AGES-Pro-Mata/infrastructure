#!/bin/bash

# Backup environment files to Azure Storage
# Usage: ./scripts/backup/backup-env-files.sh <environment>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="${1:-dev}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Azure Storage Configuration
STORAGE_ACCOUNT="promatadevterraform"
RESOURCE_GROUP="rg-promata-terraform-dev"
CONTAINER_NAME="environment-files"

echo "🔄 Backing up environment files for $ENV to Azure Storage..."

# Get storage account key
echo "🔑 Getting storage account key..."
STORAGE_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --query '[0].value' \
    --output tsv)

# Create container if it doesn't exist
echo "📦 Ensuring container '$CONTAINER_NAME' exists..."
az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --output none 2>/dev/null || true

# Backup files that exist
cd "$PROJECT_ROOT"

# List of files to backup
declare -a FILES_TO_BACKUP=(
    ".env.$ENV"
    ".env.$ENV.yml"
    "envs/$ENV/config.yml"
    "envs/$ENV/hosts.yml"
)

for file in "${FILES_TO_BACKUP[@]}"; do
    if [[ -f "$file" ]]; then
        # Create blob name with timestamp and environment
        blob_name="$ENV/${TIMESTAMP}_$(basename "$file")"
        
        echo "📤 Uploading $file -> $blob_name"
        az storage blob upload \
            --file "$file" \
            --name "$blob_name" \
            --container-name "$CONTAINER_NAME" \
            --account-name "$STORAGE_ACCOUNT" \
            --account-key "$STORAGE_KEY" \
            --overwrite \
            --output none
            
        echo "✅ Uploaded: $file"
    else
        echo "⚠️  File not found, skipping: $file"
    fi
done

# Create a deployment manifest
MANIFEST_FILE="/tmp/deployment-manifest-$ENV-$TIMESTAMP.json"
cat > "$MANIFEST_FILE" << EOF
{
    "environment": "$ENV",
    "timestamp": "$TIMESTAMP",
    "deployment_date": "$(date -Iseconds)",
    "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "git_branch": "$(git branch --show-current 2>/dev/null || echo 'unknown')",
    "files_backed_up": [
$(printf '        "%s"' "${FILES_TO_BACKUP[@]}" | head -n -1 | sed 's/$/,/')
$(printf '        "%s"' "${FILES_TO_BACKUP[@]}" | tail -n 1)
    ],
    "azure_storage": {
        "account": "$STORAGE_ACCOUNT",
        "container": "$CONTAINER_NAME"
    }
}
EOF

# Upload the manifest
echo "📋 Uploading deployment manifest..."
az storage blob upload \
    --file "$MANIFEST_FILE" \
    --name "$ENV/manifests/${TIMESTAMP}_deployment-manifest.json" \
    --container-name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --overwrite \
    --output none

rm "$MANIFEST_FILE"

echo ""
echo "✅ Environment files backup completed!"
echo "🗂️  Storage Account: $STORAGE_ACCOUNT"
echo "📦 Container: $CONTAINER_NAME"
echo "🏷️  Environment: $ENV"
echo "⏰ Timestamp: $TIMESTAMP"
echo ""
echo "🔍 To list backups:"
echo "   az storage blob list --container-name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT --output table --prefix $ENV/"
echo ""
echo "📥 To download a backup:"
echo "   az storage blob download --container-name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT --name <blob-name> --file <local-file>"