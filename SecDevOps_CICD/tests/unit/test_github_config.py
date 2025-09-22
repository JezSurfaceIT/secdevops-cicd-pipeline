"""
Unit tests for GitHub repository configuration.
Tests repository structure, templates, and configuration files.
"""

import unittest
import os
import yaml
from pathlib import Path


class TestGitHubConfiguration(unittest.TestCase):
    """Test GitHub repository configuration and structure."""
    
    def setUp(self):
        """Set up test environment."""
        self.project_root = Path(__file__).parent.parent.parent
        self.github_dir = self.project_root / '.github'
    
    def test_github_directory_structure(self):
        """Test that .github directory structure exists."""
        self.assertTrue(self.github_dir.exists(), ".github directory should exist")
        
        expected_dirs = [
            self.github_dir / 'ISSUE_TEMPLATE',
            self.github_dir / 'workflows'
        ]
        
        for expected_dir in expected_dirs:
            self.assertTrue(expected_dir.exists(), f"{expected_dir} should exist")
    
    def test_codeowners_file_exists(self):
        """Test that CODEOWNERS file exists and is properly formatted."""
        codeowners_file = self.github_dir / 'CODEOWNERS'
        self.assertTrue(codeowners_file.exists(), "CODEOWNERS file should exist")
        
        # Verify content structure
        with open(codeowners_file, 'r') as f:
            content = f.read()
            # Check for required sections
            self.assertIn('# Infrastructure', content)
            self.assertIn('# CI/CD', content)
            self.assertIn('# Security', content)
            self.assertIn('/terraform/', content)
            self.assertIn('/.github/', content)
            self.assertIn('/scripts/', content)
    
    def test_pull_request_template_exists(self):
        """Test that pull request template exists."""
        pr_template = self.github_dir / 'pull_request_template.md'
        self.assertTrue(pr_template.exists(), "Pull request template should exist")
        
        with open(pr_template, 'r') as f:
            content = f.read()
            # Check for required sections
            self.assertIn('## Description', content)
            self.assertIn('## Type of Change', content)
            self.assertIn('## Testing', content)
            self.assertIn('## Checklist', content)
            self.assertIn('- [ ]', content)  # Checkbox format
    
    def test_issue_templates_exist(self):
        """Test that all required issue templates exist."""
        issue_template_dir = self.github_dir / 'ISSUE_TEMPLATE'
        
        required_templates = [
            'bug_report.md',
            'feature_request.md',
            'security_issue.md'
        ]
        
        for template_name in required_templates:
            template_path = issue_template_dir / template_name
            self.assertTrue(template_path.exists(), f"Issue template {template_name} should exist")
            
            # Verify template has front matter
            with open(template_path, 'r') as f:
                content = f.read()
                self.assertTrue(content.startswith('---'), f"{template_name} should have YAML front matter")
                self.assertIn('name:', content)
                self.assertIn('about:', content)
                self.assertIn('labels:', content)
    
    def test_bug_report_template_content(self):
        """Test bug report template has required sections."""
        bug_template = self.github_dir / 'ISSUE_TEMPLATE' / 'bug_report.md'
        
        with open(bug_template, 'r') as f:
            content = f.read()
            # Check for required sections
            self.assertIn('## Bug Description', content)
            self.assertIn('## Steps to Reproduce', content)
            self.assertIn('## Expected Behavior', content)
            self.assertIn('## Actual Behavior', content)
            self.assertIn('## Environment', content)
            self.assertIn('## Screenshots', content)
    
    def test_feature_request_template_content(self):
        """Test feature request template has required sections."""
        feature_template = self.github_dir / 'ISSUE_TEMPLATE' / 'feature_request.md'
        
        with open(feature_template, 'r') as f:
            content = f.read()
            # Check for required sections
            self.assertIn('## Feature Description', content)
            self.assertIn('## Problem Statement', content)
            self.assertIn('## Proposed Solution', content)
            self.assertIn('## Alternatives Considered', content)
            self.assertIn('## Additional Context', content)
    
    def test_security_issue_template_content(self):
        """Test security issue template has required sections."""
        security_template = self.github_dir / 'ISSUE_TEMPLATE' / 'security_issue.md'
        
        with open(security_template, 'r') as f:
            content = f.read()
            # Check for required sections and security notice
            self.assertIn('## ⚠️ SECURITY NOTICE', content)
            self.assertIn('## Vulnerability Description', content)
            self.assertIn('## Impact', content)
            self.assertIn('## Steps to Reproduce', content)
            self.assertIn('## Suggested Fix', content)
            self.assertIn('private disclosure', content.lower())
    
    def test_terraform_workflow_exists(self):
        """Test that Terraform testing workflow exists."""
        workflow_file = self.github_dir / 'workflows' / 'terraform-test.yml'
        self.assertTrue(workflow_file.exists(), "Terraform test workflow should exist")
        
        with open(workflow_file, 'r') as f:
            workflow = yaml.safe_load(f)
            
            # Check workflow structure
            self.assertIn('name', workflow)
            # GitHub Actions uses 'on' but YAML interprets it as True
            self.assertTrue(True in workflow or 'on' in workflow)
            self.assertIn('jobs', workflow)
            
            # Check triggers - 'on' key becomes True in YAML
            on_key = workflow.get(True) or workflow.get('on')
            self.assertIn('push', on_key)
            self.assertIn('pull_request', on_key)
            
            # Check job configuration
            self.assertIn('terraform', workflow['jobs'])
            terraform_job = workflow['jobs']['terraform']
            self.assertIn('runs-on', terraform_job)
            self.assertIn('steps', terraform_job)
    
    def test_precommit_config_exists(self):
        """Test that pre-commit configuration file exists."""
        precommit_file = self.project_root / '.pre-commit-config.yaml'
        self.assertTrue(precommit_file.exists(), "Pre-commit config should exist")
        
        with open(precommit_file, 'r') as f:
            config = yaml.safe_load(f)
            
            # Check configuration structure
            self.assertIn('repos', config)
            self.assertIsInstance(config['repos'], list)
            self.assertTrue(len(config['repos']) > 0, "Should have at least one repo configured")
            
            # Check for essential hooks
            hook_ids = []
            for repo in config['repos']:
                if 'hooks' in repo:
                    for hook in repo['hooks']:
                        if 'id' in hook:
                            hook_ids.append(hook['id'])
            
            # Essential hooks that should be present
            essential_hooks = [
                'trailing-whitespace',
                'end-of-file-fixer',
                'check-yaml',
                'check-added-large-files'
            ]
            
            for hook in essential_hooks:
                self.assertIn(hook, hook_ids, f"Hook {hook} should be configured")
    
    def test_github_config_script_exists(self):
        """Test that GitHub repository configuration script exists."""
        script_path = self.project_root / 'scripts' / 'setup' / 'configure-github-repo.sh'
        self.assertTrue(script_path.exists(), "GitHub configuration script should exist")
        
        # Check script is executable
        self.assertTrue(os.access(str(script_path), os.X_OK), "Script should be executable")
        
        with open(script_path, 'r') as f:
            content = f.read()
            # Check for required functions
            self.assertIn('#!/bin/bash', content)
            self.assertIn('set -e', content)  # Error handling
            self.assertIn('GITHUB_TOKEN', content)
            self.assertIn('GITHUB_REPO', content)
            self.assertIn('branch protection', content.lower())
            self.assertIn('webhook', content.lower())
    
    def test_gitignore_comprehensive(self):
        """Test that .gitignore is comprehensive for the project."""
        gitignore_file = self.project_root / '.gitignore'
        self.assertTrue(gitignore_file.exists(), ".gitignore should exist")
        
        with open(gitignore_file, 'r') as f:
            content = f.read()
            
            # Essential patterns that should be ignored
            patterns = [
                '*.tfstate',
                '*.tfstate.backup',
                '.terraform/',
                '__pycache__/',
                '*.pyc',
                '.env',
                'venv/',
                '.pytest_cache/',
                '.coverage',
                '*.log'
            ]
            
            for pattern in patterns:
                self.assertIn(pattern, content, f"Pattern {pattern} should be in .gitignore")


if __name__ == '__main__':
    unittest.main()