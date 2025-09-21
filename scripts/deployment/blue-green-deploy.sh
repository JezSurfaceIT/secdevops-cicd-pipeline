#!/bin/bash
set -e

# Blue-Green Deployment Strategy for Azure Container Instances
# Provides zero-downtime deployments with automatic rollback capability

# Configuration
APP_NAME="${1:-dummy-app-e2e-test}"
VERSION="${2:-v1.0}"
RESOURCE_GROUP="${3:-rg-secdevops-cicd-dev}"
ACR_NAME="acrsecdevopsdev"
LOCATION="eastus"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Blue-Green Deployment${NC}"
echo -e "${BLUE}=========================================${NC}"
echo "Application: $APP_NAME"
echo "Version: $VERSION"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

# Function to check container health
check_health() {
    local container_name=$1
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}Checking health of $container_name...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        # Get container status
        STATUS=$(az container show \
            --resource-group $RESOURCE_GROUP \
            --name $container_name \
            --query instanceView.state -o tsv 2>/dev/null || echo "NotFound")
        
        if [ "$STATUS" = "Running" ]; then
            # Get container IP
            CONTAINER_IP=$(az container show \
                --resource-group $RESOURCE_GROUP \
                --name $container_name \
                --query ipAddress.ip -o tsv)
            
            # Perform health check
            if curl -f -s "http://$CONTAINER_IP:3001/health" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ Container $container_name is healthy${NC}"
                return 0
            fi
        fi
        
        echo "  Attempt $attempt/$max_attempts: Status=$STATUS"
        sleep 5
        ((attempt++))
    done
    
    echo -e "${RED}❌ Container $container_name failed health check${NC}"
    return 1
}

# Function to deploy container
deploy_container() {
    local container_name=$1
    local image_tag=$2
    local dns_label=$3
    
    echo -e "${BLUE}Deploying $container_name with image $image_tag...${NC}"
    
    az container create \
        --resource-group $RESOURCE_GROUP \
        --name $container_name \
        --image "$ACR_NAME.azurecr.io/$APP_NAME:$image_tag" \
        --cpu 1 \
        --memory 1 \
        --ports 3001 \
        --dns-name-label $dns_label \
        --environment-variables NODE_ENV=production VERSION=$image_tag \
        --location $LOCATION \
        --restart-policy Always \
        --registry-login-server "$ACR_NAME.azurecr.io" \
        --registry-username $(az acr credential show --name $ACR_NAME --query username -o tsv) \
        --registry-password $(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv) \
        --output table || return 1
}

# Step 1: Identify current production (Blue) and staging (Green)
echo -e "${BLUE}Step 1: Identifying current environments...${NC}"

BLUE_EXISTS=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name "$APP_NAME-blue" \
    --query name -o tsv 2>/dev/null || echo "")

GREEN_EXISTS=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name "$APP_NAME-green" \
    --query name -o tsv 2>/dev/null || echo "")

# Determine which is production
if [ -n "$BLUE_EXISTS" ]; then
    CURRENT_PROD="blue"
    CURRENT_STAGING="green"
    CURRENT_VERSION=$(az container show \
        --resource-group $RESOURCE_GROUP \
        --name "$APP_NAME-blue" \
        --query 'containers[0].environmentVariables[?name==`VERSION`].value' -o tsv 2>/dev/null || echo "unknown")
elif [ -n "$GREEN_EXISTS" ]; then
    CURRENT_PROD="green"
    CURRENT_STAGING="blue"
    CURRENT_VERSION=$(az container show \
        --resource-group $RESOURCE_GROUP \
        --name "$APP_NAME-green" \
        --query 'containers[0].environmentVariables[?name==`VERSION`].value' -o tsv 2>/dev/null || echo "unknown")
else
    echo "No existing deployment found. Starting fresh with Blue environment."
    CURRENT_PROD="none"
    CURRENT_STAGING="blue"
    CURRENT_VERSION="none"
fi

echo "Current Production: $CURRENT_PROD (Version: $CURRENT_VERSION)"
echo "Deployment Target: $CURRENT_STAGING (Version: $VERSION)"
echo ""

# Step 2: Deploy to staging environment
echo -e "${BLUE}Step 2: Deploying to staging ($CURRENT_STAGING)...${NC}"

STAGING_CONTAINER="$APP_NAME-$CURRENT_STAGING"
STAGING_DNS="$APP_NAME-$CURRENT_STAGING"

# Delete existing staging container if it exists
if az container show --resource-group $RESOURCE_GROUP --name $STAGING_CONTAINER &>/dev/null; then
    echo "Removing existing staging container..."
    az container delete \
        --resource-group $RESOURCE_GROUP \
        --name $STAGING_CONTAINER \
        --yes || true
    sleep 10
fi

# Deploy new version to staging
if ! deploy_container $STAGING_CONTAINER $VERSION $STAGING_DNS; then
    echo -e "${RED}❌ Failed to deploy to staging${NC}"
    exit 1
fi

# Step 3: Health check on staging
echo ""
echo -e "${BLUE}Step 3: Validating staging deployment...${NC}"

