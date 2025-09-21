#!/bin/bash
# Terraform Deployment Script for SecDevOps Infrastructure
# Resource Group: rg-secdevops-cicd-dev

set -e

echo "========================================="
echo "SecDevOps Infrastructure Deployment"
echo "Resource Group: rg-secdevops-cicd-dev"
echo "========================================="

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform..."
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform
fi

# Check Azure CLI login
echo "Checking Azure authentication..."
if ! az account show &> /dev/null; then
    echo "Please login to Azure..."
    az login
fi

# Set subscription
az account set --subscription "80265df9-bba2-4ad2-88af-e002fd2ca230"

# Create state storage if it doesn't exist
echo "Setting up Terraform state storage..."
RG_STATE="rg-terraform-state"
STORAGE_ACCOUNT="tfstatesecdevops"

if ! az group show --name $RG_STATE &> /dev/null; then
    echo "Creating state resource group..."
    az group create --name $RG_STATE --location eastus
fi

if ! az storage account show --name $STORAGE_ACCOUNT --resource-group $RG_STATE &> /dev/null; then
    echo "Creating state storage account..."
    az storage account create \
        --name $STORAGE_ACCOUNT \
        --resource-group $RG_STATE \
        --location eastus \
        --sku Standard_LRS \
        --encryption-services blob
    
    az storage container create \
        --name tfstate \
        --account-name $STORAGE_ACCOUNT \
        --auth-mode login
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Format code
echo "Formatting Terraform code..."
terraform fmt -recursive

# Validate configuration
echo "Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "Planning infrastructure changes..."
terraform plan -out=tfplan

# Show what will be created
echo ""
echo "Resources to be created/modified:"
terraform show -json tfplan | jq '.resource_changes[] | {address: .address, action: .change.actions}'

echo ""
read -p "Do you want to apply these changes? (yes/no): " -r
if [[ $REPLY =~ ^[Yy]es$ ]]; then
    echo "Applying Terraform configuration..."
    terraform apply tfplan
    
    echo ""
    echo "========================================="
    echo "Deployment Complete!"
    echo "========================================="
    echo "Resource Group: rg-secdevops-cicd-dev"
    echo ""
    echo "Key Outputs:"
    terraform output -json | jq -r 'to_entries[] | "\(.key): \(.value.value)"'
    
    echo ""
    echo "To destroy infrastructure later, run:"
    echo "  terraform destroy"
else
    echo "Deployment cancelled."
    rm tfplan
fi