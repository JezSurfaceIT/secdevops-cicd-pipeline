# Resource Group Configuration

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  
  tags = merge(
    var.common_tags,
    {
      Component      = "ResourceGroup"
      SecurityLevel  = "WAF-Protected"
    }
  )
}