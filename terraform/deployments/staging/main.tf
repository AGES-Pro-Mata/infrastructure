# Azure Infrastructure for Staging Environment
# Pro-Mata Infrastructure - Staging

# Resource Group
resource "azurerm_resource_group" "staging" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "staging" {
  name                = "vnet-promata-staging"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Subnet
resource "azurerm_subnet" "staging" {
  name                 = "subnet-promata-staging"
  resource_group_name  = azurerm_resource_group.staging.name
  virtual_network_name = azurerm_virtual_network.staging.name
  address_prefixes     = ["10.1.1.0/24"]
}