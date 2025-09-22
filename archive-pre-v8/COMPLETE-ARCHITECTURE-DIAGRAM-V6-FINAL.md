# Complete SecDevOps CI/CD Architecture - Version 6
## Final IP-Restricted Architecture with Full SecDevOps

**Version:** 6.0  
**Date:** 2025-09-21  
**Status:** Complete Implementation with All Components

---

## 🔒 Complete SecDevOps Architecture - IP Restricted Access

```mermaid
graph TB
    %% Development Sources
    subgraph "Development Sources"
        LOCAL[101: Local Developer<br/>Your Machine]
        AVD[103: Azure AVD<br/>10.0.3.10]
        KALI_LOCAL[951: Kali Linux<br/>Local Network]
        
        LOCAL -->|git push| GITHUB
        AVD -->|git push| GITHUB
        KALI_LOCAL -->|Direct Access| TEST_ENV
    end
    
    %% Source Control
    subgraph "Source Control [200]"
        GITHUB[201: GitHub Main Repo<br/>oversight-mvp]
        TEST_REPO[202: Test Scripts Repo<br/>Separate Lifecycle]
        TEST_CAT[203: Test Catalogue<br/>Jest/Playwright/Code]
        
        GITHUB -->|Webhook| IP_CHECK
        TEST_REPO -->|Separate Pipeline| IP_CHECK
    end
    
    %% The ONLY way in from Internet
    subgraph "IP Security Gateway [800-803]"
        IP_CHECK{801: IP Allowlist<br/>━━━━━━━━━━<br/>✅ GitHub Webhooks<br/>✅ Azure DevOps<br/>✅ Authorized Admin IPs<br/>━━━━━━━━━━}
        WAF[802: WAF + App Gateway<br/>172.178.53.198<br/>ONLY Public IP]
        BLOCKED[❌ ACCESS DENIED]
        
        IP_CHECK -->|Allowed| WAF
        IP_CHECK -->|Blocked| BLOCKED
    end
    
    %% Single Unified VNet
    subgraph "Unified Private VNet [10.0.0.0/16]"
        FIREWALL[811: Azure Firewall<br/>10.0.0.4]
        
        WAF --> FIREWALL
        
        subgraph "CI/CD & SecDevOps [300-399]"
            JENKINS[301: Jenkins Master<br/>10.0.3.20]
            
            subgraph "Security Scanning Suite [307]"
                TRUFFLE[307.1: TruffleHog<br/>Secrets Scan]
                SONAR[307.2: SonarQube<br/>SAST]
                SNYK[307.3: Snyk<br/>Dependencies]
                SEMGREP[307.4: Semgrep<br/>Code Patterns]
                TRIVY[307.5: Trivy<br/>Container Scan]
                CHECKOV[307.6: Checkov<br/>IaC Scan]
                GITLEAKS[307.7: GitLeaks<br/>History Scan]
            end
            
            ACR[308: Container Registry<br/>10.0.3.30]
            
            JENKINS --> TRUFFLE
            TRUFFLE --> SONAR
            SONAR --> SNYK
            SNYK --> SEMGREP
            SEMGREP --> TRIVY
            TRIVY --> CHECKOV
            CHECKOV --> GITLEAKS
            GITLEAKS --> ACR
        end
        
        subgraph "Test Environment [400-499]"
            TEST_ENV[401: Test Container<br/>10.0.1.10]
            VAULT_TEST[403: HashiCorp Vault<br/>Test Secrets<br/>10.0.1.30]
            
            subgraph "Test Data States [410]"
                DB1[411: Schema Only]
                DB2[412: Framework Data]
                DB3[413: Full Test Data]
            end
            
            subgraph "Test Execution [510]"
                PLAYWRIGHT[511: Playwright<br/>E2E Tests]
                JEST[512: Jest<br/>Unit Tests]
                API_TESTS[514: API Tests]
            end
            
            subgraph "Test Access [520]"
                VNC[520: VNC/NoVNC<br/>Browser Access]
                CONSOLE[521: Console Logs<br/>WebSocket]
            end
            
            ACR --> TEST_ENV
            TEST_ENV <--> VAULT_TEST
            TEST_ENV --> DB1
            TEST_ENV --> DB2
            TEST_ENV --> DB3
            
            PLAYWRIGHT --> TEST_ENV
            JEST --> TEST_ENV
            API_TESTS --> TEST_ENV
            VNC --> TEST_ENV
            CONSOLE --> TEST_ENV
        end
        
        subgraph "Test Feedback [530]"
            TEST_RESULTS[531: Test Analyzer]
            APP_BUGS[532: App Bugs<br/>→ Azure DevOps]
            ENV_ISSUES[533: Env Issues<br/>→ Azure DevOps]
            TEST_DEBT[534: Test Debt<br/>→ Test Repo]
            
            PLAYWRIGHT --> TEST_RESULTS
            JEST --> TEST_RESULTS
            API_TESTS --> TEST_RESULTS
            
            TEST_RESULTS --> APP_BUGS
            TEST_RESULTS --> ENV_ISSUES
            TEST_RESULTS --> TEST_DEBT
            
            APP_BUGS -->|Fix| GITHUB
            TEST_DEBT -->|Update| TEST_REPO
        end
        
        TEST_ENV -->|Approval| DEPLOY_GATE{Deploy Gate}
        
        subgraph "SaaS Production [700-799]"
            SAAS_APP[701: SaaS App<br/>10.0.2.10]
            KV[714: Azure Key Vault<br/>Production Secrets<br/>10.0.7.10]
            
            PG_PROD[711: PostgreSQL<br/>10.0.5.10]
            STORAGE[712: Blob Storage<br/>10.0.6.10]
            REDIS[713: Redis Cache<br/>10.0.5.20]
            
            TENANT[729: Multi-Tenant Router<br/>ROADMAP ITEM<br/>10.0.2.100]
            
            DEPLOY_GATE -->|SaaS| SAAS_APP
            SAAS_APP <--> KV
            SAAS_APP --> PG_PROD
            SAAS_APP --> STORAGE
            SAAS_APP --> REDIS
            
            SAAS_APP -.->|Future| TENANT
        end
        
        subgraph "CBE Track [900-999]"
            CBE_PACKAGE[901: Package Creator<br/>10.0.4.5]
            CBE_MIMIC[903: CBE Mimic<br/>10.0.4.10]
            VAULT_CBE[905: CBE Vault<br/>10.0.4.30]
            PORTAL[904: Customer Portal<br/>10.0.4.40]
            
            DEPLOY_GATE -->|CBE| CBE_PACKAGE
            CBE_PACKAGE --> PORTAL
            PORTAL --> CBE_MIMIC
            CBE_MIMIC <--> VAULT_CBE
        end
        
        subgraph "Human Access [812]"
            BASTION[812: Azure Bastion<br/>10.0.8.1]
            
            BASTION --> TEST_ENV
            BASTION --> SAAS_APP
            BASTION --> AVD
        end
        
        subgraph "Monitoring [1000]"
            PROMETHEUS[1001: Prometheus<br/>10.0.9.10]
            GRAFANA[1002: Grafana<br/>10.0.9.20]
            ALERTS[1003: AlertManager<br/>10.0.9.30]
            
            TEST_ENV -.-> PROMETHEUS
            SAAS_APP -.-> PROMETHEUS
            CBE_MIMIC -.-> PROMETHEUS
            PROMETHEUS --> GRAFANA
            PROMETHEUS --> ALERTS
        end
        
        %% Firewall routes
        FIREWALL --> JENKINS
        FIREWALL --> TEST_ENV
        FIREWALL --> SAAS_APP
        FIREWALL --> CBE_MIMIC
        FIREWALL --> BASTION
        FIREWALL --> PROMETHEUS
    end
    
    %% External connections
    PORTAL -->|Download| CUSTOMER[Customer On-Prem]
    
    %% Test automation separate pipeline
    TEST_JENKINS[501: Test Jenkins<br/>10.0.3.25]
    TEST_REPO --> TEST_JENKINS
    TEST_CAT --> TEST_JENKINS
    TEST_JENKINS --> PLAYWRIGHT
    TEST_JENKINS --> JEST
    
    %% Styling
    style IP_CHECK fill:#ff0000,color:#fff,stroke:#fff,stroke-width:4px
    style WAF fill:#ff6b6b,color:#fff
    style FIREWALL fill:#ff9900,color:#fff
    style BLOCKED fill:#000,color:#fff
    style GITHUB fill:#24292e,color:#fff
    style JENKINS fill:#d24939,color:#fff
    style KV fill:#0078d4,color:#fff
    style VAULT_TEST fill:#000,color:#fff
    style VAULT_CBE fill:#000,color:#fff
    style BASTION fill:#0078d4,color:#fff
    style TENANT fill:#cccccc,color:#666
    style TEST_RESULTS fill:#ffcc00
    style PORTAL fill:#9370db
```

