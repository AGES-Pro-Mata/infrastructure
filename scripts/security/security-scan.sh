#!/bin/bash

# scripts/security-scan.sh
# Script de scan completo de segurança para Pro-Mata
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
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"  # Go up two levels: scripts/security -> scripts -> root
LOG_DIR="$PROJECT_ROOT/logs"
REPORTS_DIR="$PROJECT_ROOT/reports/security-scan"
TEMP_DIR="/tmp/pro-mata-scan-$$"

# Variáveis globais
VERBOSE=false
ENVIRONMENT=""
SCAN_TYPE="all"
DRY_RUN=false
CI_MODE=false
OUTPUT_FORMAT="text"
FAIL_ON_CRITICAL=true

# Contadores de vulnerabilidades
declare -A VULN_COUNT
VULN_COUNT[CRITICAL]=0
VULN_COUNT[HIGH]=0
VULN_COUNT[MEDIUM]=0
VULN_COUNT[LOW]=0
VULN_COUNT[INFO]=0
VULN_COUNT[TOTAL]=0

# Logging
setup_logging() {
    mkdir -p "$LOG_DIR" "$REPORTS_DIR"
    LOG_FILE="$LOG_DIR/security-scan-$(date +%Y%m%d-%H%M%S).log"
    
    if [[ "$CI_MODE" != "true" ]]; then
        exec 1> >(tee -a "$LOG_FILE")
        exec 2> >(tee -a "$LOG_FILE" >&2)
    fi
}

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$CI_MODE" == "true" ]]; then
        case "$level" in
            "ERROR")
                echo "::error::$message"
                ;;
            "WARN")
                echo "::warning::$message"
                ;;
            "INFO"|"SUCCESS")
                echo "::notice::$message"
                ;;
            *)
                echo "$message"
                ;;
        esac
    else
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
            "VULN")
                echo -e "${CYAN}[$timestamp]${NC} ${PURPLE}VULN${NC}: $message"
                ;;
            *)
                echo -e "${CYAN}[$timestamp]${NC} $message"
                ;;
        esac
    fi
}

# Função de ajuda
show_help() {
    cat << EOF
${BLUE}Pro-Mata Security Scanner${NC}

Sistema completo de scan de segurança para infraestrutura Pro-Mata

${YELLOW}Uso:${NC} $0 [OPÇÕES]

${YELLOW}OPÇÕES:${NC}
  -e, --environment ENV    Ambiente (dev|staging|prod)
  -t, --type TYPE         Tipo de scan (all|containers|images|dependencies|network|infrastructure)
  -v, --verbose           Output detalhado
  -d, --dry-run           Simular operações sem executar
  --ci-mode              Modo CI/CD (output formatado para GitHub Actions)
  -f, --format FORMAT     Formato do relatório (text|json|sarif)
  --fail-on-critical      Falhar se vulnerabilidades críticas (default: true)
  --no-fail              Não falhar mesmo com vulnerabilidades críticas
  -h, --help             Mostrar esta ajuda

${YELLOW}TIPOS DE SCAN:${NC}
  all             Scan completo (padrão)
  containers      Scan de containers em execução
  images          Scan de imagens Docker
  dependencies    Scan de dependências vulneráveis
  network         Scan de configurações de rede
  infrastructure  Scan da infraestrutura cloud

${YELLOW}EXEMPLOS:${NC}
  $0 --type images --environment prod
  $0 --full-scan --verbose
  $0 --ci-mode --format sarif
  $0 --type dependencies --no-fail

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

# Adicionar vulnerabilidade encontrada
add_vulnerability() {
    local severity="$1"
    local component="$2"
    local vulnerability="$3"
    local description="$4"
    local fix="$5"
    
    # Use safer arithmetic increment
    VULN_COUNT[$severity]=$((VULN_COUNT[$severity] + 1))
    VULN_COUNT[TOTAL]=$((VULN_COUNT[TOTAL] + 1))
    
    log "VULN" "[$severity] $component: $vulnerability"
    if [[ "$VERBOSE" == "true" ]]; then
        log "INFO" "  Description: $description"
        log "INFO" "  Fix: $fix"
    fi
    
    # Salvar no formato SARIF se necessário
    if [[ "$OUTPUT_FORMAT" == "sarif" ]]; then
        save_sarif_result "$severity" "$component" "$vulnerability" "$description" "$fix"
    fi
}

# Scan de imagens Docker
scan_docker_images() {
    log "INFO" "Iniciando scan de imagens Docker..."
    
    if ! command -v docker &> /dev/null; then
        log "WARN" "Docker não encontrado, pulando scan de imagens"
        return
    fi
    
    # Instalar Trivy se não estiver disponível
    if ! command -v trivy &> /dev/null; then
        log "INFO" "Instalando Trivy..."
        install_trivy
    fi
    
    local images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | head -10)
    
    if [[ -z "$images" ]]; then
        log "INFO" "Nenhuma imagem Docker encontrada para scan"
        return
    fi
    
    while IFS= read -r image; do
        if [[ -n "$image" ]]; then
            log "INFO" "Escaneando imagem: $image"
            scan_single_image "$image"
        fi
    done <<< "$images"
    
    log "SUCCESS" "Scan de imagens Docker concluído"
}

