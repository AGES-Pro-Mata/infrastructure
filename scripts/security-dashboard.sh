#!/bin/bash

# scripts/security-dashboard.sh
# Gerador de dashboard dinâmico de segurança Pro-Mata
# Autor: Sistema de Segurança Pro-Mata
# Versão: 1.0.0

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DASHBOARD_FILE="$PROJECT_ROOT/dashboard.html"
STATIC_DASHBOARD="$PROJECT_ROOT/security-dashboard-static.html"

# Variáveis globais
ENVIRONMENT="dev"
AUTO_OPEN=false
PORT=8080
SERVE_MODE=false
UPDATE_ONLY=false

# Função de logging
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
        *)
            echo -e "${CYAN}[$timestamp]${NC} $message"
            ;;
    esac
}

# Função de ajuda
show_help() {
    cat << EOF
${BLUE}Pro-Mata Security Dashboard Generator${NC}

Gera e serve o dashboard de segurança dinâmico com dados em tempo real

${YELLOW}Uso:${NC} $0 [OPÇÕES]

${YELLOW}OPÇÕES:${NC}
  -e, --environment ENV    Ambiente (dev|staging|prod) [default: dev]
  -p, --port PORT         Porta para servir o dashboard [default: 8080]
  -s, --serve             Servir dashboard via HTTP
  -o, --open              Abrir automaticamente no navegador
  -u, --update-only       Apenas atualizar dados sem gerar HTML
  -h, --help              Mostrar esta ajuda

${YELLOW}EXEMPLOS:${NC}
  $0                              # Gerar dashboard para dev
  $0 --environment prod --open    # Gerar e abrir dashboard de produção
  $0 --serve --port 3000         # Servir na porta 3000
  $0 --update-only               # Apenas atualizar dados

${YELLOW}FUNCIONALIDADES:${NC}
  📊 Métricas de sistema em tempo real
  🚨 Alertas de segurança atualizados
  📈 Status dos serviços
  📝 Logs de monitoramento
  🔍 Resultados de scans recentes
  🌍 Informações específicas do ambiente

EOF
}

# Coletar métricas do sistema
collect_system_metrics() {
    log "INFO" "Coletando métricas do sistema..."
    
    local cpu_usage=0
    local memory_usage=0
    local disk_usage=0
    local load_average="0.00"
    
    # CPU Usage
    if command -v top &> /dev/null; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | cut -d'%' -f1 | head -1)
        cpu_usage=${cpu_usage%.*}
    fi
    
    # Memory Usage
    if command -v free &> /dev/null; then
        memory_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
    fi
    
    # Disk Usage
    if command -v df &> /dev/null; then
        disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    fi
    
    # Load Average
    if [[ -f /proc/loadavg ]]; then
        load_average=$(cat /proc/loadavg | awk '{print $1}')
    fi
    
    # Network Connections
    local connections=0
    if command -v ss &> /dev/null; then
        connections=$(ss -tun | grep -c ESTAB || echo "0")
    fi
    
    # Processos ativos
    local processes=0
    if command -v ps &> /dev/null; then
        processes=$(ps aux | wc -l)
    fi
    
    cat > "$PROJECT_ROOT/tmp/system_metrics.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "cpu_usage": $cpu_usage,
  "memory_usage": $memory_usage,
  "disk_usage": $disk_usage,
  "load_average": "$load_average",
  "network_connections": $connections,
  "active_processes": $processes,
  "uptime": "$(uptime -p 2>/dev/null || echo 'N/A')"
}
EOF
}

