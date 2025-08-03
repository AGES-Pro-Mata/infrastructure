# Pro-Mata Infrastructure

Repositório de infraestrutura como código (IaC) e configuração como código (CaC) para o projeto Pro-Mata - Plataforma de reservas e atendimento ao visitante do Centro Pró-Mata PUCRS.

## 🏗️ Arquitetura

```plaintext
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend      │    │  Infrastructure │
│   (React +      │    │  (Spring Boot   │    │   (Terraform +  │
│   Tanstack)     │    │   + JPA)        │    │    Ansible)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Docker Hub    │
                    │   (Registry)    │
                    └─────────────────┘
```

### Tecnologias

- **Frontend**: React, Tanstack Router, Shadcn/ui, Axios
- **Backend**: Spring Boot, JPA, JWT, PostgreSQL
- **Infrastructure**: Terraform, Ansible, Docker Swarm
- **CI/CD**: GitHub Actions
- **Cloud**: Azure (Dev), AWS (Prod)

## 🚀 Quick Start

### Pré-requisitos

```bash
# Instalar dependências
sudo apt-get update
sudo apt-get install -y terraform ansible docker.io

# Configurar credenciais AWS
aws configure

# Configurar credenciais Azure
az login

# Configurar Docker Hub
docker login
```

### Deploy Local

```bash
# 1. Clonar repositórios
git clone https://github.com/pro-mata/pro-mata-infra.git
git clone https://github.com/pro-mata/pro-mata-backend.git
git clone https://github.com/pro-mata/pro-mata-frontend.git

# 2. Configurar ambiente local
cd pro-mata-infra
cp .env.example .env
# Editar .env com suas configurações

# 3. Subir ambiente local
cd environments/local
docker-compose -f docker-compose.local.yml up -d

# 4. Verificar serviços
curl http://localhost:3000          # Frontend
curl http://localhost:8080/health   # Backend
curl http://localhost:5050          # PgAdmin
```

### Deploy Development (Azure)

```bash
# Deploy completo para ambiente de desenvolvimento
./deploy.sh --provider azure --environment dev

# Ou deploy específico
cd terraform/azure
terraform init
terraform plan -var-file="../../environments/dev/.env.dev"
terraform apply

cd ../../deployment/ansible
ansible-playbook -i ../../static_ip.ini playbooks/swarm_setup.yml
```

### Deploy Production (AWS)

```bash
# Deploy completo para ambiente de produção
./deploy.sh --provider aws --environment prod

# Destruir infraestrutura
./destroy.sh --provider aws
```

## 📁 Estrutura do Projeto

```plaintext
pro-mata-infra/
├── terraform/           # Infrastructure as Code
│   ├── aws/            # AWS resources
│   ├── azure/          # Azure resources
│   └── modules/        # Shared modules
├── deployment/         # Configuration as Code
│   ├── ansible/        # Ansible playbooks
│   └── swarm/          # Docker Swarm configs
├── docker/            # Dockerfiles
├── ci-cd/             # GitHub Actions workflows
├── environments/      # Environment-specific configs
├── monitoring/        # Monitoring setup
└── docs/              # Documentation
```

## 🔄 CI/CD Pipeline

### Fluxo de Desenvolvimento

1. **Developer Push**: Código commitado em `develop` ou `main`
2. **Build & Test**: CI roda testes, security scan, build
3. **Docker Push**: Imagem enviada para Docker Hub
4. **Trigger Deploy**: Repository dispatch para infra
5. **Infrastructure**: Terraform provisiona recursos
6. **Configuration**: Ansible configura serviços
7. **Health Check**: Verificação de saúde dos serviços

### Ambientes

| Branch    | Environment | Cloud Provider | URL |
|-----------|------------|----------------|-----|
| `develop` | Development | Azure | <https://promata-dev.duckdns.org> |
| `main`    | Production | AWS | <https://promata.duckdns.org> |

## 🎯 Serviços

### Frontend

- **URL**: <https://promata.duckdns.org>
- **Tech**: React + Vite + Tanstack Router
- **Port**: 3000

### Backend  

- **URL**: <https://api.promata.duckdns.org>
- **Tech**: Spring Boot + JPA
- **Port**: 8080

### Database

- **Tech**: PostgreSQL 15
- **Port**: 5432 (Primary), 5433 (Replica)
- **Management**: PgAdmin em <https://pgadmin.promata.duckdns.org>

### Monitoring

- **Visualizer**: <https://viz.promata.duckdns.org>
- **Traefik**: <https://traefik.promata.duckdns.org>

## 🔧 Configuração

### Variáveis de Ambiente

```bash
# Database
POSTGRES_USER=promata_user
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=promata

# Authentication
JWT_SECRET=your_jwt_secret_key

# Domain
DOMAIN_NAME=promata.duckdns.org
DUCKDNS_TOKEN=your_duckdns_token

# Email
ACME_EMAIL=admin@promata.org

# Cloud Credentials
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AZURE_SUBSCRIPTION_ID=your_azure_subscription
```

### Secrets do GitHub

```bash
# Docker Hub
DOCKER_USERNAME
DOCKER_PASSWORD

# Cloud Providers
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AZURE_CREDENTIALS

# SSH Keys
SSH_PRIVATE_KEY_DEV
SSH_PRIVATE_KEY_PROD

# Repository Access
INFRA_TRIGGER_TOKEN

# Monitoring
SONAR_TOKEN
```

## 🏥 Health Checks

```bash
# Verificar status dos serviços
curl https://promata.duckdns.org/health
curl https://api.promata.duckdns.org/health

# Logs dos contêineres
docker service logs CP-Planta_backend
docker service logs CP-Planta_frontend

# Status do Swarm
docker node ls
docker service ls
```

## 🔍 Troubleshooting

### Problemas Comuns

#### 1. Falha na conexão com banco de dados

```bash
# Verificar se PostgreSQL está rodando
docker service ps CP-Planta_postgres_primary

# Verificar logs do PgBouncer
docker service logs CP-Planta_pgbouncer
```

#### 2. Certificados SSL não funcionando**

```bash
# Verificar logs do Traefik
docker service logs CP-Planta_traefik

# Verificar se DuckDNS está atualizando
curl "https://www.duckdns.org/update?domains=promata&token=YOUR_TOKEN&ip="
```

#### 3. Serviços não inicializam**

```bash
# Verificar recursos disponíveis
docker system df
docker system prune

# Verificar constraints do Swarm
docker service inspect CP-Planta_backend
```

### Logs e Monitoramento

```bash
# Logs centralizados
docker service logs -f CP-Planta_backend
docker service logs -f CP-Planta_frontend

# Métricas do sistema
docker stats
ctop  # Container monitoring tool

# Monitoramento de rede
docker network ls
docker network inspect CP-Planta_traefik_network
```

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

### Padrões de Código

- Use **Terraform format**: `terraform fmt`
- Valide **Ansible syntax**: `ansible-playbook --syntax-check`
- Teste **Docker builds** localmente antes do push
- Documente **mudanças na infraestrutura**

## 📚 Documentação

- [Setup Guide](./docs/SETUP.md)
- [Deployment Guide](./docs/DEPLOYMENT.md)
- [CI/CD Guide](./docs/CI-CD.md)
- [Troubleshooting](./docs/TROUBLESHOOTING.md)
- [Architecture](./docs/ARCHITECTURE.md)

## 📄 Licença

Este projeto é um projeto de código aberto.

## 👥 Time

- **Infrastructure**: Equipe AGES III
- **Backend**: Equipe Spring Boot
- **Frontend**: Equipe React

---

**Pro-Mata** - Centro de Pesquisas e Proteção da Natureza - PUCRS
