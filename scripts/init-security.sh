#!/bin/bash

# scripts/init-security.sh
# Script de inicialização do sistema de segurança Pro-Mata
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
VERBOSE=false
FORCE=false
SKIP_DEPENDENCIES=false
ENVIRONMENT="dev"

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
${BLUE}Pro-Mata Security System Initializer${NC}

Inicializa e configura o sistema completo de segurança Pro-Mata

${YELLOW}Uso:${NC} $0 [OPÇÕES]

${YELLOW}OPÇÕES:${NC}
  -e, --environment ENV    Ambiente inicial (dev|staging|prod) [default: dev]
  -v, --verbose           Output detalhado
  -f, --force             Forçar reinicialização (sobrescrever configurações)
  --skip-deps            Pular instalação de dependências
  -h, --help             Mostrar esta ajuda

${YELLOW}EXEMPLOS:${NC}
  $0                              # Inicialização padrão (dev)
  $0 --environment staging        # Inicializar para staging
  $0 --force --verbose           # Reinicialização completa com logs detalhados

${YELLOW}O QUE SERÁ CONFIGURADO:${NC}
  ✅ Estrutura de diretórios
  ✅ Arquivos de configuração
  ✅ Dependências do sistema
  ✅ Scripts de segurança
  ✅ Monitoramento básico
  ✅ Dashboard de segurança
  ✅ Templates de configuração

EOF
}

# Verificar se está rodando como root
check_root() {
    if [[ $EUID -eq 0 ]] && [[ "$FORCE" != "true" ]]; then
        log "WARN" "Executando como root não é recomendado para inicialização"
        echo -e "${YELLOW}Deseja continuar mesmo assim? [y/N]${NC}"
        read -r confirmation
        if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
            log "INFO" "Inicialização cancelada"
            exit 0
        fi
    fi
}

# Criar estrutura de diretórios
create_directory_structure() {
    log "INFO" "Criando estrutura de diretórios..."
    
    local directories=(
        "logs"
        "reports/security"
        "reports/security-scan"
        "reports/audit"
        "security"
        "security/templates"
        "security/keys"
        "monitoring"
        "backups"
        "backups/secrets"
        "backups/config"
        "tmp/security"
    )
    
    for dir in "${directories[@]}"; do
        local full_path="$PROJECT_ROOT/$dir"
        
        if [[ ! -d "$full_path" ]]; then
            mkdir -p "$full_path"
            log "SUCCESS" "Diretório criado: $dir"
        else
            log "INFO" "Diretório já existe: $dir"
        fi
        
        # Definir permissões apropriadas
        case "$dir" in
            "security/keys"|"backups/secrets")
                chmod 700 "$full_path" 2>/dev/null || true
                ;;
            "logs"|"tmp/security")
                chmod 755 "$full_path" 2>/dev/null || true
                ;;
            *)
                chmod 755 "$full_path" 2>/dev/null || true
                ;;
        esac
    done
    
    log "SUCCESS" "Estrutura de diretórios criada"
}

# Instalar dependências do sistema
install_dependencies() {
    if [[ "$SKIP_DEPENDENCIES" == "true" ]]; then
        log "INFO" "Pulando instalação de dependências"
        return
    fi
    
    log "INFO" "Verificando e instalando dependências..."
    
    local required_packages=(
        "curl"
        "jq"
        "openssl"
        "docker.io"
        "docker-compose"
    )
    
    local missing_packages=()
    
    # Verificar pacotes instalados
    for package in "${required_packages[@]}"; do
        if ! command -v "${package%.*}" &> /dev/null && ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        log "SUCCESS" "Todas as dependências já estão instaladas"
        return
    fi
    
    log "INFO" "Instalando pacotes em falta: ${missing_packages[*]}"
    
    # Tentar instalação automática (Ubuntu/Debian)
    if command -v apt-get &> /dev/null; then
        if [[ $EUID -eq 0 ]]; then
            apt-get update -qq
            apt-get install -y "${missing_packages[@]}"
        else
            log "WARN" "Privilégios de administrador necessários para instalar dependências"
            log "INFO" "Execute: sudo apt-get install ${missing_packages[*]}"
            echo -e "${YELLOW}Deseja continuar sem instalar as dependências? [y/N]${NC}"
            read -r confirmation
            if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    elif command -v yum &> /dev/null; then
        if [[ $EUID -eq 0 ]]; then
            yum install -y "${missing_packages[@]}"
        else
            log "WARN" "Execute: sudo yum install ${missing_packages[*]}"
        fi
    else
        log "WARN" "Sistema de pacotes não identificado. Instale manualmente: ${missing_packages[*]}"
    fi
}

