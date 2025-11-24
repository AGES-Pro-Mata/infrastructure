# Azure Infrastructure for Development Environment
# Pro-Mata Infrastructure - Development
# Region: brazilsouth (Brasil Sul - São Paulo)

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.46"
    }
  }

  # Backend configuration disabled for initial validation
  # Run backend-setup.sh to create backend.tf file
  # backend "azurerm" {
  #   # Backend configuration will be loaded from backend-setup.sh
  #   # resource_group_name  = "rg-promata-tfstate"
  #   # storage_account_name = "promatatfstate"
  #   # container_name       = "tfstate"
  #   # key                  = "dev.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    virtual_machine {
      delete_os_disk_on_deletion = true
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  # Use Service Principal authentication with environment variables:
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
  # These are automatically used by the provider when available
  use_cli = true # Enable Azure CLI authentication for local development
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Data sources
data "azurerm_client_config" "current" {}

# Generate SSH key pair for VMs
resource "tls_private_key" "main_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Resource Group
resource "azurerm_resource_group" "dev" {
  name     = var.resource_group_name
  location = var.location

  tags = var.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "dev" {
  name                = "vnet-${var.project_name}-${var.environment}"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name

  tags = var.common_tags
}

# Subnets
resource "azurerm_subnet" "public" {
  name                 = "subnet-${var.project_name}-${var.environment}-public"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "private" {
  name                 = "subnet-${var.project_name}-${var.environment}-private"
  resource_group_name  = azurerm_resource_group.dev.name
  virtual_network_name = azurerm_virtual_network.dev.name
  address_prefixes     = ["10.1.2.0/24"]
}

# Public IP for Swarm Manager - STATIC RESERVATION
resource "azurerm_public_ip" "manager" {
  name                = "pip-${var.project_name}-${var.environment}-manager"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  allocation_method   = "Static"
  sku                 = "Standard"

  # Reserve current IP address to prevent changes on redeploy
  ip_version = "IPv4"

  tags = merge(var.common_tags, {
    "IP-Type"     = "Static-Reserved"
    "Purpose"     = "Swarm-Manager"
    "DNS-Records" = "All-Services"
  })
}

# Public IP for Swarm Worker - STATIC RESERVATION (only when instance_count > 1)
resource "azurerm_public_ip" "worker" {
  count = var.instance_count > 1 ? var.instance_count - 1 : 0

  name                = "pip-${var.project_name}-${var.environment}-worker-${count.index + 1}"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  allocation_method   = "Static"
  sku                 = "Standard"

  # Reserve current IP address to prevent changes on redeploy
  ip_version = "IPv4"

  tags = merge(var.common_tags, {
    "IP-Type"     = "Static-Reserved"
    "Purpose"     = "Swarm-Worker-${count.index + 1}"
    "DNS-Records" = "All-Services"
  })
}

# Network Security Group
resource "azurerm_network_security_group" "dev" {
  name                = "nsg-${var.project_name}-${var.environment}"
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
  name                = "nic-${var.project_name}-${var.environment}-manager"
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

# Network Interface for Swarm Worker (only when instance_count > 1)
resource "azurerm_network_interface" "worker" {
  count = var.instance_count > 1 ? var.instance_count - 1 : 0

  name                = "nic-${var.project_name}-${var.environment}-worker-${count.index + 1}"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.worker[count.index].id
  }

  tags = var.common_tags
}

# Associate Network Security Group to Network Interface
resource "azurerm_network_interface_security_group_association" "manager" {
  network_interface_id      = azurerm_network_interface.manager.id
  network_security_group_id = azurerm_network_security_group.dev.id
}

resource "azurerm_network_interface_security_group_association" "worker" {
  count = var.instance_count > 1 ? var.instance_count - 1 : 0

  network_interface_id      = azurerm_network_interface.worker[count.index].id
  network_security_group_id = azurerm_network_security_group.dev.id
}

# Virtual Machine for Swarm Manager
resource "azurerm_linux_virtual_machine" "manager" {
  name                = "vm-${var.project_name}-${var.environment}-manager"
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
    public_key = tls_private_key.main_ssh.public_key_openssh
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

  # Explicit dependencies for proper destroy order
  depends_on = [
    azurerm_network_interface_security_group_association.manager,
    azurerm_public_ip.manager
  ]
}

# Virtual Machine for Swarm Worker (only when instance_count > 1)
resource "azurerm_linux_virtual_machine" "worker" {
  count = var.instance_count > 1 ? var.instance_count - 1 : 0

  name                = "vm-${var.project_name}-${var.environment}-worker-${count.index + 1}"
  resource_group_name = azurerm_resource_group.dev.name
  location            = azurerm_resource_group.dev.location
  size                = var.vm_size
  admin_username      = "ubuntu"

  # Disable password authentication
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.worker[count.index].id,
  ]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = tls_private_key.main_ssh.public_key_openssh
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

  # Explicit dependencies for proper destroy order
  depends_on = [
    azurerm_network_interface_security_group_association.worker,
    azurerm_public_ip.worker
  ]
}

# Storage Account for backups and state
resource "azurerm_storage_account" "dev" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.dev.name
  location                 = azurerm_resource_group.dev.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.common_tags

  # Prevent accidental deletion of storage account
  lifecycle {
    prevent_destroy = false # Set to true in production
  }
}

# Container for backups
resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_name  = azurerm_storage_account.dev.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.dev]
}

# Container for terraform state backups
resource "azurerm_storage_container" "terraform_backups" {
  name                  = "terraform-state-backups"
  storage_account_name  = azurerm_storage_account.dev.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.dev]
}

# Cloudflare DNS Module
module "cloudflare_dns" {
  count  = var.enable_cloudflare_dns ? 1 : 0
  source = "../../modules/shared/dns/cloudflare"

  zone_id     = var.cloudflare_zone_id
  domain_name = var.domain_name

  # Frontend endpoint (if using Azure Blob Storage)
  # frontend_endpoint = module.frontend_storage[0].primary_web_host
  frontend_endpoint = "" # Configurar quando frontend storage estiver provisionado

  # Backend IP
  backend_ip = azurerm_public_ip.manager.ip_address

  # Opcional: Traefik dashboard
  create_traefik_record = true

  # SSL Configuration
  ssl_mode = "flexible" # flexible para Let's Encrypt via Traefik

  # Explicit dependency to ensure proper destroy order
  depends_on = [
    azurerm_public_ip.manager,
    azurerm_linux_virtual_machine.manager
  ]
}