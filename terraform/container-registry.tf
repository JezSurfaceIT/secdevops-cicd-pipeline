# Azure Container Registry

resource "azurerm_container_registry" "main" {
  name                = "acr${var.project_name}${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = true
  
  retention_policy {
    enabled = true
    days    = 30
  }
  
  trust_policy {
    enabled = true
  }
  
  network_rule_set {
    default_action = "Deny"
    
    ip_rule {
      action   = "Allow"
      ip_range = "${var.allowed_ips[0]}/32"
    }
    
    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.containers.id
    }
  }
  
  tags = merge(
    var.common_tags,
    {
      Component     = "Registry"
      SecurityScan  = "Trivy"
      Stage         = "Build"
    }
  )
}

# ACR Webhook for CI/CD
resource "azurerm_container_registry_webhook" "cicd" {
  name                = "webhook-jenkins"
  registry_name       = azurerm_container_registry.main.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  service_uri = "http://localhost:8080/generic-webhook-trigger/invoke"
  status      = "enabled"
  scope       = "${var.app_name}:*"
  
  actions = [
    "push"
  ]
  
  custom_headers = {
    "X-Jenkins-Token" = "secdevops-webhook"
  }
}