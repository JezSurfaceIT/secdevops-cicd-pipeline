# Network Configuration Guide - V8 Architecture
## Simplified Unified Network with IP Restrictions

**Version:** 8.0  
**Date:** 2025-09-22  
**Based on:** Architecture V8

---

## 🌐 Network Architecture Overview

### Core Principle: IP-Restricted Access Only

All access to the infrastructure is controlled by IP allowlist at the gateway level. No public IPs exist except the Application Gateway (172.178.53.198).

```
┌─────────────────────────────────────────────┐
│         UNIFIED VNET: 10.0.0.0/8           │
├─────────────────────────────────────────────┤
│  Hub Network (10.10.0.0/16)                │
│  SaaS Production (10.20.0.0/16)            │
│  Test Environment (10.40.0.0/16)           │
│  Development (10.60.0.0/16)                │
│  CBE Mimic (10.80.0.0/16)                  │
│  Monitoring (10.90.0.0/16)                 │
└─────────────────────────────────────────────┘
```

---

## 🏗️ Resource Group Network Organization

### Network Resource Groups (V8 Standard)

| Resource Group | Purpose | Network Components |
|----------------|---------|-------------------|
| `rg-oversight-shared-network-eastus` | Core networking infrastructure | VNet, Firewall, Bastion, Gateway |
| `rg-oversight-shared-monitoring-eastus` | Monitoring network components | Monitoring subnet resources |
| `rg-oversight-dev-jenkins-eastus` | Development network resources | Jenkins subnet, ACR endpoints |
| `rg-oversight-test-acs-eastus` | Test environment networking | Test subnet, Vault endpoints |
| `rg-oversight-prod-saas-eastus` | Production SaaS networking | SaaS subnets, private endpoints |
| `rg-oversight-prod-cbe-eastus` | CBE environment networking | CBE subnets, portal endpoints |

---

## 📋 Subnet Allocation Table

| Network Segment | CIDR | Component ID | Purpose | Resource Group |
|-----------------|------|--------------|---------|----------------|
| **Hub Services** | | | | |
| AzureFirewallSubnet | 10.10.0.0/26 | 811 | Azure Firewall | `rg-oversight-shared-network-eastus` |
| AzureBastionSubnet | 10.10.1.0/24 | 812 | Bastion Host | `rg-oversight-shared-network-eastus` |
| **SaaS Production** | | | | |
| subnet-saas-app | 10.20.2.0/24 | 700 | SaaS Application (/home/jez/code/SaaS) | `rg-oversight-prod-saas-eastus` |
| subnet-saas-db | 10.20.3.0/24 | 711 | PostgreSQL | `rg-oversight-prod-saas-eastus` |
| subnet-saas-storage | 10.20.4.0/24 | 712 | Blob Storage | `rg-oversight-prod-saas-eastus` |
| subnet-saas-redis | 10.20.5.0/24 | 713 | Redis Cache | `rg-oversight-prod-saas-eastus` |
| subnet-saas-keyvault | 10.20.6.0/24 | 714 | Key Vault | `rg-oversight-prod-saas-eastus` |
| subnet-saas-tenant | 10.20.7.0/24 | 729 | **ROADMAP** Multi-tenant | `rg-oversight-prod-saas-eastus` |
| **Test Environment** | | | | |
| subnet-test-app | 10.40.1.0/24 | 401 | Test Container | `rg-oversight-test-acs-eastus` |
| subnet-test-vault | 10.40.2.0/24 | 303 | HashiCorp Vault | `rg-oversight-test-acs-eastus` |
| **Development** | | | | |
| subnet-dev-avd | 10.60.1.0/24 | 103 | Azure AVD | `rg-oversight-dev-jenkins-eastus` |
| subnet-dev-jenkins | 10.60.2.0/24 | 301,501 | Jenkins CI/CD | `rg-oversight-dev-jenkins-eastus` |
| subnet-dev-acr | 10.60.3.0/24 | 308 | Container Registry | `rg-oversight-dev-jenkins-eastus` |
| **CBE Environment** | | | | |
| subnet-cbe-mimic | 10.80.1.0/24 | 860 | CBE Test | `rg-oversight-prod-cbe-eastus` |
| subnet-cbe-vault | 10.80.2.0/24 | 871 | CBE Vault | `rg-oversight-prod-cbe-eastus` |
| subnet-cbe-db | 10.80.3.0/24 | 872 | CBE PostgreSQL | `rg-oversight-prod-cbe-eastus` |
| subnet-cbe-portal | 10.80.4.0/24 | 902 | Customer Portal (/home/jez/code/customer-portal-v2) | `rg-oversight-prod-cbe-eastus` |
| subnet-cbe-guac | 10.80.5.0/24 | 873 | Guacamole | `rg-oversight-prod-cbe-eastus` |
| **Monitoring** | | | | |
| subnet-monitoring | 10.90.1.0/24 | 1001-1005 | Prometheus/Grafana | `rg-oversight-shared-monitoring-eastus` |

