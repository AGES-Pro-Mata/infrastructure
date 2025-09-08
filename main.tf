# Define o provedor para o Azure
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# Configura o provedor do Azure
provider "azurerm" {
  features {}
}

# Cria o grupo de recursos para a aplicação
resource "azurerm_resource_group" "app_rg" {
  name     = var.resource_group_name
  location = var.location
}

# Cria a Service Principal (entidade de serviço)
resource "azuread_application" "app" {
  display_name = "${var.app_name}-sp"
}

# Cria a senha (secret) para a Service Principal
resource "azuread_service_principal_password" "sp_password" {
  service_principal_id = azuread_service_principal.sp.object_id
  end_date_relative    = "8760h" # Validade de 1 ano
}

# Atribui a permissão de "Contributor" para a Service Principal
# A permissão é aplicada apenas ao novo Resource Group da aplicação
resource "azurerm_role_assignment" "role_assignment" {
  scope                = azurerm_resource_group.app_rg.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.sp.object_id
}

# Cria a Service Principal (entidade de serviço)
# Este é o recurso que estava faltando!
resource "azuread_service_principal" "sp" {
  application_id = azuread_application.app.application_id
}

# No seu main.tf ou em um novo arquivo
resource "azurerm_storage_account" "app_storage" {
  name                     = "promataappdevstorage"
  resource_group_name      = azurerm_resource_group.app_rg.name
  location                 = azurerm_resource_group.app_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "pdf_container" {
  name                  = "pdfs"
  storage_account_name  = azurerm_storage_account.app_storage.name
  container_access_type = "private"
}