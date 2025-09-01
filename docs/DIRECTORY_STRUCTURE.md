# Estrutura de Diretórios - Pro-Mata Infrastructure

Esta é a nova estrutura organizacional da infraestrutura Pro-Mata, reorganizada para melhor modularidade, segurança e manutenibilidade.

## 📁 Estrutura Atual

```
infrastructure/
├── ansible/                          # Ansible configurations
│   ├── inventory/                    # Environment-specific inventories  
│   │   ├── dev/
│   │   │   ├── group_vars/
│   │   │   │   └── vault.yml         # Encrypted secrets (Ansible Vault)
│   │   │   └── host_vars/
│   │   ├── staging/
│   │   │   ├── group_vars/
│   │   │   │   └── vault.yml
│   │   │   └── host_vars/
│   │   └── prod/
│   │       ├── group_vars/
│   │       │   └── vault.yml
│   │       └── host_vars/
│   ├── playbooks/                    # Ansible playbooks
│   ├── roles/                        # Ansible roles
│   └── templates/                    # Jinja2 templates
├── terraform/                        # Terraform configurations
│   ├── providers.tf                  # Global providers config
│   ├── variables.tf                  # Global variables
│   ├── modules/                      # Reusable Terraform modules
│   │   ├── dns/                      # Cloudflare DNS module
│   │   │   ├── cloudflare.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── network/                  # Networking module
│   │   ├── compute/                  # VM/instances module
│   │   ├── storage/                  # Storage module
│   │   └── monitoring/               # Monitoring module
│   └── environments/                 # Environment-specific configs
│       ├── dev/
│       │   └── azure/                # Azure configuration for dev
│       │       ├── main.tf
│       │       ├── variables.tf
│       │       ├── outputs.tf
│       │       ├── providers.tf
│       │       └── cloud-init.yml
│       ├── staging/
│       │   └── azure/                # Azure configuration for staging
│       └── prod/
│           └── aws/                  # AWS configuration for prod
├── config/                           # Configuration files
│   └── environments/                 # Environment variables
│       ├── dev/
│       │   └── .env.dev             # Development environment config
│       ├── staging/
│       │   └── .env.staging         # Staging environment config
│       └── prod/
│           └── .env.prod            # Production environment config
├── docker/                          # Docker configurations
│   ├── stacks/                      # Docker stack files
│   └── configs/                     # Service configurations
├── scripts/                         # Automation scripts
│   ├── setup-vault.sh               # Ansible Vault setup
│   ├── backup-terraform-state.sh    # State backup script
│   ├── restore-terraform-state.sh   # State restore script
│   ├── validate-infrastructure.sh   # Infrastructure validation
│   └── test-cloudflare-setup.sh     # Cloudflare testing
├── backups/                         # Local backups
│   └── terraform-state/             # Terraform state backups
├── docs/                            # Documentation
│   ├── SECURITY.md                  # Security procedures
│   └── DIRECTORY_STRUCTURE.md       # This file
├── .github/                         # GitHub workflows
├── Makefile                         # Build automation
└── README.md                        # Project documentation
```

## 🔄 Migração da Estrutura Antiga

### Estrutura Anterior
```
infrastructure/
├── environments/
│   ├── dev/azure/                   # Terraform configs misturados
│   ├── backend.tf                   # Backend configs espalhados
│   └── modules/dns/cloudfare.tf     # Módulos dentro de environments
└── ansible/                         # Configurações básicas
```

### Estrutura Nova (Implementada)
```
infrastructure/
├── terraform/                       # Terraform isolado e modular
│   ├── providers.tf                # Providers centralizados
│   ├── variables.tf                # Variáveis globais
│   ├── modules/                    # Módulos reutilizáveis
│   └── environments/               # Configs específicas por ambiente
├── config/                         # Configurações separadas
├── ansible/                        # Ansible expandido com vault
└── scripts/                        # Automação expandida
```

## 🏗️ Benefícios da Nova Estrutura

### 1. Separação de Responsabilidades
- **Terraform**: Apenas infraestrutura
- **Config**: Apenas configurações de ambiente
- **Ansible**: Apenas provisionamento e deploy
- **Scripts**: Apenas automação

