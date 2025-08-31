#!/bin/bash
# Gestão Robusta de Secrets - Pro-Mata Infrastructure
# Combina multiple providers para máxima confiabilidade

set -euo pipefail

ENV=${1:-dev}
ACTION=${2:-load}
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Configurações por ambiente
declare -A VAULT_CONFIGS=(
    ["dev"]="kv-promata-dev-secrets"
    ["staging"]="kv-promata-staging-secrets"  
    ["prod"]="kv-promata-prod-secrets"
)

# Função para log estruturado
log() {
    local level="$1"
    local message="$2"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Detectar ambiente de execução
detect_environment() {
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "github"
    elif [[ -n "${AZURE_CLIENT_ID:-}" ]]; then
        echo "azure"  
    elif command -v az &> /dev/null && az account show &> /dev/null; then
        echo "azure-cli"
    else
        echo "local"
    fi
}

# Carregar secrets do Azure Key Vault
load_from_azure_keyvault() {
    local vault_name="${VAULT_CONFIGS[$ENV]}"
    
    log "INFO" "Loading secrets from Azure Key Vault: $vault_name"
    
    # Lista de secrets necessários
    local secrets=(
        "postgres-password"
        "postgres-replica-password" 
        "pgladmin-password"
        "jwt-secret"
        "traefik-auth-users"
        "grafana-admin-password"
    )
    
    # Criar arquivo temporário de secrets
    local secrets_file="$PROJECT_ROOT/environments/$ENV/.env.secrets"
    
    echo "# Secrets loaded from Azure Key Vault - $(date)" > "$secrets_file"
    echo "# Environment: $ENV" >> "$secrets_file"
    echo "" >> "$secrets_file"
    
    for secret_name in "${secrets[@]}"; do
        local env_var_name=$(echo "$secret_name" | tr '-' '_' | tr '[:lower:]' '[:upper:]')
        
        # Tentar carregar do Key Vault
        local secret_value
        if secret_value=$(az keyvault secret show \
            --vault-name "$vault_name" \
            --name "$secret_name" \
            --query value \
            --output tsv 2>/dev/null); then
            
            echo "export ${env_var_name}='${secret_value}'" >> "$secrets_file"
            log "SUCCESS" "Loaded: $env_var_name"
        else
            log "WARNING" "Failed to load: $secret_name from Key Vault"
            
            # Fallback para valor default seguro
            case "$secret_name" in
                "postgres-password"|"postgres-replica-password"|"pgladmin-password")
                    local default_pass=$(openssl rand -base64 32)
                    echo "export ${env_var_name}='${default_pass}'" >> "$secrets_file"
                    log "WARNING" "Generated temporary password for: $env_var_name"
                    ;;
                "jwt-secret")
                    local jwt_secret=$(openssl rand -hex 64)
                    echo "export ${env_var_name}='${jwt_secret}'" >> "$secrets_file"
                    log "WARNING" "Generated temporary JWT secret"
                    ;;
                *)
                    echo "export ${env_var_name}='CHANGE_ME_IN_KEYVAULT'" >> "$secrets_file"
                    log "ERROR" "Please set $secret_name in Key Vault: $vault_name"
                    ;;
            esac
        fi
    done
    
    # Proteger o arquivo de secrets
    chmod 600 "$secrets_file"
    log "SUCCESS" "Secrets file created: $secrets_file"
}

# Carregar secrets do GitHub (para CI/CD)
load_from_github_secrets() {
    log "INFO" "Loading secrets from GitHub environment variables"
    
    local secrets_file="$PROJECT_ROOT/environments/$ENV/.env.secrets"
    
    echo "# Secrets loaded from GitHub Actions - $(date)" > "$secrets_file"
    echo "# Environment: $ENV" >> "$secrets_file"
    echo "" >> "$secrets_file"
    
    # Mapear variáveis do GitHub para o formato local
    local github_secrets=(
        "POSTGRES_PASSWORD"
        "POSTGRES_REPLICA_PASSWORD"
        "PGLADMIN_PASSWORD" 
        "JWT_SECRET"
        "TRAEFIK_AUTH_USERS"
        "GRAFANA_ADMIN_PASSWORD"
    )
    
    for secret_var in "${github_secrets[@]}"; do
        if [[ -n "${!secret_var:-}" ]]; then
            echo "export ${secret_var}='${!secret_var}'" >> "$secrets_file"
            log "SUCCESS" "Loaded from GitHub: $secret_var"
        else
            log "ERROR" "Missing GitHub secret: $secret_var"
        fi
    done
    
    chmod 600 "$secrets_file"
}

# Carregar secrets com fallback chain
load_secrets_with_fallback() {
    local runtime_env=$(detect_environment)
    
    log "INFO" "Detected runtime environment: $runtime_env"
    
    case "$runtime_env" in
        "github")
            load_from_github_secrets
            ;;
        "azure"|"azure-cli")
            load_from_azure_keyvault
            ;;
        "local")
            # Para desenvolvimento local, tentar Azure primeiro
            if command -v az &> /dev/null && az account show &> /dev/null; then
                load_from_azure_keyvault
            else
                log "ERROR" "Local development requires Azure CLI authentication"
                log "INFO" "Run: az login"
                exit 1
            fi
            ;;
        *)
            log "ERROR" "Unsupported runtime environment: $runtime_env"
            exit 1
            ;;
    esac
}

