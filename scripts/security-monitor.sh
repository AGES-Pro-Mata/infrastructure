#!/bin/bash

# scripts/security-monitor.sh
# Sistema de monitoramento de segurança em tempo real para Pro-Mata
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
MONITOR_DIR="$PROJECT_ROOT/monitoring"
PID_FILE="$MONITOR_DIR/security-monitor.pid"

# Variáveis globais
VERBOSE=false
ENVIRONMENT=""
MONITOR_INTERVAL=30
DAEMON_MODE=false
ALERT_THRESHOLD_CRITICAL=1
ALERT_THRESHOLD_HIGH=5
CHECK_ALERTS_ONLY=false
DURATION=""

# Contadores e estado
declare -A ALERT_COUNTERS
declare -A LAST_ALERT_TIME
MONITOR_START_TIME=""

# Logging
setup_logging() {
    mkdir -p "$LOG_DIR" "$MONITOR_DIR"
    LOG_FILE="$LOG_DIR/security-monitor-$(date +%Y%m%d-%H%M%S).log"
    
    if [[ "$DAEMON_MODE" == "true" ]]; then
        exec 1> "$LOG_FILE"
        exec 2> "$LOG_FILE"
    else
        exec 1> >(tee -a "$LOG_FILE")
        exec 2> >(tee -a "$LOG_FILE" >&2)
    fi
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
        "ALERT")
            echo -e "${CYAN}[$timestamp]${NC} ${RED}ALERT${NC}: $message"
            ;;
        "SUCCESS")
            echo -e "${CYAN}[$timestamp]${NC} ${GREEN}SUCCESS${NC}: $message"
            ;;
        *)
            echo -e "${CYAN}[$timestamp]${NC} $message"
            ;;
    esac
}

# Função de ajuda
show_help() {
    cat << EOF
${BLUE}Pro-Mata Security Monitor${NC}

Sistema de monitoramento de segurança em tempo real para infraestrutura Pro-Mata

${YELLOW}Uso:${NC} $0 [OPÇÕES]

${YELLOW}OPÇÕES:${NC}
  -e, --environment ENV      Ambiente (dev|staging|prod)
  -i, --interval SECONDS     Intervalo de monitoramento em segundos (default: 30)
  -d, --daemon              Executar em modo daemon
  -v, --verbose             Output detalhado
  --duration DURATION       Duração do monitoramento (ex: 1h, 30m, 2h30m)
  --check-alerts            Apenas verificar e processar alertas existentes
  --alert-critical N        Threshold para alertas críticos (default: 1)
  --alert-high N           Threshold para alertas altos (default: 5)
  -h, --help               Mostrar esta ajuda

${YELLOW}COMANDOS DE CONTROLE:${NC}
  start                    Iniciar monitoramento
  stop                     Parar monitoramento
  status                   Verificar status do monitor
  restart                  Reiniciar monitoramento

${YELLOW}EXEMPLOS:${NC}
  $0 --environment prod --daemon
  $0 --check-alerts --environment staging
  $0 --interval 60 --duration 2h
  $0 start --environment prod
  $0 stop

${YELLOW}MONITORAMENTO INCLUI:${NC}
  - Tentativas de login suspeitas
  - Mudanças em arquivos críticos
  - Uso anormal de recursos
  - Processos suspeitos
  - Conexões de rede anômalas
  - Falhas de autenticação
  - Alertas de vulnerabilidades

EOF
}

# Inicializar contadores
init_counters() {
    ALERT_COUNTERS[login_failures]=0
    ALERT_COUNTERS[file_changes]=0
    ALERT_COUNTERS[suspicious_processes]=0
    ALERT_COUNTERS[network_anomalies]=0
    ALERT_COUNTERS[resource_usage]=0
    ALERT_COUNTERS[auth_failures]=0
    ALERT_COUNTERS[vulnerabilities]=0
    
    LAST_ALERT_TIME[login_failures]=0
    LAST_ALERT_TIME[file_changes]=0
    LAST_ALERT_TIME[suspicious_processes]=0
    LAST_ALERT_TIME[network_anomalies]=0
    LAST_ALERT_TIME[resource_usage]=0
    LAST_ALERT_TIME[auth_failures]=0
    LAST_ALERT_TIME[vulnerabilities]=0
    
    MONITOR_START_TIME=$(date +%s)
}

