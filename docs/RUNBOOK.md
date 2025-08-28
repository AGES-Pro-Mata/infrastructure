# =€ Pro-Mata Infrastructure Runbook

Simple and straightforward guide for deploying Pro-Mata infrastructure in development environment.

## =Ë Prerequisites

### Local Development
- **Azure CLI** installed and configured
- **Terraform** >= 1.8.0
- **Docker** and **Docker Compose**
- **Git** with repository access
- **SSH key pair** for VM access

### CI/CD Deployment
- GitHub repository with Actions enabled
- Azure subscription with contributor access
- DuckDNS account for domain management
- Docker Hub account for image registry

## =à Quick Start - Development Environment

### 1. Clone and Setup Repository

```bash
# Clone the repository
git clone <your-repo-url>
cd infrastructure

# Copy environment template
cp environments/dev/.env.dev.template environments/dev/.env.dev

# Edit environment variables
nano environments/dev/.env.dev
```

### 2. Configure Environment Variables

Edit `environments/dev/.env.dev` and replace placeholders:

```bash
# Required Azure settings
AZURE_SUBSCRIPTION_ID=your-actual-subscription-id
AZURE_TENANT_ID=your-actual-tenant-id

# Required secrets
DUCKDNS_TOKEN=your-actual-duckdns-token
POSTGRES_PASSWORD=your-secure-password-123
POSTGRES_REPLICA_PASSWORD=your-secure-replica-password-123
PGLADMIN_PASSWORD=your-secure-pgladmin-password-123
JWT_SECRET=your-super-secret-jwt-key-here
TRAEFIK_AUTH_USERS=admin:$$2y$$10$$your-htpasswd-hash
GRAFANA_ADMIN_PASSWORD=your-secure-grafana-password-123

# SSH public key
TF_VAR_ssh_public_key=ssh-rsa AAAAB3Nza... your-email@domain.com
```

### 3. Deploy Locally

```bash
# Navigate to dev environment
cd environments/dev/azure/

# Login to Azure
az login

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply

# Get VM IP address
terraform output swarm_manager_public_ip
```

### 4. Configure Docker Swarm

```bash
# SSH into the manager VM
ssh ubuntu@$(terraform output -raw swarm_manager_public_ip)

# Initialize Docker Swarm (if not already done by cloud-init)
docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')

# Deploy the stacks
cd /opt/promata
git clone <your-repo-url> .
./scripts/deploy-stacks.sh
```

## = CI/CD Deployment

### 1. Configure GitHub Secrets

Go to your GitHub repository ’ Settings ’ Secrets and variables ’ Actions

Add these **Repository Secrets**:

#### **Azure Authentication**
```
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_CLIENT_ID=your-service-principal-client-id
AZURE_CLIENT_SECRET=your-service-principal-secret
AZURE_TENANT_ID=your-tenant-id
AZURE_CREDENTIALS={"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}
```

#### **Application Secrets**
```
POSTGRES_PASSWORD=your-secure-postgres-password
POSTGRES_REPLICA_PASSWORD=your-secure-replica-password
PGLADMIN_PASSWORD=your-secure-pgladmin-password
JWT_SECRET=your-jwt-secret-key
DUCKDNS_TOKEN=your-duckdns-token
TRAEFIK_AUTH_USERS=admin:$2y$10$your-htpasswd-hash
GRAFANA_ADMIN_PASSWORD=your-grafana-password
```

#### **Infrastructure Secrets**
```
SSH_PRIVATE_KEY_DEV=-----BEGIN OPENSSH PRIVATE KEY-----...
SSH_PUBLIC_KEY=ssh-rsa AAAAB3NzaC1yc2E...
DOCKER_USERNAME=your-dockerhub-username
DOCKER_PASSWORD=your-dockerhub-password
```

#### **Optional Notification Secrets**
```
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
DISCORD_WEBHOOK_URL_PR=https://discord.com/api/webhooks/...
```

### 2. Deploy via GitHub Actions

#### **Option A: Automatic Deployment**
Push to `feature/dev-environment` branch:
```bash
git add .
git commit -m "deploy dev environment"
git push origin feature/dev-environment
```

#### **Option B: Manual Deployment**
1. Go to GitHub ’ Actions
2. Select "Pro-Mata Deployment Trigger" workflow
3. Click "Run workflow"
4. Choose:
   - **Environment**: `dev`
   - **Backend image tag**: `latest`
   - **Frontend image tag**: `latest`
5. Click "Run workflow"

### 3. Monitor Deployment

```bash
# Watch the GitHub Actions workflow
# Check logs in the Actions tab

# Once deployed, get the public IP
# Check workflow output or run locally:
cd environments/dev/azure/
terraform output swarm_manager_public_ip
```

## < Access Your Application

Once deployed, access your services:

