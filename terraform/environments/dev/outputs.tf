# Outputs for Azure Development Environment

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.dev.name
}

output "manager_public_ip" {
  description = "Public IP address of the Docker Swarm manager"
  value       = azurerm_public_ip.manager.ip_address
}

output "manager_private_ip" {
  description = "Private IP address of the Docker Swarm manager"
  value       = azurerm_network_interface.manager.private_ip_address
}

output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.dev.name
}

output "subnet_id" {
  description = "ID of the swarm subnet"
  value       = azurerm_subnet.swarm.id
}
