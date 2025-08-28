# 🏗️ Pro-Mata Infrastructure

Este repositório armazena artefatos específicos de infraestrutura para o projeto Pro-Mata AGES, incluindo configurações Terraform, playbooks Ansible, Dockerfiles e scripts de CI/CD.

## 📁 Estrutura do Projeto

```plaintext
infra/
├── README.md
├── .github/workflows/           # GitHub Actions (padrão frontend)
│   ├── ci-cd.yml               # Pipeline principal (DESABILITADO)
│   ├── discord-notify-extended.yml  # Notificações Discord
│   ├── gitlab-sync.yml         # Sincronização GitLab  
│   └── notify-pr.yml           # Notificações de PR
├── environments/               # Environment-specific infrastructure
│   ├── dev/
│   │   └── azure/              # Development Azure infrastructure  
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       ├── providers.tf
│   │       ├── cloud-init.yml
│   │       └── modules/
│   │           └── common/
│   ├── staging/
│   │   └── azure/              # Staging Azure infrastructure
│   └── prod/
│       └── aws/                # Production AWS infrastructure (ECS Fargate)
├── deployment/
│   ├── ansible/                # Configuração e Deploy
│   │   ├── playbooks/
│   │   │   ├── ansible.cfg
│   │   │   ├── swarm_setup.yml
│   │   │   └── stack.env.j2
│   │   └── roles/
│   │       ├── networking/
│   │       │   └── coredns/
│   │       └── database/
│   │           ├── postgresql/
│   │           ├── pgbouncer/
│   │           └── pgadmin/
│   └── swarm/
│       └── stack.yml.j2
├── docker/                     # Configurações Docker
│   ├── backend/
│   │   ├── Dockerfile.dev
│   │   ├── Dockerfile.prod
│   │   └── docker-compose.backend.yml
│   ├── frontend/
│   │   ├── Dockerfile.dev
│   │   ├── Dockerfile.prod
│   │   └── docker-compose.frontend.yml
│   └── database/
│       ├── postgresql/
│       ├── pgbouncer/
│       └── pgadmin/
├── environments/               # Configurações por Ambiente
│   ├── dev/
│   │   └── .env.dev           # Azure East US 2
│   ├── staging/
│   │   └── .env.staging       # Azure East US 2  
│   ├── prod/
│   │   └── .env.prod          # AWS US East 1
│   └── local/
│       └── .env.local
├── monitoring/                 # Observabilidade
│   ├── prometheus/
│   ├── grafana/
│   └── logs/
├── scripts/                    # Scripts de Automação
│   ├── sync-infrastructure.py  # Sincronização GitLab
│   ├── notify-deployment.sh    # Notificações Discord
│   ├── rollback.sh            # Rollback automatizado
│   └── test-infrastructure.sh  # Testes de infraestrutura
└── docs/
    ├── SETUP.md
    └── STRUCTURE.md
```

## 🌐 Arquitetura de Ambientes

### 🧪 **Development & Staging** (Azure East US 2)

- **Plataforma**: Azure Container Instances + Docker Swarm
- **Compute**: Standard_B2s/B2ms VMs
- **Rede**: VNet 10.1.0.0/16 (dev), 10.2.0.0/16 (staging)
- **Armazenamento**: Premium SSD
- **Monitoramento**: Azure Monitor

### 🌟 **Production** (AWS US East 1)

- **Plataforma**: Amazon ECS Fargate
- **Compute**: Fargate 512 CPU / 1024 Memory
- **Rede**: VPC 10.0.0.0/16 com subnets privadas/públicas
- **Balanceamento**: Application Load Balancer
- **Monitoramento**: CloudWatch + Container Insights

## 🔧 Configuração de Infraestrutura

### Terraform Modules

- **`terraform/azure/`**: Infraestrutura de desenvolvimento e staging
- **`terraform/aws/`**: Infraestrutura de produção
- **`terraform/modules/common/`**: Módulos reutilizáveis

### Ansible Roles

- **`deployment/ansible/roles/`**: Configuração automática de serviços
- **`deployment/swarm/`**: Configuração do Docker Swarm para Azure

### Environment Variables

- **`environments/dev/`**: Configurações de desenvolvimento
- **`environments/staging/`**: Configurações de staging  
- **`environments/prod/`**: Configurações de produção
- **`environments/local/`**: Desenvolvimento local
