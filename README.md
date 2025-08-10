# 🏗️ Pro-Mata Infrastructure

Repositório de infraestrutura do projeto Pro-Mata AGES, contendo configurações Terraform, playbooks Ansible, workflows CI/CD e scripts de automação.

## 📁 Visão Geral

Este repositório implementa uma estratégia de **monitoramento de infraestrutura**, onde mudanças em arquivos de build são detectadas e implantadas automaticamente, sem construção local de imagens Docker.

## 🌐 Arquitetura

### 🧪 **Ambientes de Desenvolvimento**

- **Azure East US 2**: Development & Staging
- **Orquestração**: Docker Swarm
- **Infraestrutura**: Terraform + Ansible

### 🌟 **Ambiente de Produção**

- **AWS US East 1**: Production
- **Orquestração**: Amazon ECS Fargate
- **Balanceamento**: Application Load Balancer

## 🚀 Quick Start

### 1. Pré-requisitos

```bash
# Instalar dependências
terraform --version  # >= 1.8.0
ansible --version    # >= 8.5.0
```

### 2. Configurar Ambiente

```bash
# Clonar repositório
git clone <repo-url>
cd infra/

# Configurar variáveis de ambiente
cp environments/dev/.env.dev.example environments/dev/.env.dev
# Editar com suas configurações
```

### 3. Deploy Desenvolvimento (Azure)

```bash
# Inicializar Terraform
cd terraform/azure/
terraform init
terraform plan
terraform apply

# Configurar Docker Swarm
cd ../../deployment/ansible/
ansible-playbook playbooks/swarm_setup.yml
```

### 4. Deploy Produção (AWS)

```bash
# Deploy AWS ECS
cd terraform/aws/
terraform init
terraform plan
terraform apply
```

## 📊 Container Registry

Todas as imagens são armazenadas em:

```text
ghcr.io/ages-pro-mata/backend:latest
ghcr.io/ages-pro-mata/frontend:latest
```

## 🔧 Workflows CI/CD

| Workflow | Status | Descrição |
|----------|---------|-----------|
| `ci-cd.yml` | `DISABLED` | Pipeline principal (monitoramento) |
| `discord-notify-extended.yml` | `ACTIVE` | Notificações Discord |
| `gitlab-sync.yml` | `ACTIVE` | Sincronização GitLab |
| `notify-pr.yml` | `ACTIVE` | Notificações de PR |

## 📚 Documentação

- [📋 Estrutura Completa](./docs/STRUCTURE.md)
- [⚙️ Configuração](./docs/SETUP.md)
- [🔧 Troubleshooting](./docs/TROUBLESHOOTING.md)

## 🤝 Como Contribuir

1. Crie uma branch feature
2. Faça suas alterações
3. Teste localmente
4. Abra um Pull Request

## 📄 Licença

MIT License - veja [LICENSE](LICENSE) para detalhes.

Este repositório contém toda a infraestrutura como código (IaC) para o projeto Pro-Mata AGES PUCRS.

> **⚠️ STATUS ATUAL**: Os workflows de deployment estão temporariamente desabilitados. Apenas sincronização com GitLab e notificações estão ativos.

## 📋 Visão Geral

O repositório de infraestrutura é responsável por:

- ⚙️ Provisionamento de recursos cloud (Azure/AWS) - **DESABILITADO**
- 🚀 Pipelines de deployment automatizado - **DESABILITADO**
- 📊 Monitoramento de mudanças em builds - **DESABILITADO**
- 🔄 Sincronização com GitLab AGES - **ATIVO**
- � Sistema de notificações - **ATIVO**

## 🏗️ Arquitetura

### Ambientes de Deploy

- **Development**: Azure (East US 2) - Docker Swarm
- **Staging**: Azure (East US 2) - Docker Swarm  
- **Production**: AWS (US East 1) - ECS Fargate

### Stack Tecnológico

- **IaC**: Terraform 1.8.0
- **Orquestração**: Ansible 8.5.0
- **Containers**: Docker, Docker Swarm, ECS
- **CI/CD**: GitHub Actions
- **Monitoramento**: CloudWatch, Azure Monitor

## 📁 Estrutura do Repositório

```text
infra/
├── .github/workflows/           # GitHub Actions workflows (padrão frontend)
│   ├── ci-cd.yml               # Pipeline principal (DESABILITADO)
│   ├── discord-notify-extended.yml  # Notificações Discord
│   ├── gitlab-sync.yml         # Sincronização GitLab
│   └── notify-pr.yml           # Notificações de PR
├── environments/               # Configurações por ambiente
│   ├── dev/                   # Desenvolvimento
│   ├── staging/               # Staging
│   └── prod/                  # Produção
├── terraform/                 # Módulos Terraform
├── ansible/                   # Playbooks Ansible
├── scripts/                   # Scripts de automação
│   ├── sync-infrastructure.py # Sincronização GitLab
│   ├── notify-deployment.sh   # Notificações Discord
│   ├── rollback.sh           # Rollback automatizado
│   └── test-infrastructure.sh # Testes de infraestrutura
└── docs/                     # Documentação
```

## 🚀 Como Usar

> **⚠️ IMPORTANTE**: Os deployments estão temporariamente desabilitados. Para reativar, remova `if: false` dos workflows de deployment.

### Workflows Ativos

#### 1. Sincronização GitLab (Automática)

- Executa a cada 30 minutos
- Sincroniza issues, PRs e código com GitLab AGES
- Pode ser executada manualmente

#### 2. Notificações Discord (Automática)