# Criar arquivos de configuração
create_config_files() {
    log "INFO" "Criando arquivos de configuração..."
    
    # Arquivo de configuração principal do sistema de segurança
    create_main_security_config
    
    # Template de configuração de ambiente
    create_environment_template
    
    # Configuração de monitoramento
    create_monitoring_config
    
    # Configuração de alertas
    create_alerts_config
    
    log "SUCCESS" "Arquivos de configuração criados"
}

# Configuração principal de segurança
create_main_security_config() {
    local config_file="$PROJECT_ROOT/security/security-config.yml"
    
    if [[ -f "$config_file" ]] && [[ "$FORCE" != "true" ]]; then
        log "INFO" "Configuração principal já existe: $(basename "$config_file")"
        return
    fi
    
    cat > "$config_file" << 'EOF'
# Configuração Principal do Sistema de Segurança Pro-Mata
# Arquivo: security/security-config.yml

system:
  name: "Pro-Mata Security System"
  version: "1.0.0"
  environment: "dev"  # dev|staging|prod
  
monitoring:
  enabled: true
  interval: 30  # segundos
  log_level: "INFO"  # DEBUG|INFO|WARN|ERROR
  retention_days: 30
  
  alerts:
    discord_webhook: ""
    email_notifications: false
    slack_integration: false
    
    thresholds:
      critical: 1
      high: 5
      medium: 10

scanning:
  enabled: true
  schedule: "0 2 * * *"  # Diário às 2h
  types:
    - "containers"
    - "images"
    - "dependencies"
    - "network"
    - "infrastructure"
  
  retention:
    reports: 90  # dias
    scan_data: 30  # dias

secrets:
  rotation:
    enabled: true
    schedule:
      database: 30  # dias
      api_keys: 90  # dias
      jwt: 7  # dias
      ssl: 365  # dias
  
  backup:
    enabled: true
    retention: 5  # backups
    encryption: true

compliance:
  enabled: true
  standards:
    - "OWASP"
    - "CIS"
  
  checks:
    - "password_policy"
    - "ssl_configuration" 
    - "firewall_rules"
    - "file_permissions"
    - "user_access"

reporting:
  enabled: true
  formats:
    - "html"
    - "json"
    - "pdf"
  
  schedule: "0 6 * * 1"  # Segunda-feira às 6h
  recipients:
    - "security@promata.ages.pucrs.br"

dashboard:
  enabled: true
  port: 8080
  auth_required: false  # Para desenvolvimento
  auto_refresh: 30  # segundos
EOF
    
    chmod 644 "$config_file"
    log "SUCCESS" "Configuração principal criada: $(basename "$config_file")"
}

