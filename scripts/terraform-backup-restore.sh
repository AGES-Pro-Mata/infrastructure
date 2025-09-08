#!/bin/bash
# Pro-Mata Terraform State Backup and Restore System
# Sistema completo de backup e recuperação do estado Terraform

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENVIRONMENT="${1:-}"
ACTION="${2:-}"

# Paths
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
BACKUP_DIR="$PROJECT_ROOT/backups/terraform"
CONFIG_FILE="$PROJECT_ROOT/.terraform-backup.conf"

# Default configuration
DEFAULT_REMOTE_BACKEND="azure"  # azure, s3, gcs
DEFAULT_RETENTION_DAYS=30
DEFAULT_COMPRESSION=true

# Logging functions
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }

# Show usage
show_usage() {
    echo "🏗️  Pro-Mata Terraform Backup & Restore System"
    echo "=============================================="
    echo ""
    echo "Usage: $0 <environment> <action> [options]"
    echo ""
    echo "Environments: dev, staging, prod"
    echo ""
    echo "Actions:"
    echo "  backup          - Criar backup do estado atual"
    echo "  restore         - Restaurar de backup"
    echo "  list            - Listar backups disponíveis"
    echo "  clean           - Limpar backups antigos"
    echo "  sync-remote     - Sincronizar com backend remoto"
    echo "  fetch-remote    - Baixar estado do backend remoto"
    echo "  setup           - Configurar sistema de backup"
    echo "  validate        - Validar integridade dos backups"
    echo ""
    echo "Examples:"
    echo "  $0 dev backup"
    echo "  $0 prod restore backup-20240907-143022"
    echo "  $0 staging list"
    echo "  $0 dev sync-remote"
    echo ""
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        # Create default config
        cat > "$CONFIG_FILE" <<EOF
# Pro-Mata Terraform Backup Configuration

# Remote backend type (azure, s3, gcs)
REMOTE_BACKEND="$DEFAULT_REMOTE_BACKEND"

# Backup retention in days
RETENTION_DAYS=$DEFAULT_RETENTION_DAYS

# Enable compression
COMPRESSION=$DEFAULT_COMPRESSION

# Azure Storage (if using Azure backend)
AZURE_STORAGE_ACCOUNT="promatabackups"
AZURE_CONTAINER_NAME="terraform-state"

# AWS S3 (if using S3 backend)
AWS_S3_BUCKET="promata-terraform-backups"
AWS_REGION="us-east-1"

# Google Cloud Storage (if using GCS backend)
GCS_BUCKET="promata-terraform-backups"
GCS_PROJECT="promata-infrastructure"

# Encryption key for local backups (optional)
BACKUP_ENCRYPTION_KEY=""

# Notification webhook (optional)
NOTIFICATION_WEBHOOK=""
EOF
        log "Arquivo de configuração criado: $CONFIG_FILE"
        source "$CONFIG_FILE"
    fi
}

# Validate environment
validate_environment() {
    case "$ENVIRONMENT" in
        dev|staging|prod)
            ;;
        *)
            error "Ambiente inválido: $ENVIRONMENT. Use: dev, staging, prod"
            ;;
    esac
    
    local tf_env_dir="$TERRAFORM_DIR/environments/$ENVIRONMENT"
    if [[ ! -d "$tf_env_dir" ]]; then
        error "Diretório do Terraform não encontrado: $tf_env_dir"
    fi
}

# Check dependencies
check_dependencies() {
    local deps=("terraform")
    
    # Add cloud CLI tools based on backend
    case "$REMOTE_BACKEND" in
        azure) deps+=("az") ;;
        s3) deps+=("aws") ;;
        gcs) deps+=("gcloud") ;;
    esac
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Dependência não encontrada: $dep"
        fi
    done
    
    # Check cloud authentication
    case "$REMOTE_BACKEND" in
        azure)
            if ! az account show &>/dev/null; then
                error "Não logado no Azure. Execute: az login"
            fi
            ;;
        s3)
            if ! aws sts get-caller-identity &>/dev/null; then
                error "Credenciais AWS não configuradas"
            fi
            ;;
        gcs)
            if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &>/dev/null; then
                error "Não logado no Google Cloud. Execute: gcloud auth login"
            fi
            ;;
    esac
}

