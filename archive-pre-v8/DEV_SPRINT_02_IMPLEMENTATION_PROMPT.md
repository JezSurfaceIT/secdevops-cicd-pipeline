# Developer Implementation Prompt - Sprint 2
## SecDevOps CI/CD Pipeline - Jenkins & Security Tools Setup

**Sprint:** 2 (Weeks 3-4)  
**Start Date:** Current  
**Prerequisites:** Sprint 1 Infrastructure Complete  
**Methodology:** Test-Driven Development (TDD)  

---

## 🎯 Your Mission

You are implementing Sprint 2 of the SecDevOps CI/CD pipeline. This sprint focuses on Jenkins installation, pipeline creation, security tool integration, and monitoring setup. You will build a production-ready CI/CD pipeline with comprehensive security scanning and quality gates.

---

## 📋 Sprint 2 Stories Overview

### Implementation Order:
1. **STORY-003-01:** Install and Configure Jenkins Master (8 points)
2. **STORY-003-02:** Create Base Jenkins Pipeline (13 points)  
3. **STORY-006-01:** Integrate Security Scanning Tools (8 points)
4. **STORY-003-03:** Implement Quality Gates (5 points)
5. **STORY-003-04:** Configure Monitoring and Alerting (8 points)

**Total Sprint Points:** 42

---

## 🚀 Quick Start Commands

```bash
# Navigate to project directory
cd ~/SecDevOps_CICD

# Create Sprint 2 branch
git checkout -b sprint-2/jenkins-pipeline

# Setup directory structure for Sprint 2
mkdir -p scripts/{jenkins,security,quality-gates,monitoring}
mkdir -p jenkins/{shared-libraries,config}
mkdir -p monitoring/{prometheus,grafana,alertmanager}
mkdir -p tests/sprint2/{unit,integration}

# Start implementation
code .
```

---

## 📁 Sprint 2 Directory Structure

```
SecDevOps_CICD/
├── jenkins/
│   ├── Jenkinsfile                    # Main pipeline
│   ├── Jenkinsfile.security          # Security-focused pipeline
│   ├── shared-libraries/
│   │   └── vars/
│   │       ├── buildUtils.groovy
│   │       ├── securityUtils.groovy
│   │       ├── testUtils.groovy
│   │       ├── deployUtils.groovy
│   │       ├── containerUtils.groovy
│   │       ├── qualityGates.groovy
│   │       └── notificationUtils.groovy
│   └── config/
│       ├── jenkins.yaml              # Jenkins configuration as code
│       ├── plugins.txt                # Required plugins list
│       └── credentials.xml           # Credential templates
├── scripts/
│   ├── jenkins/
│   │   ├── install-jenkins.sh
│   │   ├── configure-jenkins-ssl.sh
│   │   ├── install-plugins.groovy
│   │   ├── configure-sonarqube.groovy
│   │   └── backup-jenkins.sh
│   ├── security/
│   │   ├── install-security-tools.sh
│   │   ├── configure-snyk.sh
│   │   ├── configure-trivy.sh
│   │   ├── configure-sonarqube.sh
│   │   └── run-security-scan.sh
│   ├── quality-gates/
│   │   ├── quality-gate-evaluator.js
│   │   ├── thresholds-config.json
│   │   └── override-handler.sh
│   └── monitoring/
│       ├── install-monitoring-stack.sh
│       ├── configure-prometheus.sh
│       ├── configure-grafana.sh
│       └── setup-alerts.sh
├── monitoring/
│   ├── docker-compose.monitoring.yml
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── alert_rules.yml
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── jenkins-metrics.json
│   │   │   ├── security-overview.json
│   │   │   └── pipeline-performance.json
│   │   └── datasources/
│   │       └── prometheus.yml
│   └── alertmanager/
│       └── alertmanager.yml
├── tests/
│   └── sprint2/
│       ├── unit/
│       │   ├── test_jenkins_config.py
│       │   ├── test_pipeline_stages.py
│       │   ├── test_security_tools.py
│       │   └── test_quality_gates.py
│       └── integration/
│           ├── test_jenkins_pipeline.py
│           ├── test_security_scanning.py
│           ├── test_monitoring_stack.py
│           └── test_end_to_end_flow.py
└── docs/
    └── sprint2/
        ├── jenkins-setup-guide.md
        ├── pipeline-documentation.md
        ├── security-tools-guide.md
        └── monitoring-guide.md
```

---

## 🔄 Implementation Guide by Story

### STORY-003-01: Install and Configure Jenkins Master

#### Step 1: Write Tests First (TDD)

```python
# tests/sprint2/unit/test_jenkins_config.py
import pytest
import subprocess
import requests
import json
import os

class TestJenkinsInstallation:
    """Test Jenkins installation and configuration"""
    
    def test_jenkins_service_status(self):
        """Jenkins service should be running"""
        result = subprocess.run(
            ['systemctl', 'is-active', 'jenkins'],
            capture_output=True,
            text=True
        )
        assert result.stdout.strip() == 'active'
    
    def test_jenkins_port_listening(self):
        """Jenkins should be listening on port 8080"""
        result = subprocess.run(
            ['netstat', '-tlpn'],
            capture_output=True,
            text=True
        )
        assert '8080' in result.stdout
    
    def test_jenkins_ssl_configured(self):
        """HTTPS should be configured via Nginx"""
        response = requests.get('https://localhost', verify=False)
        assert response.status_code in [200, 403]  # 403 if auth required
    
    def test_jenkins_plugins_installed(self):
        """Essential plugins should be installed"""
        required_plugins = [
            'git', 'docker-workflow', 'pipeline', 
            'azure-credentials', 'sonar', 'blueocean'
        ]
        # Mock or actual API call to check plugins
        jenkins_url = 'http://localhost:8080'
        for plugin in required_plugins:
            # Implementation to verify plugin
            pass
    
    def test_jenkins_backup_configured(self):
        """Backup cron job should exist"""
        assert os.path.exists('/etc/cron.d/jenkins-backup')
    
    def test_jenkins_data_disk_mounted(self):
        """Data disk should be mounted for Jenkins home"""
        result = subprocess.run(['df', '-h'], capture_output=True, text=True)
        assert '/mnt/jenkins' in result.stdout
```

#### Step 2: Create Installation Script

```bash
#!/bin/bash
# scripts/jenkins/install-jenkins.sh

set -e

echo "🔧 Installing Jenkins Master..."
echo "================================"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for Jenkins to be ready
wait_for_jenkins() {
    echo "⏳ Waiting for Jenkins to start..."
    timeout=300
    while [ $timeout -gt 0 ]; do
        if curl -s http://localhost:8080/login > /dev/null; then
            echo "✅ Jenkins is ready!"
            return 0
        fi
        sleep 5
        ((timeout-=5))
    done
    echo "❌ Jenkins failed to start"
    return 1
}

# Update system
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Java 17
echo "☕ Installing Java 17..."
sudo apt-get install -y openjdk-17-jdk openjdk-17-jre
java -version

# Add Jenkins repository
echo "📚 Adding Jenkins repository..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
    /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
echo "📥 Installing Jenkins..."
sudo apt-get update
sudo apt-get install -y jenkins

# Configure Jenkins Java options
echo "⚙️ Configuring Jenkins..."
sudo systemctl stop jenkins
sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null <<EOF
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Xmx2g -XX:+UseG1GC -Djenkins.install.runSetupWizard=false"
EOF

# Setup data disk (if available)
if [ -b /dev/sdc ]; then
    echo "💾 Setting up data disk..."
    sudo mkfs.ext4 /dev/sdc
    sudo mkdir -p /mnt/jenkins
    sudo mount /dev/sdc /mnt/jenkins
    echo "/dev/sdc /mnt/jenkins ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    
    # Move Jenkins home
    sudo mv /var/lib/jenkins /mnt/jenkins/
    sudo ln -s /mnt/jenkins/jenkins /var/lib/jenkins
    sudo chown -R jenkins:jenkins /mnt/jenkins/jenkins
fi

# Start Jenkins
echo "🚀 Starting Jenkins..."
sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Wait for Jenkins
wait_for_jenkins

# Get initial admin password
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "🔑 Initial Admin Password:"
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
fi

echo "✅ Jenkins installation complete!"
echo "Access Jenkins at: http://$(hostname -I | awk '{print $1}'):8080"
```

#### Step 3: Configure SSL/TLS

```bash
#!/bin/bash
# scripts/jenkins/configure-jenkins-ssl.sh

set -e

echo "🔒 Configuring SSL/TLS for Jenkins..."

# Install Nginx
sudo apt-get install -y nginx certbot python3-certbot-nginx

# Generate self-signed certificate (for testing)
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/jenkins.key \
    -out /etc/nginx/ssl/jenkins.crt \
    -subj "/C=GB/ST=London/L=London/O=SecDevOps/CN=jenkins.local"

# Configure Nginx reverse proxy
sudo tee /etc/nginx/sites-available/jenkins > /dev/null <<'EOF'
upstream jenkins {
    keepalive 32;
    server 127.0.0.1:8080;
}

server {
    listen 80;
    server_name jenkins.local;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name jenkins.local;

    ssl_certificate /etc/nginx/ssl/jenkins.crt;
    ssl_certificate_key /etc/nginx/ssl/jenkins.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    access_log /var/log/nginx/jenkins.access.log;
    error_log /var/log/nginx/jenkins.error.log;

    location / {
        proxy_pass http://jenkins;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host:$server_port;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
        
        proxy_read_timeout 90;
        proxy_buffering off;
        
        # Required for Jenkins websocket agents
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Enable site and restart Nginx
sudo ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

echo "✅ SSL/TLS configuration complete!"
echo "Access Jenkins at: https://jenkins.local"
```

---

### STORY-003-02: Create Base Jenkins Pipeline

#### Step 1: Create Shared Library Structure

```bash
# Create shared library
mkdir -p jenkins/shared-libraries/vars
cd jenkins/shared-libraries

# Initialize as git repository (required for Jenkins)
git init
git add .
git commit -m "Initial shared library"
```

#### Step 2: Implement Shared Library Functions

```groovy
// jenkins/shared-libraries/vars/buildUtils.groovy
def checkoutCode() {
    echo "📥 Checking out code..."
    checkout scm
    
    // Get commit info
    env.GIT_COMMIT_SHORT = sh(
        script: "git rev-parse --short HEAD",
        returnStdout: true
    ).trim()
    
    env.GIT_COMMIT_MESSAGE = sh(
        script: "git log -1 --pretty=%B",
        returnStdout: true
    ).trim()
    
    echo "Commit: ${env.GIT_COMMIT_SHORT}"
    echo "Message: ${env.GIT_COMMIT_MESSAGE}"
}

def buildApplication() {
    echo "🔨 Building application..."
    
    sh '''
        # Install dependencies
        npm ci --legacy-peer-deps
        
        # Run linting
        npm run lint
        
        # Build application
        npm run build:production
        
        # Generate build info
        echo "{
            \\"buildNumber\\": \\"${BUILD_NUMBER}\\",
            \\"commit\\": \\"${GIT_COMMIT}\\",
            \\"branch\\": \\"${BRANCH_NAME}\\",
            \\"timestamp\\": \\"$(date -Iseconds)\\"
        }" > dist/build-info.json
    '''
}

def validateEnvironment() {
    echo "🔍 Validating environment..."
    
    // Check required tools
    def requiredCommands = ['node', 'npm', 'docker', 'git']
    
    requiredCommands.each { cmd ->
        def result = sh(
            script: "which ${cmd}",
            returnStatus: true
        )
        if (result != 0) {
            error "Required command '${cmd}' not found!"
        }
    }
    
    // Check Node version
    def nodeVersion = sh(
        script: "node --version",
        returnStdout: true
    ).trim()
    
    if (!nodeVersion.startsWith('v18') && !nodeVersion.startsWith('v20')) {
        error "Node.js version must be 18 or 20, found: ${nodeVersion}"
    }
    
    echo "✅ Environment validation passed"
}
```

