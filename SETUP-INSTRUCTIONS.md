# 🏗️ Configuração da Infraestrutura Pro-Mata para Sua Organização

Este documento contém instruções detalhadas para adaptar esta infraestrutura para sua organização específica.

## 📋 Pré-requisitos

### 1. Ferramentas Necessárias
```bash
# Terraform (versão 1.8+)
wget https://releases.hashicorp.com/terraform/1.8.0/terraform_1.8.0_linux_amd64.zip
unzip terraform_1.8.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Ansible
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Make
sudo apt install -y make
```

### 2. Contas e Serviços
- ✅ **Azure Subscription** ativa
- ✅ **DockerHub Account** (para suas imagens)
- ✅ **Cloudflare Account** (gratuito - opcional para DNS)
- ✅ **Domínio registrado** (registro.br ou outro)

## 🔧 Configuração Inicial

### Passo 1: Azure Service Principal

Crie um Service Principal para o Terraform/GitHub Actions:

```bash
# Login no Azure
az login

# Obter sua Subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"

# Criar Service Principal
az ad sp create-for-rbac --name "pro-mata-terraform-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/$SUBSCRIPTION_ID" \
  --query="{clientId:appId,clientSecret:password,subscriptionId:id,tenantId:tenant}" \
  -o json
```

**💾 Salve a saída JSON** - você precisará dela nos secrets do GitHub.

### Passo 2: Configurar Secrets no GitHub

No seu repositório GitHub, vá em **Settings > Secrets and variables > Actions** e adicione:

| Secret Name | Valor | Descrição |
|-------------|--------|-----------|
| `AZURE_CREDENTIALS` | JSON do Service Principal | Credenciais completas do Azure |
| `AZURE_SUBSCRIPTION_ID` | Sua Subscription ID | ID da subscription Azure |
| `ANSIBLE_VAULT_PASSWORD` | Uma senha forte | Para criptografar secrets (opcional) |

**Exemplo do AZURE_CREDENTIALS:**
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", 
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### Passo 3: Adaptar Configurações para Sua Organização

#### 3.1. Atualizar Imagens Docker

Em `envs/dev/terraform.tfvars`:
```hcl
# Substituir YOUR_DOCKERHUB_ORG pela sua organização
backend_image = "SUA_ORG/pro-mata-backend-dev:latest"
frontend_image = "SUA_ORG/pro-mata-frontend-dev:latest"
migration_image = "SUA_ORG/pro-mata-migration-dev:latest"
```

#### 3.2. Configurar Subscription ID

Em `envs/dev/terraform.tfvars`:
```hcl
# Substituir pelo seu Subscription ID
azure_subscription_id = "sua-subscription-id-aqui"
```

#### 3.3. Configurar Domínio (Opcional)

Se você tem um domínio:
```hcl
domain_name = "seudominio.com.br"
# Configurações Cloudflare (se usar)
cloudflare_api_token = "seu-token-aqui"
cloudflare_zone_id = "seu-zone-id-aqui"
```

#### 3.4. Atualizar Nome do Projeto

Em `envs/dev/terraform.tfvars`:
```hcl
project_name = "seu-projeto"
azure_resource_group = "seu-projeto-dev-rg"
```

## 🚀 Deploy

### Deploy Local
```bash
# Teste local (requer Azure CLI logado)
make deploy ENV=dev
```

### Deploy via GitHub Actions

O deploy acontece automaticamente quando você:
1. Fizer push para `main` ou `dev`
2. Executar workflow manual em **Actions > Deploy Development Environment**

## 🌐 Configuração de DNS com Cloudflare (Opcional)

### Por que usar Cloudflare?
- ✅ **Gratuito** para uso básico
- ✅ **SSL automático**
- ✅ **CDN global**
- ✅ **Proteção DDoS**
- ✅ **Cache inteligente**

### Configuração:

1. **Criar conta no Cloudflare** (gratuito)

2. **Adicionar seu domínio ao Cloudflare**
   - Vai receber 2 nameservers (ex: `alex.ns.cloudflare.com`, `kate.ns.cloudflare.com`)

3. **Alterar nameservers no registro.br**
   - Entrar no painel do registro.br
   - Alterar DNS para os nameservers do Cloudflare
   - Aguardar propagação (até 24h)

4. **Obter credenciais do Cloudflare**
   ```bash
   # API Token (recomendado)
   # No painel Cloudflare: My Profile > API Tokens > Create Token
   # Template: Custom Token
   # Permissions: Zone:Read, DNS:Edit
   # Zone Resources: Include - Specific Zone - seu domínio
   ```

5. **Adicionar ao terraform.tfvars**
   ```hcl
   cloudflare_api_token = "seu-token-aqui"
   cloudflare_zone_id = "zone-id-do-seu-dominio"
   enable_cloudflare_dns = true
   ```

## 📊 Monitoramento e Verificação

### Após o Deploy

Verifique se tudo funcionou:

```bash
# Status da infraestrutura
make status ENV=dev

# Health check
make health ENV=dev

# Verificar outputs do Terraform
cd terraform/deployments/dev
terraform output
```

### URLs de Acesso (exemplo)

Após o deploy bem-sucedido:
- **Frontend**: https://seudominio.com.br
- **API**: https://api.seudominio.com.br  
- **Traefik Dashboard**: https://traefik.seudominio.com.br
- **Grafana**: https://grafana.seudominio.com.br

## 🔒 Segurança

### Configurações de Segurança Implementadas

- ✅ **SSH apenas com chaves** (senhas desabilitadas)
- ✅ **Firewall UFW** configurado
- ✅ **Fail2ban** para proteção SSH
- ✅ **SSL/TLS** automático via Cloudflare
- ✅ **Rede isolada** para aplicações
- ✅ **Logs centralizados**

### Recomendações Adicionais

1. **Backup regular** dos dados
2. **Monitoramento** ativo (Grafana/Prometheus incluído)
3. **Atualizações** regulares do sistema
4. **Revisão** periódica de acessos

## 🛠️ Solução de Problemas

### Problemas Comuns

#### 1. "Storage account name already exists"
```bash
# Editar envs/dev/terraform.tfvars
storage_account_name = "meuprojetodevstg$(date +%s | tail -c 6)"
```

#### 2. "Subscription not authorized"
```bash
# Verificar se Service Principal tem permissões corretas
az role assignment list --assignee <client-id> --subscription <subscription-id>
```

#### 3. "Docker images not found"
```bash
# Verificar se as imagens existem no DockerHub
docker pull SUA_ORG/pro-mata-backend-dev:latest
```

#### 4. Pipeline falha
```bash
# Verificar logs detalhados em GitHub Actions
# Verificar se todos os secrets estão configurados
```

### Comandos Úteis

```bash
# Limpar recursos (CUIDADO!)
make destroy-dev

# Validar configuração
make validate ENV=dev

# Logs detalhados
make deploy ENV=dev VERBOSE=true

# Backup do estado
make backup ENV=dev
```

## 📞 Suporte

### Documentação Adicional

- [Documentação do Terraform Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Documentação do Ansible](https://docs.ansible.com/)
- [Cloudflare Docs](https://developers.cloudflare.com/)

### Estrutura do Projeto

```
infrastructure/
├── envs/
│   └── dev/
│       ├── terraform.tfvars          # Variáveis específicas do ambiente
│       └── ansible-vars.yml          # Variáveis do Ansible
├── terraform/
│   ├── deployments/
│   │   └── dev/                      # Configuração Terraform por ambiente
│   └── modules/                      # Módulos reutilizáveis
├── ansible/                          # Playbooks e configurações
├── scripts/                          # Scripts de deploy e utilitários
└── .github/workflows/                # Automação CI/CD
```

---

## ✅ Checklist Final

Antes do primeiro deploy, certifique-se de que:

- [ ] Service Principal criado e configurado
- [ ] Secrets do GitHub configurados
- [ ] Imagens Docker atualizadas para sua organização
- [ ] Subscription ID configurada
- [ ] Domínio configurado (se aplicável)
- [ ] Cloudflare configurado (se aplicável)
- [ ] Nomes do projeto atualizados

**🎉 Pronto! Sua infraestrutura está configurada para sua organização.**

Execute `make deploy ENV=dev` ou use o GitHub Actions para fazer o primeiro deploy!