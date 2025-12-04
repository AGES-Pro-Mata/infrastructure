# PRO-MATA Infrastructure

Infraestrutura como código para plataforma de monitoramento ambiental PUCRS.

## Stack Técnico

- **Frontend**: React 19 + Vite → AWS S3 + Cloudflare CDN
- **Backend**: NestJS + Prisma → Docker container
- **Database**: PostgreSQL 17 (único, schemas separados)
- **Analytics**: Umami (métricas validadas)
- **BI**: Metabase (dashboards stakeholder)
- **Proxy**: Traefik v3 (SSL automático Let's Encrypt)
- **IaC**: Terraform 1.10 (AWS sa-east-1, Azure brazilsouth)
- **CI/CD**: GitHub Actions
- **Config**: Ansible (setup inicial)

## Arquitetura

```plaintext
┌─────────────────┐
│   Cloudflare    │ (CDN + SSL + DDoS)
└────────┬────────┘
         │
    ┌────┴─────┐
    │          │
┌───▼───┐  ┌──▼─────┐
│  S3   │  │  EC2   │
│ (Frontend) │ (Backend) │
└───────┘  └────┬───┘
                │
    ┌───────────┼───────────┐
    │           │           │
┌───▼───┐  ┌───▼───┐  ┌────▼────┐
│Umami  │  │Backend│  │Metabase │
└───┬───┘  └───┬───┘  └────┬────┘
    │          │           │
    └──────────┼───────────┘
          ┌────▼─────┐
          │PostgreSQL│
          │ (único)  │
          └──────────┘
```

## Serviços

1. **Traefik** - Reverse proxy + SSL automático
2. **PostgreSQL 17** - Banco único (schemas: app, umami, metabase)
3. **Backend** - API NestJS
4. **Umami** - Analytics (validado stakeholder)
5. **Metabase** - BI para stakeholder

## Quick Start

### 1. Configurar Secrets

Settings → Secrets and variables → Actions

```bash
AWS_ACCESS_KEY_ID=<secret>
AWS_SECRET_ACCESS_KEY=<secret>
CLOUDFLARE_API_TOKEN=<secret>
CLOUDFLARE_ZONE_ID=<secret>
POSTGRES_PASSWORD=<secret>
JWT_SECRET=<secret>
APP_SECRET=<secret>
```

### 2. Deploy Automático

```bash
git push origin main
```

GitHub Actions deploya:

- Terraform provisiona infraestrutura
- Backend build + deploy EC2
- Frontend build + S3 sync

### 3. Configurar Usuários

```bash
ssh ubuntu@<EC2_IP>
cd /opt/promata
docker-compose exec backend npm run cli user:create \
  --email admin@promata.com.br \
  --password Admin123! \
  --role ADMIN
```

## Deploy Manual

### Infraestrutura

```bash
# AWS (São Paulo)
cd iac/aws
terraform init
terraform apply

# Azure (Brasil Sul)
cd iac/azure/dev
terraform init
terraform apply
```

### Aplicação

**Single-Node:**

```bash
docker-compose up -d
```

**Multi-Node (Swarm):**

```bash
docker stack deploy -c docker/stacks/swarm.yml promata
```

## Desenvolvimento Local

### Quick Start (Recomendado)

```bash
# Inicia tudo automaticamente
make local
```

Isso irá:
1. Criar `.env` com valores de desenvolvimento
2. Configurar Traefik para HTTP local
3. Criar schemas no PostgreSQL
4. Iniciar todos os containers
5. Aguardar services ficarem healthy

### URLs Locais

| Serviço | URL |
|---------|-----|
| Frontend | http://localhost |
| API | http://localhost:3000/health |
| Traefik Dashboard | http://localhost:8080 |
| PostgreSQL | localhost:5432 |
| Umami | http://localhost:3002 |
| Metabase | http://localhost:3003 |

### Comandos Úteis

```bash
make local-logs      # Ver logs de todos os containers
make local-ps        # Status dos containers
make local-down      # Parar stack
make local-reset     # Resetar tudo (apaga dados!)
make local-db        # Conectar ao PostgreSQL
make local-rebuild   # Rebuild e restart
```

### Manual (Alternativo)

```bash
# Copiar env
cp envs/local.env.example .env

# Editar variáveis
vim .env

# Subir stack
docker compose up -d

# Criar admin
docker compose exec backend npm run cli user:create \
  --email admin@test.com --password admin123 --role ADMIN
```

## Deploy pelo Cliente (Primeiro Uso)

Esta seção é destinada ao Prof. Augusto Alvim e equipe do Centro Pro-Mata para realizar o primeiro deploy e configuração do sistema.

### Pré-requisitos

1. **Conta AWS** configurada com credenciais
2. **Token Cloudflare API** com permissões:
   - Zone:DNS:Edit
   - Zone:Zone:Read
3. **Terraform** instalado (v1.10+)
4. **Make** instalado

### Configurar Variáveis de Ambiente

```bash
export AWS_REGION=sa-east-1
export DOMAIN_NAME=promata.com.br
export CLOUDFLARE_API_TOKEN=seu-token-aqui
export CLOUDFLARE_ZONE_ID=seu-zone-id
export ACME_EMAIL=admin@promata.com.br
export BACKEND_IMAGE=norohim/pro-mata-backend:latest
```

### Deploy Completo Automatizado

```bash
# 1. Clone o repositório
git clone https://github.com/ages-pucrs/promata-infrastructure
cd promata-infrastructure

# 2. Execute o deploy completo (IaC + Docker Compose)
make deploy-compose-full ENV=prod \
  CLOUDFLARE_API_TOKEN=$CLOUDFLARE_API_TOKEN \
  DOMAIN_NAME=promata.com.br \
  AWS_REGION=sa-east-1
```

Este comando irá:

1. Provisionar infraestrutura AWS (VPC, EC2, S3, DNS)
2. Configurar Cloudflare DNS
3. Fazer deploy do Docker Compose stack
4. Gerar certificados SSL automaticamente

### Primeiro Acesso ao Sistema

1. Aguarde ~2 minutos para certificados SSL serem gerados
2. Acesse: <https://promata.com.br>
3. **Faça login com as credenciais fornecidas diretamente ao administrador**
4. **IMPORTANTE**: Altere a senha imediatamente após primeiro login
5. Configure usuários adicionais via interface web

### Gerenciamento de Usuários e Seed

Para adicionar novos administradores ou modificar o seed padrão, consulte:

📖 **[docs/SEED_MANAGEMENT.md](docs/SEED_MANAGEMENT.md)** - Guia completo de gerenciamento de usuários

### Comandos Úteis Pós-Deploy

```bash
# SSH para a instância EC2
make ssh-instance ENV=prod

# Ver logs de todos os serviços
ssh ubuntu@<EC2_IP> "cd /opt/promata && docker compose logs -f"

# Ver status dos serviços
ssh ubuntu@<EC2_IP> "cd /opt/promata && docker compose ps"

# Atualizar imagens Docker
ssh ubuntu@<EC2_IP> "cd /opt/promata && docker compose pull && docker compose up -d"
```

## URLs

- **Frontend**: <https://promata.com.br>
- **API**: <https://api.promata.com.br>
- **Analytics**: <https://analytics.promata.com.br>
- **BI**: <https://metabase.promata.com.br>

## Comandos Úteis

```bash
# Logs
docker-compose logs -f
docker-compose logs -f backend

# Status
docker-compose ps
docker stats

# Health
curl https://api.promata.com.br/health

# Backup
docker-compose exec postgres pg_dump -U promata promata > backup.sql
```

## Estrutura

```plaintext
infrastructure/
├── .github/workflows/       # CI/CD
│   ├── infra-aws.yml
│   ├── deploy-backend.yml
│   └── deploy-frontend.yml
├── iac/
│   ├── aws/                 # Terraform AWS (sa-east-1)
│   │   ├── modules/
│   │   │   ├── compute/    # EC2
│   │   │   └── storage/    # S3
│   │   └── backend.tf      # S3 state
│   ├── azure/               # Terraform Azure (brazilsouth)
│   └── modules/shared/dns/ # Cloudflare
├── docker/
│   ├── docker-compose.yml   # Single-node
│   ├── docker-compose.dev.yml  # Dev tools
│   ├── stacks/swarm.yml     # Multi-node
│   └── database/            # PostgreSQL init scripts
├── scripts/
│   └── terraform/
│       ├── setup-backend-aws.sh   # Criar S3 backend (AWS)
│       ├── setup-backend-azure.sh # Criar Blob Storage backend (Azure)
│       └── setup-backends.sh      # Menu interativo
├── envs/
│   ├── local.env.example
│   └── production.env.example
├── docs/
│   ├── DEPLOYMENT.md
│   └── USER_MANAGEMENT.md
└── README.md
```

## Documentação

- [DEPLOYMENT.md](docs/DEPLOYMENT.md) - Manual completo de deploy
- [USER_MANAGEMENT.md](docs/USER_MANAGEMENT.md) - Gerenciar usuários

## Configurações

### GitHub Secrets

```plaintext
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ZONE_ID
POSTGRES_PASSWORD
JWT_SECRET
APP_SECRET
DOCKER_USERNAME
DOCKER_PASSWORD
EC2_SSH_KEY
DISCORD_WEBHOOK_URL
```

### GitHub Variables

```plaintext
DOMAIN_NAME=promata.com.br
AWS_S3_BUCKET=promata-frontend
VITE_UMAMI_WEBSITE_ID=<após configurar>
POSTGRES_USER=promata
POSTGRES_DB=promata
```

## Regiões

- **AWS**: sa-east-1 (São Paulo, Brasil)
- **Azure**: brazilsouth (Brasil Sul)

Ambas otimizadas para latência no Brasil.

## Suporte Multi-Cloud

Infraestrutura suporta tanto AWS quanto Azure:

- **Frontend**: S3 (AWS) ou Blob Storage (Azure) + Cloudflare
- **Backend**: EC2 (AWS) ou VM (Azure)
- **DNS**: Cloudflare (unificado)

## Contribuir

1. Fork o repositório
2. Criar branch: `git checkout -b feature/nova-feature`
3. Commit: `git commit -m 'Add nova feature'`
4. Push: `git push origin feature/nova-feature`
5. Abrir Pull Request

## Licença

AGES Open Source for Proof of Concept Projects

---

**PRO-MATA** - Plataforma de Monitoramento Ambiental PUCRS
