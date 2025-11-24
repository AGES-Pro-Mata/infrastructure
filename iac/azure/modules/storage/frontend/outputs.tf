# Outputs for Azure Blob Storage Frontend Module

output "storage_account_id" {
  description = "ID da Storage Account"
  value       = azurerm_storage_account.frontend.id
}

output "storage_account_name" {
  description = "Nome da Storage Account"
  value       = azurerm_storage_account.frontend.name
}

output "primary_web_endpoint" {
  description = "Endpoint primário do website"
  value       = azurerm_storage_account.frontend.primary_web_endpoint
}

output "primary_web_host" {
  description = "Host primário do website"
  value       = azurerm_storage_account.frontend.primary_web_host
}

output "primary_blob_endpoint" {
  description = "Endpoint primário do blob"
  value       = azurerm_storage_account.frontend.primary_blob_endpoint
}

output "primary_access_key" {
  description = "Chave de acesso primária (sensível)"
  value       = azurerm_storage_account.frontend.primary_access_key
  sensitive   = true
}
