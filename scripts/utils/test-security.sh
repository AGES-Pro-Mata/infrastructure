#!/bin/bash

# scripts/test-security.sh
# Suite completa de testes para o sistema de segurança Pro-Mata
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
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"

# Variáveis globais
ENVIRONMENT="dev"
VERBOSE=false
QUICK_TEST=false
GENERATE_REPORT=true
TEST_TYPE="all"

# Contadores de teste
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Array para armazenar resultados
declare -a TEST_RESULTS=()

# Logging
setup_logging() {
    mkdir -p "$LOG_DIR" "$TEST_RESULTS_DIR"
    LOG_FILE="$LOG_DIR/security-tests-$(date +%Y%m%d-%H%M%S).log"
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
        "TEST_PASS")
            echo -e "${CYAN}[$timestamp]${NC} ${GREEN}✅ PASS${NC}: $message"
            ;;
        "TEST_FAIL")
            echo -e "${CYAN}[$timestamp]${NC} ${RED}❌ FAIL${NC}: $message"
            ;;
        "TEST_SKIP")
            echo -e "${CYAN}[$timestamp]${NC} ${YELLOW}⏭️ SKIP${NC}: $message"
            ;;
        *)
            echo -e "${CYAN}[$timestamp]${NC} $message"
            ;;
    esac
}

# Função de ajuda
show_help() {
    cat << EOF
${BLUE}Pro-Mata Security Test Suite${NC}

Suite completa de testes para validação do sistema de segurança

${YELLOW}Uso:${NC} $0 [OPÇÕES]

${YELLOW}OPÇÕES:${NC}
  -e, --environment ENV    Ambiente (dev|staging|prod) [default: dev]
  -t, --type TYPE         Tipo de teste (all|unit|integration|e2e|performance)
  -q, --quick             Executar apenas testes essenciais
  -v, --verbose           Output detalhado
  --no-report            Não gerar relatório HTML
  -h, --help             Mostrar esta ajuda

${YELLOW}TIPOS DE TESTE:${NC}
  all            Todos os testes (padrão)
  unit           Testes unitários de componentes
  integration    Testes de integração entre componentes  
  e2e            Testes end-to-end do fluxo completo
  performance    Testes de performance e carga

${YELLOW}EXEMPLOS:${NC}
  $0                              # Todos os testes para dev
  $0 --environment prod --quick   # Testes rápidos para produção
  $0 --type integration           # Apenas testes de integração
  $0 --verbose --no-report        # Sem relatório, output detalhado

${YELLOW}CATEGORIAS DE TESTE:${NC}
  📁 Estrutura de arquivos e permissões
  ⚙️ Configurações e dependências  
  🔧 Scripts e funcionalidades
  🔍 Scans e detecções
  🚨 Sistema de alertas
  📊 Dashboard e relatórios
  🔒 Segurança e criptografia
  🔄 Backup e recovery

EOF
}

# Executar teste individual
run_test() {
    local test_name="$1"
    local test_function="$2"
    local test_category="$3"
    
    ((TESTS_TOTAL++))
    
    if [[ "$VERBOSE" == "true" ]]; then
        log "INFO" "Executando teste: $test_name"
    fi
    
    local start_time=$(date +%s%3N)
    local test_result="PASS"
    local test_output=""
    
    # Executar teste e capturar resultado
    if test_output=$($test_function 2>&1); then
        ((TESTS_PASSED++))
        log "TEST_PASS" "$test_name"
    else
        ((TESTS_FAILED++))
        test_result="FAIL"
        log "TEST_FAIL" "$test_name"
        if [[ "$VERBOSE" == "true" ]] && [[ -n "$test_output" ]]; then
            log "ERROR" "Detalhes: $test_output"
        fi
    fi
    
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    # Armazenar resultado
    TEST_RESULTS+=("$test_category|$test_name|$test_result|$duration|$test_output")
}

# Pular teste
skip_test() {
    local test_name="$1"
    local reason="$2"
    local test_category="$3"
    
    ((TESTS_TOTAL++))
    ((TESTS_SKIPPED++))
    
    log "TEST_SKIP" "$test_name ($reason)"
    
    # Armazenar resultado
    TEST_RESULTS+=("$test_category|$test_name|SKIP|0|$reason")
}

