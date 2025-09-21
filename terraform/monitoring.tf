# Monitoring Infrastructure (Log Analytics & Application Insights)

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = merge(
    var.common_tags,
    {
      Component = "Monitoring"
      Type      = "LogAnalytics"
    }
  )
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  
  tags = merge(
    var.common_tags,
    {
      Component = "Monitoring"
      Type      = "AppInsights"
    }
  )
}

# Container Instance Monitoring
resource "azurerm_monitor_diagnostic_setting" "container_app" {
  name               = "diag-container-app"
  target_resource_id = azurerm_container_group.app.id
  
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  metric {
    category = "AllMetrics"
    enabled  = true
  }
  
  enabled_log {
    category = "ContainerInstanceLog"
  }
}

# Application Gateway Monitoring
resource "azurerm_monitor_diagnostic_setting" "appgateway" {
  name               = "diag-appgateway"
  target_resource_id = azurerm_application_gateway.main.id
  
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  metric {
    category = "AllMetrics"
    enabled  = true
  }
  
  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }
  
  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }
  
  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }
}

# Alerts
resource "azurerm_monitor_metric_alert" "container_cpu" {
  name                = "alert-container-cpu-high"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_container_group.app.id]
  description         = "Alert when CPU usage is too high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  
  criteria {
    metric_namespace = "Microsoft.ContainerInstance/containerGroups"
    metric_name      = "CpuUsage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  
  tags = var.common_tags
}

resource "azurerm_monitor_metric_alert" "appgateway_unhealthy" {
  name                = "alert-appgateway-unhealthy-hosts"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_gateway.main.id]
  description         = "Alert when backend hosts are unhealthy"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  
  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }
  
  tags = var.common_tags
}