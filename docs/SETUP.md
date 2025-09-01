# ⚙️ Pro-Mata Infrastructure Setup

Detailed configuration guide for Pro-Mata infrastructure deployment.

## 📋 Prerequisites

### Tools Required

```bash
terraform --version  # >= 1.8.0
ansible --version    # >= 8.5.0
docker --version     # >= 24.0.0
az --version         # Azure CLI (dev)
aws --version        # AWS CLI (prod)
```

### Authentication

```bash
# Azure (Development)
az login
az account set --subscription "your-subscription-id"

# AWS (Production) 
aws configure
```

## 🌐 Environment Configuration

### Development (Azure)

```bash
cd environments/dev/
cp .env.dev.example .env.dev
```

Key variables in `.env.dev`:

```bash
# Azure
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_RESOURCE_GROUP=pro-mata-dev-rg
AZURE_LOCATION=eastus2

# Application
BACKEND_IMAGE=norohim/pro-mata-backend-dev
FRONTEND_IMAGE=norohim/pro-mata-frontend-dev

# Database
POSTGRES_PASSWORD=CHANGE_ME_SECURE_PASSWORD_HERE
REDIS_PASSWORD=redis_password_here

# DNS
DOMAIN_NAME=promata.com.br
```

### Production (AWS)

```bash
cd environments/prod/
cp .env.prod.example .env.prod
```

Key variables in `.env.prod`:

```bash
# AWS
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012

# Application  
BACKEND_IMAGE=norohim/pro-mata-backend:latest
FRONTEND_IMAGE=norohim/pro-mata-frontend:latest

# Database
POSTGRES_PASSWORD=CHANGE_ME_ULTRA_SECURE_PASSWORD_HERE
REDIS_PASSWORD=redis_ultra_secure_password

# Load Balancer
DOMAIN_NAME=app.promata.com  
SSL_CERTIFICATE_ARN=arn:aws:acm:us-east-1:123456789012:certificate/xxx
```

## 🚀 Deployment Steps

### Development Deployment

```bash
# Infrastructure
cd environments/dev/azure/
terraform init
terraform plan
terraform apply

# Configuration
cd ../../../ansible/
ansible-playbook -i inventory/dev playbooks/site.yml

# Application stacks
make stacks-deploy
```

### Production Deployment  

```bash
# Infrastructure
cd environments/prod/aws/
terraform init
terraform plan  
terraform apply

# ECS deployment handled by Terraform
```

## 🔧 Useful Commands

### Terraform

```bash
terraform validate    # Validate configuration
terraform fmt         # Format files
terraform show         # View current state
terraform destroy      # Destroy infrastructure
```

### Ansible

```bash
ansible all -m ping -i inventory/dev           # Test connectivity
ansible-playbook playbooks/site.yml --check    # Dry run
```

### Docker Swarm

```bash
docker node ls                    # Cluster status
docker service ls                 # List services
docker service logs SERVICE_NAME  # Service logs
docker service scale SERVICE=3    # Scale service
```

## 🐛 Troubleshooting

### Authentication Issues

```bash
# Azure token refresh
az login --use-device-code
az account show

# Terraform state lock  
terraform force-unlock LOCK_ID
```

### Network Issues

```bash
# Docker Swarm connectivity
sudo ufw status
telnet <node-ip> 2377

# DNS resolution
nslookup promata.com.br
```

### Registry Issues

```bash
# Docker registry login
docker login
docker system info | grep Registry
```

## 📊 Monitoring & Health

### Health Checks

```bash
# Application endpoints
curl https://api.promata.com.br/health
curl https://promata.com.br/health

# Database connectivity  
PGPASSWORD=$POSTGRES_PASSWORD psql -h $DB_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT 1;"
```

### Logs

```bash
# Docker Swarm
docker service logs -f SERVICE_NAME

# AWS ECS  
aws logs tail /aws/ecs/SERVICE_NAME --follow

# Azure Container
az container logs --resource-group RG_NAME --name CONTAINER_NAME
```

## 🔄 Updates & Rollbacks

### Image Updates

```bash
# Docker Swarm
docker service update --image NEW_IMAGE:TAG SERVICE_NAME

# AWS ECS
aws ecs update-service --cluster CLUSTER --service SERVICE --force-new-deployment
```

### Rollbacks

```bash
# Docker Swarm
docker service rollback SERVICE_NAME

# AWS ECS  
aws ecs update-service --cluster CLUSTER --service SERVICE --task-definition SERVICE:PREVIOUS_REVISION
```

---

**Configuration complete!** See [RUNBOOK.md](./RUNBOOK.md) for deployment procedures.
