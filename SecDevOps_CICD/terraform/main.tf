terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
  
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}

# Generate random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Local variables
locals {
  resource_prefix = var.resource_prefix
  location        = var.location
  environment     = var.environment
  
  common_tags = {
    Environment = var.environment
    Project     = "SecDevOps-CICD"
    ManagedBy   = "Terraform"
    CreatedDate = timestamp()
    Owner       = var.owner_email
  }
}

# Networking Module
module "networking" {
  source = "./modules/networking"
  
  environment = var.environment
  location    = local.location
  tags        = local.common_tags
  admin_ip    = var.admin_ip
}

# Jenkins VM Module
module "jenkins_vm" {
  source = "./modules/jenkins-vm"
  
  depends_on = [module.networking]
  
  environment         = var.environment
  location           = local.location
  resource_group_name = module.networking.resource_group_name
  subnet_id          = module.networking.jenkins_subnet_id
  tags               = local.common_tags
  ssh_public_key_path = "~/.ssh/id_rsa.pub"
}

# Azure Container Registry Module
module "acr" {
  source = "./modules/acr"
  
  depends_on = [module.jenkins_vm]
  
  environment         = var.environment
  location           = local.location
  resource_group_name = module.networking.resource_group_name
  tags               = local.common_tags
  jenkins_public_ip  = module.jenkins_vm.public_ip_address
}