#!/bin/bash
# Pro-Mata Database Restore Script
# Restores database backups with safety checks

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV=${2:-dev}

# Parameters
BACKUP_FILE=${1:-""}
FORCE_RESTORE=${FORCE_RESTORE:-false}
CREATE_BACKUP_BEFORE_RESTORE=${CREATE_BACKUP_BEFORE_RESTORE:-true}

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

# Safety check for production environment
safety_check() {
    if [[ "$ENV" == "prod" ]] && [[ "$FORCE_RESTORE" != "true" ]]; then
        error "Production database restore requires FORCE_RESTORE=true"
    fi
    
    if [[ "$ENV" == "prod" ]]; then
        warn "You are about to restore PRODUCTION database!"
        read -p "Type 'yes' to continue: " confirmation
        if [[ "$confirmation" != "yes" ]]; then
            error "Restore cancelled by user"
        fi
    fi
}

# Get database info
get_db_info() {
    POSTGRES_CONTAINER=$(ssh ubuntu@${MANAGER_IP} "docker ps --filter name=promata_postgres-primary --format '{{.Names}}' | head -1" 2>/dev/null || echo "")
    
    if [[ -z "$POSTGRES_CONTAINER" ]]; then
        error "PostgreSQL container not found. Is the stack running?"
    fi
    
    DB_USER=${POSTGRES_USER:-promata}
    DB_NAME=${POSTGRES_DB:-promata_dev}
    DB_PASSWORD=${POSTGRES_PASSWORD}
    
    info "Database Info:"
    info "  Container: $POSTGRES_CONTAINER"
    info "  User: $DB_USER"
    info "  Database: $DB_NAME"
}

# List available backups
list_available_backups() {
    log "📋 Available backups for $ENV environment:"
    
    ssh ubuntu@${MANAGER_IP} << EOSSH
        # Find all backup files
        find /var/lib/postgresql/backups -name "*${ENV}*" -type f | sort -r | head -20
EOSSH
}

# Validate backup file
validate_backup_file() {
    if [[ -z "$BACKUP_FILE" ]]; then
        error "Backup file not specified. Use: $0 <backup_file> [environment]"
    fi
    
    # Check if backup file exists
    if ! ssh ubuntu@${MANAGER_IP} "docker exec $POSTGRES_CONTAINER test -f '$BACKUP_FILE'"; then
        error "Backup file not found: $BACKUP_FILE"
    fi
    
    info "Backup file validated: $BACKUP_FILE"
}

# Create backup before restore (safety measure)
create_pre_restore_backup() {
    if [[ "$CREATE_BACKUP_BEFORE_RESTORE" == "true" ]]; then
        log "📦 Creating backup before restore (safety measure)..."
        
        local pre_restore_backup="/var/lib/postgresql/backups/pre-restore-$(date +%Y%m%d_%H%M%S).sql.gz"
        
        ssh ubuntu@${MANAGER_IP} << EOSSH
            export PGPASSWORD="$DB_PASSWORD"
            docker exec $POSTGRES_CONTAINER pg_dump -U $DB_USER -d $DB_NAME | gzip > "$pre_restore_backup"
            echo "✅ Pre-restore backup created: $pre_restore_backup"
EOSSH
        
        log "✅ Pre-restore backup completed"
    fi
}

# Stop application services during restore
stop_application_services() {
    log "⏸️  Stopping application services..."
    
    ssh ubuntu@${MANAGER_IP} << EOSSH
        # Scale down application services to prevent connections
        docker service scale promata_backend=0
        docker service scale promata_frontend=0
        
        # Wait for services to stop
        sleep 30
        
        echo "✅ Application services stopped"
EOSSH
}

# Start application services after restore
start_application_services() {
    log "▶️  Starting application services..."
    
    ssh ubuntu@${MANAGER_IP} << EOSSH
        # Scale back up application services
        docker service scale promata_backend=${BACKEND_REPLICAS:-3}
        docker service scale promata_frontend=${FRONTEND_REPLICAS:-2}
        
        # Wait for services to be ready
        sleep 60
        
        echo "✅ Application services restarted"
EOSSH
}

# Perform database restore
perform_restore() {
    log "🔄 Starting database restore..."
    
    local restore_start=$(date +%s)
    
    # Determine restore command based on file type
    local restore_cmd
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        restore_cmd="gunzip -c $BACKUP_FILE | psql -U $DB_USER -d $DB_NAME"
    elif [[ "$BACKUP_FILE" == *.zst ]]; then
        restore_cmd="zstdcat $BACKUP_FILE | psql -U $DB_USER -d $DB_NAME"
    elif [[ "$BACKUP_FILE" == *.sql ]]; then
        restore_cmd="psql -U $DB_USER -d $DB_NAME < $BACKUP_FILE"
    else
        restore_cmd="pg_restore -U $DB_USER -d $DB_NAME --clean --if-exists $BACKUP_FILE"
    fi
    
    ssh ubuntu@${MANAGER_IP} << EOSSH
        export PGPASSWORD="$DB_PASSWORD"
        
        # Drop existing connections
        docker exec $POSTGRES_CONTAINER psql -U $DB_USER -d postgres -c "
            SELECT pg_terminate_backend(pid) 
            FROM pg_stat_activity 
            WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"
        
        # Perform restore
        echo "🔄 Executing restore command..."
        if docker exec $POSTGRES_CONTAINER bash -c "$restore_cmd"; then
            echo "✅ Database restore completed successfully"
        else
            echo "❌ Database restore failed"
            exit 1
        fi
        
        # Update database statistics
        docker exec $POSTGRES_CONTAINER psql -U $DB_USER -d $DB_NAME -c "ANALYZE;"
        
        echo "📊 Database statistics updated"
EOSSH
    
    local restore_end=$(date +%s)
    local duration=$((restore_end - restore_start))
    
    log "✅ Database restore completed in ${duration} seconds"
}