# Instalar Trivy
install_trivy() {
    local os_type=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
    esac
    
    local trivy_version="0.48.0"
    local download_url="https://github.com/aquasecurity/trivy/releases/download/v${trivy_version}/trivy_${trivy_version}_${os_type}_${arch}.tar.gz"
    
    log "INFO" "Baixando Trivy v${trivy_version}..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Trivy seria instalado"
        return
    fi
    
    curl -sL "$download_url" | tar -xz -C "$TEMP_DIR"
    sudo mv "$TEMP_DIR/trivy" /usr/local/bin/ 2>/dev/null || {
        mkdir -p "$HOME/.local/bin"
        mv "$TEMP_DIR/trivy" "$HOME/.local/bin/"
        export PATH="$HOME/.local/bin:$PATH"
    }
    
    log "SUCCESS" "Trivy instalado com sucesso"
}

# Scan de uma imagem específica
scan_single_image() {
    local image="$1"
    local scan_output="$TEMP_DIR/trivy-$(basename "$image" | tr ':/' '_').json"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Scan seria executado na imagem: $image"
        return
    fi
    
    trivy image --format json --output "$scan_output" "$image" 2>/dev/null || {
        log "ERROR" "Falha no scan da imagem: $image"
        return
    }
    
    # Processar resultados
    if [[ -f "$scan_output" ]]; then
        process_trivy_results "$scan_output" "$image"
    fi
}

# Processar resultados do Trivy
process_trivy_results() {
    local scan_file="$1"
    local image="$2"
    
    if ! command -v jq &> /dev/null; then
        log "WARN" "jq não encontrado, pulando processamento detalhado"
        return
    fi
    
    local vulnerabilities=$(jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity != null) | "\(.Severity)|\(.VulnerabilityID)|\(.Title)|\(.Description)|\(.FixedVersion // "N/A")"' "$scan_file" 2>/dev/null || echo "")
    
    while IFS='|' read -r severity vuln_id title description fix; do
        if [[ -n "$severity" ]] && [[ -n "$vuln_id" ]]; then
            case "$severity" in
                "CRITICAL") severity="CRITICAL" ;;
                "HIGH") severity="HIGH" ;;
                "MEDIUM") severity="MEDIUM" ;;
                "LOW") severity="LOW" ;;
                *) severity="INFO" ;;
            esac
            
            add_vulnerability "$severity" "$image" "$vuln_id: $title" "$description" "Update to: $fix"
        fi
    done <<< "$vulnerabilities"
}

# Scan de containers em execução
scan_running_containers() {
    log "INFO" "Iniciando scan de containers em execução..."
    
    if ! command -v docker &> /dev/null; then
        log "WARN" "Docker não encontrado, pulando scan de containers"
        return
    fi
    
    local running_containers=$(docker ps --format "{{.Names}}")
    
    if [[ -z "$running_containers" ]]; then
        log "INFO" "Nenhum container em execução encontrado"
        return
    fi
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            log "INFO" "Analisando container: $container"
            analyze_container_security "$container"
        fi
    done <<< "$running_containers"
    
    log "SUCCESS" "Scan de containers em execução concluído"
}

