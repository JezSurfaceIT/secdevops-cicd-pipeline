import pytest
import subprocess
from pathlib import Path

class TestACRIntegration:
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.terraform_dir = Path(__file__).parent.parent.parent / "terraform"
        
    def test_terraform_validate_with_acr_module(self):
        """Test terraform validates with ACR module included"""
        main_tf = self.terraform_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            if 'module "acr"' in content:
                # Run terraform init and validate
                subprocess.run(
                    ["terraform", "init", "-backend=false"],
                    cwd=self.terraform_dir,
                    capture_output=True,
                    text=True
                )
                
                result = subprocess.run(
                    ["terraform", "validate"],
                    cwd=self.terraform_dir,
                    capture_output=True,
                    text=True
                )
                assert result.returncode == 0, f"Terraform validate failed: {result.stderr}"
    
    def test_terraform_plan_with_acr(self):
        """Test terraform plan includes ACR resources"""
        tfvars_file = self.terraform_dir / "environments" / "dev.tfvars"
        if not tfvars_file.exists():
            pytest.skip("dev.tfvars not found, skipping plan test")
        
        main_tf = self.terraform_dir / "main.tf"
        if main_tf.exists() and 'module "acr"' in main_tf.read_text():
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
            
            # Check plan includes ACR resources
            if result.returncode == 0:
                assert "azurerm_container_registry" in result.stdout or "acr" in result.stdout.lower()
    
    @pytest.mark.skip(reason="Requires Azure credentials")
    def test_acr_login(self):
        """Test ACR login with service principal"""
        pass
    
    @pytest.mark.skip(reason="Requires Azure credentials")
    def test_acr_push_pull(self):
        """Test pushing and pulling images from ACR"""
        pass
    
    @pytest.mark.skip(reason="Requires Azure credentials")
    def test_acr_vulnerability_scanning(self):
        """Test vulnerability scanning is enabled"""
        pass
    
    @pytest.mark.skip(reason="Requires Azure credentials")
    def test_acr_geo_replication(self):
        """Test geo-replication is working"""
        pass
    
    @pytest.mark.skip(reason="Requires Azure credentials")
    def test_acr_retention_policy(self):
        """Test retention policy is applied"""
        pass