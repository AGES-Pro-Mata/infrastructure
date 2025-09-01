# Segurança e Gerenciamento de Segredos - Pro-Mata

## 🔒 Visão Geral de Segurança

Este documento descreve as práticas de segurança implementadas na infraestrutura do Pro-Mata, incluindo gerenciamento de segredos, backup e procedimentos de emergência.

## 🗝️ Gerenciamento de Segredos com Ansible Vault

### Estrutura de Segredos por Ambiente

```bash
ansible/
├── inventory/
│   ├── dev/
│   │   └── group_vars/
│   │       └── vault.yml          # Segredos do ambiente dev
│   ├── staging/
│   │   └── group_vars/
│   │       └── vault.yml          # Segredos do ambiente staging
│   └── prod/
│       └── group_vars/
│           └── vault.yml          # Segredos do ambiente prod
└── .vault_pass                    # Senha do vault (NÃO versionar)
```

### Configuração Inicial do Vault

```bash
# 1. Executar script de configuração
./scripts/setup-vault.sh dev

# 2. Editar vault para adicionar credenciais reais
ansible-vault edit ansible/inventory/dev/group_vars/vault.yml --vault-password-file .vault_pass

# 3. Verificar vault
ansible-vault view ansible/inventory/dev/group_vars/vault.yml --vault-password-file .vault_pass
```

### Segredos por Ambiente

#### Desenvolvimento (dev)

```yaml
# Credenciais de banco de dados
vault_postgres_password: "REPLACE_WITH_SECURE_PASSWORD"
vault_postgres_replica_password: "dev_replica_pass_2024"

# Segredos da aplicação
vault_jwt_secret: "dev_jwt_256bit_secret_key_here"

# Credenciais de serviços
vault_traefik_password: "dev_traefik_admin_2024"
vault_traefik_auth_users: "admin:$2y$10$hashed_password_dev"
vault_grafana_admin_password: "dev_grafana_admin_2024"
vault_pgadmin_password: "dev_pgadmin_password_2024"

# Configuração SSL/TLS
vault_acme_email: "devops@promata.com.br"

# Serviços externos
vault_duckdns_token: "duck_dns_token_for_dev_env"
vault_cloudflare_api_token: "REPLACE_WITH_YOUR_CLOUDFLARE_TOKEN"
vault_cloudflare_zone_id: "cf_zone_id_here"

# Chaves de backup e monitoramento
vault_backup_encryption_key: "backup_encryption_key_dev"
vault_prometheus_basic_auth_password: "prometheus_password_dev"
```

#### Staging

```yaml
# Estrutura similar ao dev, mas com valores específicos para staging
vault_postgres_password: "staging_secure_pg_pass_2024"
# ... outros segredos com valores de staging
```

#### Produção

```yaml
# Estrutura similar, mas com valores mais seguros e específicos para prod
vault_postgres_password: "prod_ultra_secure_pg_pass_2024"
# ... outros segredos com valores de produção
```

### Comandos Úteis do Vault

```bash
# Aliases disponíveis (source .vault_aliases)
source .vault_aliases

# Editar vault por ambiente
vault-edit-dev
vault-edit-staging
vault-edit-prod

# Visualizar vault por ambiente
vault-view-dev
vault-view-staging
vault-view-prod

# Criptografar/descriptografar
vault-encrypt-dev
vault-decrypt-dev

# Alterar senha do vault
ansible-vault rekey ansible/inventory/dev/group_vars/vault.yml --vault-password-file .vault_pass
```

### Rotação de Segredos

#### Script de Rotação Automatizada

```bash
#!/bin/bash
# scripts/rotate-secrets.sh

ENVIRONMENT=${1:-dev}
VAULT_FILE="ansible/inventory/$ENVIRONMENT/group_vars/vault.yml"

# Fazer backup do vault atual
cp "$VAULT_FILE" "$VAULT_FILE.backup-$(date +%Y%m%d-%H%M%S)"

# Gerar novos segredos
NEW_POSTGRES_PASSWORD=$(openssl rand -base64 32)
NEW_JWT_SECRET=$(openssl rand -hex 64)
NEW_TRAEFIK_PASSWORD=$(openssl rand -base64 16)

echo "Novos segredos gerados. Atualizando vault..."
# Atualizar vault com novos valores
```

#### Cronograma de Rotação Recomendado

