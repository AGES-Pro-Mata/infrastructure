#!/bin/bash

# security-status.sh - Status do sistema de segurança

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔐 Pro-Mata Security System Status"
echo "=================================="
echo ""

# Verificar monitoramento
if pgrep -f "security-monitor.sh" > /dev/null; then
    echo "✅ Monitoramento: ATIVO"
else
    echo "❌ Monitoramento: INATIVO"
fi

# Verificar último scan
if [[ -f "$PROJECT_ROOT/reports/security-scan/latest-scan.txt" ]]; then
    last_scan=$(stat -c %y "$PROJECT_ROOT/reports/security-scan/latest-scan.txt" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
    echo "✅ Último scan: $last_scan"
else
    echo "❌ Nenhum scan encontrado"
fi

# Verificar alertas recentes
alert_count=$(find "$PROJECT_ROOT/monitoring" -name "alert-*.json" 2>/dev/null | wc -l)
echo "🚨 Alertas ativos: $alert_count"

# Verificar configuração
if [[ -f "$PROJECT_ROOT/security/security-config.yml" ]]; then
    echo "✅ Configuração: OK"
else
    echo "❌ Configuração: AUSENTE"
fi

# Verificar dependências essenciais
echo ""
echo "📋 Dependências:"
for cmd in docker curl jq openssl; do
    if command -v "$cmd" &> /dev/null; then
        echo "  ✅ $cmd"
    else
        echo "  ❌ $cmd"
    fi
done

echo ""
echo "📊 Uso de recursos:"
echo "  CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')"
echo "  RAM: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
echo "  Disco: $(df -h / | awk 'NR==2{print $5}')"

echo ""
echo "Para mais detalhes, execute:"
echo "  make security-check ENVIRONMENT=dev"
