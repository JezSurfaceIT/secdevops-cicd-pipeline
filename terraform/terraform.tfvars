# Terraform Variables Configuration
# Resource group: rg-secdevops-cicd-dev

subscription_id     = "80265df9-bba2-4ad2-88af-e002fd2ca230"
resource_group_name = "rg-secdevops-cicd-dev"
location           = "eastus"
environment        = "dev"
project_name       = "secdevops"

# Networking
vnet_address_space       = ["10.0.0.0/16"]
subnet_containers_prefix = "10.0.1.0/24"
subnet_appgw_prefix     = "10.0.2.0/24"

# Security - IP Whitelist
allowed_ips = [
  "86.3.129.121"  # Jez's IP
]
waf_mode = "Prevention"

# Container Registry
acr_sku = "Premium"

# Application
app_name       = "dummy-app-e2e-test"
app_version    = "v1.1"
container_cpu  = 1
container_memory = 1

# Monitoring
grafana_admin_password = "admin123"

# Tags for all resources
common_tags = {
  Environment    = "Dev"
  Pipeline       = "SecDevOps-E2E"
  Project        = "CICD"
  Owner          = "Jez"
  ManagedBy      = "Terraform"
  ExecutionGroup = "e2e-full"
  ResourceGroup  = "rg-secdevops-cicd-dev"
}