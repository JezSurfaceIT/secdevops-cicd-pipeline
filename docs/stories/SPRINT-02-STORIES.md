# Sprint 2 Stories - Jenkins Setup and Basic Pipeline
**Sprint Duration:** 2 weeks  
**Sprint Goal:** Install Jenkins, configure basic CI/CD pipeline with security tools  
**Total Story Points:** 42

---

## STORY-003-01: Install and Configure Jenkins Master

**Story ID:** STORY-003-01  
**Epic:** EPIC-003 (CI/CD Pipeline Implementation)  
**Points:** 8  
**Priority:** P0  
**Assignee:** DevOps Engineer  

### User Story
**As a** DevOps Engineer  
**I want to** install and configure Jenkins on Azure VM  
**So that** we have a CI/CD orchestration platform ready for pipeline execution

### Acceptance Criteria
- [ ] Jenkins LTS installed on Azure VM
- [ ] SSL/TLS configured with valid certificates
- [ ] Jenkins plugins installed (Blue Ocean, Pipeline, Docker, Azure)
- [ ] Authentication configured (local + Azure AD preparation)
- [ ] Backup strategy implemented
- [ ] Jenkins home directory on separate data disk
- [ ] System monitoring configured
- [ ] Jenkins accessible via HTTPS

### Technical Implementation

```bash
#!/bin/bash
# scripts/setup/install-jenkins.sh

set -e

echo "🔧 Installing Jenkins on Azure VM..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install Java 17 (required for Jenkins)
sudo apt install -y openjdk-17-jdk openjdk-17-jre

# Add Jenkins repository
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo apt-key add -
sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

# Install Jenkins
sudo apt update
sudo apt install -y jenkins

# Configure Jenkins to use Java 17
sudo systemctl stop jenkins
sudo sed -i 's/^JAVA_ARGS=.*/JAVA_ARGS="-Djava.awt.headless=true -Xmx2g -XX:+UseG1GC"/' /etc/default/jenkins

# Setup data disk for Jenkins home
sudo mkdir -p /mnt/jenkins
# Assuming data disk is /dev/sdc
sudo mkfs -t ext4 /dev/sdc
sudo mount /dev/sdc /mnt/jenkins
echo "/dev/sdc /mnt/jenkins ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# Move Jenkins home to data disk
sudo systemctl stop jenkins
sudo mv /var/lib/jenkins /mnt/jenkins/
sudo ln -s /mnt/jenkins/jenkins /var/lib/jenkins
sudo chown -R jenkins:jenkins /mnt/jenkins/jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

echo "✅ Jenkins installation complete"
```

### Plugin Installation Script
```groovy
// scripts/jenkins/install-plugins.groovy
import jenkins.model.*
import java.util.logging.Logger

def logger = Logger.getLogger("")
def installed = false
def initialized = false

def pluginList = [
    "ace-editor",
    "ant",
    "antisamy-markup-formatter",
    "apache-httpcomponents-client-4-api",
    "authentication-tokens",
    "azure-credentials",
    "azure-container-agents",
    "blueocean",
    "bootstrap5-api",
    "bouncycastle-api",
    "branch-api",
    "build-timeout",
    "caffeine-api",
    "checks-api",
    "cloudbees-folder",
    "command-launcher",
    "credentials",
    "credentials-binding",
    "display-url-api",
    "docker-commons",
    "docker-workflow",
    "durable-task",
    "echarts-api",
    "email-ext",
    "font-awesome-api",
    "git",
    "git-client",
    "git-server",
    "github",
    "github-api",
    "github-branch-source",
    "gradle",
    "handlebars",
    "jackson2-api",
    "jakarta-activation-api",
    "jakarta-mail-api",
    "javax-activation-api",
    "javax-mail-api",
    "jaxb",
    "jdk-tool",
    "jjwt-api",
    "jquery3-api",
    "jsch",
    "junit",
    "ldap",
    "lockable-resources",
    "mailer",
    "matrix-auth",
    "matrix-project",
    "mina-sshd-api-common",
    "mina-sshd-api-core",
    "momentjs",
    "okhttp-api",
    "pam-auth",
    "pipeline-build-step",
    "pipeline-github-lib",
    "pipeline-graph-analysis",
    "pipeline-input-step",
    "pipeline-milestone-step",
    "pipeline-model-api",
    "pipeline-model-definition",
    "pipeline-model-extensions",
    "pipeline-rest-api",
    "pipeline-stage-step",
    "pipeline-stage-tags-metadata",
    "pipeline-stage-view",
    "plain-credentials",
    "plugin-util-api",
    "popper2-api",
    "resource-disposer",
    "scm-api",
    "script-security",
    "snakeyaml-api",
    "sonar",
    "ssh-credentials",
    "ssh-slaves",
    "sshd",
    "structs",
    "timestamper",
    "token-macro",
    "trilead-api",
    "variant",
    "workflow-aggregator",
    "workflow-api",
    "workflow-basic-steps",
    "workflow-cps",
    "workflow-durable-task-step",
    "workflow-job",
    "workflow-multibranch",
    "workflow-scm-step",
    "workflow-step-api",
    "workflow-support",
    "ws-cleanup"
]

def instance = Jenkins.getInstance()
def pm = instance.getPluginManager()
def uc = instance.getUpdateCenter()

pluginList.each { pluginName ->
    if (!pm.getPlugin(pluginName)) {
        logger.info("Installing plugin: ${pluginName}")
        def plugin = uc.getPlugin(pluginName)
        if (plugin) {
            plugin.deploy()
            installed = true
        }
    }
}

if (installed) {
    instance.save()
    instance.restart()
}
```