```bash
# Desenvolvimento: A cada 3 meses
# Staging: A cada 2 meses  
# Produção: Mensalmente (ou conforme política de segurança)

# Cronograma de rotação automática
0 2 1 * * /opt/pro-mata/infrastructure/scripts/rotate-secrets.sh prod
0 2 15 * * /opt/pro-mata/infrastructure/scripts/rotate-secrets.sh staging
0 2 1 */3 * /opt/pro-mata/infrastructure/scripts/rotate-secrets.sh dev
```

## 🗄️ Backup e Restauração de Estados Terraform

### Estratégias de Backup

#### 1. Backend Remoto (Produção)

```hcl
# terraform/environments/prod/aws/backend.tf
terraform {
  backend "s3" {
    bucket = "pro-mata-terraform-states"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
    
    # Configurações de segurança
    encrypt                = true
    versioning            = true
    server_side_encryption = "AES256"
  }
}
```

#### 2. Backend Remoto (Dev/Staging)

```hcl
# terraform/environments/dev/azure/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "pro-mata-terraform-state-rg"
    storage_account_name = "promodaterraformstates"
    container_name      = "dev-tfstate"
    key                 = "terraform.tfstate"
    
    # Configurações de segurança
    use_azuread_auth = true
    snapshot         = true
  }
}
```

### Scripts de Backup e Restauração

#### Backup Manual

```bash
# Backup local
./scripts/backup-terraform-state.sh dev local

# Backup para Azure Storage
./scripts/backup-terraform-state.sh dev azure

# Backup para múltiplos destinos
./scripts/backup-terraform-state.sh prod all
```

#### Restauração

```bash
# Listar backups disponíveis
ls -la backups/terraform-state/

# Restaurar de arquivo local
./scripts/restore-terraform-state.sh dev terraform-dev-azure-20240101-120000.tfstate

# Restaurar de Azure Storage
./scripts/restore-terraform-state.sh dev azure:terraform-dev-azure-20240101-120000.tfstate
```

### Backup Automatizado

#### GitHub Actions

```yaml
name: Terraform State Backup
on:
  schedule:
    - cron: '0 2 * * *'  # Diário às 2h UTC

jobs:
  backup-terraform-state:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Azure/AWS CLI
        # ... configuração dos CLIs
        
      - name: Backup Terraform State
        run: |
          ./scripts/backup-terraform-state.sh ${{ matrix.environment }} azure
        env:
          AZURE_CREDENTIALS: ${{ secrets.AZURE_CREDENTIALS }}
```

## 🌐 Configuração Cloudflare

### Tokens de API e Segurança

```bash
# Configuração no vault
vault_cloudflare_api_token: "your_cloudflare_api_token_here"
vault_cloudflare_zone_id: "your_zone_id_here"

# Permissões necessárias no token Cloudflare:
# - Zone:Read
# - DNS:Edit  
# - Zone Settings:Edit (para SSL/TLS)
# - Page Rules:Edit (para otimizações)
```

### Configuração SSL/TLS Segura

```hcl
# Terraform - Configuração SSL progressiva
resource "cloudflare_zone_settings_override" "ssl_settings" {
  zone_id = var.cloudflare_zone_id
  
  settings {
    # Iniciar com "flexible", evoluir para "strict"
    ssl                      = "flexible"  # → "full" → "strict"
    always_use_https        = "on"
    min_tls_version         = "1.2"        # Mínimo recomendado
    opportunistic_encryption = "on"
    tls_1_3                 = "zrt"        # TLS 1.3 quando possível
    
    security_level          = "medium"     # ou "high" para prod
    browser_check          = "on"
    challenge_ttl          = 1800          # 30 minutos
  }
}
```

### Page Rules de Segurança

```hcl
# Regras para proteger endpoints sensíveis
resource "cloudflare_page_rule" "admin_security" {
  zone_id  = var.cloudflare_zone_id
  target   = "admin.promata.com.br/*"
  priority = 1
  
  actions {
    security_level = "high"
    cache_level    = "bypass"
    
    # Apenas para IPs confiáveis em produção
    ip_geolocation = "off"
  }
}

resource "cloudflare_page_rule" "api_rate_limit" {
  zone_id  = var.cloudflare_zone_id
  target   = "api.promata.com.br/*"
  priority = 2
  
  actions {
    cache_level    = "bypass"
    security_level = "medium"
  }
}
```

## 🚨 Procedimentos de Emergência

### Runbook de Emergência

#### 1. Comprometimento de Segredos

```bash
# Ações imediatas:
1. Rotacionar todas as senhas comprometidas
2. Revogar tokens de API expostos
3. Regenerar chaves JWT
4. Notificar equipe de segurança

# Scripts:
./scripts/rotate-secrets.sh prod emergency
./scripts/revoke-api-tokens.sh
```