- **Frontend**: https://promata-dev.duckdns.org
- **Backend API**: https://api.promata-dev.duckdns.org
- **Traefik Dashboard**: https://traefik.promata-dev.duckdns.org (use auth)
- **PgAdmin**: https://pgadmin.promata-dev.duckdns.org (use auth)

## =Ê Monitoring and Management

### Check Application Status
```bash
# SSH into the manager VM
ssh ubuntu@<vm-public-ip>

# Check Docker Swarm status
docker node ls
docker service ls

# Check stack status
docker stack ls
docker stack services promata-app
docker stack services promata-database
docker stack services promata-proxy

# View logs
docker service logs promata-app_backend -f
docker service logs promata-app_frontend -f
```

### Update Application
```bash
# Update image tags and redeploy
docker service update --image norohim/pro-mata-backend:new-tag promata-app_backend
docker service update --image norohim/pro-mata-frontend:new-tag promata-app_frontend
```

## =' Common Tasks

### Restart Services
```bash
ssh ubuntu@<vm-public-ip>

# Restart specific service
docker service update --force promata-app_backend

# Restart entire stack
docker stack rm promata-app
sleep 10
docker stack deploy -c docker/stacks/app-stack.yml promata-app
```

### Update Environment Variables
```bash
# Update secrets in the VM
ssh ubuntu@<vm-public-ip>
nano /opt/promata/environments/dev/.env.dev

# Redeploy stack with new environment
docker stack rm promata-app
docker stack deploy -c docker/stacks/app-stack.yml promata-app
```

### Backup Database
```bash
ssh ubuntu@<vm-public-ip>
cd /opt/promata

# Run backup script
./scripts/backup-database.sh --environment dev
```

### View Application Logs
```bash
ssh ubuntu@<vm-public-ip>

# Backend logs
docker service logs promata-app_backend --tail 100 -f

# Frontend logs  
docker service logs promata-app_frontend --tail 100 -f

# Database logs
docker service logs promata-database_postgres-primary --tail 100 -f

# Traefik logs
docker service logs promata-proxy_traefik --tail 100 -f
```

## <˜ Troubleshooting

### Infrastructure Issues

#### VM Not Accessible
```bash
# Check VM status in Azure
az vm show --resource-group rg-promata-dev --name vm-promata-dev-manager --query "powerState"

# Restart VM if needed
az vm restart --resource-group rg-promata-dev --name vm-promata-dev-manager

# Check NSG rules
az network nsg show --resource-group rg-promata-dev --name nsg-promata-dev
```

#### Docker Swarm Issues
```bash
ssh ubuntu@<vm-public-ip>

# Check swarm status
docker system info | grep Swarm

# Rejoin swarm if needed
docker swarm leave --force
docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
```

### Application Issues

#### Services Not Starting
```bash
ssh ubuntu@<vm-public-ip>

# Check service status
docker service ls
docker service ps promata-app_backend --no-trunc

# Check container logs
docker service logs promata-app_backend --tail 50
```

#### Database Connection Issues
```bash
ssh ubuntu@<vm-public-ip>

# Test database connection
docker exec -it $(docker ps -q -f name=postgres-primary) psql -U promata -d promata_dev -c "SELECT version();"

# Check PgBouncer status
docker exec -it $(docker ps -q -f name=pgbouncer) psql -h localhost -p 6432 -U promata -d pgbouncer -c "SHOW STATS;"
```

#### Domain Not Resolving
```bash
# Check DuckDNS status
curl "https://www.duckdns.org/update?domains=promata-dev&token=<your-token>&ip="

# Test DNS resolution
nslookup promata-dev.duckdns.org
```

### CI/CD Issues

#### Terraform Apply Fails
- Check Azure credentials are correct in GitHub Secrets
- Verify subscription has sufficient permissions
- Check resource quotas in Azure subscription

#### SSH Connection Fails
- Verify SSH_PRIVATE_KEY_DEV secret matches SSH_PUBLIC_KEY
- Check VM is running: `az vm show --resource-group rg-promata-dev --name vm-promata-dev-manager`
- Verify NSG allows SSH access

#### Images Not Found
- Verify DOCKER_USERNAME and DOCKER_PASSWORD are correct
- Check images exist in Docker Hub registry
- Ensure image tags are correct

## = Clean Up

### Destroy Development Environment
```bash
# Local cleanup
cd environments/dev/azure/
terraform destroy

# Or via GitHub Actions
# Go to Actions ’ "Deploy Infrastructure (Secure)"
# Run workflow with action: "destroy"
```

### Remove GitHub Secrets
Go to Settings ’ Secrets and variables ’ Actions and remove all secrets when no longer needed.

---

## =Þ Support

For issues not covered in this runbook:

1. Check the [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) guide
2. Review GitHub Actions workflow logs
3. Check Azure portal for resource status
4. Contact the development team

---

**Last Updated**: 2024-08-28  
**Environment**: Development  
**Provider**: Azure  
**Region**: East US 2