# Coletar alertas recentes
collect_recent_alerts() {
    log "INFO" "Coletando alertas recentes..."
    
    local alerts_file="$PROJECT_ROOT/tmp/recent_alerts.json"
    echo '{"alerts": [' > "$alerts_file"
    
    local alert_count=0
    local max_alerts=10
    
    # Buscar arquivos de alerta recentes
    find "$PROJECT_ROOT/monitoring" -name "alert-*.json" -type f -mtime -1 2>/dev/null | \
    sort -r | head -$max_alerts | \
    while IFS= read -r alert_file; do
        if [[ -f "$alert_file" ]]; then
            if [[ $alert_count -gt 0 ]]; then
                echo "," >> "$alerts_file"
            fi
            cat "$alert_file" >> "$alerts_file"
            ((alert_count++))
        fi
    done
    
    echo ']}' >> "$alerts_file"
    
    # Se não há alertas, criar estrutura vazia
    if [[ $alert_count -eq 0 ]]; then
        cat > "$alerts_file" << EOF
{
  "alerts": [
    {
      "timestamp": "$(date +%s)",
      "type": "system_check",
      "severity": "info",
      "message": "Sistema funcionando normalmente",
      "recommendation": "Nenhuma ação necessária",
      "environment": "$ENVIRONMENT"
    }
  ]
}
EOF
    fi
}

# Verificar status dos serviços
check_services_status() {
    log "INFO" "Verificando status dos serviços..."
    
    local services_file="$PROJECT_ROOT/tmp/services_status.json"
    
    cat > "$services_file" << EOF
{
  "services": [
EOF
    
    # Definir serviços por ambiente
    local services=()
    case "$ENVIRONMENT" in
        "dev")
            services=("Backend API:http://localhost:3000/health" "PostgreSQL:localhost:5432" "Redis:localhost:6379")
            ;;
        "staging")
            services=("Backend API:https://api-staging.promata.duckdns.org/health" "Frontend:https://staging.promata.duckdns.org")
            ;;
        "prod")
            services=("Backend API:https://api.promata.duckdns.org/health" "Frontend:https://promata.duckdns.org")
            ;;
        *)
            services=("Sistema:localhost:22")
            ;;
    esac
    
    local service_count=0
    
    for service_def in "${services[@]}"; do
        local service_name=$(echo "$service_def" | cut -d':' -f1)
        local service_url=$(echo "$service_def" | cut -d':' -f2-)
        local status="offline"
        local response_time="N/A"
        local status_code="N/A"
        
        # Testar conectividade
        if [[ "$service_url" =~ ^https?:// ]]; then
            # HTTP/HTTPS check
            local start_time=$(date +%s%3N)
            if curl -sf "$service_url" -m 10 >/dev/null 2>&1; then
                status="online"
                local end_time=$(date +%s%3N)
                response_time="$((end_time - start_time))ms"
                status_code=$(curl -s -o /dev/null -w "%{http_code}" "$service_url" -m 5 2>/dev/null || echo "N/A")
            fi
        else
            # TCP check
            local host=$(echo "$service_url" | cut -d':' -f1)
            local port=$(echo "$service_url" | cut -d':' -f2)
            if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
                status="online"
                response_time="<100ms"
            fi
        fi
        
        if [[ $service_count -gt 0 ]]; then
            echo "," >> "$services_file"
        fi
        
        cat >> "$services_file" << EOF
    {
      "name": "$service_name",
      "status": "$status",
      "response_time": "$response_time",
      "url": "$service_url",
      "status_code": "$status_code",
      "checked_at": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
    }
EOF
        ((service_count++))
    done
    
    cat >> "$services_file" << EOF
  ]
}
EOF
}

