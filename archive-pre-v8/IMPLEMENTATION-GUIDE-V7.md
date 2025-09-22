# SecDevOps CI/CD Implementation Guide - Based on V7 Architecture
## Complete Deployment Instructions

**Version:** 1.0  
**Date:** 2025-09-21  
**Architecture:** V7 Comprehensive

---

## 📋 Implementation Overview

This guide provides step-by-step instructions to implement the complete SecDevOps CI/CD architecture as defined in Version 7.

---

## Phase 1: Network Foundation

### 1.1 Create Unified VNet with IP Restrictions

```bash
#!/bin/bash
# scripts/deploy/01-create-network-foundation.sh

set -e

echo "🔒 Phase 1: Network Foundation"

# Create resource group
RESOURCE_GROUP="rg-oversight-unified"
LOCATION="uksouth"

az group create --name $RESOURCE_GROUP --location $LOCATION

# Create unified VNet (10.0.0.0/16)
az network vnet create \
    --name vnet-unified \
    --resource-group $RESOURCE_GROUP \
    --address-prefix 10.0.0.0/8

# Create subnets as per V7 architecture
SUBNETS=(
    "AzureFirewallSubnet:10.10.0.0/26"        # 811: Firewall
    "AzureBastionSubnet:10.10.1.0/24"         # 812: Bastion
    "subnet-saas-app:10.20.2.0/24"            # 701: SaaS App
    "subnet-saas-db:10.20.3.0/24"             # 711: PostgreSQL
    "subnet-saas-storage:10.20.4.0/24"        # 712: Storage
    "subnet-saas-redis:10.20.5.0/24"          # 713: Redis
    "subnet-saas-keyvault:10.20.6.0/24"       # 714: Key Vault
    "subnet-saas-tenant:10.20.7.0/24"         # 729: Future Tenant Router
    "subnet-test-app:10.40.1.0/24"            # 401: Test Container
    "subnet-test-vault:10.40.2.0/24"          # 303: Test Vault
    "subnet-dev-avd:10.60.1.0/24"             # 103: AVD
    "subnet-dev-jenkins:10.60.2.0/24"         # 301,501: Jenkins
    "subnet-dev-acr:10.60.3.0/24"             # 308: ACR
    "subnet-cbe-mimic:10.80.1.0/24"           # 860: CBE Mimic
    "subnet-cbe-vault:10.80.2.0/24"           # 871: CBE Vault
    "subnet-cbe-db:10.80.3.0/24"              # 872: CBE PostgreSQL
    "subnet-cbe-portal:10.80.4.0/24"          # 902: Customer Portal
    "subnet-cbe-guac:10.80.5.0/24"            # 873: Guacamole
    "subnet-monitoring:10.90.1.0/24"           # 1001-1005: Monitoring
)

for SUBNET in "${SUBNETS[@]}"; do
    NAME="${SUBNET%%:*}"
    PREFIX="${SUBNET#*:}"
    echo "Creating subnet: $NAME ($PREFIX)"
    
    az network vnet subnet create \
        --name $NAME \
        --resource-group $RESOURCE_GROUP \
        --vnet-name vnet-unified \
        --address-prefix $PREFIX
done

echo "✅ Network foundation created"
```

### 1.2 Configure IP Security Gateway (800-803)

