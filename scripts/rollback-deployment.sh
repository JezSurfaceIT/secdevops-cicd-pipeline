#!/bin/bash

# Emergency Rollback Script for Blue-Green Deployment
# Usage: ./rollback-deployment.sh [--force]

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
LOG_FILE="/tmp/rollback_$(date +%Y%m%d_%H%M%S).log"

# Function to print colored output
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${2:-$NC}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

# Function to capture current state
capture_state() {
    log "📸 Capturing current deployment state..." "$BLUE"
    
    # Get current routing
    local current_pool=$(az network application-gateway rule show \
        --gateway-name "$APPGW_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --name "routing-rule" \
        --query "backendAddressPool.id" -o tsv 2>/dev/null || echo "unknown")
    
    if [[ "$current_pool" == *"green"* ]]; then
        echo "green"
    elif [[ "$current_pool" == *"blue"* ]]; then
        echo "blue"
    else
        echo "unknown"
    fi
}

# Function to check slot health
check_health() {
    local slot=$1
    local url
    
    if [ "$slot" == "blue" ]; then
        url="https://${APP_NAME}-blue.azurewebsites.net/health"
    else
        url="https://${APP_NAME}-blue-green.azurewebsites.net/health"
    fi
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    
    if [ "$response" == "200" ]; then
        return 0
    else
        return 1
    fi
}

# Function to perform rollback
perform_rollback() {
    local target_slot=$1
    
    log "🔄 Rolling back to ${target_slot} slot..." "$YELLOW"
    
    # Update Application Gateway routing
    az network application-gateway rule update \
        --gateway-name "$APPGW_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --name "routing-rule" \
        --backend-pool "${target_slot}-pool" \
        --output none
    
    log "✅ Traffic routed back to ${target_slot} slot" "$GREEN"
    
    # Restart the slot to ensure clean state
    log "♻️  Restarting ${target_slot} slot..." "$BLUE"
    if [ "$target_slot" == "blue" ]; then
        az webapp restart \
            --resource-group "$RESOURCE_GROUP" \
            --name "${APP_NAME}-blue" \
            --output none
    else
        az webapp restart \
            --resource-group "$RESOURCE_GROUP" \
            --name "${APP_NAME}-blue" \
            --slot "green" \
            --output none
    fi
    
    log "✅ Slot restarted successfully" "$GREEN"
}

# Function to notify stakeholders
send_notifications() {
    local reason=$1
    local rolled_back_to=$2
    
    log "📧 Sending rollback notifications..." "$BLUE"
    
    # Create notification payload
    local message="EMERGENCY ROLLBACK EXECUTED\n"
    message+="Time: $(date)\n"
    message+="Reason: $reason\n"
    message+="Rolled back to: $rolled_back_to slot\n"
    message+="Log file: $LOG_FILE"
    
    # If Slack webhook is configured
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 $message\"}" \
            "$SLACK_WEBHOOK_URL" 2>/dev/null || log "⚠️  Slack notification failed" "$YELLOW"
    fi
    
    # Log to audit system
    echo "$message" >> /var/log/deployments/rollbacks.log 2>/dev/null || true
}

# Function to create rollback report
create_report() {
    local initial_state=$1
    local final_state=$2
    local reason=$3
    
    log "📝 Generating rollback report..." "$BLUE"
    
    cat > "${LOG_FILE%.log}_report.md" << EOF
# Deployment Rollback Report

## Summary
- **Date/Time**: $(date)
- **Initial State**: $initial_state slot active
- **Final State**: $final_state slot active
- **Reason**: $reason
- **Executed By**: $(whoami)@$(hostname)

## Health Check Results
- Blue Slot: $(check_health blue && echo "✅ Healthy" || echo "❌ Unhealthy")
- Green Slot: $(check_health green && echo "✅ Healthy" || echo "❌ Unhealthy")

## Application Gateway Status
\`\`\`
$(az network application-gateway show \
    --name "$APPGW_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "{Name:name,State:operationalState,Health:healthProbeResults}" \
    -o json 2>/dev/null || echo "Unable to fetch")
\`\`\`

## Recent Deployments
\`\`\`
$(az webapp deployment list \
    --resource-group "$RESOURCE_GROUP" \
    --name "${APP_NAME}-blue" \
    --query "[0:5].{Time:receivedTime,Author:author,Message:message}" \
    -o table 2>/dev/null || echo "Unable to fetch")
\`\`\`

## Recommendations
1. Investigate the root cause of the failure
2. Review application logs and metrics
3. Fix identified issues before next deployment
4. Consider implementing additional health checks

## Log File
Full logs available at: $LOG_FILE

---
*Generated automatically by rollback-deployment.sh*
EOF
    
    log "✅ Report saved to: ${LOG_FILE%.log}_report.md" "$GREEN"
}

# Main rollback logic
main() {
    local FORCE_MODE=false
    local ROLLBACK_REASON="Manual intervention required"
    
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            --force)
                FORCE_MODE=true
                shift
                ;;
            --reason=*)
                ROLLBACK_REASON="${arg#*=}"
                shift
                ;;
            *)
                ;;
        esac
    done
    
    log "🚨 EMERGENCY ROLLBACK INITIATED 🚨" "$RED"
    log "Reason: $ROLLBACK_REASON" "$YELLOW"
    
    # Check Azure login
    if ! az account show >/dev/null 2>&1; then
        log "❌ Not logged into Azure. Please run: az login" "$RED"
        exit 1
    fi
    
    # Capture current state
    CURRENT_STATE=$(capture_state)
    log "📊 Current active slot: $CURRENT_STATE" "$BLUE"
    
    # Determine rollback target
    if [ "$CURRENT_STATE" == "green" ]; then
        ROLLBACK_TARGET="blue"
    elif [ "$CURRENT_STATE" == "blue" ]; then
        ROLLBACK_TARGET="green"
    else
        log "⚠️  Cannot determine current state. Defaulting to blue slot" "$YELLOW"
        ROLLBACK_TARGET="blue"
    fi
    
    log "🎯 Rollback target: $ROLLBACK_TARGET slot" "$BLUE"
    
    # Health check on target slot
    if ! check_health "$ROLLBACK_TARGET"; then
        if [ "$FORCE_MODE" == true ]; then
            log "⚠️  Target slot unhealthy but --force flag used. Proceeding..." "$YELLOW"
        else
            log "❌ Target slot ($ROLLBACK_TARGET) is unhealthy!" "$RED"
            log "   Use --force to override health check" "$YELLOW"
            exit 1
        fi
    else
        log "✅ Target slot ($ROLLBACK_TARGET) is healthy" "$GREEN"
    fi
    
    # Confirm rollback (unless force mode)
    if [ "$FORCE_MODE" != true ]; then
        echo -e "${YELLOW}⚠️  This will immediately switch all traffic to $ROLLBACK_TARGET slot!${NC}"
        echo -n "Continue? (yes/no): "
        read confirmation
        if [ "$confirmation" != "yes" ]; then
            log "❌ Rollback cancelled by user" "$RED"
            exit 0
        fi
    fi
    
    # Perform the rollback
    perform_rollback "$ROLLBACK_TARGET"
    
    # Verify rollback success
    sleep 5
    NEW_STATE=$(capture_state)
    
    if [ "$NEW_STATE" == "$ROLLBACK_TARGET" ]; then
        log "✅ Rollback completed successfully!" "$GREEN"
        
        # Post-rollback health check
        if check_health "$ROLLBACK_TARGET"; then
            log "✅ Application is healthy after rollback" "$GREEN"
        else
            log "⚠️  Application may be degraded - manual check required!" "$YELLOW"
        fi
    else
        log "❌ Rollback may have failed - manual intervention required!" "$RED"
    fi
    
    # Send notifications
    send_notifications "$ROLLBACK_REASON" "$ROLLBACK_TARGET"
    
    # Generate report
    create_report "$CURRENT_STATE" "$NEW_STATE" "$ROLLBACK_REASON"
    
    # Final summary
    log "" "$NC"
    log "📋 Rollback Summary:" "$BLUE"
    log "├── Previous state: $CURRENT_STATE" "$NC"
    log "├── Current state: $NEW_STATE" "$NC"
    log "├── Timestamp: $(date)" "$NC"
    log "├── Log file: $LOG_FILE" "$NC"
    log "└── Report: ${LOG_FILE%.log}_report.md" "$NC"
    
    log "" "$NC"
    log "🔧 Post-Rollback Actions Required:" "$YELLOW"
    log "1. Review application logs for root cause" "$NC"
    log "2. Check monitoring dashboards for anomalies" "$NC"
    log "3. Verify all dependent services are functional" "$NC"
    log "4. Document incident and lessons learned" "$NC"
    log "5. Fix issues before attempting next deployment" "$NC"
}

# Run main function
main "$@"