- Envia notificações para Discord
- Monitora atividades do repositório (issues, PRs, deployments)
- Notificações estendidas para eventos específicos

#### 3. Notificações de PR (Automática)

- Notifica abertura, fechamento e merge de PRs
- Integrado com sistema de Discord
- Executa automaticamente em mudanças de PR

### Workflows Desabilitados (CI/CD)

Para reativar o pipeline de deployment, edite `.github/workflows/ci-cd.yml` e remova:

```yaml
if: false  # 🚫 DISABLED
```

## 🧪 Testes

### Executar Testes de Infraestrutura

```bash
# Todos os testes
./scripts/test-infrastructure.sh

# Apenas Terraform
./scripts/test-infrastructure.sh --type terraform --environment dev

# Dry run
./scripts/test-infrastructure.sh --dry-run --verbose

# Testar endpoints de produção
./scripts/test-infrastructure.sh --type endpoints --environment prod --provider aws
```

### Validações Incluídas

- ✅ Sintaxe Terraform
- ✅ Validação de playbooks Ansible
- ✅ Conectividade de endpoints
- ✅ Validação de workflows GitHub Actions
- ✅ Sintaxe de scripts Python/Shell

## 🔄 Rollback

Em caso de problemas, use o script de rollback:

```bash
# Rollback desenvolvimento
./scripts/rollback.sh --environment dev --provider azure

# Rollback produção (com confirmação)
./scripts/rollback.sh --environment prod --provider aws

# Dry run do rollback
./scripts/rollback.sh --environment staging --provider azure --dry-run
```

## 📊 Monitoramento

### Health Checks Automáticos

- **Development**: <https://dev.promata.ages.pucrs.br>
- **Staging**: <https://staging.promata.ages.pucrs.br>
- **Production**: <https://promata.ages.pucrs.br>

### Notificações Discord

O sistema envia notificações automáticas via Discord para:

- ✅ Deployments bem-sucedidos
- ❌ Falhas de deployment
- 🔄 Rollbacks executados
- 🏗️ Atualizações de infraestrutura

## 🔧 Configuração

### Secrets Necessários

#### GitHub Secrets

```text
GITLAB_TOKEN=xxx               # Token GitLab AGES
GITLAB_PROJECT_ID=xxx          # ID do projeto GitLab
GIT_TOKEN=xxx                  # Token GitHub

# Azure (Dev/Staging)
AZURE_CREDENTIALS=xxx          # Service Principal JSON
SSH_PRIVATE_KEY_DEV=xxx        # Chave SSH desenvolvimento  
SSH_PRIVATE_KEY_STAGING=xxx    # Chave SSH staging

# AWS (Production)
AWS_ACCESS_KEY_ID=xxx          # Access Key AWS
AWS_SECRET_ACCESS_KEY=xxx      # Secret Key AWS
SSH_PRIVATE_KEY_PROD=xxx       # Chave SSH produção

# Notificações
DISCORD_WEBHOOK_URL=xxx        # Webhook Discord
```

#### GitHub Variables

```text
GITLAB_URL=https://tools.ages.pucrs.br
```

### Configuração de Ambientes

Cada ambiente possui:

- `variables.tfvars` - Variáveis Terraform
- `docker-compose.template.yml` - Template Docker Compose
- `inventory.yml` - Inventário Ansible (Azure environments)

## 📚 Links Úteis

### Aplicações

- 🧪 **Dev**: [App](https://dev.promata.ages.pucrs.br) | [API](https://api-dev.promata.ages.pucrs.br)
- 🎭 **Staging**: [App](https://staging.promata.ages.pucrs.br) | [API](https://api-staging.promata.ages.pucrs.br)
- 🌟 **Prod**: [App](https://promata.ages.pucrs.br) | [API](https://api.promata.ages.pucrs.br)

### Repositórios Relacionados

- 🌐 [Frontend](https://github.com/AGES-Pro-Mata/frontend)
- 🖥️ [Backend](https://github.com/AGES-Pro-Mata/backend)
- 🗄️ [Database](https://github.com/AGES-Pro-Mata/database)

### GitLab AGES

- 🦊 [Projeto GitLab](https://tools.ages.pucrs.br/pro-mata/infra)
- 📋 [Board Kanban](https://tools.ages.pucrs.br/pro-mata/infra/-/boards)

## 🔒 Segurança

### Práticas Implementadas

- 🔐 Rotação automática de secrets
- 🛡️ Validação de imagens antes do deploy
- 🔍 Scan de vulnerabilidades em containers
- 📊 Monitoramento de segurança contínuo
- 🚨 Alertas automáticos para falhas críticas

### Tags de Produção

Apenas tags estáveis são aceitas em produção:

- ✅ `latest`
- ✅ `v1.2.3` (semver)
- ❌ `dev`, `feature-*`

## 🤝 Contribuição

### Workflow de Mudanças

1. Criar branch `feature/nome-da-mudanca`
2. Fazer alterações e testar localmente
3. Executar `./scripts/test-infrastructure.sh`
4. Criar Pull Request
5. Aguardar review e merge

### Padrões de Commit

```text
feat(terraform): adiciona suporte para Azure Container Instances
fix(ansible): corrige configuração de nginx
docs(readme): atualiza instruções de deployment
```

## 📞 Suporte

- 💬 **Discord**: Canal #infra-pro-mata
- 📧 **Email**: <promata@ages.pucrs.br>
- 🐛 **Issues**: [GitHub Issues](https://github.com/AGES-Pro-Mata/infra/issues)

---

**Pro-Mata Infrastructure System - AGES PUCRS**  
*Infraestrutura como Código para o Sistema Pro-Mata*
