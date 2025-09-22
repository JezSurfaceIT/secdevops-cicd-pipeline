# GitOps Deployment Guide for Oversight MVP
## Proper CI/CD Flow Implementation

**Version:** 1.0  
**Date:** 2025-09-21  
**Status:** Active Implementation Guide

---

## 🚨 CRITICAL: GitOps Principles

**ALL deployments MUST follow this flow:**
```
Code → GitHub → Jenkins → Security Scans → Build → Test → Production
```

**NEVER deploy directly from:**
- ❌ Local development environments
- ❌ AVD instances  
- ❌ Developer machines
- ❌ Manual Docker builds

---

## 📋 Prerequisites

### 1. GitHub Repository Setup
```bash
# Initialize Oversight MVP repository
cd /home/jez/code/Oversight-MVP-09-04
git init
git remote add origin https://github.com/JezSurfaceIT/oversight-mvp.git

# Create .gitignore
cat > .gitignore << 'EOF'
# Node
node_modules/
.next/
out/
build/
dist/

# Environment
.env
.env.local
.env.*.local

# Secrets
*.key
*.pem
*.crt
ssl/

# IDE
.vscode/
.idea/

# Logs
*.log
npm-debug.log*

# OS
.DS_Store
Thumbs.db

# Test Coverage
coverage/
.nyc_output/
EOF

# Initial commit
git add .
git commit -m "feat: Initial Oversight MVP commit"
git push -u origin main
```

### 2. Branch Protection Rules
```yaml
# Configure in GitHub Settings → Branches
main:
  - Require pull request reviews: 2
  - Dismiss stale reviews: true
  - Require review from CODEOWNERS: true
  - Require status checks: true
  - Require branches up to date: true
  - Include administrators: false
  - Restrict force pushes: true

develop:
  - Require pull request reviews: 1
  - Require status checks: true
  - Auto-merge enabled: true
```

### 3. GitHub Secrets Configuration
```bash
# Add these secrets in GitHub Settings → Secrets
AZURE_SUBSCRIPTION_ID=80265df9-bba2-4ad2-88af-e002fd2ca230
AZURE_CLIENT_ID=<service-principal-id>
AZURE_CLIENT_SECRET=<service-principal-secret>
AZURE_TENANT_ID=<tenant-id>
ACR_LOGIN_SERVER=acrsecdevopsdev.azurecr.io
ACR_USERNAME=<acr-username>
ACR_PASSWORD=<acr-password>
SONARQUBE_TOKEN=<sonarqube-token>
SNYK_TOKEN=<snyk-token>
```

---

## 🔧 Jenkins Pipeline Configuration

