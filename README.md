# README.md

# Pro-Mata AWS Infrastructure

Complete AWS infrastructure for Pro-Mata project using Terraform, mirroring the Azure architecture but leveraging AWS services.

## 🏗️ Architecture Overview

This infrastructure replicates the Azure setup using AWS services:

- **EC2 Instances**: Replace Azure VMs with static Elastic IPs
- **Docker Swarm**: Same container orchestration as Azure
- **S3 Storage**: Replace Azure Storage Account
- **SES Email**: Email service for application notifications
- **Secrets Manager**: Replace Azure Key Vault
- **CloudWatch**: Monitoring and logging
- **Cloudflare**: DNS and CDN (same as Azure setup)

## 💰 Cost Estimate

Based on AWS Calculator (us-east-2):
- **Monthly Cost**: ~$61.20 USD
- **Annual Cost**: ~$734.40 USD
- **Services**: EC2 (2x t3.medium), S3 (1 bucket), SES, Elastic IPs

## 🚀 Quick Start

### Prerequisites

1. **AWS Account** with administrative access
2. **AWS CLI** installed and configured
3. **Terraform** >= 1.5 installed
4. **Cloudflare account** with domain management

### 1. Initial Setup

```bash
# Clone and setup
git clone <this-repository>
cd aws-infrastructure

# Run setup script (creates backend, SSH keys, config files)
./scripts/setup.sh
```

### 2. Configure Variables

Copy and configure the variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Update `terraform.tfvars` with your values:
```hcl
# SSH Key (generate with ssh-keygen)
ssh_public_key = "your-public-key-here"

# Cloudflare credentials
cloudflare_api_token = "your-actual-token"
cloudflare_zone_id   = "your-actual-zone-id"
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

### 4. Verify Deployment

```bash
# Check outputs
terraform output

# SSH into manager node
ssh ubuntu@<manager-ip> -i promata-prod-key.pem

# Check infrastructure status
docker node ls
```

## 📊 Infrastructure Components

### Networking
- **VPC**: 10.0.0.0/16 with public/private subnets
- **Internet Gateway**: Public access
- **NAT Gateways**: Private subnet internet access
- **Security Groups**: Firewall rules for each service

### Compute
- **Manager Node**: t3.medium (Traefik, monitoring, management)
- **Worker Node**: t3.medium (applications, databases)
- **Elastic IPs**: Static IPs for DNS stability
- **EBS Volumes**: Encrypted storage for data persistence

### Security
- **Security Groups**: Network-level firewall rules
- **Encrypted Storage**: All EBS volumes and S3 bucket encrypted
- **SSH Keys**: Secure access to EC2 instances

### Services
- **S3 Bucket**: Application files (PDFs, emails, attachments)
- **SES**: Email service for application notifications
- **Cloudflare**: DNS management and CDN

## 🛠️ Available Commands

### Basic Operations
```bash
terraform init              # Initialize Terraform
terraform plan              # Plan changes
terraform apply             # Apply changes
terraform output            # Show outputs
terraform destroy           # Destroy infrastructure (careful!)
```

### Validation and Formatting
```bash
terraform validate          # Validate configuration
terraform fmt              # Format Terraform files
```

### Operations
```bash
# SSH into instances
ssh ubuntu@<manager-ip> -i promata-prod-key.pem
ssh ubuntu@<worker-ip> -i promata-prod-key.pem

