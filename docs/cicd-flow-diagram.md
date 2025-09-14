# CI/CD Flow Diagram - Template para Lucidchart

## Diagrama Completo do Fluxo CI/CD

```mermaid
graph TB
    %% Developer Workflow
    subgraph "👨‍💻 Development Workflow"
        DEV[Developer]
        LOCAL[Local Development]
        COMMIT[Git Commit]
        PUSH_DEV[Push to Branch]
        
        DEV --> LOCAL
        LOCAL --> COMMIT
        COMMIT --> PUSH_DEV
    end
    
    %% GitHub Actions CI/CD
    subgraph "🤖 GitHub Actions Pipeline"
        subgraph "🔍 Quality Checks"
            LINT[ESLint/Prettier]
            TEST_UNIT[Unit Tests]
            TEST_INT[Integration Tests]
            SECURITY[Security Scan]
        end
        
        subgraph "🏗️ Build Process"
            BUILD_BE[Build Backend]
            BUILD_FE[Build Frontend]
            BUILD_INFRA[Build Infrastructure]
        end
        
        subgraph "📦 Container Registry"
            DOCKER_BUILD[Docker Build]
            DOCKER_PUSH[Push to Registry]
            TAG_LATEST[Tag: latest]
            TAG_VERSION[Tag: v1.x.x]
        end
        
        subgraph "✅ Approval Process"
            AUTO_DEV[Auto Deploy Dev]
            MANUAL_REVIEW[Manual Review]
            APPROVE_PROD[Approve Production]
        end
    end
    
    %% Current Azure Infrastructure
    subgraph "☁️ Current Infrastructure (Azure)"
        subgraph "🌐 Edge Layer"
            CLOUDFLARE[Cloudflare CDN/WAF]
            DNS[DNS Management]
        end
        
        subgraph "⚖️ Load Balancing"
            TRAEFIK[Traefik Reverse Proxy]
            SSL[SSL Termination]
        end
        
        subgraph "🖥️ Azure VMs (Static IPs)"
            MANAGER[Manager Node<br/>🔧 Management Services]
            WORKER[Worker Node<br/>📱 Application Services]
        end
        
        subgraph "📊 Services on Manager"
            PROMETHEUS[Prometheus]
            GRAFANA[Grafana]
            PGADMIN[PgAdmin]
            TRAEFIK_DASH[Traefik Dashboard]
        end
        
        subgraph "🚀 Services on Worker"
            FRONTEND[React Frontend]
            BACKEND[NestJS Backend]
            POSTGRES_PRIMARY[PostgreSQL Primary]
            POSTGRES_REPLICA[PostgreSQL Replica]
            REDIS[Redis Cache]
            UMAMI[Umami Analytics]
            METABASE[Metabase BI]
        end
        
        subgraph "💾 Storage & Security"
            AZURE_STORAGE[Azure Storage<br/>Terraform State]
            KEY_VAULT[Azure Key Vault<br/>Secrets]
            BACKUP[Automated Backups]
        end
    end
    
    %% Future AWS Infrastructure
    subgraph "🌟 Future Infrastructure (AWS)"
        subgraph "🌐 AWS Edge"
            CLOUDFLARE_AWS[Cloudflare CDN/WAF]
            ROUTE53[Route 53 DNS]
        end
        
        subgraph "⚖️ AWS Load Balancing"
            ALB[Application Load Balancer]
            TARGET_GROUPS[Target Groups]
        end
        
        subgraph "🖥️ ECS Fargate (Serverless)"
            ECS_CLUSTER[ECS Fargate Cluster]
            FRONTEND_TASK[Frontend Tasks<br/>Auto-scaling 1-10]
            BACKEND_TASK[Backend Tasks<br/>Auto-scaling 2-20]
        end
        
        subgraph "💾 Managed Data Services"
            RDS_PRIMARY[RDS PostgreSQL<br/>Multi-AZ Primary]
            RDS_REPLICA[RDS Read Replica]
            ELASTICACHE[ElastiCache Redis<br/>Cluster Mode]
            S3[S3 Static Assets]
        end
        
        subgraph "📊 AWS Monitoring"
            CLOUDWATCH[CloudWatch]
            XRAY[X-Ray Tracing]
            CLOUDTRAIL[CloudTrail Audit]
        end
        
        subgraph "🔒 AWS Security"
            SECRETS_MANAGER[Secrets Manager]
            IAM[IAM Roles & Policies]
            VPC[VPC with Private Subnets]
        end
    end
    
    %% Connections - Development Flow
    PUSH_DEV --> LINT
    LINT --> TEST_UNIT
    TEST_UNIT --> TEST_INT
    TEST_INT --> SECURITY
    SECURITY --> BUILD_BE
    SECURITY --> BUILD_FE
    BUILD_BE --> DOCKER_BUILD
    BUILD_FE --> DOCKER_BUILD
    DOCKER_BUILD --> DOCKER_PUSH
    DOCKER_PUSH --> TAG_LATEST
    TAG_LATEST --> AUTO_DEV
    
    %% Connections - Production Flow
    DOCKER_PUSH --> TAG_VERSION
    TAG_VERSION --> MANUAL_REVIEW
    MANUAL_REVIEW --> APPROVE_PROD
    
    %% Connections - Current Azure
    AUTO_DEV --> CLOUDFLARE
    APPROVE_PROD --> CLOUDFLARE
    CLOUDFLARE --> DNS
    DNS --> TRAEFIK
    TRAEFIK --> SSL
    SSL --> MANAGER
    SSL --> WORKER
    
    MANAGER --> PROMETHEUS
    MANAGER --> GRAFANA
    MANAGER --> PGLADMIN
    MANAGER --> TRAEFIK_DASH
    
    WORKER --> FRONTEND
    WORKER --> BACKEND
    WORKER --> POSTGRES_PRIMARY
    WORKER --> POSTGRES_REPLICA
    WORKER --> REDIS
    WORKER --> UMAMI
    WORKER --> METABASE
    
    BACKEND --> POSTGRES_PRIMARY
    BACKEND --> REDIS
    FRONTEND --> BACKEND
    PROMETHEUS --> BACKEND
    GRAFANA --> PROMETHEUS
    
    %% Connections - Future AWS
    CLOUDFLARE_AWS --> ROUTE53
    ROUTE53 --> ALB
    ALB --> TARGET_GROUPS
    TARGET_GROUPS --> FRONTEND_TASK
    TARGET_GROUPS --> BACKEND_TASK
    
    ECS_CLUSTER --> FRONTEND_TASK
    ECS_CLUSTER --> BACKEND_TASK
    
    BACKEND_TASK --> RDS_PRIMARY
    BACKEND_TASK --> ELASTICACHE
    FRONTEND_TASK --> S3
    
    CLOUDWATCH --> ECS_CLUSTER
    XRAY --> BACKEND_TASK
    SECRETS_MANAGER --> BACKEND_TASK
    
    %% Styling
    classDef azure fill:#e8f5e8,stroke:#4caf50,stroke-width:2px
    classDef aws fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    classDef cicd fill:#e3f2fd,stroke:#2196f3,stroke-width:2px
    classDef dev fill:#f3e5f5,stroke:#9c27b0,stroke-width:2px
    classDef critical fill:#ffebee,stroke:#f44336,stroke-width:3px
    
    class MANAGER,WORKER,AZURE_STORAGE,KEY_VAULT azure
    class ALB,ECS_CLUSTER,RDS_PRIMARY,CLOUDWATCH aws
    class LINT,TEST_UNIT,DOCKER_BUILD,DOCKER_PUSH cicd
    class DEV,LOCAL,COMMIT dev
    class POSTGRES_PRIMARY,BACKEND,KEY_VAULT critical
```