```groovy
// jenkins/shared-libraries/vars/securityUtils.groovy
def scanForSecrets() {
    echo "🔍 Scanning for secrets with TruffleHog..."
    
    sh '''
        # Run TruffleHog scan
        docker run --rm -v $(pwd):/repo \
            trufflesecurity/trufflehog:latest \
            git file:///repo --json > reports/secrets-scan.json
        
        # Check for verified secrets
        if [ $(jq '.[] | select(.verified==true)' reports/secrets-scan.json | wc -l) -gt 0 ]; then
            echo "❌ CRITICAL: Verified secrets found in code!"
            jq '.[] | select(.verified==true)' reports/secrets-scan.json
            exit 1
        fi
        
        echo "✅ No verified secrets found"
    '''
}

def runSonarQube() {
    echo "📊 Running SonarQube analysis..."
    
    withSonarQubeEnv('SonarQube') {
        sh '''
            sonar-scanner \
                -Dsonar.projectKey=secdevops-oversight \
                -Dsonar.projectName="SecDevOps Oversight MVP" \
                -Dsonar.sources=src \
                -Dsonar.tests=tests \
                -Dsonar.exclusions=node_modules/**,coverage/**,dist/** \
                -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \
                -Dsonar.testExecutionReportPaths=reports/test-report.xml
        '''
    }
}

def runSnyk() {
    echo "🛡️ Running Snyk security scan..."
    
    sh '''
        # Authenticate Snyk
        snyk auth ${SNYK_TOKEN}
        
        # Test for vulnerabilities
        snyk test --severity-threshold=high --json > reports/snyk-report.json || true
        
        # Monitor project
        snyk monitor --project-name="SecDevOps-${BRANCH_NAME}"
        
        # Parse results
        node scripts/security/parse-snyk-results.js
    '''
}

def runTrivy() {
    echo "🐳 Scanning container with Trivy..."
    
    sh '''
        # Update Trivy database
        trivy image --download-db-only
        
        # Scan image
        trivy image \
            --severity HIGH,CRITICAL \
            --format json \
            --output reports/trivy-report.json \
            ${BUILD_IMAGE}
        
        # Generate HTML report
        trivy image \
            --severity HIGH,CRITICAL \
            --format template \
            --template "@contrib/html.tpl" \
            --output reports/trivy-report.html \
            ${BUILD_IMAGE}
    '''
}
```

#### Step 3: Main Jenkinsfile

```groovy
// jenkins/Jenkinsfile
@Library('secdevops-pipeline-library') _

pipeline {
    agent any
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 2, unit: 'HOURS')
        timestamps()
        ansiColor('xterm')
    }
    
    environment {
        // Azure Configuration
        AZURE_SUBSCRIPTION_ID = credentials('azure-subscription-id')
        AZURE_RESOURCE_GROUP = 'rg-secdevops-cicd-dev'
        ACR_REGISTRY = 'acrsecdevopsdev.azurecr.io'
        
        // Tool Tokens
        GITHUB_TOKEN = credentials('github-token')
        SONARQUBE_TOKEN = credentials('sonarqube-token')
        SNYK_TOKEN = credentials('snyk-token')
        
        // Build Configuration
        BUILD_IMAGE = "${ACR_REGISTRY}/oversight:${BUILD_NUMBER}"
        NODE_ENV = 'production'
    }
    
    stages {
        stage('Initialize') {
            steps {
                script {
                    buildUtils.validateEnvironment()
                    buildUtils.checkoutCode()
                }
            }
        }
        
        stage('Security Pre-Checks') {
            parallel {
                stage('Secret Scan') {
                    steps {
                        script {
                            securityUtils.scanForSecrets()
                        }
                    }
                }
                
                stage('License Check') {
                    steps {
                        sh 'npm run license-check'
                    }
                }
            }
        }
        
        stage('Build & Test') {
            stages {
                stage('Build') {
                    steps {
                        script {
                            buildUtils.buildApplication()
                        }
                    }
                }
                
                stage('Unit Tests') {
                    steps {
                        script {
                            testUtils.runUnitTests()
                        }
                    }
                }
            }
        }
        
        stage('Security Analysis') {
            parallel {
                stage('SAST - SonarQube') {
                    steps {
                        script {
                            securityUtils.runSonarQube()
                        }
                    }
                }
                
                stage('SCA - Snyk') {
                    steps {
                        script {
                            securityUtils.runSnyk()
                        }
                    }
                }
                
                stage('SAST - Semgrep') {
                    steps {
                        sh '''
                            semgrep --config=auto \
                                   --json \
                                   --output reports/semgrep-report.json
                        '''
                    }
                }
            }
        }
        
        stage('Container Build') {
            steps {
                script {
                    containerUtils.buildImage()
                }
            }
        }
        
        stage('Container Security') {
            steps {
                script {
                    securityUtils.runTrivy()
                }
            }
        }
        
        stage('Quality Gates') {
            steps {
                script {
                    qualityGates.evaluate()
                }
            }
        }
        
        stage('Deploy to Test') {
            when {
                anyOf {
                    branch 'develop'
                    branch 'main'
                }
            }
            steps {
                script {
                    deployUtils.deployToTest()
                }
            }
        }
        
        stage('Integration Tests') {
            when {
                anyOf {
                    branch 'develop'
                    branch 'main'
                }
            }
            steps {
                script {
                    testUtils.runIntegrationTests()
                }
            }
        }
    }
    
    post {
        always {
            script {
                reportUtils.generateReports()
                archiveArtifacts artifacts: 'reports/**/*', allowEmptyArchive: true
            }
        }
        
        success {
            script {
                notificationUtils.sendSuccess()
            }
        }
        
        failure {
            script {
                notificationUtils.sendFailure()
                claudeIntegration.createFixPrompt()
            }
        }
        
        cleanup {
            cleanWs()
        }
    }
}
```

