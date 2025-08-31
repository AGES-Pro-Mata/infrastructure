#!/bin/bash
# Simplified backup and recovery system for Pro-Mata
# Replaces the verbose 907-line backup-recovery.sh

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/backups"
LOG_FILE="$BACKUP_DIR/backup.log"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}
error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}
warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARN:${NC} $1" | tee -a "$LOG_FILE"
}

# Create backup directory
init_backup() {
    mkdir -p "$BACKUP_DIR"
    touch "$LOG_FILE"
}

# Backup configurations
backup_configs() {
    local backup_file="$BACKUP_DIR/config-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    log "Creating configuration backup: $(basename "$backup_file")"
    
    tar -czf "$backup_file" -C "$PROJECT_ROOT" \
        --exclude="*.log" \
        --exclude="backups/*" \
        --exclude=".git/*" \
        environments/ ansible/ docker/ scripts/
    
    log "✅ Configuration backup completed: $(basename "$backup_file")"
}

# Backup secrets and environment files
backup_secrets() {
    local backup_file="$BACKUP_DIR/secrets-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    log "Creating secrets backup: $(basename "$backup_file")"
    
    tar -czf "$backup_file" -C "$PROJECT_ROOT" \
        environments/*/.env.* \
        ansible/inventory/*/group_vars/vault.yml 2>/dev/null || warn "Some vault files not found"
    
    log "✅ Secrets backup completed: $(basename "$backup_file")"
}

# Backup infrastructure data
backup_infrastructure() {
    local backup_file="$BACKUP_DIR/infrastructure-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    log "Creating infrastructure backup: $(basename "$backup_file")"
    
    tar -czf "$backup_file" -C "$PROJECT_ROOT" \
        --exclude="*.log" \
        --exclude="backups/*" \
        --exclude=".git/*" \
        --exclude="node_modules/*" \
        .
    
    log "✅ Infrastructure backup completed: $(basename "$backup_file")"
}

# List available backups
list_backups() {
    log "📋 Available backups:"
    if [[ -d "$BACKUP_DIR" ]] && [[ $(ls -A "$BACKUP_DIR"/*.tar.gz 2>/dev/null) ]]; then
        ls -lh "$BACKUP_DIR"/*.tar.gz | awk '{print "  " $9 " (" $5 ", " $6 " " $7 ")"}'
    else
        warn "No backups found in $BACKUP_DIR"
    fi
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
    fi
    
    log "🔄 Restoring from: $(basename "$backup_file")"
    
    # Create restore directory
    local restore_dir="$BACKUP_DIR/restore-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$restore_dir"
    
    # Extract backup
    tar -xzf "$backup_file" -C "$restore_dir"
    
    log "✅ Backup extracted to: $restore_dir"
    warn "⚠️  Manual review and application of restored files required"
}

# Cleanup old backups
cleanup_backups() {
    local retention_days="${1:-30}"
    log "🧹 Cleaning up backups older than $retention_days days"
    
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$retention_days -delete 2>/dev/null || true
    
    log "✅ Cleanup completed"
}

# Show help
show_help() {
    cat << EOF
Pro-Mata Simple Backup System

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  backup-configs      Backup configurations only
  backup-secrets      Backup secrets and env files
  backup-all          Full infrastructure backup
  list               List available backups
  restore FILE       Restore from backup file
  cleanup [DAYS]     Remove backups older than DAYS (default: 30)

Examples:
  $0 backup-all              # Full backup
  $0 backup-configs          # Config backup only
  $0 restore backup.tar.gz   # Restore specific backup
  $0 cleanup 7               # Remove backups >7 days old
EOF
}

# Main function
main() {
    init_backup
    
    case "${1:-}" in
        backup-configs)
            backup_configs
            ;;
        backup-secrets)
            backup_secrets
            ;;
        backup-all)
            backup_infrastructure
            ;;
        list)
            list_backups
            ;;
        restore)
            [[ -z "${2:-}" ]] && { show_help; exit 1; }
            restore_backup "$2"
            ;;
        cleanup)
            cleanup_backups "${2:-30}"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: ${1:-}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"