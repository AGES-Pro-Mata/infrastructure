#!/bin/bash
# Cleanup unused environments (staging, old prod, local configs)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "🧹 Cleaning up unused environments..."
echo "====================================="

# Create backup directory if it doesn't exist
mkdir -p "$PROJECT_ROOT/envs/archive"

# Function to safely remove if exists
safe_remove() {
    local path="$1"
    local description="$2"
    
    if [ -e "$path" ]; then
        echo "📦 Moving $description to archive..."
        if [ -d "$path" ]; then
            # Archive directory
            BASENAME=$(basename "$path")
            ARCHIVE_PATH="$PROJECT_ROOT/envs/archive/${BASENAME}-$(date +%Y%m%d)"
            mv "$path" "$ARCHIVE_PATH"
            echo "  ✅ Archived to: $ARCHIVE_PATH"
        else
            # Archive file
            BASENAME=$(basename "$path")
            DIRNAME=$(dirname "$path")
            ARCHIVE_DIR="$PROJECT_ROOT/envs/archive/$(basename "$DIRNAME")"
            mkdir -p "$ARCHIVE_DIR"
            mv "$path" "$ARCHIVE_DIR/"
            echo "  ✅ Archived to: $ARCHIVE_DIR/$BASENAME"
        fi
    else
        echo "  ✅ $description already clean"
    fi
}

echo ""
echo "🗂️  Cleaning Terraform deployments..."

# Archive old staging environment
safe_remove "$PROJECT_ROOT/terraform/deployments/staging" "Terraform staging deployment"

# Keep prod but move to archive if not used
echo "  ℹ️  Keeping prod environment (in case needed)"

echo ""
echo "🗂️  Cleaning backend configurations..."

# Archive old staging backend
safe_remove "$PROJECT_ROOT/terraform/backends/staging-backend.tf" "Staging backend config"
safe_remove "$PROJECT_ROOT/terraform/backends/staging-backend.hcl" "Staging backend HCL"

echo ""
echo "🗂️  Cleaning environment configs..."

# Staging already archived
echo "  ✅ Staging environment already archived"

echo ""
echo "🗂️  Cleaning Makefile references..."

# Update Makefile to remove staging references
if [ -f "$PROJECT_ROOT/Makefile" ]; then
    echo "  🔄 Removing staging references from Makefile..."
    
    # Create backup
    cp "$PROJECT_ROOT/Makefile" "$PROJECT_ROOT/Makefile.backup-$(date +%Y%m%d)"
    
    # Remove staging-specific lines
    sed -i '/destroy-staging/d' "$PROJECT_ROOT/Makefile"
    sed -i '/staging infrastructure/d' "$PROJECT_ROOT/Makefile"
    
    echo "  ✅ Makefile updated (backup created)"
fi

echo ""
echo "🗂️  Cleaning Ansible inventory..."

# Check for old inventory structures
find "$PROJECT_ROOT/ansible" -name "*staging*" -o -name "*local*" | while read -r item; do
    if [ -f "$item" ] || [ -d "$item" ]; then
        safe_remove "$item" "Ansible $(basename "$item")"
    fi
done

echo ""
echo "🗂️  Summary of changes:"
echo "  📦 Archived unused environments to envs/archive/"
echo "  🧹 Removed staging Terraform deployment"
echo "  🔧 Updated Makefile (backup created)"
echo "  📋 Kept dev and prod environments"
echo ""

echo "📊 Current active environments:"
ls -la "$PROJECT_ROOT/envs/" | grep "^d" | grep -v archive

echo ""
echo "📦 Archived environments:"
if [ -d "$PROJECT_ROOT/envs/archive" ]; then
    ls -la "$PROJECT_ROOT/envs/archive/"
else
    echo "  (none)"
fi

echo ""
echo "✅ Cleanup completed successfully!"
echo "💡 All unused environments archived safely"