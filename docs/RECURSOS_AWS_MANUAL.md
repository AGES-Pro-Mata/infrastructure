# 📋 Recursos AWS - Guia de Provisionamento Manual

Este documento detalha todos os recursos AWS necessários para replicar a infraestrutura Pro-Mata, baseado no código Terraform simplificado.

## 🎯 Resumo dos Recursos Necessários

### **Total de Recursos:**

- **2 EC2 Instances** (t3.medium)
- **2 Elastic IPs** (IPs estáticos)
- **1 S3 Bucket** (arquivos da aplicação)
- **1 VPC** com subnets e gateways
- **3 Security Groups** (firewall)
- **1 SES Domain** (email)
- **Cloudflare DNS** (externo)

### **Custo Estimado:** ~$45-55/mês

---

## 🌐 1. NETWORKING (VPC)

### **VPC Principal**

```
Nome: promata-prod-vpc
CIDR: 10.0.0.0/16
DNS Hostnames: Habilitado
DNS Support: Habilitado
```

### **Internet Gateway**

```
Nome: promata-prod-igw
Anexar à VPC criada acima
```

### **Subnets Públicas**

```
Subnet 1:
- Nome: promata-prod-public-subnet-1
- CIDR: 10.0.1.0/24
- AZ: us-east-2a
- Auto-assign public IP: Sim

Subnet 2:
- Nome: promata-prod-public-subnet-2
- CIDR: 10.0.2.0/24
- AZ: us-east-2b
- Auto-assign public IP: Sim
```

### **Route Table Pública**
```
Nome: promata-prod-public-rt
Rotas:
- 0.0.0.0/0 → Internet Gateway
Associar com ambas subnets públicas
```

---

## 🔒 2. SECURITY GROUPS

### **SG Manager (promata-prod-manager-sg)**
```
Inbound Rules:
- SSH (22) ← 0.0.0.0/0
- HTTP (80) ← 0.0.0.0/0
- HTTPS (443) ← 0.0.0.0/0
- Traefik Dashboard (8080) ← 0.0.0.0/0
- Prometheus (9090) ← 10.0.0.0/16
- Grafana (3000) ← 10.0.0.0/16
- Node Exporter (9100) ← 10.0.0.0/16
- Postgres Exporter (9187) ← 10.0.0.0/16
- Docker Swarm Manager (2377) ← 10.0.0.0/16
- Docker Swarm Communication (7946 TCP/UDP) ← 10.0.0.0/16
- Docker Swarm Overlay (4789 UDP) ← 10.0.0.0/16

Outbound Rules:
- All traffic (0-65535) → 0.0.0.0/0
```

### **SG Worker (promata-prod-worker-sg)**
```
Inbound Rules:
- SSH (22) ← 0.0.0.0/0
- HTTP (80) ← 0.0.0.0/0
- HTTPS (443) ← 0.0.0.0/0
- Application Ports (3000-3010) ← 10.0.0.0/16
- PostgreSQL (5432-5433) ← 10.0.0.0/16
- Prisma Studio (5555) ← 10.0.0.0/16
- Node Exporter (9100) ← 10.0.0.0/16
- Postgres Exporter (9187) ← 10.0.0.0/16
- Docker Swarm Communication (7946 TCP/UDP) ← 10.0.0.0/16
- Docker Swarm Overlay (4789 UDP) ← 10.0.0.0/16

Outbound Rules:
- All traffic (0-65535) → 0.0.0.0/0
```

### **SG Database (promata-prod-database-sg)**
```
Inbound Rules:
- PostgreSQL (5432) ← SG Manager
- PostgreSQL (5432) ← SG Worker
- PostgreSQL Replica (5433) ← SG Manager
- PostgreSQL Replica (5433) ← SG Worker

Outbound Rules:
- All traffic (0-65535) → 0.0.0.0/0
```

---

## 💻 3. EC2 INSTANCES