# ============================================================================
# TESTES DE ESTRUTURA DE ARQUIVOS
# ============================================================================

test_directory_structure() {
    local required_dirs=(
        "scripts"
        "security" 
        "logs"
        "reports/security"
        "reports/security-scan"
        "monitoring"
        "backups"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
            echo "Diretório ausente: $dir"
            return 1
        fi
    done
    
    return 0
}

test_script_files_exist() {
    local required_scripts=(
        "scripts/security-scan.sh"
        "scripts/security-audit.sh"
        "scripts/security-monitor.sh"
        "scripts/rotate-secrets.sh"
        "scripts/init-security.sh"
        "scripts/security-dashboard.sh"
        "scripts/backup-recovery.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$script" ]]; then
            echo "Script ausente: $script"
            return 1
        fi
    done
    
    return 0
}

test_script_permissions() {
    local script_files=(
        "scripts/security-scan.sh"
        "scripts/security-audit.sh" 
        "scripts/security-monitor.sh"
        "scripts/rotate-secrets.sh"
        "scripts/init-security.sh"
        "scripts/security-dashboard.sh"
        "scripts/backup-recovery.sh"
    )
    
    for script in "${script_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$script" ]]; then
            if [[ ! -x "$PROJECT_ROOT/$script" ]]; then
                echo "Script não executável: $script"
                return 1
            fi
        fi
    done
    
    return 0
}

test_config_files_exist() {
    local config_files=(
        "security/security-config.yml"
        "Makefile"
    )
    
    for config in "${config_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$config" ]]; then
            echo "Arquivo de configuração ausente: $config"
            return 1
        fi
    done
    
    return 0
}

# ============================================================================
# TESTES DE DEPENDÊNCIAS
# ============================================================================

test_system_dependencies() {
    local required_commands=(
        "bash"
        "curl"
        "jq"
        "openssl"
        "tar"
        "gzip"
    )
    
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        echo "Comandos ausentes: ${missing_commands[*]}"
        return 1
    fi
    
    return 0
}

test_docker_available() {
    if ! command -v docker &> /dev/null; then
        echo "Docker não instalado"
        return 1
    fi
    
    if ! docker info &>/dev/null; then
        echo "Docker não está rodando"
        return 1
    fi
    
    return 0
}

test_cloud_cli_tools() {
    case "$ENVIRONMENT" in
        "dev")
            # Dev não precisa de CLIs cloud específicas
            return 0
            ;;
        "staging")
            if ! command -v az &> /dev/null; then
                echo "Azure CLI não instalado (necessário para staging)"
                return 1
            fi
            ;;
        "prod")
            if ! command -v aws &> /dev/null; then
                echo "AWS CLI não instalado (necessário para produção)"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# ============================================================================
# TESTES FUNCIONAIS DOS SCRIPTS
# ============================================================================

test_security_scan_help() {
    if ! "$PROJECT_ROOT/scripts/security-scan.sh" --help &>/dev/null; then
        echo "Script security-scan.sh falhou no help"
        return 1
    fi
    
    return 0
}

test_security_audit_help() {
    if ! "$PROJECT_ROOT/scripts/security-audit.sh" --help &>/dev/null; then
        echo "Script security-audit.sh falhou no help"
        return 1
    fi
    
    return 0
}

test_rotate_secrets_help() {
    if ! "$PROJECT_ROOT/scripts/rotate-secrets.sh" --help &>/dev/null; then
        echo "Script rotate-secrets.sh falhou no help"
        return 1
    fi
    
    return 0
}

test_security_monitor_help() {
    if ! "$PROJECT_ROOT/scripts/security-monitor.sh" --help &>/dev/null; then
        echo "Script security-monitor.sh falhou no help"
        return 1
    fi
    
    return 0
}

test_backup_recovery_help() {
    if ! "$PROJECT_ROOT/scripts/backup-recovery.sh" --help &>/dev/null; then
        echo "Script backup-recovery.sh falhou no help"
        return 1
    fi
    
    return 0
}