---

## 🔒 IP Security Configuration

### Gateway IP Allowlist (Component 801)

```bash
#!/bin/bash
# scripts/network/configure-ip-allowlist.sh

# CRITICAL: Only these IPs can access ANYTHING
ALLOWED_EXTERNAL_IPS=(
    # GitHub Webhooks (required for CI/CD)
    "140.82.112.0/20:GitHub-Webhooks-1"
    "143.55.64.0/20:GitHub-Webhooks-2"
    "192.30.252.0/22:GitHub-API"
    
    # Azure DevOps (for pipeline agents)
    "13.107.6.0/24:Azure-DevOps-1"
    "13.107.9.0/24:Azure-DevOps-2"
    
    # Admin Access (replace with actual IPs)
    "YOUR_OFFICE_IP/32:Office-Admin"
    "YOUR_HOME_IP/32:Home-Admin"
)

# Internal/Local Access (not via gateway)
LOCAL_ACCESS=(
    "192.168.1.100:Kali-Testing"  # Direct to test network
    "10.0.0.0/8:Azure-Internal"    # All Azure services
)
```

### NSG Rules Configuration

```bash
#!/bin/bash
# scripts/network/configure-nsgs-v8.sh

# V8 Resource Group Structure
NETWORK_RG="rg-oversight-shared-network-eastus"

# Create master NSG for gateway
az network nsg create \
    --resource-group $NETWORK_RG \
    --name nsg-gateway-master \
    --location eastus

# Apply IP restrictions at gateway
PRIORITY=100
for RULE in "${ALLOWED_EXTERNAL_IPS[@]}"; do
    IP="${RULE%%:*}"
    NAME="${RULE#*:}"
    
    az network nsg rule create \
        --resource-group $NETWORK_RG \
        --nsg-name nsg-gateway-master \
        --name "Allow-$NAME" \
        --priority $PRIORITY \
        --source-address-prefixes "$IP" \
        --destination-port-ranges 443 80 \
        --access Allow \
        --protocol Tcp \
        --direction Inbound
    
    PRIORITY=$((PRIORITY + 10))
done

# Default deny all
az network nsg rule create \
    --resource-group $NETWORK_RG \
    --nsg-name nsg-gateway-master \
    --name "DenyAllInbound" \
    --priority 4096 \
    --source-address-prefixes '*' \
    --destination-port-ranges '*' \
    --access Deny \
    --protocol '*' \
    --direction Inbound

echo "✅ NSGs configured in $NETWORK_RG"
```

---

## 🔥 Azure Firewall Configuration (Component 811)

### Firewall Rules for Internal Traffic

```bash
#!/bin/bash
# scripts/network/configure-firewall-v8.sh

NETWORK_RG="rg-oversight-shared-network-eastus"
FIREWALL_NAME="fw-oversight-central"

# Deploy Azure Firewall in shared network resource group
az network firewall create \
    --name $FIREWALL_NAME \
    --resource-group $NETWORK_RG \
    --location eastus

# Configure IP configuration
az network public-ip create \
    --name pip-firewall \
    --resource-group $NETWORK_RG \
    --allocation-method Static \
    --sku Standard

az network firewall ip-config create \
    --firewall-name $FIREWALL_NAME \
    --name fw-ipconfig \
    --public-ip-address pip-firewall \
    --resource-group $NETWORK_RG \
    --vnet-name vnet-unified

# Application rules for cross-environment communication
az network firewall application-rule create \
    --firewall-name $FIREWALL_NAME \
    --resource-group $NETWORK_RG \
    --collection-name AllowCrossEnvironment \
    --name AllowHTTPS \
    --protocols Https=443 Http=80 \
    --source-addresses "10.0.0.0/8" \
    --target-fqdns "*" \
    --action Allow \
    --priority 100

# Network rules for inter-resource group communication
az network firewall network-rule create \
    --firewall-name $FIREWALL_NAME \
    --resource-group $NETWORK_RG \
    --collection-name InterRGCommunication \
    --name AllowSubnetComm \
    --protocols Any \
    --source-addresses "10.0.0.0/8" \
    --destination-addresses "10.0.0.0/8" \
    --destination-ports "*" \
    --action Allow \
    --priority 100

echo "✅ Firewall configured in $NETWORK_RG for cross-RG communication"
```