### **Configurações Gerais**
```
AMI: Ubuntu 22.04 LTS (ami-0ea3c35c5c3284d82)
Instance Type: t3.medium
Storage: 50GB gp3 encrypted
Key Pair: promata-prod-key (criar novo)
```

### **Instance 1 - Manager**
```
Nome: promata-prod-manager
Subnet: promata-prod-public-subnet-1
Security Group: promata-prod-manager-sg
User Data: [Script de inicialização - ver seção Scripts]
```

### **Instance 2 - Worker**
```
Nome: promata-prod-worker
Subnet: promata-prod-public-subnet-2
Security Group: promata-prod-worker-sg
User Data: [Script de inicialização - ver seção Scripts]
```

### **EBS Volumes Adicionais (Opcionais)**
```
Manager Data Volume:
- Size: 30GB gp3 encrypted
- Mount: /dev/sdf

Worker Data Volume:
- Size: 50GB gp3 encrypted
- Mount: /dev/sdf
```

---

## 🌍 4. ELASTIC IPs

### **EIP Manager**
```
Nome: promata-prod-manager-eip
Associar com: Instance Manager
```

### **EIP Worker**
```
Nome: promata-prod-worker-eip
Associar com: Instance Worker
```

---

## 📦 5. S3 BUCKET

### **Bucket Aplicação**
```
Nome: promata-prod-app-files
Região: us-east-2
Versioning: Habilitado
Encryption: AES256
Public Access: Bloqueado (todos os 4 checkboxes)

CORS Configuration:
{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "POST", "PUT", "DELETE", "HEAD"],
      "AllowedOrigins": ["*"],
      "MaxAgeSeconds": 3000
    }
  ]
}
```

---

## 📧 6. SES (SIMPLE EMAIL SERVICE)

### **Domain Identity**
```
Domain: promata.com.br
Verification: Via DNS records no Cloudflare
```

### **Email Identities (Development)**
```
Emails para verificar:
- admin@promata.com.br
- noreply@promata.com.br
- support@promata.com.br
```

### **Configuration Set**
```
Nome: promata-prod-ses-config
TLS Policy: Require
Event Destination: CloudWatch (opcional)
```

---

## 🌐 7. CLOUDFLARE DNS RECORDS

### **Produção (promata.com.br)**
```
Tipo A Records:
- @ → EIP Manager
- www → EIP Manager
- api → EIP Worker
- traefik → EIP Manager
- grafana → EIP Manager
- prometheus → EIP Manager
- analytics → EIP Worker
- metabase → EIP Worker
- prisma → EIP Manager

Email Records:
- MX: 10 inbound-smtp.us-east-2.amazonaws.com
- TXT (SPF): v=spf1 include:amazonses.com ~all
```

---

## 🔑 8. TAGS PADRONIZADAS

### **Tags para TODOS os recursos:**
```
Project: promata
Environment: prod
ManagedBy: manual
Owner: cppn-pucrs
```

---

## 💰 9. ESTIMATIVA DE CUSTOS

### **Custos Mensais (us-east-2):**
```
2x EC2 t3.medium (24/7): ~$38.00
2x Elastic IPs: ~$7.20
EBS Storage (100GB total): ~$10.00
S3 Storage (estimado): ~$2.00
SES (estimado): ~$1.00
Data Transfer: ~$3.00

TOTAL ESTIMADO: ~$61.20/mês
```

### **Custos Únicos:**
```
EBS Snapshots: Conforme uso
Data Transfer OUT: Conforme tráfego
```

---

## ⚠️ NOTAS IMPORTANTES

1. **Região:** Todos os recursos devem ser criados em **us-east-2** (Ohio)
2. **Naming:** Usar sempre sufixo `-prod` nos nomes dos recursos
3. **Keys:** Gerar e baixar key pair antes de criar instâncias
4. **Ordem:** Seguir ordem: VPC → Subnets → Security Groups → Instances → EIPs
5. **DNS:** Configurar Cloudflare após obter os Elastic IPs
6. **SES:** Verificar domain e emails antes de usar em produção
