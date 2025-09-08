#!/bin/bash
# Pro-Mata Ansible Vault Setup and Management
# Este script configura o Ansible Vault para gerenciamento seguro de secrets

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENVIRONMENT="${1:-dev}"

# Paths
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
INVENTORY_DIR="$ANSIBLE_DIR/inventory/$ENVIRONMENT"
VAULT_FILE="$INVENTORY_DIR/group_vars/vault.yml"
VAULT_PASS_FILE="$PROJECT_ROOT/.vault_pass"

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check dependencies
check_dependencies() {
    log "Verificando dependências..."
    
    if ! command -v ansible-vault &> /dev/null; then
        error "ansible-vault não está instalado. Execute: pip install ansible"
    fi
    
    if ! command -v openssl &> /dev/null; then
        error "openssl não está instalado"
    fi
    
    if ! command -v htpasswd &> /dev/null; then
        warn "htpasswd não está instalado. Algumas senhas não serão geradas automaticamente"
    fi
    
    log "✅ Dependências verificadas"
}

# Create directory structure
setup_directories() {
    log "Criando estrutura de diretórios..."
    
    mkdir -p "$INVENTORY_DIR/group_vars"
    mkdir -p "$INVENTORY_DIR/host_vars"
    mkdir -p "$ANSIBLE_DIR/playbooks"
    mkdir -p "$ANSIBLE_DIR/roles"
    
    log "✅ Estrutura de diretórios criada"
}

# Generate vault password
generate_vault_password() {
    if [[ ! -f "$VAULT_PASS_FILE" ]]; then
        log "Gerando senha do vault..."
        openssl rand -base64 32 > "$VAULT_PASS_FILE"
        chmod 600 "$VAULT_PASS_FILE"
        log "✅ Senha do vault gerada em $VAULT_PASS_FILE"
    else
        info "Senha do vault já existe em $VAULT_PASS_FILE"
    fi
}

# Generate secure passwords
generate_secure_password() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Generate bcrypt hash for passwords
generate_bcrypt_hash() {
    local password="$1"
    if command -v htpasswd &> /dev/null; then
        echo "$(htpasswd -nbB "" "$password" | cut -d: -f2)"
    else
        # Fallback - just return the password with a note
        echo "$password # TODO: Generate bcrypt hash manually"
    fi
}

# Create vault file with secrets
create_vault_file() {
    log "Criando arquivo vault para ambiente $ENVIRONMENT..."
    
    # Generate environment-specific passwords
    local postgres_password db_replica_password jwt_secret
    local traefik_password grafana_password pgadmin_password
    local prometheus_password backup_key api_key webhook_secret
    
    case "$ENVIRONMENT" in
        "dev")
            postgres_password="dev_$(generate_secure_password 16)"
            db_replica_password="repl_$(generate_secure_password 16)"
            jwt_secret="$(generate_secure_password 64)"
            traefik_password="$(generate_secure_password 16)"
            grafana_password="$(generate_secure_password 16)"
            pgadmin_password="$(generate_secure_password 16)"
            prometheus_password="$(generate_secure_password 16)"
            backup_key="$(generate_secure_password 32)"
            api_key="$(generate_secure_password 32)"
            webhook_secret="$(generate_secure_password 24)"
            ;;
        "staging")
            postgres_password="stg_$(generate_secure_password 24)"
            db_replica_password="repl_$(generate_secure_password 24)"
            jwt_secret="$(generate_secure_password 64)"
            traefik_password="$(generate_secure_password 20)"
            grafana_password="$(generate_secure_password 20)"
            pgladmin_password="$(generate_secure_password 20)"
            prometheus_password="$(generate_secure_password 20)"
            backup_key="$(generate_secure_password 32)"
            api_key="$(generate_secure_password 32)"
            webhook_secret="$(generate_secure_password 24)"
            ;;
        "prod")
            postgres_password="$(generate_secure_password 32)"
            db_replica_password="$(generate_secure_password 32)"
            jwt_secret="$(generate_secure_password 64)"
            traefik_password="$(generate_secure_password 24)"
            grafana_password="$(generate_secure_password 24)"
            pgadmin_password="$(generate_secure_password 24)"
            prometheus_password="$(generate_secure_password 24)"
            backup_key="$(generate_secure_password 32)"
            api_key="$(generate_secure_password 32)"
            webhook_secret="$(generate_secure_password 24)"
            ;;
    esac
    
    # Generate Traefik basic auth hash
    local traefik_auth_hash
    traefik_auth_hash="admin:$(generate_bcrypt_hash "$traefik_password")"
    
    # Create temporary vault file
    cat > "$VAULT_FILE.tmp" <<EOF
---
# Ansible Vault para ambiente $ENVIRONMENT
# Criado em: $(date)
# ATENÇÃO: Este arquivo contém informações sensíveis

# === CREDENCIAIS DO BANCO DE DADOS ===
vault_postgres_password: "$postgres_password"
vault_postgres_replica_password: "$db_replica_password"

# === SEGREDOS DA APLICAÇÃO ===
vault_jwt_secret: "$jwt_secret"

# === CREDENCIAIS DOS SERVIÇOS ===
# Traefik Proxy
vault_traefik_password: "$traefik_password"
vault_traefik_auth_users: "$traefik_auth_hash"

# Grafana
vault_grafana_admin_password: "$grafana_password"

# PgAdmin
vault_pgadmin_password: "$pgadmin_password"

# Prometheus
vault_prometheus_password: "$prometheus_password"

# === CONFIGURAÇÃO SSL/TLS ===
vault_acme_email: "admin@promata.com.br"

# === SERVIÇOS EXTERNOS ===
# Cloudflare (preencher manualmente)
vault_cloudflare_api_token: "CHANGE_ME_cloudflare_api_token"
vault_cloudflare_zone_id: "CHANGE_ME_cloudflare_zone_id"
vault_cloudflare_email: "admin@promata.com.br"

# === BACKUP E SEGURANÇA ===
vault_backup_encryption_key: "$backup_key"

# === API KEYS ===
vault_api_key: "$api_key"
vault_webhook_secret: "$webhook_secret"

# === MONITORAMENTO ===
vault_prometheus_basic_auth_password: "$prometheus_password"

# === CONFIGURAÇÃO POR AMBIENTE ===
vault_environment: "$ENVIRONMENT"

# === SECRETS ESPECÍFICOS DO $ENVIRONMENT ===
vault_debug_mode: $([ "$ENVIRONMENT" = "prod" ] && echo "false" || echo "true")
vault_log_level: $([ "$ENVIRONMENT" = "prod" ] && echo "warn" || echo "debug")

# === AZURE/AWS SECRETS (preencher conforme necessário) ===
# Azure
vault_azure_tenant_id: "CHANGE_ME_azure_tenant_id"
vault_azure_subscription_id: "CHANGE_ME_azure_subscription_id"
vault_azure_client_id: "CHANGE_ME_azure_client_id"
vault_azure_client_secret: "CHANGE_ME_azure_client_secret"

# AWS (para produção)
vault_aws_access_key_id: "CHANGE_ME_aws_access_key_id"
vault_aws_secret_access_key: "CHANGE_ME_aws_secret_access_key"
vault_aws_region: "us-east-1"

# === NOTIFICAÇÕES ===
vault_slack_webhook_url: "CHANGE_ME_slack_webhook_url"
vault_discord_webhook_url: "CHANGE_ME_discord_webhook_url"

# === BACKUP REMOTO ===
vault_backup_s3_bucket: "promata-backups-$ENVIRONMENT"
vault_backup_s3_access_key: "CHANGE_ME_s3_access_key"
vault_backup_s3_secret_key: "CHANGE_ME_s3_secret_key"
EOF

    log "✅ Arquivo vault temporário criado"
}

# Encrypt vault file
encrypt_vault_file() {
    log "Criptografando arquivo vault..."
    
    ansible-vault encrypt "$VAULT_FILE.tmp" --vault-password-file "$VAULT_PASS_FILE"
    mv "$VAULT_FILE.tmp" "$VAULT_FILE"
    
    log "✅ Arquivo vault criptografado: $VAULT_FILE"
}