# Template de configuração de ambiente
create_environment_template() {
    local template_file="$PROJECT_ROOT/security/templates/environment.env.template"
    
    cat > "$template_file" << 'EOF'
# Template de Configuração de Ambiente - Pro-Mata Security
# Copie para .env.security e ajuste os valores

# Configurações Gerais
ENVIRONMENT=dev
VERBOSE=false
DRY_RUN=false

# Configurações de Monitoramento
MONITOR_INTERVAL=30
MONITOR_DURATION=""
ALERT_THRESHOLD_CRITICAL=1
ALERT_THRESHOLD_HIGH=5

# Configurações de Scan
SCAN_TYPE=all
FAIL_ON_CRITICAL=true
OUTPUT_FORMAT=text

# Configurações de Notificação
DISCORD_WEBHOOK_URL=""
SLACK_WEBHOOK_URL=""
EMAIL_SMTP_HOST=""
EMAIL_SMTP_PORT=587
EMAIL_FROM=""
EMAIL_TO=""

# Configurações Cloud
# Azure (dev/staging)
AZURE_SUBSCRIPTION_ID=""
AZURE_TENANT_ID=""
AZURE_CLIENT_ID=""
AZURE_CLIENT_SECRET=""

# AWS (prod)
AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
AWS_REGION=us-east-1

# Configurações de Backup
BACKUP_RETENTION_DAYS=30
BACKUP_ENCRYPTION_KEY=""

# Configurações de Dashboard
DASHBOARD_PORT=8080
DASHBOARD_AUTH=false
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=""

# Configurações de Banco (para testes de conectividade)
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=promata
DATABASE_USER=promata
DATABASE_PASSWORD=""

# Configurações de Cache Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=""
EOF
    
    chmod 644 "$template_file"
    log "SUCCESS" "Template de ambiente criado: $(basename "$template_file")"
}

# Configuração de monitoramento
create_monitoring_config() {
    local monitor_config="$PROJECT_ROOT/monitoring/monitor-config.json"
    
    cat > "$monitor_config" << 'EOF'
{
  "monitoring": {
    "enabled": true,
    "interval": 30,
    "checks": {
      "login_attempts": {
        "enabled": true,
        "threshold": 5,
        "window": 300
      },
      "file_changes": {
        "enabled": true,
        "paths": [
          "/etc/passwd",
          "/etc/shadow",
          "/etc/ssh/sshd_config",
          "/etc/nginx/nginx.conf"
        ]
      },
      "processes": {
        "enabled": true,
        "suspicious_patterns": [
          "nc.*-l",
          "ncat.*-l",
          "socat",
          "wget.*http.*sh",
          "curl.*|.*sh"
        ]
      },
      "network": {
        "enabled": true,
        "max_connections_per_ip": 50,
        "expected_ports": [22, 80, 443, 3000, 5000, 5432, 6379]
      },
      "resources": {
        "enabled": true,
        "thresholds": {
          "cpu": 90,
          "memory": 90,
          "disk": 85
        }
      }
    },
    "alerts": {
      "cooldown": 300,
      "channels": {
        "discord": {
          "enabled": false,
          "webhook_url": ""
        },
        "email": {
          "enabled": false,
          "smtp_host": "",
          "smtp_port": 587,
          "from": "",
          "to": []
        },
        "slack": {
          "enabled": false,
          "webhook_url": ""
        }
      }
    },
    "logging": {
      "level": "INFO",
      "retention_days": 30,
      "max_log_size": "100MB"
    }
  }
}
EOF
    
    chmod 644 "$monitor_config"
    log "SUCCESS" "Configuração de monitoramento criada: $(basename "$monitor_config")"
}

