# 🛠️ Configuração Passo-a-Passo - AWS Console

Este guia detalha como criar manualmente a infraestrutura Pro-Mata no console da AWS, seguindo a ordem correta de dependências.

## 📋 **PRÉ-REQUISITOS**

- [ ] Conta AWS com permissões administrativas
- [ ] Região configurada para **us-east-2** (Ohio)
- [ ] Conta Cloudflare com domínio promata.com.br
- [ ] Chave SSH gerada localmente

---

## 🔧 **PASSO 1: CRIAR VPC E NETWORKING**

### **1.1 Criar VPC**
1. **AWS Console** → **VPC** → **Create VPC**
2. **Configurações:**
   ```
   Name: promata-prod-vpc
   IPv4 CIDR: 10.0.0.0/16
   IPv6 CIDR: No IPv6 CIDR block
   Tenancy: Default

   Tags:
   - Project: promata
   - Environment: {dev|prod}
   - ManagedBy: manual
   ```

### **1.2 Criar Internet Gateway**
1. **VPC** → **Internet Gateways** → **Create internet gateway**
2. **Configurações:**
   ```
   Name: promata-prod-igw

   Tags:
   - Project: promata
   - Environment: {dev|prod}
   ```
3. **Attach to VPC:** Selecionar a VPC criada

### **1.3 Criar Subnets Públicas**
1. **VPC** → **Subnets** → **Create subnet**
2. **Subnet 1:**
   ```
   VPC: promata-prod-vpc
   Name: promata-prod-public-subnet-1
   AZ: us-east-2a
   IPv4 CIDR: 10.0.1.0/24
   Auto-assign public IPv4: Enable
   ```
3. **Subnet 2:**
   ```
   VPC: promata-prod-vpc
   Name: promata-prod-public-subnet-2
   AZ: us-east-2b
   IPv4 CIDR: 10.0.2.0/24
   Auto-assign public IPv4: Enable
   ```

### **1.4 Criar Route Table**
1. **VPC** → **Route Tables** → **Create route table**
2. **Configurações:**
   ```
   Name: promata-prod-public-rt
   VPC: promata-prod-vpc
   ```
3. **Adicionar Route:**
   - **Routes** → **Edit routes** → **Add route**
   - Destination: `0.0.0.0/0`
   - Target: Internet Gateway criado
4. **Associar Subnets:**
   - **Subnet associations** → **Edit subnet associations**
   - Selecionar ambas subnets públicas

---

## 🔒 **PASSO 2: CRIAR SECURITY GROUPS**

### **2.1 Security Group Manager**
1. **EC2** → **Security Groups** → **Create security group**
2. **Configurações:**
   ```
   Name: promata-prod-manager-sg
   Description: Security group for manager node
   VPC: promata-prod-vpc
   ```
3. **Inbound Rules:**
   ```
   SSH         | TCP | 22   | 0.0.0.0/0
   HTTP        | TCP | 80   | 0.0.0.0/0
   HTTPS       | TCP | 443  | 0.0.0.0/0
   Traefik     | TCP | 8080 | 0.0.0.0/0
   Prometheus  | TCP | 9090 | 10.0.0.0/16
   Grafana     | TCP | 3000 | 10.0.0.0/16
   Node Exp    | TCP | 9100 | 10.0.0.0/16
   PG Exp      | TCP | 9187 | 10.0.0.0/16
   Swarm Mgr   | TCP | 2377 | 10.0.0.0/16
   Swarm Comm  | TCP | 7946 | 10.0.0.0/16
   Swarm Comm  | UDP | 7946 | 10.0.0.0/16
   Swarm Over  | UDP | 4789 | 10.0.0.0/16
   ```

### **2.2 Security Group Worker**
1. **Create security group**
2. **Configurações:**
   ```
   Name: promata-prod-worker-sg
   Description: Security group for worker node
   VPC: promata-prod-vpc
   ```
