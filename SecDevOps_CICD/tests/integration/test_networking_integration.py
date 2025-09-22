import pytest
import os
import subprocess
import json
from pathlib import Path

class TestNetworkingIntegration:
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.terraform_dir = Path(__file__).parent.parent.parent / "terraform"
        
    def test_terraform_init(self):
        """Test terraform can initialize"""
        result = subprocess.run(
            ["terraform", "init", "-backend=false"],
            cwd=self.terraform_dir,
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Terraform init failed: {result.stderr}"
    
    def test_terraform_validate(self):
        """Test terraform configuration is valid"""
        # First init
        subprocess.run(
            ["terraform", "init", "-backend=false"],
            cwd=self.terraform_dir,
            capture_output=True,
            text=True
        )
        
        # Then validate
        result = subprocess.run(
            ["terraform", "validate"],
            cwd=self.terraform_dir,
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Terraform validate failed: {result.stderr}"
    
    def test_terraform_plan(self):
        """Test terraform plan executes successfully"""
        # Check if tfvars file exists
        tfvars_file = self.terraform_dir / "environments" / "dev.tfvars"
        if not tfvars_file.exists():
            pytest.skip("dev.tfvars not found, skipping plan test")
            
        # Init first
        subprocess.run(
            ["terraform", "init", "-backend=false"],
            cwd=self.terraform_dir,
            capture_output=True,
            text=True
        )
        
        # Run plan
        result = subprocess.run(
            ["terraform", "plan", "-var-file=environments/dev.tfvars", "-no-color"],
            cwd=self.terraform_dir,
            capture_output=True,
            text=True
        )
        
        # Plan should succeed even if resources would be created
        assert result.returncode == 0, f"Terraform plan failed: {result.stderr}"
        
        # Check plan output contains expected resources
        assert "azurerm_resource_group.main" in result.stdout or "will be created" in result.stdout
        
    @pytest.mark.skip(reason="Requires Azure credentials and actual deployment")
    def test_deployed_resource_group(self):
        """Test actual deployed resource group - requires Azure access"""
        # This test would run after actual deployment
        # Skipped in unit testing phase
        pass
    
    @pytest.mark.skip(reason="Requires deployed infrastructure")
    def test_network_connectivity(self):
        """Test network connectivity between subnets - requires deployment"""
        # This test would verify actual network connectivity
        # Skipped in unit testing phase
        pass
    
    @pytest.mark.skip(reason="Requires deployed infrastructure")
    def test_nsg_effectiveness(self):
        """Test NSG rules are actually blocking/allowing traffic"""
        # This test would verify NSG rules work as expected
        # Skipped in unit testing phase
        pass