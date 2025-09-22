# Sprint 1 Stories - Foundation Setup
**Sprint Duration:** 2 weeks  
**Sprint Goal:** Establish basic infrastructure and source control  
**Total Story Points:** 40

---

## STORY-001-01: Create Azure Resource Group and Networking

**Story ID:** STORY-001-01  
**Epic:** EPIC-001 (Infrastructure Foundation)  
**Points:** 5  
**Priority:** P0  
**Assignee:** DevOps Engineer  

### User Story
**As a** DevOps Engineer  
**I want to** provision the base Azure infrastructure using Terraform  
**So that** we have a reproducible and version-controlled foundation for all resources

### Acceptance Criteria
- [ ] Terraform modules created and tested
- [ ] Resource group provisioned with proper naming convention
- [ ] Virtual Network (10.0.0.0/16) configured
- [ ] Two subnets created:
  - Jenkins subnet: 10.0.1.0/24
  - Container subnet: 10.0.2.0/24
- [ ] Network Security Groups configured with rules:
  - Jenkins: Allow SSH (22), HTTPS (443), HTTP (8080) from specific IPs
  - Containers: Allow HTTPS (443) from internet
- [ ] Resource tagging strategy implemented:
  - Environment: dev/test/prod
  - Owner: team-name
  - CostCenter: project-code
  - ManagedBy: terraform
- [ ] Infrastructure code committed to Git repository

### Technical Implementation

```hcl
# terraform/main.tf
terraform {
  required_version = ">= 1.0"
  
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "saterraformstate"
    container_name      = "tfstate"
    key                 = "secdevops.tfstate"
  }
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

# terraform/modules/networking/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "uksouth"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}

# terraform/modules/networking/main.tf
resource "azurerm_resource_group" "main" {
  name     = "rg-secdevops-cicd-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-secdevops-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_subnet" "jenkins" {
  name                 = "snet-jenkins"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "containers" {
  name                 = "snet-containers"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  
  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.ContainerInstance/containerGroups"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

resource "azurerm_network_security_group" "jenkins" {
  name                = "nsg-jenkins"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "22"
    source_address_prefix     = var.admin_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "443"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Jenkins"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "8080"
    source_address_prefix     = var.admin_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "jenkins" {
  subnet_id                 = azurerm_subnet.jenkins.id
  network_security_group_id = azurerm_network_security_group.jenkins.id
}
```

### Testing Script
```bash
#!/bin/bash
# test-infrastructure.sh

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -var-file="environments/dev.tfvars" -out=plan.out

# Apply with approval
terraform apply plan.out

# Verify resources
az network vnet show --resource-group rg-secdevops-cicd-dev --name vnet-secdevops-dev
az network nsg show --resource-group rg-secdevops-cicd-dev --name nsg-jenkins
```

### Definition of Done
- [ ] Terraform code reviewed and approved
- [ ] Resources successfully provisioned in Azure
- [ ] Network connectivity tested
- [ ] Security rules validated
- [ ] Documentation updated in wiki
- [ ] Code merged to main branch

---

## STORY-001-02: Provision Azure VM for Jenkins

**Story ID:** STORY-001-02  
**Epic:** EPIC-001 (Infrastructure Foundation)  
**Points:** 8  
**Priority:** P0  
**Assignee:** DevOps Engineer  

### User Story
**As a** DevOps Engineer  
**I want to** provision an Azure VM for Jenkins Master  
**So that** we have a dedicated CI/CD orchestration server

### Acceptance Criteria
- [ ] VM provisioned with Standard_D4s_v3 size
- [ ] Ubuntu 22.04 LTS installed
- [ ] SSH access configured with key authentication only
- [ ] Public IP with DNS label configured
- [ ] Managed disk (128GB) with backup policy
- [ ] Auto-shutdown at 8 PM daily (cost saving)
- [ ] Azure Monitor agent installed
- [ ] Boot diagnostics enabled

### Technical Implementation

```hcl
# terraform/modules/jenkins-vm/main.tf
resource "azurerm_public_ip" "jenkins" {
  name                = "pip-jenkins-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                = "Standard"
  domain_name_label  = "jenkins-secdevops-${var.environment}"
  tags               = var.tags
}

resource "azurerm_network_interface" "jenkins" {
  name                = "nic-jenkins-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags               = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id         = azurerm_public_ip.jenkins.id
  }
}

resource "azurerm_linux_virtual_machine" "jenkins" {
  name                = "vm-jenkins-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size               = "Standard_D4s_v3"
  tags               = var.tags

  disable_password_authentication = true
  
  admin_username = "azureuser"
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key_path)
  }

  network_interface_ids = [
    azurerm_network_interface.jenkins.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb        = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_virtual_machine_extension" "monitor_agent" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.jenkins.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "jenkins" {
  virtual_machine_id = azurerm_linux_virtual_machine.jenkins.id
  location          = var.location
  enabled           = true

  daily_recurrence_time = "2000"
  timezone             = "GMT Standard Time"

  notification_settings {
    enabled = false
  }
}

resource "azurerm_backup_protected_vm" "jenkins" {
  resource_group_name = var.backup_resource_group_name
  recovery_vault_name = var.recovery_vault_name
  source_vm_id       = azurerm_linux_virtual_machine.jenkins.id
  backup_policy_id   = var.backup_policy_id
}
```

### Post-Deployment Configuration Script
```bash
#!/bin/bash
# configure-jenkins-vm.sh

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
  curl \
  git \
  wget \
  software-properties-common \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Configure firewall
sudo ufw allow 22/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp
sudo ufw --force enable

# Create Jenkins user
sudo useradd -m -s /bin/bash jenkins
sudo usermod -aG docker jenkins

# Setup data disk
sudo mkdir -p /var/jenkins_home
# Mount instructions depend on actual disk configuration

echo "VM configuration complete. Ready for Jenkins installation."
```

### Definition of Done
- [ ] VM successfully provisioned and accessible via SSH
- [ ] All extensions installed and configured
- [ ] Backup policy verified
- [ ] Auto-shutdown tested
- [ ] Monitoring data visible in Azure Portal
- [ ] Documentation updated

---

## STORY-001-03: Configure Azure Container Registry

**Story ID:** STORY-001-03  
**Epic:** EPIC-001 (Infrastructure Foundation)  
**Points:** 5  
**Priority:** P0  
**Assignee:** DevOps Engineer  

### User Story
**As a** DevOps Engineer  
**I want to** set up Azure Container Registry  
**So that** we can store and manage Docker images securely

### Acceptance Criteria
- [ ] ACR provisioned with Premium SKU
- [ ] Vulnerability scanning enabled
- [ ] Geo-replication to secondary region
- [ ] Content trust (image signing) enabled
- [ ] Retention policy: 30 days for untagged, keep 10 latest versions
- [ ] Service principal created with push/pull permissions
- [ ] Jenkins credentials configured

### Technical Implementation