```bash
#!/bin/bash
# scripts/deploy/02-configure-security-gateway.sh

set -e

echo "🔐 Configuring IP Security Gateway"

RESOURCE_GROUP="rg-oversight-unified"
NSG_NAME="nsg-ip-allowlist"
WAF_POLICY="waf-policy-main"
APP_GW_NAME="appgw-main"

# Component 801: Create IP Allowlist NSG
az network nsg create \
    --resource-group $RESOURCE_GROUP \
    --name $NSG_NAME \
    --location uksouth

# Add allowed IPs only
ALLOWED_IPS=(
    "GitHub-Webhooks:140.82.112.0/20"
    "GitHub-Webhooks2:143.55.64.0/20"
    "Azure-DevOps:13.107.6.0/24"
    "Admin-IP:YOUR_ADMIN_IP/32"
)

PRIORITY=100
for RULE in "${ALLOWED_IPS[@]}"; do
    NAME="${RULE%%:*}"
    IP="${RULE#*:}"
    
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $NSG_NAME \
        --name "Allow-$NAME" \
        --priority $PRIORITY \
        --source-address-prefixes "$IP" \
        --destination-port-ranges 443 80 \
        --access Allow \
        --protocol Tcp
    
    PRIORITY=$((PRIORITY + 10))
done

# Deny all other traffic
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name $NSG_NAME \
    --name DenyAll \
    --priority 4096 \
    --source-address-prefixes '*' \
    --destination-port-ranges '*' \
    --access Deny \
    --protocol '*'

# Component 802: Create WAF Policy
az network application-gateway waf-policy create \
    --name $WAF_POLICY \
    --resource-group $RESOURCE_GROUP \
    --location uksouth \
    --type OWASP \
    --version 3.2

# Component 803: Create Application Gateway
az network public-ip create \
    --name pip-appgw \
    --resource-group $RESOURCE_GROUP \
    --allocation-method Static \
    --sku Standard

az network application-gateway create \
    --name $APP_GW_NAME \
    --resource-group $RESOURCE_GROUP \
    --vnet-name vnet-unified \
    --subnet subnet-appgw \
    --public-ip-address pip-appgw \
    --sku WAF_v2 \
    --capacity 2 \
    --waf-policy $WAF_POLICY

echo "✅ Security gateway configured with IP allowlist"
```

---

## Phase 2: Development & CI/CD Setup

### 2.1 Deploy Jenkins CI/CD (301, 501)

```bash
#!/bin/bash
# scripts/deploy/03-deploy-jenkins.sh

set -e

echo "🔧 Deploying Jenkins CI/CD"

# Component 301: Main Jenkins
az vm create \
    --resource-group rg-oversight-unified \
    --name vm-jenkins-main \
    --image UbuntuLTS \
    --size Standard_D4s_v3 \
    --subnet subnet-dev-jenkins \
    --private-ip-address 10.60.2.10 \
    --public-ip-address "" \
    --admin-username jenkins \
    --generate-ssh-keys

# Component 501: Test Jenkins
az vm create \
    --resource-group rg-oversight-unified \
    --name vm-jenkins-test \
    --image UbuntuLTS \
    --size Standard_D2s_v3 \
    --subnet subnet-dev-jenkins \
    --private-ip-address 10.60.2.20 \
    --public-ip-address "" \
    --admin-username jenkins \
    --generate-ssh-keys

# Install Jenkins on both VMs
for VM in vm-jenkins-main vm-jenkins-test; do
    az vm run-command invoke \
        --resource-group rg-oversight-unified \
        --name $VM \
        --command-id RunShellScript \
        --scripts @jenkins-install.sh
done

echo "✅ Jenkins deployed"
```

### 2.2 Configure Security Scanning Suite (307.1-307.7)

