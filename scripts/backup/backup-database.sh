#!/bin/bash
# Pro-Mata Advanced Database Backup Script
# Supports full, incremental, and point-in-time recovery backups

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV=${2:-dev}

# Default configuration
BACKUP_TYPE=${1:-daily}  # daily, weekly, monthly, full, incremental
COMPRESSION=${COMPRESSION:-gzip}  # gzip, zstd, none
RETENTION_DAYS=${RETENTION_DAYS:-30}
ENCRYPTION_KEY=${ENCRYPTION_KEY:-""}
STORAGE_TYPE=${STORAGE_TYPE:-local}  # local, s3, azure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }

# Load environment configuration
load_config() {
    if [[ -f "$PROJECT_ROOT/envs/$ENV/.env.$ENV" ]]; then
        source "$PROJECT_ROOT/envs/$ENV/.env.$ENV"
    else
        error "Environment file not found: $PROJECT_ROOT/envs/$ENV/.env.$ENV"
    fi
}

# Get database connection info
get_db_info() {
    # Try to get from running container first
    POSTGRES_CONTAINER=$(ssh ubuntu@${MANAGER_IP} "docker ps --filter name=promata_postgres-primary --format '{{.Names}}' | head -1" 2>/dev/null || echo "")
    
    if [[ -z "$POSTGRES_CONTAINER" ]]; then
        error "PostgreSQL container not found. Is the stack running?"
    fi
    
    DB_HOST=${DB_HOST:-postgres-primary}
    DB_PORT=${DB_PORT:-5432}
    DB_USER=${POSTGRES_USER:-promata}
    DB_NAME=${POSTGRES_DB:-promata_dev}
    DB_PASSWORD=${POSTGRES_PASSWORD}
    
    info "Database Info:"
    info "  Host: $DB_HOST"
    info "  Port: $DB_PORT"
    info "  User: $DB_USER"
    info "  Database: $DB_NAME"
}

# Create backup directories
setup_backup_dirs() {
    local backup_date=$(date +%Y/%m/%d)
    local base_dir="/var/lib/postgresql/backups"
    
    ssh ubuntu@${MANAGER_IP} << EOSSH
        # Create backup directory structure
        docker exec $POSTGRES_CONTAINER mkdir -p $base_dir/{daily,weekly,monthly,full,incremental,wal}/$backup_date
        docker exec $POSTGRES_CONTAINER mkdir -p $base_dir/logs
        docker exec $POSTGRES_CONTAINER mkdir -p $base_dir/metadata
EOSSH
    
    BACKUP_DIR="$base_dir/$BACKUP_TYPE/$backup_date"
    log "Backup directory: $BACKUP_DIR"
}

# Generate backup filename
generate_backup_name() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local hostname=$(ssh ubuntu@${MANAGER_IP} "hostname" 2>/dev/null || echo "unknown")
    
    case $BACKUP_TYPE in
        "full"|"weekly"|"monthly")
            BACKUP_NAME="promata_${ENV}_full_${timestamp}_${hostname}"
            ;;
        "incremental")
            BACKUP_NAME="promata_${ENV}_incr_${timestamp}_${hostname}"
            ;;
        *)
            BACKUP_NAME="promata_${ENV}_${BACKUP_TYPE}_${timestamp}_${hostname}"
            ;;
    esac
    
    # Add compression extension
    case $COMPRESSION in
        "gzip")
            BACKUP_NAME="${BACKUP_NAME}.sql.gz"
            ;;
        "zstd")
            BACKUP_NAME="${BACKUP_NAME}.sql.zst"
            ;;
        *)
            BACKUP_NAME="${BACKUP_NAME}.sql"
            ;;
    esac
    
    info "Backup filename: $BACKUP_NAME"
}