# ============================================================================
# TESTES DE INTEGRAÇÃO
# ============================================================================

test_makefile_security_commands() {
    if [[ ! -f "$PROJECT_ROOT/Makefile" ]]; then
        echo "Makefile não encontrado"
        return 1
    fi
    
    # Verificar se comandos de segurança existem
    local security_targets=(
        "security-check"
        "security-scan"
        "security-audit"
        "security-monitor"
        "security-rotate"
        "security-backup"
    )
    
    for target in "${security_targets[@]}"; do
        if ! grep -q "^$target:" "$PROJECT_ROOT/Makefile"; then
            echo "Target Makefile ausente: $target"
            return 1
        fi
    done
    
    return 0
}

test_scan_dry_run() {
    if [[ -x "$PROJECT_ROOT/scripts/security-scan.sh" ]]; then
        if ! "$PROJECT_ROOT/scripts/security-scan.sh" --dry-run --type dependencies 2>/dev/null; then
            echo "Scan dry-run falhou"
            return 1
        fi
    else
        echo "Script security-scan.sh não executável"
        return 1
    fi
    
    return 0
}

test_audit_compliance_check() {
    if [[ -x "$PROJECT_ROOT/scripts/security-audit.sh" ]]; then
        if ! "$PROJECT_ROOT/scripts/security-audit.sh" --compliance-check 2>/dev/null; then
            echo "Audit compliance check falhou"
            return 1
        fi
    else
        echo "Script security-audit.sh não executável"
        return 1
    fi
    
    return 0
}

test_backup_list() {
    if [[ -x "$PROJECT_ROOT/scripts/backup-recovery.sh" ]]; then
        if ! "$PROJECT_ROOT/scripts/backup-recovery.sh" list 2>/dev/null; then
            echo "Backup list falhou"
            return 1
        fi
    else
        echo "Script backup-recovery.sh não executável"
        return 1
    fi
    
    return 0
}

# ============================================================================
# TESTES END-TO-END
# ============================================================================

test_full_security_workflow() {
    local temp_env_file="$PROJECT_ROOT/.env.security.test"
    
    # Criar arquivo de ambiente de teste
    cat > "$temp_env_file" << EOF
ENVIRONMENT=dev
VERBOSE=false
DRY_RUN=true
DISCORD_WEBHOOK_URL=""
EOF
    
    # Teste de workflow completo
    if ! timeout 30 "$PROJECT_ROOT/scripts/security-scan.sh" --environment dev --dry-run --type dependencies 2>/dev/null; then
        rm -f "$temp_env_file"
        echo "Workflow scan falhou"
        return 1
    fi
    
    if ! timeout 30 "$PROJECT_ROOT/scripts/security-audit.sh" --compliance-check 2>/dev/null; then
        rm -f "$temp_env_file"
        echo "Workflow audit falhou"
        return 1
    fi
    
    rm -f "$temp_env_file"
    return 0
}

test_dashboard_generation() {
    if [[ -x "$PROJECT_ROOT/scripts/security-dashboard.sh" ]]; then
        if ! timeout 30 "$PROJECT_ROOT/scripts/security-dashboard.sh" --update-only 2>/dev/null; then
            echo "Dashboard generation falhou"
            return 1
        fi
    else
        echo "Script security-dashboard.sh não executável"
        return 1
    fi
    
    return 0
}

# ============================================================================
# TESTES DE PERFORMANCE
# ============================================================================

test_scan_performance() {
    if [[ ! -x "$PROJECT_ROOT/scripts/security-scan.sh" ]]; then
        echo "Script não executável"
        return 1
    fi
    
    local start_time=$(date +%s)
    
    if ! timeout 60 "$PROJECT_ROOT/scripts/security-scan.sh" --environment dev --dry-run --type dependencies &>/dev/null; then
        echo "Scan timeout (>60s)"
        return 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $duration -gt 60 ]]; then
        echo "Scan muito lento: ${duration}s"
        return 1
    fi
    
    return 0
}

