# Outputs for Azure Development Environment

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.dev.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.dev.location
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.dev.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.dev.name
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = azurerm_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = azurerm_subnet.private.id
}

output "swarm_manager_public_ip" {
  description = "Public IP address of the Docker Swarm manager"
  value       = azurerm_public_ip.manager.ip_address
}

output "swarm_manager_private_ip" {
  description = "Private IP address of the Docker Swarm manager"
  value       = azurerm_network_interface.manager.private_ip_address
}

output "swarm_manager_vm_id" {
  description = "ID of the Docker Swarm manager VM"
  value       = azurerm_linux_virtual_machine.manager.id
}

output "swarm_worker_public_ips" {
  description = "Public IP addresses of the Docker Swarm workers"
  value       = var.instance_count > 1 ? azurerm_public_ip.worker[*].ip_address : []
}

output "swarm_worker_private_ips" {
  description = "Private IP addresses of the Docker Swarm workers"
  value       = var.instance_count > 1 ? azurerm_network_interface.worker[*].private_ip_address : []
}

output "swarm_worker_vm_ids" {
  description = "IDs of the Docker Swarm worker VMs"
  value       = var.instance_count > 1 ? azurerm_linux_virtual_machine.worker[*].id : []
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.dev.name
}

output "storage_account_primary_key" {
  description = "Primary key of the storage account"
  value       = azurerm_storage_account.dev.primary_access_key
  sensitive   = true
}

output "nsg_id" {
  description = "ID of the network security group"
  value       = azurerm_network_security_group.dev.id
}

# Outputs for Ansible inventory
output "ansible_inventory_manager" {
  description = "Ansible inventory entry for the manager node"
  value = {
    ansible_host = azurerm_public_ip.manager.ip_address
    ansible_user = "ubuntu"
    private_ip   = azurerm_network_interface.manager.private_ip_address
  }
}

# Connection information
output "ssh_connection_command" {
  description = "SSH command to connect to the manager node"
  value       = "ssh ubuntu@${azurerm_public_ip.manager.ip_address}"
}

# Infrastructure summary
output "infrastructure_summary" {
  description = "Summary of the deployed infrastructure"
  value = {
    environment           = var.environment
    resource_group        = azurerm_resource_group.dev.name
    location              = azurerm_resource_group.dev.location
    instance_count        = var.instance_count
    deployment_mode       = var.instance_count == 1 ? "compose" : "swarm"
    swarm_manager_public  = azurerm_public_ip.manager.ip_address
    swarm_manager_private = azurerm_network_interface.manager.private_ip_address
    swarm_workers_public  = var.instance_count > 1 ? azurerm_public_ip.worker[*].ip_address : []
    swarm_workers_private = var.instance_count > 1 ? azurerm_network_interface.worker[*].private_ip_address : []
    vm_size               = var.vm_size
    storage_account       = azurerm_storage_account.dev.name
    domain_name           = var.domain_name
  }
}

# SSH Key outputs for Ansible
output "ssh_private_key" {
  description = "Private SSH key for Ansible to connect to VMs"
  value       = tls_private_key.main_ssh.private_key_pem
  sensitive   = true
}

output "ssh_public_key" {
  description = "Public SSH key used for VMs"
  value       = tls_private_key.main_ssh.public_key_openssh
}

# Complete Ansible inventory as JSON
output "ansible_inventory" {
  description = "Complete Ansible inventory configuration"
  value = {
    all = {
      vars = {
        ansible_user            = "ubuntu"
        ansible_ssh_common_args = "-o StrictHostKeyChecking=no"
        env                     = var.environment
        domain_name             = var.domain_name
        instance_count          = var.instance_count
        deployment_mode         = var.instance_count == 1 ? "compose" : "swarm"
        manager_public_ip       = azurerm_public_ip.manager.ip_address
        manager_private_ip      = azurerm_network_interface.manager.private_ip_address
      }
      children = {
        "${var.project_name}_${var.environment}" = {
          children = merge(
            {
              managers = {
                hosts = {
                  swarm-manager = {
                    ansible_host = azurerm_public_ip.manager.ip_address
                    private_ip   = azurerm_network_interface.manager.private_ip_address
                    node_role    = "manager"
                  }
                }
              }
            },
            var.instance_count > 1 ? {
              workers = {
                hosts = {
                  for idx in range(var.instance_count - 1) :
                  "swarm-worker-${idx + 1}" => {
                    ansible_host = azurerm_public_ip.worker[idx].ip_address
                    private_ip   = azurerm_network_interface.worker[idx].private_ip_address
                    node_role    = "worker"
                  }
                }
              }
            } : {}
          )
        }
      }
    }
  }
}