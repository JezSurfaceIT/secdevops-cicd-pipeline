# Network Configuration Guide - V7 Architecture
## Simplified Unified Network with IP Restrictions

**Version:** 1.0  
**Date:** 2025-09-21  
**Based on:** Architecture V7

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

## 📋 Subnet Allocation Table

| Network Segment | CIDR | Component ID | Purpose |
|-----------------|------|--------------|---------|
| **Hub Services** | | | |
| AzureFirewallSubnet | 10.10.0.0/26 | 811 | Azure Firewall |
| AzureBastionSubnet | 10.10.1.0/24 | 812 | Bastion Host |
| **SaaS Production** | | | |
| subnet-saas-app | 10.20.2.0/24 | 701 | SaaS Application |
| subnet-saas-db | 10.20.3.0/24 | 711 | PostgreSQL |
| subnet-saas-storage | 10.20.4.0/24 | 712 | Blob Storage |
| subnet-saas-redis | 10.20.5.0/24 | 713 | Redis Cache |
| subnet-saas-keyvault | 10.20.6.0/24 | 714 | Key Vault |
| subnet-saas-tenant | 10.20.7.0/24 | 729 | **ROADMAP** Multi-tenant |
| **Test Environment** | | | |
| subnet-test-app | 10.40.1.0/24 | 401 | Test Container |
| subnet-test-vault | 10.40.2.0/24 | 303 | HashiCorp Vault |
| **Development** | | | |
| subnet-dev-avd | 10.60.1.0/24 | 103 | Azure AVD |
| subnet-dev-jenkins | 10.60.2.0/24 | 301,501 | Jenkins CI/CD |
| subnet-dev-acr | 10.60.3.0/24 | 308 | Container Registry |
| **CBE Mimic** | | | |
| subnet-cbe-mimic | 10.80.1.0/24 | 860 | CBE Test |
| subnet-cbe-vault | 10.80.2.0/24 | 871 | CBE Vault |
| subnet-cbe-db | 10.80.3.0/24 | 872 | CBE PostgreSQL |
| subnet-cbe-portal | 10.80.4.0/24 | 902 | Customer Portal |
| subnet-cbe-guac | 10.80.5.0/24 | 873 | Guacamole |
| **Monitoring** | | | |
| subnet-monitoring | 10.90.1.0/24 | 1001-1005 | Prometheus/Grafana |

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
# scripts/network/configure-nsgs.sh

RESOURCE_GROUP="rg-oversight-unified"

# Create master NSG for gateway
az network nsg create \
    --resource-group $RESOURCE_GROUP \
    --name nsg-gateway-master \
    --location uksouth

# Apply IP restrictions at gateway
PRIORITY=100
for RULE in "${ALLOWED_EXTERNAL_IPS[@]}"; do
    IP="${RULE%%:*}"
    NAME="${RULE#*:}"
    
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
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
    --resource-group $RESOURCE_GROUP \
    --nsg-name nsg-gateway-master \
    --name "DenyAllInbound" \
    --priority 4096 \
    --source-address-prefixes '*' \
    --destination-port-ranges '*' \
    --access Deny \
    --protocol '*' \
    --direction Inbound
```

---

## 🔥 Azure Firewall Configuration (Component 811)

### Firewall Rules for Internal Traffic

```bash
#!/bin/bash
# scripts/network/configure-firewall.sh

RESOURCE_GROUP="rg-oversight-unified"
FIREWALL_NAME="fw-oversight-central"

# Deploy Azure Firewall
az network firewall create \
    --name $FIREWALL_NAME \
    --resource-group $RESOURCE_GROUP \
    --location uksouth

# Configure IP configuration
az network public-ip create \
    --name pip-firewall \
    --resource-group $RESOURCE_GROUP \
    --allocation-method Static \
    --sku Standard

az network firewall ip-config create \
    --firewall-name $FIREWALL_NAME \
    --name fw-ipconfig \
    --public-ip-address pip-firewall \
    --resource-group $RESOURCE_GROUP \
    --vnet-name vnet-unified

# Application rules
az network firewall application-rule create \
    --firewall-name $FIREWALL_NAME \
    --resource-group $RESOURCE_GROUP \
    --collection-name AllowWebTraffic \
    --name AllowHTTPS \
    --protocols Https=443 Http=80 \
    --source-addresses "10.0.0.0/8" \
    --target-fqdns "*" \
    --action Allow \
    --priority 100

# Network rules for internal communication
az network firewall network-rule create \
    --firewall-name $FIREWALL_NAME \
    --resource-group $RESOURCE_GROUP \
    --collection-name InternalTraffic \
    --name AllowSubnetComm \
    --protocols Any \
    --source-addresses "10.0.0.0/8" \
    --destination-addresses "10.0.0.0/8" \
    --destination-ports "*" \
    --action Allow \
    --priority 100
```

---

## 🌐 DNS Configuration

### Private DNS Zones

```bash
#!/bin/bash
# scripts/network/configure-private-dns.sh

RESOURCE_GROUP="rg-oversight-unified"
VNET_NAME="vnet-unified"

# Create private DNS zones
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
    # Create zone
    az network private-dns zone create \
        --resource-group $RESOURCE_GROUP \
        --name $ZONE
    
    # Link to VNet
    az network private-dns link vnet create \
        --resource-group $RESOURCE_GROUP \
        --zone-name $ZONE \
        --name link-unified \
        --virtual-network $VNET_NAME \
        --registration-enabled false
done

# Add custom DNS records
az network private-dns record-set a add-record \
    --resource-group $RESOURCE_GROUP \
    --zone-name oversight.internal \
    --record-set-name jenkins-main \
    --ipv4-address 10.60.2.10

az network private-dns record-set a add-record \
    --resource-group $RESOURCE_GROUP \
    --zone-name oversight.internal \
    --record-set-name test-app \
    --ipv4-address 10.40.1.10
```

---

## 🔗 Service Endpoints & Private Links

### Configure Private Endpoints

```bash
#!/bin/bash
# scripts/network/configure-private-endpoints.sh

RESOURCE_GROUP="rg-oversight-unified"
VNET_NAME="vnet-unified"

# Key Vault Private Endpoint (714)
KEYVAULT_ID=$(az keyvault show --name kv-oversight-prod --resource-group $RESOURCE_GROUP --query id -o tsv)

az network private-endpoint create \
    --name pe-keyvault \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --subnet subnet-saas-keyvault \
    --private-connection-resource-id $KEYVAULT_ID \
    --group-id vault \
    --connection-name keyvault-connection

# PostgreSQL Private Endpoint (711)
PG_ID=$(az postgres server show --name pg-oversight-prod --resource-group $RESOURCE_GROUP --query id -o tsv)

az network private-endpoint create \
    --name pe-postgresql \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --subnet subnet-saas-db \
    --private-connection-resource-id $PG_ID \
    --group-id postgresqlServer \
    --connection-name postgres-connection

# Storage Private Endpoint (712)
STORAGE_ID=$(az storage account show --name stoversightprod --resource-group $RESOURCE_GROUP --query id -o tsv)

az network private-endpoint create \
    --name pe-storage \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --subnet subnet-saas-storage \
    --private-connection-resource-id $STORAGE_ID \
    --group-id blob \
    --connection-name storage-connection
```

---

## 🚦 Traffic Flow Patterns

### External → Internal

```
Internet → IP Check (801) → WAF (802) → App Gateway (803) → 
Firewall (811) → Internal Service
```

### CI/CD Flow

```
GitHub (201) → Webhook → IP Check → Jenkins (301) → 
ACR (308) → Test (401) → Production (701)
```

### Test Access

```
Kali (192.168.1.100) → Direct Network → Test Environment (10.40.1.0/24)
(No gateway required - local network access)
```

---

## 🔧 Network Troubleshooting

### Check Connectivity

```bash
# Test IP allowlist
curl -I https://172.178.53.198
# Should return 403 if your IP is not allowed

# Test from allowed IP
curl -H "X-Forwarded-For: 140.82.112.1" https://172.178.53.198
# Should return 200 if GitHub webhook IP

# Check firewall logs
az network firewall log show \
    --firewall-name fw-oversight-central \
    --resource-group rg-oversight-unified \
    --query "['AzureFirewallApplicationRule', 'AzureFirewallNetworkRule']"

# Verify DNS resolution
nslookup jenkins-main.oversight.internal
# Should resolve to 10.60.2.10

# Test private endpoint
nslookup kv-oversight-prod.vault.azure.net
# Should resolve to private IP in 10.20.6.0/24 range
```

### Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Cannot access from external | Add IP to allowlist: `./scripts/add-ip.sh` |
| Internal service unreachable | Check firewall rules and NSGs |
| DNS not resolving | Verify private DNS zone links |
| Private endpoint not working | Check subnet service endpoints |

---

## 📊 Network Monitoring

### Enable Network Watcher

```bash
# Enable Network Watcher
az network watcher configure \
    --resource-group rg-oversight-unified \
    --locations uksouth \
    --enabled

# Enable NSG flow logs
az network watcher flow-log create \
    --name fl-nsg-gateway \
    --nsg nsg-gateway-master \
    --resource-group rg-oversight-unified \
    --location uksouth \
    --storage-account stoversightlogs
```

### Monitor Traffic

```bash
# View allowed traffic
az monitor metrics list \
    --resource "nsg-gateway-master" \
    --resource-group rg-oversight-unified \
    --metric "BytesInAllowed"

# View blocked traffic
az monitor metrics list \
    --resource "nsg-gateway-master" \
    --resource-group rg-oversight-unified \
    --metric "BytesInBlocked"
```

---

## ✅ Network Configuration Checklist

- [ ] Unified VNet created (10.0.0.0/8)
- [ ] All subnets configured per table
- [ ] IP allowlist NSG applied to gateway
- [ ] Azure Firewall deployed and configured
- [ ] Private DNS zones created and linked
- [ ] Private endpoints configured for all services
- [ ] Network Watcher enabled
- [ ] Flow logs configured
- [ ] DNS records added for internal services
- [ ] Bastion configured for admin access
- [ ] All public IPs removed (except gateway)
- [ ] Local access configured for Kali testing

---

This network configuration implements the simplified, IP-restricted architecture from V7 with complete security isolation.