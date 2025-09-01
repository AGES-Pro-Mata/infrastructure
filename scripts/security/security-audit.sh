#!/bin/bash

# scripts/security-audit.sh
# Script de auditoria de segurança completa para Pro-Mata
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
LOG_DIR="$PROJECT_ROOT/logs"
REPORTS_DIR="$PROJECT_ROOT/reports/security"
TEMP_DIR="/tmp/pro-mata-audit-$$"

# Variáveis globais
VERBOSE=false
ENVIRONMENT=""
OUTPUT_FORMAT="text"
FULL_AUDIT=false
SAVE_REPORT=true
AUDIT_TYPE=""

# Logging
setup_logging() {
    mkdir -p "$LOG_DIR" "$REPORTS_DIR"
    LOG_FILE="$LOG_DIR/security-audit-$(date +%Y%m%d-%H%M%S).log"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
}

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${CYAN}[$timestamp]${NC} ${GREEN}INFO${NC}: $message"
            ;;
        "WARN")
            echo -e "${CYAN}[$timestamp]${NC} ${YELLOW}WARN${NC}: $message"
            ;;
        "ERROR")
            echo -e "${CYAN}[$timestamp]${NC} ${RED}ERROR${NC}: $message"
            ;;
        "SUCCESS")
            echo -e "${CYAN}[$timestamp]${NC} ${GREEN}SUCCESS${NC}: $message"
            ;;
        "FINDING")
            echo -e "${CYAN}[$timestamp]${NC} ${PURPLE}FINDING${NC}: $message"
            ;;
        *)
            echo -e "${CYAN}[$timestamp]${NC} $message"
            ;;
    esac
}

# Função de ajuda
show_help() {
    cat << EOF
${BLUE}Pro-Mata Security Audit System${NC}

Sistema completo de auditoria de segurança para infraestrutura Pro-Mata

${YELLOW}Uso:${NC} $0 [OPÇÕES] [COMANDO]

${YELLOW}COMANDOS:${NC}
  --full-audit              Auditoria completa de segurança
  --audit-access           Auditoria de logs de acesso
  --audit-changes          Auditoria de mudanças de configuração
  --audit-compliance       Auditoria de conformidade
  --generate-report        Gerar relatório de auditoria
  --compliance-check       Verificação rápida de conformidade

${YELLOW}OPÇÕES:${NC}
  -e, --environment ENV    Ambiente (dev|staging|prod)
  -v, --verbose           Output detalhado
  -f, --format FORMAT     Formato do relatório (text|json|html|pdf)
  -o, --output FILE       Arquivo de saída para relatório
  --no-save              Não salvar relatório em arquivo
  -h, --help             Mostrar esta ajuda

${YELLOW}EXEMPLOS:${NC}
  $0 --full-audit -e prod -f html
  $0 --audit-access -e staging -v
  $0 --compliance-check -e dev
  $0 --generate-report -f pdf -o security-report.pdf

${YELLOW}TIPOS DE AUDITORIA:${NC}
  - Acesso: Logs de autenticação e autorização
  - Mudanças: Alterações em configurações e código
  - Conformidade: Aderência a políticas de segurança
  - Vulnerabilidades: Scan de security issues
  - Performance: Análise de performance de segurança

EOF
}

# Inicializar ambiente temporário
setup_temp_env() {
    mkdir -p "$TEMP_DIR"
    trap cleanup_temp_env EXIT
}