---

## 🌐 DNS Configuration

### Private DNS Zones with Resource Group Distribution

```bash
#!/bin/bash
# scripts/network/configure-private-dns-v8.sh

NETWORK_RG="rg-oversight-shared-network-eastus"
VNET_NAME="vnet-unified"

# Create private DNS zones in shared network resource group
DNS_ZONES=(
    "privatelink.postgres.database.azure.com"
    "privatelink.blob.core.windows.net"
    "privatelink.redis.cache.windows.net"
    "privatelink.vaultcore.azure.net"
    "privatelink.azurewebsites.net"
    "privatelink.azurecr.io"
    "oversight.internal"  # Custom internal domain
)

for ZONE in "${DNS_ZONES[@]}"; do
    # Create zone in shared network RG
    az network private-dns zone create \
        --resource-group $NETWORK_RG \
        --name $ZONE
    
    # Link to VNet
    az network private-dns link vnet create \
        --resource-group $NETWORK_RG \
        --zone-name $ZONE \
        --name link-unified \
        --virtual-network $VNET_NAME \
        --registration-enabled false
done

# Add custom DNS records for cross-environment communication
az network private-dns record-set a add-record \
    --resource-group $NETWORK_RG \
    --zone-name oversight.internal \
    --record-set-name jenkins-main \
    --ipv4-address 10.60.2.10

az network private-dns record-set a add-record \
    --resource-group $NETWORK_RG \
    --zone-name oversight.internal \
    --record-set-name test-app \
    --ipv4-address 10.40.1.10

az network private-dns record-set a add-record \
    --resource-group $NETWORK_RG \
    --zone-name oversight.internal \
    --record-set-name saas-app \
    --ipv4-address 10.20.2.10

az network private-dns record-set a add-record \
    --resource-group $NETWORK_RG \
    --zone-name oversight.internal \
    --record-set-name customer-portal \
    --ipv4-address 10.80.4.10

echo "✅ Private DNS configured in $NETWORK_RG with cross-environment records"
```

---

## 🔗 Service Endpoints & Private Links

### Configure Private Endpoints by Resource Group

```bash
#!/bin/bash
# scripts/network/configure-private-endpoints-v8.sh

NETWORK_RG="rg-oversight-shared-network-eastus"
PROD_SAAS_RG="rg-oversight-prod-saas-eastus"
PROD_CBE_RG="rg-oversight-prod-cbe-eastus"
DEV_RG="rg-oversight-dev-jenkins-eastus"
VNET_NAME="vnet-unified"

echo "🔗 Configuring Private Endpoints for V8 Architecture"

# SaaS Production Private Endpoints
echo "Creating SaaS Production private endpoints..."

# Key Vault Private Endpoint (714)
KEYVAULT_ID=$(az keyvault show --name kv-oversight-prod --resource-group $PROD_SAAS_RG --query id -o tsv)
az network private-endpoint create \
    --name pe-keyvault \
    --resource-group $PROD_SAAS_RG \
    --vnet-name $VNET_NAME \
    --subnet subnet-saas-keyvault \
    --private-connection-resource-id $KEYVAULT_ID \
    --group-id vault \
    --connection-name keyvault-connection

# PostgreSQL Private Endpoint (711)
PG_ID=$(az postgres server show --name pg-oversight-prod --resource-group $PROD_SAAS_RG --query id -o tsv)
az network private-endpoint create \
    --name pe-postgresql \
    --resource-group $PROD_SAAS_RG \
    --vnet-name $VNET_NAME \
    --subnet subnet-saas-db \
    --private-connection-resource-id $PG_ID \
    --group-id postgresqlServer \
    --connection-name postgres-connection

# Storage Private Endpoint (712)
STORAGE_ID=$(az storage account show --name stoversightprod --resource-group $PROD_SAAS_RG --query id -o tsv)
az network private-endpoint create \
    --name pe-storage \
    --resource-group $PROD_SAAS_RG \
    --vnet-name $VNET_NAME \
    --subnet subnet-saas-storage \
    --private-connection-resource-id $STORAGE_ID \
    --group-id blob \
    --connection-name storage-connection

# Development Private Endpoints
echo "Creating Development private endpoints..."

# ACR Private Endpoint (308)
ACR_ID=$(az acr show --name acrsecdevopsdev --resource-group $DEV_RG --query id -o tsv)
az network private-endpoint create \
    --name pe-acr \
    --resource-group $DEV_RG \
    --vnet-name $VNET_NAME \
    --subnet subnet-dev-acr \
    --private-connection-resource-id $ACR_ID \
    --group-id registry \
    --connection-name acr-connection

echo "✅ Private endpoints configured across resource groups"
```

