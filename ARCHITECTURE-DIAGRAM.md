# SecDevOps E2E CI/CD Architecture Diagram

```mermaid
graph TB
    subgraph "Azure Subscription: 80265df9-bba2-4ad2-88af-e002fd2ca230"
        subgraph "Resource Group: rg-secdevops-cicd-dev"
            subgraph "Networking Layer"
                VNET[VNet: vnet-secdevops-test<br/>10.0.0.0/16<br/>Tags: Pipeline=SecDevOps-E2E]
                
                subgraph "Subnets"
                    SUBNET1[subnet-containers<br/>10.0.1.0/24<br/>Delegated: ContainerInstance]
                    SUBNET2[subnet-appgateway<br/>10.0.2.0/24]
                end
                
                NSG[NSG: nsg-containers<br/>Rules: Allow AppGW only]
                PIP[Public IP: pip-appgw-secdevops<br/>172.178.53.198<br/>Tags: Stage=Production]
            end
            
            subgraph "Security Layer"
                WAF[WAF Policy: waf-policy-secdevops<br/>Mode: Prevention<br/>Allowed IP: 86.3.129.121<br/>Tags: PolicyType=IP-Restriction]
                APPGW[Application Gateway: appgw-secdevops-test<br/>SKU: WAF_v2<br/>Backend: 10.0.1.4:3001<br/>Tags: SecurityLevel=WAF-v2]
            end
            
            subgraph "Container Registry"
                ACR[ACR: acrsecdevopsdev<br/>SKU: Premium<br/>Images: dummy-app-e2e-test:v1.1<br/>Tags: SecurityScan=Trivy]
            end
            
            subgraph "Application Layer"
                CONTAINER1[Container: dummy-app-private<br/>IP: 10.0.1.4:3001<br/>Tags: Stage=Test, Version=v1.1]
                CONTAINER2[Container: dummy-app-blue<br/>DNS: dummy-app-blue.eastus.azurecontainer.io<br/>Tags: Environment=Blue]
                CONTAINER3[Container: dummy-app-green<br/>DNS: dummy-app-green.eastus.azurecontainer.io<br/>Tags: Environment=Green]
            end
            
            subgraph "Monitoring"
                LAW[Log Analytics: log-secdevops-dev]
                AI[App Insights: appi-secdevops-dev]
            end
        end
    end
    
    subgraph "Local Infrastructure (Docker)"
        subgraph "CI/CD Pipeline"
            JENKINS[Jenkins<br/>localhost:8080<br/>Password: 27eaee2a...]
            SONAR[SonarQube<br/>localhost:9000<br/>Code Quality]
        end
        
        subgraph "Monitoring Stack"
            PROM[Prometheus<br/>localhost:9091<br/>Metrics Collection]
            GRAF[Grafana<br/>localhost:3000<br/>Dashboards]
            ALERT[Alertmanager<br/>localhost:9093<br/>Alert Routing]
        end
        
        subgraph "Security Tools"
            ZAP[OWASP ZAP<br/>DAST Scanner]
            TRIVY[Trivy<br/>Container Scanner]
        end
    end
    
    subgraph "Pipeline Execution Flow"
        TRIGGER[Git Push/Manual Trigger] --> JENKINS
        JENKINS --> CHECKOUT[1. Code Checkout]
        CHECKOUT --> QUALITY[2. Code Quality<br/>Lint, SonarQube]
        QUALITY --> SAST[3. Security Scan<br/>Trivy SAST]
        SAST --> TEST[4. Unit Tests<br/>Coverage > 80%]
        TEST --> BUILD[5. Docker Build]
        BUILD --> SCAN[6. Container Scan<br/>Trivy Image]
        SCAN --> PUSH[7. Push to ACR]
        PUSH --> DEPLOY[8. Deploy to Azure]
        DEPLOY --> E2E[9. E2E Tests]
        E2E --> DAST[10. OWASP ZAP Scan]
        DAST --> PROD[11. Production Deploy]
    end
    
    %% Connections
    PIP --> APPGW
    APPGW --> WAF
    APPGW --> SUBNET2
    SUBNET2 --> SUBNET1
    SUBNET1 --> CONTAINER1
    ACR --> CONTAINER1
    ACR --> CONTAINER2
    ACR --> CONTAINER3
    NSG --> SUBNET1
    
    JENKINS --> ACR
    JENKINS --> CONTAINER1
    PROM --> GRAF
    PROM --> ALERT
    
    LAW --> AI
    CONTAINER1 --> LAW
    APPGW --> LAW
    
    classDef azure fill:#0078d4,stroke:#fff,color:#fff
    classDef security fill:#d73027,stroke:#fff,color:#fff
    classDef monitoring fill:#4575b4,stroke:#fff,color:#fff
    classDef pipeline fill:#74a9cf,stroke:#333,color:#333
    classDef app fill:#5aae61,stroke:#fff,color:#fff
    
    class VNET,SUBNET1,SUBNET2,PIP,ACR,LAW,AI azure
    class WAF,APPGW,NSG,ZAP,TRIVY security
    class PROM,GRAF,ALERT monitoring
    class JENKINS,SONAR,QUALITY,SAST,TEST,BUILD,SCAN,PUSH,DEPLOY,E2E,DAST,PROD pipeline
    class CONTAINER1,CONTAINER2,CONTAINER3 app
```

