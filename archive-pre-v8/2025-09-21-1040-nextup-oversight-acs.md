# Next Session: Deploy Oversight App from AVD Test to ACS
## Timestamp: 2025-09-21 10:40
## Session Owner: Noman

## Objective
Deploy the Oversight MVP application from Azure Virtual Desktop (AVD) test environment through the SecDevOps CI/CD pipeline to Azure Container Service (ACS).

## For Noman
Hey Noman! This session focuses on deploying your Oversight application using the automated E2E pipeline we've built. Everything is ready to go with a single script execution.

## Current State
- ✅ Complete SecDevOps CI/CD pipeline implemented
- ✅ Application Gateway with WAF deployed (IP: 172.178.53.198)
- ✅ Blue-green deployment strategy ready
- ✅ Full IaC in Terraform
- ✅ Resource Group: `rg-secdevops-cicd-dev`
- ✅ ACR: `acrsecdevopsdev.azurecr.io`

## Required Steps

### 1. Prepare Oversight Application
```bash
# Location of Oversight MVP
cd /home/jez/code/Oversight-MVP-09-04/

# Verify application structure
ls -la

# Check for Dockerfile
cat Dockerfile

# Review application configuration
cat config/*.yaml
```

### 2. Containerize Oversight Application
```bash
# Create/update Dockerfile for Oversight
cat > Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["python", "app.py"]
EOF

# Build container image
docker build -t oversight-mvp:v1.0 .

# Test locally
docker run -p 8000:8000 oversight-mvp:v1.0
```

### 3. Push to Azure Container Registry
```bash
# Tag for ACR
docker tag oversight-mvp:v1.0 acrsecdevopsdev.azurecr.io/oversight-mvp:v1.0

# Login to ACR
az acr login --name acrsecdevopsdev

# Push image
docker push acrsecdevopsdev.azurecr.io/oversight-mvp:v1.0
```

### 4. Deploy to ACS via Pipeline
```bash
# Use existing E2E pipeline
./run-e2e-pipeline.sh oversight-mvp v1.0

# Or deploy directly to ACS
az container create \
  --resource-group rg-secdevops-cicd-dev \
  --name oversight-mvp-test \
  --image acrsecdevopsdev.azurecr.io/oversight-mvp:v1.0 \
  --cpu 2 \
  --memory 4 \
  --ports 8000 \
  --environment-variables \
    ENV=test \
    AZURE_TENANT_ID=${TENANT_ID} \
    AZURE_CLIENT_ID=${CLIENT_ID} \
  --subnet /subscriptions/80265df9-bba2-4ad2-88af-e002fd2ca230/resourceGroups/rg-secdevops-cicd-dev/providers/Microsoft.Network/virtualNetworks/vnet-secdevops-test/subnets/subnet-containers \
  --registry-login-server acrsecdevopsdev.azurecr.io \
  --registry-username $(az acr credential show --name acrsecdevopsdev --query username -o tsv) \
  --registry-password $(az acr credential show --name acrsecdevopsdev --query passwords[0].value -o tsv)
```

### 5. Configure Application Gateway for Oversight
```bash
# Add backend pool for Oversight
az network application-gateway address-pool create \
  --gateway-name appgw-secdevops-test \
  --resource-group rg-secdevops-cicd-dev \
  --name oversight-backend \
  --servers <CONTAINER_IP>

# Add routing rule
az network application-gateway rule create \
  --gateway-name appgw-secdevops-test \
  --resource-group rg-secdevops-cicd-dev \
  --name oversight-rule \
  --http-listener appGatewayHttpListener \
  --address-pool oversight-backend \
  --http-settings appGatewayBackendHttpSettings \
  --priority 10
```

### 6. AVD Integration Points
```bash
# If Oversight needs AVD session data
# Configure managed identity for container
az container update \
  --resource-group rg-secdevops-cicd-dev \
  --name oversight-mvp-test \
  --assign-identity [system]

# Grant permissions to AVD resources
az role assignment create \
  --assignee <CONTAINER_IDENTITY> \
  --role "Desktop Virtualization Reader" \
  --scope /subscriptions/80265df9-bba2-4ad2-88af-e002fd2ca230/resourceGroups/<AVD_RG>
```

### 7. Security Scanning for Oversight
```bash
# Run security scans specific to Oversight
./scripts/security/run-zap-scan.sh http://<OVERSIGHT_IP>:8000 full

# SonarQube analysis
./scripts/quality/run-sonarqube-scan.sh oversight-mvp "Oversight MVP"

# Container security scan
docker run --rm aquasec/trivy:latest image \
  acrsecdevopsdev.azurecr.io/oversight-mvp:v1.0
```