cleanup_temp_env() {
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

# Estrutura para armazenar findings
declare -A AUDIT_FINDINGS
declare -A AUDIT_STATS

# Inicializar estatísticas
init_audit_stats() {
    AUDIT_STATS[CRITICAL]=0
    AUDIT_STATS[HIGH]=0
    AUDIT_STATS[MEDIUM]=0
    AUDIT_STATS[LOW]=0
    AUDIT_STATS[INFO]=0
    AUDIT_STATS[TOTAL]=0
}

# Adicionar finding
add_finding() {
    local severity="$1"
    local category="$2"
    local title="$3"
    local description="$4"
    local recommendation="$5"
    
    local finding_id="FINDING_$(date +%s)_$$_${AUDIT_STATS[TOTAL]}"
    
    AUDIT_FINDINGS["$finding_id"]=$(cat << EOF
{
  "id": "$finding_id",
  "severity": "$severity",
  "category": "$category", 
  "title": "$title",
  "description": "$description",
  "recommendation": "$recommendation",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "environment": "$ENVIRONMENT"
}
EOF
    )
    
    ((AUDIT_STATS[$severity]++))
    ((AUDIT_STATS[TOTAL]++))
    
    log "FINDING" "[$severity] $title"
    if [[ "$VERBOSE" == "true" ]]; then
        log "INFO" "  Description: $description"
        log "INFO" "  Recommendation: $recommendation"
    fi
}

# Auditoria de acesso
audit_access_logs() {
    log "INFO" "Iniciando auditoria de logs de acesso..."
    
    local access_log_paths
    case "$ENVIRONMENT" in
        "dev")
            access_log_paths="/var/log/nginx/access.log /var/log/auth.log"
            ;;
        "staging"|"prod")
            # Paths específicos para cada ambiente
            access_log_paths="/var/log/nginx/access.log /var/log/auth.log /var/log/audit/audit.log"
            ;;
        *)
            access_log_paths="/var/log/nginx/access.log"
            ;;
    esac
    
    # Análise de tentativas de login suspeitas
    log "INFO" "Analisando tentativas de login suspeitas..."
    
    local suspicious_ips=$(grep -h "Failed password" /var/log/auth.log 2>/dev/null | \
        awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | \
        awk '$1 > 10 {print $2}' | head -10 || echo "")
    
    if [[ -n "$suspicious_ips" ]]; then
        while IFS= read -r ip; do
            local attempts=$(grep -c "Failed password.*$ip" /var/log/auth.log 2>/dev/null || echo "0")
            if [[ $attempts -gt 10 ]]; then
                add_finding "HIGH" "ACCESS_CONTROL" \
                    "Múltiplas tentativas de login falharam do IP $ip" \
                    "Foram detectadas $attempts tentativas de login falharam do IP $ip nas últimas 24h" \
                    "Investigar o IP $ip e considerar bloqueio se for malicioso"
            fi
        done <<< "$suspicious_ips"
    fi
    
    # Análise de acessos fora do horário comercial
    log "INFO" "Verificando acessos fora do horário comercial..."
    
    local after_hours=$(grep -h "$(date +%b)" /var/log/auth.log 2>/dev/null | \
        awk '$3 < "08:00:00" || $3 > "18:00:00" {print}' | wc -l || echo "0")
    
    if [[ $after_hours -gt 50 ]]; then
        add_finding "MEDIUM" "ACCESS_CONTROL" \
            "Alto número de acessos fora do horário comercial" \
            "Foram detectados $after_hours acessos fora do horário comercial (08h-18h)" \
            "Revisar política de acesso e implementar alertas para acessos noturnos"
    fi
    
    # Análise de privilégios elevados
    log "INFO" "Analisando uso de privilégios elevados..."
    
    local sudo_usage=$(grep -c "sudo:" /var/log/auth.log 2>/dev/null || echo "0")
    local unusual_sudo=$(grep "sudo:" /var/log/auth.log 2>/dev/null | \
        grep -v -E "(systemctl|docker|make)" | wc -l || echo "0")
    
    if [[ $unusual_sudo -gt 20 ]]; then
        add_finding "MEDIUM" "PRIVILEGE_ESCALATION" \
            "Uso incomum de privilégios sudo detectado" \
            "Foram identificados $unusual_sudo comandos sudo incomuns de um total de $sudo_usage" \
            "Revisar logs de sudo e implementar auditoria mais granular de comandos privilegiados"
    fi
    
    log "SUCCESS" "Auditoria de logs de acesso concluída"
}

# Auditoria de mudanças de configuração
audit_configuration_changes() {
    log "INFO" "Iniciando auditoria de mudanças de configuração..."
    
    # Verificar mudanças em arquivos críticos
    local critical_files=(
        "/etc/nginx/nginx.conf"
        "/etc/ssh/sshd_config" 
        "/etc/ssl/certs/"
        "$PROJECT_ROOT/terraform/"
        "$PROJECT_ROOT/ansible/"
        "$PROJECT_ROOT/.env*"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ -e "$file" ]]; then
            log "INFO" "Verificando mudanças em: $file"
            
            # Verificar se há mudanças recentes (últimas 24h)
            local recent_changes=$(find "$file" -type f -mtime -1 2>/dev/null | wc -l || echo "0")
            
            if [[ $recent_changes -gt 0 ]]; then
                add_finding "MEDIUM" "CONFIGURATION_CHANGE" \
                    "Mudanças recentes detectadas em arquivo crítico" \
                    "Arquivo $file foi modificado nas últimas 24 horas" \
                    "Revisar as mudanças e garantir que foram autorizadas e documentadas"
            fi
            
            # Verificar permissões
            local perms=$(stat -c "%a" "$file" 2>/dev/null || echo "000")
            case "$file" in
                *".env"*)
                    if [[ "$perms" != "600" ]] && [[ "$perms" != "400" ]]; then
                        add_finding "HIGH" "FILE_PERMISSIONS" \
                            "Permissões inadequadas em arquivo de configuração sensível" \
                            "Arquivo $file possui permissões $perms (deveria ser 600 ou 400)" \
                            "Executar: chmod 600 $file"
                    fi
                    ;;
                *"ssh"*)
                    if [[ "$perms" != "644" ]] && [[ "$perms" != "600" ]]; then
                        add_finding "HIGH" "FILE_PERMISSIONS" \
                            "Permissões inadequadas em configuração SSH" \
                            "Arquivo $file possui permissões $perms (deveria ser 644 ou 600)" \
                            "Executar: chmod 644 $file (ou 600 se contém chaves privadas)"
                    fi
                    ;;
            esac
        fi
    done
    
    # Auditoria de mudanças no Git
    if [[ -d "$PROJECT_ROOT/.git" ]]; then
        log "INFO" "Analisando mudanças no controle de versão..."
        
        local recent_commits=$(cd "$PROJECT_ROOT" && git log --since="24 hours ago" --oneline | wc -l || echo "0")
        local security_commits=$(cd "$PROJECT_ROOT" && git log --since="7 days ago" --grep="security\|fix\|vulnerability" --oneline | wc -l || echo "0")
        
        if [[ $recent_commits -gt 10 ]]; then
            add_finding "INFO" "VERSION_CONTROL" \
                "Alto número de commits recentes" \
                "Foram identificados $recent_commits commits nas últimas 24 horas" \
                "Verificar se todas as mudanças foram revisadas adequadamente"
        fi
        
        if [[ $security_commits -gt 0 ]]; then
            add_finding "INFO" "SECURITY_FIXES" \
                "Commits relacionados à segurança detectados" \
                "Foram identificados $security_commits commits relacionados à segurança na última semana" \
                "Garantir que todos os patches de segurança foram testados e aplicados em produção"
        fi
    fi
    
    log "SUCCESS" "Auditoria de mudanças de configuração concluída"
}

