#!/bin/bash
set -e

# Blue-Green Rollback Script
# Quickly switches back to the previous version in case of issues

APP_NAME="${1:-dummy-app-e2e-test}"
TARGET_ENV="${2:-blue}"  # Environment to rollback to (blue or green)
RESOURCE_GROUP="${3:-rg-secdevops-cicd-dev}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}Blue-Green Rollback${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo "Application: $APP_NAME"
echo "Rolling back to: $TARGET_ENV"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

# Step 1: Verify target environment exists and is healthy
echo -e "${BLUE}Step 1: Verifying $TARGET_ENV environment...${NC}"

TARGET_CONTAINER="$APP_NAME-$TARGET_ENV"

if ! az container show --resource-group $RESOURCE_GROUP --name $TARGET_CONTAINER &>/dev/null; then
    echo -e "${RED}❌ Error: $TARGET_ENV environment does not exist!${NC}"
    exit 1
fi

# Get target version
TARGET_VERSION=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name $TARGET_CONTAINER \
    --query 'containers[0].environmentVariables[?name==`VERSION`].value' -o tsv 2>/dev/null || echo "unknown")

echo "Target version: $TARGET_VERSION"

# Check health
TARGET_IP=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name $TARGET_CONTAINER \
    --query ipAddress.ip -o tsv)

echo "Checking health of $TARGET_CONTAINER..."
if ! curl -f -s "http://$TARGET_IP:3001/health" > /dev/null 2>&1; then
    echo -e "${RED}❌ Warning: $TARGET_ENV environment is not healthy!${NC}"
    read -p "Continue with rollback anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Rollback cancelled."
        exit 1
    fi
else
    echo -e "${GREEN}✅ $TARGET_ENV environment is healthy${NC}"
fi

# Step 2: Update production to point to target environment
echo ""
echo -e "${BLUE}Step 2: Switching production to $TARGET_ENV...${NC}"

PROD_CONTAINER="$APP_NAME-prod"
ACR_NAME="acrsecdevopsdev"

# Get image from target environment
TARGET_IMAGE=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name $TARGET_CONTAINER \
    --query 'containers[0].image' -o tsv)

echo "Rolling back to image: $TARGET_IMAGE"

# Update production container
if az container show --resource-group $RESOURCE_GROUP --name $PROD_CONTAINER &>/dev/null; then
    echo "Updating production container..."
    az container delete \
        --resource-group $RESOURCE_GROUP \
        --name $PROD_CONTAINER \
        --yes
    sleep 10
fi

echo "Recreating production with rollback version..."
az container create \
    --resource-group $RESOURCE_GROUP \
    --name $PROD_CONTAINER \
    --image $TARGET_IMAGE \
    --cpu 2 \
    --memory 2 \
    --ports 80 443 \
    --dns-name-label "$APP_NAME-prod" \
    --environment-variables NODE_ENV=production VERSION=$TARGET_VERSION DEPLOYMENT=rollback \
    --location eastus \
    --restart-policy Always \
    --registry-login-server "$ACR_NAME.azurecr.io" \
    --registry-username $(az acr credential show --name $ACR_NAME --query username -o tsv) \
    --registry-password $(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv) \
    --output table

# Step 3: Verify rollback
echo ""
echo -e "${BLUE}Step 3: Verifying rollback...${NC}"

# Wait for container to be ready
sleep 20

# Check health
PROD_IP=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name $PROD_CONTAINER \
    --query ipAddress.ip -o tsv)

if curl -f -s "http://$PROD_IP/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Rollback successful!${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Production health check failed after rollback${NC}"
fi

# Step 4: Summary
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}Rollback Complete!${NC}"
echo -e "${BLUE}=========================================${NC}"

PROD_FQDN=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name $PROD_CONTAINER \
    --query ipAddress.fqdn -o tsv 2>/dev/null || echo "")

echo "Production Version: $TARGET_VERSION (rolled back)"
echo "Production URL: http://$PROD_IP"
[ -n "$PROD_FQDN" ] && echo "Production FQDN: http://$PROD_FQDN"
echo ""
echo -e "${YELLOW}Note: The failed deployment is still available for debugging${NC}"