# Configuração de alertas
create_alerts_config() {
    local alerts_config="$PROJECT_ROOT/security/alerts-rules.yml"
    
    cat > "$alerts_config" << 'EOF'
# Regras de Alertas de Segurança Pro-Mata
# Arquivo: security/alerts-rules.yml

alerts:
  # Alertas Críticos
  critical:
    - name: "container_privileged"
      description: "Container rodando em modo privilegiado"
      condition: "privileged_container_detected"
      action: "immediate_notification"
      
    - name: "critical_vulnerability"
      description: "Vulnerabilidade crítica encontrada"
      condition: "critical_cve_detected"
      action: "immediate_notification"
      
    - name: "ssl_expired"
      description: "Certificado SSL expirado"
      condition: "ssl_cert_expired"
      action: "immediate_notification"
      
    - name: "brute_force_attack"
      description: "Possível ataque de força bruta"
      condition: "failed_logins > 20 in 5min"
      action: "immediate_notification"

  # Alertas Altos
  high:
    - name: "high_vulnerability"
      description: "Vulnerabilidade alta encontrada"
      condition: "high_cve_detected"
      action: "notification_with_delay"
      
    - name: "suspicious_process"
      description: "Processo suspeito detectado"
      condition: "suspicious_binary_executed"
      action: "notification_with_delay"
      
    - name: "ssl_expiring_soon"
      description: "Certificado SSL expira em breve"
      condition: "ssl_cert_expires_in < 7days"
      action: "notification_with_delay"
      
    - name: "high_resource_usage"
      description: "Alto uso de recursos do sistema"
      condition: "cpu > 95% OR memory > 95% OR disk > 95%"
      action: "notification_with_delay"

  # Alertas Médios
  medium:
    - name: "medium_vulnerability"
      description: "Vulnerabilidade média encontrada"
      condition: "medium_cve_detected"
      action: "daily_summary"
      
    - name: "config_file_changed"
      description: "Arquivo de configuração crítico alterado"
      condition: "critical_file_modified"
      action: "notification_with_delay"
      
    - name: "unusual_network_activity"
      description: "Atividade de rede incomum"
      condition: "unexpected_connections OR new_listening_ports"
      action: "notification_with_delay"

  # Configurações de Ação
  actions:
    immediate_notification:
      channels: ["discord", "email", "slack"]
      delay: 0
      repeat: false
      
    notification_with_delay:
      channels: ["discord", "email"]
      delay: 300  # 5 minutos
      repeat: false
      
    daily_summary:
      channels: ["email"]
      delay: 0
      schedule: "0 8 * * *"  # 8h da manhã

# Configurações de Rate Limiting
rate_limiting:
  enabled: true
  rules:
    - alert_type: "critical"
      max_per_hour: 10
      max_per_day: 50
      
    - alert_type: "high"
      max_per_hour: 20
      max_per_day: 100
      
    - alert_type: "medium"
      max_per_hour: 50
      max_per_day: 200

# Configurações de Escalação
escalation:
  enabled: true
  rules:
    - condition: "critical_alerts > 5 in 1hour"
      action: "escalate_to_management"
      
    - condition: "system_compromise_detected"
      action: "emergency_response"
      
    - condition: "multiple_services_down"
      action: "escalate_to_oncall"
EOF
    
    chmod 644 "$alerts_config"
    log "SUCCESS" "Configuração de alertas criada: $(basename "$alerts_config")"
}

# Configurar permissões de arquivos
set_file_permissions() {
    log "INFO" "Configurando permissões de arquivos..."
    
    # Scripts executáveis
    local scripts_dir="$PROJECT_ROOT/scripts"
    if [[ -d "$scripts_dir" ]]; then
        find "$scripts_dir" -name "*.sh" -exec chmod +x {} \;
        log "SUCCESS" "Permissões de scripts configuradas"
    fi
    
    # Diretórios sensíveis
    local sensitive_dirs=(
        "security/keys"
        "backups/secrets"
    )
    
    for dir in "${sensitive_dirs[@]}"; do
        local full_path="$PROJECT_ROOT/$dir"
        if [[ -d "$full_path" ]]; then
            chmod 700 "$full_path"
            log "SUCCESS" "Permissões restritivas aplicadas: $dir"
        fi
    done
    
    # Arquivos de configuração
    find "$PROJECT_ROOT/security" -name "*.yml" -exec chmod 644 {} \; 2>/dev/null || true
    find "$PROJECT_ROOT/security" -name "*.json" -exec chmod 644 {} \; 2>/dev/null || true
}

# Criar scripts auxiliares
create_helper_scripts() {
    log "INFO" "Criando scripts auxiliares..."
    
    # Script de start rápido
    create_quick_start_script
    
    # Script de status do sistema
    create_status_script
    
    # Script de limpeza
    create_cleanup_script
    
    log "SUCCESS" "Scripts auxiliares criados"
}

