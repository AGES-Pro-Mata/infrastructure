#!/bin/bash
# Pro-Mata PostgreSQL User Initialization
set -e

echo "🔧 Criando usuários e databases para Pro-Mata..."

# Wait for PostgreSQL to be fully ready
until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  echo "Aguardando PostgreSQL estar pronto..."
  sleep 2
done

echo "PostgreSQL pronto, criando usuários..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Criar usuário de replicação
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'replicator') THEN
            CREATE ROLE replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD '${POSTGRES_REPLICA_PASSWORD:-replicator}';
            GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO replicator;
            GRANT SELECT ON ALL TABLES IN SCHEMA public TO replicator;
        ELSE
            ALTER ROLE replicator WITH ENCRYPTED PASSWORD '${POSTGRES_REPLICA_PASSWORD:-replicator}';
        END IF;
    END
    \$\$;
    
    -- Criar usuário para aplicação Pro-Mata
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'promata') THEN
            CREATE ROLE promata WITH LOGIN ENCRYPTED PASSWORD '${POSTGRES_PASSWORD:-promata}';
        ELSE
            ALTER ROLE promata WITH ENCRYPTED PASSWORD '${POSTGRES_PASSWORD:-promata}';
        END IF;
    END
    \$\$;
    
    -- Criar databases do Pro-Mata se não existirem
    SELECT 'CREATE DATABASE promata_dev OWNER promata'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'promata_dev')\gexec
    
    SELECT 'CREATE DATABASE promata_prod OWNER promata'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'promata_prod')\gexec
    
    SELECT 'CREATE DATABASE promata_test OWNER promata'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'promata_test')\gexec
EOSQL

# Configure permissions for each database
for db in promata_dev promata_prod promata_test; do
    echo "Configurando permissões para $db..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<-EOSQL
        GRANT CONNECT ON DATABASE $db TO promata;
        GRANT USAGE ON SCHEMA public TO promata;
        GRANT CREATE ON SCHEMA public TO promata;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO promata;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO promata;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO promata;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO promata;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO promata;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON FUNCTIONS TO promata;
EOSQL
done

echo "✅ Usuários e databases criados com sucesso!"
echo "👤 Usuários criados:"
echo "   - replicator (replicação)"
echo "   - promata (aplicação)"
echo "🗄️  Databases criadas:"
echo "   - promata_dev"
echo "   - promata_prod"  
echo "   - promata_test"