### 1. Create Jenkinsfile in Repository
```groovy
// Jenkinsfile
@Library('shared-pipeline-library') _

pipeline {
    agent any
    
    environment {
        APP_NAME = 'oversight-mvp'
        ACR_NAME = 'acrsecdevopsdev'
        RESOURCE_GROUP = 'rg-secdevops-cicd-dev'
        GITHUB_REPO = 'https://github.com/JezSurfaceIT/oversight-mvp.git'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Security Scan - Secrets') {
            steps {
                sh '''
                    docker run --rm -v "$PWD:/pwd" \
                        trufflesecurity/trufflehog:latest \
                        github --repo=${GITHUB_REPO}
                '''
            }
        }
        
        stage('Code Quality') {
            parallel {
                stage('SonarQube') {
                    steps {
                        withSonarQubeEnv('SonarQube') {
                            sh 'npm run sonar'
                        }
                    }
                }
                stage('ESLint') {
                    steps {
                        sh 'npm run lint'
                    }
                }
            }
        }
        
        stage('Build') {
            steps {
                sh '''
                    docker build -t ${APP_NAME}:${BUILD_NUMBER} .
                    docker tag ${APP_NAME}:${BUILD_NUMBER} \
                        ${ACR_NAME}.azurecr.io/${APP_NAME}:${BUILD_NUMBER}
                    docker tag ${APP_NAME}:${BUILD_NUMBER} \
                        ${ACR_NAME}.azurecr.io/${APP_NAME}:latest
                '''
            }
        }
        
        stage('Container Security Scan') {
            steps {
                sh '''
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image \
                        ${APP_NAME}:${BUILD_NUMBER}
                '''
            }
        }
        
        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'npm test'
                    }
                }
                stage('Integration Tests') {
                    steps {
                        sh 'npm run test:integration'
                    }
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'acr-credentials',
                        usernameVariable: 'ACR_USERNAME',
                        passwordVariable: 'ACR_PASSWORD'
                    )
                ]) {
                    sh '''
                        echo $ACR_PASSWORD | docker login ${ACR_NAME}.azurecr.io \
                            -u $ACR_USERNAME --password-stdin
                        docker push ${ACR_NAME}.azurecr.io/${APP_NAME}:${BUILD_NUMBER}
                        docker push ${ACR_NAME}.azurecr.io/${APP_NAME}:latest
                    '''
                }
            }
        }
        
        stage('Deploy to Test') {
            steps {
                sh '''
                    az container create \
                        --resource-group ${RESOURCE_GROUP} \
                        --name ${APP_NAME}-test-${BUILD_NUMBER} \
                        --image ${ACR_NAME}.azurecr.io/${APP_NAME}:${BUILD_NUMBER} \
                        --cpu 2 --memory 4 \
                        --environment-variables \
                            ENV=test \
                            BUILD_NUMBER=${BUILD_NUMBER} \
                        --ports 8000
                '''
            }
        }
        
        stage('Dynamic Security Testing') {
            steps {
                sh '''
                    CONTAINER_IP=$(az container show \
                        --resource-group ${RESOURCE_GROUP} \
                        --name ${APP_NAME}-test-${BUILD_NUMBER} \
                        --query ipAddress.ip -o tsv)
                    
                    docker run -t owasp/zap2docker-stable zap-baseline.py \
                        -t http://${CONTAINER_IP}:8000 \
                        -r zap_report.html
                '''
            }
        }
        
        stage('Production Approval') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to production?', 
                      ok: 'Deploy',
                      submitter: 'admin,devops-team'
            }
        }
        
        stage('Blue-Green Deployment') {
            when {
                branch 'main'
            }
            steps {
                sh './scripts/deployment/blue-green-deploy.sh ${APP_NAME} ${BUILD_NUMBER}'
            }
        }
    }
    
    post {
        always {
            cleanWs()
            publishHTML([
                reportDir: '.',
                reportFiles: 'zap_report.html',
                reportName: 'OWASP ZAP Report'
            ])
        }
        success {
            slackSend(
                channel: '#deployments',
                color: 'good',
                message: "✅ Deployment successful: ${APP_NAME}:${BUILD_NUMBER}"
            )
        }
        failure {
            slackSend(
                channel: '#deployments',
                color: 'danger',
                message: "❌ Deployment failed: ${APP_NAME}:${BUILD_NUMBER}"
            )
        }
    }
}
```

### 2. Configure Jenkins Webhook
```bash
# In Jenkins: Manage Jenkins → Configure System
# GitHub Webhook URL: http://<jenkins-url>/github-webhook/

# In GitHub: Settings → Webhooks
# Payload URL: http://<jenkins-url>/github-webhook/
# Content type: application/json
# Events: Push, Pull Request
```

---

## 🚀 Developer Workflow

### Standard Development Flow
```bash
# 1. Create feature branch
git checkout -b feature/new-feature

# 2. Make changes
code .

# 3. Commit with conventional commits
git add .
git commit -m "feat: Add new dashboard component"

# 4. Push to GitHub
git push origin feature/new-feature

# 5. Create Pull Request (automated via GitHub)
# Jenkins automatically runs CI pipeline on PR

# 6. After review and approval, merge to develop
# Jenkins automatically deploys to test environment

# 7. Release to production
git checkout main
git merge develop
git push origin main
# Jenkins waits for manual approval, then deploys
```

