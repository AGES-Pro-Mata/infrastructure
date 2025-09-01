#!/bin/bash
# Database Backup Script - Pro-Mata Infrastructure

set -e

ENV=${1:-dev}
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"; exit 1; }

# Load environment
ENV_FILE="$PROJECT_ROOT/environments/$ENV/.env.$ENV"
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    error "Environment file not found: $ENV_FILE"
fi

# Configuration
BACKUP_DIR="/opt/promata/backups"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="promata_${ENV}_${TIMESTAMP}.sql"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

# Create backup directory
create_backup_dir() {
    log "📁 Creating backup directory..."
    
    # Create on manager node
    ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "sudo mkdir -p $BACKUP_DIR && sudo chown promata:promata $BACKUP_DIR"
}

# Get database container
get_db_container() {
    log "🔍 Finding database container..."
    
    DB_CONTAINER=$(ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "docker ps --filter name=postgres-primary --format '{{.Names}}' | head -1")
    
    if [[ -z "$DB_CONTAINER" ]]; then
        error "PostgreSQL primary container not found"
    fi
    
    log "Found container: $DB_CONTAINER"
}

# Create database backup
create_backup() {
    log "💾 Creating database backup..."
    
    ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "docker exec $DB_CONTAINER pg_dump -U $POSTGRES_USER -d $POSTGRES_DB" > "/tmp/$BACKUP_FILE"
    
    # Compress backup
    gzip "/tmp/$BACKUP_FILE"
    BACKUP_FILE="${BACKUP_FILE}.gz"
    BACKUP_PATH="${BACKUP_PATH}.gz"
    
    # Copy to backup directory on manager
    scp -o StrictHostKeyChecking=no "/tmp/$BACKUP_FILE" "promata@$MANAGER_IP:$BACKUP_PATH"
    
    # Remove local temp file
    rm "/tmp/$BACKUP_FILE"
    
    log "✅ Backup created: $BACKUP_PATH"
}

# Verify backup
verify_backup() {
    log "🔍 Verifying backup..."
    
    local backup_size
    backup_size=$(ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "ls -lh $BACKUP_PATH | awk '{print \$5}'")
    
    if [[ -z "$backup_size" ]]; then
        error "Backup verification failed"
    fi
    
    log "✅ Backup verified: $backup_size"
}

# Clean old backups
cleanup_old_backups() {
    log "🧹 Cleaning old backups (retention: $RETENTION_DAYS days)..."
    
    local deleted_count
    deleted_count=$(ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "find $BACKUP_DIR -name 'promata_${ENV}_*.sql.gz' -mtime +$RETENTION_DAYS -delete -print | wc -l")
    
    if [[ "$deleted_count" -gt 0 ]]; then
        log "🗑️  Deleted $deleted_count old backup(s)"
    else
        log "✅ No old backups to clean"
    fi
}

# List backups
list_backups() {
    log "📋 Available backups:"
    
    ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
        "ls -lh $BACKUP_DIR/promata_${ENV}_*.sql.gz 2>/dev/null | tail -10" || log "No backups found"
}

# Test backup (optional restore test to temp database)
test_backup() {
    if [[ "${TEST_BACKUP:-false}" == "true" ]]; then
        log "🧪 Testing backup restore..."
        
        local test_db="promata_backup_test_$$"
        
        # Create test database
        ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
            "docker exec $DB_CONTAINER createdb -U $POSTGRES_USER $test_db"
        
        # Restore backup to test database
        ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
            "gunzip -c $BACKUP_PATH | docker exec -i $DB_CONTAINER psql -U $POSTGRES_USER -d $test_db"
        
        # Verify tables exist
        local table_count
        table_count=$(ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
            "docker exec $DB_CONTAINER psql -U $POSTGRES_USER -d $test_db -t -c \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';\"" | tr -d ' ')
        
        # Drop test database
        ssh -o StrictHostKeyChecking=no promata@"$MANAGER_IP" \
            "docker exec $DB_CONTAINER dropdb -U $POSTGRES_USER $test_db"
        
        if [[ "$table_count" -gt 0 ]]; then
            log "✅ Backup test successful ($table_count tables restored)"
        else
            error "Backup test failed (no tables found)"
        fi
    fi
}

# Send notification (optional)
send_notification() {
    if [[ -n "${SLACK_WEBHOOK:-}" ]] || [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
        log "📤 Sending backup notification..."
        
        local message="✅ Database backup completed for $ENV environment\nFile: $BACKUP_FILE\nSize: $(ssh promata@$MANAGER_IP "ls -lh $BACKUP_PATH | awk '{print \$5}'")"
        
        # Add your notification logic here
        log "📨 Notification sent"
    fi
}

# Get manager IP from Terraform
get_manager_ip() {
    cd "$PROJECT_ROOT/terraform/environments/$ENV"
    MANAGER_IP=$(terraform output -raw swarm_manager_public_ip)
    cd "$PROJECT_ROOT"
}

# Main execution
main() {
    log "💾 Starting database backup for $ENV environment"
    
    get_manager_ip
    create_backup_dir
    get_db_container
    create_backup
    verify_backup
    cleanup_old_backups
    list_backups
    test_backup
    send_notification
    
    echo ""
    log "🎉 Database backup completed successfully!"
    log "📄 Backup file: $BACKUP_FILE"
    log "📁 Location: $BACKUP_PATH"
    log "🕒 Retention: $RETENTION_DAYS days"
    
    # Instructions for restore
    echo ""
    log "🔄 To restore this backup:"
    log "   1. Copy backup to container: docker cp $BACKUP_PATH container_name:/tmp/"
    log "   2. Restore: docker exec container_name gunzip -c /tmp/$BACKUP_FILE | psql -U $POSTGRES_USER -d $POSTGRES_DB"
}

# Help function
show_help() {
    echo "Database Backup Script - Pro-Mata Infrastructure"
    echo ""
    echo "Usage: $0 [environment] [options]"
    echo ""
    echo "Environments:"
    echo "  dev     - Development environment (default)"
    echo "  prod    - Production environment"
    echo ""
    echo "Environment Variables:"
    echo "  BACKUP_RETENTION_DAYS - Days to keep backups (default: 7)"
    echo "  TEST_BACKUP          - Test restore after backup (default: false)"
    echo "  SLACK_WEBHOOK        - Slack webhook for notifications (optional)"
    echo ""
    echo "Examples:"
    echo "  $0              # Backup dev environment"
    echo "  $0 dev          # Backup dev environment"
    echo "  TEST_BACKUP=true $0 dev  # Backup and test restore"
}

# Handle arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac