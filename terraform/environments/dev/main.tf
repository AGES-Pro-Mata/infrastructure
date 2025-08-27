# Pro-Mata Development Infrastructure - Azure
terraform {
  required_version = ">= 1.8.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  
  # Backend configuration will be added by backend-setup.sh
  # Do not specify backend here - it will be configured via backend.tf
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "dev" {
  name     = var.resource_group_name
  location = var.azure_location
  
  tags = {
    Environment = "development"
    Project     = "pro-mata"
    ManagedBy   = "terraform"
    CostCenter  = "ages-pucrs"
  }
}

# Virtual Network - depends on Resource Group
resource "azurerm_virtual_network" "dev" {
  name                = "vnet-promata-dev"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  tags = azurerm_resource_group.dev.tags
  
  depends_on = [azurerm_resource_group.dev]
}

# Subnets - depend on Virtual Network
resource "azurerm_subnet" "swarm" {
  name                 = "subnet-swarm"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.1.1.0/24"]
  
  depends_on = [azurerm_virtual_network.dev]
}

resource "azurerm_subnet" "database" {
  name                 = "subnet-database"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.1.2.0/24"]
  
  depends_on = [azurerm_virtual_network.dev]
}

# Network Security Group - depends on Resource Group
resource "azurerm_network_security_group" "dev" {
  name                = "nsg-promata-dev"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  # HTTP
  security_rule {
    name                       = "HTTP"
    priority                   = 1001
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
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # SSH
  security_rule {
    name                       = "SSH"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Traefik Dashboard
  security_rule {
    name                       = "TraefikDashboard"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Docker Swarm TCP
  security_rule {
    name                       = "DockerSwarm"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["2377", "7946"]
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "10.1.0.0/16"
  }
  
  # Docker Swarm UDP
  security_rule {
    name                       = "DockerSwarmUDP"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = ["7946", "4789"]
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "10.1.0.0/16"
  }
  
  tags = azurerm_resource_group.dev.tags
  
  depends_on = [azurerm_resource_group.dev]
}

# Public IP - depends on Resource Group
resource "azurerm_public_ip" "swarm_manager" {
  name                = "pip-promata-swarm-manager"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = azurerm_resource_group.dev.tags
  
  depends_on = [azurerm_resource_group.dev]
}

# Network Interfaces - depend on Subnet and Public IP
resource "azurerm_network_interface" "swarm_manager" {
  name                = "nic-promata-swarm-manager"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swarm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.swarm_manager.id
  }
  
  tags = azurerm_resource_group.dev.tags
  
  depends_on = [
    azurerm_subnet.swarm,
    azurerm_public_ip.swarm_manager
  ]
}

resource "azurerm_network_interface" "swarm_worker" {
  name                = "nic-promata-swarm-worker"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swarm.id
    private_ip_address_allocation = "Dynamic"
  }
  
  tags = azurerm_resource_group.dev.tags
  
  depends_on = [azurerm_subnet.swarm]
}

# NSG Associations - depend on NSG and Network Interfaces  
resource "azurerm_network_interface_security_group_association" "manager" {
  network_interface_id      = azurerm_network_interface.swarm_manager.id
  network_security_group_id = azurerm_network_security_group.dev.id
  
  depends_on = [
    azurerm_network_interface.swarm_manager,
    azurerm_network_security_group.dev
  ]
}

resource "azurerm_network_interface_security_group_association" "worker" {
  network_interface_id      = azurerm_network_interface.swarm_worker.id
  network_security_group_id = azurerm_network_security_group.dev.id
  
  depends_on = [
    azurerm_network_interface.swarm_worker,
    azurerm_network_security_group.dev
  ]
}

# Virtual Machines - depend on Network Interfaces and NSG Associations
resource "azurerm_linux_virtual_machine" "swarm_manager" {
  name                = "vm-promata-swarm-manager"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  size                = var.vm_size
  admin_username      = var.admin_username
  
  disable_password_authentication = true
  
  network_interface_ids = [
    azurerm_network_interface.swarm_manager.id,
  ]
  
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  custom_data = base64encode(file("${path.module}/cloud-init-manager.yml"))
  
  tags = merge(azurerm_resource_group.dev.tags, {
    Role = "swarm-manager"
    NodeType = "manager"
  })
  
  depends_on = [
    azurerm_network_interface.swarm_manager,
    azurerm_network_interface_security_group_association.manager
  ]
}

resource "azurerm_linux_virtual_machine" "swarm_worker" {
  name                = "vm-promata-swarm-worker"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  size                = var.vm_size
  admin_username      = var.admin_username
  
  disable_password_authentication = true
  
  network_interface_ids = [
    azurerm_network_interface.swarm_worker.id,
  ]
  
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  custom_data = base64encode(file("${path.module}/cloud-init-worker.yml"))
  
  tags = merge(azurerm_resource_group.dev.tags, {
    Role = "swarm-worker"
    NodeType = "worker"
  })
  
  depends_on = [
    azurerm_network_interface.swarm_worker,
    azurerm_network_interface_security_group_association.worker
  ]
}