#!/bin/bash
# Pro-Mata PostgreSQL User Initialization
set -e

echo "🔧 Criando usuários e databases para Pro-Mata..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Criar usuário de replicação
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'replicator') THEN
            CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '${POSTGRES_REPLICA_PASSWORD:-replica_password}';
            GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO replicator;
        END IF;
    END
    \$\$;
    
    -- Criar usuário para aplicação Pro-Mata
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'promata_app') THEN
            CREATE USER promata_app WITH ENCRYPTED PASSWORD '${POSTGRES_APP_PASSWORD:-app_password}';
        END IF;
    END
    \$\$;
    
    -- Criar databases do Pro-Mata se não existirem
    SELECT 'CREATE DATABASE promata_dev OWNER promata_app'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'promata_dev')\gexec
    
    SELECT 'CREATE DATABASE promata_prod OWNER promata_app'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'promata_prod')\gexec
    
    SELECT 'CREATE DATABASE promata_test OWNER promata_app'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'promata_test')\gexec
    
    -- Configurar permissões para promata_app
    \c promata_dev
    GRANT CONNECT ON DATABASE promata_dev TO promata_app;
    GRANT USAGE ON SCHEMA public TO promata_app;
    GRANT CREATE ON SCHEMA public TO promata_app;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO promata_app;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO promata_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO promata_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO promata_app;
    
    \c promata_prod
    GRANT CONNECT ON DATABASE promata_prod TO promata_app;
    GRANT USAGE ON SCHEMA public TO promata_app;
    GRANT CREATE ON SCHEMA public TO promata_app;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO promata_app;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO promata_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO promata_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO promata_app;
    
    \c promata_test
    GRANT CONNECT ON DATABASE promata_test TO promata_app;
    GRANT USAGE ON SCHEMA public TO promata_app;
    GRANT CREATE ON SCHEMA public TO promata_app;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO promata_app;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO promata_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO promata_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO promata_app;
EOSQL

echo "✅ Usuários e databases criados com sucesso!"
echo "👤 Usuários criados:"
echo "   - replicator (replicação)"
echo "   - promata_app (aplicação)"
echo "🗄️  Databases criadas:"
echo "   - promata_dev"
echo "   - promata_prod"  
echo "   - promata_test"