---

## 🚦 Traffic Flow Patterns

### External → Internal
```
Internet → IP Check (801) → WAF (802) → App Gateway (803) → 
Firewall (811) → Internal Service (Cross-RG routing)
```

### CI/CD Flow
```
GitHub (201) → Webhook → IP Check → Jenkins (301 in dev-jenkins-eastus) → 
ACR (308 in dev-jenkins-eastus) → Test (401 in test-acs-eastus) → 
Production (700 in prod-saas-eastus with /home/jez/code/SaaS)
```

### Cross-Environment Communication
```
Jenkins (rg-oversight-dev-jenkins-eastus) ↔ Test (rg-oversight-test-acs-eastus)
Test (rg-oversight-test-acs-eastus) ↔ SaaS (rg-oversight-prod-saas-eastus)
CBE Portal (rg-oversight-prod-cbe-eastus) ↔ Monitoring (rg-oversight-shared-monitoring-eastus)
```

### Test Access
```
Kali (192.168.1.100) → Direct Network → Test Environment (10.40.1.0/24 in test-acs-eastus)
(No gateway required - local network access)
```

---

## 🔧 Network Troubleshooting

### Resource Group Network Validation

```bash
#!/bin/bash
# scripts/network/validate-v8-networking.sh

echo "🔍 Validating V8 Network Configuration"

# Check all resource groups exist
EXPECTED_RGS=(
    "rg-oversight-shared-network-eastus"
    "rg-oversight-shared-monitoring-eastus"
    "rg-oversight-dev-jenkins-eastus"
    "rg-oversight-test-acs-eastus"
    "rg-oversight-prod-saas-eastus"
    "rg-oversight-prod-cbe-eastus"
)

for RG in "${EXPECTED_RGS[@]}"; do
    if az group show --name $RG >/dev/null 2>&1; then
        echo "✅ Resource Group: $RG"
        
        # Check network resources in each RG
        RESOURCE_COUNT=$(az resource list --resource-group $RG --query "length([?type=='Microsoft.Network/virtualNetworks' || contains(type, 'Microsoft.Network')])")
        echo "   Network resources: $RESOURCE_COUNT"
    else
        echo "❌ Missing Resource Group: $RG"
    fi
done

# Test cross-RG connectivity
echo ""
echo "🔍 Testing cross-resource group connectivity..."

# Test IP allowlist
curl -I https://172.178.53.198
# Should return 403 if your IP is not allowed

# Test from allowed IP
curl -H "X-Forwarded-For: 140.82.112.1" https://172.178.53.198
# Should return 200 if GitHub webhook IP

# Check firewall logs
az network firewall log show \
    --firewall-name fw-oversight-central \
    --resource-group rg-oversight-shared-network-eastus \
    --query "['AzureFirewallApplicationRule', 'AzureFirewallNetworkRule']"

# Verify DNS resolution across environments
nslookup jenkins-main.oversight.internal
# Should resolve to 10.60.2.10

nslookup saas-app.oversight.internal
# Should resolve to 10.20.2.10

nslookup customer-portal.oversight.internal
# Should resolve to 10.80.4.10

# Test private endpoint resolution
nslookup kv-oversight-prod.vault.azure.net
# Should resolve to private IP in 10.20.6.0/24 range
```

### Common V8 Network Issues & Solutions

| Issue | Resource Group | Solution |
|-------|----------------|----------|
| Cannot access from external | rg-oversight-shared-network-eastus | Add IP to allowlist: `./scripts/add-ip.sh` |
| Inter-RG service unreachable | Any | Check firewall rules and cross-RG routing |
| DNS not resolving | rg-oversight-shared-network-eastus | Verify private DNS zone links |
| Private endpoint not working | Service-specific RG | Check subnet service endpoints |
| SaaS integration issues | rg-oversight-prod-saas-eastus | Verify /home/jez/code/SaaS path configuration |
| Portal integration issues | rg-oversight-prod-cbe-eastus | Verify /home/jez/code/customer-portal-v2 path |

---

## 📊 Network Monitoring

### Enable Network Watcher for V8

