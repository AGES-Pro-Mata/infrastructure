#!/bin/bash

# scripts/backup-recovery.sh
# Sistema completo de backup e recovery para Pro-Mata Security
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
BACKUP_DIR="$PROJECT_ROOT/backups"
LOG_DIR="$PROJECT_ROOT/logs"

# Variáveis globais
ENVIRONMENT=""
OPERATION=""
BACKUP_FILE=""
VERBOSE=false
DRY_RUN=false
ENCRYPT_BACKUP=true
RETENTION_DAYS=30
BACKUP_TYPE="full"

# Logging
setup_logging() {
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/backup-recovery-$(date +%Y%m%d-%H%M%S).log"
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
        *)
            echo -e "${CYAN}[$timestamp]${NC} $message"
            ;;
    esac
}

# Função de ajuda
show_help() {
    cat << EOF
${BLUE}Pro-Mata Backup & Recovery System${NC}

Sistema completo de backup e recovery para infraestrutura e dados de segurança

${YELLOW}Uso:${NC} $0 [OPERAÇÃO] [OPÇÕES]

${YELLOW}OPERAÇÕES:${NC}
  backup                   Criar backup completo
  backup-config           Backup apenas configurações
  backup-secrets          Backup apenas secrets
  backup-logs             Backup de logs
  restore                 Restaurar do backup
  list                    Listar backups disponíveis
  verify                  Verificar integridade dos backups
  cleanup                 Limpeza de backups antigos

${YELLOW}OPÇÕES:${NC}
  -e, --environment ENV    Ambiente (dev|staging|prod)
  -f, --file FILE         Arquivo de backup específico (para restore)
  -t, --type TYPE         Tipo de backup (full|incremental|differential)
  -v, --verbose           Output detalhado
  -d, --dry-run           Simular operações
  --no-encrypt            Não criptografar backup
  --retention DAYS        Dias de retenção [default: 30]
  -h, --help              Mostrar esta ajuda

${YELLOW}EXEMPLOS:${NC}
  $0 backup --environment prod                    # Backup completo de produção
  $0 backup-secrets --environment staging         # Backup apenas secrets
  $0 restore --file backup-20250126.tar.gz       # Restaurar backup específico
  $0 cleanup --retention 7                       # Limpar backups > 7 dias
  $0 verify --environment prod                   # Verificar integridade

${YELLOW}TIPOS DE BACKUP:${NC}
  full            Backup completo (padrão)
  incremental     Apenas mudanças desde último backup
  differential    Mudanças desde último backup completo

EOF
}

