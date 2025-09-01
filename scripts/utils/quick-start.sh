#!/bin/bash

# scripts/quick-start.sh
# Script de inicialização rápida do Pro-Mata Security System
# Autor: Sistema de Segurança Pro-Mata
# Versão: 1.0.0

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Variáveis globais
INTERACTIVE=true
ENVIRONMENT="dev"
SETUP_MODE=false

# Função de logging
log() {
    local level="$1"
    local message="$2"
    
    case "$level" in
        "INFO")
            echo -e "${CYAN}ℹ️ ${NC}$message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ ${NC}$message"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️ ${NC}$message"
            ;;
        "ERROR")
            echo -e "${RED}❌ ${NC}$message"
            ;;
        "STEP")
            echo -e "${BLUE}▶️ ${NC}$message"
            ;;
        *)
            echo -e "$message"
            ;;
    esac
}

# Banner do sistema
show_banner() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
██████╗ ██████╗  ██████╗       ███╗   ███╗ █████╗ ████████╗ █████╗ 
██╔══██╗██╔══██╗██╔═══██╗      ████╗ ████║██╔══██╗╚══██╔══╝██╔══██╗
██████╔╝██████╔╝██║   ██║█████╗██╔████╔██║███████║   ██║   ███████║
██╔═══╝ ██╔══██╗██║   ██║╚════╝██║╚██╔╝██║██╔══██║   ██║   ██╔══██║
██║     ██║  ██║╚██████╔╝      ██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║
╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}🔐 Pro-Mata Security System - Quick Start${NC}"
    echo -e "${PURPLE}Sistema Completo de Monitoramento e Segurança${NC}"
    echo ""
}

# Verificar se o sistema já está inicializado
check_initialization() {
    if [[ ! -f "$PROJECT_ROOT/security/security-config.yml" ]]; then
        log "WARN" "Sistema não inicializado. Executando inicialização automática..."
        SETUP_MODE=true
        return 1
    fi
    return 0
}

# Detectar ambiente automaticamente
detect_environment() {
    local detected_env="dev"
    
    # Verificar variáveis de ambiente
    if [[ -n "${ENVIRONMENT:-}" ]]; then
        detected_env="$ENVIRONMENT"
    elif [[ -f "$PROJECT_ROOT/.env.security" ]]; then
        detected_env=$(grep "^ENVIRONMENT=" "$PROJECT_ROOT/.env.security" | cut -d'=' -f2 | tr -d '"' || echo "dev")
    fi
    
    # Verificar hostname/domínio
    local hostname=$(hostname 2>/dev/null || echo "localhost")
    if [[ "$hostname" =~ staging ]]; then
        detected_env="staging"
    elif [[ "$hostname" =~ prod ]]; then
        detected_env="prod"
    fi
    
    ENVIRONMENT="$detected_env"
    log "INFO" "Ambiente detectado: $ENVIRONMENT"
}

