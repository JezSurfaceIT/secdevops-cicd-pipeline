#!/bin/bash
set -e

# Configuration
RESOURCE_GROUP="rg-secdevops-cicd-dev"
LOCATION="eastus"
VNET_NAME="vnet-secdevops-test"
SUBNET_CONTAINER="subnet-containers"
SUBNET_APPGW="subnet-appgateway"
APPGW_NAME="appgw-secdevops-test"
WAF_POLICY_NAME="waf-policy-secdevops"
PUBLIC_IP_NAME="pip-appgw-secdevops"
CONTAINER_NAME="dummy-app-private"
APP_IMAGE="acrsecdevopsdev.azurecr.io/dummy-app-e2e-test:v1.1"
ALLOWED_IP="${1:-86.3.129.121}"  # Your IP address

echo "Setting up Application Gateway with IP restrictions for IP: $ALLOWED_IP"

# Step 1: Create VNet with subnets
echo "Creating Virtual Network..."
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefix 10.0.0.0/16 \
  --subnet-name $SUBNET_CONTAINER \
  --subnet-prefix 10.0.1.0/24 \
  --location $LOCATION

echo "Adding Application Gateway subnet..."
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $SUBNET_APPGW \
  --address-prefix 10.0.2.0/24

# Step 2: Create Network Profile for Container Instance
echo "Creating network profile for containers..."
SUBNET_ID=$(az network vnet subnet show \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $SUBNET_CONTAINER \
  --query id -o tsv)

# Enable subnet delegation for container instances
az network vnet subnet update \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $SUBNET_CONTAINER \
  --delegations Microsoft.ContainerInstance/containerGroups

# Step 3: Deploy container in private subnet
echo "Deploying container in private network..."
az container create \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --image $APP_IMAGE \
  --cpu 1 \
  --memory 1 \
  --os-type Linux \
  --subnet $SUBNET_ID \
  --registry-login-server acrsecdevopsdev.azurecr.io \
  --registry-username $(az acr credential show --name acrsecdevopsdev --query username -o tsv) \
  --registry-password $(az acr credential show --name acrsecdevopsdev --query passwords[0].value -o tsv) \
  --ports 3001 \
  --location $LOCATION \
  --environment-variables NODE_ENV=test \
  --restart-policy Always

# Get container private IP
CONTAINER_IP=$(az container show \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --query ipAddress.ip -o tsv)

echo "Container deployed with private IP: $CONTAINER_IP"

# Step 4: Create Public IP for Application Gateway
echo "Creating public IP for Application Gateway..."
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_NAME \
  --sku Standard \
  --allocation-method Static \
  --location $LOCATION

# Step 5: Create WAF Policy with IP restriction
echo "Creating WAF policy with IP restrictions..."
az network application-gateway waf-policy create \
  --resource-group $RESOURCE_GROUP \
  --name $WAF_POLICY_NAME \
  --location $LOCATION

# Update WAF policy settings to Prevention mode
az network application-gateway waf-policy policy-setting update \
  --resource-group $RESOURCE_GROUP \
  --policy-name $WAF_POLICY_NAME \
  --state Enabled \
  --mode Prevention

# Create custom rule for IP restriction with match conditions in JSON format
echo "Adding IP restriction rules..."
cat > /tmp/waf-rules.json << EOF
[
  {
    "name": "AllowSpecificIP",
    "priority": 1,
    "ruleType": "MatchRule",
    "action": "Allow",
    "matchConditions": [
      {
        "matchVariables": [
          {
            "variableName": "RemoteAddr"
          }
        ],
        "operator": "IPMatch",
        "matchValues": ["$ALLOWED_IP"],
        "negationCondition": false,
        "transforms": []
      }
    ]
  },
  {
    "name": "BlockAllOthers",
    "priority": 2,
    "ruleType": "MatchRule",
    "action": "Block",
    "matchConditions": [
      {
        "matchVariables": [
          {
            "variableName": "RemoteAddr"
          }
        ],
        "operator": "IPMatch",
        "matchValues": ["0.0.0.0/0"],
        "negationCondition": false,
        "transforms": []
      }
    ]
  }
]
EOF

# Update WAF policy with custom rules
az network application-gateway waf-policy update \
  --resource-group $RESOURCE_GROUP \
  --name $WAF_POLICY_NAME \
  --set customRules=@/tmp/waf-rules.json

# Step 6: Create Application Gateway
echo "Creating Application Gateway (this may take 15-20 minutes)..."
az network application-gateway create \
  --resource-group $RESOURCE_GROUP \
  --name $APPGW_NAME \
  --location $LOCATION \
  --vnet-name $VNET_NAME \
  --subnet $SUBNET_APPGW \
  --public-ip-address $PUBLIC_IP_NAME \
  --http-settings-cookie-based-affinity Disabled \
  --http-settings-port 3001 \
  --http-settings-protocol Http \
  --frontend-port 80 \
  --sku WAF_v2 \
  --capacity 1 \
  --servers $CONTAINER_IP \
  --waf-policy $WAF_POLICY_NAME \
  --priority 1

# Get Application Gateway public IP
APPGW_IP=$(az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_NAME \
  --query ipAddress -o tsv)

echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo "Application Gateway IP: $APPGW_IP"
echo "Allowed IP: $ALLOWED_IP"
echo "Application URL: http://$APPGW_IP"
echo "Container (private): $CONTAINER_IP:3001"
echo ""
echo "Only requests from IP $ALLOWED_IP will be allowed."
echo "All other IPs will be blocked by WAF."