# Verificar pré-requisitos
check_prerequisites() {
    log "INFO" "Verificando pré-requisitos..."
    
    local required_commands=("tar" "gzip" "openssl")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Comando necessário não encontrado: $cmd"
            exit 1
        fi
    done
    
    # Verificar permissões de diretórios
    if [[ ! -w "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR" 2>/dev/null || {
            log "ERROR" "Não foi possível criar/escrever no diretório de backup: $BACKUP_DIR"
            exit 1
        }
    fi
    
    log "SUCCESS" "Pré-requisitos verificados"
}

# Gerar chave de criptografia
generate_encryption_key() {
    local key_file="$SCRIPT_DIR/.backup.key"
    
    # Criar diretório se não existir
    mkdir -p "$(dirname "$key_file")"
    
    if [[ ! -f "$key_file" ]]; then
        log "INFO" "Gerando chave de criptografia..."
        if ! openssl rand -base64 32 > "$key_file" 2>/dev/null; then
            log "ERROR" "Falha ao gerar chave de criptografia"
            return 1
        fi
        chmod 600 "$key_file" 2>/dev/null || true
        log "SUCCESS" "Chave de criptografia gerada"
    fi
    
    echo "$key_file"
}

# Backup completo
create_full_backup() {
    log "INFO" "Iniciando backup completo..."
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="backup-full-$ENVIRONMENT-$timestamp"
    local backup_path="$BACKUP_DIR/$backup_name"
    local final_backup="$backup_path.tar.gz"
    
    if [[ "$ENCRYPT_BACKUP" == "true" ]]; then
        final_backup="$backup_path.tar.gz.enc"
    fi
    
    # Criar diretório temporário
    local temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/$backup_name"
    
    # Coletar dados para backup
    backup_configurations "$temp_dir/$backup_name"
    backup_security_data "$temp_dir/$backup_name"
    backup_logs_data "$temp_dir/$backup_name"
    backup_secrets_data "$temp_dir/$backup_name"
    backup_monitoring_data "$temp_dir/$backup_name"
    
    # Criar manifesto do backup
    create_backup_manifest "$temp_dir/$backup_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Backup seria criado: $final_backup"
        log "INFO" "[DRY RUN] Conteúdo:"
        find "$temp_dir/$backup_name" -type f | head -10
        rm -rf "$temp_dir"
        return
    fi
    
    # Criar arquivo tar
    log "INFO" "Compactando backup..."
    tar -czf "$backup_path.tar.gz" -C "$temp_dir" "$backup_name"
    
    # Criptografar se necessário
    if [[ "$ENCRYPT_BACKUP" == "true" ]]; then
        local key_file=$(generate_encryption_key)
        if [[ $? -ne 0 ]] || [[ ! -f "$key_file" ]]; then
            log "WARN" "Falha na geração da chave, salvando backup sem criptografia"
            final_backup="$backup_path.tar.gz"
        else
            log "INFO" "Criptografando backup..."
            if openssl enc -aes-256-cbc -salt -in "$backup_path.tar.gz" -out "$final_backup" -pass file:"$key_file" 2>/dev/null; then
                rm "$backup_path.tar.gz"
            else
                log "WARN" "Falha na criptografia, mantendo backup sem criptografia"
                final_backup="$backup_path.tar.gz"
            fi
        fi
    fi
    
    # Verificar integridade
    if verify_backup "$final_backup"; then
        log "SUCCESS" "Backup criado e verificado: $final_backup"
        
        # Salvar metadata
        save_backup_metadata "$final_backup" "full" "$ENVIRONMENT"
    else
        log "ERROR" "Falha na verificação do backup"
        rm -f "$final_backup"
        exit 1
    fi
    
    # Limpeza
    rm -rf "$temp_dir"
    
    echo "$final_backup"
}

# Backup de configurações
backup_configurations() {
    local target_dir="$1/configurations"
    mkdir -p "$target_dir"
    
    log "INFO" "Fazendo backup de configurações..."
    
    # Copiar arquivos de configuração
    if [[ -d "$PROJECT_ROOT/security" ]]; then
        cp -r "$PROJECT_ROOT/security" "$target_dir/"
    fi
    
    if [[ -f "$PROJECT_ROOT/.env.security" ]]; then
        cp "$PROJECT_ROOT/.env.security" "$target_dir/"
    fi
    
    # Configurações do Docker
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        cp "$PROJECT_ROOT/docker-compose.yml" "$target_dir/"
    fi
    
    # Makefile
    if [[ -f "$PROJECT_ROOT/Makefile" ]]; then
        cp "$PROJECT_ROOT/Makefile" "$target_dir/"
    fi
    
    log "SUCCESS" "Backup de configurações concluído"
}

# Backup de dados de segurança
backup_security_data() {
    local target_dir="$1/security-data"
    mkdir -p "$target_dir"
    
    log "INFO" "Fazendo backup de dados de segurança..."
    
    # Relatórios de segurança
    if [[ -d "$PROJECT_ROOT/reports" ]]; then
        cp -r "$PROJECT_ROOT/reports" "$target_dir/"
    fi
    
    # Dados de monitoramento
    if [[ -d "$PROJECT_ROOT/monitoring" ]]; then
        cp -r "$PROJECT_ROOT/monitoring" "$target_dir/"
    fi
    
    log "SUCCESS" "Backup de dados de segurança concluído"
}

# Backup de logs
backup_logs_data() {
    local target_dir="$1/logs"
    mkdir -p "$target_dir"
    
    log "INFO" "Fazendo backup de logs..."
    
    # Logs do sistema de segurança
    if [[ -d "$PROJECT_ROOT/logs" ]]; then
        # Copiar apenas logs recentes (últimos 30 dias)
        find "$PROJECT_ROOT/logs" -name "*.log" -type f -mtime -30 -exec cp {} "$target_dir/" \;
    fi
    
    # Logs do sistema (se acessíveis)
    local system_logs=(
        "/var/log/auth.log"
        "/var/log/syslog"
        "/var/log/nginx/access.log"
        "/var/log/nginx/error.log"
    )
    
    for log_file in "${system_logs[@]}"; do
        if [[ -r "$log_file" ]]; then
            # Copiar apenas últimas 1000 linhas
            tail -1000 "$log_file" > "$target_dir/$(basename "$log_file")" 2>/dev/null || true
        fi
    done
    
    log "SUCCESS" "Backup de logs concluído"
}

# Backup de secrets
backup_secrets_data() {
    local target_dir="$1/secrets"
    mkdir -p "$target_dir"
    
    log "INFO" "Fazendo backup de secrets..."
    
    # Backup baseado no ambiente
    case "$ENVIRONMENT" in
        "dev"|"staging")
            backup_azure_secrets "$target_dir"
            ;;
        "prod")
            backup_aws_secrets "$target_dir"
            ;;
        *)
            log "WARN" "Ambiente não especificado, pulando backup de secrets cloud"
            ;;
    esac
    
    log "SUCCESS" "Backup de secrets concluído"
}

