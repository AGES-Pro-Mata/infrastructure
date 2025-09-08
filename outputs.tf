output "AZURE_TENANT_ID" {
  description = "O ID do seu Azure AD Tenant."
  value       = data.azurerm_client_config.current.tenant_id
}

output "AZURE_CLIENT_ID" {
  description = "O ID do cliente (appId) da Service Principal."
  value       = azuread_application.app.application_id
}

output "AZURE_CLIENT_SECRET" {
  description = "A senha da Service Principal."
  value       = azuread_service_principal_password.sp_password.value
  sensitive   = true # Marca a saída como sensível para não ser exibida no console
}

output "AZURE_STORAGE_CONTAINER_URL" {
  description = "A URL do contêiner de armazenamento de PDFs."
  value       = azurerm_storage_container.pdf_container.resource_manager_id
}

# Obtém as informações de configuração do cliente atual do Azure
# Este é o recurso que estava faltando!
data "azurerm_client_config" "current" {}