output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "jenkins_subnet_id" {
  description = "ID of the Jenkins subnet"
  value       = azurerm_subnet.jenkins.id
}

output "containers_subnet_id" {
  description = "ID of the containers subnet"
  value       = azurerm_subnet.containers.id
}

output "jenkins_nsg_id" {
  description = "ID of the Jenkins NSG"
  value       = azurerm_network_security_group.jenkins.id
}