# Obter resultados do último scan
get_scan_results() {
    log "INFO" "Obtendo resultados do último scan..."
    
    local scan_file="$PROJECT_ROOT/tmp/scan_results.json"
    local latest_scan=""
    
    # Encontrar relatório mais recente
    latest_scan=$(find "$PROJECT_ROOT/reports/security-scan" -name "*.txt" -type f -printf '%T@ %p\n' 2>/dev/null | \
                  sort -n | tail -1 | cut -d' ' -f2- || echo "")
    
    if [[ -n "$latest_scan" ]] && [[ -f "$latest_scan" ]]; then
        local scan_date=$(stat -c %y "$latest_scan" | cut -d'.' -f1)
        local critical_vulns=0
        local high_vulns=0
        local medium_vulns=0
        local low_vulns=0
        
        # Extrair contadores do relatório
        if grep -q "CRÍTICAS:" "$latest_scan"; then
            critical_vulns=$(grep "CRÍTICAS:" "$latest_scan" | awk '{print $2}' || echo "0")
        fi
        
        if grep -q "ALTAS:" "$latest_scan"; then
            high_vulns=$(grep "ALTAS:" "$latest_scan" | awk '{print $2}' || echo "0")
        fi
        
        if grep -q "MÉDIAS:" "$latest_scan"; then
            medium_vulns=$(grep "MÉDIAS:" "$latest_scan" | awk '{print $2}' || echo "0")
        fi
        
        if grep -q "BAIXAS:" "$latest_scan"; then
            low_vulns=$(grep "BAIXAS:" "$latest_scan" | awk '{print $2}' || echo "0")
        fi
        
        cat > "$scan_file" << EOF
{
  "last_scan": "$scan_date",
  "vulnerabilities": {
    "critical": $critical_vulns,
    "high": $high_vulns,
    "medium": $medium_vulns,
    "low": $low_vulns,
    "total": $((critical_vulns + high_vulns + medium_vulns + low_vulns))
  },
  "scan_file": "$latest_scan"
}
EOF
    else
        cat > "$scan_file" << EOF
{
  "last_scan": "Nunca executado",
  "vulnerabilities": {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
    "total": 0
  },
  "scan_file": null
}
EOF
    fi
}

# Obter informações do ambiente
get_environment_info() {
    log "INFO" "Coletando informações do ambiente..."
    
    local env_file="$PROJECT_ROOT/tmp/environment_info.json"
    local last_backup="N/A"
    local next_backup="N/A"
    local secrets_rotation="N/A"
    
    # Último backup
    local latest_backup=$(find "$PROJECT_ROOT/backups" -name "*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | \
                          sort -n | tail -1 | cut -d' ' -f2- || echo "")
    
    if [[ -n "$latest_backup" ]]; then
        last_backup=$(stat -c %y "$latest_backup" | cut -d'.' -f1)
    fi
    
    # Informações específicas do ambiente
    local cloud_provider="Local"
    local resource_group="N/A"
    
    case "$ENVIRONMENT" in
        "dev"|"staging")
            cloud_provider="Azure"
            resource_group="promata-$ENVIRONMENT-rg"
            ;;
        "prod")
            cloud_provider="AWS"
            resource_group="promata-prod"
            ;;
    esac
    
    cat > "$env_file" << EOF
{
  "environment": "$ENVIRONMENT",
  "cloud_provider": "$cloud_provider",
  "resource_group": "$resource_group",
  "last_backup": "$last_backup",
  "next_backup": "$next_backup",
  "secrets_rotation": "$secrets_rotation",
  "monitoring_active": $(pgrep -f "security-monitor.sh" >/dev/null && echo "true" || echo "false"),
  "system_info": {
    "hostname": "$(hostname)",
    "os": "$(uname -o 2>/dev/null || uname)",
    "kernel": "$(uname -r)",
    "architecture": "$(uname -m)"
  }
}
EOF
}