# Setup backup system
setup_backup_system() {
    log "Configurando sistema de backup para $ENVIRONMENT..."
    
    # Create backup directories
    mkdir -p "$BACKUP_DIR/$ENVIRONMENT"
    mkdir -p "$BACKUP_DIR/$ENVIRONMENT/local"
    mkdir -p "$BACKUP_DIR/$ENVIRONMENT/remote"
    mkdir -p "$BACKUP_DIR/$ENVIRONMENT/automated"
    
    # Create remote storage if needed
    case "$REMOTE_BACKEND" in
        azure)
            if ! az storage container show --name "$AZURE_CONTAINER_NAME" --account-name "$AZURE_STORAGE_ACCOUNT" &>/dev/null; then
                log "Criando container Azure Storage..."
                az storage container create \
                    --name "$AZURE_CONTAINER_NAME" \
                    --account-name "$AZURE_STORAGE_ACCOUNT" \
                    --public-access off
            fi
            ;;
        s3)
            if ! aws s3 ls "s3://$AWS_S3_BUCKET" &>/dev/null; then
                log "Criando bucket S3..."
                aws s3 mb "s3://$AWS_S3_BUCKET" --region "$AWS_REGION"
                aws s3api put-bucket-versioning \
                    --bucket "$AWS_S3_BUCKET" \
                    --versioning-configuration Status=Enabled
            fi
            ;;
        gcs)
            if ! gsutil ls "gs://$GCS_BUCKET" &>/dev/null; then
                log "Criando bucket GCS..."
                gsutil mb -p "$GCS_PROJECT" "gs://$GCS_BUCKET"
                gsutil versioning set on "gs://$GCS_BUCKET"
            fi
            ;;
    esac
    
    # Create automated backup script
    create_automated_backup_script
    
    log "✅ Sistema de backup configurado"
}

# Create automated backup script
create_automated_backup_script() {
    local cron_script="$BACKUP_DIR/automated-backup.sh"
    
    cat > "$cron_script" <<EOF
#!/bin/bash
# Automated Terraform Backup Script
# Add to crontab: 0 */6 * * * $cron_script

cd "$PROJECT_ROOT"

# Backup all environments
for env in dev staging prod; do
    echo "Backing up \$env environment..."
    $0 \$env backup --automated
done

# Clean old backups
for env in dev staging prod; do
    echo "Cleaning old backups for \$env..."
    $0 \$env clean
done
EOF

    chmod +x "$cron_script"
    log "Script de backup automatizado criado: $cron_script"
}

# Backup terraform state
backup_state() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="backup-$timestamp"
    local tf_dir="$TERRAFORM_DIR/environments/$ENVIRONMENT"
    local backup_path="$BACKUP_DIR/$ENVIRONMENT/local/$backup_name"
    
    log "Criando backup do estado Terraform para $ENVIRONMENT..."
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    cd "$tf_dir"
    
    # Ensure Terraform is initialized
    if [[ ! -d ".terraform" ]]; then
        log "Inicializando Terraform..."
        terraform init
    fi
    
    # Pull latest state from remote
    log "Atualizando estado local..."
    terraform refresh
    
    # Create backup metadata
    cat > "$backup_path/metadata.json" <<EOF
{
    "timestamp": "$timestamp",
    "environment": "$ENVIRONMENT",
    "terraform_version": "$(terraform version -json | jq -r '.terraform_version')",
    "backend_type": "$REMOTE_BACKEND",
    "created_by": "$(whoami)",
    "hostname": "$(hostname)",
    "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "git_branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
}
EOF
    
    # Backup terraform state
    if [[ -f "terraform.tfstate" ]]; then
        cp "terraform.tfstate" "$backup_path/"
        log "✅ Estado local copiado"
    fi
    
    # Backup remote state
    if terraform state pull > "$backup_path/terraform.tfstate.remote" 2>/dev/null; then
        log "✅ Estado remoto baixado"
    else
        warn "Não foi possível baixar o estado remoto"
    fi
    
    # Backup terraform configuration
    tar -czf "$backup_path/terraform-config.tar.gz" \
        --exclude='.terraform' \
        --exclude='*.tfstate*' \
        --exclude='*.backup' \
        .
    
    # Backup .terraform directory (without providers)
    if [[ -d ".terraform" ]]; then
        tar -czf "$backup_path/terraform-metadata.tar.gz" \
            --exclude='.terraform/providers' \
            .terraform/
    fi
    
    # Compress backup if enabled
    if [[ "$COMPRESSION" == "true" ]]; then
        cd "$BACKUP_DIR/$ENVIRONMENT/local"
        tar -czf "$backup_name.tar.gz" "$backup_name/"
        rm -rf "$backup_name"
        log "✅ Backup comprimido"
        backup_path="$backup_path.tar.gz"
    fi
    
    # Upload to remote storage
    upload_to_remote_storage "$backup_path" "$backup_name"
    
    # Create symlink to latest backup
    cd "$BACKUP_DIR/$ENVIRONMENT/local"
    ln -sf "$(basename "$backup_path")" "latest"
    
    log "✅ Backup criado: $backup_name"
    
    # Send notification if configured
    if [[ -n "$NOTIFICATION_WEBHOOK" ]]; then
        send_notification "✅ Terraform backup created for $ENVIRONMENT" "$backup_name"
    fi
}

