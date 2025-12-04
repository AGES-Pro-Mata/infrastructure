#!/bin/bash
# ============================================================================
# Setup Terraform Backend for Azure
# Cria Storage Account e Container para Terraform state
# Region: brazilsouth (São Paulo)
# ============================================================================

set -e

# Configurações
RESOURCE_GROUP="rg-promata-terraform"
STORAGE_ACCOUNT="promatatfstate${RANDOM:0:4}"  # Nome único
CONTAINER_NAME="tfstate"
LOCATION="brazilsouth"

echo "🚀 Configurando Terraform Backend no Azure em ${LOCATION}..."

# Verificar se Azure CLI está instalado
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI não encontrado. Instale: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Verificar login
echo "✅ Verificando autenticação Azure..."
az account show &> /dev/null || {
    echo "❌ Não autenticado. Execute: az login"
    exit 1
}

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "📋 Subscription: ${SUBSCRIPTION_ID}"

# Criar Resource Group
echo "📦 Criando Resource Group: ${RESOURCE_GROUP}..."
az group create \
    --name ${RESOURCE_GROUP} \
    --location ${LOCATION} \
    --tags Project=promata ManagedBy=terraform Purpose=terraform-state \
    --output none 2>/dev/null || echo "ℹ️  Resource Group já existe"

# Verificar se já existe uma storage account
EXISTING_SA=$(az storage account list \
    --resource-group ${RESOURCE_GROUP} \
    --query "[?starts_with(name, 'promatatfstate')].name" \
    -o tsv 2>/dev/null | head -1)

if [ -n "$EXISTING_SA" ]; then
    STORAGE_ACCOUNT=$EXISTING_SA
    echo "ℹ️  Usando Storage Account existente: ${STORAGE_ACCOUNT}"
else
    # Criar Storage Account
    echo "💾 Criando Storage Account: ${STORAGE_ACCOUNT}..."
    az storage account create \
        --name ${STORAGE_ACCOUNT} \
        --resource-group ${RESOURCE_GROUP} \
        --location ${LOCATION} \
        --sku Standard_LRS \
        --kind StorageV2 \
        --https-only true \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access false \
        --tags Project=promata ManagedBy=terraform Purpose=terraform-state \
        --output none
    echo "✅ Storage Account criado"
fi

# Obter chave da storage account
echo "🔑 Obtendo chave de acesso..."
ACCOUNT_KEY=$(az storage account keys list \
    --resource-group ${RESOURCE_GROUP} \
    --account-name ${STORAGE_ACCOUNT} \
    --query '[0].value' -o tsv)

# Criar Container
echo "📁 Criando container: ${CONTAINER_NAME}..."
az storage container create \
    --name ${CONTAINER_NAME} \
    --account-name ${STORAGE_ACCOUNT} \
    --account-key ${ACCOUNT_KEY} \
    --output none 2>/dev/null || echo "ℹ️  Container já existe"

# Habilitar versionamento de blobs
echo "📝 Habilitando versionamento de blobs..."
az storage account blob-service-properties update \
    --account-name ${STORAGE_ACCOUNT} \
    --resource-group ${RESOURCE_GROUP} \
    --enable-versioning true \
    --output none

# Habilitar soft delete
echo "🔄 Habilitando soft delete (7 dias)..."
az storage account blob-service-properties update \
    --account-name ${STORAGE_ACCOUNT} \
    --resource-group ${RESOURCE_GROUP} \
    --enable-delete-retention true \
    --delete-retention-days 7 \
    --output none

echo ""
echo "✅ Terraform Backend Azure configurado com sucesso!"
echo ""
echo "📋 Informações:"
echo "   Resource Group:  ${RESOURCE_GROUP}"
echo "   Storage Account: ${STORAGE_ACCOUNT}"
echo "   Container:       ${CONTAINER_NAME}"
echo "   Location:        ${LOCATION}"
echo ""
echo "🔧 Configuração do backend (adicione ao backend.tf):"
echo ""
cat << EOF
terraform {
  backend "azurerm" {
    resource_group_name  = "${RESOURCE_GROUP}"
    storage_account_name = "${STORAGE_ACCOUNT}"
    container_name       = "${CONTAINER_NAME}"
    key                  = "dev/terraform.tfstate"
  }
}
EOF
echo ""
echo "🔧 Ou use partial configuration:"
echo "   terraform init -backend-config=backends/dev-backend.hcl"
echo ""
echo "📁 Criando arquivo de configuração parcial..."

# Criar arquivo HCL
cat > "$(dirname "$0")/../../iac/azure/backends/dev-backend.hcl" << EOF
resource_group_name  = "${RESOURCE_GROUP}"
storage_account_name = "${STORAGE_ACCOUNT}"
container_name       = "${CONTAINER_NAME}"
key                  = "dev/terraform.tfstate"
EOF

echo "✅ Arquivo criado: iac/azure/backends/dev-backend.hcl"
