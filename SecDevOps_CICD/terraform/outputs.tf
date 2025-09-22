output "resource_group_name" {
  description = "Name of the main resource group"
  value       = module.networking.resource_group_name
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.networking.vnet_name
}

output "jenkins_subnet_id" {
  description = "ID of the Jenkins subnet"
  value       = module.networking.jenkins_subnet_id
}

output "containers_subnet_id" {
  description = "ID of the containers subnet"
  value       = module.networking.containers_subnet_id
}

output "jenkins_vm_public_ip" {
  description = "Public IP address of Jenkins VM"
  value       = module.jenkins_vm.public_ip_address
}

output "jenkins_vm_fqdn" {
  description = "FQDN of Jenkins VM"
  value       = module.jenkins_vm.public_ip_address
}

output "jenkins_ssh_connection" {
  description = "SSH connection string for Jenkins VM"
  value       = module.jenkins_vm.ssh_connection_string
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = module.jenkins_vm.jenkins_url
}

output "acr_login_server" {
  description = "Login server for Azure Container Registry"
  value       = module.acr.acr_login_server
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.acr.acr_name
}