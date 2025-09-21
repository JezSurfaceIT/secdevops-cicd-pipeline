# Variables for SecDevOps Infrastructure

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  default     = "80265df9-bba2-4ad2-88af-e002fd2ca230"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-secdevops-cicd-dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "secdevops"
}

# Networking
variable "vnet_address_space" {
  description = "Virtual network address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_containers_prefix" {
  description = "Container subnet prefix"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_appgw_prefix" {
  description = "Application Gateway subnet prefix"
  type        = string
  default     = "10.0.2.0/24"
}

# Security
variable "allowed_ips" {
  description = "List of allowed IP addresses for WAF"
  type        = list(string)
  default     = ["86.3.129.121"]
}

variable "waf_mode" {
  description = "WAF operation mode"
  type        = string
  default     = "Prevention"
}

# Container Registry
variable "acr_sku" {
  description = "Azure Container Registry SKU"
  type        = string
  default     = "Premium"
}

# Application
variable "app_name" {
  description = "Application name"
  type        = string
  default     = "dummy-app-e2e-test"
}

variable "app_version" {
  description = "Application version"
  type        = string
  default     = "v1.1"
}

variable "container_cpu" {
  description = "Container CPU cores"
  type        = number
  default     = 1
}

variable "container_memory" {
  description = "Container memory in GB"
  type        = number
  default     = 1
}

# Jenkins
variable "jenkins_admin_password" {
  description = "Jenkins admin password"
  type        = string
  default     = "27eaee2a61aa4a5e97e04df34411b49f"
  sensitive   = true
}

# Monitoring
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

# Tags
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment    = "Dev"
    Pipeline       = "SecDevOps-E2E"
    Project        = "CICD"
    Owner          = "Jez"
    ManagedBy      = "Terraform"
    ExecutionGroup = "e2e-full"
  }
}