# Upload backup to remote storage
upload_to_remote_storage() {
    local backup_path="$1"
    local backup_name="$2"
    local remote_path="$ENVIRONMENT/$backup_name"
    
    case "$REMOTE_BACKEND" in
        azure)
            log "Enviando backup para Azure Storage..."
            if [[ -f "$backup_path" ]]; then
                az storage blob upload \
                    --file "$backup_path" \
                    --name "$remote_path.tar.gz" \
                    --container-name "$AZURE_CONTAINER_NAME" \
                    --account-name "$AZURE_STORAGE_ACCOUNT" \
                    --overwrite
            else
                # Upload directory
                az storage blob upload-batch \
                    --source "$backup_path" \
                    --destination "$AZURE_CONTAINER_NAME/$remote_path" \
                    --account-name "$AZURE_STORAGE_ACCOUNT"
            fi
            ;;
        s3)
            log "Enviando backup para S3..."
            if [[ -f "$backup_path" ]]; then
                aws s3 cp "$backup_path" "s3://$AWS_S3_BUCKET/$remote_path.tar.gz"
            else
                aws s3 sync "$backup_path" "s3://$AWS_S3_BUCKET/$remote_path/"
            fi
            ;;
        gcs)
            log "Enviando backup para Google Cloud Storage..."
            if [[ -f "$backup_path" ]]; then
                gsutil cp "$backup_path" "gs://$GCS_BUCKET/$remote_path.tar.gz"
            else
                gsutil -m rsync -r "$backup_path" "gs://$GCS_BUCKET/$remote_path/"
            fi
            ;;
    esac
    
    log "✅ Backup enviado para armazenamento remoto"
}

# List available backups
list_backups() {
    log "Backups disponíveis para $ENVIRONMENT:"
    echo ""
    
    # Local backups
    echo "📁 Backups Locais:"
    local local_backup_dir="$BACKUP_DIR/$ENVIRONMENT/local"
    if [[ -d "$local_backup_dir" ]]; then
        for backup in "$local_backup_dir"/backup-* "$local_backup_dir"/*.tar.gz; do
            if [[ -e "$backup" ]]; then
                local name=$(basename "$backup")
                local size=$(du -h "$backup" | cut -f1)
                local date=$(stat -c %y "$backup" 2>/dev/null || stat -f %Sm "$backup" 2>/dev/null || echo "unknown")
                echo "  📦 $name ($size) - $date"
            fi
        done
    else
        echo "  Nenhum backup local encontrado"
    fi
    
    echo ""
    
    # Remote backups
    echo "☁️  Backups Remotos:"
    list_remote_backups
}

# List remote backups
list_remote_backups() {
    case "$REMOTE_BACKEND" in
        azure)
            az storage blob list \
                --container-name "$AZURE_CONTAINER_NAME" \
                --account-name "$AZURE_STORAGE_ACCOUNT" \
                --prefix "$ENVIRONMENT/" \
                --query "[].{Name:name, Size:properties.contentLength, Modified:properties.lastModified}" \
                --output table 2>/dev/null || echo "  Erro ao listar backups remotos"
            ;;
        s3)
            aws s3 ls "s3://$AWS_S3_BUCKET/$ENVIRONMENT/" --recursive --human-readable 2>/dev/null || echo "  Erro ao listar backups remotos"
            ;;
        gcs)
            gsutil ls -l "gs://$GCS_BUCKET/$ENVIRONMENT/" 2>/dev/null || echo "  Erro ao listar backups remotos"
            ;;
    esac
}

# Restore from backup
restore_backup() {
    local backup_name="${3:-latest}"
    local tf_dir="$TERRAFORM_DIR/environments/$ENVIRONMENT"
    local backup_path="$BACKUP_DIR/$ENVIRONMENT/local/$backup_name"
    
    if [[ "$backup_name" == "latest" ]]; then
        backup_path="$BACKUP_DIR/$ENVIRONMENT/local/latest"
        if [[ -L "$backup_path" ]]; then
            backup_path=$(readlink -f "$backup_path")
            backup_name=$(basename "$backup_path")
        else
            error "Symlink 'latest' não encontrado"
        fi
    fi
    
    log "Restaurando backup: $backup_name para $ENVIRONMENT..."
    
    # Check if backup exists locally
    if [[ ! -e "$backup_path" ]]; then
        log "Backup não encontrado localmente, tentando baixar do remoto..."
        download_from_remote_storage "$backup_name"
        
        if [[ ! -e "$backup_path" ]]; then
            error "Backup não encontrado: $backup_name"
        fi
    fi
    
    # Create safety backup of current state
    local safety_backup="$BACKUP_DIR/$ENVIRONMENT/local/safety-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$safety_backup"
    
    cd "$tf_dir"
    if [[ -f "terraform.tfstate" ]]; then
        cp "terraform.tfstate" "$safety_backup/"
        log "✅ Backup de segurança criado"
    fi
    
    # Extract and restore backup
    local restore_dir="$backup_path"
    if [[ -f "$backup_path" && "$backup_path" == *.tar.gz ]]; then
        # Extract compressed backup
        restore_dir="/tmp/terraform-restore-$$"
        mkdir -p "$restore_dir"
        tar -xzf "$backup_path" -C "$restore_dir" --strip-components=1
    fi
    
    # Restore state files
    if [[ -f "$restore_dir/terraform.tfstate.remote" ]]; then
        # Push remote state
        log "Restaurando estado remoto..."
        terraform state push "$restore_dir/terraform.tfstate.remote"
        log "✅ Estado remoto restaurado"
    elif [[ -f "$restore_dir/terraform.tfstate" ]]; then
        # Copy local state
        cp "$restore_dir/terraform.tfstate" .
        log "✅ Estado local restaurado"
    fi
    
    # Restore configuration if needed
    if [[ -f "$restore_dir/terraform-config.tar.gz" ]]; then
        echo -n "Restaurar configuração do Terraform também? (y/N): "
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            tar -xzf "$restore_dir/terraform-config.tar.gz"
            log "✅ Configuração restaurada"
        fi
    fi
    
    # Clean up temporary files
    if [[ "$restore_dir" != "$backup_path" ]]; then
        rm -rf "$restore_dir"
    fi
    
    log "✅ Restauração concluída"
    
    # Verify restoration
    if terraform validate &>/dev/null; then
        log "✅ Configuração validada"
    else
        warn "⚠️  Configuração inválida após restauração"
    fi
}

# Download backup from remote storage
download_from_remote_storage() {
    local backup_name="$1"
    local remote_path="$ENVIRONMENT/$backup_name"
    local local_path="$BACKUP_DIR/$ENVIRONMENT/local/$backup_name"
    
    log "Baixando backup do armazenamento remoto..."
    
    case "$REMOTE_BACKEND" in
        azure)
            az storage blob download \
                --name "$remote_path.tar.gz" \
                --container-name "$AZURE_CONTAINER_NAME" \
                --account-name "$AZURE_STORAGE_ACCOUNT" \
                --file "$local_path.tar.gz"
            ;;
        s3)
            aws s3 cp "s3://$AWS_S3_BUCKET/$remote_path.tar.gz" "$local_path.tar.gz"
            ;;
        gcs)
            gsutil cp "gs://$GCS_BUCKET/$remote_path.tar.gz" "$local_path.tar.gz"
            ;;
    esac
    
    log "✅ Backup baixado"
}

# Fetch state from remote backend
fetch_remote_state() {
    local tf_dir="$TERRAFORM_DIR/environments/$ENVIRONMENT"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local fetch_path="$BACKUP_DIR/$ENVIRONMENT/remote/fetch-$timestamp"
    
    log "Baixando estado atual do backend remoto..."
    
    mkdir -p "$fetch_path"
    cd "$tf_dir"
    
    # Initialize if needed
    if [[ ! -d ".terraform" ]]; then
        terraform init
    fi
    
    # Pull remote state
    if terraform state pull > "$fetch_path/terraform.tfstate" 2>/dev/null; then
        log "✅ Estado remoto baixado: $fetch_path/terraform.tfstate"
        
        # Create metadata
        cat > "$fetch_path/metadata.json" <<EOF
{
    "timestamp": "$timestamp",
    "environment": "$ENVIRONMENT",
    "action": "fetch_remote",
    "backend_type": "$REMOTE_BACKEND"
}
EOF
        
        # Create symlink to latest fetch
        cd "$BACKUP_DIR/$ENVIRONMENT/remote"
        ln -sf "fetch-$timestamp" "latest"
        
        log "✅ Estado remoto salvo em: $fetch_path"
    else
        error "Falha ao baixar estado remoto"
    fi
}

# Sync with remote backend
sync_remote_backend() {
    local tf_dir="$TERRAFORM_DIR/environments/$ENVIRONMENT"
    
    log "Sincronizando com backend remoto..."
    
    cd "$tf_dir"
    
    # Initialize and refresh
    terraform init
    terraform refresh
    
    log "✅ Sincronização concluída"
}

# Clean old backups
clean_old_backups() {
    log "Limpando backups antigos (mais de $RETENTION_DAYS dias)..."
    
    # Clean local backups
    find "$BACKUP_DIR/$ENVIRONMENT/local" -name "backup-*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$BACKUP_DIR/$ENVIRONMENT/local" -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    # Clean remote backups (implementation depends on cloud provider)
    case "$REMOTE_BACKEND" in
        azure)
            # Azure has lifecycle management policies
            log "Configure lifecycle policies no Azure Storage para limpeza automática"
            ;;
        s3)
            # S3 has lifecycle policies
            log "Configure lifecycle policies no S3 para limpeza automática"
            ;;
        gcs)
            # GCS has lifecycle policies
            log "Configure lifecycle policies no GCS para limpeza automática"
            ;;
    esac
    
    log "✅ Limpeza concluída"
}

# Validate backup integrity
validate_backups() {
    log "Validando integridade dos backups..."
    
    local errors=0
    
    for backup in "$BACKUP_DIR/$ENVIRONMENT/local"/backup-* "$BACKUP_DIR/$ENVIRONMENT/local"/*.tar.gz; do
        if [[ -e "$backup" ]]; then
            local name=$(basename "$backup")
            echo -n "  Validando $name... "
            
            if [[ "$backup" == *.tar.gz ]]; then
                if tar -tzf "$backup" &>/dev/null; then
                    echo "✅"
                else
                    echo "❌"
                    errors=$((errors + 1))
                fi
            else
                if [[ -f "$backup/terraform.tfstate" || -f "$backup/terraform.tfstate.remote" ]]; then
                    echo "✅"
                else
                    echo "❌"
                    errors=$((errors + 1))
                fi
            fi
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        log "✅ Todos os backups são válidos"
    else
        warn "⚠️  $errors backups com problemas encontrados"
    fi
}

# Send notification
send_notification() {
    local message="$1"
    local details="${2:-}"
    
    if [[ -n "$NOTIFICATION_WEBHOOK" ]]; then
        curl -X POST "$NOTIFICATION_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"$message\", \"details\": \"$details\"}" \
            &>/dev/null || true
    fi
}

# Main function
main() {
    if [[ $# -lt 2 ]]; then
        show_usage
        exit 1
    fi
    
    load_config
    validate_environment
    check_dependencies
    
    case "$ACTION" in
        backup)
            backup_state
            ;;
        restore)
            restore_backup "$@"
            ;;
        list)
            list_backups
            ;;
        clean)
            clean_old_backups
            ;;
        sync-remote)
            sync_remote_backend
            ;;
        fetch-remote)
            fetch_remote_state
            ;;
        setup)
            setup_backup_system
            ;;
        validate)
            validate_backups
            ;;
        *)
            error "Ação inválida: $ACTION"
            ;;
    esac
}

# Run main function
main "$@"