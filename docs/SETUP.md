# ⚙️ Setup e Configuração

Este guia detalha como configurar e deployar a infraestrutura do Pro-Mata.

## 📋 Pré-requisitos

### Ferramentas Necessárias

```bash
# Terraform
terraform --version  # >= 1.8.0

# Ansible  
ansible --version    # >= 8.5.0

# Docker (para desenvolvimento local)
docker --version     # >= 24.0.0

# AWS CLI (para produção)
aws --version        # >= 2.0.0

# Azure CLI (para dev/staging)
az --version         # >= 2.0.0
```

### Credenciais e Acessos

#### AWS (Produção)

```bash
# Configurar AWS CLI
aws configure
# AWS Access Key ID: [sua-chave]
# AWS Secret Access Key: [sua-chave-secreta]
# Default region name: us-east-1
# Default output format: json
```

#### Azure (Dev/Staging)

```bash
# Login Azure CLI
az login
az account set --subscription "sua-subscription-id"
```

#### GitHub Container Registry

```bash
# Configurar acesso ao GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

## 🌐 Configuração por Ambiente

### 🧪 Development (Azure)

#### 1. Configurar Variáveis de Desenvolvimento

```bash
cd environments/dev/
cp .env.dev.example .env.dev
```

Editar `.env.dev`:

```bash
# Azure Configuration
AZURE_SUBSCRIPTION_ID=sua-subscription-id
AZURE_RESOURCE_GROUP=pro-mata-dev-rg
AZURE_LOCATION=eastus2

# Application
ENVIRONMENT=development
BACKEND_IMAGE=ghcr.io/ages-pro-mata/backend:latest
FRONTEND_IMAGE=ghcr.io/ages-pro-mata/frontend:latest

# Database
POSTGRES_DB=pro_mata_dev
POSTGRES_USER=app_user
POSTGRES_PASSWORD=secure_password_here

# Redis
REDIS_PASSWORD=redis_password_here
```

#### 2. Deploy Infraestrutura Azure

```bash
cd terraform/azure/
terraform init
terraform plan -var-file="../../environments/dev/.env.dev"
terraform apply -var-file="../../environments/dev/.env.dev"
```

#### 3. Configurar Docker Swarm

```bash
cd deployment/ansible/
ansible-playbook playbooks/swarm_setup.yml -i inventory/dev
```

### 🌟 Production (AWS)

#### 1. Configurar Variáveis de Produção

```bash
cd environments/prod/
cp .env.prod.example .env.prod
```

Editar `.env.prod`:

```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012

# Application
ENVIRONMENT=production
BACKEND_IMAGE=ghcr.io/ages-pro-mata/backend:latest
FRONTEND_IMAGE=ghcr.io/ages-pro-mata/frontend:latest

# Database
POSTGRES_DB=pro_mata_prod
POSTGRES_USER=app_user
POSTGRES_PASSWORD=ultra_secure_password_here

# Redis
REDIS_PASSWORD=redis_ultra_secure_password

# Load Balancer
DOMAIN_NAME=app.promata.com
SSL_CERTIFICATE_ARN=arn:aws:acm:us-east-1:123456789012:certificate/xxx
```

#### 2. Deploy Infraestrutura AWS

```bash
cd terraform/aws/
terraform init
terraform plan -var-file="../../environments/prod/.env.prod"
terraform apply -var-file="../../environments/prod/.env.prod"
```

## 🔧 Comandos Úteis

### Terraform

```bash
# Validar configuração
terraform validate

# Formatar arquivos
terraform fmt

# Ver estado atual
terraform show

# Destruir infraestrutura
terraform destroy
```

### Ansible

```bash
# Testar conectividade
ansible all -m ping -i inventory/dev

# Executar playbook específico
ansible-playbook playbooks/swarm_setup.yml -i inventory/dev

# Modo dry-run
ansible-playbook playbooks/swarm_setup.yml -i inventory/dev --check
```

### Docker Swarm

```bash
# Ver status do cluster
docker node ls

# Listar serviços
docker service ls

# Ver logs de um serviço
docker service logs pro-mata-backend

# Escalar serviço
docker service scale pro-mata-backend=3
```

## 🐛 Troubleshooting

### Problemas Comuns

#### 1. Erro de Autenticação Azure

```bash
# Renovar token
az login --use-device-code

# Verificar subscription ativa
az account show
```

#### 2. Terraform State Lock

```bash
# Forçar unlock (use com cuidado!)
terraform force-unlock LOCK_ID
```

#### 3. Docker Swarm não conecta

```bash
# Verificar firewall
sudo ufw status

# Verificar conectividade de rede
telnet <node-ip> 2377
```

#### 4. Imagens não fazem pull

```bash
# Verificar login no registry
docker system info | grep Registry

# Re-login
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

## 📊 Monitoramento

### Health Checks

```bash
# Backend health
curl https://api.promata.com/health

# Frontend health  
curl https://app.promata.com/health

# Database connection
PGPASSWORD=$POSTGRES_PASSWORD psql -h $DB_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT 1;"
```

### Logs

```bash
# Docker Swarm logs
docker service logs -f pro-mata-backend

# AWS ECS logs
aws logs tail /aws/ecs/pro-mata-backend --follow

# Azure Container logs
az container logs --resource-group pro-mata-dev-rg --name pro-mata-backend
```

## � Atualizações

### Atualizar Imagens

```bash
# Azure (Docker Swarm)
docker service update --image ghcr.io/ages-pro-mata/backend:latest pro-mata-backend

# AWS (ECS)
aws ecs update-service --cluster pro-mata-prod --service pro-mata-backend --force-new-deployment
```

### Rollback

```bash
# Docker Swarm rollback
docker service rollback pro-mata-backend

# AWS ECS rollback
aws ecs update-service --cluster pro-mata-prod --service pro-mata-backend --task-definition pro-mata-backend:PREVIOUS_REVISION
```

## 📚 Próximos Passos

1. Configurar monitoramento avançado (Prometheus/Grafana)
2. Implementar backups automáticos
3. Configurar alertas
4. Documentar procedimentos de disaster recovery