# Auditoria de conformidade
audit_compliance() {
    log "INFO" "Iniciando auditoria de conformidade..."
    
    # Verificar política de senhas
    log "INFO" "Verificando política de senhas..."
    
    if [[ -f "/etc/pam.d/common-password" ]]; then
        local password_policy=$(grep -E "(minlen|retry|difok)" /etc/pam.d/common-password || echo "")
        if [[ -z "$password_policy" ]]; then
            add_finding "MEDIUM" "COMPLIANCE" \
                "Política de senhas não configurada adequadamente" \
                "Não foi encontrada configuração de política de senhas em /etc/pam.d/common-password" \
                "Implementar política de senhas robusta com requisitos de complexidade"
        fi
    fi
    
    # Verificar configurações de SSL/TLS
    log "INFO" "Verificando configurações SSL/TLS..."
    
    local ssl_protocols
    case "$ENVIRONMENT" in
        "prod")
            # Configurações mais rigorosas para produção
            ssl_protocols="TLSv1.2 TLSv1.3"
            ;;
        *)
            ssl_protocols="TLSv1.2 TLSv1.3"
            ;;
    esac
    
    if [[ -f "/etc/nginx/nginx.conf" ]]; then
        local weak_ssl=$(grep -E "SSLv|TLSv1\.0|TLSv1\.1" /etc/nginx/nginx.conf || echo "")
        if [[ -n "$weak_ssl" ]]; then
            add_finding "HIGH" "COMPLIANCE" \
                "Protocolos SSL/TLS inseguros habilitados" \
                "Detectados protocolos SSL/TLS obsoletos na configuração do Nginx" \
                "Remover suporte a SSLv2, SSLv3, TLSv1.0 e TLSv1.1. Usar apenas TLSv1.2+"
        fi
        
        local weak_ciphers=$(grep -E "RC4|DES|MD5" /etc/nginx/nginx.conf || echo "")
        if [[ -n "$weak_ciphers" ]]; then
            add_finding "HIGH" "COMPLIANCE" \
                "Cifras SSL/TLS inseguras detectadas" \
                "Detectadas cifras criptográficas fracas na configuração SSL" \
                "Remover cifras inseguras (RC4, DES, MD5) e usar apenas cifras aprovadas"
        fi
    fi
    
    # Verificar backup de secrets
    log "INFO" "Verificando política de backup..."
    
    local backup_age=999999
    if [[ -d "$PROJECT_ROOT/backups" ]]; then
        local latest_backup=$(find "$PROJECT_ROOT/backups" -name "*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
        if [[ -n "$latest_backup" ]]; then
            backup_age=$(( ($(date +%s) - $(stat -c %Y "$latest_backup" 2>/dev/null || echo 0)) / 86400 ))
        fi
    fi
    
    if [[ $backup_age -gt 7 ]]; then
        add_finding "MEDIUM" "COMPLIANCE" \
            "Backup desatualizado detectado" \
            "O último backup encontrado tem $backup_age dias de idade" \
            "Executar backup regular: make security-backup-all ENVIRONMENT=$ENVIRONMENT"
    fi
    
    # Verificar rotação de logs
    log "INFO" "Verificando rotação de logs..."
    
    if [[ ! -f "/etc/logrotate.d/nginx" ]]; then
        add_finding "MEDIUM" "COMPLIANCE" \
            "Rotação de logs não configurada" \
            "Não foi encontrada configuração de rotação de logs para Nginx" \
            "Configurar logrotate para gerenciar logs automaticamente"
    fi
    
    # Verificar updates de segurança
    log "INFO" "Verificando updates de segurança..."
    
    local security_updates=0
    if command -v apt &> /dev/null; then
        security_updates=$(apt list --upgradable 2>/dev/null | grep -c security || echo "0")
    elif command -v yum &> /dev/null; then
        security_updates=$(yum check-update --security 2>/dev/null | wc -l || echo "0")
    fi
    
    if [[ $security_updates -gt 0 ]]; then
        add_finding "MEDIUM" "COMPLIANCE" \
            "Updates de segurança pendentes" \
            "Foram encontrados $security_updates updates de segurança disponíveis" \
            "Executar updates de segurança: apt update && apt upgrade (ou equivalente)"
    fi
    
    log "SUCCESS" "Auditoria de conformidade concluída"
}