### SSL/TLS Configuration
```bash
#!/bin/bash
# scripts/setup/configure-jenkins-ssl.sh

# Generate self-signed certificate (for testing)
sudo mkdir -p /etc/jenkins/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/jenkins/ssl/jenkins.key \
    -out /etc/jenkins/ssl/jenkins.crt \
    -subj "/C=GB/ST=London/L=London/O=Oversight/CN=jenkins.oversight.local"

# Configure Nginx as reverse proxy
sudo apt install -y nginx

cat <<EOF | sudo tee /etc/nginx/sites-available/jenkins
upstream jenkins {
    server 127.0.0.1:8080 fail_timeout=0;
}

server {
    listen 80;
    server_name jenkins.oversight.local;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name jenkins.oversight.local;

    ssl_certificate /etc/jenkins/ssl/jenkins.crt;
    ssl_certificate_key /etc/jenkins/ssl/jenkins.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_set_header Host \$host:\$server_port;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect http:// https://;
        proxy_pass http://jenkins;
        proxy_read_timeout 90;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx
```

### Testing
```python
# tests/unit/test_jenkins_config.py
import pytest
import requests
from unittest.mock import patch, MagicMock

class TestJenkinsConfiguration:
    def test_jenkins_service_running(self):
        """Test Jenkins service is running"""
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout='active')
            result = subprocess.run(['systemctl', 'is-active', 'jenkins'])
            assert result.returncode == 0
    
    def test_jenkins_https_accessible(self):
        """Test Jenkins is accessible via HTTPS"""
        response = requests.get('https://jenkins.oversight.local', verify=False)
        assert response.status_code == 200
    
    def test_required_plugins_installed(self):
        """Test all required plugins are installed"""
        required_plugins = ['git', 'docker-workflow', 'azure-credentials', 'pipeline']
        # Implementation to check plugins via Jenkins API
        pass
    
    def test_jenkins_backup_configured(self):
        """Test backup configuration exists"""
        assert os.path.exists('/etc/cron.d/jenkins-backup')
```

### Definition of Done
- [ ] Jenkins service running and accessible
- [ ] HTTPS configured and working
- [ ] All required plugins installed
- [ ] Admin user created and secured
- [ ] Backup script scheduled
- [ ] Monitoring configured
- [ ] Documentation updated

---

## STORY-003-02: Create Base Jenkins Pipeline

**Story ID:** STORY-003-02  
**Epic:** EPIC-003 (CI/CD Pipeline Implementation)  
**Points:** 13  
**Priority:** P0  
**Assignee:** DevOps Engineer  

