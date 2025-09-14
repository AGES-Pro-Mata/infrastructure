# Lucidchart Diagram Guide - Pro-Mata CI/CD & Deployment

## Diagrama Visual para Lucidchart - Instruções Detalhadas

### Visão Geral

Este guia fornece instruções detalhadas para criar um diagrama abrangente no Lucidchart mostrando:

1. **CI/CD Pipeline Atual** (Test, Build & Push)
2. **Processo de Deploy Atual** (Azure)
3. **Arquitetura Futura** (AWS com IPs estáticos)

---

## 🎨 **SEÇÃO 1: CI/CD Pipeline (Topo do Diagrama)**

### Área: "GitHub Actions Workflow"

**Posição**: Parte superior do diagrama
**Cor de Fundo**: Azul claro (#E3F2FD)

#### Fluxo de Desenvolvimento (Linha Superior)

```mermaid
[Developer] → [Git Push] → [GitHub Repo] → [Actions Trigger]
    ↓
[Lint & Tests] → [Build Docker Images] → [Push to Registry] → [Deploy Dev]
```

**Elementos visuais**:

- **Developer**: Ícone de pessoa
- **Git Push**: Seta verde com "git push"
- **GitHub Repo**: Logo GitHub
- **Actions Trigger**: Ícone de engrenagem
- **Lint & Tests**: Ícone de checklist verde
- **Build Docker Images**: Logo Docker azul
- **Push to Registry**: Ícone de upload para Docker Hub
- **Deploy Dev**: Ícone de servidor com "DEV"

#### Fluxo de Produção (Linha Inferior)

```plain
[Git Push to Main] → [Security Scan] → [Integration Tests] → [Build Production Images]
    ↓
[Push to Registry] → [Terraform Plan] → [Manual Approval] → [Deploy Production]
```

**Elementos visuais**:

- **Security Scan**: Ícone de escudo
- **Integration Tests**: Ícone de engrenagens conectadas
- **Manual Approval**: Ícone de pessoa com checkmark
- **Deploy Production**: Ícone de servidor com "PROD"

---

## 🏗️ **SEÇÃO 2: Arquitetura Atual - Azure (Centro-Esquerda)**

### Área: "Current Azure Infrastructure"

**Posição**: Centro-esquerda do diagrama
**Cor de Fundo**: Verde claro (#E8F5E8)

#### Camada Externa

```plain
[Internet Users] → [Cloudflare CDN/WAF] → [Azure Load Balancer]
```

#### Camada de Aplicação Azure

```plain
┌─ Azure Resource Group ──────────────────────┐
│                                             │
│  ┌─ Manager Node (Static IP) ────────────┐  │
│  │  • Traefik Reverse Proxy             │  │
│  │  • Prometheus Monitoring             │  │  
│  │  • Grafana Dashboards                │  │
│  │  • PgAdmin Database Admin            │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  ┌─ Worker Node (Static IP) ─────────────┐  │
│  │  • React Frontend                    │  │
│  │  • NestJS Backend                    │  │
│  │  • PostgreSQL Primary                │  │
│  │  • PostgreSQL Replica                │  │
│  │  • Redis Cache                       │  │
│  │  • Umami Analytics                   │  │
│  │  • Metabase BI                       │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  ┌─ Storage & Security ───────────────────┐ │
│  │  • Azure Storage (Terraform State)   │  │
│  │  • Azure Key Vault (Secrets)         │  │
│  │  • Azure Backup (Database Backups)   │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

**Elementos visuais detalhados**:

- **Manager Node**: Retângulo azul com ícones de serviços
- **Worker Node**: Retângulo verde com ícones de aplicações
- **Storage**: Retângulo amarelo com ícones de armazenamento
- **Conexões**: Setas bidirecionais entre nós
- **IPs Estáticos**: Caixas pequenas com "Static IP" em vermelho

---

## 🚀 **SEÇÃO 3: Arquitetura Futura - AWS (Centro-Direita)**

### Área: "Future AWS Infrastructure"

**Posição**: Centro-direita do diagrama
**Cor de Fundo**: Laranja claro (#FFF3E0)

#### Camada AWS Serverless

```plain
┌─ AWS Cloud Infrastructure ──────────────────┐
│                                             │
│  ┌─ Application Load Balancer ─────────────┐ │
│  │  • AWS ALB with SSL                    │  │
│  │  • Health Checks                       │  │
│  │  • Auto Scaling                        │  │
│  └───────────────────────────────────────────┘ │
│                                             │
│  ┌─ ECS Fargate Cluster ──────────────────┐  │
│  │  ┌─ Frontend Service ─────────────────┐ │  │
│  │  │  • React App (Serverless)         │ │  │
│  │  │  • Auto-scaling 1-10 tasks       │ │  │
│  │  └───────────────────────────────────┘ │  │
│  │  ┌─ Backend Service ──────────────────┐ │  │
│  │  │  • NestJS API (Serverless)        │ │  │
│  │  │  • Auto-scaling 2-20 tasks       │ │  │
│  │  └───────────────────────────────────┘ │  │
│  └───────────────────────────────────────────┘ │
│                                             │
│  ┌─ Managed Data Services ─────────────────┐  │
│  │  • RDS PostgreSQL Multi-AZ            │  │
│  │  • ElastiCache Redis Cluster          │  │
│  │  • S3 Bucket (Static Assets)          │  │
│  └───────────────────────────────────────────┘ │
│                                             │
│  ┌─ Monitoring & Security ─────────────────┐  │
│  │  • CloudWatch Logs & Metrics          │  │
│  │  • X-Ray Distributed Tracing          │  │
│  │  • Secrets Manager                    │  │
│  │  • IAM Roles & Policies               │  │
│  └───────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

#### IPs Estáticos AWS (Destacar)

```plain
┌─ Static IP Configuration ───────────────────┐
│  • Elastic IP #1 → ALB Primary              │
│  • Elastic IP #2 → ALB Secondary            │
│  • Route 53 → Cloudflare Integration       │
│  • Infrastructure as Code (Terraform)      │
└─────────────────────────────────────────────┘
```

---

## 🔄 **SEÇÃO 4: Processo de Migração (Parte Inferior)**

### Área: "Migration Strategy"

**Posição**: Parte inferior do diagrama
**Cor de Fundo**: Roxo claro (#F3E5F5)

#### Timeline de Migração

```plain
Phase 1: Setup AWS Infrastructure (2 weeks)
[Terraform AWS] → [ECS Setup] → [RDS Setup] → [Testing]

Phase 2: Data Migration (1 week)  
[Database Export] → [S3 Transfer] → [RDS Import] → [Validation]

Phase 3: DNS Cutover (3 days)
[Cloudflare Config] → [IP Switch] → [Traffic Monitor] → [Rollback Plan]

Phase 4: Optimization (1 week)
[Performance Tuning] → [Cost Optimization] → [Monitoring Setup]
```

---

## 📊 **ELEMENTOS VISUAIS ESPECIAIS**

### Legenda (Canto inferior direito)

```plain
🟢 Atual (Azure)     🟠 Futuro (AWS)     🔵 Comum (ambos)
Static IP            Managed Service      Container
Database             Monitoring          Load Balancer
```

### Fluxo de Dados (Setas coloridas)

- **Verde**: Fluxo de dados atual
- **Laranja**: Fluxo de dados futuro  
- **Azul**: CI/CD Pipeline
- **Vermelho**: Comunicação crítica (DB, Auth)

### Métricas de Performance (Caixas)

```plain
┌─ Azure Current ─────┐    ┌─ AWS Target ────────┐
│ • 99.5% Uptime     │    │ • 99.9% Uptime      │
│ • 2s Response Time │    │ • <500ms Response   │
│ • Manual Scaling   │    │ • Auto Scaling      │
│ • 2 Static IPs     │    │ • 2 Elastic IPs     │
└────────────────────┘    └─────────────────────┘
```

---

## 🎯 **INSTRUÇÕES ESPECÍFICAS PARA LUCIDCHART**

### Passo 1: Layout Básico

1. **Canvas Size**: A3 ou maior
2. **Grid**: Ativado para alinhamento
3. **Zoom**: 75% para visão geral

### Passo 2: Cores e Estilos

1. **CI/CD Section**: #E3F2FD (azul claro)
2. **Azure Section**: #E8F5E8 (verde claro)  
3. **AWS Section**: #FFF3E0 (laranja claro)
4. **Migration Section**: #F3E5F5 (roxo claro)

### Passo 3: Ícones Recomendados

- **AWS**: Use biblioteca oficial AWS
- **Azure**: Use biblioteca oficial Azure
- **Docker**: Logo oficial Docker
- **GitHub**: Logo oficial GitHub
- **Database**: Ícone de cilindro
- **Load Balancer**: Ícone de balanceador

### Passo 4: Conectores

- **Setas grossas**: Fluxos principais
- **Setas finas**: Comunicação interna
- **Linhas tracejadas**: Conexões futuras
- **Linhas vermelhas**: Conexões críticas

### Passo 5: Anotações

- **Caixas de texto**: Para métricas importantes
- **Callouts**: Para destacar IPs estáticos
- **Notas**: Para explicar decisões arquiteturais

---

## 📝 **TEXTO EXPLICATIVO PARA INCLUIR**

### Título Principal

## Pro-Mata Platform: CI/CD Pipeline & Infrastructure Evolution

### Subtítulos

1. **"GitHub Actions Workflow"** (seção CI/CD)
2. **"Current Azure Infrastructure"** (arquitetura atual)
3. **"Future AWS Serverless Architecture"** (arquitetura futura)
4. **"Migration Roadmap"** (estratégia de migração)

### Notas Importantes

- **Static IPs**: Destacar que ambas arquiteturas mantêm IPs estáticos
- **Zero Downtime**: Enfatizar estratégia de migração sem interrupção
- **Cost Optimization**: AWS Fargate vs Azure VMs
- **Auto Scaling**: Benefícios da arquitetura serverless

---

Este diagrama deve servir como documentação técnica completa e também como ferramenta de comunicação para stakeholders não-técnicos, mostrando claramente a evolução da infraestrutura e os benefícios da migração proposta.