---

## 🧪 Testing Your Implementation

### Run Unit Tests
```bash
# Test Jenkins installation
pytest tests/sprint2/unit/test_jenkins_config.py -v

# Test pipeline stages
pytest tests/sprint2/unit/test_pipeline_stages.py -v

# Test security tools
pytest tests/sprint2/unit/test_security_tools.py -v
```

### Run Integration Tests
```bash
# Full pipeline test
pytest tests/sprint2/integration/test_jenkins_pipeline.py -v

# Security scanning test
pytest tests/sprint2/integration/test_security_scanning.py -v
```

### Manual Validation
```bash
# Check Jenkins status
systemctl status jenkins

# Check Jenkins logs
tail -f /var/log/jenkins/jenkins.log

# Test pipeline execution
curl -X POST http://localhost:8080/job/test-pipeline/build

# Check monitoring
curl http://localhost:9090/metrics  # Prometheus
curl http://localhost:3000           # Grafana
```

---

## 📊 Success Criteria

### Each Story Must Have:
- [ ] All tests written first (TDD)
- [ ] Tests passing (>95% coverage)
- [ ] Security scans clean
- [ ] Documentation complete
- [ ] Code reviewed
- [ ] Deployed and validated

### Sprint Completion Requires:
- [ ] Jenkins fully operational
- [ ] Pipeline executing successfully
- [ ] All security tools integrated
- [ ] Quality gates enforcing standards
- [ ] Monitoring active with alerts
- [ ] Dashboards showing metrics
- [ ] Documentation complete
- [ ] Demo ready

---

## 🚨 Common Issues and Solutions

### Issue: Jenkins won't start
```bash
# Check Java version
java -version  # Should be 17

# Check Jenkins logs
sudo journalctl -u jenkins -n 100

# Check permissions
ls -la /var/lib/jenkins
```

### Issue: Pipeline fails on security scan
```bash
# Check tool installation
snyk --version
trivy --version
sonar-scanner --version

# Validate credentials
echo $SNYK_TOKEN
echo $SONARQUBE_TOKEN
```

### Issue: Quality gates too strict
```javascript
// Adjust thresholds in quality-gate-evaluator.js
thresholds: {
    security: {
        critical: 0,  // Keep at 0
        high: 10,     // Adjust as needed
        medium: 50    // Adjust as needed
    }
}
```

---

## 📈 Sprint Progress Tracking

Update daily in `docs/progress/sprint-02-progress.md`:

```markdown
## Sprint 2 - Day X

### Completed Today
- ✅ Jenkins installation script
- ✅ SSL configuration
- ✅ Plugin installation

### In Progress
- 🔄 Pipeline development (60%)
- 🔄 Security tool integration (40%)

### Blockers
- None / [Describe]

### Tomorrow's Plan
- Complete pipeline stages
- Test security scanning
```

---

## 🎯 Definition of Done Checklist

Before marking any story complete:

- [ ] All acceptance criteria met
- [ ] Tests written and passing
- [ ] Security scan clean
- [ ] Code reviewed and approved
- [ ] Documentation updated
- [ ] Deployed to environment
- [ ] Validated by running tests
- [ ] No technical debt introduced
- [ ] Monitoring/alerts configured
- [ ] Runbook updated

---

## 🚀 Get Started Now!

```bash
# Start with the first story
cd ~/SecDevOps_CICD
git checkout -b feature/STORY-003-01-jenkins-install

# Write your first test
vim tests/sprint2/unit/test_jenkins_config.py

# Run test (should fail - RED phase)
pytest tests/sprint2/unit/test_jenkins_config.py

# Implement feature
vim scripts/jenkins/install-jenkins.sh

# Run test again (should pass - GREEN phase)
pytest tests/sprint2/unit/test_jenkins_config.py

# Refactor and commit
git add .
git commit -m "feat(STORY-003-01): implement Jenkins installation with tests"
```

---

**YOU ARE NOW READY TO IMPLEMENT SPRINT 2**

Remember: TDD First, Security Always, Document Everything!

Good luck! 🚀