```hcl
# terraform/modules/acr/main.tf
resource "azurerm_container_registry" "main" {
  name                = "acrsecdevops${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                = "Premium"
  admin_enabled      = false
  tags               = var.tags

  georeplications {
    location                = "northeurope"
    zone_redundancy_enabled = true
    tags                   = var.tags
  }
  
  retention_policy {
    days    = 30
    enabled = true
  }
  
  trust_policy {
    enabled = true
  }
  
  network_rule_set {
    default_action = "Allow"
    
    ip_rule {
      action   = "Allow"
      ip_range = var.jenkins_public_ip
    }
  }
}

resource "azurerm_container_registry_task" "cleanup" {
  name                  = "cleanup-task"
  container_registry_id = azurerm_container_registry.main.id
  
  platform {
    os           = "Linux"
    architecture = "amd64"
  }
  
  acr_build_task {
    base_image_trigger {
      name                = "defaultBaseimageTriggerName"
      type                = "Runtime"
      status              = "Enabled"
      update_trigger_type = "All"
    }
  }
  
  timer_trigger {
    name     = "daily-cleanup"
    schedule = "0 2 * * *"
  }
  
  encoded_step {
    task_content = base64encode(<<EOF
version: v1.1.0
steps:
  - cmd: acr purge --filter 'oversight-app:.*' --untagged --ago 30d
    disableWorkingDirectoryOverride: true
    timeout: 3600
EOF
    )
  }
}

# Service Principal for Jenkins
resource "azuread_application" "jenkins_acr" {
  display_name = "sp-jenkins-acr-${var.environment}"
}

resource "azuread_service_principal" "jenkins_acr" {
  application_id = azuread_application.jenkins_acr.application_id
}

resource "azuread_service_principal_password" "jenkins_acr" {
  service_principal_id = azuread_service_principal.jenkins_acr.object_id
  end_date            = "2025-12-31T00:00:00Z"
}

resource "azurerm_role_assignment" "jenkins_acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.jenkins_acr.object_id
}

resource "azurerm_role_assignment" "jenkins_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azuread_service_principal.jenkins_acr.object_id
}

# Output credentials for Jenkins configuration
output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "jenkins_sp_id" {
  value     = azuread_application.jenkins_acr.application_id
  sensitive = true
}

output "jenkins_sp_password" {
  value     = azuread_service_principal_password.jenkins_acr.value
  sensitive = true
}
```

### Validation Script
```bash
#!/bin/bash
# validate-acr.sh

# Login to ACR using service principal
az login --service-principal \
  -u $JENKINS_SP_ID \
  -p $JENKINS_SP_PASSWORD \
  --tenant $TENANT_ID

az acr login --name acrsecdevopsdev

# Test push
docker pull nginx:alpine
docker tag nginx:alpine acrsecdevopsdev.azurecr.io/test:v1
docker push acrsecdevopsdev.azurecr.io/test:v1

# Verify vulnerability scanning
az acr repository show-tags \
  --name acrsecdevopsdev \
  --repository test \
  --detail

# Check replication status
az acr replication list --registry-name acrsecdevopsdev

echo "ACR validation complete"
```

### Definition of Done
- [ ] ACR successfully provisioned
- [ ] Vulnerability scanning verified
- [ ] Geo-replication active
- [ ] Service principal tested
- [ ] Jenkins can push/pull images
- [ ] Retention policy verified

---

## STORY-002-01: Configure GitHub Repository Structure

**Story ID:** STORY-002-01  
**Epic:** EPIC-002 (Source Control & Version Management)  
**Points:** 5  
**Priority:** P0  
**Assignee:** Lead Developer  

### User Story
**As a** Development Team  
**I want to** set up the GitHub repository with proper structure and configuration  
**So that** we have organized and protected code management

### Acceptance Criteria
- [ ] Repository created with comprehensive .gitignore
- [ ] Branch protection rules configured for main and develop
- [ ] CODEOWNERS file with proper mappings
- [ ] PR and issue templates created
- [ ] Repository settings optimized (merge strategies, etc.)
- [ ] Jenkins webhook configured and tested

### Implementation Files

```yaml
# .github/CODEOWNERS
# Global owners
* @tech-lead @senior-dev

# Infrastructure
/terraform/ @devops-team
/scripts/ @devops-team
/.github/workflows/ @devops-team

# Security
/security/ @security-team
Jenkinsfile* @security-team @devops-team

# Application
/src/ @dev-team
/tests/ @qa-team @dev-team

# Documentation
/docs/ @tech-writer @tech-lead
*.md @tech-writer
```

```markdown
# .github/pull_request_template.md
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change
- [ ] Security fix
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Security scans pass

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Security impact assessed

## Screenshots (if applicable)

## Related Issues
Fixes #(issue)
```

