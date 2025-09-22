# Quick Deploy: Oversight MVP to ACS

## One-Command Deployment

```bash
# Deploy Oversight MVP v1.0
./deploy-oversight-single-script.sh v1.0
```

That's it! This single command will:
1. ✅ Build the Oversight Docker image
2. ✅ Push to Azure Container Registry
3. ✅ Run full E2E CI/CD pipeline (security scans, tests, quality gates)
4. ✅ Deploy to Azure Container Service
5. ✅ Configure networking and security

## What the E2E Pipeline Does

The `run-e2e-pipeline.sh` script automatically:
- 🔒 Runs Trivy security scanning
- 🧪 Executes unit tests  
- 📊 Checks code coverage (>80% required)
- 🚀 Deploys to Azure Container Instance
- ✅ Validates deployment health
- 📈 ~100 second total execution

## Verify Deployment

```bash
# Check container status
az container list --resource-group rg-secdevops-cicd-dev --output table

# View logs
az container logs --resource-group rg-secdevops-cicd-dev --name oversight-mvp-test

# Get container IP
az container show --resource-group rg-secdevops-cicd-dev --name oversight-mvp-test --query ipAddress.ip -o tsv

# Test application
curl http://<CONTAINER_IP>:8000/health
```

## Access URLs

- **Via Application Gateway (WAF-protected)**: http://172.178.53.198
- **Direct Container**: Use IP from command above
- **Monitoring**: http://localhost:3000 (Grafana)

## Resource Group
All resources are in: `rg-secdevops-cicd-dev`

## Rollback if Needed

```bash
# Quick rollback to previous version
./scripts/deployment/blue-green-rollback.sh oversight-mvp blue
```

## That's All! 
The existing E2E pipeline handles everything automatically.