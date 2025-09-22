<!-- Powered by BMAD™ Core -->

# Azure Resource Naming Convention - MANDATORY

## Overview
This document defines the MANDATORY naming conventions for all Azure resources. These conventions ensure consistency, clarity, and proper resource organization across all environments.

## Resource Group Naming Convention

### Format
```
e2e-{environment}-{region}-{project}-{component}-{instance}
```

### Components

#### Environment (Required)
- `dev` - Development environment
- `test` - Testing environment  
- `staging` - Staging/Pre-production environment
- `prod` - Production environment

#### Region (Required)
Standard Azure region abbreviations:
- `eus` - East US
- `eus2` - East US 2
- `wus` - West US
- `wus2` - West US 2
- `cus` - Central US
- `neu` - North Europe
- `weu` - West Europe
- `uksouth` - UK South
- `ukwest` - UK West
- `sea` - Southeast Asia
- `eau` - East Australia

#### Project (Required)
- Abbreviated project name
- Maximum 10 characters
- Use lowercase letters only
- Examples: `secops`, `oversight`, `monitor`, `infra`

#### Component (Required)
- `app` - Application resources
- `data` - Databases, storage accounts
- `network` - Virtual networks, NSGs, load balancers
- `security` - Key vaults, security resources
- `shared` - Shared services
- `monitoring` - Monitoring and logging resources

#### Instance (Required)
- 3-digit number: `001`, `002`, `003`
- Always start with `001`
- Increment for multiple instances

### Examples
- `e2e-prod-eus-secops-app-001` - Production SecOps application in East US
- `e2e-dev-weu-monitor-data-001` - Development monitoring database in West Europe
- `e2e-test-neu-infra-network-002` - Test infrastructure network (instance 2) in North Europe

## Child Resource Naming Conventions

### Virtual Machines
```
vm-{purpose}-{environment}-{instance}
```
Example: `vm-web-prod-001`, `vm-db-dev-002`

### Storage Accounts
```
st{project}{environment}{instance}
```
Example: `stsecdevops001`, `stmonitorprod002`
(Note: Storage accounts must be globally unique, lowercase, no hyphens)

### Virtual Networks
```
vnet-{environment}-{region}-{project}-{instance}
```
Example: `vnet-prod-eus-secops-001`

### Subnets
```
snet-{purpose}-{instance}
```
Example: `snet-frontend-001`, `snet-backend-002`

### Network Security Groups
```
nsg-{subnet-name}
```
Example: `nsg-snet-frontend-001`

### Key Vaults
```
kv-{project}-{environment}-{instance}
```
Example: `kv-secops-prod-001`

### App Services
```
app-{project}-{purpose}-{environment}
```
Example: `app-secops-api-prod`

### SQL Databases
```
sqldb-{project}-{environment}-{instance}
```
Example: `sqldb-secops-prod-001`

### Container Registries
```
cr{project}{environment}{instance}
```
Example: `crsecdevops001`
(Note: Container registries must be globally unique, alphanumeric only)

### AKS Clusters
```
aks-{project}-{environment}-{region}-{instance}
```
Example: `aks-secops-prod-eus-001`

## Tagging Strategy

### Mandatory Tags
All resources MUST have these tags:

```json
{
  "environment": "dev|test|staging|prod",
  "project": "project-name",
  "owner": "team-or-person",
  "cost-center": "cost-center-code",
  "created-date": "YYYY-MM-DD",
  "managed-by": "terraform|arm|bicep",
  "component": "app|data|network|security|shared|monitoring"
}
```

### Optional Tags
```json
{
  "criticality": "low|medium|high|critical",
  "data-classification": "public|internal|confidential|restricted",
  "backup-policy": "daily|weekly|monthly",
  "maintenance-window": "day-time",
  "compliance": "pci|hipaa|gdpr|sox"
}
```

## Implementation in IaC

