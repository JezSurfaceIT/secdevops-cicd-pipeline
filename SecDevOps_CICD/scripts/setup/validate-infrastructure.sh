#!/bin/bash
set -e

echo "======================================"
echo "Infrastructure Validation Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check status
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

# Check if we're logged into Azure
echo "→ Checking Azure login..."
az account show &>/dev/null
check_status $? "Azure CLI authenticated"

# Get environment from argument or default to dev
ENV=${1:-dev}
echo "→ Validating environment: $ENV"

# Check Resource Group
echo "→ Checking Resource Group..."
az group show --name "rg-secdevops-cicd-$ENV" &>/dev/null
check_status $? "Resource Group exists"

# Check Virtual Network
echo "→ Checking Virtual Network..."
az network vnet show \
    --resource-group "rg-secdevops-cicd-$ENV" \
    --name "vnet-secdevops-$ENV" &>/dev/null
check_status $? "Virtual Network exists"

# Check Subnets
echo "→ Checking Subnets..."
az network vnet subnet show \
    --resource-group "rg-secdevops-cicd-$ENV" \
    --vnet-name "vnet-secdevops-$ENV" \
    --name "snet-jenkins" &>/dev/null
check_status $? "Jenkins subnet exists"

az network vnet subnet show \
    --resource-group "rg-secdevops-cicd-$ENV" \
    --vnet-name "vnet-secdevops-$ENV" \
    --name "snet-containers" &>/dev/null
check_status $? "Containers subnet exists"

# Check NSG
echo "→ Checking Network Security Group..."
az network nsg show \
    --resource-group "rg-secdevops-cicd-$ENV" \
    --name "nsg-jenkins" &>/dev/null
check_status $? "Jenkins NSG exists"

# Check Jenkins VM
echo "→ Checking Jenkins VM..."
az vm show \
    --resource-group "rg-secdevops-cicd-$ENV" \
    --name "vm-jenkins-$ENV" &>/dev/null
check_status $? "Jenkins VM exists"

# Check VM is running
echo "→ Checking VM status..."
VM_STATUS=$(az vm get-instance-view \
    --resource-group "rg-secdevops-cicd-$ENV" \
    --name "vm-jenkins-$ENV" \
    --query "instanceView.statuses[?code=='PowerState/running']" \
    --output tsv)
if [ -n "$VM_STATUS" ]; then
    check_status 0 "Jenkins VM is running"
else
    check_status 1 "Jenkins VM is not running"
fi

# Check Public IP
echo "→ Checking Public IP..."
PUBLIC_IP=$(az network public-ip show \
    --resource-group "rg-secdevops-cicd-$ENV" \
    --name "pip-jenkins-$ENV" \
    --query "ipAddress" \
    --output tsv)
if [ -n "$PUBLIC_IP" ]; then
    check_status 0 "Public IP assigned: $PUBLIC_IP"
else
    check_status 1 "No public IP assigned"
fi

# Check FQDN
echo "→ Checking FQDN..."
FQDN=$(az network public-ip show \
    --resource-group "rg-secdevops-cicd-$ENV" \
    --name "pip-jenkins-$ENV" \
    --query "dnsSettings.fqdn" \
    --output tsv)
if [ -n "$FQDN" ]; then
    check_status 0 "FQDN configured: $FQDN"
else
    check_status 1 "No FQDN configured"
fi

# Test connectivity (if public IP is available)
if [ -n "$PUBLIC_IP" ]; then
    echo "→ Testing connectivity..."
    
    # Test SSH port
    timeout 5 nc -zv $PUBLIC_IP 22 &>/dev/null
    check_status $? "SSH port (22) is accessible"
    
    # Test Jenkins port
    timeout 5 nc -zv $PUBLIC_IP 8080 &>/dev/null
    if [ $? -eq 0 ]; then
        check_status 0 "Jenkins port (8080) is accessible"
    else
        echo -e "${YELLOW}!${NC} Jenkins port (8080) not accessible (Jenkins may not be installed yet)"
    fi
fi

echo "======================================"
echo "Validation Complete!"
echo "======================================"

if [ -n "$FQDN" ]; then
    echo ""
    echo "Access Points:"
    echo "  SSH: ssh azureuser@$FQDN"
    echo "  Jenkins: http://$FQDN:8080"
fi