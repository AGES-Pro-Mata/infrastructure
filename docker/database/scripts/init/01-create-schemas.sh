#!/bin/bash
# Create separate schemas for each service in single database

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create schemas
    CREATE SCHEMA IF NOT EXISTS app;
    CREATE SCHEMA IF NOT EXISTS umami;
    CREATE SCHEMA IF NOT EXISTS metabase;

    -- Set search path default to app schema
    ALTER DATABASE ${POSTGRES_DB} SET search_path TO app,public;

    -- Grant permissions
    GRANT ALL PRIVILEGES ON SCHEMA app TO ${POSTGRES_USER};
    GRANT ALL PRIVILEGES ON SCHEMA umami TO ${POSTGRES_USER};
    GRANT ALL PRIVILEGES ON SCHEMA metabase TO ${POSTGRES_USER};

    -- Info
    SELECT 'Schemas created successfully:' AS status;
    SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('app', 'umami', 'metabase');
EOSQL

echo "✅ Database schemas initialized successfully!"