## Resource Labels & Execution Groups

### Execution Group: `e2e-full`
All resources are tagged with `ExecutionGroup=e2e-full` for easy identification

### Resource Group Details
- **Name**: `rg-secdevops-cicd-dev`
- **Location**: `eastus`
- **Tags**:
  - Environment: Dev
  - Pipeline: SecDevOps-E2E
  - Project: CICD
  - Owner: Jez
  - CreatedBy: Claude
  - ManagedBy: Pipeline
  - ExecutionGroup: e2e-full
  - SecurityLevel: WAF-Protected

### Key Service Endpoints

| Service | URL | Purpose | Labels |
|---------|-----|---------|--------|
| Application Gateway | http://172.178.53.198 | WAF-protected entry point | Stage=Production, SecurityLevel=WAF-v2 |
| Jenkins | http://localhost:8080 | CI/CD orchestration | Component=CICD |
| Grafana | http://localhost:3000 | Monitoring dashboards | Component=Monitoring |
| Prometheus | http://localhost:9091 | Metrics collection | Component=Metrics |
| SonarQube | http://localhost:9000 | Code quality analysis | Component=Quality |
| Alertmanager | http://localhost:9093 | Alert management | Component=Alerting |

### Container Instances

| Name | IP/DNS | Stage | Strategy |
|------|--------|-------|----------|
| dummy-app-private | 10.0.1.4:3001 (private) | Test | Main deployment |
| dummy-app-blue | dummy-app-blue.eastus.azurecontainer.io | Production | Blue-Green |
| dummy-app-green | dummy-app-green.eastus.azurecontainer.io | Staging | Blue-Green |
| dummy-app-prod | dummy-app-prod.eastus.azurecontainer.io | Production | Active |

### Pipeline Scripts

| Script | Location | Purpose | Execution Time |
|--------|----------|---------|----------------|
| run-e2e-pipeline.sh | /home/jez/code/SecDevOps_CICD/ | Complete E2E pipeline | ~100 seconds |
| blue-green-deploy.sh | scripts/deployment/ | Zero-downtime deployment | ~3 minutes |
| run-zap-scan.sh | scripts/security/ | DAST scanning | 5-10 minutes |
| run-sonarqube-scan.sh | scripts/quality/ | Code quality analysis | 2-5 minutes |
| deploy-with-app-gateway.sh | /home/jez/code/SecDevOps_CICD/ | WAF deployment | 15-20 minutes |

### Security Layers

1. **Network Security**
   - Private VNet with isolated subnets
   - NSG rules restricting access
   - Container subnet delegation

2. **Application Security**
   - WAF v2 with OWASP rules
   - IP whitelisting (86.3.129.121)
   - Prevention mode enabled

3. **Container Security**
   - Trivy scanning at build time
   - ACR with retention policies
   - Private endpoint connections

4. **Code Security**
   - SAST with Trivy
   - DAST with OWASP ZAP
   - SonarQube security hotspots

### Monitoring & Alerting

```mermaid
graph LR
    subgraph "Metrics Flow"
        APP[Application] --> PROM[Prometheus]
        JENKINS[Jenkins] --> PROM
        DOCKER[Docker] --> PROM
        PROM --> GRAF[Grafana]
        PROM --> ALERT[Alertmanager]
        ALERT --> SLACK[Notifications]
    end
    
    subgraph "Azure Monitoring"
        APPGW[App Gateway] --> LAW[Log Analytics]
        CONTAINER[Containers] --> LAW
        LAW --> AI[App Insights]
        AI --> ALERTS[Azure Alerts]
    end
```

### Deployment Strategies

```mermaid
graph TB
    subgraph "Blue-Green Deployment"
        TRAFFIC[Traffic] --> ROUTER{Router}
        ROUTER -->|Active| BLUE[Blue Environment<br/>v1.0]
        ROUTER -.->|Standby| GREEN[Green Environment<br/>v1.1]
        
        DEPLOY[New Deployment] --> GREEN
        TEST[Tests Pass] --> SWITCH[Switch Traffic]
        SWITCH --> ROUTER
    end
```

### Tags Structure

All resources follow this tagging convention:
```yaml
Tags:
  Environment: Dev/Test/Prod
  Pipeline: SecDevOps-E2E
  Component: Application/Network/Security/Monitoring
  Stage: Build/Test/Production
  ExecutionGroup: e2e-full
  SecurityLevel: WAF-Protected/Private/Public
  Version: v1.0/v1.1/latest
  DeploymentStrategy: Blue-Green/Canary/Rolling
  Owner: Jez
  ManagedBy: Terraform/Pipeline
```

### Quick Access Commands

```bash
# Run full E2E pipeline
./run-e2e-pipeline.sh dummy-app-e2e-test v1.2

# Deploy with blue-green strategy
./scripts/deployment/blue-green-deploy.sh dummy-app-e2e-test v1.2

# Security scan
./scripts/security/run-zap-scan.sh http://172.178.53.198 baseline

# Quality check
./scripts/quality/run-sonarqube-scan.sh secdevops-cicd "SecDevOps CICD"

# Query resources by execution group
az resource list --tag ExecutionGroup=e2e-full --output table
```