# Verificar se o monitor está rodando
is_monitor_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Iniciar monitoramento
start_monitoring() {
    if is_monitor_running; then
        log "WARN" "Monitor já está rodando (PID: $(cat "$PID_FILE"))"
        return 1
    fi
    
    log "SUCCESS" "Iniciando monitoramento de segurança..."
    
    # Salvar PID
    echo $$ > "$PID_FILE"
    
    # Setup de limpeza
    trap cleanup_monitor EXIT INT TERM
    
    init_counters
    
    log "INFO" "Monitor iniciado - PID: $$"
    log "INFO" "Ambiente: ${ENVIRONMENT:-'all'}"
    log "INFO" "Intervalo: ${MONITOR_INTERVAL}s"
    
    if [[ -n "$DURATION" ]]; then
        local duration_seconds=$(parse_duration "$DURATION")
        log "INFO" "Duração: $DURATION ($duration_seconds segundos)"
        
        # Timer para parar o monitoramento
        (sleep "$duration_seconds" && kill $$) &
    fi
    
    # Loop principal de monitoramento
    while true; do
        monitor_cycle
        sleep "$MONITOR_INTERVAL"
    done
}

# Parar monitoramento
stop_monitoring() {
    if ! is_monitor_running; then
        log "INFO" "Monitor não está rodando"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    log "INFO" "Parando monitor (PID: $pid)..."
    
    if kill "$pid" 2>/dev/null; then
        log "SUCCESS" "Monitor parado com sucesso"
    else
        log "ERROR" "Falha ao parar monitor"
        return 1
    fi
    
    rm -f "$PID_FILE"
}

# Status do monitoramento
monitoring_status() {
    if is_monitor_running; then
        local pid=$(cat "$PID_FILE")
        local start_time=""
        
        if command -v ps &> /dev/null; then
            start_time=$(ps -p "$pid" -o lstart= 2>/dev/null | xargs || echo "")
        fi
        
        log "SUCCESS" "Monitor ativo (PID: $pid)"
        if [[ -n "$start_time" ]]; then
            log "INFO" "Iniciado em: $start_time"
        fi
        
        # Mostrar estatísticas se disponíveis
        show_monitoring_stats
    else
        log "INFO" "Monitor não está rodando"
        return 1
    fi
}

# Mostrar estatísticas de monitoramento
show_monitoring_stats() {
    if [[ -f "$MONITOR_DIR/stats.json" ]]; then
        log "INFO" "Estatísticas de monitoramento:"
        if command -v jq &> /dev/null; then
            jq -r '.alerts | to_entries[] | "  - \(.key): \(.value)"' "$MONITOR_DIR/stats.json" 2>/dev/null || true
        fi
    fi
}

# Limpeza ao sair
cleanup_monitor() {
    log "INFO" "Finalizando monitoramento..."
    
    # Salvar estatísticas finais
    save_monitoring_stats
    
    # Remover PID file
    rm -f "$PID_FILE"
    
    log "SUCCESS" "Monitor finalizado"
}

# Salvar estatísticas de monitoramento
save_monitoring_stats() {
    local stats_file="$MONITOR_DIR/stats.json"
    local end_time=$(date +%s)
    local duration=$((end_time - MONITOR_START_TIME))
    
    cat > "$stats_file" << EOF
{
  "session": {
    "start_time": "$MONITOR_START_TIME",
    "end_time": "$end_time",
    "duration_seconds": $duration,
    "environment": "${ENVIRONMENT:-'unknown'}"
  },
  "alerts": {
    "login_failures": ${ALERT_COUNTERS[login_failures]},
    "file_changes": ${ALERT_COUNTERS[file_changes]},
    "suspicious_processes": ${ALERT_COUNTERS[suspicious_processes]},
    "network_anomalies": ${ALERT_COUNTERS[network_anomalies]},
    "resource_usage": ${ALERT_COUNTERS[resource_usage]},
    "auth_failures": ${ALERT_COUNTERS[auth_failures]},
    "vulnerabilities": ${ALERT_COUNTERS[vulnerabilities]}
  },
  "thresholds": {
    "critical": $ALERT_THRESHOLD_CRITICAL,
    "high": $ALERT_THRESHOLD_HIGH
  }
}
EOF
}