# Script de start rápido
create_quick_start_script() {
    local quick_start="$PROJECT_ROOT/scripts/quick-start.sh"
    
    cat > "$quick_start" << 'EOF'
#!/bin/bash

# quick-start.sh - Inicialização rápida do sistema de segurança Pro-Mata

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
        "$SCRIPT_DIR/security-audit.sh" --environment dev --compliance-check
        ;;
    0)
        echo "👋 Até logo!"
        ;;
    *)
        echo "❌ Opção inválida"
        ;;
esac
EOF
    
    chmod +x "$quick_start"
    log "SUCCESS" "Script quick-start criado"
}

# Script de status do sistema
create_status_script() {
    local status_script="$PROJECT_ROOT/scripts/security-status.sh"
    
    cat > "$status_script" << 'EOF'
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
EOF
    
    chmod +x "$status_script"
    log "SUCCESS" "Script de status criado"
}

# Script de limpeza
create_cleanup_script() {
    local cleanup_script="$PROJECT_ROOT/scripts/security-cleanup.sh"
    
    cat > "$cleanup_script" << 'EOF'
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
EOF
    
    chmod +x "$cleanup_script"
    log "SUCCESS" "Script de limpeza criado"
}

# Verificar e corrigir configuração do Docker
setup_docker() {
    log "INFO" "Configurando Docker para uso de segurança..."
    
    # Verificar se Docker está rodando
    if ! docker info &>/dev/null; then
        log "WARN" "Docker não está rodando ou não está instalado"
        return
    fi
    
    # Verificar se usuário está no grupo docker
    if ! groups | grep -q docker; then
        log "WARN" "Usuário atual não está no grupo docker"
        if [[ $EUID -ne 0 ]]; then
            log "INFO" "Execute: sudo usermod -aG docker $USER"
            log "INFO" "Depois faça logout/login para aplicar as mudanças"
        fi
    fi
    
    # Criar network de segurança se não existir
    if ! docker network ls | grep -q "promata-security"; then
        docker network create promata-security 2>/dev/null || true
        log "SUCCESS" "Rede Docker de segurança criada"
    fi
    
    log "SUCCESS" "Configuração Docker verificada"
}

# Criar arquivo de ambiente inicial
create_initial_env() {
    local env_file="$PROJECT_ROOT/.env.security"
    
    if [[ -f "$env_file" ]] && [[ "$FORCE" != "true" ]]; then
        log "INFO" "Arquivo de ambiente já existe: .env.security"
        return
    fi
    
    log "INFO" "Criando arquivo de ambiente inicial..."
    
    cp "$PROJECT_ROOT/security/templates/environment.env.template" "$env_file"
    
    # Configurar valores básicos para o ambiente especificado
    sed -i "s/ENVIRONMENT=dev/ENVIRONMENT=$ENVIRONMENT/" "$env_file"
    
    # Gerar senha padrão do dashboard
    local dashboard_password=$(openssl rand -base64 12)
    sed -i "s/DASHBOARD_PASSWORD=\"\"/DASHBOARD_PASSWORD=\"$dashboard_password\"/" "$env_file"
    
    chmod 600 "$env_file"
    
    log "SUCCESS" "Arquivo .env.security criado"
    log "INFO" "Senha do dashboard gerada: $dashboard_password"
    log "WARN" "Revise e configure o arquivo .env.security antes de usar em produção"
}

