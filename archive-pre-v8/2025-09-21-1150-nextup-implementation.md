# Next Session: Execute Critical Infrastructure Fixes
## Implementation Sprint - Day 1

**Date:** 2025-09-21 11:50  
**Purpose:** Execute the 4 critical fixes identified in architecture analysis  
**Goal:** Get infrastructure from 7.5/10 to 8.0/10 by fixing blocking issues

---

## 🎯 IMPLEMENTATION PROMPT FOR NEXT SESSION

Copy and paste this entire section to start the next session:

---

### **SESSION START PROMPT:**

I need to implement 4 critical infrastructure fixes for the SecDevOps pipeline. Please help me execute these tasks in order:

## Task 1: Azure VPN Gateway Setup (URGENT - Blocks Penetration Testing)

**Current Problem:** Kali Linux at 192.168.1.100 cannot reach Azure test network at 10.40.1.0/24

**Required Actions:**
1. Create Azure VPN Gateway in resource group `secdevops-rg`
2. Configure Point-to-Site VPN with address pool 172.16.0.0/24
3. Generate certificates for Kali client connection
4. Test connectivity from Kali (192.168.1.100) to Test Environment (10.40.1.10)
5. Verify penetration testing tools (nmap, metasploit) work through VPN

**Files to create/modify:**
- `/scripts/setup-vpn-gateway.sh` - Automated VPN setup
- `/scripts/generate-vpn-certs.sh` - Certificate generation
- `/docs/KALI-VPN-SETUP.md` - Connection instructions

## Task 2: Blue-Green Deployment Implementation

**Current Problem:** No zero-downtime deployment strategy, single point of failure

**Required Actions:**
1. Create Azure App Service deployment slots:
   - `app-oversight-prod-blue` (current production)
   - `app-oversight-prod-green` (new deployments)
2. Configure Application Gateway with:
   - Blue backend pool
   - Green backend pool
   - Weighted routing rules
3. Create deployment automation scripts with:
   - Health checks
   - Gradual traffic switching (10% → 25% → 50% → 100%)
   - Automatic rollback on failure
4. Test full deployment cycle with rollback

**Files to create/modify:**
- `/scripts/deploy-blue-green.sh` - Main deployment script
- `/scripts/switch-traffic.sh` - Traffic management
- `/scripts/rollback-deployment.sh` - Emergency rollback
- `/terraform/blue-green-infrastructure.tf` - IaC for slots
- Update `/jenkins/Jenkinsfile` - Add blue-green stages

## Task 3: Database State Switching API

**Current Problem:** Manual test data management, no programmatic control

**Required Actions:**
1. Create Flask/FastAPI service with endpoints:
   - `GET /api/test/db-state` - Current state
   - `POST /api/test/db-state` - Switch state
   - `POST /api/test/db-reset` - Reset current state
2. Implement three database states:
   - `schema-only` - Empty tables
   - `framework` - Basic data
   - `full` - Complete test data
3. Create SQL scripts for each state
4. Deploy as container on port 5000
5. Integrate with Jenkins pipeline

**Files to create:**
- `/services/test-data-api/app.py` - API service
- `/services/test-data-api/Dockerfile` - Container definition
- `/sql/states/schema-only.sql` - Empty DB state
- `/sql/states/framework-data.sql` - Basic data state
- `/sql/states/full-test-data.sql` - Full data state
- Update `/jenkins/Jenkinsfile` - Add API calls

## Task 4: DAST Security Scanning with OWASP ZAP

**Current Problem:** No runtime security testing, missing vulnerability detection

**Required Actions:**
1. Deploy OWASP ZAP as Docker container
2. Configure ZAP API on port 8080
3. Create scanning profiles:
   - Baseline scan (5 minutes)
   - Full scan (30 minutes)
   - API scan (10 minutes)
4. Integrate with Jenkins pipeline:
   - Run after deployment to test
   - Fail build on high-risk findings
   - Generate HTML and JSON reports
5. Create security dashboard

**Files to create:**
- `/docker-compose.zap.yml` - ZAP deployment
- `/scripts/run-dast-scan.sh` - Scanning automation
- `/zap/policies/baseline.policy` - Scan configuration
- Update `/jenkins/Jenkinsfile` - Add DAST stage
- `/scripts/parse-zap-results.py` - Result analyzer

---

## 📊 VALIDATION CHECKLIST

After implementation, verify:

### VPN Gateway
```bash
# From Kali machine
ping 10.40.1.10  # Should succeed
nmap -p 80,443 10.40.1.10  # Should show open ports
curl http://10.40.1.10/health  # Should return 200 OK
```

### Blue-Green Deployment
```bash
# Check slots exist
az webapp deployment slot list --name app-oversight-prod --resource-group secdevops-rg

# Test deployment
./scripts/deploy-blue-green.sh green v1.0.1
./scripts/switch-traffic.sh 10
./scripts/rollback-deployment.sh  # Should revert to blue
```

### DB State API
```bash
# Test API endpoints
curl http://localhost:5000/api/test/db-state
curl -X POST http://localhost:5000/api/test/db-state -H 'Content-Type: application/json' -d '{"state": "full"}'

# Verify state switch time < 30 seconds
time curl -X POST http://localhost:5000/api/test/db-reset
```

### DAST Scanning
```bash
# Run baseline scan
docker run -t owasp/zap2docker-stable zap-baseline.py -t http://test-app:8080 -r report.html

# Check Jenkins integration
curl -X POST http://jenkins:8080/job/security-scan/build
```

---

## 🚀 EXECUTION ORDER

**Morning (3-4 hours):**
1. Start VPN Gateway creation (45 min build time)
2. While VPN builds → Implement DB State API
3. Test DB API thoroughly
4. Complete VPN configuration when ready

**Afternoon (3-4 hours):**
1. Create blue-green infrastructure
2. Implement traffic switching
3. Deploy and configure OWASP ZAP
4. Integrate with Jenkins pipeline

**Evening (1-2 hours):**
1. Run comprehensive tests
2. Document any issues
3. Update architecture diagrams
4. Prepare monitoring dashboards

---

## 💾 ENVIRONMENT VARIABLES NEEDED

```bash
# Azure
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_RESOURCE_GROUP="secdevops-rg"
export AZURE_LOCATION="eastus"

# Database
export DB_HOST="10.40.1.20"
export DB_USER="testadmin"
export DB_PASSWORD="[from-vault]"
export DB_NAME="oversight_test"

# VPN
export VPN_CLIENT_ROOT_CERT="vpn-root.crt"
export VPN_ADDRESS_POOL="172.16.0.0/24"

# ZAP
export ZAP_API_KEY="secdevops-api-key-$(date +%s)"
export ZAP_PORT="8080"
```

---

## 🔧 HELPFUL COMMANDS

```bash
# Monitor VPN Gateway creation
watch -n 30 'az network vnet-gateway show --name vpn-secdevops --resource-group secdevops-rg --query "provisioningState"'

# Quick blue-green switch
az webapp deployment slot swap --slot green --name app-oversight-prod --resource-group secdevops-rg

# Emergency rollback
az network application-gateway rule update --gateway-name appgw-secdevops --resource-group secdevops-rg --name rule1 --backend-pool blue-pool --weight 100

# Force DB state reset
docker exec test-db psql -U postgres -c "DROP DATABASE oversight_test; CREATE DATABASE oversight_test;"
```

---

## 📝 EXPECTED OUTCOMES

By end of session:
1. ✅ Kali can perform penetration testing on test environment
2. ✅ Zero-downtime deployments working with blue-green
3. ✅ Test data management automated via API
4. ✅ Security scanning integrated in pipeline
5. ✅ Architecture score improved from 7.5 to 8.0

---

## 🚨 IF BLOCKED

**VPN Issues:** Use Azure Bastion as alternative (browser-based access)
**Blue-Green Issues:** Implement simpler canary deployment first
**DB API Issues:** Use shell scripts temporarily
**ZAP Issues:** Use simpler nikto scanner initially

---

**END OF PROMPT**

Use this exact prompt to start the implementation session. All tasks are clearly defined with specific actions, validation steps, and expected outcomes.