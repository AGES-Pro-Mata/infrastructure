# 🏗️ Pro-Mata Infrastructure Architecture

Technical overview of the Pro-Mata infrastructure components and organization.

## 📁 Repository Structure

```plain
infrastructure/
├── environments/          # Environment-specific configs
│   ├── dev/azure/        # Development (Azure)
│   └── prod/aws/         # Production (AWS)
├── terraform/            # Infrastructure as Code
├── ansible/              # Configuration management  
├── docker/stacks/        # Application stacks
├── scripts/              # Automation scripts
└── docs/                # Documentation
```

## 🌐 Environment Architecture

### Development (Azure East US 2)

- **Compute**: Docker Swarm on Standard_B2s VMs
- **Network**: VNet 10.1.0.0/16 with NSGs
- **Storage**: Premium SSD managed disks
- **DNS**: Custom domain (promata.com.br)
- **TLS**: Let's Encrypt via Traefik
- **Database**: PostgreSQL with PgBouncer pooling
- **Monitoring**: Prometheus + Grafana

### Production (AWS US East 1)

- **Compute**: ECS Fargate (512 CPU / 1024 Memory)
- **Network**: VPC 10.0.0.0/16 with public/private subnets
- **Load Balancer**: Application Load Balancer
- **DNS**: Route 53 with ACM certificates
- **Monitoring**: CloudWatch + Container Insights

## 🔧 Component Stack

### Core Services

- **Frontend**: React application (Nginx)
- **Backend**: Node.js API server
- **Cache**: Redis for session storage

### Infrastructure Components

- **Terraform**: Infrastructure provisioning
- **ECS Fargate**: Container service (prod)

### Monitoring & Security

- **Metrics**: Prometheus (dev) / CloudWatch (prod)
- **TLS**: Automated certificate management

## 🔄 Deployment Pipeline

### Development Flow

1. **Infrastructure**: Terraform provisions Azure resources
2. **Deployment**: Docker containers deployed to swarm
3. **Configuration**: Ansible configures services
4. **DNS**: Custom domain setup with Let's Encrypt

### Production Flow

1. **Infrastructure**: Terraform provisions AWS resources
2. **Containers**: Docker images pushed to ECR
3. **Deployment**: ECS Fargate services deployed
4. **DNS**: Custom domain configuration
5. **Health**: ALB health checks ensure availability
4.**Health**: ALB health checks ensure availability

## 🛡️ Security Model

### Network Security

- **Azure**: NSGs restrict traffic to required ports
- **TLS**: End-to-end encryption for all services
- **Development**: Azure Key Vault integration
- **Production**: AWS Secrets Manager
- **CI/CD**: GitHub Secrets for automation
- **Development**: Azure Key Vault integration
- **Production**: AWS Secrets Manager
- **CI/CD**: GitHub Secrets for automation

### Access Control

- **SSH**: Key-based authentication only
- **APIs**: JWT-based authentication
- **Admin**: Multi-factor authentication required
- **Reliability**: High availability and fault tolerance  
- **Security**: Defense in depth approach
- **Maintainability**: Infrastructure as Code practices
