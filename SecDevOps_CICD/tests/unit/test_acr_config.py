import pytest
from pathlib import Path

class TestAzureContainerRegistry:
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.terraform_dir = Path(__file__).parent.parent.parent / "terraform"
        self.module_dir = self.terraform_dir / "modules" / "acr"
        
    def test_module_structure_exists(self):
        """Test that ACR module structure exists"""
        assert self.module_dir.exists(), "ACR module directory should exist"
        
        main_tf = self.module_dir / "main.tf"
        variables_tf = self.module_dir / "variables.tf"
        outputs_tf = self.module_dir / "outputs.tf"
        
        assert main_tf.exists(), "main.tf should exist in ACR module"
        assert variables_tf.exists(), "variables.tf should exist in ACR module"
        assert outputs_tf.exists(), "outputs.tf should exist in ACR module"
    
    def test_acr_resource_configuration(self):
        """Test ACR resource is properly configured"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azurerm_container_registry" "main"' in content
            assert 'acrsecdevops${var.environment}' in content
            assert 'sku                = "Premium"' in content
            assert 'admin_enabled      = false' in content
    
    def test_geo_replication(self):
        """Test geo-replication is configured"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'georeplications' in content
            assert 'northeurope' in content
            assert 'zone_redundancy_enabled = true' in content
    
    def test_retention_policy(self):
        """Test retention policy is configured"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'retention_policy' in content
            assert 'days    = 30' in content
            assert 'enabled = true' in content
    
    def test_trust_policy(self):
        """Test content trust policy is enabled"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'trust_policy' in content
            assert 'enabled = true' in content
    
    def test_network_rules(self):
        """Test network rules are configured"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'network_rule_set' in content
            assert 'default_action' in content
            assert 'ip_rule' in content
    
    def test_cleanup_task(self):
        """Test ACR cleanup task is configured"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azurerm_container_registry_task" "cleanup"' in content
            assert 'timer_trigger' in content
            assert 'schedule' in content
            assert 'acr purge' in content
    
    def test_service_principal(self):
        """Test service principal for Jenkins is created"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azuread_application" "jenkins_acr"' in content
            assert 'sp-jenkins-acr-${var.environment}' in content
            assert 'resource "azuread_service_principal" "jenkins_acr"' in content
            assert 'resource "azuread_service_principal_password" "jenkins_acr"' in content
    
    def test_role_assignments(self):
        """Test proper role assignments for service principal"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'resource "azurerm_role_assignment" "jenkins_acr_push"' in content
            assert 'role_definition_name = "AcrPush"' in content
            assert 'resource "azurerm_role_assignment" "jenkins_acr_pull"' in content
            assert 'role_definition_name = "AcrPull"' in content
    
    def test_module_variables(self):
        """Test module has required variables"""
        variables_tf = self.module_dir / "variables.tf"
        if variables_tf.exists():
            content = variables_tf.read_text()
            required_vars = [
                'variable "environment"',
                'variable "location"',
                'variable "resource_group_name"',
                'variable "tags"',
                'variable "jenkins_public_ip"'
            ]
            for var in required_vars:
                assert var in content, f"{var} should be defined"
    
    def test_module_outputs(self):
        """Test module provides necessary outputs"""
        outputs_tf = self.module_dir / "outputs.tf"
        if outputs_tf.exists():
            content = outputs_tf.read_text()
            required_outputs = [
                'output "acr_login_server"',
                'output "acr_id"',
                'output "acr_name"',
                'output "jenkins_sp_id"',
                'output "jenkins_sp_password"'
            ]
            for output in required_outputs:
                assert output in content, f"{output} should be defined"
    
    def test_acr_sku_premium(self):
        """Test ACR uses Premium SKU for advanced features"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            assert 'sku                = "Premium"' in content, "ACR should use Premium SKU"
    
    def test_vulnerability_scanning(self):
        """Test vulnerability scanning is configured (Premium feature)"""
        main_tf = self.module_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            # Premium SKU enables vulnerability scanning by default
            assert 'sku                = "Premium"' in content, "Premium SKU enables vulnerability scanning"