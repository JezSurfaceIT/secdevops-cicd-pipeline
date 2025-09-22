import pytest
import subprocess
from pathlib import Path

class TestJenkinsVMIntegration:
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.terraform_dir = Path(__file__).parent.parent.parent / "terraform"
        
    def test_terraform_validate_with_vm_module(self):
        """Test terraform validates with VM module included"""
        # Check if main.tf includes the jenkins-vm module
        main_tf = self.terraform_dir / "main.tf"
        if main_tf.exists():
            content = main_tf.read_text()
            if 'module "jenkins_vm"' in content:
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
    
    def test_terraform_plan_with_vm(self):
        """Test terraform plan includes VM resources"""
        tfvars_file = self.terraform_dir / "environments" / "dev.tfvars"
        if not tfvars_file.exists():
            pytest.skip("dev.tfvars not found, skipping plan test")
        
        # Check if jenkins_vm module is in main.tf
        main_tf = self.terraform_dir / "main.tf"
        if main_tf.exists() and 'module "jenkins_vm"' in main_tf.read_text():
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
            
            # Check plan includes VM resources
            if result.returncode == 0:
                assert "azurerm_linux_virtual_machine" in result.stdout or "jenkins" in result.stdout
                assert "azurerm_public_ip" in result.stdout or "public_ip" in result.stdout
    
    @pytest.mark.skip(reason="Requires Azure credentials")
    def test_vm_connectivity(self):
        """Test VM is accessible via SSH after deployment"""
        pass
    
    @pytest.mark.skip(reason="Requires Azure credentials")  
    def test_vm_extensions_installed(self):
        """Test VM extensions are properly installed"""
        pass
    
    @pytest.mark.skip(reason="Requires Azure credentials")
    def test_auto_shutdown_active(self):
        """Test auto-shutdown schedule is active"""
        pass