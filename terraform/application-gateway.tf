# Application Gateway Configuration

locals {
  backend_address_pool_name      = "appGatewayBackendPool"
  frontend_port_name             = "appGatewayFrontendPort"
  frontend_ip_configuration_name = "appGatewayFrontendIP"
  http_setting_name              = "appGatewayBackendHttpSettings"
  listener_name                  = "appGatewayHttpListener"
  request_routing_rule_name      = "rule1"
  gateway_ip_configuration_name  = "appGatewayIPConfig"
}

resource "azurerm_application_gateway" "main" {
  name                = "appgw-${var.project_name}-test"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }
  
  gateway_ip_configuration {
    name      = local.gateway_ip_configuration_name
    subnet_id = azurerm_subnet.appgateway.id
  }
  
  frontend_port {
    name = local.frontend_port_name
    port = 80
  }
  
  frontend_port {
    name = "${local.frontend_port_name}-https"
    port = 443
  }
  
  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgateway.id
  }
  
  backend_address_pool {
    name         = local.backend_address_pool_name
    ip_addresses = [azurerm_container_group.app.ip_address]
  }
  
  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 3001
    protocol              = "Http"
    request_timeout       = 30
    
    probe_name = "health-probe"
  }
  
  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }
  
  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 1
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
  
  probe {
    name                = "health-probe"
    protocol            = "Http"
    path                = "/health"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }
  
  firewall_policy_id = azurerm_web_application_firewall_policy.main.id
  
  tags = merge(
    var.common_tags,
    {
      Component     = "Gateway"
      SecurityLevel = "WAF-v2"
      AllowedIP     = join(",", var.allowed_ips)
      Stage         = "Production"
    }
  )
  
  depends_on = [
    azurerm_container_group.app,
    azurerm_web_application_firewall_policy.main
  ]
}