### 2. Modularidade
- Módulos Terraform reutilizáveis entre ambientes
- Configurações específicas por ambiente isoladas
- Vault separado por ambiente para segurança

### 3. Segurança Aprimorada
- Ansible Vault por ambiente
- Backups automatizados de estado
- Scripts de validação e teste

### 4. Manutenibilidade
- Estrutura clara e previsível
- Documentação centralizada
- Scripts de automação padronizados

## 🔧 Como Usar a Nova Estrutura

### Comandos Makefile Atualizados

```bash
# Setup inicial
make vault-setup ENV=dev              # Configurar vault de segredos

# Deploy e validação
make deploy-automated ENV=dev         # Deploy completo automatizado
make infrastructure-validate ENV=dev  # Validar infraestrutura
make cloudflare-test                  # Testar configuração Cloudflare

# Backup e segurança
make backup-state ENV=dev             # Backup do estado Terraform
```

### Trabalhando com Terraform

```bash
# Navegar para o ambiente
cd terraform/environments/dev/azure/

# Comandos terraform normais
terraform init
terraform plan
terraform apply

# Usar módulos
module "cloudflare_dns" {
  source = "../../../modules/dns"
  # ... configurações
}
```

### Trabalhando com Ansible Vault

```bash
# Setup do vault
./scripts/setup-vault.sh dev

# Editar secrets
ansible-vault edit ansible/inventory/dev/group_vars/vault.yml --vault-password-file .vault_pass

# Visualizar secrets
ansible-vault view ansible/inventory/dev/group_vars/vault.yml --vault-password-file .vault_pass
```

## 📋 Checklist de Migração

### ✅ Concluído
- [x] Estrutura de diretórios criada
- [x] Módulo Cloudflare DNS implementado
- [x] Ansible Vault configurado por ambiente
- [x] Scripts de backup/restore criados
- [x] Scripts de validação implementados
- [x] Makefile atualizado com novos paths
- [x] Documentação de segurança criada

### 🔄 Em Progresso
- [ ] Migração completa de todos os ambientes
- [ ] Testes dos novos scripts em todos os ambientes
- [ ] Configuração de CI/CD atualizada

### 📝 Próximos Passos
- [ ] Implementar módulos adicionais (network, compute, storage)
- [ ] Configurar backend remoto para todos os ambientes
- [ ] Implementar automação completa de rotação de secrets
- [ ] Configurar monitoramento da nova estrutura

## 🎯 Migração de Ambiente Existente

Se você tem um ambiente existente, siga estes passos:

### 1. Backup do Estado Atual
```bash
# Backup do estado existente
cp environments/dev/azure/terraform.tfstate backups/terraform-state/terraform-dev-azure-migration-$(date +%Y%m%d).tfstate
```

### 2. Configurar Nova Estrutura
```bash
# Setup vault para o ambiente
make vault-setup ENV=dev

# Copiar configurações existentes
cp environments/dev/.env.dev config/environments/dev/
```

### 3. Migrar Estado Terraform
```bash
# Mover arquivos terraform
mv environments/dev/azure/* terraform/environments/dev/azure/

# Reinicializar terraform na nova localização
cd terraform/environments/dev/azure/
terraform init
```

### 4. Validar Migração
```bash
# Validar nova estrutura
make infrastructure-validate ENV=dev

# Testar configurações
make cloudflare-test
```

## 🚨 Problemas Comuns e Soluções

### Estado Terraform Perdido
```bash
# Restaurar de backup
./scripts/restore-terraform-state.sh dev backup-file.tfstate
```

### Vault Password Perdida
```bash
# Recriar vault (CUIDADO: perde dados)
rm ansible/inventory/dev/group_vars/vault.yml
make vault-setup ENV=dev
```

### Conflitos de Path
```bash
# Verificar paths no Makefile
grep -n "environments/" Makefile
# Devem apontar para terraform/environments/
```

## 📚 Referências

- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/)
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)

Esta nova estrutura proporciona uma base sólida para o crescimento e manutenção da infraestrutura Pro-Mata, seguindo as melhores práticas da indústria.