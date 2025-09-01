# 🏗️ Proposta de Reorganização da Estrutura do Repositório Pro-Mata

## 📊 Análise dos Problemas Atuais

### ❌ Problemas Identificados

1. **Pastas com Nomes Duplicados**
   - `environments/` (raiz)
   - `config/environments/`
   - `terraform/environments/`

2. **Confusão de Responsabilidades**
   - Arquivos de configuração misturados com código Terraform
   - Backend configs espalhados em múltiplos locais
   - Módulos duplicados em diferentes locais

3. **Paths Inconsistentes**
   - Makefile referencia diferentes estruturas
   - Scripts apontam para locais conflitantes
   - CI/CD workflows usam paths inconsistentes

## 🎯 Estrutura Proposta

### 📁 Nova Estrutura Organizacional

```text
infrastructure/
├── .github/                           # GitHub workflows
│   └── workflows/
├── envs/                             # ✨ NOVO: Unified environment configs
│   ├── dev/
│   │   ├── .env                      # Environment variables
│   │   ├── terraform.tfvars          # Terraform variables
│   │   ├── ansible-vars.yml          # Ansible variables
│   │   └── secrets/
│   │       └── vault.yml             # Encrypted secrets
│   ├── staging/
│   │   ├── .env
│   │   ├── terraform.tfvars
│   │   ├── ansible-vars.yml
│   │   └── secrets/
│   │       └── vault.yml
│   └── prod/
│       ├── .env
│       ├── terraform.tfvars
│       ├── ansible-vars.yml
│       └── secrets/
│           └── vault.yml
├── terraform/                        # ✨ REORGANIZADO: Terraform puro
│   ├── providers.tf                  # Global providers
│   ├── variables.tf                  # Global variables
│   ├── backends/                     # ✨ NOVO: Backend configurations
│   │   ├── dev.tf                    # Azure backend for dev
│   │   ├── staging.tf                # Azure backend for staging
│   │   └── prod.tf                   # AWS backend for prod
│   ├── modules/                      # Reusable modules
│   │   ├── azure/
│   │   │   ├── vm/
│   │   │   ├── network/
│   │   │   ├── storage/
│   │   │   └── monitoring/
│   │   ├── aws/
│   │   │   ├── ec2/
│   │   │   ├── vpc/
│   │   │   ├── s3/
│   │   │   └── cloudwatch/
│   │   └── shared/
│   │       ├── dns/                  # Cloudflare DNS
│   │       ├── docker/
│   │       └── monitoring/
│   └── deployments/                  # ✨ NOVO: Environment deployments
│       ├── dev/
│       │   ├── main.tf               # Environment-specific resources
│       │   ├── variables.tf          # Local variables
│       │   └── outputs.tf            # Outputs
│       ├── staging/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── prod/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── ansible/                          # Configuration management
│   ├── inventory/
│   │   ├── dev/
│   │   │   ├── hosts.yml
│   │   │   └── group_vars/
│   │   ├── staging/
│   │   │   ├── hosts.yml
│   │   │   └── group_vars/
│   │   └── prod/
│   │       ├── hosts.yml
│   │       └── group_vars/
│   ├── playbooks/
│   ├── roles/
│   └── templates/
├── docker/                           # Docker configurations
│   ├── stacks/                      # Docker compose stacks
│   ├── configs/                     # Service configurations
│   └── images/                      # Custom Dockerfiles
├── scripts/                          # Automation scripts
│   ├── setup/                       # Setup and initialization
│   ├── deploy/                      # Deployment scripts
│   ├── backup/                      # Backup and restore
│   ├── security/                    # Security and validation
│   └── utils/                       # Utility scripts
├── docs/                            # Documentation
│   ├── architecture/
│   ├── deployment/
│   ├── security/
│   └── troubleshooting/
├── tests/                           # ✨ NOVO: Infrastructure tests
│   ├── terraform/
│   ├── ansible/
│   └── integration/
├── tools/                           # ✨ NOVO: Development tools
│   ├── hooks/                       # Git hooks
│   ├── linters/                     # Code quality tools
│   └── validators/                  # Configuration validators
├── backups/                         # Local backups
│   ├── terraform-state/
│   ├── ansible-vault/
│   └── configurations/
├── Makefile                         # Build automation
├── README.md                        # Project documentation
└── .gitignore                       # Git ignore rules
```

