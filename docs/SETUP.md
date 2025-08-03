# Pro-Mata Setup Guide

Este guia fornece instruções detalhadas para configurar o ambiente Pro-Mata do zero.

## 📋 Pré-requisitos

### Software Necessário

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y \
  curl \
  git \
  docker.io \
  docker-compose \
  terraform \
  ansible \
  jq \
  wget

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker

# Instalar AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Instalar Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Contas e Credenciais

1. **Docker Hub**: Criar conta em <https://hub.docker.com>
2. **AWS**: Configurar conta e obter Access Keys
3. **Azure**: Configurar conta e subscription
4. **DuckDNS**: Registrar domínio em <https://duckdns.org>
5. **GitHub**: Configurar Personal Access Tokens

## 🔧 Configuração Inicial

### 1. Clonar Repositórios

```bash
# Criar diretório do projeto
mkdir pro-mata && cd pro-mata

# Clonar repositórios
git clone https://github.com/pro-mata/pro-mata-infra.git
git clone https://github.com/pro-mata/pro-mata-backend.git
git clone https://github.com/pro-mata/pro-mata-frontend.git

# Estrutura esperada:
# pro-mata/
# ├── pro-mata-infra/
# ├── pro-mata-backend/
# └── pro-mata-frontend/
```

### 2. Configurar Credenciais AWS

```bash
# Configurar AWS CLI
aws configure
# AWS Access Key ID: [seu-access-key]
# AWS Secret Access Key: [seu-secret-key]
# Default region name: us-east-1
# Default output format: json

# Testar configuração
aws sts get-caller-identity
```

### 3. Configurar Credenciais Azure

```bash
# Login no Azure
az login

# Listar subscriptions
az account list --output table

# Definir subscription padrão
az account set --subscription "sua-subscription-id"

# Criar service principal para Terraform
az ad sp create-for-rbac --name "pro-mata-terraform" --role="Contributor" --scopes="/subscriptions/sua-subscription-id"
```

### 4. Configurar DuckDNS

```bash
# Registrar domínio no DuckDNS
# 1. Acesse https://duckdns.org
# 2. Faça login com GitHub/Google
# 3. Registre: promata.duckdns.org
# 4. Copie seu token DuckDNS
```

### 5. Configurar Docker Hub

```bash
# Login no Docker Hub
docker login
# Username: seu-username
# Password: seu-password

# Testar push (opcional)
docker pull hello-world
docker tag hello-world seu-username/hello-world
docker push seu-username/hello-world
```

## 🌐 Configuração de Ambiente

### 1. Arquivo .env Principal

```bash
cd pro-mata-infra
cp .env.example .env
```

Edite o arquivo `.env`:

```bash
# Database Configuration
POSTGRES_USER=promata_user
POSTGRES_PASSWORD=ProMata2025SecurePass!
POSTGRES_DB=promata

# JWT Configuration
JWT_SECRET=ProMata2025JWTSecretKeyVerySecureAndLong!

# Domain Configuration
DOMAIN_NAME=promata.duckdns.org
DUCKDNS_SUBDOMAIN=promata
DUCKDNS_TOKEN=seu-duckdns-token-aqui

# Email Configuration
ACME_EMAIL=admin@promata.org

# Docker Configuration
DOCKER_USERNAME=seu-docker-username
DOCKER_PASSWORD=seu-docker-password

# AWS Configuration (Production)
AWS_ACCESS_KEY_ID=seu-aws-access-key
AWS_SECRET_ACCESS_KEY=seu-aws-secret-key
AWS_REGION=us-east-1

# Azure Configuration (Development)
AZURE_SUBSCRIPTION_ID=sua-azure-subscription-id
AZURE_CLIENT_ID=seu-service-principal-client-id
AZURE_CLIENT_SECRET=seu-service-principal-secret
AZURE_TENANT_ID=seu-azure-tenant-id

# GitHub Configuration
GITHUB_TOKEN=seu-github-personal-access-token
INFRA_TRIGGER_TOKEN=token-para-trigger-deployment
```

