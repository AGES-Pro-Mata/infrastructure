# 🏗️ Infrastructure as Code - Generic Template

A complete infrastructure template using Terraform and Ansible for deploying applications on Azure with Docker Swarm.

## 🚀 Quick Start

### 1. Prerequisites
- Azure account with active subscription
- DockerHub account for your application images
- GitHub repository for CI/CD

### 2. Setup (5 minutes)

1. **Clone and configure**:
   ```bash
   git clone <your-repo>
   cd infrastructure
   cp config.example.sh config.sh
   ```

2. **Edit `config.sh`** with your details:
   ```bash
   export PROJECT_NAME="myproject"           # Your project name
   export DOCKERHUB_ORG="myorg"              # Your DockerHub organization  
   export DOMAIN_NAME="example.com"          # Your domain (optional)
   ```

3. **Apply configuration**:
   ```bash
   ./config.sh apply
   ```

4. **Set GitHub secrets** in your repo:
   - `AZURE_CREDENTIALS` - Azure service principal JSON
   - `AZURE_SUBSCRIPTION_ID` - Your Azure subscription ID  
   - `ANSIBLE_VAULT_PASSWORD` - Use the generated password from step 3

5. **Deploy**:
   ```bash
   git add . && git commit -m "Initial setup" && git push
   ```
   Or run manually: `make deploy ENV=dev`

### 3. Azure Service Principal Setup

```bash
# Login to Azure
az login

# Create service principal
az ad sp create-for-rbac --name "myproject-terraform-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/$(az account show --query id -o tsv)"
```

Use the JSON output as your `AZURE_CREDENTIALS` GitHub secret.

## 📁 What You Get

- **Azure Infrastructure**: VMs, networking, security groups, storage
- **Docker Swarm**: Container orchestration with manager and worker nodes  
- **CI/CD Pipeline**: Automated deployment via GitHub Actions
- **DNS Management**: Optional Cloudflare integration
- **Monitoring**: Grafana, Prometheus (built-in)
- **Security**: SSL, firewall, SSH keys auto-generated

## 🔧 Customization

### Application Images
Update in `envs/dev/terraform.tfvars`:
```hcl
backend_image = "myorg/myapp-backend-dev:latest"
frontend_image = "myorg/myapp-frontend-dev:latest"
```

### Domain Configuration
```hcl
domain_name = "yourdomain.com"
enable_cloudflare_dns = true
```

### Resource Sizing
```hcl
vm_size = "Standard_B2s"        # Dev: small, Prod: larger
backend_replicas = 1            # Number of backend containers
```

## 📋 Commands

```bash
# Deploy infrastructure
make deploy ENV=dev

# Check status
make status ENV=dev

# Run health check
make health ENV=dev

# View deployment info
make show-deployment-info ENV=dev

# Clean up (DESTRUCTIVE!)
make destroy-dev
```

## 🌐 Access Your Application

After successful deployment:
- **Frontend**: https://yourdomain.com
- **API**: https://api.yourdomain.com
- **Traefik Dashboard**: https://traefik.yourdomain.com
- **Grafana**: https://grafana.yourdomain.com

## 🔒 Security Features

- SSH key-based authentication (passwords disabled)
- UFW firewall configured
- Fail2ban for intrusion prevention  
- SSL/TLS via Cloudflare or Let's Encrypt
- Network segmentation
- Secrets management with Ansible Vault

## 🔍 Monitoring

Built-in monitoring stack includes:
- **Prometheus**: Metrics collection
- **Grafana**: Dashboards and alerts
- **Node Exporter**: System metrics
- **Docker metrics**: Container monitoring

## 🆘 Troubleshooting

### Common Issues

1. **"Storage account name already exists"**
   ```bash
   # Edit envs/dev/terraform.tfvars and change:
   storage_account_name = "myprojectnewname123"
   ```

2. **"Docker images not found"**
   - Ensure your DockerHub images exist and are publicly accessible
   - Or add DockerHub login to GitHub workflow

3. **"Subscription not authorized"**
   - Check your Azure service principal has Contributor role
   - Verify AZURE_CREDENTIALS secret is correct JSON

4. **"Domain not resolving"**
   - If using Cloudflare, ensure nameservers are updated
   - DNS propagation can take up to 24 hours

### Debugging

```bash
# Check Terraform state
cd terraform/deployments/dev
terraform show

# Check infrastructure logs  
make status ENV=dev

# SSH into VMs (after deployment)
ssh -i ~/.ssh/myproject_key ubuntu@<public-ip>
```

## 📊 Architecture

```
[GitHub] → [GitHub Actions] → [Azure]
    ↓           ↓               ↓
[Your Code] → [CI/CD] → [Terraform] → [VMs + Docker Swarm]
                          ↓              ↓
                    [Ansible] → [Deploy Apps + Monitoring]
```

## 🔄 Environments

- **dev**: Development environment (small VMs, 1 replica)
- **staging**: Staging environment (coming soon)
- **prod**: Production environment (coming soon)

## 📚 Documentation

- [Setup Instructions](SETUP-INSTRUCTIONS.md) - Detailed setup guide
- [Makefile Commands](./Makefile) - All available commands
- [Terraform Variables](./terraform/deployments/dev/variables.tf) - All configuration options

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes
4. Submit a pull request

## 📄 License

This template is provided as-is for educational and development purposes.

---

**🎉 Ready to deploy?** Run `./config.sh apply` and push your changes!