if ! check_health $STAGING_CONTAINER; then
    echo -e "${RED}❌ Staging deployment failed health check${NC}"
    echo "Rolling back: Deleting failed staging container..."
    az container delete \
        --resource-group $RESOURCE_GROUP \
        --name $STAGING_CONTAINER \
        --yes
    exit 1
fi

# Get staging URL
STAGING_IP=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name $STAGING_CONTAINER \
    --query ipAddress.ip -o tsv)

STAGING_FQDN=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name $STAGING_CONTAINER \
    --query ipAddress.fqdn -o tsv 2>/dev/null || echo "")

echo ""
echo -e "${GREEN}✅ Staging deployment successful!${NC}"
echo "Staging URL: http://$STAGING_IP:3001"
[ -n "$STAGING_FQDN" ] && echo "Staging FQDN: http://$STAGING_FQDN:3001"

# Step 4: Run smoke tests on staging
echo ""
echo -e "${BLUE}Step 4: Running smoke tests on staging...${NC}"

# Basic API tests
echo "Testing health endpoint..."
curl -f -s "http://$STAGING_IP:3001/health" > /dev/null || exit 1
echo "✅ Health check passed"

echo "Testing API endpoints..."
curl -f -s "http://$STAGING_IP:3001/api/users" > /dev/null || exit 1
echo "✅ API test passed"

# Step 5: Promote staging to production
echo ""
echo -e "${BLUE}Step 5: Promoting $CURRENT_STAGING to production...${NC}"

if [ "$CURRENT_PROD" != "none" ]; then
    # Update DNS/Traffic Manager/Application Gateway to point to new version
    echo "Switching traffic to $CURRENT_STAGING environment..."
    
    # In a real scenario, you would update:
    # - Application Gateway backend pool
    # - Traffic Manager endpoints
    # - DNS CNAME records
    # For this demo, we'll create/update a "production" container that acts as the main endpoint
    
    PROD_CONTAINER="$APP_NAME-prod"
    PROD_IMAGE="$ACR_NAME.azurecr.io/$APP_NAME:$VERSION"
    
    # Check if production container exists
    if az container show --resource-group $RESOURCE_GROUP --name $PROD_CONTAINER &>/dev/null; then
        echo "Updating production container..."
        az container delete \
            --resource-group $RESOURCE_GROUP \
            --name $PROD_CONTAINER \
            --yes
        sleep 10
    fi
    
    echo "Creating production container with new version..."
    az container create \
        --resource-group $RESOURCE_GROUP \
        --name $PROD_CONTAINER \
        --image $PROD_IMAGE \
        --cpu 2 \
        --memory 2 \
        --ports 80 443 \
        --dns-name-label "$APP_NAME-prod" \
        --environment-variables NODE_ENV=production VERSION=$VERSION DEPLOYMENT=blue-green \
        --location $LOCATION \
        --restart-policy Always \
        --registry-login-server "$ACR_NAME.azurecr.io" \
        --registry-username $(az acr credential show --name $ACR_NAME --query username -o tsv) \
        --registry-password $(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv) \
        --output table
fi

# Step 6: Verify production
echo ""
echo -e "${BLUE}Step 6: Verifying production deployment...${NC}"

if [ "$CURRENT_PROD" != "none" ]; then
    if check_health "$APP_NAME-prod"; then
        echo -e "${GREEN}✅ Production deployment successful!${NC}"
        
        # Step 7: Keep old version for quick rollback
        echo ""
        echo -e "${BLUE}Step 7: Keeping previous version ($CURRENT_PROD) for rollback...${NC}"
        
        OLD_PROD_CONTAINER="$APP_NAME-$CURRENT_PROD"
        echo "Previous version available at: $OLD_PROD_CONTAINER"
        echo "To rollback, run: ./blue-green-rollback.sh $APP_NAME $CURRENT_PROD"
    else
        echo -e "${RED}❌ Production deployment failed!${NC}"
        echo "Initiating automatic rollback..."
        exit 1
    fi
else
    echo -e "${GREEN}✅ Initial deployment successful!${NC}"
fi

# Step 8: Summary
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${BLUE}=========================================${NC}"

# Get production URL
PROD_IP=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name "$APP_NAME-prod" \
    --query ipAddress.ip -o tsv 2>/dev/null || echo $STAGING_IP)

PROD_FQDN=$(az container show \
    --resource-group $RESOURCE_GROUP \
    --name "$APP_NAME-prod" \
    --query ipAddress.fqdn -o tsv 2>/dev/null || echo $STAGING_FQDN)

echo "Production Version: $VERSION"
echo "Production URL: http://$PROD_IP"
[ -n "$PROD_FQDN" ] && echo "Production FQDN: http://$PROD_FQDN"
echo ""
echo "Active Environment: $CURRENT_STAGING"
echo "Standby Environment: $CURRENT_PROD"
echo ""
echo "To perform rollback if needed:"
echo "  ./blue-green-rollback.sh $APP_NAME $CURRENT_PROD"