# Auditoria de vulnerabilidades
audit_vulnerabilities() {
    log "INFO" "Iniciando auditoria de vulnerabilidades..."
    
    # Verificar portas abertas
    log "INFO" "Verificando portas abertas..."
    
    local open_ports=$(ss -tlnp | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -n | uniq || echo "")
    local unexpected_ports=""
    
    while IFS= read -r port; do
        case "$port" in
            22|80|443|3000|5000|5432|6379) 
                # Portas esperadas
                ;;
            *)
                unexpected_ports+="$port "
                ;;
        esac
    done <<< "$open_ports"
    
    if [[ -n "$unexpected_ports" ]]; then
        add_finding "MEDIUM" "VULNERABILITY" \
            "Portas não esperadas abertas" \
            "Detectadas portas abertas não esperadas: $unexpected_ports" \
            "Revisar serviços rodando e fechar portas desnecessárias"
    fi
    
    # Verificar processos suspeitos
    log "INFO" "Verificando processos em execução..."
    
    local suspicious_processes=$(ps aux | grep -E "(nc|ncat|socat|telnet).*-l" | grep -v grep || echo "")
    if [[ -n "$suspicious_processes" ]]; then
        add_finding "HIGH" "VULNERABILITY" \
            "Processos suspeitos detectados" \
            "Detectados processos que podem indicar backdoors ou shells reversos" \
            "Investigar processos suspeitos e remover se maliciosos"
    fi
    
    # Verificar usuários com privilégios elevados
    log "INFO" "Verificando usuários privilegiados..."
    
    local sudo_users=$(grep -E "^[^#].*sudo" /etc/group | cut -d: -f4 | tr ',' '\n' | sort || echo "")
    local expected_sudo_users="root ubuntu admin promata"
    
    while IFS= read -r user; do
        if [[ -n "$user" ]] && ! echo "$expected_sudo_users" | grep -q "$user"; then
            add_finding "MEDIUM" "VULNERABILITY" \
                "Usuário com privilégios sudo não esperado" \
                "Usuário '$user' possui privilégios sudo mas não está na lista de usuários aprovados" \
                "Revisar necessidade do usuário ter privilégios sudo e remover se desnecessário"
        fi
    done <<< "$sudo_users"
    
    # Verificar permissões de arquivos sensíveis
    log "INFO" "Verificando permissões de arquivos sensíveis..."
    
    local sensitive_files=(
        "/etc/passwd:644"
        "/etc/shadow:640"
        "/etc/ssh/sshd_config:644"
        "/root:700"
        "/home/*/.ssh:700"
    )
    
    for file_perm in "${sensitive_files[@]}"; do
        local file="${file_perm%:*}"
        local expected_perm="${file_perm#*:}"
        
        if [[ "$file" == *"*"* ]]; then
            # Lidar com wildcards
            for actual_file in $file; do
                if [[ -e "$actual_file" ]]; then
                    local actual_perm=$(stat -c "%a" "$actual_file" 2>/dev/null || echo "000")
                    if [[ "$actual_perm" != "$expected_perm" ]]; then
                        add_finding "MEDIUM" "VULNERABILITY" \
                            "Permissões inadequadas em arquivo sensível" \
                            "Arquivo $actual_file possui permissões $actual_perm (esperadas: $expected_perm)" \
                            "Executar: chmod $expected_perm $actual_file"
                    fi
                fi
            done
        else
            if [[ -e "$file" ]]; then
                local actual_perm=$(stat -c "%a" "$file" 2>/dev/null || echo "000")
                if [[ "$actual_perm" != "$expected_perm" ]]; then
                    add_finding "MEDIUM" "VULNERABILITY" \
                        "Permissões inadequadas em arquivo sensível" \
                        "Arquivo $file possui permissões $actual_perm (esperadas: $expected_perm)" \
                        "Executar: chmod $expected_perm $file"
                fi
            fi
        fi
    done
    
    log "SUCCESS" "Auditoria de vulnerabilidades concluída"
}