```bash
#!/bin/bash
# scripts/network/enable-monitoring-v8.sh

NETWORK_RG="rg-oversight-shared-network-eastus"
MONITORING_RG="rg-oversight-shared-monitoring-eastus"

# Enable Network Watcher
az network watcher configure \
    --resource-group $NETWORK_RG \
    --locations eastus \
    --enabled

# Enable NSG flow logs
az network watcher flow-log create \
    --name fl-nsg-gateway \
    --nsg nsg-gateway-master \
    --resource-group $NETWORK_RG \
    --location eastus \
    --storage-account stoversightlogs

# Create monitoring dashboard in monitoring RG
az monitor dashboard create \
    --resource-group $MONITORING_RG \
    --name "V8-Network-Dashboard" \
    --input-path network-dashboard-v8.json

echo "✅ Network monitoring enabled across V8 resource groups"
```

### Cross-Resource Group Traffic Monitoring

```bash
#!/bin/bash
# scripts/network/monitor-cross-rg-traffic.sh

echo "📊 Monitoring Cross-Resource Group Traffic"

# Monitor traffic between dev and test environments
az monitor metrics list \
    --resource "fw-oversight-central" \
    --resource-group rg-oversight-shared-network-eastus \
    --metric "NetworkRuleHit" \
    --filter "SourceIp contains '10.60.' and DestinationIp contains '10.40.'"

# Monitor SaaS production traffic
az monitor metrics list \
    --resource "fw-oversight-central" \
    --resource-group rg-oversight-shared-network-eastus \
    --metric "ApplicationRuleHit" \
    --filter "DestinationIp contains '10.20.'"

# Monitor CBE environment traffic
az monitor metrics list \
    --resource "fw-oversight-central" \
    --resource-group rg-oversight-shared-network-eastus \
    --metric "ApplicationRuleHit" \
    --filter "DestinationIp contains '10.80.'"
```

---

## ✅ Network Configuration Checklist

### V8 Resource Group Network Setup
- [ ] **rg-oversight-shared-network-eastus** - Unified VNet created (10.0.0.0/8)
- [ ] **rg-oversight-shared-network-eastus** - All subnets configured per table
- [ ] **rg-oversight-shared-network-eastus** - IP allowlist NSG applied to gateway
- [ ] **rg-oversight-shared-network-eastus** - Azure Firewall deployed and configured
- [ ] **rg-oversight-shared-network-eastus** - Private DNS zones created and linked

### Environment-Specific Network Configuration
- [ ] **rg-oversight-dev-jenkins-eastus** - ACR private endpoint configured
- [ ] **rg-oversight-test-acs-eastus** - Test environment network isolation
- [ ] **rg-oversight-prod-saas-eastus** - SaaS private endpoints for all services
- [ ] **rg-oversight-prod-cbe-eastus** - CBE network with portal access
- [ ] **rg-oversight-shared-monitoring-eastus** - Monitoring network components

### Integration & Connectivity
- [ ] Network Watcher enabled across all regions
- [ ] Flow logs configured for security monitoring
- [ ] DNS records added for cross-environment services
- [ ] Bastion configured for admin access in appropriate RGs
- [ ] All public IPs removed (except gateway)
- [ ] Local access configured for Kali testing
- [ ] Cross-resource group routing verified
- [ ] SaaS app network integration with /home/jez/code/SaaS verified
- [ ] Customer portal network integration with /home/jez/code/customer-portal-v2 verified

### Resource Group Naming Compliance
- [ ] All network resources follow `rg-oversight-{env}-{component}-{region}` naming
- [ ] Resource group tags properly applied for identification
- [ ] Network security groups properly distributed across RGs
- [ ] Private endpoints created in appropriate resource groups

---

## 🎯 V8 Network Architecture Benefits

### Improved Organization
- **Resource Group Separation**: Clear separation of concerns across environments
- **Standardized Naming**: Consistent resource group naming for operational clarity
- **Environment Isolation**: Network-level isolation between dev, test, and production

### Enhanced Integration
- **SaaS Integration**: Direct network path to existing SaaS codebase at `/home/jez/code/SaaS`
- **Portal Integration**: Dedicated network configuration for customer portal at `/home/jez/code/customer-portal-v2`
- **Cross-Environment Communication**: Optimized routing between resource groups

### Operational Excellence
- **Centralized Monitoring**: Shared monitoring resource group for all network telemetry
- **Simplified Management**: Clear ownership model for network components
- **Scalability**: Resource group structure supports future environment additions

---

This network configuration implements the V8 simplified, IP-restricted architecture with complete security isolation, standardized resource group organization, and integration with existing codebases.