### Emergency Hotfix Flow
```bash
# 1. Create hotfix from main
git checkout -b hotfix/critical-fix main

# 2. Make minimal fix
git add .
git commit -m "fix: Resolve critical security issue"

# 3. Push and create PR
git push origin hotfix/critical-fix

# 4. Fast-track review process
# Merge directly to main after approval
# Jenkins deploys with expedited approval
```

---

## 📊 Monitoring Deployments

### View Pipeline Status
```bash
# Check Jenkins pipeline
curl -s http://<jenkins-url>/job/oversight-mvp/lastBuild/api/json | jq .result

# Check container status
az container list --resource-group rg-secdevops-cicd-dev --output table

# View application logs
az container logs --resource-group rg-secdevops-cicd-dev \
    --name oversight-mvp-test-${BUILD_NUMBER}

# Check Application Gateway health
az network application-gateway show-backend-health \
    --resource-group rg-secdevops-cicd-dev \
    --name appgw-secdevops-test
```

### Grafana Dashboards
```yaml
Dashboard URLs:
  - Pipeline Metrics: http://<grafana-url>/d/pipeline
  - Application Health: http://<grafana-url>/d/app-health
  - Security Scans: http://<grafana-url>/d/security
  - Deployment History: http://<grafana-url>/d/deployments
```

---

## ⚠️ Common Mistakes to Avoid

### ❌ DON'T: Direct Docker Deployment
```bash
# WRONG - Bypasses CI/CD
docker build -t oversight-mvp .
docker push acrsecdevopsdev.azurecr.io/oversight-mvp
```

### ✅ DO: Use Git Push
```bash
# CORRECT - Triggers full pipeline
git push origin feature/my-feature
```

### ❌ DON'T: Deploy from Local
```bash
# WRONG - No audit trail
./deploy-oversight-single-script.sh v1.0
```

### ✅ DO: Use GitHub Flow
```bash
# CORRECT - Full traceability
git tag v1.0
git push origin v1.0
```

---

## 🔐 Security Checklist

Before each deployment:
- [ ] All secrets in Azure Key Vault (never in code)
- [ ] Security scans passing (no HIGH/CRITICAL vulnerabilities)
- [ ] Code review completed
- [ ] Test coverage > 80%
- [ ] OWASP ZAP scan clean
- [ ] Container scan clean
- [ ] Dependencies up to date

---

## 📚 Additional Resources

- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [Azure Container Instances](https://docs.microsoft.com/en-us/azure/container-instances/)
- [OWASP DevSecOps Guideline](https://owasp.org/www-project-devsecops-guideline/)

---

## 🆘 Troubleshooting

### Pipeline Fails at Security Scan
```bash
# Check specific vulnerability
docker run --rm -v "$PWD:/pwd" trufflesecurity/trufflehog:latest github --repo=<repo-url>

# Fix and retry
git commit -m "fix: Remove exposed secret"
git push
```

### Container Fails to Start
```bash
# Check logs
az container logs --resource-group rg-secdevops-cicd-dev --name <container-name>

# Validate image locally
docker run -p 8000:8000 acrsecdevopsdev.azurecr.io/oversight-mvp:latest
```

### Jenkins Webhook Not Triggering
```bash
# Test webhook manually
curl -X POST http://<jenkins-url>/github-webhook/ \
  -H "Content-Type: application/json" \
  -d '{"ref":"refs/heads/main"}'

# Check Jenkins logs
tail -f /var/log/jenkins/jenkins.log
```

---

**Remember:** Every deployment must have a Git commit hash. If you can't trace a deployment back to a specific commit in GitHub, you're doing it wrong!