# Verify restore integrity
verify_restore() {
    log "🔍 Verifying restore integrity..."
    
    ssh ubuntu@${MANAGER_IP} << EOSSH
        export PGPASSWORD="$DB_PASSWORD"
        
        # Check if database is accessible
        if ! docker exec $POSTGRES_CONTAINER psql -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null; then
            echo "❌ Database not accessible after restore"
            exit 1
        fi
        
        # Count tables
        TABLE_COUNT=\$(docker exec $POSTGRES_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" | tr -d ' ')
        
        if [[ "\$TABLE_COUNT" -gt 0 ]]; then
            echo "✅ Restore verification passed: \$TABLE_COUNT tables found"
        else
            echo "❌ Restore verification failed: no tables found"
            exit 1
        fi
        
        # Check for Prisma migrations table
        if docker exec $POSTGRES_CONTAINER psql -U $DB_USER -d $DB_NAME -c "\\dt _prisma_migrations" > /dev/null 2>&1; then
            MIGRATION_COUNT=\$(docker exec $POSTGRES_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "
                SELECT COUNT(*) FROM _prisma_migrations;" | tr -d ' ')
            echo "📋 Migrations found: \$MIGRATION_COUNT"
        fi
EOSSH
    
    log "✅ Restore verification completed"
}

# Generate restore report
generate_report() {
    log "📊 Generating restore report..."
    
    local report_file="/tmp/restore_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
# Pro-Mata Database Restore Report
Date: $(date)
Environment: $ENV
Backup File: $BACKUP_FILE

## Restore Details
Status: Success
Duration: $(date)

## Database Information
Container: $POSTGRES_CONTAINER
User: $DB_USER
Database: $DB_NAME

## Verification Results
EOF

    # Add verification results
    ssh ubuntu@${MANAGER_IP} << EOSSH
        export PGPASSWORD="$DB_PASSWORD"
        
        # Get table count
        TABLE_COUNT=\$(docker exec $POSTGRES_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_schema = 'public';" | tr -d ' ')
        
        echo "Tables Restored: \$TABLE_COUNT" >> /tmp/restore_report_*.txt
        
        # Get database size
        DB_SIZE=\$(docker exec $POSTGRES_CONTAINER psql -U $DB_USER -d $DB_NAME -t -c "
            SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" | tr -d ' ')
        
        echo "Database Size: \$DB_SIZE" >> /tmp/restore_report_*.txt
EOSSH
    
    log "📊 Restore report generated: $(basename $report_file)"
}

# Show help
show_help() {
    cat << EOF
Pro-Mata Database Restore Script

Uso: $0 <backup_file> [environment]

Parameters:
  backup_file    - Path to backup file to restore
  environment    - Target environment (dev, staging, prod)

Environment Variables:
  FORCE_RESTORE=true                    - Force restore in production
  CREATE_BACKUP_BEFORE_RESTORE=false   - Skip pre-restore backup
  
Safety Features:
  - Creates backup before restore (can be disabled)
  - Stops application during restore
  - Verifies restore integrity
  - Requires confirmation for production

Examples:
  # List available backups
  $0 list dev
  
  # Restore specific backup
  $0 /var/lib/postgresql/backups/daily/2024/01/15/promata_dev_20240115_120000.sql.gz dev
  
  # Force production restore
  FORCE_RESTORE=true $0 backup_file.sql.gz prod

Commands:
  list <env>     - List available backups
  help          - Show this help
EOF
}

# Main execution
main() {
    case ${1:-help} in
        "list")
            load_config
            list_available_backups
            exit 0
            ;;
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        *)
            if [[ -z "${1:-}" ]]; then
                show_help
                exit 1
            fi
            BACKUP_FILE=$1
            ;;
    esac
    
    log "🔄 Starting Pro-Mata Database Restore"
    log "Backup: $BACKUP_FILE | Environment: $ENV"
    
    # Execute restore process
    load_config
    safety_check
    get_db_info
    validate_backup_file
    create_pre_restore_backup
    stop_application_services
    
    # Perform the restore
    perform_restore
    verify_restore
    
    # Restart services
    start_application_services
    generate_report
    
    log "🎉 Database restore completed successfully!"
    log "📁 Backup restored: $BACKUP_FILE"
    log "🗄️  Database: $DB_NAME"
    
    warn "🔍 Please verify your application is working correctly"
}

# Execute main function with all arguments
main "$@"