# Create ansible configuration
create_ansible_config() {
    log "Criando configuração do Ansible..."
    
    cat > "$PROJECT_ROOT/ansible.cfg" <<EOF
[defaults]
inventory = ansible/inventory/$ENVIRONMENT/hosts.yml
vault_password_file = .vault_pass
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
bin_ansible_callbacks = True
gathering = smart
fact_caching = memory
fact_caching_timeout = 86400

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
pipelining = True
control_path = ~/.ansible/cp/%%h-%%p-%%r

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
EOF

    log "✅ Configuração do Ansible criada"
}

# Create hosts file
create_hosts_file() {
    log "Criando arquivo de hosts para $ENVIRONMENT..."
    
    cat > "$INVENTORY_DIR/hosts.yml" <<EOF
---
all:
  children:
    managers:
      hosts:
        vm-pro-mata-$ENVIRONMENT-manager:
          ansible_host: "{{ vault_manager_ip | default('CHANGE_ME_manager_ip') }}"
          ansible_user: ubuntu
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
          ansible_python_interpreter: /usr/bin/python3
          node_role: manager
          node_labels:
            environment: $ENVIRONMENT
            database.primary: true
            
    workers:
      hosts:
        # Adicionar workers conforme necessário
        # vm-pro-mata-$ENVIRONMENT-worker-1:
        #   ansible_host: "{{ vault_worker_1_ip | default('CHANGE_ME_worker_1_ip') }}"
        #   ansible_user: ubuntu
        #   node_role: worker
        
  vars:
    ansible_ssh_private_key_file: "~/.ssh/promata_$ENVIRONMENT"
    ansible_become: true
    ansible_become_method: sudo
EOF

    log "✅ Arquivo de hosts criado"
}

# Create group vars
create_group_vars() {
    log "Criando variáveis do grupo..."
    
    cat > "$INVENTORY_DIR/group_vars/all.yml" <<EOF
---
# Variáveis globais para ambiente $ENVIRONMENT
environment: $ENVIRONMENT

# Configuração do domínio
domain_name: $([ "$ENVIRONMENT" = "prod" ] && echo "promata.com.br" || echo "$ENVIRONMENT.promata.com.br")

# Imagens Docker
backend_image: "norohim/pro-mata-backend$([ "$ENVIRONMENT" = "prod" ] && echo "" || echo "-$ENVIRONMENT"):latest"
frontend_image: "norohim/pro-mata-frontend$([ "$ENVIRONMENT" = "prod" ] && echo "" || echo "-$ENVIRONMENT"):latest"
database_image: "norohim/pro-mata-database-infrastructure:latest"

# Configuração de réplicas
backend_replicas: $([ "$ENVIRONMENT" = "prod" ] && echo "3" || echo "1")
frontend_replicas: $([ "$ENVIRONMENT" = "prod" ] && echo "2" || echo "1")

# Configuração de recursos
postgres_memory_limit: $([ "$ENVIRONMENT" = "prod" ] && echo "2G" || echo "1G")
postgres_cpu_limit: $([ "$ENVIRONMENT" = "prod" ] && echo "1.5" || echo "0.8")

# Features
monitoring_enabled: true
backup_enabled: true
analytics_enabled: $([ "$ENVIRONMENT" = "prod" ] && echo "true" || echo "false")

# Configuração do PgBouncer
pgbouncer_pool_mode: transaction
pgbouncer_max_client_conn: $([ "$ENVIRONMENT" = "prod" ] && echo "500" || echo "200")
pgbouncer_pool_size: $([ "$ENVIRONMENT" = "prod" ] && echo "50" || echo "25")

# Configuração de backup
backup_retention_days: $([ "$ENVIRONMENT" = "prod" ] && echo "30" || echo "7")

# Configuração de logs
log_level: "{{ vault_log_level }}"
debug_mode: "{{ vault_debug_mode }}"
EOF

    log "✅ Variáveis do grupo criadas"
}