# Coletar logs recentes
collect_recent_logs() {
    log "INFO" "Coletando logs recentes..."
    
    local logs_file="$PROJECT_ROOT/tmp/recent_logs.json"
    echo '{"logs": [' > "$logs_file"
    
    local log_count=0
    local max_logs=20
    
    # Coletar de vários arquivos de log
    local log_sources=(
        "$PROJECT_ROOT/logs/security-monitor-*.log"
        "$PROJECT_ROOT/logs/security-scan-*.log"
        "$PROJECT_ROOT/logs/security-audit-*.log"
        "/var/log/auth.log"
        "/var/log/syslog"
    )
    
    for log_pattern in "${log_sources[@]}"; do
        for log_file in $log_pattern; do
            if [[ -f "$log_file" ]] && [[ -r "$log_file" ]]; then
                # Últimas 5 linhas de cada log
                tail -5 "$log_file" 2>/dev/null | while IFS= read -r line; do
                    if [[ -n "$line" ]] && [[ $log_count -lt $max_logs ]]; then
                        local log_type="info"
                        local log_source=$(basename "$log_file")
                        
                        # Determinar tipo do log
                        if [[ "$line" =~ ERROR|CRITICAL ]]; then
                            log_type="error"
                        elif [[ "$line" =~ WARN|WARNING ]]; then
                            log_type="warning"
                        elif [[ "$line" =~ SUCCESS|OK ]]; then
                            log_type="success"
                        fi
                        
                        if [[ $log_count -gt 0 ]]; then
                            echo "," >> "$logs_file"
                        fi
                        
                        # Escapar JSON
                        local escaped_line=$(echo "$line" | sed 's/"/\\"/g' | sed "s/'/\\'/g")
                        
                        cat >> "$logs_file" << EOF
    {
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
      "level": "$log_type",
      "message": "$escaped_line",
      "source": "$log_source"
    }
EOF
                        ((log_count++))
                    fi
                done
                
                if [[ $log_count -ge $max_logs ]]; then
                    break
                fi
            fi
        done
        
        if [[ $log_count -ge $max_logs ]]; then
            break
        fi
    done
    
    # Se não há logs, adicionar entrada padrão
    if [[ $log_count -eq 0 ]]; then
        cat >> "$logs_file" << EOF
    {
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
      "level": "info",
      "message": "Sistema de monitoramento iniciado",
      "source": "security-system"
    }
EOF
    fi
    
    echo ']}' >> "$logs_file"
}

