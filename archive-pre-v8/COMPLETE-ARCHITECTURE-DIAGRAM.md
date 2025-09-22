# Complete SecDevOps CI/CD Architecture
## Full Implementation Diagram - As Built

**Version:** 2.0  
**Date:** 2025-09-21  
**Status:** Final Implementation Blueprint

---

## 🏗️ Complete System Architecture

```mermaid
graph TB
    %% Development Layer
    subgraph "Development Environments"
        DEV1[Local Developer<br/>VSCode + .env.local]
        DEV2[Claude Code<br/>Development]
        AVD[Azure AVD Instance<br/>52.149.134.219]
        
        DEV1 -->|git push| GITHUB
        DEV2 -->|git push| GITHUB
        AVD -->|git push| GITHUB
    end

    %% Source Control & Test Automation
    subgraph "Source Control"
        GITHUB[GitHub Main Repo<br/>oversight-mvp]
        TEST_REPO[Test Automation Repo<br/>test-automation-suite<br/>Separate Lifecycle]
        
        GITHUB -->|Webhook| JENKINS
        TEST_REPO -->|Separate Pipeline| TEST_JENKINS
    end

    %% CI/CD Pipeline
    subgraph "Jenkins CI/CD Pipeline"
        JENKINS[Jenkins Master<br/>vm-jenkins-dev]
        
        JENKINS --> STAGE1{Environment<br/>Config}
        STAGE1 -->|.env.test| VAULT_TEST[HashiCorp Vault<br/>Test Secrets]
        STAGE1 -->|.env.saas| ASM[Azure Secrets<br/>Manager]
        STAGE1 -->|.env.cbe| VAULT_CBE[HashiCorp Vault<br/>CBE Secrets]
        
        VAULT_TEST --> BUILD[Docker Build<br/>Multi-stage]
        ASM --> BUILD
        VAULT_CBE --> BUILD
        
        BUILD --> SEC_SCAN[Security Scans<br/>TruffleHog<br/>SonarQube<br/>Snyk]
        SEC_SCAN --> CONTAINER_SCAN[Trivy<br/>Container Scan]
        CONTAINER_SCAN --> ACR[Azure Container<br/>Registry<br/>acrsecdevopsdev]
    end

    %% Test Environment with HashiCorp Vault
    subgraph "Test Environment - ACS"
        ACR --> TEST_ENV[Azure Container<br/>Instance - Test]
        TEST_ENV <-->|Runtime Secrets| VAULT_TEST
        
        subgraph "Test Data Management"
            DB_STATE1[DB State 1<br/>Schema Only]
            DB_STATE2[DB State 2<br/>Framework Data]
            DB_STATE3[DB State 3<br/>Full Test Data]
        end
        
        TEST_ENV --> DB_STATE1
        TEST_ENV --> DB_STATE2
        TEST_ENV --> DB_STATE3
        
        subgraph "File API Testing"
            FILE_API[File Processing API]
            TEST_FILES[Test File Store]
            FILE_HARNESS[Test Harness]
        end
        
        TEST_ENV --> FILE_API
        FILE_API --> TEST_FILES
        FILE_HARNESS --> FILE_API
    end

    %% Test Automation & Feedback
    subgraph "Test Execution & Feedback"
        TEST_JENKINS[Test Automation<br/>Jenkins]
        PLAYWRIGHT[Playwright Tests<br/>Azure Runner]
        BROWSER_ACCESS[Browser Access<br/>VNC/NoVNC]
        CONSOLE_LOG[Console Access<br/>Fluent Bit + WebSocket]
        
        TEST_JENKINS --> PLAYWRIGHT
        PLAYWRIGHT --> TEST_ENV
        BROWSER_ACCESS --> TEST_ENV
        CONSOLE_LOG --> TEST_ENV
        
        subgraph "Feedback Loops"
            TEST_FEEDBACK[Test Results<br/>Analyzer]
            APP_BUGS[App Bugs<br/>→ Dev Jira]
            ENV_ISSUES[Env Issues<br/>→ ServiceNow]
            TEST_DEBT[Test Tech Debt<br/>→ Test Jira]
        end
        
        PLAYWRIGHT --> TEST_FEEDBACK
        TEST_FEEDBACK --> APP_BUGS
        TEST_FEEDBACK --> ENV_ISSUES
        TEST_FEEDBACK --> TEST_DEBT
        
        APP_BUGS -->|Fix in Code| GITHUB
        ENV_ISSUES -->|Fix Environment| TEST_ENV
        TEST_DEBT -->|Refactor Tests| TEST_REPO
    end

    %% Deployment Gate
    TEST_ENV -->|Approval| DEPLOY_GATE{Deployment<br/>Decision Gate}
    
    %% Track 1: SaaS Production
    subgraph "Track 1: SaaS Production"
        DEPLOY_GATE -->|SaaS Track| SAAS_BUILD[Azure App Service<br/>Environment]
        SAAS_BUILD <-->|Secrets| ASM_PROD[Azure Secrets<br/>Manager Prod]
        
        subgraph "SaaS Infrastructure"
            PG_MANAGED[Azure PostgreSQL<br/>Managed Service]
            TENANT_ROUTER[Multi-Tenant<br/>Router]
            APP_GATEWAY[Application Gateway<br/>172.178.53.198]
            WAF[Web Application<br/>Firewall]
        end
        
        SAAS_BUILD --> PG_MANAGED
        SAAS_BUILD --> TENANT_ROUTER
        TENANT_ROUTER --> APP_GATEWAY
        APP_GATEWAY --> WAF
        
        subgraph "SaaS Access"
            BASTION_SAAS[Azure Bastion<br/>Browser Access]
            CONSOLE_SAAS[Console Logs<br/>Log Analytics]
        end
        
        BASTION_SAAS --> SAAS_BUILD
        CONSOLE_SAAS --> SAAS_BUILD
    end
    
    %% Track 2: Client Build Environment
    subgraph "Track 2: Client Build Environment"
        DEPLOY_GATE -->|CBE Track| CBE_PACKAGE[CBE Package<br/>Creator]
        
        CBE_PACKAGE --> CBE_ENV[Client Infrastructure<br/>On-Premises]
        
        subgraph "CBE Components"
            VAULT_LOCAL[HashiCorp Vault<br/>Local Secrets]
            PG_LOCAL[PostgreSQL<br/>Container]
            PORTAL[Customer Portal]
            NGINX[NGINX<br/>Reverse Proxy]
        end
        
        CBE_ENV --> VAULT_LOCAL
        CBE_ENV --> PG_LOCAL
        CBE_ENV --> PORTAL
        PORTAL --> NGINX
        
        subgraph "CBE Access"
            GUAC[Apache Guacamole<br/>Browser Access]
            CONSOLE_CBE[Console Access<br/>Docker Logs]
        end
        
        GUAC --> CBE_ENV
        CONSOLE_CBE --> CBE_ENV
    end
    
    %% Penetration Testing
    subgraph "Security Testing"
        KALI[Kali Linux<br/>Local Machine]
        
        KALI -->|Pentest| SAAS_BUILD
        KALI -->|Pentest| TEST_ENV
        KALI -->|Report| SEC_TICKETS[Security Tickets<br/>Critical Issues]
    end
    
    %% Monitoring & Observability
    subgraph "Monitoring Stack"
        PROMETHEUS[Prometheus<br/>Metrics]
        GRAFANA[Grafana<br/>Dashboards]
        ALERTS[AlertManager]
        
        TEST_ENV -.->|Metrics| PROMETHEUS
        SAAS_BUILD -.->|Metrics| PROMETHEUS
        CBE_ENV -.->|Metrics| PROMETHEUS
        
        PROMETHEUS --> GRAFANA
        PROMETHEUS --> ALERTS
    end
    
    %% Styling
    style GITHUB fill:#24292e,color:#fff
    style JENKINS fill:#d24939,color:#fff
    style ACR fill:#0078d4,color:#fff
    style VAULT_TEST fill:#000,color:#fff
    style VAULT_CBE fill:#000,color:#fff
    style VAULT_LOCAL fill:#000,color:#fff
    style ASM fill:#0078d4,color:#fff
    style ASM_PROD fill:#0078d4,color:#fff
    style SAAS_BUILD fill:#99ccff
    style CBE_ENV fill:#99ff99
    style KALI fill:#ff6666,color:#fff
    style TEST_FEEDBACK fill:#ffcc00
    style APP_GATEWAY fill:#40e0d0
    style WAF fill:#ff6b6b,color:#fff
```