# Verificar status do sistema
check_system_status() {
    log "STEP" "Verificando status do sistema..."
    
    local status_ok=true
    local issues=()
    
    # Verificar scripts executáveis
    local scripts=("security-scan.sh" "security-audit.sh" "security-monitor.sh" "rotate-secrets.sh")
    for script in "${scripts[@]}"; do
        if [[ ! -x "$PROJECT_ROOT/scripts/$script" ]]; then
            issues+=("Script não executável: $script")
            status_ok=false
        fi
    done
    
    # Verificar dependências
    local deps=("curl" "jq" "openssl" "docker")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            issues+=("Dependência ausente: $dep")
            status_ok=false
        fi
    done
    
    # Verificar monitoramento ativo
    if pgrep -f "security-monitor.sh" > /dev/null; then
        log "SUCCESS" "Monitoramento: ATIVO"
    else
        log "WARN" "Monitoramento: INATIVO"
    fi
    
    # Verificar último scan
    local latest_scan=$(find "$PROJECT_ROOT/reports/security-scan" -name "*.txt" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
    if [[ -n "$latest_scan" ]]; then
        local scan_age=$((($(date +%s) - $(stat -c %Y "$latest_scan")) / 3600))
        if [[ $scan_age -lt 24 ]]; then
            log "SUCCESS" "Último scan: há ${scan_age}h"
        else
            log "WARN" "Último scan: há ${scan_age}h (>24h)"
        fi
    else
        log "WARN" "Nenhum scan encontrado"
    fi
    
    # Verificar alertas
    local alert_count=$(find "$PROJECT_ROOT/monitoring" -name "alert-*.json" 2>/dev/null | wc -l)
    if [[ $alert_count -eq 0 ]]; then
        log "SUCCESS" "Alertas ativos: 0"
    else
        log "WARN" "Alertas ativos: $alert_count"
    fi
    
    if [[ "$status_ok" == "false" ]]; then
        echo ""
        log "ERROR" "Issues encontrados:"
        for issue in "${issues[@]}"; do
            echo -e "  ${RED}• ${NC}$issue"
        done
        echo ""
    fi
    
    return $status_ok
}

# Menu principal interativo
show_main_menu() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}            MENU PRINCIPAL              ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}🔍 VERIFICAÇÕES E SCANS:${NC}"
    echo "  1) 🔍 Executar scan de segurança completo"
    echo "  2) 📋 Executar auditoria de conformidade"
    echo "  3) 🧪 Executar testes do sistema"
    echo "  4) 📊 Verificar status geral"
    echo ""
    echo -e "${CYAN}🔧 MONITORAMENTO:${NC}"
    echo "  5) 👁️  Iniciar monitoramento em tempo real"
    echo "  6) ⏹️  Parar monitoramento"
    echo "  7) 🚨 Verificar alertas recentes"
    echo ""
    echo -e "${CYAN}🔄 OPERAÇÕES:${NC}"
    echo "  8) 🔑 Rotacionar secrets"
    echo "  9) 💾 Criar backup completo"
    echo " 10) 🔄 Restaurar do backup"
    echo ""
    echo -e "${CYAN}📊 VISUALIZAÇÃO:${NC}"
    echo " 11) 📈 Abrir dashboard de segurança"
    echo " 12) 📄 Gerar relatório de segurança"
    echo " 13) 📝 Ver logs recentes"
    echo ""
    echo -e "${CYAN}⚙️ CONFIGURAÇÃO:${NC}"
    echo " 14) ⚙️  Configurar sistema"
    echo " 15) 🧹 Limpeza e manutenção"
    echo " 16) ❓ Ajuda e documentação"
    echo ""
    echo -e "${CYAN}0) 🚪 Sair${NC}"
    echo ""
}

# Executar scan de segurança
run_security_scan() {
    log "STEP" "Iniciando scan de segurança completo..."
    
    echo ""
    echo "Tipos de scan disponíveis:"
    echo "1) Completo (recomendado)"
    echo "2) Containers apenas"  
    echo "3) Dependências apenas"
    echo "4) Rede apenas"
    echo ""
    
    read -p "Escolha o tipo de scan [1]: " scan_choice
    scan_choice=${scan_choice:-1}
    
    local scan_type="all"
    case "$scan_choice" in
        1) scan_type="all" ;;
        2) scan_type="containers" ;;
        3) scan_type="dependencies" ;;
        4) scan_type="network" ;;
        *) scan_type="all" ;;
    esac
    
    echo ""
    log "INFO" "Executando scan tipo: $scan_type"
    
    if "$PROJECT_ROOT/scripts/security-scan.sh" --environment "$ENVIRONMENT" --type "$scan_type" --verbose; then
        log "SUCCESS" "Scan concluído com sucesso!"
        
        # Mostrar resumo
        local latest_report=$(find "$PROJECT_ROOT/reports/security-scan" -name "*.txt" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
        if [[ -n "$latest_report" ]]; then
            echo ""
            log "INFO" "Resumo do scan:"
            if grep -q "CRÍTICAS:" "$latest_report"; then
                local critical=$(grep "CRÍTICAS:" "$latest_report" | awk '{print $2}' || echo "0")
                local high=$(grep "ALTAS:" "$latest_report" | awk '{print $2}' || echo "0")
                echo -e "  ${RED}• Críticas: $critical${NC}"
                echo -e "  ${YELLOW}• Altas: $high${NC}"
            fi
        fi
    else
        log "ERROR" "Scan falhou. Verifique os logs para detalhes."
    fi
    
    pause_for_user
}

