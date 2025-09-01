#!/bin/bash
# Backup Terraform state for Pro-Mata infrastructure
# Usage: ./scripts/backup-terraform-state.sh <environment> [backup_type]

set -euo pipefail

ENVIRONMENT=${1:-dev}
BACKUP_TYPE=${2:-local}  # local, azure, s3, github
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Pro-Mata Terraform State Backup ===${NC}"
echo "Environment: $ENVIRONMENT"
echo "Backup type: $BACKUP_TYPE"
echo "Timestamp: $TIMESTAMP"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}❌ Invalid environment. Use: dev, staging, or prod${NC}"
    exit 1
fi

# Determine cloud provider and paths
case $ENVIRONMENT in
    dev|staging)
        CLOUD_PROVIDER="azure"
        ;;
    prod)
        CLOUD_PROVIDER="aws"
        ;;
esac

STATE_DIR="$ROOT_DIR/terraform/environments/$ENVIRONMENT/$CLOUD_PROVIDER"
STATE_FILE="$STATE_DIR/terraform.tfstate"
BACKUP_DIR="$ROOT_DIR/backups/terraform-state"
BACKUP_FILE="$BACKUP_DIR/terraform-$ENVIRONMENT-$CLOUD_PROVIDER-$TIMESTAMP.tfstate"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "State directory: $STATE_DIR"
echo "State file: $STATE_FILE"
echo "Backup file: $BACKUP_FILE"

# Check if terraform state exists
if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${YELLOW}⚠️  No local state file found. Checking if using remote backend...${NC}"
    
    if [[ -f "$STATE_DIR/backend.tf" ]] || [[ -f "$STATE_DIR/.terraform/terraform.tfstate" ]]; then
        echo -e "${BLUE}📥 Downloading state from remote backend...${NC}"
        cd "$STATE_DIR"
        
        # Initialize terraform to ensure backend is configured
        terraform init -input=false
        
        # Get state to local file for backup
        terraform state pull > terraform.tfstate.backup-tmp
        STATE_FILE="$STATE_DIR/terraform.tfstate.backup-tmp"
    else
        echo -e "${RED}❌ No terraform state found (local or remote)${NC}"
        exit 1
    fi
fi

# Verify state file is not empty
if [[ ! -s "$STATE_FILE" ]]; then
    echo -e "${RED}❌ State file is empty${NC}"
    exit 1
fi

# Create local backup
cp "$STATE_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✅ Local backup created: $BACKUP_FILE${NC}"

# Compress backup
if command -v gzip >/dev/null 2>&1; then
    gzip -c "$BACKUP_FILE" > "$BACKUP_FILE.gz"
    echo -e "${GREEN}✅ Compressed backup created: $BACKUP_FILE.gz${NC}"
fi

# Remote backup functions
backup_to_azure() {
    local storage_account=""
    local container="terraform-state-backups"
    local blob_name="terraform-$ENVIRONMENT-$CLOUD_PROVIDER-$TIMESTAMP.tfstate"
    
    case $ENVIRONMENT in
        dev)
            storage_account="promatadevstore"
            ;;
        staging)
            storage_account="promatastagingstore"
            ;;
        prod)
            storage_account="promataprodstore"
            ;;
    esac
    
    echo -e "${BLUE}📤 Uploading to Azure Storage: $storage_account/$container/$blob_name${NC}"
    
    if ! command -v az >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Azure CLI not available. Skipping Azure backup.${NC}"
        return 1
    fi
    
    if ! az account show >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Not authenticated with Azure. Skipping Azure backup.${NC}"
        return 1
    fi
    
    if az storage blob upload \
        --account-name "$storage_account" \
        --container-name "$container" \
        --name "$blob_name" \
        --file "$BACKUP_FILE" \
        --metadata "Environment=$ENVIRONMENT" "BackupDate=$TIMESTAMP" "CloudProvider=$CLOUD_PROVIDER" \
        --overwrite; then
        echo -e "${GREEN}✅ Azure backup successful${NC}"
    else
        echo -e "${RED}❌ Azure backup failed${NC}"
        return 1
    fi
}

# Perform remote backup based on type
case $BACKUP_TYPE in
    "azure")
        backup_to_azure
        ;;
    "local")
        echo -e "${GREEN}✅ Local backup only${NC}"
        ;;
    *)
        echo -e "${YELLOW}⚠️  Unknown backup type: $BACKUP_TYPE${NC}"
        echo "Available types: local, azure"
        ;;
esac

# Clean up temporary state file if created
if [[ -f "$STATE_DIR/terraform.tfstate.backup-tmp" ]]; then
    rm "$STATE_DIR/terraform.tfstate.backup-tmp"
fi

# Clean old local backups (keep last 10)
echo -e "${BLUE}🧹 Cleaning old backups (keeping 10 most recent)...${NC}"
cd "$BACKUP_DIR"
ls -t terraform-$ENVIRONMENT-$CLOUD_PROVIDER-*.tfstate 2>/dev/null | tail -n +11 | xargs -r rm
ls -t terraform-$ENVIRONMENT-$CLOUD_PROVIDER-*.tfstate.gz 2>/dev/null | tail -n +11 | xargs -r rm

echo ""
echo -e "${GREEN}=== Backup Complete! ===${NC}"
echo "Local backup: $BACKUP_FILE"
if [[ -f "$BACKUP_FILE.gz" ]]; then
    echo "Compressed backup: $BACKUP_FILE.gz"
fi