terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Variables
variable "resource_group_name" {
  default = "secdevops-rg"
}

variable "location" {
  default = "eastus"
}

variable "app_name" {
  default = "app-oversight-prod"
}

# Data source for existing resource group
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# App Service Plan (if not exists)
resource "azurerm_service_plan" "main" {
  name                = "asp-secdevops-prod"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  os_type            = "Linux"
  sku_name           = "P1v2"
}

# Blue Slot (Production)
resource "azurerm_linux_web_app" "blue" {
  name                = "${var.app_name}-blue"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    always_on = true
    
    application_stack {
      node_version = "18-lts"
    }
    
    health_check_path = "/health"
  }

  app_settings = {
    "DEPLOYMENT_SLOT" = "blue"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }

  tags = {
    Environment = "Production"
    Slot        = "Blue"
  }
}

# Green Slot (Staging)
resource "azurerm_linux_web_app_slot" "green" {
  name           = "green"
  app_service_id = azurerm_linux_web_app.blue.id

  site_config {
    always_on = true
    
    application_stack {
      node_version = "18-lts"
    }
    
    health_check_path = "/health"
  }

  app_settings = {
    "DEPLOYMENT_SLOT" = "green"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }

  tags = {
    Environment = "Staging"
    Slot        = "Green"
  }
}

# Application Gateway for traffic management
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-secdevops"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                = "Standard"
}

# Virtual Network for Application Gateway
resource "azurerm_virtual_network" "appgw" {
  name                = "vnet-appgw-secdevops"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = ["10.50.0.0/16"]
}

resource "azurerm_subnet" "appgw" {
  name                 = "subnet-appgw"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.appgw.name
  address_prefixes     = ["10.50.1.0/24"]
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = "appgw-secdevops"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # Backend pools
  backend_address_pool {
    name  = "blue-pool"
    fqdns = [azurerm_linux_web_app.blue.default_hostname]
  }

  backend_address_pool {
    name  = "green-pool"
    fqdns = ["${azurerm_linux_web_app.blue.name}-green.azurewebsites.net"]
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 30
    pick_host_name_from_backend_address = true
    
    probe_name = "health-probe"
  }

  # Health probe
  probe {
    name                = "health-probe"
    protocol            = "Https"
    path                = "/health"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    pick_host_name_from_backend_http_settings = true
  }

  # HTTP listener
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name            = "http-port"
    protocol                      = "Http"
  }

  # Request routing rule with weighted distribution
  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "blue-pool"
    backend_http_settings_name = "http-settings"
  }

  tags = {
    Environment = "Production"
    Purpose     = "Blue-Green-Deployment"
  }
}

# Outputs
output "blue_app_url" {
  value = "https://${azurerm_linux_web_app.blue.default_hostname}"
}

output "green_app_url" {
  value = "https://${azurerm_linux_web_app.blue.name}-green.azurewebsites.net"
}

output "appgw_public_ip" {
  value = azurerm_public_ip.appgw.ip_address
}

output "resource_group" {
  value = data.azurerm_resource_group.main.name
}