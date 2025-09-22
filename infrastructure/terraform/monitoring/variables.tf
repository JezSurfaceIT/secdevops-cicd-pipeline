# Variables for Prometheus Monitoring Infrastructure

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "Azure region short code (eus, wus, neu)"
  type        = string
  default     = "eus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "e2e-dev-eus-secops-app-001"
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "e2e-dev-eus-secops-aks-001"
}

variable "prometheus_replicas" {
  description = "Number of Prometheus replicas for HA"
  type        = number
  default     = 2
  
  validation {
    condition     = var.prometheus_replicas >= 2
    error_message = "Prometheus requires at least 2 replicas for HA."
  }
}

variable "prometheus_version" {
  description = "Prometheus container image version"
  type        = string
  default     = "v2.45.0"
}

variable "thanos_version" {
  description = "Thanos container image version"
  type        = string
  default     = "v0.32.0"
}

variable "oauth2_proxy_version" {
  description = "OAuth2 Proxy container image version"
  type        = string
  default     = "v7.4.0"
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID for service discovery"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  sensitive   = true
}

variable "azure_client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
}

variable "azure_storage_account" {
  description = "Azure Storage Account name for Thanos"
  type        = string
  default     = "e2edevthanos"
}

variable "azure_storage_key" {
  description = "Azure Storage Account key for Thanos"
  type        = string
  sensitive   = true
}

variable "prometheus_tls_cert" {
  description = "TLS certificate for Prometheus"
  type        = string
  sensitive   = true
}

variable "prometheus_tls_key" {
  description = "TLS private key for Prometheus"
  type        = string
  sensitive   = true
}

variable "oauth_client_id" {
  description = "OAuth2 Client ID for authentication"
  type        = string
  sensitive   = true
}

variable "oauth_client_secret" {
  description = "OAuth2 Client Secret for authentication"
  type        = string
  sensitive   = true
}

variable "cookie_secret" {
  description = "Cookie secret for OAuth2 proxy"
  type        = string
  sensitive   = true
}

variable "email_domain" {
  description = "Email domain for OAuth2 authentication"
  type        = string
  default     = "oversight.com"
}

# Grafana Variables
variable "grafana_replicas" {
  description = "Number of Grafana replicas for HA"
  type        = number
  default     = 3
  
  validation {
    condition     = var.grafana_replicas >= 3
    error_message = "Grafana requires at least 3 replicas for HA."
  }
}

variable "grafana_version" {
  description = "Grafana container image version"
  type        = string
  default     = "10.2.0"
}

variable "grafana_domain" {
  description = "Domain name for Grafana"
  type        = string
  default     = "monitoring.oversight.com"
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_db_host" {
  description = "PostgreSQL host for Grafana"
  type        = string
  default     = "e2e-dev-eus-grafana-psql"
}

variable "grafana_db_password" {
  description = "PostgreSQL password for Grafana"
  type        = string
  sensitive   = true
}

variable "grafana_db_reader_password" {
  description = "PostgreSQL reader password for dashboards"
  type        = string
  sensitive   = true
}

variable "grafana_plugins" {
  description = "Grafana plugins to install"
  type        = string
  default     = "grafana-azure-monitor-datasource,grafana-piechart-panel,grafana-worldmap-panel"
}