# Executar auditoria
run_security_audit() {
    log "STEP" "Executando auditoria de segurança..."
    
    if "$PROJECT_ROOT/scripts/security/security-audit.sh" --compliance-check --environment "$ENVIRONMENT" --verbose; then
        log "SUCCESS" "Auditoria concluída!"
    else
        log "ERROR" "Auditoria falhou. Verifique os logs."
    fi
    
    pause_for_user
}

# Executar testes
run_tests() {
    log "STEP" "Executando testes do sistema..."
    
    echo ""
    echo "Tipos de teste:"
    echo "1) Rápidos (unit + integration)"
    echo "2) Completos (todos os testes)"
    echo ""
    
    read -p "Escolha [1]: " test_choice
    test_choice=${test_choice:-1}
    
    local test_args=""
    if [[ "$test_choice" == "1" ]]; then
        test_args="--quick"
    fi
    
    if "$PROJECT_ROOT/scripts/test-security.sh" --environment "$ENVIRONMENT" $test_args; then
        log "SUCCESS" "Testes concluídos!"
    else
        log "ERROR" "Alguns testes falharam."
    fi
    
    pause_for_user
}

# Iniciar monitoramento
start_monitoring() {
    if pgrep -f "security-monitor.sh" > /dev/null; then
        log "WARN" "Monitoramento já está ativo"
        return
    fi
    
    log "STEP" "Iniciando monitoramento em tempo real..."
    
    echo ""
    echo "Opções de monitoramento:"
    echo "1) Contínuo (até ser parado manualmente)"
    echo "2) Por tempo limitado"
    echo ""
    
    read -p "Escolha [1]: " monitor_choice
    monitor_choice=${monitor_choice:-1}
    
    local duration_arg=""
    if [[ "$monitor_choice" == "2" ]]; then
        read -p "Duração (ex: 1h, 30m): " duration
        if [[ -n "$duration" ]]; then
            duration_arg="--duration $duration"
        fi
    fi
    
    # Iniciar em background
    nohup "$PROJECT_ROOT/scripts/security-monitor.sh" --environment "$ENVIRONMENT" $duration_arg > /dev/null 2>&1 &
    
    sleep 2
    
    if pgrep -f "security-monitor.sh" > /dev/null; then
        log "SUCCESS" "Monitoramento iniciado!"
        log "INFO" "Use a opção 6 para parar o monitoramento"
    else
        log "ERROR" "Falha ao iniciar monitoramento"
    fi
    
    pause_for_user
}

# Parar monitoramento
stop_monitoring() {
    if ! pgrep -f "security-monitor.sh" > /dev/null; then
        log "WARN" "Monitoramento não está ativo"
        return
    fi
    
    log "STEP" "Parando monitoramento..."
    
    pkill -f "security-monitor.sh" 2>/dev/null || true
    
    sleep 2
    
    if ! pgrep -f "security-monitor.sh" > /dev/null; then
        log "SUCCESS" "Monitoramento parado!"
    else
        log "ERROR" "Falha ao parar monitoramento"
    fi
    
    pause_for_user
}

# Verificar alertas
check_alerts() {
    log "STEP" "Verificando alertas recentes..."
    
    "$PROJECT_ROOT/scripts/security-monitor.sh" --check-alerts --environment "$ENVIRONMENT"
    
    pause_for_user
}

