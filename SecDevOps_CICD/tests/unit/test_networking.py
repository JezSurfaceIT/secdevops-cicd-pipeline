import pytest
import json
import subprocess
import os
from pathlib import Path

class TestAzureNetworking:
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.terraform_dir = Path(__file__).parent.parent.parent / "terraform"
        self.module_dir = self.terraform_dir / "modules" / "networking"
        
    def test_resource_group_exists(self):
        """Test that resource group is created with correct naming"""
        # Check that main.tf exists
        main_tf = self.module_dir / "main.tf"
        assert main_tf.exists(), "main.tf should exist in networking module"
        
        # Verify resource group configuration
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azurerm_resource_group" "main"' in content
            assert 'rg-secdevops-cicd-${var.environment}' in content
            
    def test_virtual_network_configuration(self):
        """Test VNet has correct address space"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azurerm_virtual_network" "main"' in content
            assert '10.0.0.0/16' in content
            assert 'vnet-secdevops-${var.environment}' in content
    
    def test_subnet_configuration(self):
        """Test subnets are correctly configured"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            # Assert Jenkins subnet: 10.0.1.0/24
            assert 'resource "azurerm_subnet" "jenkins"' in content
            assert '10.0.1.0/24' in content
            assert 'snet-jenkins' in content
            
            # Assert Container subnet: 10.0.2.0/24
            assert 'resource "azurerm_subnet" "containers"' in content
            assert '10.0.2.0/24' in content
            assert 'snet-containers' in content
    
    def test_nsg_rules(self):
        """Test NSG has required security rules"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            # Assert SSH, HTTPS, Jenkins ports
            assert 'resource "azurerm_network_security_group" "jenkins"' in content
            assert 'destination_port_range    = "22"' in content  # SSH
            assert 'destination_port_range    = "443"' in content  # HTTPS
            assert 'destination_port_range    = "8080"' in content  # Jenkins
            assert 'nsg-jenkins' in content
    
    def test_resource_tags(self):
        """Test all resources have required tags"""
        main_tf = self.module_dir / "main.tf"
        variables_tf = self.module_dir / "variables.tf"
        
        # Check variables.tf for tags variable
        if variables_tf.exists():
            content = variables_tf.read_text()
            assert 'variable "tags"' in content
            
        # Check main.tf uses tags
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'tags     = var.tags' in content or 'tags = var.tags' in content
            
    def test_nsg_subnet_association(self):
        """Test NSG is associated with subnet"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azurerm_subnet_network_security_group_association" "jenkins"' in content
            assert 'subnet_id' in content
            assert 'network_security_group_id' in content
            
    def test_module_outputs(self):
        """Test module has required outputs"""
        outputs_tf = self.module_dir / "outputs.tf"
        assert outputs_tf.exists(), "outputs.tf should exist in networking module"
        
        if outputs_tf.exists():
            content = outputs_tf.read_text()
            assert 'output "resource_group_name"' in content
            assert 'output "vnet_id"' in content
            assert 'output "jenkins_subnet_id"' in content
            assert 'output "containers_subnet_id"' in content

    def test_module_variables(self):
        """Test module has required variables"""
        variables_tf = self.module_dir / "variables.tf"
        assert variables_tf.exists(), "variables.tf should exist in networking module"
        
        if variables_tf.exists():
            content = variables_tf.read_text()
            assert 'variable "environment"' in content
            assert 'variable "location"' in content
            assert 'variable "tags"' in content
            assert 'variable "admin_ip"' in content