test_audit_performance() {
    if [[ ! -x "$PROJECT_ROOT/scripts/security-audit.sh" ]]; then
        echo "Script não executável"
        return 1
    fi
    
    local start_time=$(date +%s)
    
    if ! timeout 45 "$PROJECT_ROOT/scripts/security-audit.sh" --compliance-check &>/dev/null; then
        echo "Audit timeout (>45s)"
        return 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $duration -gt 45 ]]; then
        echo "Audit muito lento: ${duration}s"
        return 1
    fi
    
    return 0
}

# ============================================================================
# TESTES DE SEGURANÇA
# ============================================================================

test_script_security() {
    local security_issues=()
    
    # Verificar se scripts não contêm hardcoded credentials
    for script in "$PROJECT_ROOT/scripts"/*.sh; do
        if [[ -f "$script" ]]; then
            # Procurar por padrões suspeitos
            if grep -qE "(password|secret|key|token)\s*=" "$script" 2>/dev/null; then
                if grep -qE "(password|secret|key|token)\s*=\s*['\"]?[A-Za-z0-9]{8,}" "$script" 2>/dev/null; then
                    security_issues+=("Possível credential hardcoded em $(basename "$script")")
                fi
            fi
        fi
    done
    
    if [[ ${#security_issues[@]} -gt 0 ]]; then
        echo "Issues encontrados: ${security_issues[*]}"
        return 1
    fi
    
    return 0
}

test_file_permissions_security() {
    local permission_issues=()
    
    # Verificar permissões de arquivos sensíveis
    if [[ -f "$PROJECT_ROOT/.env.security" ]]; then
        local perms=$(stat -c "%a" "$PROJECT_ROOT/.env.security")
        if [[ "$perms" != "600" ]] && [[ "$perms" != "400" ]]; then
            permission_issues+=(".env.security tem permissões inseguras: $perms")
        fi
    fi
    
    # Verificar diretórios sensíveis
    local sensitive_dirs=("security/keys" "backups/secrets")
    for dir in "${sensitive_dirs[@]}"; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            local perms=$(stat -c "%a" "$PROJECT_ROOT/$dir")
            if [[ "$perms" != "700" ]]; then
                permission_issues+=("$dir tem permissões inseguras: $perms")
            fi
        fi
    done
    
    if [[ ${#permission_issues[@]} -gt 0 ]]; then
        echo "Issues encontrados: ${permission_issues[*]}"
        return 1
    fi
    
    return 0
}

# ============================================================================
# EXECUTAR TESTES POR CATEGORIA
# ============================================================================

run_unit_tests() {
    log "INFO" "Executando testes unitários..."
    
    run_test "Estrutura de diretórios" "test_directory_structure" "Unit"
    run_test "Scripts existem" "test_script_files_exist" "Unit"
    run_test "Permissões dos scripts" "test_script_permissions" "Unit"
    run_test "Arquivos de configuração" "test_config_files_exist" "Unit"
    run_test "Dependências do sistema" "test_system_dependencies" "Unit"
    
    if [[ "$QUICK_TEST" != "true" ]]; then
        run_test "Docker disponível" "test_docker_available" "Unit"
        run_test "Ferramentas cloud" "test_cloud_cli_tools" "Unit"
    fi
}

run_integration_tests() {
    log "INFO" "Executando testes de integração..."
    
    run_test "Security scan --help" "test_security_scan_help" "Integration"
    run_test "Security audit --help" "test_security_audit_help" "Integration"
    run_test "Rotate secrets --help" "test_rotate_secrets_help" "Integration"
    run_test "Security monitor --help" "test_security_monitor_help" "Integration"
    run_test "Backup recovery --help" "test_backup_recovery_help" "Integration"
    run_test "Targets do Makefile" "test_makefile_security_commands" "Integration"
    
    if [[ "$QUICK_TEST" != "true" ]]; then
        run_test "Scan dry-run" "test_scan_dry_run" "Integration"
        run_test "Audit compliance check" "test_audit_compliance_check" "Integration"
        run_test "Backup list" "test_backup_list" "Integration"
    fi
}

run_e2e_tests() {
    log "INFO" "Executando testes end-to-end..."
    
    if [[ "$QUICK_TEST" == "true" ]]; then
        skip_test "Workflow completo" "Quick test mode" "E2E"
        skip_test "Dashboard generation" "Quick test mode" "E2E"
    else
        run_test "Workflow completo" "test_full_security_workflow" "E2E"
        run_test "Geração de dashboard" "test_dashboard_generation" "E2E"
    fi
}

run_performance_tests() {
    log "INFO" "Executando testes de performance..."
    
    if [[ "$QUICK_TEST" == "true" ]]; then
        skip_test "Performance scan" "Quick test mode" "Performance"
        skip_test "Performance audit" "Quick test mode" "Performance"
    else
        run_test "Performance do scan" "test_scan_performance" "Performance"
        run_test "Performance da auditoria" "test_audit_performance" "Performance"
    fi
}

run_security_tests() {
    log "INFO" "Executando testes de segurança..."
    
    run_test "Segurança dos scripts" "test_script_security" "Security"
    run_test "Permissões de arquivos" "test_file_permissions_security" "Security"
}

# ============================================================================
# GERAÇÃO DE RELATÓRIOS
# ============================================================================

generate_test_report() {
    if [[ "$GENERATE_REPORT" != "true" ]]; then
        return
    fi
    
    log "INFO" "Gerando relatório de testes..."
    
    local report_file="$TEST_RESULTS_DIR/security-test-report-$(date +%Y%m%d-%H%M%S).html"
    local success_rate=0
    
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        success_rate=$(( (TESTS_PASSED * 100) / TESTS_TOTAL ))
    fi
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Relatório de Testes de Segurança Pro-Mata</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 40px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 40px; }
        .metric { text-align: center; padding: 20px; background: #f8f9fa; border-radius: 8px; }
        .metric-value { font-size: 2rem; font-weight: bold; margin-bottom: 10px; }
        .pass { color: #28a745; }
        .fail { color: #dc3545; }
        .skip { color: #ffc107; }
        .test-results { margin-top: 30px; }
        .test-category { margin-bottom: 30px; }
        .test-category h3 { background: #007bff; color: white; padding: 10px 15px; margin: 0; border-radius: 5px 5px 0 0; }
        .test-list { border: 1px solid #dee2e6; border-top: none; border-radius: 0 0 5px 5px; }
        .test-item { display: flex; justify-content: space-between; align-items: center; padding: 12px 15px; border-bottom: 1px solid #eee; }
        .test-item:last-child { border-bottom: none; }
        .test-name { font-weight: 500; }
        .test-result { padding: 4px 12px; border-radius: 4px; font-size: 0.9rem; font-weight: bold; }
        .test-result.PASS { background: #d4edda; color: #155724; }
        .test-result.FAIL { background: #f8d7da; color: #721c24; }
        .test-result.SKIP { background: #fff3cd; color: #856404; }
        .progress-bar { width: 100%; height: 20px; background: #e9ecef; border-radius: 10px; overflow: hidden; margin: 10px 0; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #28a745, #20c997); transition: width 0.3s ease; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 Relatório de Testes de Segurança Pro-Mata</h1>
            <p>Gerado em: $(date '+%d/%m/%Y %H:%M:%S')</p>
            <p>Ambiente: <strong>$ENVIRONMENT</strong></p>
        </div>
        
        <div class="summary">
            <div class="metric">
                <div class="metric-value">$TESTS_TOTAL</div>
                <div>Total de Testes</div>
            </div>
            <div class="metric">
                <div class="metric-value pass">$TESTS_PASSED</div>
                <div>Aprovados</div>
            </div>
            <div class="metric">
                <div class="metric-value fail">$TESTS_FAILED</div>
                <div>Falharam</div>
            </div>
            <div class="metric">
                <div class="metric-value skip">$TESTS_SKIPPED</div>
                <div>Ignorados</div>
            </div>
            <div class="metric">
                <div class="metric-value">$success_rate%</div>
                <div>Taxa de Sucesso</div>
            </div>
        </div>
        
        <div class="progress-bar">
            <div class="progress-fill" style="width: $success_rate%"></div>
        </div>
        
        <div class="test-results">
EOF
    
    # Agrupar resultados por categoria
    local categories=("Unit" "Integration" "E2E" "Performance" "Security")
    
    for category in "${categories[@]}"; do
        local category_tests=()
        
        for result in "${TEST_RESULTS[@]}"; do
            if [[ "$result" =~ ^$category\| ]]; then
                category_tests+=("$result")
            fi
        done
        
        if [[ ${#category_tests[@]} -gt 0 ]]; then
            cat >> "$report_file" << EOF
            <div class="test-category">
                <h3>$category Tests</h3>
                <div class="test-list">
EOF
            
            for test_result in "${category_tests[@]}"; do
                IFS='|' read -r cat name result duration output <<< "$test_result"
                
                cat >> "$report_file" << EOF
                    <div class="test-item">
                        <div class="test-name">$name</div>
                        <div class="test-result $result">$result</div>
                    </div>
EOF
            done
            
            cat >> "$report_file" << EOF
                </div>
            </div>
EOF
        fi
    done
    
    cat >> "$report_file" << EOF
        </div>
        
        <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #dee2e6; text-align: center; color: #6c757d;">
            <small>Relatório gerado pelo Pro-Mata Security Test Suite v1.0.0</small>
        </div>
    </div>
</body>
</html>
EOF
    
    log "SUCCESS" "Relatório gerado: $report_file"
}

# ============================================================================
# FUNÇÕES PRINCIPAIS
# ============================================================================

# Parse de argumentos
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -t|--type)
                TEST_TYPE="$2"
                shift 2
                ;;
            -q|--quick)
                QUICK_TEST=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-report)
                GENERATE_REPORT=false
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
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        log "ERROR" "Ambiente inválido: $ENVIRONMENT. Use: dev, staging, prod"
        exit 1
    fi
    
    if [[ ! "$TEST_TYPE" =~ ^(all|unit|integration|e2e|performance)$ ]]; then
        log "ERROR" "Tipo de teste inválido: $TEST_TYPE"
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
    echo "🧪 Security Test Suite - Validação Completa do Sistema"
    echo -e "${NC}"
    
    parse_arguments "$@"
    validate_arguments
    setup_logging
    
    log "INFO" "Iniciando testes de segurança"
    log "INFO" "Ambiente: $ENVIRONMENT"
    log "INFO" "Tipo: $TEST_TYPE"
    log "INFO" "Quick mode: $QUICK_TEST"
    
    local start_time=$(date +%s)
    
    # Executar testes baseados no tipo
    case "$TEST_TYPE" in
        "all")
            run_unit_tests
            run_integration_tests
            run_e2e_tests
            run_performance_tests
            run_security_tests
            ;;
        "unit")
            run_unit_tests
            ;;
        "integration")
            run_integration_tests
            ;;
        "e2e")
            run_e2e_tests
            ;;
        "performance")
            run_performance_tests
            ;;
        "security")
            run_security_tests
            ;;
    esac
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Gerar relatório
    generate_test_report
    
    # Resumo final
    echo ""
    log "SUCCESS" "Testes concluídos em ${total_duration}s"
    echo ""
    echo -e "${CYAN}📊 RESUMO DOS TESTES:${NC}"
    echo -e "  Total: $TESTS_TOTAL"
    echo -e "  ${GREEN}✅ Aprovados: $TESTS_PASSED${NC}"
    echo -e "  ${RED}❌ Falharam: $TESTS_FAILED${NC}"
    echo -e "  ${YELLOW}⏭️ Ignorados: $TESTS_SKIPPED${NC}"
    
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        local success_rate=$(( (TESTS_PASSED * 100) / TESTS_TOTAL ))
        echo -e "  📈 Taxa de sucesso: $success_rate%"
    fi
    
    echo ""
    
    # Exit code baseado nos resultados
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log "ERROR" "Alguns testes falharam"
        exit 1
    else
        log "SUCCESS" "Todos os testes passaram!"
        exit 0
    fi
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi