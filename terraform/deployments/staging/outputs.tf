# Outputs for Staging Environment

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.staging.name
}

output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.staging.name
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = azurerm_subnet.staging.id
}