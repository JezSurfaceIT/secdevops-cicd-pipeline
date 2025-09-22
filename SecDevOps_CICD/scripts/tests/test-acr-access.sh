#!/bin/bash
set -e

echo "======================================"
echo "Azure Container Registry Validation"
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
        return 0
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

# Get environment from argument or default to dev
ENV=${1:-dev}
ACR_NAME="acrsecdevops${ENV}"

echo "→ Validating ACR: $ACR_NAME"

# Check if logged into Azure
echo "→ Checking Azure login..."
az account show &>/dev/null
check_status $? "Azure CLI authenticated"

# Check ACR exists
echo "→ Checking ACR exists..."
az acr show --name $ACR_NAME &>/dev/null
check_status $? "ACR $ACR_NAME exists"

# Get ACR details
echo "→ Getting ACR details..."
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
if [ -n "$ACR_LOGIN_SERVER" ]; then
    check_status 0 "Login server: $ACR_LOGIN_SERVER"
else
    check_status 1 "Failed to get login server"
fi

# Check ACR SKU
echo "→ Checking ACR SKU..."
SKU=$(az acr show --name $ACR_NAME --query sku.name -o tsv)
if [ "$SKU" == "Premium" ]; then
    check_status 0 "SKU is Premium (required for advanced features)"
else
    check_status 1 "SKU is $SKU (should be Premium)"
fi

# Check geo-replication
echo "→ Checking geo-replication..."
REPLICATIONS=$(az acr replication list --registry-name $ACR_NAME --query "[].location" -o tsv | wc -l)
if [ $REPLICATIONS -gt 1 ]; then
    check_status 0 "Geo-replication configured ($REPLICATIONS locations)"
    az acr replication list --registry-name $ACR_NAME --query "[].{Location:location,Status:provisioningState}" -o table
else
    check_status 1 "No geo-replication configured"
fi

# Check retention policy
echo "→ Checking retention policy..."
RETENTION_ENABLED=$(az acr config retention show --registry $ACR_NAME --query status -o tsv)
if [ "$RETENTION_ENABLED" == "enabled" ]; then
    RETENTION_DAYS=$(az acr config retention show --registry $ACR_NAME --query days -o tsv)
    check_status 0 "Retention policy enabled ($RETENTION_DAYS days)"
else
    check_status 1 "Retention policy not enabled"
fi

# Check content trust
echo "→ Checking content trust..."
TRUST_POLICY=$(az acr config content-trust show --registry $ACR_NAME --query status -o tsv 2>/dev/null)
if [ "$TRUST_POLICY" == "enabled" ]; then
    check_status 0 "Content trust enabled"
else
    echo -e "${YELLOW}!${NC} Content trust status: $TRUST_POLICY"
fi

# Check tasks (for cleanup)
echo "→ Checking scheduled tasks..."
TASKS=$(az acr task list --registry $ACR_NAME --query "[].name" -o tsv | wc -l)
if [ $TASKS -gt 0 ]; then
    check_status 0 "Tasks configured ($TASKS tasks)"
    az acr task list --registry $ACR_NAME --query "[].{Name:name,Status:status}" -o table
else
    echo -e "${YELLOW}!${NC} No scheduled tasks configured"
fi

# Test with service principal (if credentials provided)
if [ -n "$JENKINS_SP_ID" ] && [ -n "$JENKINS_SP_PASSWORD" ]; then
    echo "→ Testing service principal access..."
    
    # Try to login with SP
    echo $JENKINS_SP_PASSWORD | docker login $ACR_LOGIN_SERVER \
        -u $JENKINS_SP_ID \
        --password-stdin &>/dev/null
    check_status $? "Service principal can login"
    
    # Test push capability
    echo "→ Testing push capability..."
    docker pull hello-world:latest &>/dev/null
    docker tag hello-world:latest $ACR_LOGIN_SERVER/test:validation
    docker push $ACR_LOGIN_SERVER/test:validation &>/dev/null
    check_status $? "Can push images to ACR"
    
    # Clean up test image
    az acr repository delete --name $ACR_NAME --repository test --yes &>/dev/null
else
    echo -e "${YELLOW}!${NC} Set JENKINS_SP_ID and JENKINS_SP_PASSWORD to test service principal"
fi

echo "======================================"
echo "ACR Validation Complete!"
echo "======================================"
echo ""
echo "ACR Details:"
echo "  Name: $ACR_NAME"
echo "  Login Server: $ACR_LOGIN_SERVER"
echo "  SKU: $SKU"
echo ""
echo "To login to ACR:"
echo "  az acr login --name $ACR_NAME"
echo ""
echo "To push an image:"
echo "  docker tag myimage:latest $ACR_LOGIN_SERVER/myimage:latest"
echo "  docker push $ACR_LOGIN_SERVER/myimage:latest"