# Parsing de duração (1h, 30m, 2h30m)
parse_duration() {
    local duration="$1"
    local total_seconds=0
    
    # Extrair horas
    if [[ "$duration" =~ ([0-9]+)h ]]; then
        local hours=${BASH_REMATCH[1]}
        total_seconds=$((total_seconds + hours * 3600))
    fi
    
    # Extrair minutos
    if [[ "$duration" =~ ([0-9]+)m ]]; then
        local minutes=${BASH_REMATCH[1]}
        total_seconds=$((total_seconds + minutes * 60))
    fi
    
    # Se apenas número, assumir segundos
    if [[ "$duration" =~ ^[0-9]+$ ]]; then
        total_seconds="$duration"
    fi
    
    echo "$total_seconds"
}

# Ciclo de monitoramento principal
monitor_cycle() {
    if [[ "$VERBOSE" == "true" ]]; then
        log "INFO" "Executando ciclo de monitoramento..."
    fi
    
    monitor_login_attempts
    monitor_file_changes
    monitor_processes
    monitor_network
    monitor_resource_usage
    monitor_authentication
    check_recent_vulnerabilities
    
    # Processar alertas acumulados
    process_alerts
}

# Monitorar tentativas de login
monitor_login_attempts() {
    local auth_log="/var/log/auth.log"
    
    if [[ ! -f "$auth_log" ]]; then
        return
    fi
    
    # Verificar falhas de login nos últimos $MONITOR_INTERVAL segundos
    local recent_failures=$(grep "$(date '+%b %d %H:')" "$auth_log" 2>/dev/null | \
        grep "Failed password" | \
        tail -20 | wc -l)
    
    if [[ $recent_failures -gt 3 ]]; then
        ((ALERT_COUNTERS[login_failures]++))
        
        # Extrair IPs suspeitos
        local suspicious_ips=$(grep "$(date '+%b %d %H:')" "$auth_log" 2>/dev/null | \
            grep "Failed password" | \
            awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -5)
        
        log "ALERT" "[$recent_failures] Tentativas de login falharam recentemente"
        
        if [[ "$VERBOSE" == "true" ]] && [[ -n "$suspicious_ips" ]]; then
            log "INFO" "IPs suspeitos: $suspicious_ips"
        fi
        
        # Alerta crítico se muitas tentativas
        if [[ $recent_failures -gt 10 ]]; then
            send_critical_alert "login_brute_force" \
                "Possível ataque de força bruta detectado: $recent_failures tentativas de login falharam" \
                "Verificar logs de autenticação e considerar bloqueio de IPs suspeitos"
        fi
    fi
}

# Monitorar mudanças em arquivos críticos
monitor_file_changes() {
    local critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/ssh/sshd_config"
        "/etc/nginx/nginx.conf"
        "$PROJECT_ROOT/.env*"
    )
    
    local changes_detected=0
    
    for file_pattern in "${critical_files[@]}"; do
        if [[ "$file_pattern" == *"*" ]]; then
            # Lidar com wildcards
            for file in $file_pattern; do
                if [[ -f "$file" ]] && check_file_modified "$file"; then
                    ((changes_detected++))
                    log "ALERT" "Arquivo crítico modificado: $file"
                fi
            done
        else
            if [[ -f "$file_pattern" ]] && check_file_modified "$file_pattern"; then
                ((changes_detected++))
                log "ALERT" "Arquivo crítico modificado: $file_pattern"
            fi
        fi
    done
    
    if [[ $changes_detected -gt 0 ]]; then
        ((ALERT_COUNTERS[file_changes] += changes_detected))
        
        if [[ $changes_detected -gt 2 ]]; then
            send_critical_alert "multiple_file_changes" \
                "$changes_detected arquivos críticos foram modificados recentemente" \
                "Verificar se as mudanças foram autorizadas e documentadas"
        fi
    fi
}

# Verificar se arquivo foi modificado recentemente
check_file_modified() {
    local file="$1"
    local marker_file="$MONITOR_DIR/$(basename "$file").lastcheck"
    
    if [[ ! -f "$marker_file" ]]; then
        # Primeira execução - criar marker
        stat -c %Y "$file" > "$marker_file" 2>/dev/null || echo "0" > "$marker_file"
        return 1
    fi
    
    local last_check=$(cat "$marker_file")
    local current_mtime=$(stat -c %Y "$file" 2>/dev/null || echo "0")
    
    if [[ $current_mtime -gt $last_check ]]; then
        echo "$current_mtime" > "$marker_file"
        return 0
    fi
    
    return 1
}