# Create vault management aliases
create_vault_aliases() {
    log "Criando aliases para gerenciamento do vault..."
    
    cat > "$PROJECT_ROOT/.vault_aliases" <<EOF
#!/bin/bash
# Aliases do Ansible Vault para Pro-Mata
# Execute: source .vault_aliases

# Aliases específicos do ambiente $ENVIRONMENT
alias vault-edit-$ENVIRONMENT='ansible-vault edit $VAULT_FILE --vault-password-file $VAULT_PASS_FILE'
alias vault-view-$ENVIRONMENT='ansible-vault view $VAULT_FILE --vault-password-file $VAULT_PASS_FILE'
alias vault-decrypt-$ENVIRONMENT='ansible-vault decrypt $VAULT_FILE --vault-password-file $VAULT_PASS_FILE'
alias vault-encrypt-$ENVIRONMENT='ansible-vault encrypt $VAULT_FILE --vault-password-file $VAULT_PASS_FILE'

# Aliases gerais do vault
alias vault-create='ansible-vault create --vault-password-file $VAULT_PASS_FILE'
alias vault-rekey='ansible-vault rekey --vault-password-file $VAULT_PASS_FILE'
alias vault-validate='ansible-vault view $VAULT_FILE --vault-password-file $VAULT_PASS_FILE > /dev/null && echo "✅ Vault válido" || echo "❌ Vault inválido"'

# Teste de conectividade
alias ansible-ping-$ENVIRONMENT='ansible all -i $INVENTORY_DIR/hosts.yml -m ping'

# Deploy commands
alias deploy-$ENVIRONMENT='ansible-playbook -i $INVENTORY_DIR/hosts.yml --vault-password-file $VAULT_PASS_FILE ansible/playbooks/deploy.yml'

echo "🔐 Aliases do Vault carregados para ambiente $ENVIRONMENT"
echo "📋 Aliases disponíveis:"
echo "  vault-edit-$ENVIRONMENT    - Editar vault"
echo "  vault-view-$ENVIRONMENT    - Visualizar vault"
echo "  vault-validate        - Validar vault"
echo "  ansible-ping-$ENVIRONMENT - Testar conectividade"
echo "  deploy-$ENVIRONMENT       - Fazer deploy"
EOF

    chmod +x "$PROJECT_ROOT/.vault_aliases"
    log "✅ Aliases criados em $PROJECT_ROOT/.vault_aliases"
}

# Update gitignore
update_gitignore() {
    log "Atualizando .gitignore..."
    
    local gitignore="$PROJECT_ROOT/.gitignore"
    
    # Add vault-related entries
    local vault_entries=(
        "# Ansible Vault"
        ".vault_pass"
        "ansible-vault-password"
        "*.vault_tmp"
        "vault.yml.tmp"
        ""
        "# Ansible"
        "*.retry"
        ".ansible/"
        ""
    )
    
    # Check if security section exists
    if ! grep -q "# Ansible Vault" "$gitignore" 2>/dev/null; then
        echo "" >> "$gitignore"
        for entry in "${vault_entries[@]}"; do
            echo "$entry" >> "$gitignore"
        done
        log "✅ Entradas do vault adicionadas ao .gitignore"
    else
        info ".gitignore já contém entradas do vault"
    fi
}

