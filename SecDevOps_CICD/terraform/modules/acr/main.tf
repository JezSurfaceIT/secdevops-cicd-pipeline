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
      ip_range = "${var.jenkins_public_ip}/32"
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
  client_id = azuread_application.jenkins_acr.client_id
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