# Rotacionar secrets
rotate_secrets() {
    log "STEP" "Rotação de secrets..."
    
    echo ""
    log "WARN" "Esta operação irá rotacionar credenciais sensíveis!"
    echo ""
    echo "Tipos de rotação:"
    echo "1) Apenas banco de dados"
    echo "2) Apenas chaves de API"  
    echo "3) Todos os secrets (ATENÇÃO: pode afetar serviços)"
    echo ""
    
    read -p "Escolha [1]: " rotation_choice
    rotation_choice=${rotation_choice:-1}
    
    local rotation_type="rotate-db"
    case "$rotation_choice" in
        1) rotation_type="rotate-db" ;;
        2) rotation_type="rotate-api" ;;
        3) rotation_type="rotate-all" ;;
    esac
    
    echo ""
    read -p "Confirmar rotação? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "INFO" "Rotação cancelada"
        return
    fi
    
    if "$PROJECT_ROOT/scripts/rotate-secrets.sh" --environment "$ENVIRONMENT" "$rotation_type"; then
        log "SUCCESS" "Rotação concluída!"
    else
        log "ERROR" "Falha na rotação"
    fi
    
    pause_for_user
}

# Criar backup
create_backup() {
    log "STEP" "Criando backup completo..."
    
    if "$PROJECT_ROOT/scripts/backup-recovery.sh" backup --environment "$ENVIRONMENT"; then
        log "SUCCESS" "Backup criado!"
        
        # Mostrar localização
        local latest_backup=$(find "$PROJECT_ROOT/backups" -name "backup-*.tar.gz*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
        if [[ -n "$latest_backup" ]]; then
            log "INFO" "Backup salvo: $(basename "$latest_backup")"
        fi
    else
        log "ERROR" "Falha ao criar backup"
    fi
    
    pause_for_user
}

# Restaurar backup
restore_backup() {
    log "STEP" "Restaurar do backup..."
    
    # Listar backups disponíveis
    echo ""
    log "INFO" "Backups disponíveis:"
    "$PROJECT_ROOT/scripts/backup-recovery.sh" list
    
    echo ""
    read -p "Nome do arquivo de backup: " backup_file
    
    if [[ -n "$backup_file" ]]; then
        echo ""
        log "WARN" "Esta operação irá sobrescrever configurações atuais!"
        read -p "Confirmar restore? [y/N]: " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if "$PROJECT_ROOT/scripts/backup-recovery.sh" restore --file "$backup_file"; then
                log "SUCCESS" "Restore concluído!"
                log "INFO" "Reinicie os serviços para aplicar as mudanças"
            else
                log "ERROR" "Falha no restore"
            fi
        else
            log "INFO" "Restore cancelado"
        fi
    fi
    
    pause_for_user
}

# Abrir dashboard
open_dashboard() {
    log "STEP" "Abrindo dashboard de segurança..."
    
    if "$PROJECT_ROOT/scripts/security-dashboard.sh" --environment "$ENVIRONMENT" --open; then
        log "SUCCESS" "Dashboard aberto!"
        log "INFO" "Se não abriu automaticamente, acesse: dashboard.html"
    else
        log "ERROR" "Falha ao gerar dashboard"
    fi
    
    pause_for_user
}

# Gerar relatório
generate_report() {
    log "STEP" "Gerando relatório de segurança..."
    
    echo ""
    echo "Formatos disponíveis:"
    echo "1) HTML (recomendado)"
    echo "2) PDF"
    echo "3) JSON"
    echo ""
    
    read -p "Escolha [1]: " format_choice
    format_choice=${format_choice:-1}
    
    local format="html"
    case "$format_choice" in
        1) format="html" ;;
        2) format="pdf" ;;
        3) format="json" ;;
    esac
    
    if "$PROJECT_ROOT/scripts/security-audit.sh" --generate-report --format "$format" --environment "$ENVIRONMENT"; then
        log "SUCCESS" "Relatório gerado!"
        
        local latest_report=$(find "$PROJECT_ROOT/reports" -name "*.$format" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
        if [[ -n "$latest_report" ]]; then
            log "INFO" "Relatório: $latest_report"
            
            if [[ "$format" == "html" ]] && command -v xdg-open &> /dev/null; then
                read -p "Abrir relatório no navegador? [y/N]: " open_report
                if [[ "$open_report" =~ ^[Yy]$ ]]; then
                    xdg-open "$latest_report" &>/dev/null &
                fi
            fi
        fi
    else
        log "ERROR" "Falha ao gerar relatório"
    fi
    
    pause_for_user
}