# Monitorar processos suspeitos
monitor_processes() {
    # Buscar processos que podem indicar atividade maliciosa
    local suspicious_patterns=(
        "nc.*-l"           # netcat listening
        "ncat.*-l"         # ncat listening  
        "socat"            # socat (pode ser usado para tunneling)
        "wget.*http"       # downloads suspeitos
        "curl.*|.*sh"      # pipe para shell
    )
    
    local suspicious_found=0
    
    for pattern in "${suspicious_patterns[@]}"; do
        local matches=$(ps aux | grep -E "$pattern" | grep -v grep | wc -l)
        
        if [[ $matches -gt 0 ]]; then
            ((suspicious_found++))
            local process_details=$(ps aux | grep -E "$pattern" | grep -v grep | head -3)
            log "ALERT" "Processo suspeito detectado: $pattern"
            
            if [[ "$VERBOSE" == "true" ]]; then
                log "INFO" "Detalhes: $process_details"
            fi
        fi
    done
    
    if [[ $suspicious_found -gt 0 ]]; then
        ((ALERT_COUNTERS[suspicious_processes] += suspicious_found))
        
        if [[ $suspicious_found -gt 1 ]]; then
            send_critical_alert "multiple_suspicious_processes" \
                "$suspicious_found processos suspeitos detectados simultaneamente" \
                "Investigar processos imediatamente e verificar se são maliciosos"
        fi
    fi
}

# Monitorar rede
monitor_network() {
    # Verificar conexões de rede anômalas
    local unusual_connections=0
    
    # Verificar muitas conexões de um mesmo IP
    local top_ips=$(ss -tnp | grep ESTAB | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -5)
    
    while read -r count ip; do
        if [[ -n "$count" ]] && [[ $count -gt 50 ]] && [[ "$ip" != "127.0.0.1" ]]; then
            ((unusual_connections++))
            log "ALERT" "IP com muitas conexões: $ip ($count conexões)"
        fi
    done <<< "$top_ips"
    
    # Verificar portas inesperadas listening
    local unexpected_ports=$(ss -tlnp | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -n | uniq)
    local expected_ports="22 80 443 3000 5000 5432 6379"
    local new_ports=""
    
    while IFS= read -r port; do
        if [[ -n "$port" ]] && ! echo "$expected_ports" | grep -q "$port"; then
            new_ports+="$port "
        fi
    done <<< "$unexpected_ports"
    
    if [[ -n "$new_ports" ]]; then
        ((unusual_connections++))
        log "ALERT" "Novas portas em listening: $new_ports"
    fi
    
    if [[ $unusual_connections -gt 0 ]]; then
        ((ALERT_COUNTERS[network_anomalies] += unusual_connections))
    fi
}

# Monitorar uso de recursos
monitor_resource_usage() {
    # Verificar CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | cut -d'%' -f1)
    cpu_usage=${cpu_usage%.*}  # Remover decimais
    
    if [[ $cpu_usage -gt 90 ]]; then
        ((ALERT_COUNTERS[resource_usage]++))
        log "ALERT" "Alto uso de CPU detectado: ${cpu_usage}%"
        
        if [[ $cpu_usage -gt 95 ]]; then
            # Encontrar processos consumindo CPU
            local top_processes=$(ps aux --sort=-%cpu | head -5 | tail -4)
            send_critical_alert "high_cpu_usage" \
                "Uso crítico de CPU: ${cpu_usage}%" \
                "Top processos: $top_processes"
        fi
    fi
    
    # Verificar memória
    local mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
    
    if [[ $mem_usage -gt 90 ]]; then
        ((ALERT_COUNTERS[resource_usage]++))
        log "ALERT" "Alto uso de memória detectado: ${mem_usage}%"
        
        if [[ $mem_usage -gt 95 ]]; then
            local top_mem_processes=$(ps aux --sort=-%mem | head -5 | tail -4)
            send_critical_alert "high_memory_usage" \
                "Uso crítico de memória: ${mem_usage}%" \
                "Top processos: $top_mem_processes"
        fi
    fi
    
    # Verificar espaço em disco
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $disk_usage -gt 85 ]]; then
        ((ALERT_COUNTERS[resource_usage]++))
        log "ALERT" "Alto uso de disco detectado: ${disk_usage}%"
        
        if [[ $disk_usage -gt 95 ]]; then
            send_critical_alert "high_disk_usage" \
                "Uso crítico de disco: ${disk_usage}%" \
                "Verificar logs e arquivos desnecessários para limpeza"
        fi
    fi
}

