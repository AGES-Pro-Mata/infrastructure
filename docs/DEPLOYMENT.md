# Manual de Deploy - PRO-MATA

## Arquiteturas Suportadas

### 1. Single-Node (Recomendado)

- **Infraestrutura**: 1 EC2 (AWS sa-east-1) ou 1 VM (Azure brazilsouth)
- **Orquestração**: Docker Compose
- **Comando**: `docker-compose up -d`
- **Ideal para**: Até ~10k usuários/mês

### 2. Multi-Node (Escalabilidade)

- **Infraestrutura**: 2+ VMs em cluster
- **Orquestração**: Docker Swarm
- **Comando**: `docker stack deploy -c docker/stacks/swarm.yml promata`
- **Ideal para**: Alta disponibilidade

## Stack Técnico

- **Frontend**: React 19 + Vite → S3/Blob + Cloudflare
- **Backend**: NestJS + Prisma → Container
- **Database**: PostgreSQL 17 (schemas: app, umami, metabase)
- **Analytics**: Umami
- **BI**: Metabase
- **Proxy**: Traefik v3 + Let's Encrypt
- **IaC**: Terraform 1.10
- **CI/CD**: GitHub Actions

## Configuração Inicial

### 1. Configurar GitHub Secrets

**Settings → Secrets and variables → Actions → New repository secret**

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

### 2. Configurar GitHub Variables

**Settings → Secrets and variables → Actions → Variables**

```plaintext
DOMAIN_NAME=promata.com.br
AWS_S3_BUCKET=promata-frontend
VITE_UMAMI_WEBSITE_ID=<após configurar>
POSTGRES_USER=promata
POSTGRES_DB=promata
```

### 3. Deploy Infraestrutura

#### Opção A: Automático (GitHub Actions)

```bash
git push origin main  # Workflows deployam automaticamente
```

#### Opção B: Manual

**AWS (sa-east-1 - São Paulo):**

```bash
# Setup backend
cd scripts/terraform
./setup-backend.sh

# Deploy
cd iac/aws
terraform init
terraform plan -var="domain_name=promata.com.br"
terraform apply
```

**Azure (brazilsouth):**

```bash
cd iac/azure/dev
terraform init
terraform plan
terraform apply
```

### 4. Configurar DNS

Cloudflare cria automaticamente:

- `promata.com.br` → S3 frontend
- `api.promata.com.br` → EC2 backend
- `analytics.promata.com.br` → Umami
- `metabase.promata.com.br` → Metabase

Aguardar propagação DNS (~5min).

### 5. Deploy Aplicação

**Single-Node (Compose):**

```bash
ssh ubuntu@<EC2_IP>
cd /opt/promata

# Criar .env
cat > .env << EOF
DOMAIN_NAME=promata.com.br
POSTGRES_DB=promata
POSTGRES_USER=promata
POSTGRES_PASSWORD=<secret>
JWT_SECRET=<secret>
APP_SECRET=<secret>
EOF

# Subir stack
docker-compose up -d
```

**Multi-Node (Swarm):**

```bash
# No manager node
docker swarm init

# Nos workers
docker swarm join --token <TOKEN> <MANAGER_IP>:2377

# Deploy
docker stack deploy -c docker/stacks/swarm.yml promata
```

## Gerenciar Usuários

### Criar Admin

```bash
docker-compose exec backend npm run cli user:create \
  --email admin@promata.com.br \
  --password SuaSenha123! \
  --role ADMIN
```

### Resetar Senha

```bash
docker-compose exec backend npm run cli user:reset-password \
  --email usuario@exemplo.com \
  --password NovaSenha123!
```

## Configurar Analytics

### Umami

1. Acesse: <https://analytics.promata.com.br>
2. Login: `admin` / `umami`
3. **Altere a senha!**
4. Adicionar website: `https://promata.com.br`
5. Copiar Website ID
6. Atualizar GitHub Variable: `VITE_UMAMI_WEBSITE_ID`
7. Re-deploy frontend

### Metabase

1. Acesse: <https://metabase.promata.com.br>
2. Configurar admin
3. Conectar banco:
   - Type: PostgreSQL
   - Host: `postgres`
   - Port: `5432`
   - Database: `promata`
   - Schema: `app`
   - User: `promata`
   - Password: `<POSTGRES_PASSWORD>`

## Backup

### Manual

```bash
# Database
docker-compose exec postgres pg_dump -U promata promata > backup.sql

# Upload S3
aws s3 cp backup.sql s3://promata-backups/$(date +%Y%m%d).sql
```

### Automático (Cron)

```bash
crontab -e

# Diário às 3AM
0 3 * * * cd /opt/promata && docker-compose exec postgres pg_dump -U promata promata | gzip > /backups/promata-$(date +\%Y\%m\%d).sql.gz
```

## Monitoramento

### Logs

```bash
docker-compose logs -f
docker-compose logs -f backend
docker-compose logs --tail=100 backend
```

### Status

```bash
docker-compose ps
docker stats
```

### Health Checks

```bash
curl https://api.promata.com.br/health
curl https://promata.com.br
docker-compose exec postgres pg_isready -U promata
```

## Troubleshooting

### Serviço não inicia

```bash
docker-compose logs <servico>
docker-compose restart <servico>
docker-compose up -d --build <servico>
```

### Banco inacessível

```bash
docker-compose ps postgres
docker-compose exec postgres psql -U promata
docker-compose exec backend env | grep DATABASE_URL
```

### SSL não funciona

Aguardar 15min para Cloudflare provisionar certificados.

```bash
nslookup promata.com.br
curl -I https://promata.com.br
```

## Escalar para Multi-Node

### 1. Provisionar VMs

Ajustar Terraform `instance_count = 3`

### 2. Inicializar Swarm

```bash
# Manager
docker swarm init --advertise-addr <IP>

# Workers
docker swarm join --token <TOKEN> <MANAGER_IP>:2377
```

### 3. Label para Database

```bash
docker node update --label-add database=true <NODE_NAME>
```

### 4. Deploy Stack

```bash
docker stack deploy -c docker/stacks/swarm.yml promata

# Escalar backend
docker service scale promata_backend=3
```

## URLs

- **Frontend**: <https://promata.com.br>
- **API**: <https://api.promata.com.br>
- **Analytics**: <https://analytics.promata.com.br>
- **BI**: <https://metabase.promata.com.br>
- **Docs**: [README.md](../README.md)