# Analisar segurança de um container
analyze_container_security() {
    local container="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Análise seria executada no container: $container"
        return
    fi
    
    # Verificar se está rodando como root
    local user=$(docker exec "$container" whoami 2>/dev/null || echo "unknown")
    if [[ "$user" == "root" ]]; then
        add_vulnerability "MEDIUM" "$container" "Container rodando como root" \
            "Container está executando processos como usuário root" \
            "Configurar container para rodar com usuário não-privilegiado"
    fi
    
    # Verificar mounts perigosos
    local dangerous_mounts=$(docker inspect "$container" --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' | grep -E "(:/etc|:/var|:/:|:/proc|:/sys)" || echo "")
    if [[ -n "$dangerous_mounts" ]]; then
        add_vulnerability "HIGH" "$container" "Mounts perigosos detectados" \
            "Container possui mounts que podem comprometer o host: $dangerous_mounts" \
            "Revisar necessidade dos mounts e usar volumes específicos"
    fi
    
    # Verificar capabilities
    local capabilities=$(docker inspect "$container" --format '{{.HostConfig.CapAdd}}' 2>/dev/null || echo "")
    if [[ "$capabilities" != "[]" ]] && [[ -n "$capabilities" ]]; then
        add_vulnerability "MEDIUM" "$container" "Capabilities adicionais detectadas" \
            "Container possui capabilities extras: $capabilities" \
            "Revisar se todas as capabilities são necessárias"
    fi
    
    # Verificar se está privilegiado
    local privileged=$(docker inspect "$container" --format '{{.HostConfig.Privileged}}' 2>/dev/null || echo "false")
    if [[ "$privileged" == "true" ]]; then
        add_vulnerability "CRITICAL" "$container" "Container privilegiado" \
            "Container está rodando em modo privilegiado" \
            "Remover --privileged e usar capabilities específicas"
    fi
}

# Scan de dependências
scan_dependencies() {
    log "INFO" "Iniciando scan de dependências..."
    
    # Scan de dependências Node.js
    if [[ -f "$PROJECT_ROOT/package.json" ]]; then
        scan_npm_dependencies
    fi
    
    # Scan de dependências Python
    if [[ -f "$PROJECT_ROOT/requirements.txt" ]] || [[ -f "$PROJECT_ROOT/Pipfile" ]]; then
        scan_python_dependencies
    fi
    
    # Scan de dependências Java/Maven
    if [[ -f "$PROJECT_ROOT/pom.xml" ]]; then
        scan_maven_dependencies
    fi
    
    log "SUCCESS" "Scan de dependências concluído"
}

# Scan de dependências NPM
scan_npm_dependencies() {
    log "INFO" "Escaneando dependências Node.js..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Audit do NPM seria executado"
        return
    fi
    
    cd "$PROJECT_ROOT"
    
    # Executar npm audit
    local audit_output=$(npm audit --json 2>/dev/null || echo '{"vulnerabilities":{}}')
    
    if command -v jq &> /dev/null; then
        local critical_count=$(echo "$audit_output" | jq -r '.vulnerabilities | to_entries[] | select(.value.severity == "critical") | .key' | wc -l)
        local high_count=$(echo "$audit_output" | jq -r '.vulnerabilities | to_entries[] | select(.value.severity == "high") | .key' | wc -l)
        local medium_count=$(echo "$audit_output" | jq -r '.vulnerabilities | to_entries[] | select(.value.severity == "moderate") | .key' | wc -l)
        
        if [[ $critical_count -gt 0 ]]; then
            add_vulnerability "CRITICAL" "npm-dependencies" "$critical_count vulnerabilidades críticas" \
                "Foram encontradas $critical_count vulnerabilidades críticas nas dependências Node.js" \
                "Executar: npm audit fix"
        fi
        
        if [[ $high_count -gt 0 ]]; then
            add_vulnerability "HIGH" "npm-dependencies" "$high_count vulnerabilidades altas" \
                "Foram encontradas $high_count vulnerabilidades altas nas dependências Node.js" \
                "Executar: npm audit fix"
        fi
        
        if [[ $medium_count -gt 0 ]]; then
            add_vulnerability "MEDIUM" "npm-dependencies" "$medium_count vulnerabilidades médias" \
                "Foram encontradas $medium_count vulnerabilidades médias nas dependências Node.js" \
                "Executar: npm audit fix"
        fi
    fi
}

# Scan de dependências Python
scan_python_dependencies() {
    log "INFO" "Escaneando dependências Python..."
    
    if ! command -v safety &> /dev/null; then
        log "INFO" "Instalando Safety para scan de dependências Python..."
        pip install safety 2>/dev/null || {
            log "WARN" "Não foi possível instalar Safety, pulando scan Python"
            return
        }
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Safety check seria executado"
        return
    fi
    
    local safety_output=$(safety check --json 2>/dev/null || echo '[]')
    
    if command -v jq &> /dev/null; then
        local vuln_count=$(echo "$safety_output" | jq '. | length')
        
        if [[ $vuln_count -gt 0 ]]; then
            add_vulnerability "HIGH" "python-dependencies" "$vuln_count vulnerabilidades encontradas" \
                "Safety encontrou $vuln_count vulnerabilidades nas dependências Python" \
                "Atualizar dependências vulneráveis identificadas pelo Safety"
        fi
    fi
}

# Scan de dependências Maven
scan_maven_dependencies() {
    log "INFO" "Escaneando dependências Maven..."
    
    if ! command -v mvn &> /dev/null; then
        log "WARN" "Maven não encontrado, pulando scan Maven"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Maven dependency-check seria executado"
        return
    fi
    
    cd "$PROJECT_ROOT"
    
    # Usar OWASP Dependency Check se disponível
    mvn org.owasp:dependency-check-maven:check 2>/dev/null || {
        log "WARN" "OWASP Dependency Check não configurado, pulando scan Maven detalhado"
        return
    }
    
    # Processar resultados se gerados
    local report_file="target/dependency-check-report.json"
    if [[ -f "$report_file" ]] && command -v jq &> /dev/null; then
        local vuln_count=$(jq '.dependencies[].vulnerabilities? | length' "$report_file" 2>/dev/null | awk '{sum += $1} END {print sum+0}')
        
        if [[ $vuln_count -gt 0 ]]; then
            add_vulnerability "HIGH" "maven-dependencies" "$vuln_count vulnerabilidades encontradas" \
                "OWASP Dependency Check encontrou $vuln_count vulnerabilidades" \
                "Revisar relatório em target/dependency-check-report.html"
        fi
    fi
}

# Scan de rede
scan_network_security() {
    log "INFO" "Iniciando scan de segurança de rede..."
    
    # Verificar portas abertas
    scan_open_ports
    
    # Verificar configurações de firewall
    scan_firewall_config
    
    # Verificar certificados SSL
    scan_ssl_certificates
    
    log "SUCCESS" "Scan de segurança de rede concluído"
}

# Scan de portas abertas
scan_open_ports() {
    log "INFO" "Verificando portas abertas..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Scan de portas seria executado"
        return
    fi
    
    # Usar ss para listar portas TCP em listening, com melhor tratamento de erros
    local open_ports
    if ! open_ports=$(ss -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -n | uniq); then
        log "WARNING" "Falha ao obter lista de portas abertas, continuando..."
        return
    fi
    
    local unexpected_ports=""
    local expected_ports="22 80 443 3000 5000 5432 6379"
    
    # Processar cada porta de forma mais segura
    while IFS= read -r port; do
        if [[ -n "$port" ]] && [[ "$port" =~ ^[0-9]+$ ]] && ! echo "$expected_ports" | grep -q "\b$port\b"; then
            unexpected_ports+="$port "
        fi
    done <<< "$open_ports"
    
    if [[ -n "$unexpected_ports" ]]; then
        add_vulnerability "MEDIUM" "network" "Portas não esperadas abertas" \
            "Portas abertas não esperadas: $unexpected_ports" \
            "Revisar serviços e fechar portas desnecessárias"
    fi
    
    # Verificar se portas esperadas estão abertas
    local missing_ports=""
    if [[ -n "$open_ports" ]]; then
        for expected_port in $expected_ports; do
            if ! echo "$open_ports" | grep -q "^$expected_port$"; then
                case "$expected_port" in
                    22) missing_ports+="SSH($expected_port) " ;;
                    80|443) missing_ports+="HTTP($expected_port) " ;;
                    5432) missing_ports+="PostgreSQL($expected_port) " ;;
                esac
            fi
        done
    fi
    
    if [[ -n "$missing_ports" ]] && [[ "$ENVIRONMENT" == "prod" ]]; then
        add_vulnerability "INFO" "network" "Serviços esperados não detectados" \
            "Serviços não detectados em produção: $missing_ports" \
            "Verificar se os serviços estão rodando corretamente"
    fi
}