# Gerar dashboard HTML dinâmico
generate_dashboard_html() {
    log "INFO" "Gerando dashboard HTML..."
    
    # Verificar se temos dados coletados
    mkdir -p "$PROJECT_ROOT/tmp"
    
    collect_system_metrics
    collect_recent_alerts
    check_services_status
    get_scan_results
    get_environment_info
    collect_recent_logs
    
    # Ler dados dos arquivos temporários
    local system_data=""
    local alerts_data=""
    local services_data=""
    local scan_data=""
    local env_data=""
    local logs_data=""
    
    if [[ -f "$PROJECT_ROOT/tmp/system_metrics.json" ]]; then
        system_data=$(cat "$PROJECT_ROOT/tmp/system_metrics.json")
    fi
    
    if [[ -f "$PROJECT_ROOT/tmp/recent_alerts.json" ]]; then
        alerts_data=$(cat "$PROJECT_ROOT/tmp/recent_alerts.json")
    fi
    
    if [[ -f "$PROJECT_ROOT/tmp/services_status.json" ]]; then
        services_data=$(cat "$PROJECT_ROOT/tmp/services_status.json")
    fi
    
    if [[ -f "$PROJECT_ROOT/tmp/scan_results.json" ]]; then
        scan_data=$(cat "$PROJECT_ROOT/tmp/scan_results.json")
    fi
    
    if [[ -f "$PROJECT_ROOT/tmp/environment_info.json" ]]; then
        env_data=$(cat "$PROJECT_ROOT/tmp/environment_info.json")
    fi
    
    if [[ -f "$PROJECT_ROOT/tmp/recent_logs.json" ]]; then
        logs_data=$(cat "$PROJECT_ROOT/tmp/recent_logs.json")
    fi
    
    # Usar o dashboard estático como base e injetar dados
    if [[ -f "$STATIC_DASHBOARD" ]]; then
        cp "$STATIC_DASHBOARD" "$DASHBOARD_FILE"
    else
        log "WARN" "Dashboard estático não encontrado, usando template básico"
        create_basic_dashboard_template
    fi
    
    # Injetar script de dados dinâmicos
    local data_script="
<script id=\"dynamic-data\">
// Dados dinâmicos coletados em $(date)
window.proMataSecurityData = {
    system: $system_data,
    alerts: $alerts_data,
    services: $services_data,
    scan: $scan_data,
    environment: $env_data,
    logs: $logs_data,
    lastUpdate: '$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'
};

// Função para atualizar o dashboard com dados reais
function updateDashboardWithRealData() {
    const data = window.proMataSecurityData;
    
    // Atualizar métricas de sistema
    if (data.system) {
        document.getElementById('cpu-usage').textContent = data.system.cpu_usage + '%';
        document.getElementById('memory-usage').textContent = data.system.memory_usage + '%';
        document.getElementById('disk-usage').textContent = data.system.disk_usage + '%';
        document.getElementById('network-connections').textContent = data.system.network_connections;
        
        // Atualizar barras de progresso
        document.querySelector('#cpu-usage').parentNode.querySelector('.progress-fill').style.width = data.system.cpu_usage + '%';
        document.querySelector('#memory-usage').parentNode.querySelector('.progress-fill').style.width = data.system.memory_usage + '%';
        document.querySelector('#disk-usage').parentNode.querySelector('.progress-fill').style.width = data.system.disk_usage + '%';
    }
    
    // Atualizar alertas
    if (data.alerts && data.alerts.alerts) {
        const alertsContainer = document.getElementById('recent-alerts');
        if (alertsContainer) {
            alertsContainer.innerHTML = '';
            
            data.alerts.alerts.slice(0, 5).forEach(alert => {
                const alertDiv = document.createElement('div');
                alertDiv.className = `alert-item ${alert.severity}`;

                // Severity
                const severityDiv = document.createElement('div');
                severityDiv.className = `alert-severity ${alert.severity}`;
                severityDiv.textContent = alert.severity.toUpperCase();
                alertDiv.appendChild(severityDiv);

                // Message and recommendation
                const messageDiv = document.createElement('div');
                messageDiv.className = 'alert-message';
                const strong = document.createElement('strong');
                strong.textContent = alert.message;
                messageDiv.appendChild(strong);
                messageDiv.appendChild(document.createElement('br'));
                const recommendationSpan = document.createElement('span');
                recommendationSpan.textContent = alert.recommendation;
                messageDiv.appendChild(recommendationSpan);
                alertDiv.appendChild(messageDiv);

                // Time
                const timeDiv = document.createElement('div');
                timeDiv.className = 'alert-time';
                timeDiv.textContent = `há ${getTimeAgo(alert.timestamp)}`;
                alertDiv.appendChild(timeDiv);
                alertsContainer.appendChild(alertDiv);
            });
        }
        
        // Atualizar contadores de alertas
        const criticalCount = data.alerts.alerts.filter(a => a.severity === 'critical').length;
        const highCount = data.alerts.alerts.filter(a => a.severity === 'high').length;
        
        if (document.getElementById('critical-alerts')) {
            document.getElementById('critical-alerts').textContent = criticalCount;
        }
        if (document.getElementById('high-alerts')) {
            document.getElementById('high-alerts').textContent = highCount;
        }
    }
    
    // Atualizar status dos serviços
    if (data.services && data.services.services) {
        const servicesContainer = document.getElementById('services-status');
        if (servicesContainer) {
            servicesContainer.innerHTML = '';
            
            data.services.services.forEach(service => {
                const statusClass = service.status === 'online' ? 'online' : 'offline';
                const serviceDiv = document.createElement('div');
                serviceDiv.style.marginBottom = '15px';
                serviceDiv.innerHTML = \`
                    <span class=\"status-indicator \${statusClass}\"></span>
                    <strong>\${service.name}</strong> - \${service.status === 'online' ? 'Saudável' : 'Indisponível'}
                    <small style=\"float: right; color: #999;\">\${service.response_time}</small>
                \`;
                servicesContainer.appendChild(serviceDiv);
            });
        }
    }
    
    // Atualizar informações do ambiente
    if (data.environment) {
        const envElement = document.getElementById('current-environment');
        if (envElement) {
            let envColor = '🟡';
            if (data.environment.environment === 'staging') envColor = '🟢';
            if (data.environment.environment === 'prod') envColor = '🔴';
            
            envElement.textContent = \`\${envColor} \${data.environment.environment.toUpperCase()}\`;
        }
    }
    
    // Atualizar logs
    if (data.logs && data.logs.logs) {
        const logsContainer = document.getElementById('security-logs');
        if (logsContainer) {
            logsContainer.innerHTML = '';
            
            data.logs.logs.slice(-15).forEach(log => {
                const logDiv = document.createElement('div');
                logDiv.className = \`log-entry \${log.level}\`;
                logDiv.textContent = \`[\${new Date(log.timestamp).toLocaleString('pt-BR')}] \${log.message}\`;
                logsContainer.appendChild(logDiv);
            });
            
            logsContainer.scrollTop = logsContainer.scrollHeight;
        }
    }
    
    // Atualizar timestamp da última atualização
    if (document.getElementById('last-scan')) {
        document.getElementById('last-scan').textContent = new Date(data.lastUpdate).toLocaleTimeString('pt-BR', {
            hour: '2-digit',
            minute: '2-digit'
        });
    }
}

// Função auxiliar para calcular tempo relativo
function getTimeAgo(timestamp) {
    const now = Date.now();
    const then = typeof timestamp === 'string' ? Date.parse(timestamp) : timestamp * 1000;
    const diff = now - then;
    
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);
    
    if (days > 0) return \`\${days} dia\${days > 1 ? 's' : ''}\`;
    if (hours > 0) return \`\${hours} hora\${hours > 1 ? 's' : ''}\`;
    if (minutes > 0) return \`\${minutes} min\`;
    return 'agora';
}

// Atualizar dashboard quando a página carregar
document.addEventListener('DOMContentLoaded', function() {
    updateDashboardWithRealData();
    
    // Auto-atualização a cada 30 segundos
    setInterval(function() {
        // Em produção, isso faria uma chamada AJAX para buscar novos dados
        console.log('Auto-refresh would update data here');
    }, 30000);
});
</script>
"
    
    # Injetar o script antes do fechamento do body
    if grep -q "</body>" "$DASHBOARD_FILE"; then
        sed -i "s|</body>|$data_script</body>|" "$DASHBOARD_FILE"
    else
        echo "$data_script" >> "$DASHBOARD_FILE"
    fi
    
    log "SUCCESS" "Dashboard HTML gerado: $DASHBOARD_FILE"
}

# Criar template básico se não existir
create_basic_dashboard_template() {
    cat > "$DASHBOARD_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pro-Mata Security Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 30px; }
        .dashboard-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .widget { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: flex; justify-content: space-between; margin-bottom: 10px; }
        .alert-item { padding: 10px; margin-bottom: 10px; border-radius: 4px; }
        .critical { background: #ffe6e6; border-left: 4px solid #e74c3c; }
        .high { background: #fff3e0; border-left: 4px solid #ff9800; }
        .medium { background: #fff8e1; border-left: 4px solid #ffc107; }
        .logs { background: #1e1e1e; color: #00ff00; padding: 15px; height: 200px; overflow-y: auto; font-family: monospace; }
        .status-indicator { display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 8px; }
        .online { background: #4caf50; }
        .offline { background: #f44336; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 Pro-Mata Security Dashboard</h1>
            <p>Sistema de Monitoramento de Segurança</p>
        </div>
        
        <div class="dashboard-grid">
            <div class="widget">
                <h3>📊 Métricas do Sistema</h3>
                <div class="metric">
                    <span>CPU:</span>
                    <span id="cpu-usage">0%</span>
                </div>
                <div class="metric">
                    <span>Memória:</span>
                    <span id="memory-usage">0%</span>
                </div>
                <div class="metric">
                    <span>Disco:</span>
                    <span id="disk-usage">0%</span>
                </div>
                <div class="metric">
                    <span>Conexões:</span>
                    <span id="network-connections">0</span>
                </div>
            </div>
            
            <div class="widget">
                <h3>🚨 Alertas Recentes</h3>
                <div id="recent-alerts">
                    <div class="alert-item">Carregando alertas...</div>
                </div>
            </div>
            
            <div class="widget">
                <h3>⚙️ Status dos Serviços</h3>
                <div id="services-status">
                    <div>Carregando status...</div>
                </div>
            </div>
            
            <div class="widget">
                <h3>📝 Logs de Segurança</h3>
                <div id="security-logs" class="logs">
                    Carregando logs...
                </div>
            </div>
            
            <div class="widget">
                <h3>🌍 Ambiente</h3>
                <div id="current-environment">🟡 CARREGANDO</div>
                <p>Última atualização: <span id="last-scan">--</span></p>
            </div>
            
            <div class="widget">
                <h3>📈 Status Geral</h3>
                <div class="metric">
                    <span>Alertas Críticos:</span>
                    <span id="critical-alerts">0</span>
                </div>
                <div class="metric">
                    <span>Alertas Altos:</span>
                    <span id="high-alerts">0</span>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
EOF
}

# Servir dashboard via HTTP
serve_dashboard() {
    log "INFO" "Servindo dashboard na porta $PORT..."
    
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        log "ERROR" "Python não encontrado para servir o dashboard"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    
    # Tentar Python 3 primeiro, depois Python 2
    if command -v python3 &> /dev/null; then
        log "INFO" "Iniciando servidor Python 3..."
        python3 -m http.server "$PORT" 2>/dev/null || python3 -m SimpleHTTPServer "$PORT"
    elif command -v python &> /dev/null; then
        log "INFO" "Iniciando servidor Python 2..."
        python -m SimpleHTTPServer "$PORT"
    fi
}

# Abrir dashboard no navegador
open_dashboard() {
    local url
    
    if [[ "$SERVE_MODE" == "true" ]]; then
        url="http://localhost:$PORT/dashboard.html"
        log "INFO" "Dashboard disponível em: $url"
    else
        url="file://$DASHBOARD_FILE"
        log "INFO" "Abrindo dashboard local: $url"
    fi
    
    # Tentar abrir no navegador
    if command -v xdg-open &> /dev/null; then
        xdg-open "$url" &>/dev/null &
    elif command -v open &> /dev/null; then
        open "$url" &>/dev/null &
    elif command -v start &> /dev/null; then
        start "$url" &>/dev/null &
    else
        log "INFO" "Abra manualmente o dashboard em: $url"
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
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -s|--serve)
                SERVE_MODE=true
                shift
                ;;
            -o|--open)
                AUTO_OPEN=true
                shift
                ;;
            -u|--update-only)
                UPDATE_ONLY=true
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

# Função principal
main() {
    echo -e "${BLUE}"
    echo "📊 Pro-Mata Security Dashboard Generator"
    echo "======================================="
    echo -e "${NC}"
    
    parse_arguments "$@"
    
    log "INFO" "Gerando dashboard para ambiente: $ENVIRONMENT"
    
    if [[ "$UPDATE_ONLY" == "true" ]]; then
        log "INFO" "Modo atualização - apenas coletando dados"
        mkdir -p "$PROJECT_ROOT/tmp"
        collect_system_metrics
        collect_recent_alerts
        check_services_status
        get_scan_results
        get_environment_info
        collect_recent_logs
        log "SUCCESS" "Dados atualizados em $PROJECT_ROOT/tmp/"
        return 0
    fi
    
    # Gerar dashboard
    generate_dashboard_html
    
    if [[ "$SERVE_MODE" == "true" ]]; then
        if [[ "$AUTO_OPEN" == "true" ]]; then
            # Abrir depois de um delay para dar tempo do servidor iniciar
            (sleep 2 && open_dashboard) &
        fi
        serve_dashboard
    else
        if [[ "$AUTO_OPEN" == "true" ]]; then
            open_dashboard
        fi
        log "SUCCESS" "Dashboard gerado com sucesso!"
        log "INFO" "Arquivo: $DASHBOARD_FILE"
    fi
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi