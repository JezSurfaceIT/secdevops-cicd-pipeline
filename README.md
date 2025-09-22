# SecDevOps CI/CD Pipeline - Oversight MVP

## 📚 V8 Architecture Documentation

**All current V8 architecture documentation is located in the [v8/](./v8/) directory.**

**Start here:** [V8 Architecture Summary](./v8/V8-ARCHITECTURE-SUMMARY.md)

### Key V8 Documents:
- [Complete Architecture Diagram](./v8/COMPLETE-ARCHITECTURE-DIAGRAM-V8-COMPREHENSIVE.md)
- [Implementation Guide](./v8/IMPLEMENTATION-GUIDE-V8.md)
- [Deployment Checklist](./v8/DEPLOYMENT-CHECKLIST-V8.md)

---

## 🚀 GitOps-Driven Deployment Platform

**Version:** 2.0  
**Architecture:** GitOps with Jenkins CI/CD  
**Security:** DevSecOps with automated scanning  
**Infrastructure:** Azure Cloud Native

---

## 📋 Quick Start for Developers

### Deploy Your Code (The RIGHT Way)
```bash
# 1. Make your changes
code .

# 2. Commit to Git
git add .
git commit -m "feat: Add new feature"

# 3. Push to GitHub (this triggers EVERYTHING automatically)
git push origin feature/my-feature

# 4. Create Pull Request and get review
# 5. Merge = Automatic deployment!
```

**That's it!** No manual Docker builds, no direct deployments. Git push = Full secure deployment.

---

## 🏗️ Architecture Overview

```
Developer → GitHub → Jenkins → Security Scans → Build → Test → Deploy → Production
```

### Key Components:
- **Source Control**: GitHub (single source of truth)
- **CI/CD Engine**: Jenkins on Azure VM
- **Container Registry**: Azure Container Registry
- **Deployment Target**: Azure Container Instances
- **Security**: Multi-stage scanning (SAST, DAST, Container)
- **Monitoring**: Prometheus + Grafana + Azure Monitor

---

## 📁 Repository Structure

```
SecDevOps_CICD/
├── README.md                           # This file
├── GITOPS-DEPLOYMENT-GUIDE.md          # Complete GitOps guide
├── MIGRATION-TO-GITOPS.md              # Migration from old methods
├── SECDEVOPS_CICD_ARCHITECTURE.md      # Full architecture document
├── Jenkinsfile                         # Pipeline definition
├── deploy-from-github.sh               # GitOps deployment script
├── scripts/
│   ├── security/                      # Security scanning scripts
│   ├── deployment/                     # Deployment utilities
│   ├── monitoring/                     # Monitoring setup
│   └── quality/                        # Code quality tools
├── terraform/                          # Infrastructure as Code
├── docs/                               # Documentation
└── tests/                              # Test suites
```

---

## 🔐 Security First Approach

Every deployment goes through:

1. **Secret Scanning** - TruffleHog detects exposed credentials
2. **Code Analysis** - SonarQube checks code quality
3. **Dependency Check** - Snyk finds vulnerable packages  
4. **Container Scanning** - Trivy scans Docker images
5. **Dynamic Testing** - OWASP ZAP tests running application
6. **WAF Protection** - Application Gateway with Web Application Firewall

---

## 🚫 What NOT to Do

### ❌ NEVER Do This:
```bash
# DON'T bypass Git
./deploy-oversight-single-script.sh   # DEPRECATED

# DON'T build locally and push
docker build -t myapp .
docker push registry/myapp

# DON'T deploy directly
az container create ...
```

### ✅ ALWAYS Do This:
```bash
# Push to Git - that's all!
git push origin main
```

---

## 📊 Pipeline Stages

| Stage | Duration | Purpose | Tools |
|-------|----------|---------|-------|
| Checkout | 30s | Get code from GitHub | Git |
| Security Scan | 2-3 min | Find secrets & vulnerabilities | TruffleHog, Snyk |
| Build | 3-5 min | Create Docker container | Docker, Node.js |
| Test | 5-10 min | Run 5000+ tests | Jest, Playwright |
| Container Scan | 2 min | Check container security | Trivy |
| Deploy to Test | 2 min | Deploy to test environment | Azure CLI |
| Security Test | 5 min | Dynamic application testing | OWASP ZAP |
| Approval Gate | Manual | Human review for production | Jenkins |
| Production Deploy | 3 min | Blue-Green deployment | Custom scripts |