3. **Inbound Rules:**
   ```
   SSH         | TCP | 22        | 0.0.0.0/0
   HTTP        | TCP | 80        | 0.0.0.0/0
   HTTPS       | TCP | 443       | 0.0.0.0/0
   App Ports   | TCP | 3000-3010 | 10.0.0.0/16
   PostgreSQL  | TCP | 5432-5433 | 10.0.0.0/16
   Prisma      | TCP | 5555      | 10.0.0.0/16
   Node Exp    | TCP | 9100      | 10.0.0.0/16
   PG Exp      | TCP | 9187      | 10.0.0.0/16
   Swarm Comm  | TCP | 7946      | 10.0.0.0/16
   Swarm Comm  | UDP | 7946      | 10.0.0.0/16
   Swarm Over  | UDP | 4789      | 10.0.0.0/16
   ```

### **2.3 Security Group Database**
1. **Create security group**
2. **Configurações:**
   ```
   Name: promata-prod-database-sg
   Description: Security group for database access
   VPC: promata-prod-vpc
   ```
3. **Inbound Rules:**
   ```
   PostgreSQL | TCP | 5432 | SG Manager
   PostgreSQL | TCP | 5432 | SG Worker
   PG Replica | TCP | 5433 | SG Manager
   PG Replica | TCP | 5433 | SG Worker
   ```

---

## 💻 **PASSO 3: CRIAR EC2 INSTANCES**

### **3.1 Preparar Key Pair**
1. **EC2** → **Key Pairs** → **Create key pair**
2. **Configurações:**
   ```
   Name: promata-prod-key
   Type: RSA
   Format: .pem
   ```
3. **Download** e salvar em local seguro

### **3.2 Criar Instance Manager**
1. **EC2** → **Instances** → **Launch instance**
2. **Configurações:**
   ```
   Name: promata-prod-manager
   AMI: Ubuntu Server 22.04 LTS (Free tier eligible)
   Instance type: t3.medium
   Key pair: promata-prod-key

   Network settings:
   - VPC: promata-prod-vpc
   - Subnet: promata-prod-public-subnet-1
   - Auto-assign public IP: Enable
   - Security groups: promata-prod-manager-sg

   Storage:
   - Root volume: 50 GiB, gp3, Encrypted

   Advanced details:
   - User data: [Ver scripts de inicialização]
   ```

### **3.3 Criar Instance Worker**
1. **Launch instance**
2. **Configurações:**
   ```
   Name: promata-prod-worker
   AMI: Ubuntu Server 22.04 LTS
   Instance type: t3.medium
   Key pair: promata-prod-key

   Network settings:
   - VPC: promata-prod-vpc
   - Subnet: promata-prod-public-subnet-2
   - Auto-assign public IP: Enable
   - Security groups: promata-prod-worker-sg

   Storage:
   - Root volume: 50 GiB, gp3, Encrypted
   ```

---

## 🌍 **PASSO 4: CONFIGURAR ELASTIC IPs**

### **4.1 Allocate Elastic IPs**
1. **EC2** → **Elastic IPs** → **Allocate Elastic IP address**
2. **Manager EIP:**
   ```
   Name: promata-prod-manager-eip
   Network Border Group: us-east-2
   ```
3. **Worker EIP:**
   ```
   Name: promata-prod-worker-eip
   Network Border Group: us-east-2
   ```

### **4.2 Associate Elastic IPs**
1. **Selecionar Manager EIP** → **Actions** → **Associate Elastic IP address**
   - Instance: promata-prod-manager
2. **Selecionar Worker EIP** → **Actions** → **Associate Elastic IP address**
   - Instance: promata-prod-worker

---

## 📦 **PASSO 5: CRIAR S3 BUCKET**

### **5.1 Create Bucket**
1. **S3** → **Create bucket**
2. **Configurações:**
   ```
   Name: promata-prod-app-files
   Region: US East (Ohio) us-east-2

   Object Ownership: ACLs disabled
   Block all public access: ✓ (todos os checkboxes)
   Bucket Versioning: Enable
   Default encryption:
   - Server-side encryption: Amazon S3 managed keys (SSE-S3)
   ```

### **5.2 Configure CORS**
1. **Bucket** → **Permissions** → **Cross-origin resource sharing (CORS)**
2. **CORS Configuration:**
   ```json
   [
     {
       "AllowedHeaders": ["*"],
       "AllowedMethods": ["GET", "POST", "PUT", "DELETE", "HEAD"],
       "AllowedOrigins": ["*"],
       "MaxAgeSeconds": 3000
     }
   ]
   ```

---

## 📧 **PASSO 6: CONFIGURAR SES**

### **6.1 Verify Domain**
1. **SES** → **Identities** → **Create identity**
2. **Configurações:**
   ```
   Identity type: Domain
   Domain: promata.com.br
   ```
3. **Copiar DNS records** para configurar no Cloudflare

### **6.2 Verify Email Addresses**
1. **Create identity** (para cada email)
2. **Emails para verificar:**
   ```
   admin@promata.com.br
   noreply@promata.com.br
   support@promata.com.br
   ```

### **6.3 Create Configuration Set**
1. **SES** → **Configuration sets** → **Create set**
2. **Configurações:**
   ```
   Name: promata-prod-ses-config
   Reputation tracking: Enable
   Delivery options: Require TLS
   ```

---

## 🌐 **PASSO 7: CONFIGURAR CLOUDFLARE DNS**

### **7.1 Adicionar DNS Records SES**
```
Tipo    | Nome              | Conteúdo (do SES Console)
TXT     | _amazonses        | [verification token]
CNAME   | [dkim1]._domainkey| [dkim1 value]
CNAME   | [dkim2]._domainkey| [dkim2 value]
CNAME   | [dkim3]._domainkey| [dkim3 value]
```

### **7.2 Adicionar A Records (Produção)**
```
Tipo | Nome            | Conteúdo (EIP)    | Proxy
A    | @               | [Manager EIP]     | ✓
A    | www             | [Manager EIP]     | ✓
A    | api             | [Worker EIP]      | ✓
A    | traefik         | [Manager EIP]     | ✓
A    | grafana         | [Manager EIP]     | ✓
A    | prometheus      | [Manager EIP]     | ✓
A    | analytics       | [Worker EIP]      | ✓
A    | metabase        | [Worker EIP]      | ✓
A    | prisma          | [Manager EIP]     | ✓

Email Records:
MX   | @               | 10 inbound-smtp.us-east-2.amazonaws.com
TXT  | @               | v=spf1 include:amazonses.com ~all
```

---

## ✅ **PASSO 8: VERIFICAÇÃO**

### **8.1 Teste SSH**
```bash
ssh -i promata-prod-key.pem ubuntu@[Manager-EIP]
ssh -i promata-prod-key.pem ubuntu@[Worker-EIP]
```

### **8.2 Verificar Conectividade**
```bash
# No Manager
ping [Worker-EIP]
curl http://[Worker-EIP]

# No Worker
ping [Manager-EIP]
curl http://[Manager-EIP]
```

### **8.3 Testar DNS**
```bash
nslookup dev.promata.com.br
nslookup api.dev.promata.com.br
```

### **8.4 Verificar SES**
- **SES Console** → **Identities** → Status deve ser "Verified"
- Testar envio de email teste

---

## 🔧 **SCRIPTS DE INICIALIZAÇÃO**

### **Manager User Data Script:**
```bash
#!/bin/bash
# Atualizar sistema
apt-get update -y
apt-get upgrade -y

# Instalar Docker
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configurar como Swarm Manager
docker swarm init --advertise-addr $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Criar diretórios
mkdir -p /opt/promata/{config,data,logs}
chown -R ubuntu:ubuntu /opt/promata
```

### **Worker User Data Script:**
```bash
#!/bin/bash
# Atualizar sistema
apt-get update -y
apt-get upgrade -y

# Instalar Docker
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Criar diretórios
mkdir -p /opt/promata/{config,data,logs}
chown -R ubuntu:ubuntu /opt/promata

# Nota: Juntar ao swarm será feito manualmente após manager estar pronto
```

---

## 💰 **CUSTOS ESTIMADOS**

Após completar todos os passos, os custos mensais serão aproximadamente:

- **EC2 Instances (2x t3.medium):** ~$38/mês
- **Elastic IPs (2x):** ~$7.20/mês
- **EBS Storage (100GB):** ~$10/mês
- **S3 Storage:** ~$2/mês
- **SES:** ~$1/mês
- **Transfer:** ~$3/mês

**Total estimado: ~$61/mês**