# Monitorar autenticação
monitor_authentication() {
    local auth_log="/var/log/auth.log"
    
    if [[ ! -f "$auth_log" ]]; then
        return
    fi
    
    # Verificar sudo usage incomum
    local recent_sudo=$(grep "$(date '+%b %d %H:')" "$auth_log" 2>/dev/null | \
        grep "sudo:" | wc -l)
    
    if [[ $recent_sudo -gt 10 ]]; then
        ((ALERT_COUNTERS[auth_failures]++))
        log "ALERT" "Uso excessivo de sudo detectado: $recent_sudo comandos na última hora"
        
        # Comandos sudo mais executados
        local top_sudo_commands=$(grep "$(date '+%b %d %H:')" "$auth_log" 2>/dev/null | \
            grep "COMMAND=" | awk -F'COMMAND=' '{print $2}' | sort | uniq -c | sort -nr | head -3)
        
        if [[ "$VERBOSE" == "true" ]] && [[ -n "$top_sudo_commands" ]]; then
            log "INFO" "Top comandos sudo: $top_sudo_commands"
        fi
    fi
}

# Verificar vulnerabilidades recentes
check_recent_vulnerabilities() {
    local vuln_report="$PROJECT_ROOT/reports/security-scan/latest-scan.txt"
    
    if [[ ! -f "$vuln_report" ]]; then
        return
    fi
    
    # Verificar se o relatório é recente (última hora)
    local report_age=$((($(date +%s) - $(stat -c %Y "$vuln_report" 2>/dev/null || echo 0)) / 3600))
    
    if [[ $report_age -gt 1 ]]; then
        return
    fi
    
    # Procurar por vulnerabilidades críticas no relatório
    local critical_vulns=$(grep -c "CRÍTICAS:" "$vuln_report" 2>/dev/null || echo "0")
    local high_vulns=$(grep -c "ALTAS:" "$vuln_report" 2>/dev/null || echo "0")
    
    if [[ $critical_vulns -gt 0 ]] || [[ $high_vulns -gt 5 ]]; then
        ((ALERT_COUNTERS[vulnerabilities]++))
        log "ALERT" "Vulnerabilidades detectadas no último scan: $critical_vulns críticas, $high_vulns altas"
        
        if [[ $critical_vulns -gt 0 ]]; then
            send_critical_alert "critical_vulnerabilities_found" \
                "$critical_vulns vulnerabilidades críticas encontradas no último scan" \
                "Revisar relatório: $vuln_report e aplicar correções imediatamente"
        fi
    fi
}

# Processar alertas acumulados
process_alerts() {
    local total_alerts=0
    
    for counter in "${ALERT_COUNTERS[@]}"; do
        ((total_alerts += counter))
    done
    
    if [[ $total_alerts -gt $ALERT_THRESHOLD_HIGH ]]; then
        log "ALERT" "Alto número de alertas de segurança: $total_alerts"
        
        # Resumo dos alertas
        if [[ "$VERBOSE" == "true" ]]; then
            for alert_type in "${!ALERT_COUNTERS[@]}"; do
                if [[ ${ALERT_COUNTERS[$alert_type]} -gt 0 ]]; then
                    log "INFO" "  $alert_type: ${ALERT_COUNTERS[$alert_type]}"
                fi
            done
        fi
    fi
}

# Enviar alerta crítico
send_critical_alert() {
    local alert_type="$1"
    local message="$2"
    local recommendation="$3"
    local current_time=$(date +%s)
    
    # Evitar spam de alertas (mínimo 5 minutos entre alertas do mesmo tipo)
    if [[ $((current_time - LAST_ALERT_TIME[$alert_type])) -lt 300 ]]; then
        return
    fi
    
    LAST_ALERT_TIME[$alert_type]=$current_time
    
    log "ALERT" "🚨 ALERTA CRÍTICO: $message"
    log "ALERT" "💡 Recomendação: $recommendation"
    
    # Enviar notificação via Discord se configurado
    if [[ -n "${DISCORD_WEBHOOK_URL:-}" ]]; then
        send_discord_alert "critical" "$alert_type" "$message" "$recommendation"
    fi
    
    # Salvar alerta para processamento posterior
    local alert_file="$MONITOR_DIR/alert-$(date +%s)-$alert_type.json"
    cat > "$alert_file" << EOF
{
  "timestamp": "$current_time",
  "type": "$alert_type",
  "severity": "critical",
  "message": "$message",
  "recommendation": "$recommendation",
  "environment": "${ENVIRONMENT:-'unknown'}"
}
EOF
}

