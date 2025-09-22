#!/bin/bash

# Infrastructure Validation Script
# Validates all 4 critical components are working correctly

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Function to print colored output
log() {
    echo -e "${2:-$NC}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to run test
run_test() {
    local test_name=$1
    local test_command=$2
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -n "Testing: $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Function to check service health
check_health() {
    local service=$1
    local url=$2
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    [ "$response" == "200" ]
}

log "🔍 SecDevOps Infrastructure Validation Starting..." "$BLUE"
log "=" "$BLUE"
echo ""

# ===========================================
# 1. DATABASE STATE API VALIDATION
# ===========================================
log "📊 Testing Database State API..." "$BLUE"

# Check if container is running
run_test "DB API Container Running" "docker ps | grep -q test-data-api"

# Test health endpoint
run_test "DB API Health Check" "check_health 'DB API' 'http://localhost:5000/health'"

# Test state retrieval
run_test "DB API Get State" "curl -s http://localhost:5000/api/test/db-state | jq -r '.current_state' | grep -E 'schema-only|framework|full'"

# Test state switching
if [ $FAILED_TESTS -eq 0 ]; then
    log "  Testing state transitions..." "$YELLOW"
    
    # Switch to schema-only
    run_test "Switch to Schema-Only" "curl -s -X POST http://localhost:5000/api/test/db-state -H 'Content-Type: application/json' -d '{\"state\": \"schema-only\"}' | jq -r '.status' | grep success"
    
    # Switch to framework
    run_test "Switch to Framework" "curl -s -X POST http://localhost:5000/api/test/db-state -H 'Content-Type: application/json' -d '{\"state\": \"framework\"}' | jq -r '.status' | grep success"
    
    # Switch to full
    run_test "Switch to Full" "curl -s -X POST http://localhost:5000/api/test/db-state -H 'Content-Type: application/json' -d '{\"state\": \"full\"}' | jq -r '.status' | grep success"
    
    # Test reset
    run_test "Reset Current State" "curl -s -X POST http://localhost:5000/api/test/db-reset | jq -r '.status' | grep success"
fi

echo ""

# ===========================================
# 2. VPN GATEWAY VALIDATION
# ===========================================
log "🔐 Testing VPN Gateway Configuration..." "$BLUE"

# Check Azure login
run_test "Azure CLI Authenticated" "az account show > /dev/null 2>&1"

if [ $? -eq 0 ]; then
    # Check VPN Gateway status
    VPN_STATUS=$(az network vnet-gateway show \
        --name vpn-secdevops \
        --resource-group secdevops-rg \
        --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")
    
    if [ "$VPN_STATUS" == "Succeeded" ]; then
        run_test "VPN Gateway Deployed" "true"
        
        # Check public IP
        run_test "VPN Public IP Assigned" "az network vnet-gateway show --name vpn-secdevops --resource-group secdevops-rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv | grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'"
    elif [ "$VPN_STATUS" == "Provisioning" ] || [ "$VPN_STATUS" == "Updating" ]; then
        log "  ⏳ VPN Gateway still provisioning... (this takes ~45 minutes)" "$YELLOW"
        WARNINGS=$((WARNINGS + 1))
    else
        run_test "VPN Gateway Deployed" "false"
    fi
    
    # Check certificates
    run_test "VPN Certificates Generated" "test -f scripts/certs/vpn-root.crt && test -f scripts/certs/vpn-client.crt"
fi

echo ""

# ===========================================
# 3. BLUE-GREEN DEPLOYMENT VALIDATION
# ===========================================
log "🔄 Testing Blue-Green Deployment..." "$BLUE"

# Check deployment scripts
run_test "Deploy Script Exists" "test -x scripts/deploy-blue-green.sh"
run_test "Switch Traffic Script Exists" "test -x scripts/switch-traffic.sh"
run_test "Rollback Script Exists" "test -x scripts/rollback-deployment.sh"

# Check Terraform configuration
run_test "Terraform Config Valid" "cd terraform && terraform validate > /dev/null 2>&1"

if [ $? -eq 0 ] && [ "$AZURE_LOGIN" == "true" ]; then
    # Check if infrastructure exists
    BLUE_APP=$(az webapp show \
        --name app-oversight-prod-blue \
        --resource-group secdevops-rg \
        --query "state" -o tsv 2>/dev/null || echo "NotFound")
    
    if [ "$BLUE_APP" == "Running" ]; then
        run_test "Blue Slot Exists" "true"
        
        # Check green slot
        run_test "Green Slot Exists" "az webapp deployment slot list --name app-oversight-prod-blue --resource-group secdevops-rg --query '[?name==`green`]' | jq -r '.[0].state' | grep Running"
        
        # Check Application Gateway
        run_test "Application Gateway Exists" "az network application-gateway show --name appgw-secdevops --resource-group secdevops-rg --query 'operationalState' -o tsv | grep Running"
    else
        log "  ℹ️  Blue-Green infrastructure not yet deployed" "$YELLOW"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

echo ""

# ===========================================
# 4. OWASP ZAP VALIDATION
# ===========================================
log "🛡️  Testing OWASP ZAP Security Scanner..." "$BLUE"

# Check if ZAP container is running
run_test "ZAP Container Running" "docker ps | grep -q owasp-zap"

if [ $? -eq 0 ]; then
    # Wait for ZAP to be ready
    log "  Waiting for ZAP API..." "$YELLOW"
    sleep 5
    
    # Test ZAP API
    run_test "ZAP API Responsive" "curl -s 'http://localhost:8080/JSON/core/view/version/?apikey=secdevops-api-key' | jq -r '.version' | grep -E '[0-9]+\.[0-9]+'"
    
    # Check ZAP directories
    run_test "ZAP Reports Directory" "test -d zap/reports"
    run_test "ZAP Policies Directory" "test -d zap/policies"
    run_test "Baseline Policy Exists" "test -f zap/policies/baseline.policy"
    
    # Test scan script
    run_test "DAST Scan Script Exists" "test -x scripts/run-dast-scan.sh"
    run_test "Parse Script Exists" "test -x scripts/parse-zap-results.py"
else
    log "  Starting ZAP container..." "$YELLOW"
    docker-compose -f docker-compose.zap.yml up -d > /dev/null 2>&1
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# ===========================================
# 5. JENKINS INTEGRATION VALIDATION
# ===========================================
log "🔧 Testing Jenkins Integration..." "$BLUE"

# Check Jenkinsfile
run_test "Jenkinsfile Updated" "grep -q 'OWASP ZAP' jenkins/Jenkinsfile"
run_test "DB State Integration" "grep -q 'test-data-api' jenkins/Jenkinsfile"
run_test "Blue-Green Integration" "grep -q 'deploy-blue-green.sh' jenkins/Jenkinsfile"

echo ""

# ===========================================
# 6. NETWORK CONNECTIVITY TESTS
# ===========================================
log "🌐 Testing Network Connectivity..." "$BLUE"

# Check Docker network
run_test "Docker Network Exists" "docker network ls | grep -q secdevops-network"

# If network doesn't exist, create it
if [ $? -ne 0 ]; then
    log "  Creating Docker network..." "$YELLOW"
    docker network create secdevops-network > /dev/null 2>&1
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# ===========================================
# VALIDATION SUMMARY
# ===========================================
log "=" "$BLUE"
log "📋 Validation Summary" "$BLUE"
log "=" "$BLUE"

echo -e "Total Tests:    $TOTAL_TESTS"
echo -e "Passed:        ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:        ${RED}$FAILED_TESTS${NC}"
echo -e "Warnings:      ${YELLOW}$WARNINGS${NC}"

# Calculate success rate
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "Success Rate:  ${SUCCESS_RATE}%"
fi

echo ""

# Overall status
if [ $FAILED_TESTS -eq 0 ]; then
    log "✅ ALL CRITICAL COMPONENTS VALIDATED SUCCESSFULLY!" "$GREEN"
    EXIT_CODE=0
elif [ $FAILED_TESTS -le 3 ]; then
    log "⚠️  SOME COMPONENTS NEED ATTENTION" "$YELLOW"
    EXIT_CODE=1
else
    log "❌ CRITICAL FAILURES DETECTED" "$RED"
    EXIT_CODE=2
fi

# Recommendations
if [ $FAILED_TESTS -gt 0 ] || [ $WARNINGS -gt 0 ]; then
    echo ""
    log "📝 Recommendations:" "$BLUE"
    
    if ! docker ps | grep -q test-data-api; then
        echo "  • Start DB API: cd services/test-data-api && docker-compose up -d"
    fi
    
    if ! docker ps | grep -q owasp-zap; then
        echo "  • Start ZAP: docker-compose -f docker-compose.zap.yml up -d"
    fi
    
    if [ "$VPN_STATUS" == "Provisioning" ]; then
        echo "  • Monitor VPN: watch -n 30 './scripts/check-vpn-status.sh'"
    fi
    
    if [ "$BLUE_APP" != "Running" ]; then
        echo "  • Deploy Blue-Green: cd terraform && terraform apply"
    fi
fi

echo ""
log "Validation completed at $(date)" "$BLUE"

exit $EXIT_CODE