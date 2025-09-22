#!/bin/bash

# Azure VPN Gateway Setup Script
# Creates Point-to-Site VPN for Kali Linux penetration testing access

set -e

# Environment variables
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-secdevops-rg}"
LOCATION="${AZURE_LOCATION:-eastus}"
VNET_NAME="vnet-secdevops"
GATEWAY_SUBNET_NAME="GatewaySubnet"
GATEWAY_NAME="vpn-secdevops"
PUBLIC_IP_NAME="pip-vpn-secdevops"
VPN_CLIENT_ADDRESS_POOL="${VPN_ADDRESS_POOL:-172.16.0.0/24}"

echo "🔧 Starting Azure VPN Gateway Setup..."

# Check if logged into Azure
if ! az account show >/dev/null 2>&1; then
    echo "❌ Not logged into Azure. Please run: az login"
    exit 1
fi

# Create public IP for VPN Gateway
echo "📍 Creating public IP address..."
az network public-ip create \
    --resource-group $RESOURCE_GROUP \
    --name $PUBLIC_IP_NAME \
    --allocation-method Dynamic \
    --sku Basic \
    --location $LOCATION || echo "Public IP may already exist"

# Check if Gateway subnet exists
echo "🔍 Checking for Gateway subnet..."
GATEWAY_SUBNET_EXISTS=$(az network vnet subnet show \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $GATEWAY_SUBNET_NAME \
    --query "name" -o tsv 2>/dev/null || echo "")

if [ -z "$GATEWAY_SUBNET_EXISTS" ]; then
    echo "➕ Creating Gateway subnet..."
    az network vnet subnet create \
        --resource-group $RESOURCE_GROUP \
        --vnet-name $VNET_NAME \
        --name $GATEWAY_SUBNET_NAME \
        --address-prefixes 10.40.255.0/27
else
    echo "✅ Gateway subnet already exists"
fi

# Create VPN Gateway (this takes ~45 minutes)
echo "🔄 Creating VPN Gateway (this will take ~45 minutes)..."
az network vnet-gateway create \
    --resource-group $RESOURCE_GROUP \
    --name $GATEWAY_NAME \
    --location $LOCATION \
    --vnet $VNET_NAME \
    --public-ip-address $PUBLIC_IP_NAME \
    --gateway-type Vpn \
    --vpn-type RouteBased \
    --sku VpnGw1 \
    --generation Generation1 \
    --address-prefixes $VPN_CLIENT_ADDRESS_POOL \
    --client-protocol OpenVPN IkeV2 \
    --no-wait

echo "⏳ VPN Gateway creation started. Monitor with:"
echo "   watch -n 30 'az network vnet-gateway show --name $GATEWAY_NAME --resource-group $RESOURCE_GROUP --query \"provisioningState\"'"

# Generate root certificate for P2S authentication
echo "🔑 Generating root certificate..."
./generate-vpn-certs.sh

# Upload root certificate to VPN Gateway (run after gateway is ready)
echo ""
echo "📝 Next steps after gateway is ready:"
echo "1. Upload root certificate:"
echo "   az network vnet-gateway root-cert create \\"
echo "     --resource-group $RESOURCE_GROUP \\"
echo "     --gateway-name $GATEWAY_NAME \\"
echo "     --name P2SRootCert \\"
echo "     --public-cert-data \$(cat certs/vpn-root.cer)"
echo ""
echo "2. Download VPN client configuration:"
echo "   az network vnet-gateway vpn-client generate \\"
echo "     --resource-group $RESOURCE_GROUP \\"
echo "     --name $GATEWAY_NAME \\"
echo "     --processor-architecture Amd64"
echo ""
echo "3. Configure Kali client with downloaded configuration"

# Create status check script
cat > check-vpn-status.sh << 'EOF'
#!/bin/bash
GATEWAY_NAME="vpn-secdevops"
RESOURCE_GROUP="secdevops-rg"

STATUS=$(az network vnet-gateway show \
    --name $GATEWAY_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "provisioningState" -o tsv)

echo "VPN Gateway Status: $STATUS"

if [ "$STATUS" == "Succeeded" ]; then
    echo "✅ VPN Gateway is ready!"
    
    # Get public IP
    PUBLIC_IP=$(az network vnet-gateway show \
        --name $GATEWAY_NAME \
        --resource-group $RESOURCE_GROUP \
        --query "bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]" -o tsv)
    
    echo "📍 Gateway Public IP: $PUBLIC_IP"
else
    echo "⏳ Still provisioning... (~45 minutes total)"
fi
EOF

chmod +x check-vpn-status.sh

echo "✅ Setup script complete. Run ./check-vpn-status.sh to monitor progress."