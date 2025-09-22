variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "secdevops"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "owner_email" {
  description = "Email of the resource owner"
  type        = string
  default     = "devops@example.com"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "jenkins_subnet_prefix" {
  description = "Address prefix for Jenkins subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "aks_subnet_prefix" {
  description = "Address prefix for AKS subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "jenkins_vm_size" {
  description = "Size of the Jenkins VM"
  type        = string
  default     = "Standard_B2ms"
}

variable "jenkins_admin_username" {
  description = "Admin username for Jenkins VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}

variable "acr_georeplications" {
  description = "List of Azure regions for ACR geo-replication"
  type = list(object({
    location                = string
    zone_redundancy_enabled = bool
  }))
  default = [
    {
      location                = "West US"
      zone_redundancy_enabled = false
    }
  ]
}

variable "acr_retention_days" {
  description = "Number of days to retain untagged manifests"
  type        = number
  default     = 7
}

variable "admin_ip" {
  description = "Admin IP address for SSH and Jenkins access (use 'any' for open access)"
  type        = string
  default     = "*"
}