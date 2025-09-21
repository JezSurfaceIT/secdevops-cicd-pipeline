# Networking Infrastructure

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-test"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
  
  tags = merge(
    var.common_tags,
    {
      Component     = "Network"
      SecurityLevel = "Private"
      Stage         = "Infrastructure"
    }
  )
}

# Container Subnet
resource "azurerm_subnet" "containers" {
  name                 = "subnet-containers"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_containers_prefix]
  
  delegation {
    name = "containerinstance"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
  
  service_endpoints = ["Microsoft.ContainerRegistry"]
}

# Application Gateway Subnet
resource "azurerm_subnet" "appgateway" {
  name                 = "subnet-appgateway"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_appgw_prefix]
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgateway" {
  name                = "pip-appgw-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = merge(
    var.common_tags,
    {
      Component  = "PublicIP"
      AttachedTo = "AppGateway"
      Stage      = "Production"
    }
  )
}

# Network Security Group for Container Subnet
resource "azurerm_network_security_group" "containers" {
  name                = "nsg-containers"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  security_rule {
    name                       = "AllowAppGateway"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3001"
    source_address_prefix      = var.subnet_appgw_prefix
    destination_address_prefix = var.subnet_containers_prefix
  }
  
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = merge(
    var.common_tags,
    {
      Component = "Security"
      Type      = "NSG"
    }
  )
}

resource "azurerm_subnet_network_security_group_association" "containers" {
  subnet_id                 = azurerm_subnet.containers.id
  network_security_group_id = azurerm_network_security_group.containers.id
}