---

## 📋 Complete Component List

### 🔧 Development & Source Control
| Component | ID | Purpose | Access |
|-----------|-----|---------|--------|
| Local Developer | 101 | Your machine | Git push to GitHub |
| Azure AVD | 103 | Cloud development | Git push to GitHub |
| GitHub Main | 201 | Source code | Webhook to Jenkins |
| Test Scripts Repo | 202 | Test automation | Separate lifecycle |
| Test Catalogue | 203 | Test library | Jest, Playwright, Code tests |

### 🔒 Security Gateway
| Component | ID | Purpose | Details |
|-----------|-----|---------|---------|
| IP Allowlist | 801 | Primary Security | Only listed IPs allowed |
| WAF | 802 | Web Security | OWASP, DDoS protection |
| App Gateway | 803 | Public Entry | 172.178.53.198 |

### 🛡️ Complete SecDevOps Suite
| Tool | ID | Purpose | Stage |
|------|-----|---------|-------|
| TruffleHog | 307.1 | Secret scanning | Pre-commit |
| SonarQube | 307.2 | SAST analysis | Build |
| Snyk | 307.3 | Dependency scan | Build |
| Semgrep | 307.4 | Pattern matching | Build |
| Trivy | 307.5 | Container scan | Post-build |
| Checkov | 307.6 | IaC scanning | Deploy |
| GitLeaks | 307.7 | History scan | Continuous |

