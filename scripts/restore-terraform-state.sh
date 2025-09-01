#!/bin/bash
# Restore Terraform state for Pro-Mata infrastructure
# Usage: ./scripts/restore-terraform-state.sh <environment> <backup_source>

set -euo pipefail

ENVIRONMENT=${1:-dev}
BACKUP_SOURCE=${2:-}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Pro-Mata Terraform State Restore ===${NC}"
echo "Environment: $ENVIRONMENT"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}❌ Invalid environment. Use: dev, staging, or prod${NC}"
    exit 1
fi

# Check if backup source is provided
if [[ -z "$BACKUP_SOURCE" ]]; then
    echo -e "${RED}❌ Backup source required${NC}"
    echo "Usage: $0 <environment> <backup_source>"
    echo ""
    echo "Available backups:"
    BACKUP_DIR="$ROOT_DIR/backups/terraform-state"
    if [[ -d "$BACKUP_DIR" ]]; then
        ls -la "$BACKUP_DIR"/terraform-$ENVIRONMENT-*.tfstate 2>/dev/null || echo "No local backups found"
    else
        echo "No backup directory found"
    fi
    exit 1
fi

# Determine cloud provider
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
CURRENT_BACKUP="$STATE_DIR/terraform.tfstate.pre-restore-$(date +%Y%m%d-%H%M%S)"

echo "State directory: $STATE_DIR"
echo "State file: $STATE_FILE"
echo "Backup source: $BACKUP_SOURCE"

# Validate state directory exists
if [[ ! -d "$STATE_DIR" ]]; then
    echo -e "${RED}❌ State directory not found: $STATE_DIR${NC}"
    exit 1
fi

# Backup current state before restoration
if [[ -f "$STATE_FILE" ]]; then
    echo -e "${YELLOW}⚠️  Backing up current state before restoration...${NC}"
    cp "$STATE_FILE" "$CURRENT_BACKUP"
    echo -e "${GREEN}✅ Current state backed up to: $CURRENT_BACKUP${NC}"
fi

# Restore from file
if [[ -f "$BACKUP_SOURCE" ]]; then
    # Check if it's a compressed file
    if [[ "$BACKUP_SOURCE" =~ \.gz$ ]]; then
        echo -e "${BLUE}📦 Decompressing backup...${NC}"
        gunzip -c "$BACKUP_SOURCE" > "$STATE_FILE"
    else
        cp "$BACKUP_SOURCE" "$STATE_FILE"
    fi
    
    echo -e "${GREEN}✅ State restored from: $BACKUP_SOURCE${NC}"
else
    # Try to find in local backup directory
    BACKUP_DIR="$ROOT_DIR/backups/terraform-state"
    LOCAL_BACKUP="$BACKUP_DIR/$BACKUP_SOURCE"
    
    if [[ -f "$LOCAL_BACKUP" ]]; then
        cp "$LOCAL_BACKUP" "$STATE_FILE"
        echo -e "${GREEN}✅ State restored from: $LOCAL_BACKUP${NC}"
    else
        echo -e "${RED}❌ Backup source not found: $BACKUP_SOURCE${NC}"
        exit 1
    fi
fi

# Validate restored state
echo -e "${BLUE}🔍 Validating restored state...${NC}"

cd "$STATE_DIR"

# Check if state file is valid JSON
if ! python3 -m json.tool "$STATE_FILE" >/dev/null 2>&1; then
    echo -e "${RED}❌ Restored state file is not valid JSON${NC}"
    if [[ -f "$CURRENT_BACKUP" ]]; then
        cp "$CURRENT_BACKUP" "$STATE_FILE"
        echo -e "${GREEN}✅ Previous state restored${NC}"
    fi
    exit 1
fi

echo -e "${GREEN}✅ State restored successfully${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "1. Review the restored state: terraform state list"
echo "2. Verify infrastructure: terraform plan"
echo "3. Previous state backup: $CURRENT_BACKUP"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Review terraform plan before applying changes!${NC}"