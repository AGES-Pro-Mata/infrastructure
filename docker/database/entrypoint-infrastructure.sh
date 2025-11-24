#!/bin/bash
# Pro-Mata Infrastructure PostgreSQL Custom Entrypoint
set -Eeo pipefail

echo "🚀 Pro-Mata Infrastructure Database Starting..."
echo "Base Image: norohim/pro-mata-database"
echo "Infrastructure Layer: Production Configuration"

# Source the base entrypoint functions if available
if [ -f "/app/start-database.sh" ]; then
    echo "📦 Base database functionality available"
fi

# Infrastructure-specific initialization
infrastructure_init() {
    echo "🏗️  Infrastructure-specific initialization..."
    
    # Create infrastructure-specific backup directory structure
    mkdir -p /var/lib/postgresql/backups/daily
    mkdir -p /var/lib/postgresql/backups/weekly
    mkdir -p /var/lib/postgresql/backups/monthly
    mkdir -p /var/lib/postgresql/backups/wal
    
    # Set proper ownership
    chown -R postgres:postgres /var/lib/postgresql/backups
    
    # Copy PostgreSQL configuration files to proper locations
    if [ -f "/etc/postgresql/postgresql.conf" ]; then
        echo "📄 Using custom PostgreSQL configuration..."
        # Configuration will be used by postgres command, not initdb
    fi
    
    if [ -f "/etc/postgresql/pg_hba.conf" ]; then
        echo "📄 Using custom pg_hba configuration..."
        # Configuration will be used by postgres command, not initdb
    fi
    
    # Set up enhanced log rotation for infrastructure
    cat > /etc/logrotate.d/postgresql-infrastructure << 'EOF'
/var/lib/postgresql/data/log/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 640 postgres postgres
    postrotate
        /usr/bin/killall -HUP postgres 2> /dev/null || true
    endscript
}
EOF
    
    echo "✅ Infrastructure initialization completed!"
}

# Enhanced health check function for production
infrastructure_health_check() {
    local retries=5
    local count=0
    
    while [ $count -lt $retries ]; do
        if pg_isready -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}" -h localhost; then
            echo "✅ PostgreSQL Infrastructure is healthy"
            return 0
        else
            echo "⏳ Health check attempt $((count+1))/$retries..."
            count=$((count+1))
            sleep 2
        fi
    done
    
    echo "❌ PostgreSQL Infrastructure health check failed"
    return 1
}

# Setup replication for production if needed
setup_production_replication() {
    if [ "${POSTGRES_REPLICATION_MODE}" = "replica" ]; then
        echo "🔄 Setting up production replica..."
        
        # Wait for primary to be ready
        until pg_isready -h ${POSTGRES_PRIMARY_HOST} -p 5432; do
            echo "⏳ Waiting for primary PostgreSQL..."
            sleep 5
        done
        
        # Take base backup from primary
        echo "📦 Creating base backup from primary..."
        pg_basebackup -h ${POSTGRES_PRIMARY_HOST} -D ${PGDATA} -U ${POSTGRES_REPLICATION_USER} -W -R
        
        echo "✅ Production replica configured!"
    fi
}

# Main execution
main() {
    echo "🚀 Starting Pro-Mata Infrastructure PostgreSQL..."
    echo "Version: PostgreSQL $(postgres --version)"
    echo "Timezone: $(date +'%Z %z')"
    echo "Cluster: ${CLUSTER_NAME:-promata-cluster}"
    
    # Run infrastructure-specific initialization
    infrastructure_init
    
    # Always delegate to base image entrypoint which handles everything correctly
    echo "� Delegating to base image entrypoint..."
    exec docker-entrypoint.sh "$@"
}

# Execute main function
main "$@"