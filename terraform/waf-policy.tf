# WAF Policy Configuration

resource "azurerm_web_application_firewall_policy" "main" {
  name                = "waf-policy-${var.project_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  policy_settings {
    enabled                     = true
    mode                       = var.waf_mode
    request_body_check         = true
    file_upload_limit_in_mb    = 100
    max_request_body_size_in_kb = 128
  }
  
  # Allow specific IPs
  dynamic "custom_rules" {
    for_each = var.allowed_ips
    content {
      name      = "AllowIP${index(var.allowed_ips, custom_rules.value) + 1}"
      priority  = index(var.allowed_ips, custom_rules.value) + 1
      rule_type = "MatchRule"
      action    = "Allow"
      
      match_conditions {
        match_variables {
          variable_name = "RemoteAddr"
        }
        operator     = "IPMatch"
        match_values = ["${custom_rules.value}/32"]
      }
    }
  }
  
  # Block all other IPs
  custom_rules {
    name      = "BlockAllOthers"
    priority  = 100
    rule_type = "MatchRule"
    action    = "Block"
    
    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }
      operator     = "IPMatch"
      match_values = ["0.0.0.0/1", "128.0.0.0/1"]
    }
  }
  
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
      
      rule_group_override {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        disabled_rules  = []
      }
      
      rule_group_override {
        rule_group_name = "REQUEST-930-APPLICATION-ATTACK-LFI"
        disabled_rules  = []
      }
      
      rule_group_override {
        rule_group_name = "REQUEST-931-APPLICATION-ATTACK-RFI"
        disabled_rules  = []
      }
      
      rule_group_override {
        rule_group_name = "REQUEST-932-APPLICATION-ATTACK-RCE"
        disabled_rules  = []
      }
      
      rule_group_override {
        rule_group_name = "REQUEST-933-APPLICATION-ATTACK-PHP"
        disabled_rules  = []
      }
      
      rule_group_override {
        rule_group_name = "REQUEST-941-APPLICATION-ATTACK-XSS"
        disabled_rules  = []
      }
      
      rule_group_override {
        rule_group_name = "REQUEST-942-APPLICATION-ATTACK-SQLI"
        disabled_rules  = []
      }
    }
  }
  
  tags = merge(
    var.common_tags,
    {
      Component  = "Security"
      PolicyType = "IP-Restriction"
      Stage      = "Security"
    }
  )
}