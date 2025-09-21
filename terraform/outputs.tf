# Terraform Outputs

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "Resource group ID"
  value       = azurerm_resource_group.main.id
}

output "container_registry_login_server" {
  description = "ACR login server"
  value       = azurerm_container_registry.main.login_server
}

output "container_registry_admin_username" {
  description = "ACR admin username"
  value       = azurerm_container_registry.main.admin_username
  sensitive   = true
}

output "container_registry_admin_password" {
  description = "ACR admin password"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

output "application_gateway_public_ip" {
  description = "Application Gateway public IP address"
  value       = azurerm_public_ip.appgateway.ip_address
}

output "application_gateway_fqdn" {
  description = "Application Gateway FQDN"
  value       = azurerm_public_ip.appgateway.fqdn
}

output "container_private_ip" {
  description = "Private container IP address"
  value       = azurerm_container_group.app.ip_address
}

output "blue_container_fqdn" {
  description = "Blue environment container FQDN"
  value       = azurerm_container_group.blue.fqdn
}

output "vnet_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.main.id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = azurerm_log_analytics_workspace.main.id
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_app_id" {
  description = "Application Insights app ID"
  value       = azurerm_application_insights.main.app_id
}

output "waf_policy_id" {
  description = "WAF policy ID"
  value       = azurerm_web_application_firewall_policy.main.id
}

output "allowed_ips" {
  description = "List of IPs allowed through WAF"
  value       = var.allowed_ips
}

output "application_url" {
  description = "Application URL through Application Gateway"
  value       = "http://${azurerm_public_ip.appgateway.ip_address}"
}

output "jenkins_url" {
  description = "Jenkins CI/CD server URL"
  value       = "http://localhost:8080"
}

output "grafana_url" {
  description = "Grafana monitoring URL"
  value       = "http://localhost:3000"
}

output "prometheus_url" {
  description = "Prometheus metrics URL"
  value       = "http://localhost:9091"
}

output "sonarqube_url" {
  description = "SonarQube code quality URL"
  value       = "http://localhost:9000"
}