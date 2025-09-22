#!/bin/bash
# Single Script Deployment for Oversight MVP to ACS
# Uses existing E2E pipeline infrastructure

set -e

# Configuration
APP_NAME="oversight-mvp"
VERSION="${1:-v1.0}"
OVERSIGHT_PATH="/home/jez/code/Oversight-MVP-09-04"
ACR_NAME="acrsecdevopsdev"
RESOURCE_GROUP="rg-secdevops-cicd-dev"

echo "========================================="
echo "Deploying Oversight MVP using E2E Pipeline"
echo "========================================="
echo "App: $APP_NAME"
echo "Version: $VERSION"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

# Step 1: Prepare Oversight application
echo "Step 1: Preparing Oversight application..."
cd "$OVERSIGHT_PATH"

# Create Dockerfile if it doesn't exist
if [ ! -f Dockerfile ]; then
    echo "Creating Dockerfile..."
    cat > Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
ENV PYTHONUNBUFFERED=1
CMD ["python", "app.py"]
EOF
fi

# Step 2: Build Docker image
echo "Step 2: Building Docker image..."
docker build -t $APP_NAME:$VERSION .

# Step 3: Tag for ACR
echo "Step 3: Tagging for Azure Container Registry..."
docker tag $APP_NAME:$VERSION $ACR_NAME.azurecr.io/$APP_NAME:$VERSION

# Step 4: Push to ACR
echo "Step 4: Pushing to ACR..."
az acr login --name $ACR_NAME
docker push $ACR_NAME.azurecr.io/$APP_NAME:$VERSION

# Step 5: Use the existing E2E pipeline script
echo "Step 5: Running E2E deployment pipeline..."
cd /home/jez/code/SecDevOps_CICD
./run-e2e-pipeline.sh $APP_NAME $VERSION

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo "Oversight MVP has been deployed through the E2E pipeline"
echo ""
echo "Access points:"
echo "- Direct container: Check Azure Portal for IP"
echo "- Via App Gateway: http://172.178.53.198"
echo ""
echo "Next steps:"
echo "1. Check container status: az container list --resource-group $RESOURCE_GROUP --output table"
echo "2. View logs: az container logs --resource-group $RESOURCE_GROUP --name $APP_NAME-test"
echo "3. Test health: curl http://<CONTAINER_IP>:8000/health"