# Ver logs
view_logs() {
    log "STEP" "Visualizando logs recentes..."
    
    echo ""
    echo "Tipos de log:"
    echo "1) Monitoramento"
    echo "2) Scans"
    echo "3) Auditoria"
    echo "4) Rotação de secrets"
    echo "5) Todos"
    echo ""
    
    read -p "Escolha [1]: " log_choice
    log_choice=${log_choice:-1}
    
    local log_pattern=""
    case "$log_choice" in
        1) log_pattern="security-monitor-*.log" ;;
        2) log_pattern="security-scan-*.log" ;;
        3) log_pattern="security-audit-*.log" ;;
        4) log_pattern="rotate-secrets-*.log" ;;
        5) log_pattern="*.log" ;;
    esac
    
    local latest_log=$(find "$PROJECT_ROOT/logs" -name "$log_pattern" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
    
    if [[ -n "$latest_log" ]]; then
        echo ""
        log "INFO" "Mostrando: $(basename "$latest_log")"
        echo -e "${BLUE}═══════════════════════════════════════${NC}"
        tail -50 "$latest_log" | while IFS= read -r line; do
            # Colorir linhas baseado no conteúdo
            if [[ "$line" =~ ERROR ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ "$line" =~ WARN ]]; then
                echo -e "${YELLOW}$line${NC}"
            elif [[ "$line" =~ SUCCESS ]]; then
                echo -e "${GREEN}$line${NC}"
            else
                echo "$line"
            fi
        done
        echo -e "${BLUE}═══════════════════════════════════════${NC}"
    else
        log "WARN" "Nenhum log encontrado para o padrão: $log_pattern"
    fi
    
    pause_for_user
}

# Configurar sistema
configure_system() {
    log "STEP" "Configuração do sistema..."
    
    echo ""
    echo "Opções de configuração:"
    echo "1) Reconfigurar ambiente completo"
    echo "2) Editar arquivo de configuração"
    echo "3) Configurar notificações"
    echo "4) Configurar credenciais cloud"
    echo ""
    
    read -p "Escolha [1]: " config_choice
    config_choice=${config_choice:-1}
    
    case "$config_choice" in
        1)
            log "INFO" "Reconfigurando sistema..."
            "$PROJECT_ROOT/scripts/init-security.sh" --environment "$ENVIRONMENT" --force
            ;;
        2)
            local config_file="$PROJECT_ROOT/.env.security"
            if [[ -f "$config_file" ]]; then
                log "INFO" "Abrindo editor para: $config_file"
                "${EDITOR:-nano}" "$config_file"
            else
                log "ERROR" "Arquivo de configuração não encontrado"
            fi
            ;;
        3)
            configure_notifications
            ;;
        4)
            configure_cloud_credentials
            ;;
    esac
    
    pause_for_user
}

