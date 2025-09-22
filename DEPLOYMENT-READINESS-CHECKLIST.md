# 🚀 Deployment Readiness Checklist

## Components Ready for Deployment

### ✅ Monitoring Stack (Stories 6.1 & 6.2)
- **Prometheus** - Metrics collection (96% test coverage)
- **Grafana** - Dashboard visualization (100% test coverage)
- **Thanos** - Long-term metrics storage
- **OAuth2 Proxy** - Authentication layer

## 📋 Pre-Deployment Requirements

### 1. Azure Prerequisites ✋ REQUIRED
```bash
# Azure CLI login
az login

# Set subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create resource group (if not exists)
az group create \
  --name e2e-dev-eus-secops-app-001 \
  --location eastus
```

### 2. Kubernetes Cluster ✋ REQUIRED
```bash
# Option A: Use existing AKS cluster
az aks get-credentials \
  --resource-group e2e-dev-eus-secops-app-001 \
  --name e2e-dev-eus-secops-aks-001

# Option B: Create new AKS cluster
az aks create \
  --resource-group e2e-dev-eus-secops-app-001 \
  --name e2e-dev-eus-secops-aks-001 \
  --node-count 3 \
  --node-vm-size Standard_D2s_v3 \
  --enable-rbac \
  --generate-ssh-keys

# Verify kubectl access
kubectl get nodes
```

### 3. Service Principal Setup ✋ REQUIRED
```bash
# Create service principal for Terraform
az ad sp create-for-rbac \
  --name "e2e-terraform-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --output json > sp-credentials.json

# Extract and export credentials
export TF_VAR_azure_subscription_id="YOUR_SUBSCRIPTION_ID"
export TF_VAR_azure_tenant_id="YOUR_TENANT_ID"
export TF_VAR_azure_client_id="SERVICE_PRINCIPAL_CLIENT_ID"
export TF_VAR_azure_client_secret="SERVICE_PRINCIPAL_SECRET"
```

### 4. Terraform Backend Setup ✋ REQUIRED
```bash
# Create storage account for Terraform state
az storage account create \
  --resource-group e2e-dev-eus-secops-terraform-001 \
  --name e2edevtfstate \
  --sku Standard_LRS \
  --encryption-services blob

# Create blob container
az storage container create \
  --name tfstate \
  --account-name e2edevtfstate

# Get storage key
ACCOUNT_KEY=$(az storage account keys list \
  --resource-group e2e-dev-eus-secops-terraform-001 \
  --account-name e2edevtfstate \
  --query '[0].value' -o tsv)

export ARM_ACCESS_KEY=$ACCOUNT_KEY
```

### 5. Install Required Tools ✋ REQUIRED
```bash
# Terraform
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# kubectl (if not installed)
az aks install-cli
```

## 🔐 Secrets Configuration

### Required Secrets
```bash
# Prometheus/Grafana passwords
export TF_VAR_grafana_admin_password="GENERATE_STRONG_PASSWORD"
export TF_VAR_grafana_db_password="GENERATE_STRONG_PASSWORD"
export TF_VAR_grafana_db_reader_password="GENERATE_STRONG_PASSWORD"

# OAuth2 configuration (for Azure AD SSO)
export TF_VAR_oauth_client_id="YOUR_AZURE_APP_CLIENT_ID"
export TF_VAR_oauth_client_secret="YOUR_AZURE_APP_SECRET"
export TF_VAR_cookie_secret=$(openssl rand -base64 32)

# Storage keys (generated automatically if using deploy.sh)
export TF_VAR_azure_storage_key="WILL_BE_GENERATED"
```

## 📦 Deployment Steps

### Step 1: Initialize Terraform
```bash
cd infrastructure/terraform/monitoring

# Initialize Terraform
terraform init
```

### Step 2: Review Plan
```bash
# Create execution plan
terraform plan -out=tfplan

# Review what will be created
terraform show tfplan
```

### Step 3: Deploy Infrastructure
```bash
# Option A: Use the deployment script (recommended)
./deploy.sh

# Option B: Manual deployment
terraform apply tfplan
```

### Step 4: Verify Deployment
```bash
# Check Kubernetes resources
kubectl get all -n monitoring

# Check pods are running
kubectl get pods -n monitoring

# Check services
kubectl get svc -n monitoring

# Get Grafana URL
kubectl get ingress -n monitoring
```

### Step 5: Access Services
```bash
# Port-forward for local access (if ingress not configured)
# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Access URLs
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000"
```

## ⚠️ Current Blockers

### Missing Infrastructure
1. **AKS Cluster** - Need Kubernetes cluster deployed
2. **Resource Groups** - Need Azure resource groups created
3. **Networking** - VNet, Subnets, NSGs not configured
4. **DNS** - Domain configuration for ingress

### Missing Configurations
1. **TLS Certificates** - Need real certificates (currently generates self-signed)
2. **Azure AD App Registration** - For SSO authentication
3. **PostgreSQL Database** - For Grafana backend
4. **Blob Storage** - For Thanos long-term storage

## 🔧 Quick Deployment Script

Create `deploy-monitoring-stack.sh`:
```bash
#!/bin/bash
set -e

# Check prerequisites
echo "Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "Terraform required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl required"; exit 1; }
command -v az >/dev/null 2>&1 || { echo "Azure CLI required"; exit 1; }

# Check Azure login
az account show >/dev/null 2>&1 || { echo "Please run 'az login'"; exit 1; }

# Check Kubernetes access
kubectl get nodes >/dev/null 2>&1 || { echo "No Kubernetes cluster access"; exit 1; }

# Deploy
cd infrastructure/terraform/monitoring
./deploy.sh
```

## 📊 Post-Deployment Validation

```bash
# Run deployment tests
./tests/monitoring/prometheus/prometheus_deployment_test.sh
./tests/monitoring/grafana/grafana_deployment_test.sh

# Check metrics collection
curl http://localhost:9090/api/v1/targets

# Check Grafana datasources
curl http://localhost:3000/api/datasources
```

## 🆘 Troubleshooting

### Common Issues
1. **Pods not starting**: Check resource limits, node capacity
2. **Storage issues**: Verify StorageClass exists
3. **Network policies**: Ensure communication between components
4. **Authentication failures**: Verify Azure AD configuration

### Debug Commands
```bash
# Check pod logs
kubectl logs -n monitoring <pod-name>

# Describe pod for events
kubectl describe pod -n monitoring <pod-name>

# Check persistent volumes
kubectl get pv
kubectl get pvc -n monitoring

# Check secrets
kubectl get secrets -n monitoring
```

## 📝 Next Steps After Deployment

1. **Configure Alerts**: Set up alert rules in Prometheus
2. **Import Dashboards**: Load pre-built dashboards into Grafana
3. **Setup Backup**: Configure backup for persistent data
4. **Performance Tuning**: Adjust resource limits based on load
5. **Security Hardening**: Enable network policies, RBAC

---

**IMPORTANT**: Most components are IaC-ready but require the underlying Azure/Kubernetes infrastructure to be in place first. Start with creating the AKS cluster and resource groups.