# Executar testes básicos
run_basic_tests() {
    log "INFO" "Executando testes básicos do sistema..."
    
    local tests_passed=0
    local tests_total=5
    
    # Teste 1: Scripts executáveis
    if [[ -x "$PROJECT_ROOT/scripts/security-scan.sh" ]]; then
        ((tests_passed++))
        log "SUCCESS" "✅ Scripts executáveis"
    else
        log "ERROR" "❌ Scripts não executáveis"
    fi
    
    # Teste 2: Estrutura de diretórios
    if [[ -d "$PROJECT_ROOT/security" ]] && [[ -d "$PROJECT_ROOT/logs" ]]; then
        ((tests_passed++))
        log "SUCCESS" "✅ Estrutura de diretórios"
    else
        log "ERROR" "❌ Estrutura de diretórios incompleta"
    fi
    
    # Teste 3: Arquivos de configuração
    if [[ -f "$PROJECT_ROOT/security/security-config.yml" ]]; then
        ((tests_passed++))
        log "SUCCESS" "✅ Configurações criadas"
    else
        log "ERROR" "❌ Configurações não encontradas"
    fi
    
    # Teste 4: Dependências básicas
    if command -v curl &> /dev/null && command -v jq &> /dev/null; then
        ((tests_passed++))
        log "SUCCESS" "✅ Dependências básicas"
    else
        log "ERROR" "❌ Dependências básicas em falta"
    fi
    
    # Teste 5: Permissões
    if [[ -r "$PROJECT_ROOT/security/security-config.yml" ]]; then
        ((tests_passed++))
        log "SUCCESS" "✅ Permissões configuradas"
    else
        log "ERROR" "❌ Problemas de permissões"
    fi
    
    log "INFO" "Testes: $tests_passed/$tests_total passaram"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        return 0
    else
        return 1
    fi
}

# Mostrar próximos passos
show_next_steps() {
    echo ""
    log "SUCCESS" "🎉 Sistema de segurança Pro-Mata inicializado com sucesso!"
    echo ""
    echo -e "${BLUE}📋 PRÓXIMOS PASSOS:${NC}"
    echo ""
    echo -e "${YELLOW}1. Configurar ambiente:${NC}"
    echo "   ▶ Edite o arquivo: .env.security"
    echo "   ▶ Configure webhooks de notificação"
    echo "   ▶ Defina credenciais cloud (Azure/AWS)"
    echo ""
    echo -e "${YELLOW}2. Comandos disponíveis:${NC}"
    echo "   ▶ make security-check ENVIRONMENT=$ENVIRONMENT"
    echo "   ▶ make security-scan ENVIRONMENT=$ENVIRONMENT"
    echo "   ▶ make security-monitor ENVIRONMENT=$ENVIRONMENT"
    echo "   ▶ ./scripts/quick-start.sh"
    echo ""
    echo -e "${YELLOW}3. Dashboard de segurança:${NC}"
    echo "   ▶ Abra: dashboard.html no navegador"
    echo "   ▶ Ou execute: make security-dashboard"
    echo ""
    echo -e "${YELLOW}4. Documentação:${NC}"
    echo "   ▶ Guia de migração: docs/security-migration-guide.md"
    echo "   ▶ Manual de uso: README.md"
    echo ""
    echo -e "${GREEN}✅ Sistema pronto para uso!${NC}"
    echo ""
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
            -f|--force)
                FORCE=true
                shift
                ;;
            --skip-deps)
                SKIP_DEPENDENCIES=true
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
    echo "██████╗ ██████╗  ██████╗       ███╗   ███╗ █████╗ ████████╗ █████╗ "
    echo "██╔══██╗██╔══██╗██╔═══██╗      ████╗ ████║██╔══██╗╚══██╔══╝██╔══██╗"
    echo "██████╔╝██████╔╝██║   ██║█████╗██╔████╔██║███████║   ██║   ███████║"
    echo "██╔═══╝ ██╔══██╗██║   ██║╚════╝██║╚██╔╝██║██╔══██║   ██║   ██╔══██║"
    echo "██║     ██║  ██║╚██████╔╝      ██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║"
    echo "╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝"
    echo ""
    echo "🔧 Security System Initializer - Configuração Inicial"
    echo -e "${NC}"
    
    parse_arguments "$@"
    
    log "INFO" "Iniciando configuração do sistema de segurança Pro-Mata"
    log "INFO" "Ambiente alvo: $ENVIRONMENT"
    
    check_root
    create_directory_structure
    install_dependencies
    create_config_files
    set_file_permissions
    create_helper_scripts
    setup_docker
    create_initial_env
    
    if run_basic_tests; then
        show_next_steps
        exit 0
    else
        log "ERROR" "Alguns testes falharam. Revise a configuração."
        exit 1
    fi
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi