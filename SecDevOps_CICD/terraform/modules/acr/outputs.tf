output "acr_id" {
  description = "ID of the container registry"
  value       = azurerm_container_registry.main.id
}

output "acr_name" {
  description = "Name of the container registry"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Login server URL for the container registry"
  value       = azurerm_container_registry.main.login_server
}

output "jenkins_sp_id" {
  description = "Application ID of the Jenkins service principal"
  value       = azuread_application.jenkins_acr.client_id
  sensitive   = true
}

output "jenkins_sp_password" {
  description = "Password for the Jenkins service principal"
  value       = azuread_service_principal_password.jenkins_acr.value
  sensitive   = true
}

output "jenkins_sp_object_id" {
  description = "Object ID of the Jenkins service principal"
  value       = azuread_service_principal.jenkins_acr.object_id
}