---

## 📋 Component Details (As Implemented)

### Development Layer
- **Local Dev**: Uses `.env.local` (never committed)
- **Claude Code**: Development environment with Git integration
- **Azure AVD**: Instance at 52.149.134.219 for development

### Source Control
- **Main App Repo**: `github.com/JezSurfaceIT/oversight-mvp`
- **Test Automation Repo**: Separate repo with own lifecycle
- **GitOps**: All deployments triggered via Git push

### CI/CD Pipeline
- **Jenkins**: Orchestrates entire pipeline
- **Environment Config**: Dynamic .env generation from secrets
- **Security Scanning**: Multiple stages (secrets, SAST, container)
- **Container Registry**: Azure ACR for image storage

### Test Environment (Azure Container Service)
- **Secrets**: HashiCorp Vault (NOT Azure Key Vault)
- **Database States**: 3 switchable states (schema/framework/full)
- **File API**: Testable with multiple file scenarios
- **Test Automation**: Playwright with Azure runners
- **Browser Access**: VNC/NoVNC for human access
- **Console Access**: Fluent Bit + WebSocket streaming

### Feedback Loops
- **Test Results Analyzer**: Classifies failures
- **App Bugs**: Creates Jira tickets for dev team
- **Environment Issues**: Creates ServiceNow tickets
- **Test Tech Debt**: Separate Jira project for test improvements

