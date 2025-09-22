#!/bin/bash

# Blue-Green Deployment Script
# Usage: ./deploy-blue-green.sh <target-slot> <version> [package-path]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-secdevops-rg}"
APP_NAME="app-oversight-prod"
HEALTH_CHECK_RETRIES=10
HEALTH_CHECK_INTERVAL=30

# Function to print colored output
log() {
    echo -e "${2:-$NC}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to check health endpoint
check_health() {
    local url=$1
    local max_retries=$2
    local interval=$3
    
    log "🏥 Checking health at: $url" "$BLUE"
    
    for i in $(seq 1 $max_retries); do
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url/health" || echo "000")
        
        if [ "$response" == "200" ]; then
            log "✅ Health check passed (attempt $i/$max_retries)" "$GREEN"
            return 0
        else
            log "⏳ Health check failed (attempt $i/$max_retries) - HTTP $response" "$YELLOW"
            if [ $i -lt $max_retries ]; then
                sleep $interval
            fi
        fi
    done
    
    log "❌ Health checks failed after $max_retries attempts" "$RED"
    return 1
}

# Function to get current traffic distribution
get_traffic_distribution() {
    az network application-gateway rule show \
        --gateway-name "appgw-secdevops" \
        --resource-group "$RESOURCE_GROUP" \
        --name "routing-rule" \
        --query "backendAddressPool.id" -o tsv 2>/dev/null || echo ""
}

# Function to deploy to slot
deploy_to_slot() {
    local slot=$1
    local version=$2
    local package=$3
    
    if [ "$slot" == "blue" ]; then
        local app_resource="$APP_NAME-blue"
        log "🚀 Deploying $version to BLUE slot (Production)" "$BLUE"
    else
        local app_resource="$APP_NAME-blue/slots/green"
        log "🚀 Deploying $version to GREEN slot (Staging)" "$GREEN"
    fi
    
    # Deploy using ZIP deploy if package provided
    if [ -n "$package" ] && [ -f "$package" ]; then
        log "📦 Deploying package: $package" "$BLUE"
        az webapp deployment source config-zip \
            --resource-group "$RESOURCE_GROUP" \
            --name "$APP_NAME-blue" \
            --slot "$slot" \
            --src "$package"
    else
        log "🔧 Deploying from CI/CD pipeline (no package specified)" "$YELLOW"
    fi
    
    # Set version tag
    if [ "$slot" == "blue" ]; then
        az webapp config appsettings set \
            --resource-group "$RESOURCE_GROUP" \
            --name "$APP_NAME-blue" \
            --settings "APP_VERSION=$version" \
            --output none
    else
        az webapp config appsettings set \
            --resource-group "$RESOURCE_GROUP" \
            --name "$APP_NAME-blue" \
            --slot "green" \
            --settings "APP_VERSION=$version" \
            --output none
    fi
    
    log "⏳ Waiting for deployment to complete..." "$YELLOW"
    sleep 30
    
    # Get the URL for health check
    if [ "$slot" == "blue" ]; then
        local url="https://${APP_NAME}-blue.azurewebsites.net"
    else
        local url="https://${APP_NAME}-blue-green.azurewebsites.net"
    fi
    
    # Verify deployment health
    if check_health "$url" "$HEALTH_CHECK_RETRIES" "$HEALTH_CHECK_INTERVAL"; then
        log "✅ Deployment successful to $slot slot" "$GREEN"
        return 0
    else
        log "❌ Deployment health check failed for $slot slot" "$RED"
        return 1
    fi
}

# Main deployment logic
main() {
    if [ $# -lt 2 ]; then
        log "Usage: $0 <blue|green> <version> [package-path]" "$RED"
        log "Example: $0 green v1.2.3 ./app.zip" "$RED"
        exit 1
    fi
    
    local TARGET_SLOT=$1
    local VERSION=$2
    local PACKAGE=${3:-""}
    
    log "🎯 Blue-Green Deployment Started" "$BLUE"
    log "Target Slot: $TARGET_SLOT" "$BLUE"
    log "Version: $VERSION" "$BLUE"
    
    # Validate slot
    if [ "$TARGET_SLOT" != "blue" ] && [ "$TARGET_SLOT" != "green" ]; then
        log "❌ Invalid slot. Must be 'blue' or 'green'" "$RED"
        exit 1
    fi
    
    # Check Azure login
    if ! az account show >/dev/null 2>&1; then
        log "❌ Not logged into Azure. Please run: az login" "$RED"
        exit 1
    fi
    
    # Deploy to target slot
    if ! deploy_to_slot "$TARGET_SLOT" "$VERSION" "$PACKAGE"; then
        log "❌ Deployment failed!" "$RED"
        exit 1
    fi
    
    # If deploying to green, offer to switch traffic
    if [ "$TARGET_SLOT" == "green" ]; then
        log "" "$NC"
        log "📊 Green slot deployment successful!" "$GREEN"
        log "🔄 Ready to switch traffic to green slot" "$YELLOW"
        log "" "$NC"
        log "Next steps:" "$BLUE"
        log "1. Test green slot: https://${APP_NAME}-blue-green.azurewebsites.net" "$NC"
        log "2. Switch 10% traffic: ./switch-traffic.sh 10" "$NC"
        log "3. Monitor metrics and errors" "$NC"
        log "4. Gradually increase traffic: ./switch-traffic.sh 25, 50, 100" "$NC"
        log "5. Or rollback if issues: ./rollback-deployment.sh" "$NC"
    else
        log "✅ Blue slot (production) updated successfully!" "$GREEN"
    fi
    
    # Log deployment summary
    log "" "$NC"
    log "📋 Deployment Summary:" "$BLUE"
    log "├── Slot: $TARGET_SLOT" "$NC"
    log "├── Version: $VERSION" "$NC"
    log "├── Timestamp: $(date)" "$NC"
    log "└── Status: SUCCESS" "$GREEN"
}

# Run main function
main "$@"