### 2. Configurações por Ambiente

#### Development (.env.dev)

```bash
cd environments/dev
cp .env.example .env.dev
```

```bash
# Development Environment
ENVIRONMENT=dev
POSTGRES_DB=promata_dev
DOMAIN_NAME=promata-dev.duckdns.org
BACKEND_PORT=8080
FRONTEND_PORT=3000
```

#### Production (.env.prod)

```bash
cd environments/prod
cp .env.example .env.prod
```

```bash
# Production Environment
ENVIRONMENT=prod
POSTGRES_DB=promata_prod
DOMAIN_NAME=promata.duckdns.org
BACKEND_PORT=8080
FRONTEND_PORT=3000
```

## 🔐 Configuração de Secrets no GitHub

### 1. Repositório de Infraestrutura

Acesse: `https://github.com/pro-mata/pro-mata-infra/settings/secrets/actions`

```bash
# Docker Hub
DOCKER_USERNAME: seu-docker-username
DOCKER_PASSWORD: seu-docker-password

# AWS (Production)
AWS_ACCESS_KEY_ID: seu-aws-access-key
AWS_SECRET_ACCESS_KEY: seu-aws-secret-key

# Azure (Development)
AZURE_CREDENTIALS: {
  "clientId": "service-principal-client-id",
  "clientSecret": "service-principal-secret",
  "subscriptionId": "azure-subscription-id",
  "tenantId": "azure-tenant-id"
}

# SSH Keys (serão geradas pelo Terraform)
SSH_PRIVATE_KEY_DEV: conteudo-da-chave-privada-dev
SSH_PRIVATE_KEY_PROD: conteudo-da-chave-privada-prod

# Repository Access
INFRA_TRIGGER_TOKEN: github-personal-access-token

# DuckDNS
DUCKDNS_TOKEN: seu-duckdns-token

# Monitoring
SONAR_TOKEN: seu-sonar-token (opcional)
```

### 2. Repositório Backend

```bash
# Docker Hub
DOCKER_USERNAME: seu-docker-username
DOCKER_PASSWORD: seu-docker-password

# Repository Access
INFRA_TRIGGER_TOKEN: github-personal-access-token

# SonarQube (opcional)
SONAR_TOKEN: seu-sonar-token
```

### 3. Repositório Frontend

```bash
# Docker Hub
DOCKER_USERNAME: seu-docker-username
DOCKER_PASSWORD: seu-docker-password

# Repository Access
INFRA_TRIGGER_TOKEN: github-personal-access-token
```

## 🏗️ Primeiro Deploy

### 1. Deploy Local (Desenvolvimento)

```bash
cd pro-mata-infra/environments/local

# Subir ambiente local
docker-compose -f docker-compose.local.yml up -d

# Verificar serviços
docker-compose ps

# Acessar serviços
echo "Frontend: http://localhost:3000"
echo "Backend: http://localhost:8080"
echo "PgAdmin: http://localhost:5050"
echo "MailHog: http://localhost:8025"
```

### 2. Deploy Development (Azure)

```bash
cd pro-mata-infra

# Deploy completo
./deploy.sh --provider azure

# Ou passo a passo
cd terraform/azure
terraform init
terraform plan -var-file="../../environments/dev/.env.dev"
terraform apply

cd ../../deployment/ansible
ansible-playbook -i ../../static_ip.ini playbooks/swarm_setup.yml
```

### 3. Deploy Production (AWS)

```bash
cd pro-mata-infra

# Deploy completo
./deploy.sh --provider aws --environment prod

# Verificar serviços
curl https://promata.duckdns.org/health
curl https://api.promata.duckdns.org/health
```

## 🔧 Configuração dos Repositórios Backend/Frontend

### Backend Repository