```bash
#!/bin/bash
# scripts/deploy/04-configure-security-tools.sh

set -e

echo "🛡️ Configuring Security Scanning Suite"

# Create container instances for security tools
SECURITY_TOOLS=(
    "trufflehog:trufflesecurity/trufflehog:latest"
    "sonarqube:sonarqube:9-community"
    "trivy:aquasec/trivy:latest"
    "checkov:bridgecrew/checkov:latest"
)

for TOOL in "${SECURITY_TOOLS[@]}"; do
    NAME="${TOOL%%:*}"
    IMAGE="${TOOL#*:}"
    
    az container create \
        --resource-group rg-oversight-unified \
        --name "aci-$NAME" \
        --image "$IMAGE" \
        --cpu 2 \
        --memory 4 \
        --subnet subnet-dev-jenkins \
        --restart-policy OnFailure
done

# Configure Jenkins pipelines
cat > Jenkinsfile-security << 'EOF'
pipeline {
    agent any
    stages {
        stage('307.1: TruffleHog') {
            steps {
                sh 'trufflehog git https://github.com/your-repo --json'
            }
        }
        stage('307.2: SonarQube') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'sonar-scanner'
                }
            }
        }
        stage('307.3: Snyk') {
            steps {
                sh 'snyk test --all-projects'
            }
        }
        stage('307.4: Semgrep') {
            steps {
                sh 'semgrep --config=auto .'
            }
        }
        stage('307.5: Trivy') {
            steps {
                sh 'trivy image ${IMAGE_NAME}'
            }
        }
        stage('307.6: Checkov') {
            steps {
                sh 'checkov -d . --framework terraform'
            }
        }
        stage('307.7: GitLeaks') {
            steps {
                sh 'gitleaks detect --source . -v'
            }
        }
    }
}
EOF

echo "✅ Security scanning suite configured"
```

---

## Phase 3: Test Environment Setup

### 3.1 Deploy Test Environment with 3 DB States (401, 411-413)

```bash
#!/bin/bash
# scripts/deploy/05-deploy-test-environment.sh

set -e

echo "🧪 Deploying Test Environment"

# Component 401: Test Container Instance
az container create \
    --resource-group rg-oversight-unified \
    --name aci-test-app \
    --image acrsecdevopsdev.azurecr.io/oversight-mvp:test \
    --cpu 4 \
    --memory 8 \
    --subnet subnet-test-app \
    --ip-address Private \
    --environment-variables \
        NODE_ENV=test \
        VAULT_ADDR=http://10.40.2.10:8200

# Components 411-413: Create 3 DB States
DB_SERVER="psql-test-oversight"
az postgres server create \
    --resource-group rg-oversight-unified \
    --name $DB_SERVER \
    --location uksouth \
    --admin-user testadmin \
    --admin-password "$(openssl rand -base64 32)" \
    --sku-name B_Gen5_2

# Create 3 databases for different states
for i in 1 2 3; do
    case $i in
        1) DB_NAME="test_schema_only" ;;
        2) DB_NAME="test_framework_data" ;;
        3) DB_NAME="test_full_data" ;;
    esac
    
    az postgres db create \
        --resource-group rg-oversight-unified \
        --server-name $DB_SERVER \
        --name $DB_NAME
done

# Script to switch DB states
cat > switch-db-state.sh << 'EOF'
#!/bin/bash
STATE=$1
case $STATE in
    1) export DATABASE_URL="postgresql://...test_schema_only" ;;
    2) export DATABASE_URL="postgresql://...test_framework_data" ;;
    3) export DATABASE_URL="postgresql://...test_full_data" ;;
esac
echo "Switched to DB State $STATE"
EOF

chmod +x switch-db-state.sh

echo "✅ Test environment deployed with 3 DB states"
```

### 3.2 Configure Test Execution Suite (511-514)

```bash
#!/bin/bash
# scripts/deploy/06-configure-test-suite.sh

set -e

echo "🎯 Configuring Test Execution Suite"

# Component 511: Playwright
npm install -g @playwright/test
npx playwright install

# Component 512: Jest
npm install -g jest @types/jest

# Component 513-514: Test configurations
cat > test-config.json << 'EOF'
{
  "playwright": {
    "baseURL": "http://10.40.1.10:3000",
    "use": {
      "headless": true,
      "viewport": { "width": 1280, "height": 720 }
    }
  },
  "jest": {
    "testEnvironment": "node",
    "coverageDirectory": "coverage",
    "collectCoverageFrom": ["src/**/*.js"]
  },
  "api": {
    "baseURL": "http://10.40.1.10:3000/api",
    "timeout": 30000
  }
}
EOF

echo "✅ Test suite configured"
```

---

## Phase 4: Production Deployment

### 4.1 Deploy SaaS Production (701, 714)

```bash
#!/bin/bash
# scripts/deploy/07-deploy-saas-production.sh

set -e

echo "🚀 Deploying SaaS Production"

RESOURCE_GROUP="rg-oversight-unified"

# Component 714: Create Azure Key Vault
az keyvault create \
    --name kv-oversight-prod \
    --resource-group $RESOURCE_GROUP \
    --location uksouth \
    --sku standard \
    --network-acls-ips ""

# Component 701: Deploy single SaaS App
az webapp create \
    --resource-group $RESOURCE_GROUP \
    --plan asp-oversight-prod \
    --name app-oversight-saas \
    --runtime "NODE|18-lts" \
    --deployment-container-image-name acrsecdevopsdev.azurecr.io/oversight-mvp:prod

# Configure app to use Key Vault (714)
az webapp config appsettings set \
    --resource-group $RESOURCE_GROUP \
    --name app-oversight-saas \
    --settings \
        KEY_VAULT_URI="https://kv-oversight-prod.vault.azure.net/" \
        MANAGED_IDENTITY="true"

# Enable managed identity
az webapp identity assign \
    --resource-group $RESOURCE_GROUP \
    --name app-oversight-saas

# Grant Key Vault access
IDENTITY=$(az webapp identity show --resource-group $RESOURCE_GROUP --name app-oversight-saas --query principalId -o tsv)
az keyvault set-policy \
    --name kv-oversight-prod \
    --object-id $IDENTITY \
    --secret-permissions get list

# Component 711-713: Supporting services
az postgres server create \
    --resource-group $RESOURCE_GROUP \
    --name pg-oversight-prod \
    --location uksouth \
    --admin-user prodadmin \
    --admin-password "$(openssl rand -base64 32)" \
    --sku-name GP_Gen5_4

az storage account create \
    --name stoversightprod \
    --resource-group $RESOURCE_GROUP \
    --location uksouth \
    --sku Standard_LRS \
    --kind StorageV2

az redis create \
    --name redis-oversight-prod \
    --resource-group $RESOURCE_GROUP \
    --location uksouth \
    --sku Basic \
    --vm-size c0

echo "✅ SaaS Production deployed with Key Vault"
```

### 4.2 Setup CBE Package Distribution (901-902, 860)

```bash
#!/bin/bash
# scripts/deploy/08-setup-cbe-distribution.sh

set -e

echo "📦 Setting up CBE Package Distribution"

# Component 901: Package Builder
cat > build-cbe-package.sh << 'EOF'
#!/bin/bash
VERSION=$1
OUTPUT_DIR="./cbe-packages"

mkdir -p $OUTPUT_DIR/$VERSION

# Component 911-914: Package components
cp -r vault-config/ $OUTPUT_DIR/$VERSION/
cp -r postgres-scripts/ $OUTPUT_DIR/$VERSION/
cp docker-compose.cbe.yml $OUTPUT_DIR/$VERSION/
cp deploy-cbe.sh $OUTPUT_DIR/$VERSION/

# Create package
tar -czf $OUTPUT_DIR/cbe-package-$VERSION.tar.gz -C $OUTPUT_DIR/$VERSION .

echo "CBE Package created: cbe-package-$VERSION.tar.gz"
EOF

# Component 902: Customer Portal
az webapp create \
    --resource-group rg-oversight-unified \
    --plan asp-oversight-portal \
    --name app-customer-portal \
    --runtime "NODE|18-lts"

# Component 860: CBE Mimic for testing
az container create \
    --resource-group rg-oversight-unified \
    --name aci-cbe-mimic \
    --image acrsecdevopsdev.azurecr.io/oversight-cbe:latest \
    --cpu 4 \
    --memory 8 \
    --subnet subnet-cbe-mimic \
    --ip-address Private \
    --environment-variables \
        ENVIRONMENT=cbe-mimic \
        VAULT_ADDR=http://10.80.2.10:8200

echo "✅ CBE distribution configured"
```

---

## Phase 5: Monitoring & Feedback

### 5.1 Deploy Monitoring Stack (1001-1005)

```bash
#!/bin/bash
# scripts/deploy/09-deploy-monitoring.sh

set -e

echo "📊 Deploying Monitoring Stack"

# Component 1001: Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace

# Component 1002: Grafana
az container create \
    --resource-group rg-oversight-unified \
    --name aci-grafana \
    --image grafana/grafana:latest \
    --cpu 2 \
    --memory 4 \
    --subnet subnet-monitoring \
    --ports 3000 \
    --environment-variables \
        GF_SECURITY_ADMIN_PASSWORD="$(openssl rand -base64 32)"

# Component 1005: Azure Log Analytics
az monitor log-analytics workspace create \
    --resource-group rg-oversight-unified \
    --workspace-name law-oversight \
    --location uksouth

echo "✅ Monitoring stack deployed"
```

### 5.2 Configure Feedback Loops (531-534)

```bash
#!/bin/bash
# scripts/deploy/10-configure-feedback.sh

set -e

echo "🔄 Configuring Feedback Loops"

# Components 531-534: Azure DevOps integration
cat > configure-azure-devops.sh << 'EOF'
#!/bin/bash

# Create Azure DevOps project
az devops project create --name "Oversight-MVP" --org "https://dev.azure.com/your-org"

# Create boards for feedback
az boards area project create --name "App-Bugs" --project "Oversight-MVP"
az boards area project create --name "Env-Issues" --project "Oversight-MVP"
az boards area project create --name "Test-Debt" --project "Oversight-MVP"

# Configure webhooks for automated ticket creation
az devops service-endpoint create \
    --service-endpoint-type generic \
    --name "Test-Feedback-Webhook" \
    --project "Oversight-MVP"
EOF

echo "✅ Feedback loops configured"
```

---

## 🚀 Quick Start Commands

```bash
# Complete deployment
./scripts/deploy/deploy-all.sh

# Verify deployment
./scripts/verify/check-all-components.sh

# Run security scans
./scripts/security/run-full-scan.sh

# Execute test suite
./scripts/test/run-all-tests.sh
```

---

## ✅ Deployment Checklist

### Network & Security
- [ ] Unified VNet created (10.0.0.0/8)
- [ ] IP allowlist configured (801)
- [ ] WAF enabled (802)
- [ ] Application Gateway deployed (803)
- [ ] Azure Firewall active (811)

### Development & CI/CD
- [ ] Jenkins Main deployed (301)
- [ ] Jenkins Test deployed (501)
- [ ] Security tools configured (307.1-307.7)
- [ ] ACR accessible (308)
- [ ] GitHub webhooks configured (201)

### Test Environment
- [ ] Test container running (401)
- [ ] 3 DB states available (411-413)
- [ ] HashiCorp Vault for test (303)
- [ ] Test suites configured (511-514)
- [ ] VNC access available (520)

### Production
- [ ] Single SaaS app deployed (701)
- [ ] Key Vault configured (714)
- [ ] PostgreSQL running (711)
- [ ] Redis cache active (713)
- [ ] Storage account ready (712)

### CBE & Distribution
- [ ] Package builder ready (901)
- [ ] Customer portal live (902)
- [ ] CBE Mimic for testing (860)
- [ ] Package components prepared (911-914)

### Monitoring & Feedback
- [ ] Prometheus collecting metrics (1001)
- [ ] Grafana dashboards configured (1002)
- [ ] Log Analytics workspace (1005)
- [ ] Azure DevOps boards created (532-534)

---

## 🔧 Troubleshooting

### Common Issues

1. **IP not allowed through gateway**
   ```bash
   ./scripts/security/add-ip-to-allowlist.sh "YOUR_IP/32"
   ```

2. **Test DB state switching**
   ```bash
   ./scripts/test/switch-db-state.sh 2  # Switch to framework data
   ```

3. **Security scan failures**
   ```bash
   ./scripts/security/check-scan-logs.sh
   ```

---

This implementation guide follows the V7 architecture exactly, with all components numbered and properly configured.