# Auditoria de containers Docker
audit_docker_security() {
    log "INFO" "Iniciando auditoria de segurança Docker..."
    
    if ! command -v docker &> /dev/null; then
        log "WARN" "Docker não encontrado, pulando auditoria de containers"
        return
    fi
    
    # Verificar containers privilegiados
    log "INFO" "Verificando containers privilegiados..."
    
    local privileged_containers=$(docker ps --filter "label=privileged=true" --format "{{.Names}}" || echo "")
    if [[ -n "$privileged_containers" ]]; then
        while IFS= read -r container; do
            if [[ -n "$container" ]]; then
                add_finding "HIGH" "CONTAINER_SECURITY" \
                    "Container rodando em modo privilegiado" \
                    "Container '$container' está rodando com privilégios elevados" \
                    "Revisar necessidade de privilégios e usar capabilities específicas ao invés de --privileged"
            fi
        done <<< "$privileged_containers"
    fi
    
    # Verificar mounts inseguros
    log "INFO" "Verificando mounts de containers..."
    
    local dangerous_mounts=$(docker ps --format "{{.Names}}" | xargs -I {} docker inspect {} --format '{{.Name}}: {{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' 2>/dev/null | grep -E "(/etc|/var|/:|/proc|/sys)" || echo "")
    
    if [[ -n "$dangerous_mounts" ]]; then
        while IFS= read -r mount_info; do
            if [[ -n "$mount_info" ]]; then
                add_finding "MEDIUM" "CONTAINER_SECURITY" \
                    "Mount potencialmente perigoso detectado" \
                    "Container com mount suspeito: $mount_info" \
                    "Revisar se o mount é necessário e considerar usar volumes nomeados"
            fi
        done <<< "$dangerous_mounts"
    fi
    
    # Verificar uso de imagens não-oficiais
    log "INFO" "Verificando origem das imagens..."
    
    local custom_images=$(docker images --format "{{.Repository}}" | grep -v -E "(nginx|postgres|redis|ubuntu|alpine|node)" | sort -u || echo "")
    if [[ -n "$custom_images" ]]; then
        while IFS= read -r image; do
            if [[ -n "$image" ]] && [[ ! "$image" =~ (localhost|127.0.0.1|promata) ]]; then
                add_finding "INFO" "CONTAINER_SECURITY" \
                    "Uso de imagem não-oficial detectada" \
                    "Imagem '$image' não é de registry oficial ou interno" \
                    "Verificar origem da imagem e considerar usar apenas imagens de registries confiáveis"
            fi
        done <<< "$custom_images"
    fi
    
    # Verificar recursos limitados
    log "INFO" "Verificando limitação de recursos..."
    
    local unlimited_containers=$(docker ps --format "{{.Names}}" | xargs -I {} docker inspect {} --format '{{.Name}}: Memory={{.HostConfig.Memory}} CPU={{.HostConfig.CpuQuota}}' 2>/dev/null | grep "Memory=0 CPU=" || echo "")
    
    if [[ -n "$unlimited_containers" ]]; then
        while IFS= read -r container; do
            if [[ -n "$container" ]]; then
                add_finding "LOW" "CONTAINER_SECURITY" \
                    "Container sem limitação de recursos" \
                    "Container sem limites de memória/CPU: $container" \
                    "Definir limites de recursos: --memory=512m --cpus=1.0"
            fi
        done <<< "$unlimited_containers"
    fi
    
    log "SUCCESS" "Auditoria de segurança Docker concluída"
}

# Verificação rápida de conformidade
quick_compliance_check() {
    log "INFO" "Executando verificação rápida de conformidade..."
    
    init_audit_stats
    
    # Verificações essenciais
    audit_configuration_changes
    
    # Verificar apenas items críticos
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        local root_login=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' || echo "yes")
        if [[ "$root_login" != "no" ]] && [[ "$root_login" != "without-password" ]]; then
            add_finding "HIGH" "SSH_SECURITY" \
                "Login root SSH habilitado" \
                "Configuração SSH permite login direto como root" \
                "Definir PermitRootLogin no em /etc/ssh/sshd_config"
        fi
    fi
    
    # Verificar firewall básico
    if command -v ufw &> /dev/null; then
        local ufw_status=$(ufw status | grep "Status:" | awk '{print $2}' || echo "inactive")
        if [[ "$ufw_status" != "active" ]]; then
            add_finding "MEDIUM" "FIREWALL" \
                "Firewall não está ativo" \
                "UFW (Uncomplicated Firewall) está inativo" \
                "Ativar firewall: ufw enable"
        fi
    fi
    
    log "SUCCESS" "Verificação rápida de conformidade concluída"
}