# Scan de configurações de firewall
scan_firewall_config() {
    log "INFO" "Verificando configurações de firewall..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Verificação de firewall seria executada"
        return
    fi
    
    # Verificar UFW (com tratamento de erro)
    if command -v ufw &> /dev/null; then
        local ufw_status
        if ufw_status=$(ufw status 2>/dev/null | head -1 | awk '{print $2}'); then
            if [[ "$ufw_status" != "active" ]] && [[ "$ENVIRONMENT" == "prod" ]]; then
                add_vulnerability "HIGH" "firewall" "Firewall não está ativo em produção" \
                    "UFW não está ativo em ambiente de produção" \
                    "Ativar firewall: sudo ufw enable"
            fi
        else
            log "WARNING" "Não foi possível verificar status do UFW"
        fi
    else
        log "INFO" "UFW não está instalado"
    fi
    
    # Verificar iptables básico (com tratamento de erro)
    local iptables_rules=0
    if command -v iptables &> /dev/null; then
        if iptables_rules=$(iptables -L 2>/dev/null | wc -l); then
            if [[ $iptables_rules -lt 10 ]] && [[ "$ENVIRONMENT" == "prod" ]]; then
                add_vulnerability "MEDIUM" "firewall" "Regras de firewall mínimas em produção" \
                    "Poucas regras de firewall detectadas ($iptables_rules linhas)" \
                    "Configurar regras de firewall adequadas para produção"
            fi
        else
            log "WARNING" "Não foi possível verificar regras do iptables"
        fi
    else
        log "INFO" "iptables não está disponível"
    fi
}