### 8. Blue-Green Deployment for Oversight
```bash
# Deploy using blue-green strategy
./scripts/deployment/blue-green-deploy.sh oversight-mvp v1.0

# Validate deployment
curl http://<CONTAINER_IP>:8000/health

# If issues, rollback
./scripts/deployment/blue-green-rollback.sh oversight-mvp blue
```

### 9. Monitoring Setup for Oversight
```bash
# Add Oversight-specific metrics to Prometheus
cat >> /tmp/monitoring/prometheus/prometheus.yml << 'EOF'
  - job_name: 'oversight-mvp'
    static_configs:
      - targets: ['<CONTAINER_IP>:8000']
        labels:
          app: 'oversight'
          env: 'test'
EOF

# Restart Prometheus
docker restart prometheus

# Create Grafana dashboard for Oversight
# Import dashboard ID: <TO_BE_CREATED>
```

### 10. Jenkins Pipeline for Oversight
```groovy
// Add to Jenkins pipeline
stage('Deploy Oversight MVP') {
    steps {
        sh '''
            # Build and push Oversight
            docker build -t oversight-mvp:${VERSION} /home/jez/code/Oversight-MVP-09-04/
            docker tag oversight-mvp:${VERSION} acrsecdevopsdev.azurecr.io/oversight-mvp:${VERSION}
            az acr login --name acrsecdevopsdev
            docker push acrsecdevopsdev.azurecr.io/oversight-mvp:${VERSION}
            
            # Deploy to ACS
            ./run-e2e-pipeline.sh oversight-mvp ${VERSION}
        '''
    }
}
```

## Environment Variables Needed
```bash
# AVD Configuration
AVD_TENANT_ID=
AVD_SUBSCRIPTION_ID=
AVD_RESOURCE_GROUP=
AVD_HOST_POOL=

# Oversight Configuration
OVERSIGHT_DB_CONNECTION=
OVERSIGHT_API_KEY=
OVERSIGHT_AUTH_PROVIDER=

# Azure Configuration
AZURE_CLIENT_ID=
AZURE_CLIENT_SECRET=
AZURE_TENANT_ID=
```

## Validation Checklist
- [ ] Oversight application containerized
- [ ] Image pushed to ACR
- [ ] Container deployed to ACS
- [ ] Application Gateway configured
- [ ] WAF rules updated if needed
- [ ] Health endpoints responding
- [ ] AVD integration tested
- [ ] Security scans passed
- [ ] Monitoring configured
- [ ] Logs flowing to Log Analytics

## Quick Commands for Noman
```bash
# SIMPLEST OPTION - Just run this one command:
./deploy-oversight-single-script.sh v1.0

# That's it! The script does everything automatically

# After deployment, check status:
az container show --resource-group rg-secdevops-cicd-dev --name oversight-mvp-test --query instanceView.state

# View logs
az container logs --resource-group rg-secdevops-cicd-dev --name oversight-mvp-test

# Get container IP
az container show --resource-group rg-secdevops-cicd-dev --name oversight-mvp-test --query ipAddress.ip -o tsv

# Test application
curl http://<CONTAINER_IP>:8000/api/status
```

## Noman's Quick Start
```bash
# 1. Navigate to SecDevOps directory
cd /home/jez/code/SecDevOps_CICD/

# 2. Run the single deployment script
./deploy-oversight-single-script.sh v1.0

# 3. Done! Check the Application Gateway URL
echo "Access your app at: http://172.178.53.198"
```

## Success Criteria
- ✅ Oversight MVP running in ACS
- ✅ Accessible through Application Gateway
- ✅ WAF protection enabled
- ✅ Integrated with CI/CD pipeline
- ✅ Monitoring and alerts configured
- ✅ AVD session data accessible (if required)
- ✅ All security scans passing

## Next Actions After Deployment
1. Performance testing with load
2. Configure auto-scaling rules
3. Set up backup and recovery
4. Implement feature flags
5. Configure A/B testing
6. Set up continuous deployment from main branch

## Notes
- Ensure AVD test environment credentials are available
- Check if Oversight requires specific Azure services (KeyVault, Service Bus, etc.)
- Validate network connectivity between AVD and ACS
- Consider using Private Endpoints for enhanced security

Ready to deploy Oversight MVP from AVD test to ACS!