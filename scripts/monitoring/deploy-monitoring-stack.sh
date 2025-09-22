#!/bin/bash

# Complete Monitoring Stack Deployment Script
# Deploys Prometheus + Grafana with all prerequisites checks

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Monitoring Stack Deployment Manager${NC}"
echo -e "${BLUE}================================================${NC}"

# Function to check command existence
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 is installed${NC}"
        return 0
    fi
}

# Function to check environment variable
check_env_var() {
    if [ -z "${!1}" ]; then
        echo -e "${RED}✗ $1 is not set${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 is set${NC}"
        return 0
    fi
}

echo -e "\n${YELLOW}Step 1: Checking Prerequisites${NC}"
echo "================================"

# Check required tools
TOOLS_OK=true
check_command "terraform" || TOOLS_OK=false
check_command "kubectl" || TOOLS_OK=false
check_command "az" || TOOLS_OK=false
check_command "helm" || TOOLS_OK=false
check_command "jq" || TOOLS_OK=false

if [ "$TOOLS_OK" = false ]; then
    echo -e "\n${RED}Missing required tools. Please install them first.${NC}"
    echo -e "${YELLOW}Installation commands:${NC}"
    echo "  Terraform: wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip"
    echo "  kubectl: az aks install-cli"
    echo "  Azure CLI: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    echo "  Helm: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    echo "  jq: sudo apt-get install jq"
    exit 1
fi

echo -e "\n${YELLOW}Step 2: Checking Azure Authentication${NC}"
echo "======================================"

# Check Azure login
if az account show &> /dev/null; then
    CURRENT_SUB=$(az account show --query name -o tsv)
    echo -e "${GREEN}✓ Logged into Azure (Subscription: $CURRENT_SUB)${NC}"
else
    echo -e "${RED}✗ Not logged into Azure${NC}"
    echo -e "${YELLOW}Please run: az login${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Step 3: Checking Environment Variables${NC}"
echo "======================================="

# Check required environment variables
ENV_OK=true
check_env_var "TF_VAR_azure_subscription_id" || ENV_OK=false
check_env_var "TF_VAR_azure_tenant_id" || ENV_OK=false
check_env_var "TF_VAR_azure_client_id" || ENV_OK=false
check_env_var "TF_VAR_azure_client_secret" || ENV_OK=false

if [ "$ENV_OK" = false ]; then
    echo -e "\n${RED}Missing required environment variables.${NC}"
    echo -e "${YELLOW}To create a service principal and set variables:${NC}"
    cat << 'EOF'
    
    # Create service principal
    az ad sp create-for-rbac \
      --name "e2e-terraform-sp" \
      --role Contributor \
      --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

    # Set environment variables
    export TF_VAR_azure_subscription_id="YOUR_SUBSCRIPTION_ID"
    export TF_VAR_azure_tenant_id="YOUR_TENANT_ID"
    export TF_VAR_azure_client_id="SERVICE_PRINCIPAL_CLIENT_ID"
    export TF_VAR_azure_client_secret="SERVICE_PRINCIPAL_SECRET"
EOF
    exit 1
fi

echo -e "\n${YELLOW}Step 4: Checking Kubernetes Cluster${NC}"
echo "===================================="

# Check kubectl connection
if kubectl get nodes &> /dev/null; then
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    echo -e "${GREEN}✓ Connected to Kubernetes cluster (${NODE_COUNT} nodes)${NC}"
    
    # Check if monitoring namespace exists
    if kubectl get namespace monitoring &> /dev/null; then
        echo -e "${YELLOW}  ⚠ Monitoring namespace already exists${NC}"
    fi
else
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo -e "${YELLOW}To connect to AKS cluster:${NC}"
    echo "  az aks get-credentials --resource-group e2e-dev-eus-secops-app-001 --name e2e-dev-eus-secops-aks-001"
    echo -e "${YELLOW}Or create a new cluster:${NC}"
    cat << 'EOF'
    az aks create \
      --resource-group e2e-dev-eus-secops-app-001 \
      --name e2e-dev-eus-secops-aks-001 \
      --node-count 3 \
      --node-vm-size Standard_D2s_v3 \
      --enable-rbac
EOF
    exit 1
fi

echo -e "\n${YELLOW}Step 5: Setting Default Passwords${NC}"
echo "=================================="

# Generate passwords if not set
if [ -z "$TF_VAR_grafana_admin_password" ]; then
    export TF_VAR_grafana_admin_password=$(openssl rand -base64 16)
    echo -e "${YELLOW}Generated Grafana admin password${NC}"
fi

