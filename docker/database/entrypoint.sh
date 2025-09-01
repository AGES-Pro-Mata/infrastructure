#!/bin/bash
# Pro-Mata PostgreSQL Custom Entrypoint
set -Eeo pipefail

# Source original entrypoint functions
source /usr/local/bin/docker-entrypoint.sh

# Custom Pro-Mata initialization
promata_init() {
    echo "🏗️  Inicializando PostgreSQL Pro-Mata..."
    
    # Create backup directory structure
    mkdir -p /var/lib/postgresql/backups/daily
    mkdir -p /var/lib/postgresql/backups/weekly
    mkdir -p /var/lib/postgresql/backups/monthly
    mkdir -p /var/lib/postgresql/backups/wal
    
    chown -R postgres:postgres /var/lib/postgresql/backups
    
    # Set up log rotation
    cat > /etc/logrotate.d/postgresql << EOF
/var/lib/postgresql/data/log/*.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 640 postgres postgres
    postrotate
        /usr/bin/killall -HUP postgres 2> /dev/null || true
    endscript
}
EOF
    
    echo "✅ Pro-Mata PostgreSQL inicializado!"
}

# Custom health check function
promata_health_check() {
    if pg_isready -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}" -h localhost; then
        echo "✅ PostgreSQL Pro-Mata está saudável"
        return 0
    else
        echo "❌ PostgreSQL Pro-Mata não está respondendo"
        return 1
    fi
}

# Setup replication if in slave mode
setup_replication() {
    if [ "${POSTGRES_REPLICATION_MODE}" = "slave" ]; then
        echo "🔄 Configurando réplica PostgreSQL..."
        
        # Wait for primary to be ready
        until pg_isready -h ${POSTGRES_PRIMARY_HOST} -p 5432; do
            echo "Aguardando primary PostgreSQL..."
            sleep 5
        done
        
        # Take base backup from primary
        echo "📦 Criando backup base do primary..."
        pg_basebackup -h ${POSTGRES_PRIMARY_HOST} -D ${PGDATA} -U ${POSTGRES_REPLICATION_USER} -W -R
        
        echo "✅ Réplica configurada!"
    fi
}

# Main execution
main() {
    echo "🚀 Iniciando Pro-Mata PostgreSQL Container..."
    echo "Versão: PostgreSQL $(postgres --version)"
    echo "Timezone: $(date +'%Z %z')"
    
    # Run Pro-Mata initialization
    promata_init
    
    # Setup replication if needed
    setup_replication
    
    # Execute original entrypoint with all arguments
    exec docker-entrypoint.sh "$@"
}

# Execute main function
main "$@"