# Auditoria completa
full_security_audit() {
    log "INFO" "Iniciando auditoria completa de segurança..."
    
    init_audit_stats
    
    audit_access_logs
    audit_configuration_changes
    audit_compliance
    audit_vulnerabilities
    audit_docker_security
    
    log "SUCCESS" "Auditoria completa de segurança concluída"
}

# Geração de relatório
generate_report() {
    local output_file="${1:-}"
    local format="${2:-$OUTPUT_FORMAT}"
    
    if [[ -z "$output_file" ]]; then
        output_file="$REPORTS_DIR/security-audit-$(date +%Y%m%d-%H%M%S).$format"
    fi
    
    log "INFO" "Gerando relatório de auditoria em formato $format..."
    
    case "$format" in
        "json")
            generate_json_report "$output_file"
            ;;
        "html")
            generate_html_report "$output_file"
            ;;
        "pdf")
            generate_pdf_report "$output_file"
            ;;
        *)
            generate_text_report "$output_file"
            ;;
    esac
    
    log "SUCCESS" "Relatório gerado: $output_file"
    echo "$output_file"
}

# Relatório em texto
generate_text_report() {
    local output_file="$1"
    
    cat > "$output_file" << EOF
# RELATÓRIO DE AUDITORIA DE SEGURANÇA - PRO-MATA
# Gerado em: $(date '+%Y-%m-%d %H:%M:%S')
# Ambiente: $ENVIRONMENT
# Versão do Script: 1.0.0

## RESUMO EXECUTIVO

Total de findings encontrados: ${AUDIT_STATS[TOTAL]}

Distribuição por severidade:
- CRÍTICO: ${AUDIT_STATS[CRITICAL]}
- ALTO: ${AUDIT_STATS[HIGH]}  
- MÉDIO: ${AUDIT_STATS[MEDIUM]}
- BAIXO: ${AUDIT_STATS[LOW]}
- INFORMATIVO: ${AUDIT_STATS[INFO]}

## FINDINGS DETALHADOS

EOF
    
    # Iterar por todos os findings
    for finding_id in "${!AUDIT_FINDINGS[@]}"; do
        local finding="${AUDIT_FINDINGS[$finding_id]}"
        
        # Extrair campos do JSON (parsing simples)
        local severity=$(echo "$finding" | grep -o '"severity": "[^"]*"' | cut -d'"' -f4)
        local category=$(echo "$finding" | grep -o '"category": "[^"]*"' | cut -d'"' -f4)
        local title=$(echo "$finding" | grep -o '"title": "[^"]*"' | cut -d'"' -f4)
        local description=$(echo "$finding" | grep -o '"description": "[^"]*"' | cut -d'"' -f4)
        local recommendation=$(echo "$finding" | grep -o '"recommendation": "[^"]*"' | cut -d'"' -f4)
        
        cat >> "$output_file" << EOF

### [$severity] $title
**Categoria:** $category
**Descrição:** $description
**Recomendação:** $recommendation

---
EOF
    done
    
    cat >> "$output_file" << EOF

## RECOMENDAÇÕES GERAIS

1. **Implementar monitoramento contínuo** de logs de segurança
2. **Automatizar rotação de secrets** conforme política estabelecida
3. **Manter sistema sempre atualizado** com patches de segurança
4. **Revisar configurações** periodicamente
5. **Treinar equipe** em boas práticas de segurança

## PRÓXIMOS PASSOS

1. Priorizar correção de findings CRÍTICOS e ALTOS
2. Agendar revisão semanal de logs de segurança
3. Implementar alertas automáticos para anomalias
4. Documentar todas as correções aplicadas
5. Agendar próxima auditoria em 30 dias

---
*Relatório gerado pelo Pro-Mata Security Audit System v1.0.0*
EOF
}

# Relatório em JSON
generate_json_report() {
    local output_file="$1"
    
    cat > "$output_file" << EOF
{
  "audit_report": {
    "metadata": {
      "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
      "environment": "$ENVIRONMENT",
      "script_version": "1.0.0",
      "audit_type": "$AUDIT_TYPE"
    },
    "summary": {
      "total_findings": ${AUDIT_STATS[TOTAL]},
      "critical": ${AUDIT_STATS[CRITICAL]},
      "high": ${AUDIT_STATS[HIGH]},
      "medium": ${AUDIT_STATS[MEDIUM]},
      "low": ${AUDIT_STATS[LOW]},
      "info": ${AUDIT_STATS[INFO]}
    },
    "findings": [
EOF
    
    local first=true
    for finding_id in "${!AUDIT_FINDINGS[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$output_file"
        fi
        echo "      ${AUDIT_FINDINGS[$finding_id]}" >> "$output_file"
    done
    
    cat >> "$output_file" << EOF
    ]
  }
}
EOF
}

