# Container Instances Configuration

# Private Container Instance
resource "azurerm_container_group" "app" {
  name                = "${var.app_name}-private"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  restart_policy      = "Always"
  ip_address_type     = "Private"
  subnet_ids          = [azurerm_subnet.containers.id]
  
  container {
    name   = "${var.app_name}-container"
    image  = "${azurerm_container_registry.main.login_server}/${var.app_name}:${var.app_version}"
    cpu    = var.container_cpu
    memory = var.container_memory
    
    ports {
      port     = 3001
      protocol = "TCP"
    }
    
    environment_variables = {
      NODE_ENV = "test"
      VERSION  = var.app_version
    }
  }
  
  image_registry_credential {
    server   = azurerm_container_registry.main.login_server
    username = azurerm_container_registry.main.admin_username
    password = azurerm_container_registry.main.admin_password
  }
  
  tags = merge(
    var.common_tags,
    {
      Component          = "Application"
      DeploymentStrategy = "Blue-Green"
      Version            = var.app_version
      Stage              = "Test"
    }
  )
}

# Blue Environment Container
resource "azurerm_container_group" "blue" {
  name                = "${var.app_name}-blue"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  restart_policy      = "Always"
  ip_address_type     = "Public"
  dns_name_label      = "${var.app_name}-blue"
  
  container {
    name   = "${var.app_name}-blue"
    image  = "${azurerm_container_registry.main.login_server}/${var.app_name}:${var.app_version}"
    cpu    = var.container_cpu
    memory = var.container_memory
    
    ports {
      port     = 3001
      protocol = "TCP"
    }
    
    environment_variables = {
      NODE_ENV   = "production"
      VERSION    = var.app_version
      DEPLOYMENT = "blue"
    }
  }
  
  image_registry_credential {
    server   = azurerm_container_registry.main.login_server
    username = azurerm_container_registry.main.admin_username
    password = azurerm_container_registry.main.admin_password
  }
  
  tags = merge(
    var.common_tags,
    {
      Component          = "Application"
      DeploymentStrategy = "Blue-Green"
      Environment        = "Blue"
      Version            = var.app_version
      Stage              = "Production"
    }
  )
}

# Green Environment Container (placeholder, deployed during blue-green switch)
resource "azurerm_container_group" "green" {
  count               = 0  # Initially not deployed
  name                = "${var.app_name}-green"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  restart_policy      = "Always"
  ip_address_type     = "Public"
  dns_name_label      = "${var.app_name}-green"
  
  container {
    name   = "${var.app_name}-green"
    image  = "${azurerm_container_registry.main.login_server}/${var.app_name}:${var.app_version}"
    cpu    = var.container_cpu
    memory = var.container_memory
    
    ports {
      port     = 3001
      protocol = "TCP"
    }
    
    environment_variables = {
      NODE_ENV   = "production"
      VERSION    = var.app_version
      DEPLOYMENT = "green"
    }
  }
  
  image_registry_credential {
    server   = azurerm_container_registry.main.login_server
    username = azurerm_container_registry.main.admin_username
    password = azurerm_container_registry.main.admin_password
  }
  
  tags = merge(
    var.common_tags,
    {
      Component          = "Application"
      DeploymentStrategy = "Blue-Green"
      Environment        = "Green"
      Version            = var.app_version
      Stage              = "Staging"
    }
  )
}