# Configurar notificações
configure_notifications() {
    log "INFO" "Configurando notificações..."
    
    local env_file="$PROJECT_ROOT/.env.security"
    
    echo ""
    read -p "Discord Webhook URL: " discord_webhook
    read -p "Slack Webhook URL: " slack_webhook
    read -p "Email SMTP Host: " smtp_host
    read -p "Email From: " email_from
    read -p "Email To: " email_to
    
    # Atualizar arquivo de configuração
    if [[ -f "$env_file" ]]; then
        # Fazer backup
        cp "$env_file" "$env_file.backup"
        
        # Atualizar valores
        sed -i "s|DISCORD_WEBHOOK_URL=.*|DISCORD_WEBHOOK_URL=\"$discord_webhook\"|" "$env_file"
        sed -i "s|SLACK_WEBHOOK_URL=.*|SLACK_WEBHOOK_URL=\"$slack_webhook\"|" "$env_file"
        sed -i "s|EMAIL_SMTP_HOST=.*|EMAIL_SMTP_HOST=\"$smtp_host\"|" "$env_file"
        sed -i "s|EMAIL_FROM=.*|EMAIL_FROM=\"$email_from\"|" "$env_file"
        sed -i "s|EMAIL_TO=.*|EMAIL_TO=\"$email_to\"|" "$env_file"
        
        log "SUCCESS" "Notificações configuradas!"
    else
        log "ERROR" "Arquivo de configuração não encontrado"
    fi
}

# Configurar credenciais cloud
configure_cloud_credentials() {
    log "INFO" "Configurando credenciais cloud..."
    
    echo ""
    echo "Selecione o provedor cloud:"
    echo "1) Azure (para staging)"
    echo "2) AWS (para produção)"
    echo ""
    
    read -p "Escolha: " cloud_choice
    
    case "$cloud_choice" in
        1)
            echo ""
            log "INFO" "Configurando Azure..."
            echo "Execute: az login"
            echo "Depois configure as variáveis no .env.security:"
            echo "  AZURE_SUBSCRIPTION_ID"
            echo "  AZURE_TENANT_ID" 
            echo "  AZURE_CLIENT_ID"
            echo "  AZURE_CLIENT_SECRET"
            ;;
        2)
            echo ""
            log "INFO" "Configurando AWS..."
            echo "Execute: aws configure"
            echo "Depois configure as variáveis no .env.security:"
            echo "  AWS_ACCESS_KEY_ID"
            echo "  AWS_SECRET_ACCESS_KEY"
            echo "  AWS_REGION"
            ;;
    esac
}

# Limpeza e manutenção
cleanup_maintenance() {
    log "STEP" "Executando limpeza e manutenção..."
    
    echo ""
    echo "Opções de limpeza:"
    echo "1) Logs antigos (>30 dias)"
    echo "2) Backups antigos (>30 dias)"  
    echo "3) Relatórios antigos (>90 dias)"
    echo "4) Limpeza completa"
    echo ""
    
    read -p "Escolha [4]: " cleanup_choice
    cleanup_choice=${cleanup_choice:-4}
    
    case "$cleanup_choice" in
        1)
            find "$PROJECT_ROOT/logs" -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
            log "SUCCESS" "Logs antigos removidos"
            ;;
        2)
            "$PROJECT_ROOT/scripts/backup-recovery.sh" cleanup --retention 30
            ;;
        3)
            find "$PROJECT_ROOT/reports" -name "*.html" -o -name "*.pdf" -type f -mtime +90 -delete 2>/dev/null || true
            log "SUCCESS" "Relatórios antigos removidos"
            ;;
        4)
            find "$PROJECT_ROOT/logs" -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
            "$PROJECT_ROOT/scripts/backup-recovery.sh" cleanup --retention 30 2>/dev/null || true
            find "$PROJECT_ROOT/reports" -name "*.html" -o -name "*.pdf" -type f -mtime +90 -delete 2>/dev/null || true
            find /tmp -name "*pro-mata*" -type f -mtime +1 -delete 2>/dev/null || true
            log "SUCCESS" "Limpeza completa executada"
            ;;
    esac
    
    pause_for_user
}