# Scan de certificados SSL
scan_ssl_certificates() {
    log "INFO" "Verificando certificados SSL..."
    
    local endpoints
    case "$ENVIRONMENT" in
        "dev")
            endpoints="dev.promata.com.br:443"
            ;;
        "staging")
            endpoints="staging.promata.com.br:443"
            ;;
        "prod")
            endpoints="promata.com.br:443"
            ;;
        *)
            endpoints=""
            ;;
    esac
    
    if [[ -z "$endpoints" ]]; then
        log "INFO" "Nenhum endpoint definido para verificação SSL"
        return
    fi
    
    for endpoint in $endpoints; do
        if [[ "$DRY_RUN" == "true" ]]; then
            log "INFO" "[DRY RUN] Verificação SSL seria executada para: $endpoint"
            continue
        fi
        
        log "INFO" "Verificando SSL para: $endpoint"
        check_ssl_endpoint "$endpoint"
    done
}

# Verificar endpoint SSL específico
check_ssl_endpoint() {
    local endpoint="$1"
    local host=$(echo "$endpoint" | cut -d: -f1)
    local port=$(echo "$endpoint" | cut -d: -f2)
    
    # Verificar se o endpoint responde
    if ! timeout 10 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        add_vulnerability "HIGH" "ssl-$host" "Endpoint SSL não acessível" \
            "Não foi possível conectar ao endpoint $endpoint" \
            "Verificar se o serviço está rodando e acessível"
        return
    fi
    
    # Verificar expiração do certificado
    local cert_info=$(timeout 10 openssl s_client -connect "$endpoint" -servername "$host" < /dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
    
    if [[ -n "$cert_info" ]]; then
        local not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
        
        if [[ -n "$not_after" ]]; then
            local expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
            local current_epoch=$(date +%s)
            local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
            
            if [[ $days_until_expiry -lt 0 ]]; then
                add_vulnerability "CRITICAL" "ssl-$host" "Certificado SSL expirado" \
                    "Certificado SSL para $host expirou há $((-days_until_expiry)) dias" \
                    "Renovar certificado SSL imediatamente"
            elif [[ $days_until_expiry -lt 7 ]]; then
                add_vulnerability "HIGH" "ssl-$host" "Certificado SSL expira em breve" \
                    "Certificado SSL para $host expira em $days_until_expiry dias" \
                    "Renovar certificado SSL: make security-rotate-ssl ENVIRONMENT=$ENVIRONMENT"
            elif [[ $days_until_expiry -lt 30 ]]; then
                add_vulnerability "MEDIUM" "ssl-$host" "Certificado SSL deve ser renovado" \
                    "Certificado SSL para $host expira em $days_until_expiry dias" \
                    "Planejar renovação do certificado SSL"
            fi
        fi
    else
        add_vulnerability "MEDIUM" "ssl-$host" "Não foi possível verificar certificado" \
            "Falha ao verificar informações do certificado SSL para $endpoint" \
            "Verificar manualmente o certificado SSL"
    fi
}

# Scan de infraestrutura cloud
scan_infrastructure() {
    log "INFO" "Iniciando scan de infraestrutura cloud..."
    
    case "$ENVIRONMENT" in
        "dev"|"staging")
            scan_azure_infrastructure
            ;;
        "prod")
            scan_aws_infrastructure
            ;;
        *)
            log "INFO" "Ambiente não especificado, pulando scan de infraestrutura cloud"
            ;;
    esac
    
    log "SUCCESS" "Scan de infraestrutura concluído"
}