### Terraform Example
```hcl
resource "azurerm_resource_group" "main" {
  name     = "e2e-${var.environment}-${var.region}-${var.project}-app-001"
  location = var.location
  
  tags = {
    environment    = var.environment
    project        = var.project
    owner          = var.owner
    cost-center    = var.cost_center
    created-date   = formatdate("YYYY-MM-DD", timestamp())
    managed-by     = "terraform"
    component      = "app"
  }
}
```

### ARM Template Example
```json
{
  "type": "Microsoft.Resources/resourceGroups",
  "apiVersion": "2021-04-01",
  "name": "[concat('e2e-', parameters('environment'), '-', parameters('region'), '-', parameters('project'), '-app-001')]",
  "location": "[parameters('location')]",
  "tags": {
    "environment": "[parameters('environment')]",
    "project": "[parameters('project')]",
    "owner": "[parameters('owner')]",
    "cost-center": "[parameters('costCenter')]",
    "created-date": "[utcNow('yyyy-MM-dd')]",
    "managed-by": "arm",
    "component": "app"
  }
}
```

### Bicep Example
```bicep
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'e2e-${environment}-${region}-${project}-app-001'
  location: location
  tags: {
    environment: environment
    project: project
    owner: owner
    'cost-center': costCenter
    'created-date': utcNow('yyyy-MM-dd')
    'managed-by': 'bicep'
    component: 'app'
  }
}
```

## Validation Rules

### DO's
- ✅ Always use lowercase letters
- ✅ Use hyphens to separate components
- ✅ Follow the exact format specified
- ✅ Include all mandatory components
- ✅ Apply consistent naming across environments
- ✅ Document any exceptions with justification

### DON'Ts
- ❌ Never use spaces or underscores
- ❌ Never skip environment or region identifiers
- ❌ Never exceed Azure naming length limits
- ❌ Never use special characters (except hyphens where allowed)
- ❌ Never create resources without proper naming
- ❌ Never manually name resources - use IaC variables

## Enforcement

### Pre-Deployment Validation
```bash
# Validate resource names in Terraform
terraform validate

# Validate ARM template
az deployment group validate \
  --resource-group e2e-dev-eus-project-app-001 \
  --template-file template.json

# Validate Bicep
az bicep build --file main.bicep
```

### Compliance Checking Script
```bash
#!/bin/bash
# Check if resource group name follows convention
validate_rg_name() {
  local rg_name=$1
  local pattern="^e2e-(dev|test|staging|prod)-(eus|eus2|wus|wus2|cus|neu|weu|uksouth|ukwest|sea|eau)-[a-z]{1,10}-(app|data|network|security|shared|monitoring)-[0-9]{3}$"
  
  if [[ $rg_name =~ $pattern ]]; then
    echo "✅ Valid: $rg_name"
    return 0
  else
    echo "❌ Invalid: $rg_name"
    return 1
  fi
}

# Example usage
validate_rg_name "e2e-prod-eus-secops-app-001"
```

## Migration Strategy

For existing resources that don't follow this convention:

1. **Document** existing names in migration log
2. **Plan** migration during maintenance window
3. **Create** new resources with proper names
4. **Migrate** data/configuration
5. **Update** all references
6. **Validate** functionality
7. **Delete** old resources after verification

## Exceptions

Exceptions to naming conventions require:
1. Written justification
2. Architecture team approval
3. Documentation in project wiki
4. Compensating controls for consistency

## Quick Reference

| Resource Type | Format | Example |
|--------------|--------|---------|
| Resource Group | e2e-{env}-{region}-{project}-{component}-{instance} | e2e-prod-eus-secops-app-001 |
| Virtual Machine | vm-{purpose}-{env}-{instance} | vm-web-prod-001 |
| Storage Account | st{project}{env}{instance} | stsecdevops001 |
| Virtual Network | vnet-{env}-{region}-{project}-{instance} | vnet-prod-eus-secops-001 |
| Key Vault | kv-{project}-{env}-{instance} | kv-secops-prod-001 |
| App Service | app-{project}-{purpose}-{env} | app-secops-api-prod |

---

**Remember:** Consistent naming is critical for resource management, cost tracking, security auditing, and operational excellence. NO EXCEPTIONS without documented approval.