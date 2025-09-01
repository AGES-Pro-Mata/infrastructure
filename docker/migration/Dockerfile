# Pro-Mata Database Migration Container
FROM node:20-alpine

WORKDIR /app

# Install required tools
RUN apk add --no-cache postgresql-client openssl libc6-compat netcat-openbsd

# Copy only migration-related files
COPY package*.json ./
COPY prisma ./prisma/

# Install only production dependencies needed for migrations
RUN npm ci --only=production && npm cache clean --force
RUN npx prisma generate

# Migration script
COPY <<'EOF' /app/migrate.sh
#!/bin/sh
set -e

echo "🔄 Pro-Mata Database Migration Tool"
echo "Environment: ${NODE_ENV:-development}"
echo "Database Host: ${DB_HOST:-postgres-primary}"
echo "Database Port: ${DB_PORT:-5432}"

# Wait for database to be ready
echo "⏳ Aguardando PostgreSQL..."
until pg_isready -h ${DB_HOST:-postgres-primary} -p ${DB_PORT:-5432} -U ${POSTGRES_USER:-promata}; do
    echo "   Banco não disponível, tentando novamente..."
    sleep 5
done
echo "✅ PostgreSQL disponível!"

# Check database connection with Prisma
echo "🔍 Verificando conexão com Prisma..."
if ! node -e "
const { PrismaClient } = require('@prisma/client');
new PrismaClient().\$connect()
  .then(() => {
    console.log('✅ Prisma conectado com sucesso!');
    process.exit(0);
  })
  .catch(e => {
    console.error('❌ Erro na conexão Prisma:', e.message);
    process.exit(1);
  })
"; then
    echo "❌ Falha na conexão com banco via Prisma"
    exit 1
fi

# Create backup if in production
if [ "$NODE_ENV" = "production" ]; then
    echo "📦 Criando backup de segurança..."
    BACKUP_FILE="/tmp/backup-$(date +%Y%m%d-%H%M%S).sql"
    if pg_dump "${DATABASE_URL}" > "$BACKUP_FILE" 2>/dev/null; then
        echo "✅ Backup criado: $BACKUP_FILE"
        # Optionally upload to storage (implement as needed)
    else
        echo "⚠️  Backup falhou, continuando com migrações..."
    fi
fi

# Check migration status
echo "🔍 Verificando status das migrações..."
if npx prisma migrate status; then
    echo "📋 Status das migrações verificado"
else
    echo "⚠️  Problemas no status das migrações, tentando resolver..."
fi

# Deploy migrations
echo "🔄 Executando migrações..."
if npx prisma migrate deploy; then
    echo "✅ Migrações executadas com sucesso!"
else
    echo "❌ Erro ao executar migrações!"
    exit 1
fi

# Seed database if requested
if [ "$RUN_SEED" = "true" ]; then
    echo "🌱 Executando seed do banco..."
    if npx prisma db seed; then
        echo "✅ Seed executado com sucesso!"
    else
        echo "⚠️  Seed não disponível ou falhou"
    fi
fi

# Final verification
echo "🏥 Verificação final da conectividade..."
if node -e "
const { PrismaClient } = require('@prisma/client');
new PrismaClient().\$connect()
  .then(() => {
    console.log('✅ Verificação final: Conexão OK');
    process.exit(0);
  })
  .catch(e => {
    console.error('❌ Verificação final falhou:', e.message);
    process.exit(1);
  })
"; then
    echo "✅ Migration container completado com sucesso!"
else
    echo "❌ Verificação final falhou!"
    exit 1
fi
EOF

RUN chmod +x /app/migrate.sh

# Health check for init container
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD pg_isready -h ${DB_HOST:-postgres-primary} -p ${DB_PORT:-5432} -U ${POSTGRES_USER:-promata} || exit 1

ENTRYPOINT ["/app/migrate.sh"]