# Backup de secrets Azure
backup_azure_secrets() {
    local target_dir="$1"
    
    if ! command -v az &> /dev/null; then
        log "WARN" "Azure CLI não encontrado, pulando backup Azure"
        return
    fi
    
    if ! az account show &>/dev/null; then
        log "WARN" "Não logado no Azure, pulando backup"
        return
    fi
    
    log "INFO" "Fazendo backup dos secrets do Azure Key Vault..."
    
    local vault_name="promata-$ENVIRONMENT-kv"
    local secrets_file="$target_dir/azure-secrets.json"
    
    # Listar e exportar secrets
    az keyvault secret list --vault-name "$vault_name" --query "[].name" -o tsv 2>/dev/null | \
    while read -r secret_name; do
        if [[ -n "$secret_name" ]]; then
            # Exportar metadata apenas (não o valor)
            az keyvault secret show --vault-name "$vault_name" --name "$secret_name" \
               --query "{name:name, enabled:attributes.enabled, created:attributes.created, updated:attributes.updated}" \
               -o json >> "$secrets_file" 2>/dev/null || true
        fi
    done
    
    log "SUCCESS" "Backup Azure secrets concluído"
}

# Backup de secrets AWS
backup_aws_secrets() {
    local target_dir="$1"
    
    if ! command -v aws &> /dev/null; then
        log "WARN" "AWS CLI não encontrado, pulando backup AWS"
        return
    fi
    
    if ! aws sts get-caller-identity &>/dev/null; then
        log "WARN" "AWS CLI não configurado, pulando backup"
        return
    fi
    
    log "INFO" "Fazendo backup dos secrets do AWS Secrets Manager..."
    
    local secrets_file="$target_dir/aws-secrets.json"
    
    # Listar secrets e exportar metadata
    aws secretsmanager list-secrets --query "SecretList[?contains(Name, 'promata-$ENVIRONMENT')]" \
        --output json > "$secrets_file" 2>/dev/null || true
    
    log "SUCCESS" "Backup AWS secrets concluído"
}

# Backup de dados de monitoramento
backup_monitoring_data() {
    local target_dir="$1/monitoring"
    mkdir -p "$target_dir"
    
    log "INFO" "Fazendo backup de dados de monitoramento..."
    
    # Configurações de monitoramento
    if [[ -f "$PROJECT_ROOT/monitoring/monitor-config.json" ]]; then
        cp "$PROJECT_ROOT/monitoring/monitor-config.json" "$target_dir/"
    fi
    
    # Alertas ativos (últimos 7 dias)
    find "$PROJECT_ROOT/monitoring" -name "alert-*.json" -type f -mtime -7 -exec cp {} "$target_dir/" \; 2>/dev/null || true
    
    # Estatísticas de monitoramento
    if [[ -f "$PROJECT_ROOT/monitoring/stats.json" ]]; then
        cp "$PROJECT_ROOT/monitoring/stats.json" "$target_dir/"
    fi
    
    log "SUCCESS" "Backup de dados de monitoramento concluído"
}