# Validar que todos os secrets necessários estão presentes
validate_secrets() {
    log "INFO" "Validating loaded secrets..."
    
    # Carregar o arquivo de secrets
    local secrets_file="$PROJECT_ROOT/environments/$ENV/.env.secrets"
    
    if [[ ! -f "$secrets_file" ]]; then
        log "ERROR" "Secrets file not found: $secrets_file"
        return 1
    fi
    
    source "$secrets_file"
    
    # Verificar secrets críticos
    local critical_secrets=(
        "POSTGRES_PASSWORD"
        "JWT_SECRET"
    )
    
    local missing_secrets=()
    for secret in "${critical_secrets[@]}"; do
        if [[ -z "${!secret:-}" ]] || [[ "${!secret}" == "CHANGE_ME_IN_KEYVAULT" ]]; then
            missing_secrets+=("$secret")
        fi
    done
    
    if [[ ${#missing_secrets[@]} -gt 0 ]]; then
        log "ERROR" "Missing critical secrets: ${missing_secrets[*]}"
        return 1
    fi
    
    log "SUCCESS" "All critical secrets validated"
    return 0
}

# Rotacionar secrets automaticamente
rotate_secrets() {
    log "INFO" "Starting automatic secret rotation for environment: $ENV"
    
    local vault_name="${VAULT_CONFIGS[$ENV]}"
    local rotation_log="$PROJECT_ROOT/logs/secret-rotation-$(date +%Y%m%d).log"
    
    # Criar diretório de logs se não existir
    mkdir -p "$(dirname "$rotation_log")"
    
    # Secrets que podem ser rotacionados automaticamente
    local rotatable_secrets=(
        "jwt-secret"
        "grafana-admin-password"
    )
    
    for secret_name in "${rotatable_secrets[@]}"; do
        log "INFO" "Rotating secret: $secret_name"
        
        local new_value
        case "$secret_name" in
            "jwt-secret")
                new_value=$(openssl rand -hex 64)
                ;;
            "*password*")
                new_value=$(openssl rand -base64 32)
                ;;
            *)
                log "WARNING" "Don't know how to rotate: $secret_name"
                continue
                ;;
        esac
        
        # Fazer backup do valor anterior
        local old_value
        if old_value=$(az keyvault secret show \
            --vault-name "$vault_name" \
            --name "$secret_name" \
            --query value \
            --output tsv 2>/dev/null); then
            
            echo "$(date): $secret_name rotated" >> "$rotation_log"
            echo "  Old value: ${old_value:0:8}..." >> "$rotation_log"
            echo "  New value: ${new_value:0:8}..." >> "$rotation_log"
        fi
        
        # Atualizar no Key Vault
        if az keyvault secret set \
            --vault-name "$vault_name" \
            --name "$secret_name" \
            --value "$new_value" &> /dev/null; then
            
            log "SUCCESS" "Rotated: $secret_name"
        else
            log "ERROR" "Failed to rotate: $secret_name"
        fi
    done
    
    log "SUCCESS" "Secret rotation completed. Log: $rotation_log"
}

# Sincronizar secrets entre ambientes (dev -> staging -> prod)
sync_secrets() {
    local source_env="$1"  
    local target_env="$2"
    
    log "INFO" "Syncing secrets: $source_env -> $target_env"
    
    local source_vault="${VAULT_CONFIGS[$source_env]}"
    local target_vault="${VAULT_CONFIGS[$target_env]}"
    
    # Secrets que podem ser sincronizados (NÃO senhas de produção!)
    local syncable_secrets=()
    
    case "$target_env" in
        "dev"|"staging")
            # Para ambientes não-prod, podemos sincronizar mais secrets
            syncable_secrets=("traefik-auth-users")
            ;;
        "prod")
            # Para produção, só sincronizar configs, nunca secrets sensíveis
            syncable_secrets=()
            log "WARNING" "Production secrets should not be auto-synced"
            ;;
    esac
    
    for secret_name in "${syncable_secrets[@]}"; do
        local secret_value
        if secret_value=$(az keyvault secret show \
            --vault-name "$source_vault" \
            --name "$secret_name" \
            --query value \
            --output tsv 2>/dev/null); then
            
            az keyvault secret set \
                --vault-name "$target_vault" \
                --name "$secret_name" \
                --value "$secret_value" &> /dev/null
                
            log "SUCCESS" "Synced: $secret_name to $target_env"
        fi
    done
}

# Backup de secrets
backup_secrets() {
    log "INFO" "Creating backup of secrets for environment: $ENV"
    
    local vault_name="${VAULT_CONFIGS[$ENV]}"
    local backup_file="$PROJECT_ROOT/backups/secrets-$ENV-$(date +%Y%m%d-%H%M%S).json"
    
    # Criar diretório de backup
    mkdir -p "$(dirname "$backup_file")"
    
    # Exportar todos os secrets (valores mascarados por segurança)
    az keyvault secret list --vault-name "$vault_name" \
        --query '[].{name:name,created:attributes.created}' \
        --output json > "$backup_file"
        
    log "SUCCESS" "Secrets metadata backed up to: $backup_file"
}

# Função principal
main() {
    case "$ACTION" in
        "load")
            load_secrets_with_fallback
            validate_secrets
            ;;
        "rotate")
            rotate_secrets
            ;;
        "sync")
            local target_env="$3"
            if [[ -z "$target_env" ]]; then
                log "ERROR" "Usage: $0 $ENV sync TARGET_ENV"
                exit 1
            fi
            sync_secrets "$ENV" "$target_env"
            ;;
        "backup")
            backup_secrets
            ;;
        "validate")
            validate_secrets
            ;;
        *)
            log "ERROR" "Usage: $0 ENV ACTION [TARGET_ENV]"
            log "INFO" "Actions: load, rotate, sync, backup, validate"
            exit 1
            ;;
    esac
}

# Executar função principal
main "$@"