## Diagrama de Arquitetura Detalhada

```mermaid
architecture-beta
    group api(cloud)[API Layer]
    
    service db(database)[Database] in api
    service disk1(disk)[Storage] in api
    service disk2(disk)[Logs] in api
    service server(server)[Server] in api

    db:R -- L:server
    disk1:T -- B:server
    disk2:T -- B:db
```

## Fluxo de Deployment Responsivo

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant DH as Docker Hub
    participant Webhook as Webhook Service
    participant Azure as Azure Infrastructure
    participant CF as Cloudflare
    participant Users as End Users
    
    Note over Dev,Users: Responsive CI/CD Flow - Latest Tag Trigger
    
    Dev->>GH: Push code to main branch
    GH->>GH: Run GitHub Actions
    
    par Build Process
        GH->>GH: Run tests
        GH->>GH: Build Docker images
    and Security
        GH->>GH: Security scan
        GH->>GH: Vulnerability check
    end
    
    GH->>DH: Push images with 'latest' tag
    DH->>Webhook: Trigger webhook on 'latest' tag
    
    Note over Webhook,Azure: Automatic deployment trigger
    
    Webhook->>GH: Trigger infrastructure deployment
    GH->>Azure: Deploy to development environment
    
    par Infrastructure Update
        Azure->>Azure: Update Docker Swarm services
        Azure->>Azure: Rolling deployment
    and DNS Update
        Azure->>CF: Update DNS records
        CF->>CF: Propagate changes
    end
    
    Azure->>Azure: Health checks
    Azure->>GH: Deployment status
    GH->>Dev: Notification (Slack/Email)
    
    Note over Users: Frontend team can now test latest changes
    Users->>CF: Access dev.promata.com.br
    CF->>Azure: Route traffic
    Azure->>Users: Serve updated application
```

## Comparação de Arquiteturas

```mermaid
gitgraph:
    options:
        "theme": "base"
    
    commit id: "Azure VMs (Current)"
    branch aws-migration
    commit id: "AWS Planning"
    commit id: "Infrastructure as Code"
    commit id: "ECS Fargate Setup"
    commit id: "RDS Migration"
    commit id: "Static IPs Config"
    
    checkout main
    commit id: "Production Stable"
    
    checkout aws-migration
    commit id: "Testing Phase"
    commit id: "Data Migration"
    
    checkout main
    merge aws-migration
    commit id: "AWS Production"
```

---

## Métricas de Comparação

| Aspecto | Azure Atual | AWS Futuro | Benefício |
|---------|-------------|------------|-----------|
| **Custo** | $200/mês | $150/mês | -25% |
| **Uptime** | 99.5% | 99.9% | +0.4% |
| **Scaling** | Manual | Auto | Automático |
| **Maintenance** | Alta | Baixa | Managed Services |
| **Response Time** | 2s | <500ms | -75% |

## Checklist de Migração

- [ ] **Phase 1**: Setup AWS Infrastructure (2 weeks)
  - [ ] Terraform AWS modules
  - [ ] ECS Fargate configuration
  - [ ] RDS setup with Multi-AZ
  - [ ] ElastiCache Redis cluster
  - [ ] Static IP allocation (Elastic IPs)

- [ ] **Phase 2**: Data Migration (1 week)
  - [ ] Database export from Azure
  - [ ] S3 data transfer
  - [ ] RDS import and validation
  - [ ] Application configuration update

- [ ] **Phase 3**: DNS Cutover (3 days)
  - [ ] Cloudflare configuration
  - [ ] IP address switch
  - [ ] Traffic monitoring
  - [ ] Rollback plan testing

- [ ] **Phase 4**: Optimization (1 week)
  - [ ] Performance tuning
  - [ ] Cost optimization
  - [ ] Monitoring setup
  - [ ] Documentation update