#### 2. Falha na Infraestrutura

```bash
# Diagnóstico rápido:
1. Verificar status dos serviços
2. Analisar logs de erro
3. Verificar conectividade de rede
4. Validar configurações DNS

# Restauração:
./scripts/restore-terraform-state.sh prod <último_backup_bom>
terraform apply -auto-approve
```

#### 3. Rollback Cloudflare

```bash
# Em caso de problemas com Cloudflare:
1. Acessar https://registro.br/
2. Alterar nameservers de volta para:
   - ns1.registro.br
   - ns2.registro.br
3. Aguardar propagação DNS (2-24h)
4. Flush DNS local para acelerar
```

### Contatos de Emergência

```yaml
# Contatos críticos (armazenar em local seguro)
DevOps_Lead: "devops@promata.com.br"
Infrastructure_Team: "infrastructure@promata.com.br"
Security_Team: "security@promata.com.br"
Escalation: "ages-iii-iv@promata.com.br"

# Suporte de fornecedores
Azure_Support: "Portal Azure → Support"
Cloudflare_Support: "Dashboard → Support"
GitHub_Support: "github.com/contact/support"
```

## 🔐 Melhores Práticas de Segurança

### Desenvolvimento

- ✅ Nunca commitar segredos no código
- ✅ Usar vault para todos os segredos
- ✅ Rotacionar segredos regularmente
- ✅ Revisar logs de auditoria
- ✅ Implementar MFA onde possível

### Production

- ✅ SSL/TLS strict mode
- ✅ Firewall restritivo (apenas IPs necessários)
- ✅ Monitoramento 24/7
- ✅ Backup diário automático
- ✅ Logs centralizados e auditoria
- ✅ Rotação de segredos mensal
- ✅ Testes de recuperação de desastres

### Acesso

- ✅ Princípio do menor privilégio
- ✅ Chaves SSH únicas por usuário
- ✅ Acesso via bastion host em produção
- ✅ Logs de acesso auditados
- ✅ Revisão de permissões trimestral

## 📊 Métricas de Segurança

### KPIs de Segurança

```bash
# Métricas a monitorar:
- Tentativas de login falhadas
- Uso de tokens de API
- Alterações em configurações críticas
- Tempo de resposta a incidentes
- Taxa de rotação de segredos
- Cobertura de backup
```

### Dashboards Recomendados

```bash
# Grafana dashboards:
1. Security Overview
   - Login attempts
   - API usage
   - Certificate expiry
   
2. Infrastructure Health
   - Service availability  
   - Resource usage
   - Backup status
   
3. Network Security
   - Traffic patterns
   - Blocked requests
   - DDoS attempts
```

## 🏥 Testes de Recuperação

### Cronograma de Testes

```bash
# Testes mensais (dev):
- Restauração de backup Terraform
- Recuperação de segredos do vault
- Fallback de DNS

# Testes trimestrais (staging):
- Simulação de compromisso de segredos
- Teste de continuidade de negócio
- Validação de procedures de emergência

# Testes semestrais (prod):
- Disaster Recovery completo
- Auditoria de segurança externa
- Penetration testing
```

### Documentação de Testes

```markdown
# Template de Teste de Recuperação
Data: ___________
Teste: __________
Ambiente: _______

Cenário:
- [ ] Descrição do problema simulado

Procedimentos:
- [ ] Passo 1
- [ ] Passo 2
- [ ] Passo 3

Resultados:
- [ ] Tempo de recuperação
- [ ] Dados perdidos
- [ ] Lições aprendidas

Melhorias:
- [ ] Ação 1
- [ ] Ação 2
```

---

## ✅ Checklist de Implementação

### Configuração Inicial

- [ ] Configurar Ansible Vault para todos os ambientes
- [ ] Implementar backup automatizado do Terraform
- [ ] Configurar Cloudflare com SSL strict
- [ ] Configurar monitoramento de segurança
- [ ] Documentar procedures de emergência
- [ ] Treinar equipe nos procedures

### Manutenção Contínua

- [ ] Rotação mensal de segredos (prod)
- [ ] Backup diário de estados Terraform
- [ ] Revisão semanal de logs de segurança
- [ ] Teste mensal de recuperação
- [ ] Auditoria trimestral de acessos
- [ ] Update semestral de documentação

Este documento deve ser revisado e atualizado regularmente conforme a infraestrutura evolui e novas ameaças são identificadas.