# Enviar notificação Discord
send_discord_alert() {
    local severity="$1"
    local alert_type="$2"
    local message="$3"
    local recommendation="$4"
    
    local color
    case "$severity" in
        "critical") color="15158332" ;;  # Vermelho
        "high") color="15105570" ;;      # Laranja
        "medium") color="16776960" ;;    # Amarelo
        *) color="3447003" ;;            # Azul
    esac
    
    local payload=$(cat << EOF
{
  "embeds": [{
    "title": "🚨 Pro-Mata Security Monitor Alert",
    "description": "$message",
    "color": $color,
    "fields": [
      {"name": "Tipo", "value": "$alert_type", "inline": true},
      {"name": "Severidade", "value": "$severity", "inline": true},
      {"name": "Ambiente", "value": "${ENVIRONMENT:-'unknown'}", "inline": true},
      {"name": "Recomendação", "value": "$recommendation", "inline": false}
    ],
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
  }]
}
EOF
    )
    
    curl -H "Content-Type: application/json" \
         -d "$payload" \
         "$DISCORD_WEBHOOK_URL" \
         --silent > /dev/null || true
}

# Verificar alertas existentes
check_existing_alerts() {
    log "INFO" "Verificando alertas existentes..."
    
    local alert_files=$(find "$MONITOR_DIR" -name "alert-*.json" -type f 2>/dev/null | head -10)
    
    if [[ -z "$alert_files" ]]; then
        log "INFO" "Nenhum alerta pendente encontrado"
        return
    fi
    
    local alert_count=0
    
    while IFS= read -r alert_file; do
        if [[ -n "$alert_file" ]]; then
            ((alert_count++))
            
            if command -v jq &> /dev/null; then
                local alert_type=$(jq -r '.type' "$alert_file" 2>/dev/null || echo "unknown")
                local severity=$(jq -r '.severity' "$alert_file" 2>/dev/null || echo "unknown") 
                local message=$(jq -r '.message' "$alert_file" 2>/dev/null || echo "")
                
                log "ALERT" "[$severity] $alert_type: $message"
            else
                log "ALERT" "Alerta encontrado: $(basename "$alert_file")"
            fi
        fi
    done <<< "$alert_files"
    
    log "INFO" "Total de alertas encontrados: $alert_count"
    
    # Opção de limpar alertas antigos
    local old_alerts=$(find "$MONITOR_DIR" -name "alert-*.json" -type f -mtime +7 2>/dev/null)
    if [[ -n "$old_alerts" ]]; then
        local old_count=$(echo "$old_alerts" | wc -l)
        log "INFO" "Limpando $old_count alertas antigos..."
        echo "$old_alerts" | xargs rm -f
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
            -i|--interval)
                MONITOR_INTERVAL="$2"
                shift 2
                ;;
            -d|--daemon)
                DAEMON_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --duration)
                DURATION="$2"
                shift 2
                ;;
            --check-alerts)
                CHECK_ALERTS_ONLY=true
                shift
                ;;
            --alert-critical)
                ALERT_THRESHOLD_CRITICAL="$2"
                shift 2
                ;;
            --alert-high)
                ALERT_THRESHOLD_HIGH="$2"
                shift 2
                ;;
            start)
                start_monitoring
                exit $?
                ;;
            stop)
                stop_monitoring
                exit $?
                ;;
            status)
                monitoring_status
                exit $?
                ;;
            restart)
                stop_monitoring || true
                sleep 2
                start_monitoring
                exit $?
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
    echo "👁️ Security Monitor - Monitoramento de Segurança em Tempo Real"
    echo -e "${NC}"
    
    # Setup
    setup_logging
    parse_arguments "$@"
    
    if [[ "$CHECK_ALERTS_ONLY" == "true" ]]; then
        check_existing_alerts
        exit 0
    fi
    
    # Iniciar monitoramento
    start_monitoring
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi