#!/bin/bash

# Quick Start Script for SecDevOps Infrastructure
# Deploys all 4 critical components

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${2:-$NC}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log "🚀 SecDevOps Infrastructure Quick Start" "$BLUE"
log "======================================" "$BLUE"
echo ""

# Check prerequisites
log "📋 Checking prerequisites..." "$YELLOW"

# Docker check
if ! command -v docker &> /dev/null; then
    log "❌ Docker not installed" "$RED"
    exit 1
fi

# Docker Compose check
if ! command -v docker-compose &> /dev/null; then
    log "❌ Docker Compose not installed" "$RED"
    exit 1
fi

# Azure CLI check (optional)
if command -v az &> /dev/null; then
    AZURE_CLI="true"
    log "✅ Azure CLI found" "$GREEN"
else
    AZURE_CLI="false"
    log "⚠️  Azure CLI not found (VPN and Blue-Green features unavailable)" "$YELLOW"
fi

log "✅ Prerequisites satisfied" "$GREEN"
echo ""

# ===========================================
# 1. START DATABASE STATE API
# ===========================================
log "1️⃣  Starting Database State API..." "$BLUE"

# Create Docker network if not exists
if ! docker network ls | grep -q secdevops-network; then
    log "  Creating Docker network..." "$YELLOW"
    docker network create secdevops-network
fi

# Build and start DB API
cd services/test-data-api
if docker-compose up -d --build; then
    log "  ✅ Database State API started" "$GREEN"
    
    # Wait for health check
    sleep 5
    if curl -s http://localhost:5000/health > /dev/null 2>&1; then
        log "  ✅ API health check passed" "$GREEN"
    else
        log "  ⚠️  API may still be starting..." "$YELLOW"
    fi
else
    log "  ❌ Failed to start Database State API" "$RED"
fi
cd ../..
echo ""

# ===========================================
# 2. START OWASP ZAP
# ===========================================
log "2️⃣  Starting OWASP ZAP Security Scanner..." "$BLUE"

if docker-compose -f docker-compose.zap.yml up -d; then
    log "  ✅ OWASP ZAP container started" "$GREEN"
    
    # Wait for ZAP API
    log "  Waiting for ZAP API to be ready..." "$YELLOW"
    sleep 10
    
    if curl -s "http://localhost:8080/JSON/core/view/version/?apikey=secdevops-api-key" > /dev/null 2>&1; then
        log "  ✅ ZAP API is ready" "$GREEN"
    else
        log "  ⚠️  ZAP may still be starting (this can take 30-60 seconds)..." "$YELLOW"
    fi
else
    log "  ❌ Failed to start OWASP ZAP" "$RED"
fi
echo ""

# ===========================================
# 3. AZURE VPN GATEWAY (if Azure CLI available)
# ===========================================
if [ "$AZURE_CLI" == "true" ]; then
    log "3️⃣  Setting up Azure VPN Gateway..." "$BLUE"
    
    # Check Azure login
    if az account show > /dev/null 2>&1; then
        log "  ✅ Azure authenticated" "$GREEN"
        
        # Check if VPN already exists or is being created
        VPN_STATUS=$(az network vnet-gateway show \
            --name vpn-secdevops \
            --resource-group secdevops-rg \
            --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")
        
        if [ "$VPN_STATUS" == "Succeeded" ]; then
            log "  ✅ VPN Gateway already deployed" "$GREEN"
        elif [ "$VPN_STATUS" == "Provisioning" ] || [ "$VPN_STATUS" == "Updating" ]; then
            log "  ⏳ VPN Gateway is being provisioned (45 minutes remaining)..." "$YELLOW"
        else
            log "  Starting VPN Gateway creation (this will take ~45 minutes)..." "$YELLOW"
            cd scripts
            ./setup-vpn-gateway.sh &
            cd ..
            log "  🔄 VPN Gateway creation started in background" "$BLUE"
            log "     Monitor with: ./scripts/check-vpn-status.sh" "$BLUE"
        fi
    else
        log "  ❌ Not logged into Azure. Run: az login" "$RED"
    fi
else
    log "3️⃣  Skipping VPN Gateway (Azure CLI not installed)" "$YELLOW"
fi
echo ""

# ===========================================
# 4. BLUE-GREEN DEPLOYMENT SETUP
# ===========================================
if [ "$AZURE_CLI" == "true" ]; then
    log "4️⃣  Preparing Blue-Green Deployment..." "$BLUE"
    
    if az account show > /dev/null 2>&1; then
        # Check Terraform
        if command -v terraform &> /dev/null; then
            log "  ✅ Terraform found" "$GREEN"
            
            cd terraform
            # Initialize Terraform
            if [ ! -d .terraform ]; then
                log "  Initializing Terraform..." "$YELLOW"
                terraform init > /dev/null 2>&1
            fi
            
            # Validate configuration
            if terraform validate > /dev/null 2>&1; then
                log "  ✅ Terraform configuration valid" "$GREEN"
                log "  📝 Run 'cd terraform && terraform apply' to deploy Blue-Green infrastructure" "$BLUE"
            else
                log "  ❌ Terraform configuration invalid" "$RED"
            fi
            cd ..
        else
            log "  ⚠️  Terraform not installed (required for Blue-Green deployment)" "$YELLOW"
        fi
    else
        log "  ❌ Azure authentication required for Blue-Green setup" "$RED"
    fi
else
    log "4️⃣  Skipping Blue-Green setup (Azure CLI not installed)" "$YELLOW"
fi
echo ""

# ===========================================
# SERVICE STATUS SUMMARY
# ===========================================
log "======================================" "$BLUE"
log "📊 Service Status Summary" "$BLUE"
log "======================================" "$BLUE"

# Check each service
echo ""
echo -e "${BLUE}Service${NC}                    ${BLUE}Status${NC}              ${BLUE}URL/Endpoint${NC}"
echo "------------------------------------------------------------------------"

# DB State API
if curl -s http://localhost:5000/health > /dev/null 2>&1; then
    echo -e "Database State API         ${GREEN}✅ Running${NC}          http://localhost:5000"
else
    echo -e "Database State API         ${RED}❌ Not Running${NC}      http://localhost:5000"
fi

# OWASP ZAP
if docker ps | grep -q owasp-zap; then
    echo -e "OWASP ZAP Scanner          ${GREEN}✅ Running${NC}          http://localhost:8080"
else
    echo -e "OWASP ZAP Scanner          ${RED}❌ Not Running${NC}      http://localhost:8080"
fi

# VPN Gateway
if [ "$AZURE_CLI" == "true" ] && [ -n "$VPN_STATUS" ]; then
    if [ "$VPN_STATUS" == "Succeeded" ]; then
        echo -e "Azure VPN Gateway          ${GREEN}✅ Deployed${NC}         Check Azure Portal"
    elif [ "$VPN_STATUS" == "Provisioning" ]; then
        echo -e "Azure VPN Gateway          ${YELLOW}⏳ Provisioning${NC}     ~45 minutes remaining"
    else
        echo -e "Azure VPN Gateway          ${YELLOW}⚠️  Not Deployed${NC}     Run: ./scripts/setup-vpn-gateway.sh"
    fi
else
    echo -e "Azure VPN Gateway          ${YELLOW}➖ N/A${NC}              Azure CLI required"
fi

# Blue-Green
echo -e "Blue-Green Deployment      ${YELLOW}📝 Ready${NC}            Run: terraform apply"

echo ""

# ===========================================
# NEXT STEPS
# ===========================================
log "📌 Next Steps:" "$BLUE"
echo ""
echo "1. Test Database State API:"
echo "   curl http://localhost:5000/api/test/db-state"
echo ""
echo "2. Test OWASP ZAP:"
echo "   ./scripts/run-dast-scan.sh http://example.com baseline"
echo ""

if [ "$AZURE_CLI" == "true" ]; then
    echo "3. Deploy Blue-Green Infrastructure:"
    echo "   cd terraform && terraform apply"
    echo ""
    echo "4. Monitor VPN Gateway Creation:"
    echo "   ./scripts/check-vpn-status.sh"
    echo ""
fi

echo "5. Run Full Validation:"
echo "   ./scripts/validate-infrastructure.sh"
echo ""

# ===========================================
# USEFUL COMMANDS
# ===========================================
log "🔧 Useful Commands:" "$BLUE"
echo ""
echo "• View logs:           docker-compose logs -f [service-name]"
echo "• Stop services:       docker-compose down"
echo "• Restart services:    docker-compose restart"
echo "• Check Jenkins:       cat jenkins/Jenkinsfile | grep -A5 DAST"
echo "• Test deployment:     ./scripts/deploy-blue-green.sh green v1.0.0"
echo ""

log "✅ Quick start completed!" "$GREEN"
log "Run './scripts/validate-infrastructure.sh' to verify all components" "$YELLOW"