### User Story
**As a** DevOps Engineer  
**I want to** create the base Jenkins pipeline with all stages  
**So that** we have a complete CI/CD workflow structure

### Acceptance Criteria
- [ ] Jenkinsfile created with all pipeline stages
- [ ] Pipeline as Code in repository
- [ ] Parallel execution for security scans
- [ ] Error handling and retry logic
- [ ] Notification system configured
- [ ] Quality gates implemented
- [ ] Pipeline library created for shared functions

### Technical Implementation

```groovy
// Jenkinsfile
@Library('secdevops-pipeline-library') _

pipeline {
    agent any
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 2, unit: 'HOURS')
        timestamps()
        parallelsAlwaysFailFast()
        skipDefaultCheckout()
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
        BUILD_IMAGE = "${ACR_REGISTRY}/oversight-app:${BUILD_NUMBER}"
        NODE_ENV = "${BRANCH_NAME == 'main' ? 'production' : 'development'}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    buildUtils.checkoutCode()
                }
            }
        }
        
        stage('Pre-Flight Checks') {
            parallel {
                stage('Validate Environment') {
                    steps {
                        script {
                            validationUtils.validateEnvironment()
                        }
                    }
                }
                
                stage('Secret Scanning') {
                    steps {
                        script {
                            securityUtils.scanForSecrets()
                        }
                    }
                }
                
                stage('License Check') {
                    steps {
                        script {
                            complianceUtils.checkLicenses()
                        }
                    }
                }
            }
        }
        
        stage('Build & Test') {
            parallel {
                stage('Application Build') {
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
                        script {
                            securityUtils.runSemgrep()
                        }
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
            parallel {
                stage('Trivy Scan') {
                    steps {
                        script {
                            containerUtils.scanWithTrivy()
                        }
                    }
                }
                
                stage('Anchore Scan') {
                    steps {
                        script {
                            containerUtils.scanWithAnchore()
                        }
                    }
                }
            }
        }
        
        stage('Deploy to Test') {
            when {
                branch pattern: "^(develop|main|release/.*)$", comparator: "REGEXP"
            }
            steps {
                script {
                    deployUtils.deployToTest()
                }
            }
        }
        
        stage('Integration Tests') {
            when {
                branch pattern: "^(develop|main|release/.*)$", comparator: "REGEXP"
            }
            parallel {
                stage('API Tests') {
                    steps {
                        script {
                            testUtils.runAPITests()
                        }
                    }
                }
                
                stage('E2E Tests') {
                    steps {
                        script {
                            testUtils.runE2ETests()
                        }
                    }
                }
                
                stage('Performance Tests') {
                    steps {
                        script {
                            testUtils.runPerformanceTests()
                        }
                    }
                }
            }
        }
        
        stage('DAST Security') {
            when {
                branch pattern: "^(develop|main|release/.*)$", comparator: "REGEXP"
            }
            steps {
                script {
                    securityUtils.runDAST()
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
        
        stage('Promote to Production') {
            when {
                branch 'main'
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                script {
                    deployUtils.promoteToProduction()
                }
            }
        }
    }
    
    post {
        always {
            script {
                reportUtils.generateReports()
                notificationUtils.sendNotifications(currentBuild.result)
            }
        }
        
        success {
            script {
                metricsUtils.recordSuccess()
            }
        }
        
        failure {
            script {
                incidentUtils.createIncident()
                claudeIntegration.generateFixPrompt()
            }
        }
        
        cleanup {
            cleanWs()
        }
    }
}
```

### Pipeline Library Functions
```groovy
// vars/securityUtils.groovy
def scanForSecrets() {
    echo "🔍 Scanning for secrets..."
    sh '''
        trufflehog git file://. --json > reports/secrets-scan.json
        if [ $(jq '.[] | select(.verified==true)' reports/secrets-scan.json | wc -l) -gt 0 ]; then
            echo "❌ Verified secrets found!"
            exit 1
        fi
    '''
}

def runSonarQube() {
    echo "📊 Running SonarQube analysis..."
    withSonarQubeEnv('SonarQube') {
        sh '''
            sonar-scanner \
                -Dsonar.projectKey=oversight-mvp \
                -Dsonar.sources=src \
                -Dsonar.exclusions=node_modules/**,coverage/** \
                -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
        '''
    }
}

def runSnyk() {
    echo "🛡️ Running Snyk security scan..."
    sh '''
        snyk test --severity-threshold=high --json > reports/snyk-report.json || true
        snyk monitor
    '''
}

def runSemgrep() {
    echo "🔍 Running Semgrep SAST..."
    sh '''
        semgrep --config=auto --json -o reports/semgrep-report.json || true
    '''
}

def runDAST() {
    echo "🔒 Running OWASP ZAP scan..."
    sh '''
        docker run --rm -v $(pwd)/reports:/zap/wrk/:rw \
            owasp/zap2docker-stable zap-full-scan.py \
            -t https://${TEST_URL} \
            -r zap-report.html \
            -J zap-report.json || true
    '''
}
```

### Definition of Done
- [ ] Pipeline executes successfully
- [ ] All stages working correctly
- [ ] Parallel execution verified
- [ ] Error handling tested
- [ ] Notifications working
- [ ] Documentation complete

---

## STORY-006-01: Integrate Security Scanning Tools

**Story ID:** STORY-006-01  
**Epic:** EPIC-006 (Security Implementation)  
**Points:** 8  
**Priority:** P0  
**Assignee:** Security Engineer  

### User Story
**As a** Security Engineer  
**I want to** integrate all security scanning tools into the pipeline  
**So that** vulnerabilities are detected automatically

### Acceptance Criteria
- [ ] SonarQube server installed and configured
- [ ] Snyk integrated with API token
- [ ] Trivy installed and configured
- [ ] OWASP ZAP configured for DAST
- [ ] TruffleHog integrated for secret scanning
- [ ] Semgrep configured with rulesets
- [ ] All tools reporting to central dashboard

### Technical Implementation

```bash
#!/bin/bash
# scripts/setup/install-security-tools.sh

set -e

echo "🛡️ Installing Security Tools..."

# Install SonarQube using Docker
docker run -d --name sonarqube \
    -p 9000:9000 \
    -v sonarqube_data:/opt/sonarqube/data \
    -v sonarqube_extensions:/opt/sonarqube/extensions \
    -v sonarqube_logs:/opt/sonarqube/logs \
    sonarqube:lts-community

# Install Snyk CLI
npm install -g snyk
snyk auth ${SNYK_TOKEN}

# Install Trivy
wget https://github.com/aquasecurity/trivy/releases/latest/download/trivy_Linux-64bit.tar.gz
tar zxvf trivy_Linux-64bit.tar.gz
sudo mv trivy /usr/local/bin/
rm trivy_Linux-64bit.tar.gz

# Install TruffleHog
pip install truffleHog3

# Install Semgrep
pip install semgrep

# Install OWASP ZAP
docker pull owasp/zap2docker-stable

# Install Anchore
pip install anchorecli
docker-compose -f anchore-compose.yaml up -d

echo "✅ Security tools installation complete"
```

### SonarQube Configuration
```groovy
// scripts/jenkins/configure-sonarqube.groovy
import jenkins.model.*
import hudson.plugins.sonar.*
import hudson.plugins.sonar.model.*

def instance = Jenkins.getInstance()

// Configure SonarQube server
def sonarDesc = instance.getDescriptor("hudson.plugins.sonar.SonarGlobalConfiguration")
def sonarInst = new SonarInstallation(
    "SonarQube",                          // Name
    "http://localhost:9000",              // Server URL
    "sonarqube-token",                    // Token
    "",                                    // Database URL
    "",                                    // Database Login
    "",                                    // Database Password
    "",                                    // Additional Properties
    new TriggersConfig(),                 // Triggers
    ""                                     // Additional Analysis Properties
)

sonarDesc.setInstallations(sonarInst)
sonarDesc.save()
instance.save()
```

### Security Tool Integration Tests
```python
# tests/integration/test_security_tools.py
import pytest
import requests
import subprocess
import json

class TestSecurityToolsIntegration:
    def test_sonarqube_accessible(self):
        """Test SonarQube server is running"""
        response = requests.get('http://localhost:9000/api/system/status')
        assert response.status_code == 200
        assert response.json()['status'] == 'UP'
    
    def test_snyk_authentication(self):
        """Test Snyk CLI is authenticated"""
        result = subprocess.run(['snyk', 'auth'], capture_output=True, text=True)
        assert 'Authenticated' in result.stdout
    
    def test_trivy_installation(self):
        """Test Trivy is installed and working"""
        result = subprocess.run(['trivy', '--version'], capture_output=True, text=True)
        assert 'Version' in result.stdout
    
    def test_trufflehog_scan(self):
        """Test TruffleHog can scan repository"""
        result = subprocess.run(
            ['trufflehog', 'git', 'file://.', '--json'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
    
    def test_semgrep_rules(self):
        """Test Semgrep has rules configured"""
        result = subprocess.run(
            ['semgrep', '--config=auto', '--validate'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
```

### Definition of Done
- [ ] All security tools installed
- [ ] Tools integrated with Jenkins
- [ ] Test scans successful
- [ ] Reports generated correctly
- [ ] Dashboard configured
- [ ] Documentation updated

---

## STORY-003-03: Implement Quality Gates

**Story ID:** STORY-003-03  
**Epic:** EPIC-003 (CI/CD Pipeline Implementation)  
**Points:** 5  
**Priority:** P0  
**Assignee:** DevOps Engineer  

### User Story
**As a** DevOps Engineer  
**I want to** implement quality gates in the pipeline  
**So that** builds fail when quality thresholds are not met

### Acceptance Criteria
- [ ] Quality gate thresholds defined
- [ ] SonarQube quality gate configured
- [ ] Security vulnerability thresholds set
- [ ] Test coverage requirements enforced
- [ ] Performance benchmarks established
- [ ] Automatic build failure on gate violation
- [ ] Override mechanism for emergencies

### Technical Implementation

```javascript
// scripts/quality-gates/quality-gate-evaluator.js
const fs = require('fs');
const path = require('path');

class QualityGateEvaluator {
    constructor() {
        this.thresholds = {
            security: {
                critical: 0,
                high: 5,
                medium: 20,
                low: 100
            },
            coverage: {
                overall: 80,
                newCode: 90
            },
            codeQuality: {
                bugs: 5,
                vulnerabilities: 0,
                codeSmells: 50,
                duplications: 5
            },
            performance: {
                p95ResponseTime: 500,  // ms
                errorRate: 1           // percentage
            }
        };
    }

    async evaluateSecurityGate(reports) {
        const results = {
            passed: true,
            violations: [],
            summary: {}
        };

        // Parse security reports
        const snykReport = JSON.parse(fs.readFileSync(reports.snyk));
        const trivyReport = JSON.parse(fs.readFileSync(reports.trivy));
        const sonarReport = JSON.parse(fs.readFileSync(reports.sonar));

        // Count vulnerabilities by severity
        const vulnCounts = {
            critical: 0,
            high: 0,
            medium: 0,
            low: 0
        };

        // Process Snyk vulnerabilities
        snykReport.vulnerabilities?.forEach(vuln => {
            vulnCounts[vuln.severity.toLowerCase()]++;
        });

        // Check against thresholds
        Object.keys(vulnCounts).forEach(severity => {
            if (vulnCounts[severity] > this.thresholds.security[severity]) {
                results.passed = false;
                results.violations.push({
                    type: 'security',
                    severity,
                    count: vulnCounts[severity],
                    threshold: this.thresholds.security[severity]
                });
            }
        });

        results.summary = vulnCounts;
        return results;
    }

    async evaluateCoverageGate(coverageReport) {
        const results = {
            passed: true,
            violations: [],
            coverage: {}
        };

        const coverage = JSON.parse(fs.readFileSync(coverageReport));
        
        if (coverage.total.lines.pct < this.thresholds.coverage.overall) {
            results.passed = false;
            results.violations.push({
                type: 'coverage',
                metric: 'overall',
                value: coverage.total.lines.pct,
                threshold: this.thresholds.coverage.overall
            });
        }

        results.coverage = {
            lines: coverage.total.lines.pct,
            branches: coverage.total.branches.pct,
            functions: coverage.total.functions.pct,
            statements: coverage.total.statements.pct
        };

        return results;
    }

    async evaluatePerformanceGate(performanceReport) {
        const results = {
            passed: true,
            violations: [],
            metrics: {}
        };

        const perfData = JSON.parse(fs.readFileSync(performanceReport));
        
        if (perfData.p95 > this.thresholds.performance.p95ResponseTime) {
            results.passed = false;
            results.violations.push({
                type: 'performance',
                metric: 'p95ResponseTime',
                value: perfData.p95,
                threshold: this.thresholds.performance.p95ResponseTime
            });
        }

        if (perfData.errorRate > this.thresholds.performance.errorRate) {
            results.passed = false;
            results.violations.push({
                type: 'performance',
                metric: 'errorRate',
                value: perfData.errorRate,
                threshold: this.thresholds.performance.errorRate
            });
        }

        results.metrics = perfData;
        return results;
    }

    async evaluateAll(reports) {
        const results = {
            passed: true,
            gates: {}
        };

        // Evaluate each gate
        results.gates.security = await this.evaluateSecurityGate(reports);
        results.gates.coverage = await this.evaluateCoverageGate(reports.coverage);
        results.gates.performance = await this.evaluatePerformanceGate(reports.performance);

        // Overall pass/fail
        results.passed = Object.values(results.gates).every(gate => gate.passed);

        // Generate report
        this.generateReport(results);

        return results;
    }

    generateReport(results) {
        const report = {
            timestamp: new Date().toISOString(),
            buildNumber: process.env.BUILD_NUMBER,
            branch: process.env.BRANCH_NAME,
            passed: results.passed,
            gates: results.gates
        };

        fs.writeFileSync(
            'reports/quality-gate-report.json',
            JSON.stringify(report, null, 2)
        );

        // Console output for Jenkins
        console.log('\n' + '='.repeat(50));
        console.log('QUALITY GATE EVALUATION');
        console.log('='.repeat(50));
        console.log(`Overall Status: ${results.passed ? '✅ PASSED' : '❌ FAILED'}`);
        
        Object.entries(results.gates).forEach(([gateName, gate]) => {
            console.log(`\n${gateName.toUpperCase()}: ${gate.passed ? '✅' : '❌'}`);
            if (!gate.passed) {
                gate.violations.forEach(violation => {
                    console.log(`  - ${violation.metric}: ${violation.value} (threshold: ${violation.threshold})`);
                });
            }
        });

        if (!results.passed) {
            process.exit(1);
        }
    }
}

// Execute if run directly
if (require.main === module) {
    const evaluator = new QualityGateEvaluator();
    const reports = {
        snyk: 'reports/snyk-report.json',
        trivy: 'reports/trivy-report.json',
        sonar: 'reports/sonar-report.json',
        coverage: 'coverage/coverage-final.json',
        performance: 'reports/performance-report.json'
    };
    
    evaluator.evaluateAll(reports).catch(error => {
        console.error('Quality gate evaluation failed:', error);
        process.exit(1);
    });
}

module.exports = QualityGateEvaluator;
```

### Jenkins Integration
```groovy
// vars/qualityGates.groovy
def evaluate() {
    echo "🎯 Evaluating Quality Gates..."
    
    try {
        // Wait for SonarQube analysis
        timeout(time: 1, unit: 'HOURS') {
            def qg = waitForQualityGate()
            if (qg.status != 'OK') {
                error "SonarQube quality gate failed: ${qg.status}"
            }
        }
        
        // Run custom quality gate evaluation
        sh 'node scripts/quality-gates/quality-gate-evaluator.js'
        
        // Archive quality gate report
        archiveArtifacts artifacts: 'reports/quality-gate-report.json'
        
    } catch (Exception e) {
        // Check for override
        if (env.OVERRIDE_QUALITY_GATES == 'true') {
            echo "⚠️ Quality gates failed but override is enabled"
            currentBuild.result = 'UNSTABLE'
        } else {
            error "Quality gates failed: ${e.message}"
        }
    }
}
```

### Definition of Done
- [ ] Quality gate thresholds configured
- [ ] Evaluation script working
- [ ] Jenkins integration complete
- [ ] Override mechanism tested
- [ ] Reports generated
- [ ] Documentation updated

---

## STORY-003-04: Configure Monitoring and Alerting

**Story ID:** STORY-003-04  
**Epic:** EPIC-008 (Monitoring & Observability)  
**Points:** 8  
**Priority:** P1  
**Assignee:** DevOps Engineer  

### User Story
**As a** Operations Engineer  
**I want to** have monitoring and alerting configured  
**So that** we are notified of pipeline issues immediately

### Acceptance Criteria
- [ ] Jenkins metrics exported to Prometheus
- [ ] Grafana dashboards created
- [ ] Alert rules configured
- [ ] Email notifications setup
- [ ] Slack integration configured
- [ ] Pipeline performance metrics tracked
- [ ] Security metrics dashboard

### Technical Implementation

```yaml
# docker-compose.monitoring.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    ports:
      - "3000:3000"
    restart: unless-stopped

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    volumes:
      - ./monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager
    ports:
      - "9093:9093"
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:
```

### Prometheus Configuration
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

rule_files:
  - 'alert_rules.yml'

scrape_configs:
  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['jenkins:8080']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']
```

### Alert Rules
```yaml
# monitoring/alert_rules.yml
groups:
  - name: jenkins_alerts
    interval: 30s
    rules:
      - alert: JenkinsBuildFailure
        expr: jenkins_build_failed > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Jenkins build failure detected"
          description: "Build {{ $labels.job }} has failed"

      - alert: HighSecurityVulnerabilities
        expr: security_vulnerabilities_critical > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Critical security vulnerabilities detected"
          description: "{{ $value }} critical vulnerabilities found"

      - alert: LowTestCoverage
        expr: test_coverage_percentage < 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Test coverage below threshold"
          description: "Test coverage is {{ $value }}%, threshold is 80%"

      - alert: PipelineDurationHigh
        expr: jenkins_pipeline_duration_seconds > 3600
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pipeline taking too long"
          description: "Pipeline {{ $labels.job }} has been running for more than 1 hour"
```

### Notification Configuration
```groovy
// vars/notificationUtils.groovy
def sendNotifications(buildStatus) {
    def color = 'danger'
    def emoji = '❌'
    
    if (buildStatus == 'SUCCESS') {
        color = 'good'
        emoji = '✅'
    } else if (buildStatus == 'UNSTABLE') {
        color = 'warning'
        emoji = '⚠️'
    }
    
    def message = """
    ${emoji} *Build ${env.BUILD_NUMBER}* - ${buildStatus}
    *Project:* ${env.JOB_NAME}
    *Branch:* ${env.BRANCH_NAME}
    *Duration:* ${currentBuild.durationString}
    *URL:* ${env.BUILD_URL}
    """
    
    // Send to Slack
    if (env.SLACK_WEBHOOK_URL) {
        slackSend(
            channel: '#ci-cd-notifications',
            color: color,
            message: message
        )
    }
    
    // Send email
    emailext(
        subject: "${emoji} Build ${env.BUILD_NUMBER} - ${buildStatus}",
        body: message,
        to: 'devops-team@oversight.com',
        attachmentsPattern: 'reports/**/*.html'
    )
}
```

### Definition of Done
- [ ] Monitoring stack deployed
- [ ] Dashboards configured
- [ ] Alert rules active
- [ ] Notifications working
- [ ] Metrics being collected
- [ ] Documentation complete

---

## Sprint 2 Summary

### Deliverables Checklist
- [ ] Jenkins fully installed and configured
- [ ] Base pipeline operational
- [ ] All security tools integrated
- [ ] Quality gates implemented
- [ ] Monitoring and alerting active
- [ ] Documentation complete
- [ ] Tests passing

### Sprint Metrics
- **Total Points:** 42
- **Stories:** 5
- **Priority:** All P0/P1

### Next Sprint Preview
Sprint 3 will focus on:
- Container strategy implementation
- Database migration framework
- Claude Code integration
- Advanced testing scenarios

---

**Sprint 2 Ready for Implementation**  
**Estimated Duration:** 2 weeks  
**Dependencies:** Sprint 1 infrastructure must be complete