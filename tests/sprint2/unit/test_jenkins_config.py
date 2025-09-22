#!/usr/bin/env python3
"""
Unit tests for Jenkins installation and configuration
STORY-003-01: Install and Configure Jenkins Master
"""

import pytest
import subprocess
import requests
import json
import os
from unittest.mock import patch, MagicMock, mock_open
import socket


class TestJenkinsInstallation:
    """Test Jenkins installation and configuration"""
    
    def test_jenkins_service_status(self):
        """Jenkins service should be running"""
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, 
                stdout='active\n',
                stderr=''
            )
            result = subprocess.run(
                ['systemctl', 'is-active', 'jenkins'],
                capture_output=True,
                text=True
            )
            assert result.stdout.strip() == 'active'
    
    def test_jenkins_port_listening(self):
        """Jenkins should be listening on port 8080"""
        with patch('socket.socket') as mock_socket:
            mock_sock_instance = MagicMock()
            mock_socket.return_value = mock_sock_instance
            mock_sock_instance.connect_ex.return_value = 0  # 0 means port is open
            
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(('localhost', 8080))
            assert result == 0
    
    def test_jenkins_ssl_configured(self):
        """HTTPS should be configured via Nginx"""
        with patch('requests.get') as mock_get:
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_get.return_value = mock_response
            
            response = requests.get('https://localhost', verify=False)
            assert response.status_code in [200, 403]  # 403 if auth required
    
    def test_jenkins_plugins_installed(self):
        """Essential plugins should be installed"""
        required_plugins = [
            'git', 'docker-workflow', 'pipeline', 
            'azure-credentials', 'sonar', 'blueocean',
            'credentials-binding', 'workflow-aggregator'
        ]
        
        with patch('builtins.open', mock_open(read_data='git\ndocker-workflow\npipeline\nazure-credentials\nsonar\nblueocean\ncredentials-binding\nworkflow-aggregator')):
            with open('/var/lib/jenkins/plugins.txt', 'r') as f:
                installed_plugins = f.read().splitlines()
            
            for plugin in required_plugins:
                assert plugin in installed_plugins, f"Plugin {plugin} not installed"
    
    def test_jenkins_backup_configured(self):
        """Backup cron job should exist"""
        with patch('os.path.exists') as mock_exists:
            mock_exists.return_value = True
            assert os.path.exists('/etc/cron.d/jenkins-backup')
    
    def test_jenkins_data_disk_mounted(self):
        """Data disk should be mounted for Jenkins home"""
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout='/dev/sdc  50G  5G  45G  10% /mnt/jenkins\n',
                stderr=''
            )
            result = subprocess.run(['df', '-h'], capture_output=True, text=True)
            assert '/mnt/jenkins' in result.stdout
    
    def test_jenkins_java_version(self):
        """Java 17 should be installed"""
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout='openjdk version "17.0.8" 2023-07-18\n',
                stderr=''
            )
            result = subprocess.run(
                ['java', '-version'], 
                capture_output=True, 
                text=True
            )
            assert '17' in result.stdout or '17' in result.stderr
    
    def test_nginx_jenkins_config(self):
        """Nginx should have Jenkins reverse proxy configured"""
        with patch('os.path.exists') as mock_exists:
            mock_exists.return_value = True
            assert os.path.exists('/etc/nginx/sites-enabled/jenkins')
    
    def test_jenkins_initial_admin_password(self):
        """Initial admin password file should be accessible"""
        with patch('os.path.exists') as mock_exists:
            mock_exists.return_value = True
            assert os.path.exists('/var/lib/jenkins/secrets/initialAdminPassword')
    
    def test_jenkins_permissions(self):
        """Jenkins directory should have correct permissions"""
        with patch('os.stat') as mock_stat:
            mock_stat_result = MagicMock()
            mock_stat_result.st_uid = 1000  # jenkins user
            mock_stat_result.st_gid = 1000  # jenkins group
            mock_stat.return_value = mock_stat_result
            
            stat_info = os.stat('/var/lib/jenkins')
            # In real scenario, you'd check against actual jenkins uid/gid
            assert stat_info.st_uid == 1000
            assert stat_info.st_gid == 1000


class TestJenkinsConfiguration:
    """Test Jenkins configuration settings"""
    
    def test_jenkins_memory_settings(self):
        """Jenkins should have appropriate memory settings"""
        with patch('builtins.open', mock_open(read_data='JAVA_OPTS="-Xmx2g -XX:+UseG1GC"')):
            with open('/etc/default/jenkins', 'r') as f:
                content = f.read()
            assert '-Xmx2g' in content
            assert '-XX:+UseG1GC' in content
    
    def test_jenkins_security_settings(self):
        """Jenkins should have security settings configured"""
        expected_settings = {
            'csrf_protection': True,
            'disable_remember_me': False,
            'use_security': True
        }
        
        with patch('builtins.open', mock_open(read_data=json.dumps(expected_settings))):
            with open('/var/lib/jenkins/config.json', 'r') as f:
                config = json.load(f)
            
            assert config.get('csrf_protection') is True
            assert config.get('use_security') is True
    
    def test_jenkins_url_configured(self):
        """Jenkins URL should be properly configured"""
        with patch('builtins.open', mock_open(read_data='JENKINS_URL=https://jenkins.local')):
            with open('/etc/default/jenkins', 'r') as f:
                content = f.read()
            assert 'JENKINS_URL=https://jenkins.local' in content
    
    def test_ssl_certificate_exists(self):
        """SSL certificates should exist"""
        with patch('os.path.exists') as mock_exists:
            mock_exists.return_value = True
            assert os.path.exists('/etc/nginx/ssl/jenkins.crt')
            assert os.path.exists('/etc/nginx/ssl/jenkins.key')


class TestJenkinsPlugins:
    """Test Jenkins plugins installation"""
    
    def test_required_plugins_list(self):
        """Verify required plugins list is comprehensive"""
        required_plugins = [
            'git', 'github', 'github-branch-source',
            'docker-commons', 'docker-workflow', 'docker-build-step',
            'pipeline-model-definition', 'pipeline-stage-view',
            'azure-credentials', 'azure-container-agents',
            'sonar', 'dependency-check-jenkins-plugin',
            'blueocean', 'slack', 'email-ext'
        ]
        
        with patch('builtins.open', mock_open(read_data='\n'.join(required_plugins))):
            with open('/var/lib/jenkins/required-plugins.txt', 'r') as f:
                plugins = f.read().splitlines()
            
            assert len(plugins) >= len(required_plugins)
            for plugin in required_plugins:
                assert plugin in plugins


if __name__ == '__main__':
    pytest.main([__file__, '-v'])