# Relatório em HTML  
generate_html_report() {
    local output_file="$1"
    
    cat > "$output_file" << EOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Relatório de Auditoria de Segurança - Pro-Mata</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 40px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        h3 { color: #7f8c8d; }
        .summary { background: #ecf0f1; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .finding { margin: 20px 0; padding: 15px; border-radius: 5px; border-left: 5px solid #bdc3c7; }
        .critical { border-left-color: #e74c3c; background: #fdf2f2; }
        .high { border-left-color: #e67e22; background: #fef9f3; }
        .medium { border-left-color: #f39c12; background: #fefbf3; }
        .low { border-left-color: #27ae60; background: #f2fcf5; }
        .info { border-left-color: #3498db; background: #f3f9ff; }
        .severity { font-weight: bold; padding: 3px 8px; border-radius: 3px; color: white; font-size: 0.8em; }
        .critical-badge { background: #e74c3c; }
        .high-badge { background: #e67e22; }
        .medium-badge { background: #f39c12; }
        .low-badge { background: #27ae60; }
        .info-badge { background: #3498db; }
        .stats { display: flex; justify-content: space-around; text-align: center; }
        .stat { padding: 10px; }
        .stat-number { font-size: 2em; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #3498db; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔐 Relatório de Auditoria de Segurança - Pro-Mata</h1>
        
        <div class="summary">
            <h2>📊 Resumo Executivo</h2>
            <p><strong>Data:</strong> $(date '+%d/%m/%Y %H:%M:%S')</p>
            <p><strong>Ambiente:</strong> $ENVIRONMENT</p>
            <p><strong>Total de Findings:</strong> ${AUDIT_STATS[TOTAL]}</p>
            
            <div class="stats">
                <div class="stat">
                    <div class="stat-number" style="color: #e74c3c;">${AUDIT_STATS[CRITICAL]}</div>
                    <div>Crítico</div>
                </div>
                <div class="stat">
                    <div class="stat-number" style="color: #e67e22;">${AUDIT_STATS[HIGH]}</div>
                    <div>Alto</div>
                </div>
                <div class="stat">
                    <div class="stat-number" style="color: #f39c12;">${AUDIT_STATS[MEDIUM]}</div>
                    <div>Médio</div>
                </div>
                <div class="stat">
                    <div class="stat-number" style="color: #27ae60;">${AUDIT_STATS[LOW]}</div>
                    <div>Baixo</div>
                </div>
                <div class="stat">
                    <div class="stat-number" style="color: #3498db;">${AUDIT_STATS[INFO]}</div>
                    <div>Info</div>
                </div>
            </div>
        </div>
        
        <h2>🔍 Findings Detalhados</h2>
EOF
    
    # Iterar por findings ordenados por severidade
    local severities=("CRITICAL" "HIGH" "MEDIUM" "LOW" "INFO")
    for severity in "${severities[@]}"; do
        for finding_id in "${!AUDIT_FINDINGS[@]}"; do
            local finding="${AUDIT_FINDINGS[$finding_id]}"
            local finding_severity=$(echo "$finding" | grep -o '"severity": "[^"]*"' | cut -d'"' -f4)
            
            if [[ "$finding_severity" == "$severity" ]]; then
                local category=$(echo "$finding" | grep -o '"category": "[^"]*"' | cut -d'"' -f4)
                local title=$(echo "$finding" | grep -o '"title": "[^"]*"' | cut -d'"' -f4)
                local description=$(echo "$finding" | grep -o '"description": "[^"]*"' | cut -d'"' -f4)
                local recommendation=$(echo "$finding" | grep -o '"recommendation": "[^"]*"' | cut -d'"' -f4)
                
                local class_name=$(echo "$severity" | tr '[:upper:]' '[:lower:]')
                local badge_class="${class_name}-badge"
                
                cat >> "$output_file" << EOF
        <div class="finding $class_name">
            <h3>
                <span class="severity $badge_class">$severity</span>
                $title
            </h3>
            <p><strong>Categoria:</strong> $category</p>
            <p><strong>Descrição:</strong> $description</p>
            <p><strong>Recomendação:</strong> $recommendation</p>
        </div>
EOF
            fi
        done
    done
    
    cat >> "$output_file" << EOF
        
        <h2>📋 Próximos Passos</h2>
        <ol>
            <li>Priorizar correção de findings <strong>CRÍTICOS</strong> e <strong>ALTOS</strong></li>
            <li>Implementar monitoramento contínuo de logs de segurança</li>
            <li>Automatizar rotação de secrets conforme política</li>
            <li>Agendar revisão semanal de configurações de segurança</li>
            <li>Documentar todas as correções aplicadas</li>
        </ol>
        
        <div class="summary" style="margin-top: 40px;">
            <p><small>Relatório gerado pelo Pro-Mata Security Audit System v1.0.0</small></p>
        </div>
    </div>
</body>
</html>
EOF
}

# Relatório em PDF (requer wkhtmltopdf)
generate_pdf_report() {
    local output_file="$1"
    local html_file="${output_file%.*}.html"
    
    # Gerar HTML primeiro
    generate_html_report "$html_file"
    
    # Converter para PDF se wkhtmltopdf estiver disponível
    if command -v wkhtmltopdf &> /dev/null; then
        wkhtmltopdf --page-size A4 --margin-top 0.75in --margin-right 0.75in --margin-bottom 0.75in --margin-left 0.75in "$html_file" "$output_file"
        rm "$html_file"  # Remover arquivo HTML temporário
    else
        log "WARN" "wkhtmltopdf não encontrado, mantendo relatório em HTML"
        mv "$html_file" "$output_file"
    fi
}

# Parse de argumentos
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --no-save)
                SAVE_REPORT=false
                shift
                ;;
            --full-audit)
                AUDIT_TYPE="full"
                shift
                ;;
            --audit-access)
                AUDIT_TYPE="access"
                shift
                ;;
            --audit-changes)
                AUDIT_TYPE="changes"
                shift
                ;;
            --audit-compliance)
                AUDIT_TYPE="compliance"
                shift
                ;;
            --compliance-check)
                AUDIT_TYPE="quick-compliance"
                shift
                ;;
            --generate-report)
                AUDIT_TYPE="report-only"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Argumento desconhecido: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validar argumentos
validate_arguments() {
    if [[ -z "$AUDIT_TYPE" ]]; then
        log "ERROR" "Tipo de auditoria necessário. Use -h para ajuda."
        exit 1
    fi
    
    if [[ -z "$ENVIRONMENT" ]] && [[ "$AUDIT_TYPE" != "report-only" ]]; then
        log "WARN" "Ambiente não especificado, usando configurações gerais"
        ENVIRONMENT="general"
    fi
    
    if [[ -n "$ENVIRONMENT" ]] && [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod|general)$ ]]; then
        log "ERROR" "Ambiente inválido: $ENVIRONMENT. Use: dev, staging, prod"
        exit 1
    fi
}

# Função principal
main() {
    echo -e "${BLUE}"
    echo "██████╗ ██████╗  ██████╗       ███╗   ███╗ █████╗ ████████╗ █████╗ "
    echo "██╔══██╗██╔══██╗██╔═══██╗      ████╗ ████║██╔══██╗╚══██╔══╝██╔══██╗"
    echo "██████╔╝██████╔╝██║   ██║█████╗██╔████╔██║███████║   ██║   ███████║"
    echo "██╔═══╝ ██╔══██╗██║   ██║╚════╝██║╚██╔╝██║██╔══██║   ██║   ██╔══██║"
    echo "██║     ██║  ██║╚██████╔╝      ██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║"
    echo "╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝"
    echo ""
    echo "🔍 Security Audit System - Auditoria Completa de Segurança"
    echo -e "${NC}"
    
    # Setup
    setup_logging
    setup_temp_env
    parse_arguments "$@"
    validate_arguments
    
    log "INFO" "Iniciando auditoria de segurança - Tipo: $AUDIT_TYPE - Ambiente: $ENVIRONMENT"
    
    # Executar auditoria baseada no tipo
    case "$AUDIT_TYPE" in
        "full")
            full_security_audit
            ;;
        "access")
            init_audit_stats
            audit_access_logs
            ;;
        "changes")
            init_audit_stats
            audit_configuration_changes
            ;;
        "compliance")
            init_audit_stats
            audit_compliance
            ;;
        "quick-compliance")
            quick_compliance_check
            ;;
        "report-only")
            # Apenas gerar relatório (assumindo que findings já existem)
            init_audit_stats
            ;;
    esac
    
    # Gerar relatório se solicitado
    if [[ "$SAVE_REPORT" == "true" ]] && [[ "$AUDIT_TYPE" != "report-only" ]]; then
        local report_file=$(generate_report "$OUTPUT_FILE" "$OUTPUT_FORMAT")
        log "SUCCESS" "Relatório de auditoria salvo: $report_file"
    fi
    
    # Resumo final
    echo ""
    log "SUCCESS" "Auditoria de segurança concluída!"
    log "INFO" "Resumo: ${AUDIT_STATS[TOTAL]} findings encontrados"
    log "INFO" "  - Críticos: ${AUDIT_STATS[CRITICAL]}"
    log "INFO" "  - Altos: ${AUDIT_STATS[HIGH]}"
    log "INFO" "  - Médios: ${AUDIT_STATS[MEDIUM]}"
    log "INFO" "  - Baixos: ${AUDIT_STATS[LOW]}"
    log "INFO" "  - Informativos: ${AUDIT_STATS[INFO]}"
    
    # Exit code baseado na severidade dos findings
    if [[ ${AUDIT_STATS[CRITICAL]} -gt 0 ]]; then
        exit 2
    elif [[ ${AUDIT_STATS[HIGH]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi