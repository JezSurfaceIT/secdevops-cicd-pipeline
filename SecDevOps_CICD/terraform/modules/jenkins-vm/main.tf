resource "azurerm_storage_account" "diagnostics" {
  name                     = "sadiag${lower(replace(var.environment, "-", ""))}jenkins"
  resource_group_name      = var.resource_group_name
  location                = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                    = var.tags
}

resource "azurerm_public_ip" "jenkins" {
  name                = "pip-jenkins-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                = "Standard"
  domain_name_label  = "jenkins-secdevops-${var.environment}"
  tags               = var.tags
}

resource "azurerm_network_interface" "jenkins" {
  name                = "nic-jenkins-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags               = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id         = azurerm_public_ip.jenkins.id
  }
}

resource "azurerm_linux_virtual_machine" "jenkins" {
  name                = "vm-jenkins-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size               = "Standard_D4s_v3"
  tags               = var.tags

  disable_password_authentication = true
  
  admin_username = "azureuser"
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key_path)
  }

  network_interface_ids = [
    azurerm_network_interface.jenkins.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb        = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_virtual_machine_extension" "monitor_agent" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.jenkins.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "jenkins" {
  virtual_machine_id = azurerm_linux_virtual_machine.jenkins.id
  location          = var.location
  enabled           = true

  daily_recurrence_time = "2000"
  timezone             = "GMT Standard Time"

  notification_settings {
    enabled = false
  }
}

resource "azurerm_backup_protected_vm" "jenkins" {
  count               = var.backup_policy_id != "" ? 1 : 0
  resource_group_name = var.backup_resource_group_name != "" ? var.backup_resource_group_name : var.resource_group_name
  recovery_vault_name = var.recovery_vault_name
  source_vm_id       = azurerm_linux_virtual_machine.jenkins.id
  backup_policy_id   = var.backup_policy_id
}