# Mostrar ajuda
show_help() {
    log "STEP" "Ajuda e documentação..."
    
    echo ""
    echo -e "${CYAN}📚 DOCUMENTAÇÃO DISPONÍVEL:${NC}"
    echo ""
    echo "• README.md - Guia principal do projeto"
    echo "• docs/security-migration-guide.md - Guia de migração"
    echo "• security/security-config.yml - Configurações principais"
    echo ""
    echo -e "${CYAN}🔧 COMANDOS MAKEFILE:${NC}"
    echo ""
    echo "• make security-init     - Inicializar sistema"
    echo "• make security-check    - Verificação geral" 
    echo "• make security-scan     - Scan de vulnerabilidades"
    echo "• make security-audit    - Auditoria de conformidade"
    echo "• make security-monitor  - Monitoramento em tempo real"
    echo "• make security-rotate   - Rotação de secrets"
    echo "• make security-backup   - Backup completo"
    echo ""
    echo -e "${CYAN}🆘 SUPORTE:${NC}"
    echo ""
    echo "• Discord: Canal #infra-pro-mata"
    echo "• GitHub Issues: https://github.com/AGES-Pro-Mata/infra/issues"
    echo ""
    echo -e "${CYAN}🚨 COMANDOS DE EMERGÊNCIA:${NC}"
    echo ""
    echo "• make security-emergency-rotate  - Rotação de emergência"
    echo "• make security-emergency-lockdown - Lockdown do sistema"
    echo ""
    
    pause_for_user
}

# Pausa para o usuário ler
pause_for_user() {
    echo ""
    read -p "Pressione Enter para continuar..."
}

# Executar setup se necessário
run_setup() {
    log "STEP" "Inicializando sistema de segurança..."
    
    if "$PROJECT_ROOT/scripts/init-security.sh" --environment "$ENVIRONMENT" --skip-deps; then
        log "SUCCESS" "Sistema inicializado com sucesso!"
    else
        log "ERROR" "Falha na inicialização"
        exit 1
    fi
}

# Loop principal
main_loop() {
    while true; do
        show_banner
        
        # Mostrar status
        echo -e "${PURPLE}Ambiente atual: $ENVIRONMENT${NC}"
        
        # Verificar status rapidamente
        if check_system_status; then
            echo -e "${GREEN}Status: Sistema OK${NC}"
        else
            echo -e "${YELLOW}Status: Issues encontrados${NC}"
        fi
        
        show_main_menu
        
        read -p "Escolha uma opção: " choice
        
        case "$choice" in
            1) run_security_scan ;;
            2) run_security_audit ;;
            3) run_tests ;;
            4) check_system_status; pause_for_user ;;
            5) start_monitoring ;;
            6) stop_monitoring ;;
            7) check_alerts ;;
            8) rotate_secrets ;;
            9) create_backup ;;
            10) restore_backup ;;
            11) open_dashboard ;;
            12) generate_report ;;
            13) view_logs ;;
            14) configure_system ;;
            15) cleanup_maintenance ;;
            16) show_help ;;
            0) 
                log "INFO" "Finalizando Pro-Mata Security System..."
                echo -e "${CYAN}Obrigado por usar o Pro-Mata Security! 🔐${NC}"
                exit 0
                ;;
            *)
                log "ERROR" "Opção inválida: $choice"
                sleep 2
                ;;
        esac
    done
}

# Parse de argumentos
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment|-e)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --non-interactive)
                INTERACTIVE=false
                shift
                ;;
            --setup)
                SETUP_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Argumento desconhecido: $1"
                exit 1
                ;;
        esac
    done
}

# Função principal
main() {
    parse_arguments "$@"
    
    if [[ "$INTERACTIVE" == "false" ]]; then
        # Modo não interativo - apenas verificar status
        detect_environment
        if check_initialization || [[ "$SETUP_MODE" == "true" ]]; then
            check_system_status
        else
            run_setup
        fi
        return
    fi
    
    # Modo interativo
    detect_environment
    
    if ! check_initialization || [[ "$SETUP_MODE" == "true" ]]; then
        show_banner
        run_setup
        echo ""
        read -p "Pressione Enter para continuar para o menu principal..."
    fi
    
    main_loop
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi