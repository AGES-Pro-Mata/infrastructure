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

```bash
# Copiar env
cp envs/local.env.example .env

# Editar variáveis
vim .env

# Subir com Prisma Studio
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Criar admin
docker-compose exec backend npm run cli user:create \
  --email admin@test.com --password admin123 --role ADMIN
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
│       └── setup-backend.sh # Criar S3 backend
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