# Check Docker Swarm status
docker node ls
docker service ls
```

## 🔗 Service URLs

After deployment, services will be available at:

### Production URLs
- **Main App**: https://promata.com.br
- **API**: https://api.promata.com.br
- **Traefik Dashboard**: https://traefik.promata.com.br
- **Grafana**: https://grafana.promata.com.br
- **Prometheus**: https://prometheus.promata.com.br
- **Prisma Studio**: https://prisma.promata.com.br
- **Analytics**: https://analytics.promata.com.br
- **Metabase**: https://metabase.promata.com.br

## 📧 Email Service (SES)

The infrastructure includes AWS SES for email functionality:

- **SMTP Endpoint**: `email-smtp.us-east-2.amazonaws.com`
- **Port**: 587 (TLS)
- **Verified Domain**: promata.com.br
- **Verified Emails**: admin@, noreply@, support@promata.com.br

### Email Configuration for Applications

```env
# Add to your application environment
SMTP_HOST=email-smtp.us-east-2.amazonaws.com
SMTP_PORT=587
SMTP_FROM=noreply@promata.com.br
```

## 🔒 Security Configuration

### SSH Access
```bash
# SSH using the generated key pair
ssh ubuntu@<manager-ip> -i promata-{env}-key.pem
ssh ubuntu@<worker-ip> -i promata-{env}-key.pem
```

### Security Groups
- **Manager**: HTTP/HTTPS, SSH, Docker Swarm, monitoring ports (Prometheus, Grafana, Node/Postgres exporters)
- **Worker**: Application ports, database ports, Docker Swarm, monitoring ports
- **Database**: Internal access only from manager and worker security groups

## 📈 Monitoring

### Monitoring Stack
- **Prometheus**: Metrics collection (port 9090)
- **Grafana**: Dashboards and visualization (port 3000)
- **Node Exporter**: System metrics (port 9100)
- **Postgres Exporter**: Database metrics (port 9187)

### Available Dashboards
Pre-configured dashboards for:
- System metrics (CPU, memory, disk, network)
- Application performance monitoring
- Docker container and Swarm metrics
- PostgreSQL database performance
- Custom business metrics

## 🚚 Migration from Azure

### Key Differences
| Component | Azure | AWS |
|-----------|--------|-----|
| Virtual Machines | Azure VMs | EC2 Instances |
| Static IPs | Azure Public IPs | Elastic IPs |
| Storage | Storage Account | S3 Bucket |
| Secrets | Key Vault | Environment Variables |
| Monitoring | Azure Monitor | Prometheus + Grafana |
| Networking | VNet | VPC |
| Database Admin | PgAdmin | Prisma Studio |

### Migration Steps
1. **Deploy AWS infrastructure** (this repository)
2. **Export data** from Azure PostgreSQL
3. **Transfer Docker images** to new registry or reuse existing
4. **Update DNS** from Azure IPs to AWS Elastic IPs
5. **Import data** to AWS PostgreSQL
6. **Update application** configuration for AWS services
7. **Verify functionality** and performance
8. **Decommission Azure** resources

## 🔧 Troubleshooting

### Common Issues

**SSH Connection Failed**
```bash
# Check security group allows SSH from your IP
# Verify SSH key is correct
ssh -i ~/.ssh/id_rsa ubuntu@<instance-ip>
```

**Terraform State Lock**
```bash
# If state is locked, release manually
aws dynamodb delete-item \
  --table-name promata-terraform-state-lock \
  --key '{"LockID":{"S":"<lock-id>"}}'
```

**Services Not Starting**
```bash
# SSH into instances and check Docker
ssh ubuntu@<manager-ip>
sudo docker service ls
sudo docker service logs <service-name>
```

### Logs Location
- **System Logs**: CloudWatch `/aws/ec2/promata-<env>/syslog`
- **Application Logs**: CloudWatch `/aws/ec2/promata-<env>/application`
- **Local Logs**: `/opt/promata/logs/` on instances

## 📞 Support

- **Documentation**: This README and inline code comments
- **Issues**: Create GitHub issues for bugs or questions
- **Architecture**: See `ARCHITECTURE.md` for detailed design
- **Cost Optimization**: Contact AWS support for usage optimization

---

**🌟 Built for Centro de Pesquisas e Proteção da Natureza (CPPN) Pró-Mata - PUCRS**

*Migrating from Azure to AWS for AGES infrastructure project budgets usage.*
