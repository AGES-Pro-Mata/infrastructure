#!/bin/bash

# security-cleanup.sh - Limpeza do sistema de segurança

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🧹 Pro-Mata Security Cleanup"
echo "============================="
echo ""

# Limpeza de logs antigos
echo "🗑️ Limpando logs antigos (>30 dias)..."
find "$PROJECT_ROOT/logs" -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
cleaned_logs=$(find "$PROJECT_ROOT/logs" -name "*.log" -type f -mtime +30 2>/dev/null | wc -l)
echo "   Logs removidos: $cleaned_logs"

# Limpeza de relatórios antigos
echo "🗑️ Limpando relatórios antigos (>90 dias)..."
find "$PROJECT_ROOT/reports" -name "*.txt" -type f -mtime +90 -delete 2>/dev/null || true
find "$PROJECT_ROOT/reports" -name "*.html" -type f -mtime +90 -delete 2>/dev/null || true
cleaned_reports=$(find "$PROJECT_ROOT/reports" -name "*.txt" -o -name "*.html" -type f -mtime +90 2>/dev/null | wc -l)
echo "   Relatórios removidos: $cleaned_reports"

# Limpeza de alertas antigos
echo "🗑️ Limpando alertas antigos (>7 dias)..."
find "$PROJECT_ROOT/monitoring" -name "alert-*.json" -type f -mtime +7 -delete 2>/dev/null || true
cleaned_alerts=$(find "$PROJECT_ROOT/monitoring" -name "alert-*.json" -type f -mtime +7 2>/dev/null | wc -l)
echo "   Alertas removidos: $cleaned_alerts"

# Limpeza de arquivos temporários
echo "🗑️ Limpando arquivos temporários..."
find "$PROJECT_ROOT/tmp" -type f -mtime +1 -delete 2>/dev/null || true
rm -rf /tmp/pro-mata-* 2>/dev/null || true
echo "   Arquivos temporários limpos"

# Limpeza de backups antigos (manter apenas os 10 mais recentes)
echo "🗑️ Organizando backups..."
if [[ -d "$PROJECT_ROOT/backups/secrets" ]]; then
    ls -t "$PROJECT_ROOT/backups/secrets"/*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
fi

echo ""
echo "✅ Limpeza concluída!"
echo ""
echo "📊 Status atual:"
echo "   Logs: $(find "$PROJECT_ROOT/logs" -name "*.log" -type f | wc -l) arquivos"
echo "   Relatórios: $(find "$PROJECT_ROOT/reports" -name "*.txt" -o -name "*.html" -type f | wc -l) arquivos"
echo "   Alertas: $(find "$PROJECT_ROOT/monitoring" -name "alert-*.json" -type f | wc -l) ativos"
echo "   Backups: $(find "$PROJECT_ROOT/backups" -name "*.tar.gz" -type f 2>/dev/null | wc -l) arquivos"
