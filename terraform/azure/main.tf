# Azure Infrastructure for Development Environment
# Pro-Mata Infrastructure - Development

terraform {
  required_version = ">= 1.8.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "dev" {
  name     = "rg-promata-dev"
  location = var.azure_region
  
  tags = {
    Environment = "development"
    Project     = "pro-mata"
    ManagedBy   = "terraform"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "dev" {
  name                = "vnet-promata-dev"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  tags = azurerm_resource_group.dev.tags
}

# Subnet for Docker Swarm
resource "azurerm_subnet" "swarm" {
  name                 = "subnet-swarm"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "dev" {
  name                = "nsg-promata-dev"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  tags = azurerm_resource_group.dev.tags
}

# Virtual Machine for Docker Swarm Manager
resource "azurerm_linux_virtual_machine" "swarm_manager" {
  name                = "vm-promata-dev-manager"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  size                = var.vm_size
  admin_username      = var.admin_username
  
  disable_password_authentication = true
  
  network_interface_ids = [
    azurerm_network_interface.manager.id,
  ]
  
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  tags = azurerm_resource_group.dev.tags
}

# Network Interface for Manager
resource "azurerm_network_interface" "manager" {
  name                = "nic-manager"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swarm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.manager.id
  }
  
  tags = azurerm_resource_group.dev.tags
}

# Public IP for Manager
resource "azurerm_public_ip" "manager" {
  name                = "pip-manager"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = azurerm_resource_group.dev.tags
}