# Create CI/CD helper script
create_cicd_helper() {
    log "Criando script helper para CI/CD..."
    
    cat > "$PROJECT_ROOT/scripts/setup-cicd-secrets.sh" <<'EOF'
#!/bin/bash
# Helper para configurar secrets do CI/CD
# Este script ajuda a extrair secrets do vault para configuração do CI/CD

ENV=${1:-dev}
VAULT_FILE="ansible/inventory/$ENV/group_vars/vault.yml"
VAULT_PASS_FILE=".vault_pass"

if [[ ! -f "$VAULT_FILE" ]]; then
    echo "❌ Arquivo vault não encontrado: $VAULT_FILE"
    exit 1
fi

if [[ ! -f "$VAULT_PASS_FILE" ]]; then
    echo "❌ Arquivo de senha do vault não encontrado: $VAULT_PASS_FILE"
    exit 1
fi

echo "🤖 Secrets para configurar no GitHub Actions ($ENV):"
echo "================================================================"
echo ""

# Extract secrets from vault
ansible-vault view "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE" | \
grep -E "^vault_.*:" | \
while IFS=': ' read -r key value; do
    # Convert vault_key_name to GITHUB_SECRET_NAME
    github_secret=$(echo "$key" | sed 's/^vault_//' | tr '[:lower:]' '[:upper:]' | tr '_' '_')
    # Remove quotes from value
    clean_value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
    
    if [[ "$clean_value" =~ ^CHANGE_ME_ ]]; then
        echo "# $github_secret=$clean_value  # ⚠️  PRECISA SER ALTERADO"
    else
        echo "$github_secret=$clean_value"
    fi
done

echo ""
echo "📋 Secrets adicionais necessários:"
echo "ANSIBLE_VAULT_PASSWORD=<conteúdo do arquivo .vault_pass>"
echo "DEV_SSH_PRIVATE_KEY=<chave SSH privada para acesso ao servidor>"
echo "DEV_SERVER_IP=<IP do servidor de desenvolvimento>"
echo ""
echo "💡 Para configurar no GitHub:"
echo "1. Vá em Settings > Secrets and variables > Actions"
echo "2. Adicione cada secret listado acima"
echo "3. Teste o workflow de deploy"
EOF

    chmod +x "$PROJECT_ROOT/scripts/setup-cicd-secrets.sh"
    log "✅ Script helper para CI/CD criado"
}

# Test vault
test_vault() {
    log "Testando vault..."
    
    # Test decryption
    if ansible-vault view "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE" > /dev/null 2>&1; then
        log "✅ Vault pode ser descriptografado com sucesso"
    else
        error "❌ Falha ao descriptografar o vault"
    fi
    
    # Test ansible configuration
    if ansible --version > /dev/null 2>&1; then
        log "✅ Ansible configurado corretamente"
    else
        warn "⚠️  Problemas na configuração do Ansible"
    fi
}

# Main setup function
main() {
    echo "🔐 Configurando Ansible Vault para ambiente: $ENVIRONMENT"
    echo "================================================================"
    
    check_dependencies
    setup_directories
    generate_vault_password
    
    if [[ -f "$VAULT_FILE" ]]; then
        warn "Arquivo vault já existe: $VAULT_FILE"
        echo -n "Deseja sobrescrever? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            log "Mantendo arquivo vault existente"
            return 0
        fi
        
        # Backup existing vault
        cp "$VAULT_FILE" "$VAULT_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        log "✅ Backup criado do vault existente"
    fi
    
    create_vault_file
    encrypt_vault_file
    create_ansible_config
    create_hosts_file
    create_group_vars
    create_vault_aliases
    update_gitignore
    create_cicd_helper
    test_vault
    
    echo ""
    log "🎉 Setup do Ansible Vault concluído!"
    echo ""
    echo "📋 Próximos passos:"
    echo "1. Editar o vault para adicionar valores reais:"
    echo "   ansible-vault edit $VAULT_FILE --vault-password-file $VAULT_PASS_FILE"
    echo ""
    echo "2. Configurar IPs dos servidores no arquivo de hosts:"
    echo "   vim $INVENTORY_DIR/hosts.yml"
    echo ""
    echo "3. Carregar aliases do vault:"
    echo "   source .vault_aliases"
    echo ""
    echo "4. Testar conectividade:"
    echo "   ansible all -i $INVENTORY_DIR/hosts.yml -m ping"
    echo ""
    echo "5. Configurar secrets do CI/CD:"
    echo "   ./scripts/setup-cicd-secrets.sh $ENVIRONMENT"
    echo ""
    warn "⚠️  IMPORTANTE: Guarde com segurança o arquivo .vault_pass!"
    warn "⚠️  Não commite arquivos .vault_pass ou secrets em texto claro!"
}

# Run main function
main "$@"