### 🧪 Test Environment with Feedback
| Component | ID | Purpose | Details |
|-----------|-----|---------|---------|
| Test Container | 401 | Test app instance | 10.0.1.10 |
| HashiCorp Vault | 403 | Test secrets | Runtime injection |
| DB State 1 | 411 | Schema only | Clean state |
| DB State 2 | 412 | Framework data | Basic testing |
| DB State 3 | 413 | Full test data | Complete testing |
| Playwright | 511 | E2E tests | Browser automation |
| Jest | 512 | Unit tests | Component testing |
| API Tests | 514 | REST/GraphQL | API validation |
| Test Analyzer | 531 | Results processing | Categorizes failures |
| App Bugs | 532 | Dev issues | → Azure DevOps |
| Env Issues | 533 | Infrastructure | → Azure DevOps |
| Test Debt | 534 | Test improvements | → Test Repo |

### 🚀 Production (Simplified)
| Component | ID | Purpose | Details |
|-----------|-----|---------|---------|
| SaaS App | 701 | Single production app | 10.0.2.10 |
| Azure Key Vault | 714 | Production secrets | Private endpoint |
| PostgreSQL | 711 | Production DB | 10.0.5.10 |
| Blob Storage | 712 | File storage | 10.0.6.10 |
| Redis Cache | 713 | Session cache | 10.0.5.20 |
| Tenant Router | 729 | **ROADMAP** | Future multi-tenancy |

### 📦 CBE Track
| Component | ID | Purpose | Details |
|-----------|-----|---------|---------|
| Package Creator | 901 | Build CBE package | From approved code |
| CBE Mimic | 903 | Test CBE locally | Validate package |
| Customer Portal | 904 | Distribution | Customers download |
| CBE Vault | 905 | CBE secrets | Local HashiCorp |

---

## 🔄 Complete Workflows

### Development → Production
```
1. Developer (Local/AVD) → GitHub
2. GitHub Webhook → IP Check → WAF → Jenkins
3. Jenkins → Full Security Scan Suite (307.1-307.7)
4. Passed → ACR → Test Environment
5. Test Suite (Playwright/Jest/API) → Test Results
6. Test Feedback → Azure DevOps / Test Repo
7. Approved → Deploy to SaaS (701 using 714)
```

### Test Management & Feedback
```
1. Test Scripts Repo (202) → Test Jenkins (501)
2. Test Catalogue (203) → Test Execution
3. Results → Test Analyzer (531)
4. Categorization:
   - App Bugs (532) → Azure DevOps → Fix in GitHub
   - Env Issues (533) → Azure DevOps → Fix Infrastructure
   - Test Debt (534) → Update Test Repo
```

### CBE Distribution
```
1. Approved Build → Package Creator (901)
2. Package → Customer Portal (904)
3. Portal → CBE Mimic (903) for validation
4. Customer downloads from Portal → On-Premises
```

---

## 🎯 IP Allowlist Configuration

```yaml
Public Gateway Allowed IPs:
  CI/CD:
    - GitHub Webhooks (from GitHub cloud)
    - Azure DevOps Agents
    
  Administration:
    - Specific authorized admin IPs only
    
  Internal Azure:
    - Azure Services: 10.0.0.0/16

Local/Internal Access (Not via public gateway):
  Development:
    - Local Developer Machine → GitHub direct
    - Azure AVD (10.0.3.10) → Internal access
    
  Testing:
    - Kali Linux (local network) → Direct to test environment

Default: DENY ALL
```

---

## ✅ Complete Checklist

### Development & Source Control
- [x] Local developer machine access
- [x] Azure AVD for cloud development  
- [x] GitHub main repo (201)
- [x] Test scripts separate repo (202)
- [x] Test catalogue (203)

### SecDevOps Tools
- [x] TruffleHog (307.1)
- [x] SonarQube (307.2)
- [x] Snyk (307.3)
- [x] Semgrep (307.4)
- [x] Trivy (307.5)
- [x] Checkov (307.6)
- [x] GitLeaks (307.7)

### Test Environment
- [x] HashiCorp Vault for test secrets
- [x] 3-state database management
- [x] Playwright/Jest/API testing
- [x] VNC/Console access
- [x] Test feedback loops

### Production
- [x] Single SaaS app (701)
- [x] Azure Key Vault (714)
- [x] Multi-tenant router (ROADMAP)

### Security
- [x] IP allowlist enforcement
- [x] WAF protection
- [x] Private networking
- [x] Zero public IPs (except gateway)

---

This final architecture includes all requested components: single SaaS app (701) using Key Vault (714), GitHub access from local and AVD, complete SecDevOps toolset, and restored test script management with feedback loops.