### Track 1: SaaS Production
- **Platform**: Azure App Service Environment
- **Secrets**: Azure Secrets Manager
- **Database**: Managed PostgreSQL
- **Multi-tenancy**: Subdomain-based routing
- **Access**: Azure Bastion for browser, Log Analytics for logs

### Track 2: Client Build Environment
- **Deployment**: Package-based for on-premises
- **Secrets**: HashiCorp Vault (local)
- **Database**: PostgreSQL in container
- **Portal**: Customer Portal for management
- **Access**: Apache Guacamole for browser, Docker logs for console

### Security Testing
- **Kali Linux**: Run from local machine
- **Targets**: Both SaaS and Test environments
- **Reporting**: Automated ticket creation for critical findings

### Monitoring
- **Metrics**: Prometheus collecting from all environments
- **Dashboards**: Grafana for visualization
- **Alerts**: AlertManager for incident notification

---

## ✅ Key Implementation Details

### Environment Variables
```yaml
Test Environment:
  Source: HashiCorp Vault
  Runtime: Injected at container start
  
SaaS Production:
  Source: Azure Secrets Manager
  Runtime: App Service configuration

CBE:
  Source: Local HashiCorp Vault
  Runtime: Docker environment variables
```

### Database Management
```yaml
State Switching:
  Command: ./scripts/data/switch-db-state.sh [1|2|3]
  Backup: Automated snapshots before switch
  Restore: ./scripts/data/restore-known-good.sh
```

### Test Automation
```yaml
Main App Tests:
  Trigger: Git push to main repo
  Execution: Jenkins pipeline
  
Test Script Tests:
  Trigger: Git push to test repo
  Pipeline: Separate Jenkins job
  Tech Debt: Tracked separately
```

### Human Access
```yaml
Browser Access:
  Test: VNC on port 5900, NoVNC on port 8080
  SaaS: Azure Bastion
  CBE: Apache Guacamole

Console Logs:
  Test: WebSocket streaming
  SaaS: Azure Log Analytics
  CBE: Docker logs
```

### Penetration Testing
```yaml
Tool: Kali Linux Docker container
Execution: From local machine
Targets: 
  - SaaS Production
  - Test Environment
Schedule: Weekly automated scans
```

---

## 🚨 Critical Configuration Notes

1. **Test Environment uses HashiCorp Vault**, NOT Azure Key Vault
2. **Test scripts have separate repository** and lifecycle
3. **Three database states** must be maintained and switchable
4. **File API** must support test file modifications
5. **Browser access** required for all environments
6. **Console log access** required for debugging
7. **Kali pentesting** runs from local, not cloud
8. **Feedback loops** are separate for app, environment, and test issues
9. **Dual deployment tracks** (SaaS and CBE) from same codebase
10. **All secrets externalized** - no hardcoding anywhere

---

## 📊 Data Flow Summary

```
1. Developer → Git Push → GitHub
2. GitHub Webhook → Jenkins
3. Jenkins → Fetch Secrets from Vault/ASM
4. Jenkins → Build Docker Image with .env
5. Jenkins → Run Security Scans
6. Jenkins → Push to ACR
7. ACR → Deploy to Test (with Vault secrets)
8. Test → Run Playwright Tests
9. Test Results → Feedback Loop
10. Approval → Deploy to SaaS or CBE
11. SaaS uses Azure Secrets Manager
12. CBE uses local HashiCorp Vault
13. Kali → Penetration Testing
14. All environments → Prometheus → Grafana
```

---

This diagram and documentation are **functionally equivalent** and represent the actual implementation, not theoretical design. Every component shown must be built exactly as specified.