# Scan de infraestrutura Azure
scan_azure_infrastructure() {
    log "INFO" "Escaneando infraestrutura Azure..."
    
    if ! command -v az &> /dev/null; then
        log "WARN" "Azure CLI não encontrado, pulando scan Azure"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Scan Azure seria executado"
        return
    fi
    
    # Verificar se está logado
    if ! az account show &>/dev/null; then
        log "WARN" "Não logado no Azure, pulando scan"
        return
    fi
    
    local rg_name="promata-$ENVIRONMENT-rg"
    
    # Verificar recursos públicos
    local public_ips=$(az network public-ip list --resource-group "$rg_name" --query "[].{name:name, ip:ipAddress}" -o json 2>/dev/null || echo "[]")
    
    if [[ "$public_ips" != "[]" ]]; then
        local ip_count=$(echo "$public_ips" | jq '. | length')
        add_vulnerability "INFO" "azure-infrastructure" "$ip_count IPs públicos encontrados" \
            "Foram encontrados $ip_count IPs públicos no resource group $rg_name" \
            "Verificar se todos os IPs públicos são necessários"
    fi
    
    # Verificar NSG rules permissivas
    local nsgs=$(az network nsg list --resource-group "$rg_name" --query "[].name" -o tsv 2>/dev/null || echo "")
    
    while IFS= read -r nsg; do
        if [[ -n "$nsg" ]]; then
            local permissive_rules=$(az network nsg rule list --resource-group "$rg_name" --nsg-name "$nsg" --query "[?sourceAddressPrefix=='*' && access=='Allow']" -o json 2>/dev/null || echo "[]")
            
            if [[ "$permissive_rules" != "[]" ]]; then
                add_vulnerability "MEDIUM" "azure-nsg-$nsg" "Regras NSG permissivas detectadas" \
                    "NSG $nsg possui regras que permitem acesso de qualquer origem (*)" \
                    "Revisar e restringir regras do NSG para IPs específicos"
            fi
        fi
    done <<< "$nsgs"
}

