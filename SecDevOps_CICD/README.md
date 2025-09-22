# SecDevOps CI/CD Pipeline

## Overview
This repository contains the infrastructure as code (IaC) and configuration for the SecDevOps CI/CD pipeline supporting the Oversight-MVP platform.

## Project Structure
```
SecDevOps_CICD/
├── terraform/          # Infrastructure as Code
├── tests/             # Unit and integration tests
├── scripts/           # Automation scripts
├── docs/              # Documentation
└── .github/           # GitHub configuration
```

## Sprint 1 Progress
- **Status:** In Progress
- **Completed:** STORY-001-01 (Azure Networking)
- **Next:** STORY-001-02 (Jenkins VM)

## Quick Start

### Prerequisites
- Python 3.11+
- Terraform 1.0+
- Azure CLI
- Make

### Setup
```bash
# Install dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements-dev.txt

# Run tests
make test-unit

# Initialize Terraform
make init

# Plan deployment
make plan
```

## Testing
Following Test-Driven Development (TDD):
1. Write tests first (RED)
2. Implement minimum code (GREEN)
3. Refactor and optimize (REFACTOR)

## Documentation
- [Sprint Progress](docs/progress/sprint-01-progress.md)
- [Daily Updates](docs/progress/daily-updates.md)

## Technologies
- **IaC:** Terraform
- **Cloud:** Azure
- **CI/CD:** Jenkins
- **Container Registry:** Azure ACR
- **Testing:** pytest, Terratest
- **Version Control:** Git/GitHub