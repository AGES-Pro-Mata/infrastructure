#!/bin/bash
# PostgreSQL Replica Setup Script
# This script sets up the PostgreSQL replica (standby) server

set -e

echo "Setting up PostgreSQL replica..."

# Environment variables check
if [[ -z "$POSTGRES_PRIMARY_HOST" || -z "$POSTGRES_REPLICATION_USER" || -z "$POSTGRES_REPLICATION_PASSWORD" ]]; then
    echo "Error: Required environment variables not set"
    echo "Required: POSTGRES_PRIMARY_HOST, POSTGRES_REPLICATION_USER, POSTGRES_REPLICATION_PASSWORD"
    exit 1
fi

# Wait for primary to be ready
echo "Waiting for primary database to be ready..."
until pg_isready -h "$POSTGRES_PRIMARY_HOST" -p 5432 -U "$POSTGRES_REPLICATION_USER"; do
    echo "Primary database not ready, waiting..."
    sleep 5
done

echo "Primary database is ready. Setting up replica..."

# Remove any existing data directory contents
rm -rf /var/lib/postgresql/data/*

# Take base backup from primary
export PGPASSWORD="$POSTGRES_REPLICATION_PASSWORD"
pg_basebackup -h "$POSTGRES_PRIMARY_HOST" -D /var/lib/postgresql/data -U "$POSTGRES_REPLICATION_USER" -v -P -W -R

# Set proper permissions
chown -R postgres:postgres /var/lib/postgresql/data
chmod -R 700 /var/lib/postgresql/data

# Create replication slot on primary if it doesn't exist
psql -h "$POSTGRES_PRIMARY_HOST" -U "$POSTGRES_REPLICATION_USER" -d postgres -c "SELECT pg_create_physical_replication_slot('replica_slot');" || echo "Replication slot may already exist"

# Create recovery configuration for PostgreSQL 12+
cat >> /var/lib/postgresql/data/postgresql.conf << EOF

# Replica specific settings
hot_standby = on
hot_standby_feedback = on
max_standby_streaming_delay = 30s
max_standby_archive_delay = 30s
primary_conninfo = 'host=$POSTGRES_PRIMARY_HOST port=5432 user=$POSTGRES_REPLICATION_USER password=$POSTGRES_REPLICATION_PASSWORD application_name=postgres-replica'
primary_slot_name = 'replica_slot'
EOF

# Create standby signal file (PostgreSQL 12+)
touch /var/lib/postgresql/data/standby.signal

# Create archive directory
mkdir -p /var/lib/postgresql/archive
chown postgres:postgres /var/lib/postgresql/archive

echo "PostgreSQL replica setup completed successfully."
echo "Primary host: $POSTGRES_PRIMARY_HOST"
echo "Replication user: $POSTGRES_REPLICATION_USER"