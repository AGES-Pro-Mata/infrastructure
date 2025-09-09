# Pro-Mata Infrastructure

Infrastructure as Code for the Pro-Mata application using Terraform and Ansible on Azure.

## What This Does

- **Infrastructure**: Provisions Azure VMs, networking, and storage with Terraform
- **Configuration**: Sets up Docker Swarm cluster with Ansible
- **Deployment**: Automated CI/CD pipeline via GitHub Actions
- **Services**: Deploys frontend, backend, database, and monitoring stack

## Quick Start

### Prerequisites

- Azure subscription with Service Principal credentials
- GitHub repository secrets configured (see below)

### Required Secrets

```plain
AZURE_CREDENTIALS          # Service Principal JSON
AZURE_SUBSCRIPTION_ID      # Azure subscription ID
ANSIBLE_VAULT_PASSWORD     # Vault encryption key
CLOUDFLARE_API_TOKEN       # Optional: DNS management
CLOUDFLARE_ZONE_ID         # Optional: DNS zone
```

### Deploy

**Manual Deployment:**

1. Go to Actions → "Pro-Mata Unified Deployment"
2. Click "Run workflow"
3. Select environment (dev/prod) and action (deploy)

**Automatic Deployment:**

- Push to `main` branch triggers dev deployment
- External webhook via repository dispatch

### Local Development

```bash
# Deploy dev environment
make deploy-automated ENV=dev

# Check status
make quick-status ENV=dev

# Health check
make health ENV=dev

# Destroy (careful!)
make destroy-dev
```

## Architecture

- **Manager Node**: Main services (Traefik, monitoring)
- **Worker Node**: Application containers
- **Static IPs**: Reserved Azure public IPs for DNS stability
- **DNS**: Cloudflare proxy with automatic SSL

## Monitoring

- **Traefik**: <https://traefik.promata.com.br>
- **Grafana**: <https://grafana.promata.com.br>
- **Prometheus**: <https://prometheus.promata.com.br>

## Security

- Ansible Vault for secrets encryption
- Service Principal authentication
- Network security groups
- SSL termination via Cloudflare

## For Beginners - Simple Instructions

### How to Deploy (Easy Way)

1. Go to the **Actions** tab in this GitHub repo
2. Click **"Pro-Mata Unified Deployment"**
3. Click **"Run workflow"** button
4. Choose:
   - **Environment**: `dev` (for testing) or `prod` (for live site)
   - **Action**: `deploy` (to build everything)
5. Click **"Run workflow"** - wait ~15 minutes

That's it! The system will create cloud servers and make the website live.

### Check If It's Working

After deployment, visit these URLs:

- **Main site**: <https://promata.com.br>
- **API**: <https://api.promata.com.br>

### Troubleshooting for Beginners

- **Deployment failed?** Check the Actions tab for error messages
- **Website not loading?** Wait 5-10 minutes after deployment completes
- **Need help?** Ask the infrastructure team

### Important Notes

⚠️ **Never run commands with `destroy` unless you know what you're doing**
⚠️ **Production deployments should be reviewed by the team first**
✅ **Dev environment is safe to experiment with**