```markdown
# .github/ISSUE_TEMPLATE/bug_report.md
---
name: Bug Report
about: Create a report to help us improve
title: '[BUG] '
labels: 'bug'
assignees: ''
---

**Describe the bug**
Clear and concise description

**To Reproduce**
Steps to reproduce:
1. Go to '...'
2. Click on '....'
3. See error

**Expected behavior**
What you expected to happen

**Screenshots**
If applicable

**Environment:**
- OS: [e.g. Ubuntu 22.04]
- Browser [if applicable]
- Version [e.g. 1.0.0]

**Additional context**
Any other context
```

```markdown
# .github/ISSUE_TEMPLATE/security_issue.md
---
name: Security Issue
about: Report a security vulnerability
title: '[SECURITY] '
labels: 'security, priority:high'
assignees: 'security-team'
---

⚠️ **DO NOT** include sensitive information or actual exploit code

**Vulnerability Type**
- [ ] Injection
- [ ] Authentication/Authorization
- [ ] Data Exposure
- [ ] Configuration
- [ ] Other

**Description**
Brief description without sensitive details

**Impact**
Potential impact if exploited

**Suggested Fix**
If you have suggestions

**Affected Components**
List affected files/services

**Severity Assessment**
- [ ] Critical
- [ ] High
- [ ] Medium
- [ ] Low
```

### GitHub CLI Configuration Script
```bash
#!/bin/bash
# configure-github-repo.sh

REPO="organization/oversight-mvp"

# Configure branch protection for main
gh api -X PUT repos/$REPO/branches/main/protection \
  --field required_status_checks='{"strict":true,"contexts":["continuous-integration/jenkins"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":2,"dismiss_stale_reviews":true,"require_code_owner_reviews":true}' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false

# Configure branch protection for develop
gh api -X PUT repos/$REPO/branches/develop/protection \
  --field required_status_checks='{"strict":true,"contexts":["continuous-integration/jenkins"]}' \
  --field enforce_admins=false \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field restrictions=null

# Create webhook for Jenkins
gh api repos/$REPO/hooks \
  --field name=web \
  --field active=true \
  --field events='["push","pull_request","release"]' \
  --field config='{"url":"https://jenkins-secdevops-dev.uksouth.cloudapp.azure.com/github-webhook/","content_type":"json","secret":"'$WEBHOOK_SECRET'"}'

# Configure repo settings
gh api -X PATCH repos/$REPO \
  --field has_issues=true \
  --field has_projects=true \
  --field has_wiki=true \
  --field allow_squash_merge=true \
  --field allow_merge_commit=false \
  --field allow_rebase_merge=true \
  --field delete_branch_on_merge=true \
  --field allow_auto_merge=true

echo "GitHub repository configured successfully"
```

### Definition of Done
- [ ] Repository structure created and verified
- [ ] Branch protection rules active
- [ ] CODEOWNERS file working
- [ ] Templates visible in GitHub UI
- [ ] Webhook delivering events to Jenkins
- [ ] Team has appropriate access

---

## Sprint 1 Checklist

### Pre-Sprint
- [ ] Azure subscription access confirmed
- [ ] GitHub organization access granted
- [ ] Team member roles assigned
- [ ] SSH keys generated for VM access
- [ ] Terraform state storage created

### During Sprint
- [ ] Daily standups scheduled
- [ ] Blockers identified and escalated
- [ ] Documentation updated continuously
- [ ] Security reviews for each story
- [ ] Code reviews completed

### Sprint Completion
- [ ] All stories meet Definition of Done
- [ ] Infrastructure accessible and functional
- [ ] Source control properly configured
- [ ] Jenkins VM ready for software installation
- [ ] ACR operational and tested
- [ ] Sprint demo prepared
- [ ] Retrospective conducted
- [ ] Sprint 2 planning completed

### Handover to Sprint 2
- [ ] Infrastructure credentials in Key Vault
- [ ] Terraform state secured
- [ ] Documentation complete
- [ ] Known issues documented
- [ ] Technical debt logged

---

**Sprint 1 Ready for Planning Session**  
**Next:** Sprint 2 - Jenkins Setup and Basic Pipeline