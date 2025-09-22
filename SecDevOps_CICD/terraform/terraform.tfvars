# SecDevOps CI/CD Infrastructure Configuration
# Deployment Environment: Development

resource_prefix = "secdevops"
location       = "East US"
environment    = "dev"
owner_email    = "devops@secdevops.io"

# Network Configuration
vnet_address_space    = ["10.0.0.0/16"]
jenkins_subnet_prefix = "10.0.1.0/24"
aks_subnet_prefix     = "10.0.2.0/24"

# Jenkins VM Configuration
jenkins_vm_size        = "Standard_B2ms"  # 2 vCPUs, 8 GB RAM
jenkins_admin_username = "azureuser"

# Azure Container Registry Configuration
acr_retention_days = 7

# Geo-replication disabled for development
acr_georeplications = []

# Note: SSH public key will be read from ~/.ssh/id_rsa.pub
# If you need to specify a different key, uncomment and set:
# ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."