```bash
cd pro-mata-backend

# Criar arquivo application.yml
mkdir -p src/main/resources
cat > src/main/resources/application.yml << 'EOF'
spring:
  profiles:
    active: dev
  
  datasource:
    url: jdbc:postgresql://localhost:5432/promata_dev
    username: promata_user
    password: promata_pass
    driver-class-name: org.postgresql.Driver
  
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: true
    database-platform: org.hibernate.dialect.PostgreSQLDialect

jwt:
  secret: ProMata2025JWTSecretKeyVerySecureAndLong!
  expiration: 86400000 # 24 hours

server:
  port: 8080
EOF

# Criar Dockerfile.prod
cat > Dockerfile.prod << 'EOF'
FROM openjdk:17-jdk-slim as builder
WORKDIR /app
COPY . .
RUN ./mvnw clean package -DskipTests

FROM openjdk:17-jre-slim
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
```

### Frontend Repository

```bash
cd pro-mata-frontend

# Criar configuração Vite
cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { TanStackRouterVite } from '@tanstack/router-vite-plugin'

export default defineConfig({
  plugins: [react(), TanStackRouterVite()],
  server: {
    host: '0.0.0.0',
    port: 3000
  },
  build: {
    outDir: 'dist',
    sourcemap: false
  }
})
EOF

# Criar Dockerfile.prod
cat > Dockerfile.prod << 'EOF'
FROM node:18-alpine as builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
EOF
```

## ✅ Validação da Configuração

### 1. Testar Conectividade

```bash
# Teste AWS
aws ec2 describe-regions --region us-east-1

# Teste Azure
az account show

# Teste Docker Hub
docker search hello-world

# Teste DuckDNS
curl "https://www.duckdns.org/update?domains=promata&token=SEU_TOKEN&ip="
```

### 2. Validar Terraform

```bash
cd pro-mata-infra/terraform/aws
terraform init
terraform validate

cd ../azure
terraform init
terraform validate
```

### 3. Validar Ansible

```bash
cd pro-mata-infra/deployment/ansible
ansible-playbook --syntax-check playbooks/swarm_setup.yml
```

### 4. Validar Docker Builds

```bash
# Backend
cd pro-mata-backend
docker build -t pro-mata-backend:test -f Dockerfile.prod .

# Frontend
cd pro-mata-frontend
docker build -t pro-mata-frontend:test -f Dockerfile.prod .
```

## 🚨 Troubleshooting

### Problemas Comuns

1. **Terraform: Provider authentication**

   ```bash
   # Verificar credenciais
   aws sts get-caller-identity
   az account show
   ```

2. **Docker: Permission denied**

   ```bash
   # Adicionar usuário ao grupo docker
   sudo usermod -aG docker $USER
   newgrp docker
   ```

3. **DuckDNS: Token inválido**

   ```bash
   # Testar token
   curl "https://www.duckdns.org/update?domains=promata&token=SEU_TOKEN&verbose=true"
   ```

4. **GitHub Actions: Secrets não encontrados**
   - Verificar se todos os secrets foram configurados
   - Verificar se o token tem as permissões corretas

### Logs e Debug

```bash
# Terraform debug
export TF_LOG=DEBUG
terraform apply

# Ansible debug
ansible-playbook -vvv playbooks/swarm_setup.yml

# Docker debug
docker system events &
docker-compose up
```

## 📚 Próximos Passos

1. **Configurar CI/CD**: Fazer primeiro commit para testar pipeline
2. **Configurar Monitoring**: Setup Prometheus/Grafana (opcional)
3. **Configurar Backup**: Setup backup automatizado do banco
4. **Configurar SSL**: Verificar certificados Let's Encrypt
5. **Load Testing**: Testar performance da aplicação

---

**Dúvidas?** Consulte a [documentação completa](./ARCHITECTURE.md) ou abra uma issue no GitHub.
