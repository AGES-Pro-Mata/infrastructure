#!/bin/bash

# quick-start.sh - Inicialização rápida do sistema de segurança Pro-Mata

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"  # Go up two levels: scripts/utils -> scripts -> root

echo "🚀 Pro-Mata Security - Quick Start"
echo "=================================="
echo ""

# Verificar se já está inicializado
if [[ ! -f "$PROJECT_ROOT/security/security-config.yml" ]]; then
    echo "❌ Sistema não inicializado. Execute primeiro:"
    echo "   make security-init"
    exit 1
fi

echo "✅ Sistema inicializado"

# Menu de opções
echo ""
echo "Selecione uma opção:"
echo "1) Iniciar monitoramento"
echo "2) Executar scan de segurança"
echo "3) Verificar status"
echo "4) Abrir dashboard"
echo "5) Executar auditoria"
echo "0) Sair"
echo ""

read -p "Opção: " option

case "$option" in
    1)
        echo "🔍 Iniciando monitoramento..."
        "$SCRIPT_DIR/security-monitor.sh" --environment dev &
        echo "Monitor iniciado em background"
        ;;
    2)
        echo "🔍 Executando scan..."
        "$SCRIPT_DIR/security-scan.sh" --environment dev
        ;;
    3)
        echo "📊 Verificando status..."
        make security-status
        ;;
    4)
        echo "📈 Abrindo dashboard..."
        if command -v xdg-open &> /dev/null; then
            xdg-open "file://$PROJECT_ROOT/dashboard.html"
        else
            echo "Abra manualmente: $PROJECT_ROOT/dashboard.html"
        fi
        ;;
    5)
        echo "🔍 Executando auditoria..."
        "$PROJECT_ROOT/scripts/security/security-audit.sh" --compliance-check --environment dev
        ;;
    0)
        echo "👋 Até logo!"
        ;;
    *)
        echo "❌ Opção inválida"
        ;;
esac