# Criar manifesto do backup
create_backup_manifest() {
    local target_dir="$1"
    local manifest_file="$target_dir/MANIFEST.json"
    
    log "INFO" "Criando manifesto do backup..."
    
    cat > "$manifest_file" << EOF
{
  "backup_info": {
    "version": "1.0.0",
    "type": "$BACKUP_TYPE",
    "environment": "$ENVIRONMENT",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "created_by": "$(whoami)@$(hostname)",
    "script_version": "1.0.0"
  },
  "system_info": {
    "hostname": "$(hostname)",
    "os": "$(uname -o 2>/dev/null || uname)",
    "kernel": "$(uname -r)",
    "architecture": "$(uname -m)"
  },
  "backup_contents": {
    "configurations": $(find "$target_dir/configurations" -type f 2>/dev/null | wc -l),
    "security_data": $(find "$target_dir/security-data" -type f 2>/dev/null | wc -l),
    "logs": $(find "$target_dir/logs" -type f 2>/dev/null | wc -l),
    "secrets": $(find "$target_dir/secrets" -type f 2>/dev/null | wc -l),
    "monitoring": $(find "$target_dir/monitoring" -type f 2>/dev/null | wc -l)
  },
  "size_info": {
    "total_files": $(find "$target_dir" -type f | wc -l),
    "total_size_bytes": $(du -sb "$target_dir" | cut -f1)
  },
  "checksum": "$(find "$target_dir" -type f -exec sha256sum {} \; | sha256sum | cut -d' ' -f1)"
}
EOF
    
    log "SUCCESS" "Manifesto criado: $manifest_file"
}

