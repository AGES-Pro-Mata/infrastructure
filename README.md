# 🏗️ Pro-Mata Infrastructure

Infraestrutura automatizada do Pro-Mata AGES: Docker Swarm (Azure dev), ECS Fargate (AWS prod), com DNS dinâmico e alta disponibilidade.

## 🌟 Arquitetura do Ambiente de Desenvolvimento

### 🎯 Azure for Students - Docker Swarm HA

```mermaid
graph TB
    subgraph "Internet"
        LE[Let's Encrypt<br/>Certificados TLS]
    end
    
    subgraph "Azure East US 2"
        subgraph "Docker Swarm Cluster"
            LB[Traefik<br/>Load Balancer & Proxy]
            
            subgraph "Application Services"
                FE1[Frontend<br/>Replica 1]
                FE2[Frontend<br/>Replica 2]
                BE1[Backend<br/>Replica 1]
                BE2[Backend<br/>Replica 2]
            end
            
            subgraph "Database Cluster"
                PGB[PgBouncer<br/>Connection Pool]
                PG1[(PostgreSQL<br/>Primary)]
                PG2[(PostgreSQL<br/>Replica)]
            end
            
            subgraph "DNS & Monitoring"
                CDNS[CoreDNS<br/>Service Discovery]
                MON[Monitoring<br/>Prometheus + Grafana]
            end
        end
    end
    
     --> LB
    LE --> LB
    LB --> FE1
    LB --> FE2
    LB --> BE1
    LB --> BE2
    BE1 --> PGB
    BE2 --> PGB
    PGB --> PG1
    PG1 -.-> PG2
    CDNS --> LB
    MON --> BE1
    MON --> PG1
```

## 🚀 Quick Start

### Prerequisites
- Terraform >= 1.8.0, Ansible >= 8.5.0, Docker >= 24.0.0
- Azure CLI (dev) or AWS CLI (prod)

### Deploy

```bash
# Setup environment
cp environments/dev/.env.dev.example environments/dev/.env.dev
# Edit configuration

# Or step by step
make terraform-apply ansible-configure stacks-deploy
```

## 📁 Project Structure

```
infrastructure/
├── environments/{dev,prod}/      # Environment configs
├── terraform/                   # IaC definitions
├── ansible/                     # Configuration management
├── docker/stacks/              # Application stacks
├── scripts/                    # Automation scripts
└── docs/                       # Documentation
```

## 🔧 Architecture Components

**Networking**: (DNS), Traefik (proxy/LB), CoreDNS (service discovery)
**Database**: PostgreSQL HA with PgBouncer connection pooling
**Security**: Let's Encrypt SSL, Azure NSG/AWS security groups
**Monitoring**: Prometheus + Grafana, centralized logging

## ⚙️ Configuration

Copy and edit environment files:
```bash
cp environments/dev/.env.dev.example environments/dev/.env.dev
```

Key variables: Azure subscription, domain, database passwords, image tags.

### Available Commands

Run `make help` to see all available commands including:
- `make status` - Infrastructure status  
- `make health` - Health checks
- `make logs SERVICE=name` - Service logs

## 🚀 Testing Your IaC

### Terraform Validation
```bash
cd environments/dev/azure
terraform validate    # Validate syntax
terraform plan        # Preview changes
```

### Infrastructure Tests
```bash
make health                    # Health checks
scripts/test-infrastructure.sh # Test suite
scripts/health-check.sh       # Service health
```

### Full Deployment Test

```bash
make terraform-plan   # Validate infrastructure
make status          # Verify deployment
```

## 🔄 Maintenance

### Updates
```bash
make update SERVICE=backend   # Update specific service
make rollback                # Emergency rollback
./scripts/backup-database.sh # Database backup
```

### Monitoring


Alerts configured for service downtime, resource usage >80%, SSL expiration

## 🛠️ Troubleshooting

```bash
# Status checks
docker node ls && docker service ls
make status

# Service logs
make logs SERVICE=backend

# DNS/connectivity

# Emergency rollback
./scripts/rollback.sh
```

## 🔮 Production Roadmap

**Current**: Docker Swarm on Azure (dev)  
**Target**: ECS Fargate on AWS (prod) with RDS, Route 53, CloudWatch

---

**Pro-Mata Infrastructure** - AGES PUCRS  
*Automated, scalable infrastructure for Pro-Mata system*
