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