# Scan de infraestrutura AWS
scan_aws_infrastructure() {
    log "INFO" "Escaneando infraestrutura AWS..."
    
    if ! command -v aws &> /dev/null; then
        log "WARN" "AWS CLI não encontrado, pulando scan AWS"
        return
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Scan AWS seria executado"
        return
    fi
    
    # Verificar se está configurado
    if ! aws sts get-caller-identity &>/dev/null; then
        log "WARN" "AWS CLI não configurado, pulando scan"
        return
    fi
    
    # Verificar security groups permissivos
    local open_sgs=$(aws ec2 describe-security-groups --query "SecurityGroups[?IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0']]].[GroupId,GroupName]" --output text 2>/dev/null || echo "")
    
    if [[ -n "$open_sgs" ]]; then
        while IFS=$'\t' read -r sg_id sg_name; do
            if [[ -n "$sg_id" ]]; then
                add_vulnerability "HIGH" "aws-sg-$sg_id" "Security Group permissivo" \
                    "Security Group $sg_name ($sg_id) permite acesso de 0.0.0.0/0" \
                    "Restringir regras do Security Group para IPs específicos"
            fi
        done <<< "$open_sgs"
    fi
    
    # Verificar buckets S3 públicos
    local public_buckets=$(aws s3api list-buckets --query "Buckets[].Name" --output text 2>/dev/null || echo "")
    
    while IFS= read -r bucket; do
        if [[ -n "$bucket" ]] && echo "$bucket" | grep -q "promata"; then
            local bucket_policy=$(aws s3api get-bucket-policy --bucket "$bucket" 2>/dev/null || echo "")
            local public_access=$(aws s3api get-public-access-block --bucket "$bucket" 2>/dev/null || echo "")
            
            if [[ -n "$bucket_policy" ]] && echo "$bucket_policy" | grep -q '"Effect": "Allow"'; then
                add_vulnerability "MEDIUM" "aws-s3-$bucket" "Bucket S3 com política pública" \
                    "Bucket $bucket possui política que pode permitir acesso público" \
                    "Revisar política do bucket S3 e restringir acesso se necessário"
            fi
        fi
    done <<< "$public_buckets"
}

# Salvar resultado no formato SARIF
save_sarif_result() {
    local severity="$1"
    local component="$2"
    local vulnerability="$3" 
    local description="$4"
    local fix="$5"
    
    # Implementar se necessário para CI/CD
    # Por enquanto, apenas log
    log "INFO" "SARIF result logged: $severity $component $vulnerability"
}

# Gerar relatório de scan
generate_scan_report() {
    local report_file="$REPORTS_DIR/security-scan-$(date +%Y%m%d-%H%M%S).txt"
    
    log "INFO" "Gerando relatório de scan..."
    
    cat > "$report_file" << EOF
# RELATÓRIO DE SCAN DE SEGURANÇA - PRO-MATA
# Gerado em: $(date '+%Y-%m-%d %H:%M:%S')
# Ambiente: $ENVIRONMENT
# Tipo de scan: $SCAN_TYPE

## RESUMO EXECUTIVO

Total de vulnerabilidades encontradas: ${VULN_COUNT[TOTAL]}

Distribuição por severidade:
- CRÍTICAS: ${VULN_COUNT[CRITICAL]}
- ALTAS: ${VULN_COUNT[HIGH]}
- MÉDIAS: ${VULN_COUNT[MEDIUM]}
- BAIXAS: ${VULN_COUNT[LOW]}
- INFORMATIVAS: ${VULN_COUNT[INFO]}

## RECOMENDAÇÕES IMEDIATAS

EOF
    
    if [[ ${VULN_COUNT[CRITICAL]} -gt 0 ]]; then
        echo "🚨 AÇÃO CRÍTICA NECESSÁRIA: ${VULN_COUNT[CRITICAL]} vulnerabilidades críticas encontradas" >> "$report_file"
    fi
    
    if [[ ${VULN_COUNT[HIGH]} -gt 0 ]]; then
        echo "⚠️ AÇÃO PRIORITÁRIA: ${VULN_COUNT[HIGH]} vulnerabilidades altas encontradas" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## PRÓXIMOS PASSOS

1. Corrigir vulnerabilidades CRÍTICAS imediatamente
2. Planejar correção de vulnerabilidades ALTAS
3. Agendar revisão de vulnerabilidades MÉDIAS
4. Documentar todas as correções aplicadas
5. Executar novo scan após correções

---
*Relatório gerado pelo Pro-Mata Security Scanner v1.0.0*
EOF
    
    log "SUCCESS" "Relatório gerado: $report_file"
    echo "$report_file"
}

