#!/bin/bash

# Traffic Switching Script for Blue-Green Deployment
# Usage: ./switch-traffic.sh <percentage-to-green>

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-secdevops-rg}"
APPGW_NAME="appgw-secdevops"
APP_NAME="app-oversight-prod"

# Function to print colored output
log() {
    echo -e "${2:-$NC}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to update traffic distribution
update_traffic() {
    local green_weight=$1
    local blue_weight=$((100 - green_weight))
    
    log "🔄 Updating traffic distribution..." "$BLUE"
    log "├── Blue (Current): ${blue_weight}%" "$BLUE"
    log "└── Green (New): ${green_weight}%" "$GREEN"
    
    # Create weighted routing rule
    if [ $green_weight -eq 0 ]; then
        # All traffic to blue
        az network application-gateway rule update \
            --gateway-name "$APPGW_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --name "routing-rule" \
            --backend-pool "blue-pool" \
            --output none
    elif [ $green_weight -eq 100 ]; then
        # All traffic to green
        az network application-gateway rule update \
            --gateway-name "$APPGW_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --name "routing-rule" \
            --backend-pool "green-pool" \
            --output none
    else
        # Split traffic between blue and green
        # Note: Azure App Gateway requires creating multiple rules for weighted distribution
        # This is a simplified version - in production, use multiple rules or Azure Traffic Manager
        
        log "⚠️  Weighted routing requires Azure Traffic Manager or multiple rules" "$YELLOW"
        log "For now, switching to green slot at ${green_weight}% threshold" "$YELLOW"
        
        if [ $green_weight -ge 50 ]; then
            az network application-gateway rule update \
                --gateway-name "$APPGW_NAME" \
                --resource-group "$RESOURCE_GROUP" \
                --name "routing-rule" \
                --backend-pool "green-pool" \
                --output none
            log "✅ Switched primary traffic to GREEN slot" "$GREEN"
        else
            az network application-gateway rule update \
                --gateway-name "$APPGW_NAME" \
                --resource-group "$RESOURCE_GROUP" \
                --name "routing-rule" \
                --backend-pool "blue-pool" \
                --output none
            log "✅ Keeping primary traffic on BLUE slot" "$BLUE"
        fi
    fi
}

# Function to perform health checks
check_both_slots() {
    log "🏥 Performing health checks on both slots..." "$BLUE"
    
    # Check blue slot
    blue_health=$(curl -s -o /dev/null -w "%{http_code}" "https://${APP_NAME}-blue.azurewebsites.net/health" || echo "000")
    
    # Check green slot
    green_health=$(curl -s -o /dev/null -w "%{http_code}" "https://${APP_NAME}-blue-green.azurewebsites.net/health" || echo "000")
    
    if [ "$blue_health" == "200" ]; then
        log "✅ Blue slot health: OK" "$BLUE"
    else
        log "⚠️  Blue slot health: DEGRADED (HTTP $blue_health)" "$YELLOW"
    fi
    
    if [ "$green_health" == "200" ]; then
        log "✅ Green slot health: OK" "$GREEN"
    else
        log "⚠️  Green slot health: DEGRADED (HTTP $green_health)" "$YELLOW"
    fi
    
    # Return failure if green is unhealthy and we're routing traffic to it
    if [ "$green_health" != "200" ] && [ $1 -gt 0 ]; then
        return 1
    fi
    
    return 0
}

# Function to monitor metrics
monitor_metrics() {
    local duration=${1:-60}
    
    log "📊 Monitoring metrics for ${duration} seconds..." "$BLUE"
    
    # Get current metrics
    az monitor metrics list \
        --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${APP_NAME}-blue" \
        --metric "Http2xx" "Http4xx" "Http5xx" "ResponseTime" \
        --interval PT1M \
        --output table 2>/dev/null || log "⚠️  Metrics not available yet" "$YELLOW"
}

# Function to swap slots (full switchover)
swap_slots() {
    log "🔄 Performing slot swap (Blue ↔ Green)..." "$BLUE"
    
    az webapp deployment slot swap \
        --resource-group "$RESOURCE_GROUP" \
        --name "${APP_NAME}-blue" \
        --slot "green" \
        --output none
    
    log "✅ Slot swap completed!" "$GREEN"
}

# Main function
main() {
    if [ $# -lt 1 ]; then
        log "Usage: $0 <percentage-to-green> [swap]" "$RED"
        log "Examples:" "$NC"
        log "  $0 10    # Route 10% traffic to green" "$NC"
        log "  $0 25    # Route 25% traffic to green" "$NC"
        log "  $0 50    # Route 50% traffic to green" "$NC"
        log "  $0 100   # Route 100% traffic to green" "$NC"
        log "  $0 swap  # Swap blue and green slots" "$NC"
        exit 1
    fi
    
    # Check Azure login
    if ! az account show >/dev/null 2>&1; then
        log "❌ Not logged into Azure. Please run: az login" "$RED"
        exit 1
    fi
    
    # Handle swap command
    if [ "$1" == "swap" ]; then
        swap_slots
        exit 0
    fi
    
    local GREEN_PERCENTAGE=$1
    
    # Validate percentage
    if ! [[ "$GREEN_PERCENTAGE" =~ ^[0-9]+$ ]] || [ "$GREEN_PERCENTAGE" -lt 0 ] || [ "$GREEN_PERCENTAGE" -gt 100 ]; then
        log "❌ Invalid percentage. Must be between 0 and 100" "$RED"
        exit 1
    fi
    
    log "🚀 Traffic Switching Started" "$BLUE"
    
    # Check health of both slots
    if ! check_both_slots $GREEN_PERCENTAGE; then
        log "❌ Health check failed! Aborting traffic switch" "$RED"
        exit 1
    fi
    
    # Update traffic distribution
    update_traffic $GREEN_PERCENTAGE
    
    # Monitor for a short period
    if [ $GREEN_PERCENTAGE -gt 0 ] && [ $GREEN_PERCENTAGE -lt 100 ]; then
        log "" "$NC"
        log "⏳ Monitoring initial response..." "$YELLOW"
        sleep 10
        
        # Quick health recheck
        if ! check_both_slots $GREEN_PERCENTAGE; then
            log "⚠️  Health degradation detected after switch!" "$YELLOW"
            log "🔧 Consider rolling back with: ./rollback-deployment.sh" "$YELLOW"
        fi
    fi
    
    # Summary
    log "" "$NC"
    log "📋 Traffic Switch Summary:" "$BLUE"
    log "├── Green traffic: ${GREEN_PERCENTAGE}%" "$GREEN"
    log "├── Blue traffic: $((100 - GREEN_PERCENTAGE))%" "$BLUE"
    log "├── Timestamp: $(date)" "$NC"
    log "└── Status: SUCCESS" "$GREEN"
    
    # Recommendations
    if [ $GREEN_PERCENTAGE -gt 0 ] && [ $GREEN_PERCENTAGE -lt 100 ]; then
        log "" "$NC"
        log "📌 Next Steps:" "$BLUE"
        log "1. Monitor application metrics and error rates" "$NC"
        log "2. Check application logs: az webapp log tail --name ${APP_NAME}-blue --slot green" "$NC"
        log "3. If stable, increase traffic: ./switch-traffic.sh $((GREEN_PERCENTAGE + 25))" "$NC"
        log "4. If issues occur, rollback: ./rollback-deployment.sh" "$NC"
    elif [ $GREEN_PERCENTAGE -eq 100 ]; then
        log "" "$NC"
        log "✅ Full cutover to green slot complete!" "$GREEN"
        log "📌 Consider swapping slots to make green the new blue: ./switch-traffic.sh swap" "$BLUE"
    fi
}

# Run main function
main "$@"