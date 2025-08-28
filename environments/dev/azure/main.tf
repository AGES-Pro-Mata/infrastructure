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
  
  backend "azurerm" {
    # Configuration will be provided via backend-setup.sh
  }
}

provider "azurerm" {
  features {}
}

# Data sources
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "dev" {
  name     = var.resource_group_name
  location = var.location
  
  tags = var.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "dev" {
  name                = "vnet-promata-dev"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  tags = var.common_tags
}

# Subnets
resource "azurerm_subnet" "public" {
  name                 = "subnet-promata-dev-public"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "private" {
  name                 = "subnet-promata-dev-private"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.1.2.0/24"]
}

# Public IP for Swarm Manager
resource "azurerm_public_ip" "manager" {
  name                = "pip-promata-dev-manager"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = var.common_tags
}

# Network Security Group
resource "azurerm_network_security_group" "dev" {
  name                = "nsg-promata-dev"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  # SSH access
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # HTTP
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # HTTPS
  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Docker Swarm Manager Port
  security_rule {
    name                       = "DockerSwarmManager"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2377"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }
  
  # Docker Swarm Worker Communication
  security_rule {
    name                       = "DockerSwarmWorker"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7946"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }
  
  # Docker Swarm Overlay Network
  security_rule {
    name                       = "DockerSwarmOverlay"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "4789"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }
  
  tags = var.common_tags
}

# Network Interface for Swarm Manager
resource "azurerm_network_interface" "manager" {
  name                = "nic-promata-dev-manager"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.manager.id
  }
  
  tags = var.common_tags
}

# Associate Network Security Group to Network Interface
resource "azurerm_network_interface_security_group_association" "manager" {
  network_interface_id      = azurerm_network_interface.manager.id
  network_security_group_id = azurerm_network_security_group.dev.id
}

# Virtual Machine for Swarm Manager
resource "azurerm_linux_virtual_machine" "manager" {
  name                = "vm-promata-dev-manager"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  size                = var.vm_size
  admin_username      = "ubuntu"
  
  # Disable password authentication
  disable_password_authentication = true
  
  network_interface_ids = [
    azurerm_network_interface.manager.id,
  ]
  
  admin_ssh_key {
    username   = "ubuntu"
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
  
  # Cloud-init script for Docker setup
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yml", {
    docker_compose_version = var.docker_compose_version
  }))
  
  tags = var.common_tags
}

# Storage Account for backups and state
resource "azurerm_storage_account" "dev" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.dev.name
  location                 = azurerm_resource_group.dev.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  tags = var.common_tags
}

# Container for backups
resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_id    = azurerm_storage_account.dev.id
  container_access_type = "private"
}