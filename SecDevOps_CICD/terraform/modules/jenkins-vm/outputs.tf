output "vm_id" {
  description = "ID of the Jenkins VM"
  value       = azurerm_linux_virtual_machine.jenkins.id
}

output "vm_name" {
  description = "Name of the Jenkins VM"
  value       = azurerm_linux_virtual_machine.jenkins.name
}

output "public_ip_address" {
  description = "Public IP address of the Jenkins VM"
  value       = azurerm_public_ip.jenkins.ip_address
}

output "public_ip_fqdn" {
  description = "Fully qualified domain name of the Jenkins VM"
  value       = azurerm_public_ip.jenkins.fqdn
}

output "private_ip_address" {
  description = "Private IP address of the Jenkins VM"
  value       = azurerm_network_interface.jenkins.private_ip_address
}

output "ssh_connection_string" {
  description = "SSH connection string for the Jenkins VM"
  value       = "ssh azureuser@${azurerm_public_ip.jenkins.fqdn}"
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${azurerm_public_ip.jenkins.fqdn}:8080"
}

output "managed_identity_principal_id" {
  description = "Principal ID of the VM's managed identity"
  value       = azurerm_linux_virtual_machine.jenkins.identity[0].principal_id
}