#!/bin/bash
# Remove deprecated files and scripts that accumulated during development
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "🗑️  Removing deprecated files and scripts..."
echo "============================================="

# Create cleanup log
CLEANUP_LOG="$PROJECT_ROOT/envs/archive/cleanup-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$CLEANUP_LOG")"

# Function to safely remove with logging
safe_remove_deprecated() {
    local pattern="$1"
    local description="$2"
    
    echo "🔍 Looking for $description..."
    
    if command -v find >/dev/null 2>&1; then
        find "$PROJECT_ROOT" -name "$pattern" -type f 2>/dev/null | while read -r file; do
            if [ -f "$file" ]; then
                echo "  🗑️  Removing: $file" | tee -a "$CLEANUP_LOG"
                rm -f "$file"
            fi
        done
    fi
}

# Function to remove empty directories
remove_empty_dirs() {
    local base_dir="$1"
    local description="$2"
    
    echo "🔍 Removing empty directories in $description..."
    
    if [ -d "$base_dir" ]; then
        find "$base_dir" -type d -empty 2>/dev/null | while read -r dir; do
            if [ -d "$dir" ]; then
                echo "  📁 Removing empty directory: $dir" | tee -a "$CLEANUP_LOG"
                rmdir "$dir" 2>/dev/null || true
            fi
        done
    fi
}

echo "Starting cleanup process..." > "$CLEANUP_LOG"
echo "Timestamp: $(date)" >> "$CLEANUP_LOG"
echo "=================" >> "$CLEANUP_LOG"

# Remove temporary and backup files
safe_remove_deprecated "*.tmp" "temporary files"
safe_remove_deprecated "*.bak" "backup files"  
safe_remove_deprecated "*.backup" "backup files"
safe_remove_deprecated "*.old" "old files"
safe_remove_deprecated "*.orig" "original files"

# Remove editor temporary files
safe_remove_deprecated "*~" "editor backup files"
safe_remove_deprecated "*.swp" "vim swap files"
safe_remove_deprecated "*.swo" "vim swap files"
safe_remove_deprecated ".DS_Store" "macOS system files"

# Remove log files (except recent ones)
echo "🔍 Cleaning old log files (keeping recent ones)..."
find "$PROJECT_ROOT" -name "*.log" -type f -mtime +7 2>/dev/null | while read -r logfile; do
    echo "  🗑️  Removing old log: $logfile" | tee -a "$CLEANUP_LOG"
    rm -f "$logfile"
done

# Remove deprecated Terraform files
safe_remove_deprecated "terraform.tfstate.backup" "Terraform backup states"
safe_remove_deprecated "*.tfplan" "Terraform plan files"

# Remove deprecated Docker files
safe_remove_deprecated "docker-compose.override.yml.bak" "Docker compose backup files"

# Remove deprecated script versions
echo "🔍 Looking for deprecated script versions..."

# Remove old deployment scripts that might conflict
DEPRECATED_SCRIPTS=(
    "deploy-old.sh"
    "deploy-legacy.sh"
    "setup-old.sh"
    "install-old.sh"
    "backup-old.sh"
    "update-old.sh"
)

for script in "${DEPRECATED_SCRIPTS[@]}"; do
    find "$PROJECT_ROOT" -name "$script" -type f 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            echo "  🗑️  Removing deprecated script: $file" | tee -a "$CLEANUP_LOG"
            rm -f "$file"
        fi
    done
done

# Remove empty directories
remove_empty_dirs "$PROJECT_ROOT/scripts" "scripts directory"
remove_empty_dirs "$PROJECT_ROOT/ansible" "ansible directory"
remove_empty_dirs "$PROJECT_ROOT/terraform" "terraform directory"

# Clean up Git-ignored but accidentally committed files
if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    echo "🔍 Checking for accidentally committed ignored files..."
    
    # Common patterns that should be ignored
    IGNORE_PATTERNS=(
        "*.env.local"
        "*.env.backup"
        ".terraform/"
        "terraform.tfstate"
        "terraform.tfvars.backup"
        ".ansible/tmp"
    )
    
    for pattern in "${IGNORE_PATTERNS[@]}"; do
        find "$PROJECT_ROOT" -name "$pattern" 2>/dev/null | while read -r ignored; do
            if [ -e "$ignored" ]; then
                echo "  🗑️  Removing ignored file: $ignored" | tee -a "$CLEANUP_LOG"
                rm -rf "$ignored"
            fi
        done
    done
fi

# Remove duplicate configuration files
echo "🔍 Looking for duplicate configuration files..."

# Check for duplicate env files
find "$PROJECT_ROOT/envs" -name "*.env.duplicate" -o -name "*.env.copy" 2>/dev/null | while read -r dup; do
    if [ -f "$dup" ]; then
        echo "  🗑️  Removing duplicate config: $dup" | tee -a "$CLEANUP_LOG"
        rm -f "$dup"
    fi
done

# Clean up test files left behind
echo "🔍 Removing test files..."
safe_remove_deprecated "test-*.tmp" "temporary test files"
safe_remove_deprecated "debug-*.log" "debug log files"
safe_remove_deprecated "output-*.txt" "output text files"

# Summary
echo "" | tee -a "$CLEANUP_LOG"
echo "=================" | tee -a "$CLEANUP_LOG"
echo "Cleanup completed: $(date)" | tee -a "$CLEANUP_LOG"
echo "" | tee -a "$CLEANUP_LOG"

# Count files removed
REMOVED_COUNT=$(grep -c "Removing" "$CLEANUP_LOG" || echo "0")

echo "✅ Cleanup completed successfully!"
echo "📊 Files removed: $REMOVED_COUNT"
echo "📋 Cleanup log: $CLEANUP_LOG"
echo ""
echo "🧹 Repository is now clean and optimized!"
echo "💡 Consider adding any remaining patterns to .gitignore"