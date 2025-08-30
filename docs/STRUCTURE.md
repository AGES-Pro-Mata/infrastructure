# 🏗️ Pro-Mata Infrastructure Architecture

Technical overview of the Pro-Mata infrastructure components and organization.

## 📁 Repository Structure

```
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
- **DNS**: DuckDNS (promata-dev.duckdns.org)
- **TLS**: Let's Encrypt via Traefik
- **Database**: PostgreSQL with PgBouncer pooling
- **Monitoring**: Prometheus + Grafana

### Production (AWS US East 1) 
- **Compute**: ECS Fargate (512 CPU / 1024 Memory)
- **Network**: VPC 10.0.0.0/16 with public/private subnets
- **Load Balancer**: Application Load Balancer
- **DNS**: Route 53 with ACM certificates
- **Database**: RDS PostgreSQL Multi-AZ
- **Monitoring**: CloudWatch + Container Insights

## 🔧 Component Stack

### Core Services
- **Frontend**: React application (Nginx)
- **Backend**: Node.js API server
- **Database**: PostgreSQL with streaming replication
- **Proxy**: Traefik (dev) / ALB (prod)
- **Cache**: Redis for session storage

### Infrastructure Components
- **Terraform**: Infrastructure provisioning
- **Ansible**: Configuration management (dev only)
- **Docker Swarm**: Container orchestration (dev)
- **ECS Fargate**: Container service (prod)

### Monitoring & Security
- **Metrics**: Prometheus (dev) / CloudWatch (prod)
- **Dashboards**: Grafana (dev) / CloudWatch (prod)
- **Logs**: Centralized via Docker/ECS
- **Secrets**: Azure Key Vault / AWS Secrets Manager
- **TLS**: Automated certificate management

## 🔄 Deployment Pipeline

### Development Flow
1. **Infrastructure**: Terraform provisions Azure resources
2. **Configuration**: Ansible configures VMs and services
3. **Applications**: Docker Swarm deploys service stacks
4. **DNS**: DuckDNS updates with public IP
5. **Health**: Automated health checks verify deployment

### Production Flow  
1. **Infrastructure**: Terraform provisions AWS resources
2. **Applications**: ECS deploys containerized services
3. **DNS**: Route 53 manages domain routing
4. **Health**: ALB health checks ensure availability

## 🛡️ Security Model

### Network Security
- **Azure**: NSGs restrict traffic to required ports
- **AWS**: Security groups with least-privilege access
- **TLS**: End-to-end encryption for all services

### Secret Management
- **Development**: Azure Key Vault integration
- **Production**: AWS Secrets Manager
- **CI/CD**: GitHub Secrets for automation

### Access Control
- **SSH**: Key-based authentication only
- **APIs**: JWT-based authentication
- **Admin**: Multi-factor authentication required

---

**Architecture designed for**:
- **Scalability**: Easy horizontal scaling
- **Reliability**: High availability and fault tolerance  
- **Security**: Defense in depth approach
- **Maintainability**: Infrastructure as Code practices