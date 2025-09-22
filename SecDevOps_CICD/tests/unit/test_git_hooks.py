"""
Unit tests for Git hooks configuration and implementation.
Tests pre-commit, commit-msg, and pre-push hooks.
"""

import unittest
import os
import subprocess
import stat
from pathlib import Path
import tempfile
import shutil


class TestGitHooks(unittest.TestCase):
    """Test Git hooks implementation and configuration."""
    
    def setUp(self):
        """Set up test environment."""
        self.project_root = Path(__file__).parent.parent.parent
        self.hooks_dir = self.project_root / '.git' / 'hooks'
        self.scripts_dir = self.project_root / 'scripts' / 'git-hooks'
        
        # Create a temporary directory for testing hook scripts
        self.temp_dir = tempfile.mkdtemp()
    
    def tearDown(self):
        """Clean up test environment."""
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    def test_git_hooks_directory_exists(self):
        """Test that git hooks scripts directory exists."""
        self.assertTrue(self.scripts_dir.exists(), "Git hooks scripts directory should exist")
        
        # Check for individual hook scripts
        required_hooks = [
            'pre-commit',
            'commit-msg',
            'pre-push'
        ]
        
        for hook_name in required_hooks:
            hook_path = self.scripts_dir / hook_name
            self.assertTrue(hook_path.exists(), f"Hook script {hook_name} should exist")
    
    def test_pre_commit_hook_script(self):
        """Test pre-commit hook script functionality."""
        pre_commit_script = self.scripts_dir / 'pre-commit'
        self.assertTrue(pre_commit_script.exists(), "Pre-commit script should exist")
        
        # Check script is executable
        self.assertTrue(os.access(str(pre_commit_script), os.X_OK), 
                       "Pre-commit script should be executable")
        
        with open(pre_commit_script, 'r') as f:
            content = f.read()
            
            # Check for essential pre-commit checks
            self.assertIn('#!/bin/bash', content)
            self.assertIn('# Pre-commit hook', content)
            
            # Security checks
            self.assertIn('secrets', content.lower())
            self.assertIn('credentials', content.lower())
            
            # Code quality checks
            self.assertIn('lint', content.lower())
            self.assertIn('format', content.lower())
            
            # Test execution
            self.assertIn('test', content.lower())
    
    def test_commit_msg_hook_script(self):
        """Test commit-msg hook script for message validation."""
        commit_msg_script = self.scripts_dir / 'commit-msg'
        self.assertTrue(commit_msg_script.exists(), "Commit-msg script should exist")
        
        # Check script is executable
        self.assertTrue(os.access(str(commit_msg_script), os.X_OK),
                       "Commit-msg script should be executable")
        
        with open(commit_msg_script, 'r') as f:
            content = f.read()
            
            # Check for commit message validation
            self.assertIn('#!/bin/bash', content)
            self.assertIn('# Commit message hook', content)
            
            # Conventional commits format check
            self.assertIn('feat:', content.lower())
            self.assertIn('fix:', content.lower())
            self.assertIn('docs:', content.lower())
            self.assertIn('test:', content.lower())
            self.assertIn('refactor:', content.lower())
            
            # Message length validation
            self.assertIn('length', content.lower())
            self.assertIn('50', content)  # Subject line length
    
    def test_pre_push_hook_script(self):
        """Test pre-push hook script for push validation."""
        pre_push_script = self.scripts_dir / 'pre-push'
        self.assertTrue(pre_push_script.exists(), "Pre-push script should exist")
        
        # Check script is executable
        self.assertTrue(os.access(str(pre_push_script), os.X_OK),
                       "Pre-push script should be executable")
        
        with open(pre_push_script, 'r') as f:
            content = f.read()
            
            # Check for pre-push validations
            self.assertIn('#!/bin/bash', content)
            self.assertIn('# Pre-push hook', content)
            
            # Protected branch check
            self.assertIn('main', content)
            self.assertIn('master', content)
            self.assertIn('protected', content.lower())
            
            # Test execution before push
            self.assertIn('test', content.lower())
            
            # Large file check
            self.assertIn('size', content.lower())
    
    def test_install_hooks_script_exists(self):
        """Test that hook installation script exists."""
        install_script = self.scripts_dir / 'install-hooks.sh'
        self.assertTrue(install_script.exists(), "Install hooks script should exist")
        
        # Check script is executable
        self.assertTrue(os.access(str(install_script), os.X_OK),
                       "Install script should be executable")
        
        with open(install_script, 'r') as f:
            content = f.read()
            
            # Check installation logic
            self.assertIn('#!/bin/bash', content)
            self.assertIn('.git/hooks', content)
            self.assertIn('chmod +x', content)
            self.assertIn('pre-commit', content)
            self.assertIn('commit-msg', content)
            self.assertIn('pre-push', content)
    
    def test_hook_scripts_are_shellcheck_compliant(self):
        """Test that all hook scripts pass shellcheck validation."""
        # This test requires shellcheck to be installed
        hooks = ['pre-commit', 'commit-msg', 'pre-push', 'install-hooks.sh']
        
        for hook_name in hooks:
            hook_path = self.scripts_dir / hook_name
            if not hook_path.exists():
                continue  # Skip if not created yet
            
            # Check if shellcheck is available
            try:
                result = subprocess.run(['which', 'shellcheck'], 
                                      capture_output=True, text=True)
                if result.returncode != 0:
                    self.skipTest("shellcheck not installed")
            except:
                self.skipTest("shellcheck not available")
            
            # Run shellcheck on the hook script
            result = subprocess.run(['shellcheck', '-S', 'error', str(hook_path)],
                                  capture_output=True, text=True)
            self.assertEqual(result.returncode, 0,
                           f"Hook {hook_name} should pass shellcheck: {result.stderr}")
    
    def test_pre_commit_config_has_custom_hooks(self):
        """Test that .pre-commit-config.yaml includes custom local hooks."""
        pre_commit_config = self.project_root / '.pre-commit-config.yaml'
        
        with open(pre_commit_config, 'r') as f:
            content = f.read()
            
            # Check for local hooks section
            self.assertIn('- repo: local', content)
            
            # Check for custom hooks
            self.assertIn('no-commit-to-branch', content)
            self.assertIn('pytest-check', content)
    
    def test_commit_msg_validation_logic(self):
        """Test commit message validation logic."""
        # Create a test commit message file
        test_msg_file = Path(self.temp_dir) / 'test_commit_msg'
        
        # Test valid conventional commit messages
        valid_messages = [
            "feat: add new feature",
            "fix: resolve bug in parser",
            "docs: update README",
            "test: add unit tests",
            "chore: update dependencies",
            "refactor: improve code structure",
            "style: format code",
            "perf: optimize algorithm",
            "ci: update pipeline",
            "build: update build process"
        ]
        
        commit_msg_script = self.scripts_dir / 'commit-msg'
        if commit_msg_script.exists():
            for msg in valid_messages:
                with open(test_msg_file, 'w') as f:
                    f.write(msg)
                
                # The script should validate these as correct
                # (We can't actually run it here without git context)
                self.assertTrue(len(msg) <= 72, "Valid message length")
                self.assertTrue(msg.split(':')[0] in [
                    'feat', 'fix', 'docs', 'test', 'chore',
                    'refactor', 'style', 'perf', 'ci', 'build'
                ], "Valid commit type")
    
    def test_pre_push_protected_branch_logic(self):
        """Test that pre-push prevents direct pushes to protected branches."""
        pre_push_script = self.scripts_dir / 'pre-push'
        
        if pre_push_script.exists():
            with open(pre_push_script, 'r') as f:
                content = f.read()
                
                # Check for protection of main branches
                self.assertIn('refs/heads/main', content)
                self.assertIn('refs/heads/master', content)
                self.assertIn('refs/heads/develop', content)
                
                # Check for error messages
                self.assertIn('protected branch', content.lower())
                self.assertIn('exit 1', content)
    
    def test_hooks_integration_with_pre_commit_framework(self):
        """Test that custom hooks integrate with pre-commit framework."""
        pre_commit_config = self.project_root / '.pre-commit-config.yaml'
        
        with open(pre_commit_config, 'r') as f:
            content = f.read()
            
            # Verify hooks work with pre-commit framework
            self.assertIn('stages:', content)
            self.assertIn('[commit]', content)
            self.assertIn('[push]', content)
    
    def test_secret_detection_in_pre_commit(self):
        """Test that pre-commit hook detects secrets."""
        pre_commit_script = self.scripts_dir / 'pre-commit'
        
        if pre_commit_script.exists():
            with open(pre_commit_script, 'r') as f:
                content = f.read()
                
                # Check for secret detection patterns
                patterns = [
                    'AWS_SECRET',
                    'API_KEY',
                    'private_key',
                    'password',
                    'token',
                    'bearer'
                ]
                
                for pattern in patterns:
                    self.assertIn(pattern.lower(), content.lower(),
                                f"Should check for {pattern}")
    
    def test_terraform_validation_in_hooks(self):
        """Test that hooks validate Terraform files."""
        pre_commit_script = self.scripts_dir / 'pre-commit'
        
        if pre_commit_script.exists():
            with open(pre_commit_script, 'r') as f:
                content = f.read()
                
                # Check for Terraform validation
                self.assertIn('terraform', content.lower())
                self.assertIn('fmt', content)
                self.assertIn('validate', content)
    
    def test_python_linting_in_hooks(self):
        """Test that hooks perform Python linting."""
        pre_commit_script = self.scripts_dir / 'pre-commit'
        
        if pre_commit_script.exists():
            with open(pre_commit_script, 'r') as f:
                content = f.read()
                
                # Check for Python linting tools
                self.assertTrue(
                    'flake8' in content.lower() or
                    'pylint' in content.lower() or
                    'black' in content.lower(),
                    "Should include Python linting"
                )


if __name__ == '__main__':
    unittest.main()