## 🔄 Plano de Migração

### Fase 1: Preparação (Sem Impacto)
1. Criar nova estrutura de diretórios
2. Migrar configurações para `envs/`
3. Reorganizar módulos Terraform
4. Consolidar scripts em categorias

### Fase 2: Migração Gradual
1. Atualizar Makefile para nova estrutura
2. Migrar workflows do GitHub Actions
3. Atualizar documentação
4. Testar em ambiente de desenvolvimento

### Fase 3: Consolidação
1. Remover estruturas antigas
2. Limpar arquivos duplicados
3. Validar todos os ambientes
4. Documentar nova estrutura

## 🚀 Benefícios da Nova Estrutura

### 1. ✨ Clareza e Simplicidade
- **Uma pasta por responsabilidade**: Sem duplicações confusas
- **Nomenclatura intuitiva**: `envs/` ao invés de múltiplas `environments/`
- **Organização lógica**: Agrupamento por função, não por ferramenta

### 2. 🔧 Facilidade de Manutenção
- **Configurações centralizadas**: Todas as configs de ambiente em `envs/`
- **Módulos reutilizáveis**: Melhor organização dos módulos Terraform
- **Scripts categorizados**: Fácil localização de ferramentas

### 3. 🔒 Segurança Aprimorada
- **Secrets isolados**: Pasta `secrets/` dedicada por ambiente
- **Validação centralizada**: Scripts de validação organizados
- **Backup estruturado**: Backups categorizados por tipo

### 4. 🚀 Developer Experience
- **Paths intuitivos**: Sem confusão entre diferentes `environments/`
- **Documentação estruturada**: Docs organizados por categoria
- **Testes incluídos**: Pasta dedicada para testes de infraestrutura

## 📝 Exemplo de Uso da Nova Estrutura

### Comandos Atualizados
```bash
# Configuração de ambiente
cp envs/dev/.env.example envs/dev/.env
vim envs/dev/.env

# Deploy Terraform
cd terraform/deployments/dev
terraform init -backend-config=../../backends/dev.tf
terraform plan -var-file=../../../envs/dev/terraform.tfvars

# Deploy Ansible
ansible-playbook -i ansible/inventory/dev/hosts.yml \
                 -e @envs/dev/ansible-vars.yml \
                 --vault-password-file envs/dev/secrets/.vault_pass \
                 ansible/playbooks/deploy.yml

# Scripts organizados
./scripts/setup/init-environment.sh dev
./scripts/deploy/full-deploy.sh dev
./scripts/backup/backup-state.sh dev
```

### Makefile Simplificado
```makefile
ENV ?= dev
ENV_DIR := envs/$(ENV)
TF_DIR := terraform/deployments/$(ENV)

deploy:
	@echo "🚀 Deploying $(ENV) environment..."
	@./scripts/deploy/full-deploy.sh $(ENV)

init-env:
	@echo "🔧 Initializing $(ENV) environment..."
	@./scripts/setup/init-environment.sh $(ENV)

backup:
	@echo "💾 Backing up $(ENV) environment..."
	@./scripts/backup/backup-all.sh $(ENV)
```

## 🎯 Scripts de Migração Automática

Vou criar scripts para automatizar a migração:

1. **`migrate-structure.sh`**: Migração automática da estrutura
2. **`validate-migration.sh`**: Validação pós-migração
3. **`cleanup-old.sh`**: Limpeza da estrutura antiga

## 🔍 Validação da Proposta

### Checklist de Validação
- [ ] ✨ Elimina duplicação de pastas `environments/`
- [ ] 🎯 Centraliza configurações em local único
- [ ] 🔧 Simplifica paths e referencias
- [ ] 📚 Melhora organização da documentação
- [ ] 🔒 Aprimora estrutura de segurança
- [ ] 🚀 Facilita onboarding de novos desenvolvedores
- [ ] 🔄 Mantém compatibilidade durante transição

Esta proposta resolve os problemas atuais e estabelece uma base sólida para o crescimento futuro do projeto.
