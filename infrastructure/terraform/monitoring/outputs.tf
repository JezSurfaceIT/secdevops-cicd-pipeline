# Outputs for Prometheus Monitoring Infrastructure

output "prometheus_namespace" {
  description = "The namespace where Prometheus is deployed"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_service_name" {
  description = "The name of the Prometheus service"
  value       = kubernetes_service.prometheus.metadata[0].name
}

output "prometheus_internal_url" {
  description = "Internal URL for Prometheus"
  value       = "http://${kubernetes_service.prometheus.metadata[0].name}.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9090"
}

output "prometheus_federation_url" {
  description = "Federation endpoint for Prometheus"
  value       = "http://${kubernetes_service.prometheus.metadata[0].name}.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9090/federate"
}

output "thanos_remote_write_url" {
  description = "Remote write URL for Thanos"
  value       = "http://thanos-receiver.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:19291/api/v1/receive"
}

output "oauth2_proxy_service" {
  description = "OAuth2 proxy service for external access"
  value       = "oauth2-proxy.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local"
}

output "storage_account_name" {
  description = "Azure Storage Account name for Thanos metrics"
  value       = azurerm_storage_account.thanos.name
}

output "prometheus_replicas" {
  description = "Number of Prometheus replicas deployed"
  value       = var.prometheus_replicas
}

output "resource_group_annotation" {
  description = "Resource group annotation following e2e naming convention"
  value       = kubernetes_stateful_set.prometheus.metadata[0].annotations["azure-resource-group"]
}