**Total: ~25 minutes** (worth it for security and reliability!)

---

## 🛠️ Setup Instructions

### 1. Prerequisites
- GitHub account with repository access
- Azure subscription
- Jenkins access (provided by DevOps)
- Docker installed locally

### 2. Clone Repository
```bash
git clone https://github.com/JezSurfaceIT/secdevops-cicd-pipeline.git
cd secdevops-cicd-pipeline
```

### 3. Configure Git
```bash
git config user.name "Your Name"
git config user.email "your.email@company.com"
```

### 4. Start Developing
```bash
# Create feature branch
git checkout -b feature/your-feature

# Make changes
code .

# Commit and push
git add .
git commit -m "feat: Description of change"
git push origin feature/your-feature
```

---

## 📈 Monitoring & Dashboards

### Key Dashboards:
- **Jenkins**: http://vm-jenkins-dev:8080
- **SonarQube**: http://sonarqube.oversight.io:9000
- **Grafana**: http://grafana.oversight.io:3000
- **Application**: http://172.178.53.198 (via App Gateway)

### Useful Commands:
```bash
# Check deployment status
az container list --resource-group rg-secdevops-cicd-dev -o table

# View logs
az container logs --resource-group rg-secdevops-cicd-dev --name oversight-mvp-test

# Monitor pipeline
curl http://vm-jenkins-dev:8080/job/oversight-mvp/lastBuild/api/json
```

---

## 🚑 Troubleshooting

### Pipeline Failed?
1. Check Jenkins console output
2. Review security scan results
3. Verify tests are passing locally
4. Check container logs

### Emergency Deployment?
1. Create hotfix branch from main
2. Make minimal fix
3. Push and create PR with "HOTFIX" label
4. Get expedited review
5. Merge triggers priority deployment

---

## 📚 Documentation

- [GitOps Deployment Guide](./GITOPS-DEPLOYMENT-GUIDE.md) - Complete deployment instructions
- [Architecture Document](./SECDEVOPS_CICD_ARCHITECTURE.md) - Full system design
- [Migration Guide](./MIGRATION-TO-GITOPS.md) - Moving from old methods
- [Security Policies](./docs/SECURITY-POLICIES.md) - Security requirements
- [API Documentation](./docs/API.md) - API endpoints and usage

### 📊 Monitoring & Observability (NEW)
- **Prometheus**: Metrics collection with HA deployment (Story 6.1 ✅)
  - 15-day retention, Thanos for long-term storage
  - Azure & Kubernetes service discovery
  - Federation for multi-region metrics
- **Grafana**: Dashboard visualization (Story 6.2 - In Progress)
- **Infrastructure**: All deployed via IaC (Terraform)

---

## 👥 Team

### DevOps Team
- Infrastructure and pipeline management
- Contact: #devops-team on Slack

### Security Team  
- Security scanning and compliance
- Contact: #security-team on Slack

### Development Team
- Application development
- Contact: #dev-team on Slack

---

## 🎯 Key Principles

1. **GitHub is Truth** - All deployments come from Git
2. **Security First** - Multiple scanning stages before deployment
3. **Automate Everything** - Manual steps = mistakes
4. **Test Thoroughly** - 5000+ automated tests
5. **Monitor Continuously** - Full observability stack
6. **Document Always** - If it's not documented, it doesn't exist

---

## 📝 License

Proprietary - Oversight MVP  
© 2025 All Rights Reserved

---

## 🆘 Need Help?

1. Check documentation first
2. Ask in #devops-help on Slack
3. Create issue in GitHub
4. Office hours: Mon-Fri 10am-11am

---

**Remember:** Every deployment should be traceable to a Git commit. If you can't `git blame` it, it shouldn't be in production!