if [ -z "$TF_VAR_grafana_db_password" ]; then
    export TF_VAR_grafana_db_password=$(openssl rand -base64 16)
    echo -e "${YELLOW}Generated Grafana DB password${NC}"
fi

if [ -z "$TF_VAR_grafana_db_reader_password" ]; then
    export TF_VAR_grafana_db_reader_password=$(openssl rand -base64 16)
    echo -e "${YELLOW}Generated Grafana DB reader password${NC}"
fi

if [ -z "$TF_VAR_cookie_secret" ]; then
    export TF_VAR_cookie_secret=$(openssl rand -base64 32)
    echo -e "${YELLOW}Generated cookie secret${NC}"
fi

# Set test OAuth values if not provided
if [ -z "$TF_VAR_oauth_client_id" ]; then
    export TF_VAR_oauth_client_id="test-client-id"
    export TF_VAR_oauth_client_secret="test-client-secret"
    echo -e "${YELLOW}Using test OAuth credentials (replace for production)${NC}"
fi

echo -e "\n${YELLOW}Step 6: Terraform Backend Setup${NC}"
echo "================================"

# Check if resource group exists
RG_EXISTS=$(az group exists --name e2e-dev-eus-secops-terraform-001)
if [ "$RG_EXISTS" = "false" ]; then
    echo -e "${YELLOW}Creating Terraform backend resource group...${NC}"
    az group create --name e2e-dev-eus-secops-terraform-001 --location eastus
fi

# Check if storage account exists
if ! az storage account show --name e2edevtfstate --resource-group e2e-dev-eus-secops-terraform-001 &> /dev/null; then
    echo -e "${YELLOW}Creating Terraform state storage account...${NC}"
    az storage account create \
        --resource-group e2e-dev-eus-secops-terraform-001 \
        --name e2edevtfstate \
        --sku Standard_LRS \
        --encryption-services blob
    
    az storage container create \
        --name tfstate \
        --account-name e2edevtfstate \
        --auth-mode login
fi

echo -e "${GREEN}✓ Terraform backend ready${NC}"

echo -e "\n${YELLOW}Step 7: Deployment Options${NC}"
echo "=========================="
echo -e "${BLUE}Ready to deploy the monitoring stack!${NC}"
echo ""
echo "Choose deployment option:"
echo "1) Deploy everything (Prometheus + Grafana + Dashboards)"
echo "2) Deploy Prometheus only"
echo "3) Deploy Grafana only"
echo "4) Validate configuration only (dry run)"
echo "5) Destroy deployment"
echo "6) Exit"
echo ""
read -p "Enter option (1-6): " option

cd infrastructure/terraform/monitoring

case $option in
    1)
        echo -e "\n${BLUE}Deploying complete monitoring stack...${NC}"
        terraform init
        terraform plan -out=tfplan
        echo -e "\n${YELLOW}Review the plan above. Deploy? (yes/no)${NC}"
        read -r response
        if [ "$response" = "yes" ]; then
            terraform apply tfplan
            echo -e "\n${GREEN}✓ Deployment complete!${NC}"
            
            # Show access information
            echo -e "\n${BLUE}Access Information:${NC}"
            echo "=================="
            kubectl get ingress -n monitoring
            echo ""
            echo "Port-forward commands:"
            echo "  Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
            echo "  Grafana: kubectl port-forward -n monitoring svc/grafana 3000:3000"
            echo ""
            echo "Credentials:"
            echo "  Grafana admin user: admin"
            echo "  Grafana admin password: $TF_VAR_grafana_admin_password"
        fi
        ;;
    2)
        echo -e "\n${BLUE}Deploying Prometheus only...${NC}"
        terraform init
        terraform plan -target=kubernetes_stateful_set.prometheus -out=tfplan
        terraform apply tfplan
        ;;
    3)
        echo -e "\n${BLUE}Deploying Grafana only...${NC}"
        terraform init
        terraform plan -target=kubernetes_stateful_set.grafana -out=tfplan
        terraform apply tfplan
        ;;
    4)
        echo -e "\n${BLUE}Running validation only...${NC}"
        terraform init
        terraform validate
        terraform plan
        ;;
    5)
        echo -e "\n${RED}WARNING: This will destroy all monitoring infrastructure!${NC}"
        echo "Type 'destroy' to confirm: "
        read -r confirm
        if [ "$confirm" = "destroy" ]; then
            terraform destroy
        fi
        ;;
    6)
        echo -e "\n${BLUE}Exiting...${NC}"
        exit 0
        ;;
    *)
        echo -e "\n${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}Script completed successfully!${NC}"