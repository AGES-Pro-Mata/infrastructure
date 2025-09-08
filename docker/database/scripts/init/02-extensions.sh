#!/bin/bash
# Pro-Mata PostgreSQL Extensions Installation
# Note: Using continue-on-error approach for optional extensions

echo "🔧 Instalando extensões PostgreSQL para Pro-Mata..."

# Function to install extension in database
install_extensions() {
    local db_name=$1
    echo "📦 Instalando extensões em $db_name..."
    
    # Core extensions (required)
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_name" <<-EOSQL
        -- UUID generation
        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
        
        -- Text search and similarity
        CREATE EXTENSION IF NOT EXISTS "pg_trgm";
        CREATE EXTENSION IF NOT EXISTS "unaccent";
        
        -- Advanced indexing
        CREATE EXTENSION IF NOT EXISTS "btree_gin";
        CREATE EXTENSION IF NOT EXISTS "btree_gist";
        
        -- Statistics and monitoring
        CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
        
        -- Additional useful extensions
        CREATE EXTENSION IF NOT EXISTS "ltree";
        CREATE EXTENSION IF NOT EXISTS "hstore";
EOSQL

    # PostGIS (optional - may fail if not installed)
    echo "📦 Tentando instalar PostGIS em $db_name..."
    psql --username "$POSTGRES_USER" --dbname "$db_name" <<-EOSQL 2>/dev/null || echo "⚠️  PostGIS não disponível em $db_name - continuando sem geospatial"
        CREATE EXTENSION IF NOT EXISTS "postgis";
        CREATE EXTENSION IF NOT EXISTS "postgis_topology";
EOSQL

    # Database configuration (required)
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_name" <<-EOSQL
        -- Configurações específicas para fuso horário brasileiro
        ALTER DATABASE ${db_name} SET timezone TO 'America/Sao_Paulo';
        ALTER DATABASE ${db_name} SET datestyle TO 'ISO, DMY';
        ALTER DATABASE ${db_name} SET lc_monetary TO 'pt_BR.UTF-8';
        ALTER DATABASE ${db_name} SET lc_numeric TO 'pt_BR.UTF-8';
        ALTER DATABASE ${db_name} SET lc_time TO 'pt_BR.UTF-8';
        
        -- Configurações de performance
        ALTER DATABASE ${db_name} SET shared_preload_libraries TO 'pg_stat_statements';
        ALTER DATABASE ${db_name} SET track_activity_query_size TO '2048';
        ALTER DATABASE ${db_name} SET pg_stat_statements.track TO 'all';
        
        -- Log slow queries (mais de 1 segundo)
        ALTER DATABASE ${db_name} SET log_min_duration_statement TO '1000';
        
        -- Configurações de trabalho para pesquisa científica
        ALTER DATABASE ${db_name} SET work_mem TO '8MB';
        ALTER DATABASE ${db_name} SET maintenance_work_mem TO '128MB';
EOSQL
    
    echo "✅ Extensões instaladas em $db_name"
}

# Install extensions in all Pro-Mata databases
install_extensions "promata_dev"
install_extensions "promata_prod"
install_extensions "promata_test"

echo "✅ Todas as extensões instaladas com sucesso!"
echo "📦 Extensões instaladas:"
echo "   - uuid-ossp (geração de UUIDs)"
echo "   - pg_trgm (busca de similaridade)"
echo "   - unaccent (remoção de acentos)"
echo "   - btree_gin/gist (índices avançados)"
echo "   - pg_stat_statements (estatísticas)"
echo "   - postgis (dados geoespaciais)"
echo "   - ltree (estruturas hierárquicas)"
echo "   - hstore (chave-valor)"