# Parse de argumentos
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -t|--type)
                SCAN_TYPE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --ci-mode)
                CI_MODE=true
                shift
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --fail-on-critical)
                FAIL_ON_CRITICAL=true
                shift
                ;;
            --no-fail)
                FAIL_ON_CRITICAL=false
                shift
                ;;
            --full-scan)
                SCAN_TYPE="all"
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
    if [[ -n "$ENVIRONMENT" ]] && [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        log "ERROR" "Ambiente inválido: $ENVIRONMENT. Use: dev, staging, prod"
        exit 1
    fi
    
    if [[ ! "$SCAN_TYPE" =~ ^(all|containers|images|dependencies|network|infrastructure)$ ]]; then
        log "ERROR" "Tipo de scan inválido: $SCAN_TYPE"
        exit 1
    fi
}

# Função principal
main() {
    if [[ "$CI_MODE" != "true" ]]; then
        echo -e "${BLUE}"
        echo "██████╗ ██████╗  ██████╗       ███╗   ███╗ █████╗ ████████╗ █████╗ "
        echo "██╔══██╗██╔══██╗██╔═══██╗      ████╗ ████║██╔══██╗╚══██╔══╝██╔══██╗"
        echo "██████╔╝██████╔╝██║   ██║█████╗██╔████╔██║███████║   ██║   ███████║"
        echo "██╔═══╝ ██╔══██╗██║   ██║╚════╝██║╚██╔╝██║██╔══██║   ██║   ██╔══██║"
        echo "██║     ██║  ██║╚██████╔╝      ██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║"
        echo "╚═╝     ╚═╝  ╚═╝ ╚═════╝       ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝"
        echo ""
        echo "🔍 Security Scanner - Scan Completo de Vulnerabilidades"
        echo -e "${NC}"
    fi
    
    # Setup
    setup_logging
    setup_temp_env
    parse_arguments "$@"
    validate_arguments
    
    log "INFO" "Iniciando scan de segurança - Tipo: $SCAN_TYPE - Ambiente: ${ENVIRONMENT:-'all'}"
    
    # Executar scans baseado no tipo
    case "$SCAN_TYPE" in
        "all")
            scan_docker_images
            scan_running_containers
            scan_dependencies
            scan_network_security
            scan_infrastructure
            ;;
        "containers")
            scan_running_containers
            ;;
        "images")
            scan_docker_images
            ;;
        "dependencies")
            scan_dependencies
            ;;
        "network")
            scan_network_security
            ;;
        "infrastructure")
            scan_infrastructure
            ;;
    esac
    
    # Gerar relatório
    local report_file=$(generate_scan_report)
    
    # Resumo final
    echo ""
    log "SUCCESS" "Scan de segurança concluído!"
    log "INFO" "Relatório salvo: $report_file"
    log "INFO" "Resumo: ${VULN_COUNT[TOTAL]} vulnerabilidades encontradas"
    log "INFO" "  - Críticas: ${VULN_COUNT[CRITICAL]}"
    log "INFO" "  - Altas: ${VULN_COUNT[HIGH]}"
    log "INFO" "  - Médias: ${VULN_COUNT[MEDIUM]}"
    log "INFO" "  - Baixas: ${VULN_COUNT[LOW]}"
    log "INFO" "  - Informativas: ${VULN_COUNT[INFO]}"
    
    # Exit code baseado na severidade
    if [[ "$FAIL_ON_CRITICAL" == "true" ]]; then
        if [[ ${VULN_COUNT[CRITICAL]} -gt 0 ]]; then
            log "ERROR" "Falhando devido a vulnerabilidades críticas encontradas"
            exit 2
        elif [[ ${VULN_COUNT[HIGH]} -gt 0 ]]; then
            log "WARN" "Vulnerabilidades altas encontradas"
            exit 1
        fi
    fi
    
    exit 0
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi