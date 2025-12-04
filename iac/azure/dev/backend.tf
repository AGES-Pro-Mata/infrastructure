# Terraform Backend Configuration
# Azure Blob Storage backend em brazilsouth (São Paulo)
# Execute scripts/terraform/setup-backend-azure.sh primeiro para criar recursos
#
# Para usar backend remoto, descomente o bloco abaixo.
# Para desenvolvimento local, mantenha comentado (usa state local).

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-promata-terraform"
    storage_account_name = "promatatfstate"
    container_name       = "tfstate"
    key                  = "azure/dev/terraform.tfstate"

    # Azure usa blob lease para locking automaticamente
    # Não precisa de DynamoDB como AWS
  }
}

# ============================================================================
# IMPORTANTE: State Locking
# ============================================================================
# O Azure Blob Storage usa leases para locking automático.
# Se precisar forçar unlock (use com cuidado!):
#   terraform force-unlock <LOCK_ID>
#
# Ou via Azure CLI:
#   az storage blob lease break --blob-name "azure/dev/terraform.tfstate" \
#     --container-name "tfstate" --account-name "promatatfstate"
# ============================================================================