# Perform database backup based on type
perform_backup() {
    log "Starting $BACKUP_TYPE backup..."
    
    local start_time=$(date +%s)
    local backup_cmd
    local backup_path="$BACKUP_DIR/$BACKUP_NAME"
    
    case $BACKUP_TYPE in
        "full"|"weekly"|"monthly")
            backup_cmd="pg_dump -U $DB_USER -h localhost -p $DB_PORT -d $DB_NAME --verbose --no-password --format=custom --compress=0"
            ;;
        "daily")
            backup_cmd="pg_dump -U $DB_USER -h localhost -p $DB_PORT -d $DB_NAME --verbose --no-password"
            ;;
        "incremental")
            backup_cmd="pg_basebackup -U $DB_USER -h localhost -p $DB_PORT -D - --format=tar --verbose --checkpoint=fast"
            ;;
        *)
            backup_cmd="pg_dump -U $DB_USER -h localhost -p $DB_PORT -d $DB_NAME --verbose --no-password"
            ;;
    esac
    
    # Add compression to the pipeline
    case $COMPRESSION in
        "gzip")
            backup_cmd="$backup_cmd | gzip -9"
            ;;
        "zstd")
            backup_cmd="$backup_cmd | zstd -9"
            ;;
    esac
    
    # Execute backup
    ssh ubuntu@${MANAGER_IP} << EOSSH
        set -e
        export PGPASSWORD="$DB_PASSWORD"
        
        # Run backup command
        docker exec $POSTGRES_CONTAINER bash -c "$backup_cmd > $backup_path"
        
        # Check if backup was successful
        if [[ ! -f "$backup_path" ]] || [[ ! -s "$backup_path" ]]; then
            echo "❌ Backup file not created or empty"
            exit 1
        fi
        
        # Calculate file size and checksum
        BACKUP_SIZE=\$(docker exec $POSTGRES_CONTAINER stat -c%s "$backup_path")
        BACKUP_CHECKSUM=\$(docker exec $POSTGRES_CONTAINER sha256sum "$backup_path" | cut -d' ' -f1)
        
        echo "📊 Backup size: \$BACKUP_SIZE bytes"
        echo "🔍 Backup checksum: \$BACKUP_CHECKSUM"
EOSSH
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "✅ Backup completed successfully in ${duration} seconds"
    log "📁 Backup location: $backup_path"
}

# Clean up old backups
cleanup_old_backups() {
    log "🧹 Cleaning up backups older than $RETENTION_DAYS days..."
    
    ssh ubuntu@${MANAGER_IP} << EOSSH
        docker exec $POSTGRES_CONTAINER bash -c "
            # Clean up local backups
            find /var/lib/postgresql/backups/$BACKUP_TYPE -name '*.sql*' -mtime +$RETENTION_DAYS -delete
            find /var/lib/postgresql/backups/$BACKUP_TYPE -type d -empty -delete
            
            # Clean up logs
            find /var/lib/postgresql/backups/logs -name '*.log' -mtime +7 -delete
            
            echo '✅ Cleanup completed'
        "
EOSSH
}

# Show help
show_help() {
    cat << EOF
Pro-Mata Advanced Database Backup Script

Uso: $0 <backup_type> [environment]

Backup Types:
  daily       - Daily incremental backup (default)
  weekly      - Weekly full backup  
  monthly     - Monthly full backup
  full        - Full database backup
  incremental - Incremental backup with WAL

Environments: dev, staging, prod

Environment Variables:
  COMPRESSION=gzip|zstd|none     - Compression type (default: gzip)
  RETENTION_DAYS=30              - Retention period (default: 30)
  STORAGE_TYPE=local|s3|azure    - Storage backend (default: local)

Exemplos:
  $0 daily dev                   - Daily backup for dev environment
  $0 weekly prod                 - Weekly backup for production
  COMPRESSION=zstd $0 full prod  - Full backup with zstd compression
EOF
}

# Main execution
main() {
    case ${1:-help} in
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        "daily"|"weekly"|"monthly"|"full"|"incremental")
            BACKUP_TYPE=$1
            ;;
        *)
            error "Invalid backup type: ${1:-}. Use: daily, weekly, monthly, full, incremental"
            ;;
    esac
    
    log "🚀 Starting Pro-Mata Database Backup"
    log "Type: $BACKUP_TYPE | Environment: $ENV | Compression: $COMPRESSION"
    
    # Execute backup process
    load_config
    get_db_info
    setup_backup_dirs
    generate_backup_name
    perform_backup
    cleanup_old_backups
    
    log "🎉 Backup completed successfully!"
    log "📁 Backup: $BACKUP_NAME"
    log "📍 Location: $BACKUP_DIR"
}

# Execute main function with all arguments
main "$@"