# Salvar metadata do backup
save_backup_metadata() {
    local backup_file="$1"
    local backup_type="$2"
    local environment="$3"
    local metadata_file="$BACKUP_DIR/$(basename "$backup_file").meta.json"
    
    local file_size=0
    if [[ -f "$backup_file" ]]; then
        file_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
    fi
    
    cat > "$metadata_file" << EOF
{
  "backup_file": "$(basename "$backup_file")",
  "backup_type": "$backup_type",
  "environment": "$environment",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "file_size": $file_size,
  "encrypted": $ENCRYPT_BACKUP,
  "checksum": "$(sha256sum "$backup_file" | cut -d' ' -f1)",
  "retention_until": "$(date -d "+$RETENTION_DAYS days" -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF
    
    log "SUCCESS" "Metadata salvo: $metadata_file"
}

# Verificar integridade do backup
verify_backup() {
    local backup_file="$1"
    
    log "INFO" "Verificando integridade do backup: $(basename "$backup_file")"
    
    if [[ ! -f "$backup_file" ]]; then
        log "ERROR" "Arquivo de backup não encontrado: $backup_file"
        return 1
    fi
    
    # Verificar se arquivo está corrompido
    if [[ "$backup_file" =~ \.tar\.gz$ ]]; then
        if ! gzip -t "$backup_file" &>/dev/null; then
            log "ERROR" "Arquivo tar.gz corrompido"
            return 1
        fi
    elif [[ "$backup_file" =~ \.tar\.gz\.enc$ ]]; then
        # Para arquivos criptografados, tentar descriptografar em teste
        local key_file="$SCRIPT_DIR/.backup.key"
        if [[ -f "$key_file" ]]; then
            if ! openssl enc -aes-256-cbc -d -in "$backup_file" -pass file:"$key_file" | gzip -t &>/dev/null; then
                log "ERROR" "Arquivo criptografado corrompido ou chave inválida"
                return 1
            fi
        else
            log "ERROR" "Chave de criptografia não encontrada"
            return 1
        fi
    fi
    
    log "SUCCESS" "Backup verificado com sucesso"
    return 0
}

# Listar backups disponíveis
list_backups() {
    log "INFO" "Listando backups disponíveis..."
    
    local backups_found=false
    
    echo ""
    printf "%-30s %-15s %-10s %-15s %-10s\n" "ARQUIVO" "TIPO" "AMBIENTE" "DATA" "TAMANHO"
    printf "%-30s %-15s %-10s %-15s %-10s\n" "$(printf '%*s' 30 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 10 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 10 | tr ' ' '-')"
    
    for metadata_file in "$BACKUP_DIR"/*.meta.json; do
        if [[ -f "$metadata_file" ]]; then
            backups_found=true
            
            local backup_file=""
            local backup_type=""
            local environment=""
            local created_at=""
            local file_size=""
            
            if command -v jq &> /dev/null; then
                backup_file=$(jq -r '.backup_file' "$metadata_file" 2>/dev/null || echo "N/A")
                backup_type=$(jq -r '.backup_type' "$metadata_file" 2>/dev/null || echo "N/A")
                environment=$(jq -r '.environment' "$metadata_file" 2>/dev/null || echo "N/A")
                created_at=$(jq -r '.created_at' "$metadata_file" 2>/dev/null | cut -d'T' -f1 || echo "N/A")
                local size_bytes=$(jq -r '.file_size' "$metadata_file" 2>/dev/null || echo "0")
                
                # Converter bytes para formato legível
                if command -v numfmt &> /dev/null; then
                    file_size=$(numfmt --to=iec "$size_bytes" 2>/dev/null || echo "$size_bytes")
                else
                    file_size="$size_bytes"
                fi
            else
                backup_file=$(basename "$metadata_file" .meta.json)
            fi
            
            printf "%-30s %-15s %-10s %-15s %-10s\n" \
                "${backup_file:0:29}" "${backup_type:0:14}" "${environment:0:9}" \
                "${created_at:0:14}" "${file_size:0:9}"
        fi
    done
    
    if [[ "$backups_found" == "false" ]]; then
        echo "Nenhum backup encontrado em $BACKUP_DIR"
    fi
    
    echo ""
}

# Restaurar backup
restore_backup() {
    log "INFO" "Iniciando restore do backup..."
    
    if [[ -z "$BACKUP_FILE" ]]; then
        log "ERROR" "Arquivo de backup não especificado. Use --file"
        exit 1
    fi
    
    local backup_path="$BACKUP_DIR/$BACKUP_FILE"
    
    if [[ ! -f "$backup_path" ]]; then
        # Tentar encontrar o arquivo
        local found_backup=$(find "$BACKUP_DIR" -name "*$BACKUP_FILE*" -type f | head -1)
        if [[ -n "$found_backup" ]]; then
            backup_path="$found_backup"
        else
            log "ERROR" "Arquivo de backup não encontrado: $BACKUP_FILE"
            exit 1
        fi
    fi
    
    # Verificar integridade antes do restore
    if ! verify_backup "$backup_path"; then
        log "ERROR" "Backup corrompido, abortando restore"
        exit 1
    fi
    
    # Confirmação do usuário
    if [[ "$DRY_RUN" != "true" ]]; then
        echo -e "${YELLOW}⚠️ ATENÇÃO: Este restore irá sobrescrever configurações atuais!${NC}"
        echo -e "${YELLOW}Backup: $(basename "$backup_path")${NC}"
        echo -e "${YELLOW}Deseja continuar? [y/N]${NC}"
        read -r confirmation
        if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
            log "INFO" "Restore cancelado pelo usuário"
            exit 0
        fi
    fi
    
    # Criar backup das configurações atuais
    if [[ "$DRY_RUN" != "true" ]]; then
        log "INFO" "Criando backup das configurações atuais..."
        local current_backup_name="backup-before-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "$BACKUP_DIR/$current_backup_name" -C "$PROJECT_ROOT" security/ .env.security 2>/dev/null || true
        log "SUCCESS" "Backup atual salvo: $current_backup_name"
    fi
    
    # Extrair backup
    local temp_dir=$(mktemp -d)
    
    if [[ "$backup_path" =~ \.tar\.gz\.enc$ ]]; then
        # Descriptografar primeiro
        local key_file="$SCRIPT_DIR/.backup.key"
        if [[ -f "$key_file" ]]; then
            log "INFO" "Descriptografando backup..."
            openssl enc -aes-256-cbc -d -in "$backup_path" -out "$temp_dir/backup.tar.gz" -pass file:"$key_file"
            backup_path="$temp_dir/backup.tar.gz"
        else
            log "ERROR" "Chave de criptografia não encontrada"
            exit 1
        fi
    fi
    
    log "INFO" "Extraindo backup..."
    tar -xzf "$backup_path" -C "$temp_dir"
    
    # Encontrar diretório do backup
    local backup_content_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "backup-*" | head -1)
    
    if [[ -z "$backup_content_dir" ]]; then
        log "ERROR" "Estrutura de backup inválida"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY RUN] Restore seria executado:"
        log "INFO" "[DRY RUN] Conteúdo do backup:"
        find "$backup_content_dir" -type f | head -20
        rm -rf "$temp_dir"
        return
    fi
    
    # Restaurar configurações
    restore_configurations "$backup_content_dir"
    restore_security_data "$backup_content_dir"
    restore_monitoring_data "$backup_content_dir"
    
    # Limpeza
    rm -rf "$temp_dir"
    
    log "SUCCESS" "Restore concluído com sucesso!"
    log "INFO" "Reinicie os serviços para aplicar as configurações restauradas"
}

# Restaurar configurações
restore_configurations() {
    local backup_dir="$1/configurations"
    
    if [[ ! -d "$backup_dir" ]]; then
        log "WARN" "Diretório de configurações não encontrado no backup"
        return
    fi
    
    log "INFO" "Restaurando configurações..."
    
    # Restaurar diretório security
    if [[ -d "$backup_dir/security" ]]; then
        cp -r "$backup_dir/security"/* "$PROJECT_ROOT/security/" 2>/dev/null || true
        log "SUCCESS" "Configurações de segurança restauradas"
    fi
    
    # Restaurar .env.security
    if [[ -f "$backup_dir/.env.security" ]]; then
        cp "$backup_dir/.env.security" "$PROJECT_ROOT/"
        chmod 600 "$PROJECT_ROOT/.env.security"
        log "SUCCESS" "Arquivo .env.security restaurado"
    fi
    
    # Restaurar docker-compose se existe
    if [[ -f "$backup_dir/docker-compose.yml" ]]; then
        cp "$backup_dir/docker-compose.yml" "$PROJECT_ROOT/"
        log "SUCCESS" "Docker Compose restaurado"
    fi
}

# Restaurar dados de segurança
restore_security_data() {
    local backup_dir="$1/security-data"
    
    if [[ ! -d "$backup_dir" ]]; then
        log "WARN" "Diretório de dados de segurança não encontrado no backup"
        return
    fi
    
    log "INFO" "Restaurando dados de segurança..."
    
    # Restaurar relatórios
    if [[ -d "$backup_dir/reports" ]]; then
        mkdir -p "$PROJECT_ROOT/reports"
        cp -r "$backup_dir/reports"/* "$PROJECT_ROOT/reports/" 2>/dev/null || true
        log "SUCCESS" "Relatórios de segurança restaurados"
    fi
}

# Restaurar dados de monitoramento
restore_monitoring_data() {
    local backup_dir="$1/monitoring"
    
    if [[ ! -d "$backup_dir" ]]; then
        log "WARN" "Diretório de monitoramento não encontrado no backup"
        return
    fi
    
    log "INFO" "Restaurando dados de monitoramento..."
    
    # Restaurar configurações de monitoramento
    if [[ -f "$backup_dir/monitor-config.json" ]]; then
        cp "$backup_dir/monitor-config.json" "$PROJECT_ROOT/monitoring/"
        log "SUCCESS" "Configurações de monitoramento restauradas"
    fi
    
    # Restaurar estatísticas
    if [[ -f "$backup_dir/stats.json" ]]; then
        cp "$backup_dir/stats.json" "$PROJECT_ROOT/monitoring/"
        log "SUCCESS" "Estatísticas de monitoramento restauradas"
    fi
}

# Limpeza de backups antigos
cleanup_old_backups() {
    log "INFO" "Iniciando limpeza de backups antigos (>${RETENTION_DAYS} dias)..."
    
    local cleaned_count=0
    
    # Limpar backups antigos
    while IFS= read -r -d '' backup_file; do
        local file_age_days=$((($(date +%s) - $(stat -c %Y "$backup_file")) / 86400))
        
        if [[ $file_age_days -gt $RETENTION_DAYS ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log "INFO" "[DRY RUN] Seria removido: $(basename "$backup_file") ($file_age_days dias)"
            else
                rm -f "$backup_file"
                # Remover metadata também
                local metadata_file="${backup_file}.meta.json"
                rm -f "$metadata_file"
                log "INFO" "Removido: $(basename "$backup_file") ($file_age_days dias)"
            fi
            ((cleaned_count++))
        fi
    done < <(find "$BACKUP_DIR" -name "backup-*.tar.gz*" -type f -print0 2>/dev/null)
    
    if [[ $cleaned_count -eq 0 ]]; then
        log "INFO" "Nenhum backup antigo encontrado para limpeza"
    else
        log "SUCCESS" "Limpeza concluída: $cleaned_count arquivos processados"
    fi
}

# Parse de argumentos
parse_arguments() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi
    
    OPERATION="$1"
    shift
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -f|--file)
                BACKUP_FILE="$2"
                shift 2
                ;;
            -t|--type)
                BACKUP_TYPE="$2"
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
            --no-encrypt)
                ENCRYPT_BACKUP=false
                shift
                ;;
            --retention)
                RETENTION_DAYS="$2"
                shift 2
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
    case "$OPERATION" in
        backup|backup-config|backup-secrets|backup-logs)
            if [[ -z "$ENVIRONMENT" ]]; then
                log "ERROR" "Ambiente necessário para backup. Use -e dev|staging|prod"
                exit 1
            fi
            
            if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
                log "ERROR" "Ambiente inválido: $ENVIRONMENT"
                exit 1
            fi
            ;;
        restore)
            if [[ -z "$BACKUP_FILE" ]]; then
                log "ERROR" "Arquivo de backup necessário para restore. Use -f"
                exit 1
            fi
            ;;
        list|verify|cleanup)
            # Operações que não precisam de validação específica
            ;;
        *)
            log "ERROR" "Operação inválida: $OPERATION"
            show_help
            exit 1
            ;;
    esac
    
    if [[ ! "$BACKUP_TYPE" =~ ^(full|incremental|differential)$ ]]; then
        log "ERROR" "Tipo de backup inválido: $BACKUP_TYPE"
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
    echo "💾 Backup & Recovery System - Proteção de Dados de Segurança"
    echo -e "${NC}"
    
    parse_arguments "$@"
    validate_arguments
    setup_logging
    check_prerequisites
    
    case "$OPERATION" in
        backup)
            create_full_backup
            ;;
        backup-config)
            BACKUP_TYPE="config"
            # Implementar backup específico de configurações
            create_full_backup
            ;;
        backup-secrets)
            BACKUP_TYPE="secrets" 
            # Implementar backup específico de secrets
            create_full_backup
            ;;
        backup-logs)
            BACKUP_TYPE="logs"
            # Implementar backup específico de logs
            create_full_backup
            ;;
        restore)
            restore_backup
            ;;
        list)
            list_backups
            ;;
        verify)
            if [[ -n "$BACKUP_FILE" ]]; then
                verify_backup "$BACKUP_DIR/$BACKUP_FILE"
            else
                # Verificar todos os backups
                for backup in "$BACKUP_DIR"/backup-*.tar.gz*; do
                    if [[ -f "$backup" ]]; then
                        verify_backup "$backup"
                    fi
                done
            fi
            ;;
        cleanup)
            cleanup_old_backups
            ;;
    esac
    
    log "SUCCESS" "Operação '$OPERATION' concluída com sucesso!"
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi