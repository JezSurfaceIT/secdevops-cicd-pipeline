import pytest
import os
from pathlib import Path

class TestJenkinsVM:
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.terraform_dir = Path(__file__).parent.parent.parent / "terraform"
        self.module_dir = self.terraform_dir / "modules" / "jenkins-vm"
        
    def test_module_structure_exists(self):
        """Test that jenkins-vm module structure exists"""
        assert self.module_dir.exists(), "jenkins-vm module directory should exist"
        
        main_tf = self.module_dir / "main.tf"
        variables_tf = self.module_dir / "variables.tf"
        outputs_tf = self.module_dir / "outputs.tf"
        
        assert main_tf.exists(), "main.tf should exist in jenkins-vm module"
        assert variables_tf.exists(), "variables.tf should exist in jenkins-vm module"
        assert outputs_tf.exists(), "outputs.tf should exist in jenkins-vm module"
    
    def test_public_ip_configuration(self):
        """Test public IP is configured correctly"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azurerm_public_ip" "jenkins"' in content
            assert 'allocation_method   = "Static"' in content
            assert 'sku                = "Standard"' in content
            assert 'domain_name_label' in content
            assert 'pip-jenkins-${var.environment}' in content
    
    def test_network_interface_configuration(self):
        """Test network interface is properly configured"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azurerm_network_interface" "jenkins"' in content
            assert 'nic-jenkins-${var.environment}' in content
            assert 'ip_configuration' in content
            assert 'public_ip_address_id' in content
            assert 'subnet_id' in content
    
    def test_vm_configuration(self):
        """Test VM resource configuration"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azurerm_linux_virtual_machine" "jenkins"' in content
            assert 'vm-jenkins-${var.environment}' in content
            assert 'size               = "Standard_D4s_v3"' in content
            assert 'disable_password_authentication = true' in content
            assert 'admin_username = "azureuser"' in content
    
    def test_vm_os_disk(self):
        """Test VM OS disk configuration"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'os_disk' in content
            assert 'storage_account_type = "Premium_LRS"' in content
            assert 'disk_size_gb        = 128' in content
            assert 'caching              = "ReadWrite"' in content
    
    def test_vm_image_configuration(self):
        """Test VM uses Ubuntu 22.04 LTS"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'source_image_reference' in content
            assert 'publisher = "Canonical"' in content
            assert '"22_04-lts' in content.lower() or '22.04' in content
            assert 'offer' in content
    
    def test_ssh_key_configuration(self):
        """Test SSH key authentication is configured"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'admin_ssh_key' in content
            assert 'public_key' in content
            assert 'username   = "azureuser"' in content
    
    def test_boot_diagnostics(self):
        """Test boot diagnostics is enabled"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'boot_diagnostics' in content
            assert 'storage_account' in content.lower()
    
    def test_managed_identity(self):
        """Test VM has managed identity"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'identity' in content
            assert 'type = "SystemAssigned"' in content
    
    def test_monitor_agent_extension(self):
        """Test Azure Monitor agent is configured"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azurerm_virtual_machine_extension" "monitor_agent"' in content
            assert 'AzureMonitorLinuxAgent' in content
            assert 'auto_upgrade_minor_version = true' in content
    
    def test_auto_shutdown_schedule(self):
        """Test auto-shutdown is configured for cost savings"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'azurerm_dev_test_global_vm_shutdown_schedule' in content
            assert 'daily_recurrence_time = "2000"' in content
            assert 'enabled           = true' in content
    
    def test_backup_configuration(self):
        """Test VM backup is configured"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            # Check for backup configuration
            assert 'backup' in content.lower() or 'azurerm_backup_protected_vm' in content
    
    def test_module_variables(self):
        """Test module has all required variables"""
        variables_tf = self.module_dir / "variables.tf"
        if variables_tf.exists():
            content = variables_tf.read_text()
            required_vars = [
                'variable "environment"',
                'variable "location"',
                'variable "resource_group_name"',
                'variable "subnet_id"',
                'variable "tags"',
                'variable "ssh_public_key_path"'
            ]
            for var in required_vars:
                assert var in content, f"{var} should be defined"
    
    def test_module_outputs(self):
        """Test module provides necessary outputs"""
        outputs_tf = self.module_dir / "outputs.tf"
        if outputs_tf.exists():
            content = outputs_tf.read_text()
            required_outputs = [
                'output "vm_id"',
                'output "public_ip_address"',
                'output "public_ip_fqdn"',
                'output "private_ip_address"'
            ]
            for output in required_outputs:
                assert output in content, f"{output} should be defined"
    
    def test_storage_account_for_diagnostics(self):
        """Test storage account exists for boot diagnostics"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azurerm_storage_account" "diagnostics"' in content
            assert 'account_tier             = "Standard"' in content
            assert 'account_replication_type = "LRS"' in content