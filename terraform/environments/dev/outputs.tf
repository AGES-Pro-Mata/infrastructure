# Outputs for Pro-Mata Development Environment

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.dev.name
}

output "swarm_manager_public_ip" {
  description = "Public IP address of the Docker Swarm manager"
  value       = azurerm_public_ip.swarm_manager.ip_address
}

output "swarm_manager_private_ip" {
  description = "Private IP address of the Docker Swarm manager"
  value       = azurerm_network_interface.swarm_manager.private_ip_address
}

output "swarm_worker_private_ip" {
  description = "Private IP address of the Docker Swarm worker"
  value       = azurerm_network_interface.swarm_worker.private_ip_address
}

output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.dev.name
}

output "swarm_subnet_id" {
  description = "ID of the swarm subnet"
  value       = azurerm_subnet.swarm.id
}

output "database_subnet_id" {
  description = "ID of the database subnet"
  value       = azurerm_subnet.database.id
}

output "ssh_connection_command" {
  description = "SSH command to connect to swarm manager"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.swarm_manager.ip_address}"
}

output "ansible_inventory_data" {
  description = "Data for Ansible inventory"
  value = {
    manager = {
      host = azurerm_public_ip.swarm_manager.ip_address
      private_ip = azurerm_network_interface.swarm_manager.private_ip_address
    }
    worker = {
      host = azurerm_network_interface.swarm_worker.private_ip_address
      private_ip = azurerm_network_interface.swarm_worker.private_ip_address
    }
  }
  sensitive = true
}