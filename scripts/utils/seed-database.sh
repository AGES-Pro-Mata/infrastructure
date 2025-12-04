#!/bin/bash
# ============================================
# PRO-MATA - Database Seed Script
# ============================================
# Executa o seed do banco APÓS as migrations do Prisma
# 
# Uso:
#   ./scripts/utils/seed-database.sh
#   
# Pré-requisitos:
#   - PostgreSQL rodando e healthy
#   - Backend rodou prisma migrate deploy (tabelas existem)
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SEED_FILE="$PROJECT_ROOT/docker/database/scripts/seed-client.sql"

echo "🌱 Pro-Mata Database Seed"
echo "========================="

# Verificar se está no diretório correto
if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    echo "❌ Erro: Execute este script da raiz do projeto infrastructure"
    exit 1
fi

# Verificar se o arquivo de seed existe
if [ ! -f "$SEED_FILE" ]; then
    echo "❌ Erro: Arquivo de seed não encontrado: $SEED_FILE"
    exit 1
fi

cd "$PROJECT_ROOT"

# Verificar se o postgres está rodando
echo "🔍 Verificando PostgreSQL..."
if ! docker compose exec -T postgres pg_isready -U promata > /dev/null 2>&1; then
    echo "❌ Erro: PostgreSQL não está rodando ou não está healthy"
    echo "   Execute: docker compose up -d postgres"
    exit 1
fi

# Verificar se as tabelas do Prisma existem
echo "🔍 Verificando se as tabelas existem..."
TABLE_COUNT=$(docker compose exec -T postgres psql -U promata -d promata -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'app';" 2>/dev/null | tr -d ' ')

if [ "$TABLE_COUNT" -lt 1 ]; then
    echo "❌ Erro: Tabelas não encontradas no schema 'app'"
    echo "   Execute primeiro: docker compose exec backend npx prisma migrate deploy"
    exit 1
fi

echo "✅ Encontradas $TABLE_COUNT tabelas no schema 'app'"

# Executar o seed
echo "🌱 Executando seed..."
docker compose exec -T postgres psql -U promata -d promata < "$SEED_FILE"

# Verificar se o usuário foi criado
echo ""
echo "🔍 Verificando usuários criados..."
docker compose exec -T postgres psql -U promata -d promata -c \
    "SELECT email, name, role, \"isActive\" FROM app.\"User\";"

echo ""
echo "✅ Seed executado com sucesso!"
echo ""
echo "📝 Credenciais de acesso:"
echo "   Email: augusto.alvim@pucrs.br"
echo "   Senha: ProMata2025!"
echo ""
echo "⚠️  IMPORTANTE: Altere a senha no primeiro login!"
