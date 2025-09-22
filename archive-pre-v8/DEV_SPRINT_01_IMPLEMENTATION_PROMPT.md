# Developer Implementation Prompt - Sprint 1
## SecDevOps CI/CD Pipeline - Foundation Setup

**Sprint:** 1 (Weeks 1-2)  
**Start Date:** 2025-09-20  
**Methodology:** Test-Driven Development (TDD)  
**Documentation:** Continuous Updates Required  

---

## 🎯 Your Mission

You are implementing Sprint 1 of the SecDevOps CI/CD pipeline for the Oversight-MVP platform. This sprint establishes the critical infrastructure foundation and source control configuration. You must follow TDD practices, maintain comprehensive documentation, and update progress markers throughout implementation.

---

## 📋 Sprint 1 Stories to Implement

### Priority Order:
1. **STORY-001-01:** Azure Resource Group and Networking (5 points)
2. **STORY-001-02:** Azure VM for Jenkins (8 points)  
3. **STORY-001-03:** Azure Container Registry (5 points)
4. **STORY-002-01:** GitHub Repository Configuration (5 points)
5. **STORY-002-02:** Git Hooks Implementation (5 points)

**Total Points:** 28 (core stories)

---

## 🧪 TDD Implementation Requirements

### For EACH story, follow this TDD cycle:

#### 1. RED Phase - Write Tests First
```bash
# Create test file BEFORE implementation
tests/infrastructure/test_[story_id].py
tests/integration/test_[story_id]_integration.py
```

#### 2. GREEN Phase - Implement Minimum Code
```bash
# Implement just enough to pass tests
terraform/modules/[module_name]/
scripts/[script_name].sh
```

#### 3. REFACTOR Phase - Optimize and Clean
```bash
# Refactor while keeping tests green
# Update documentation
# Commit with descriptive message
```

---

## 📁 Project Structure to Create

```
SecDevOps_CICD/
├── .github/
│   ├── workflows/
│   │   └── terraform-test.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── security_issue.md
│   ├── pull_request_template.md
│   └── CODEOWNERS
├── terraform/
│   ├── environments/
│   │   ├── dev.tfvars
│   │   ├── test.tfvars
│   │   └── prod.tfvars
│   ├── modules/
│   │   ├── networking/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── tests/
│   │   │       └── networking_test.go
│   │   ├── jenkins-vm/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── tests/
│   │   │       └── jenkins_vm_test.go
│   │   └── acr/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── tests/
│   │           └── acr_test.go
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── backend.tf
├── tests/
│   ├── unit/
│   │   ├── test_networking.py
│   │   ├── test_vm_config.py
│   │   └── test_acr_config.py
│   ├── integration/
│   │   ├── test_infrastructure.py
│   │   ├── test_github_setup.py
│   │   └── test_end_to_end.py
│   └── fixtures/
│       └── terraform_fixtures.py
├── scripts/
│   ├── setup/
│   │   ├── configure-jenkins-vm.sh
│   │   ├── configure-github-repo.sh
│   │   └── validate-infrastructure.sh
│   ├── tests/
│   │   ├── test-terraform.sh
│   │   ├── test-connectivity.sh
│   │   └── test-acr-access.sh
│   └── utils/
│       ├── generate-ssh-keys.sh
│       └── setup-terraform-backend.sh
├── docs/
│   ├── architecture/
│   │   └── infrastructure-design.md
│   ├── runbooks/
│   │   ├── deployment.md
│   │   └── troubleshooting.md
│   ├── progress/
│   │   ├── sprint-01-progress.md
│   │   └── daily-updates.md
│   └── guides/
│       ├── developer-setup.md
│       └── terraform-guide.md
├── .gitignore
├── .pre-commit-config.yaml
├── Makefile
├── pytest.ini
├── requirements-dev.txt
└── README.md
```

---

## 🔄 Story Implementation Process

### STORY-001-01: Azure Resource Group and Networking

#### Step 1: Write Tests First
```python
# tests/unit/test_networking.py
import pytest
import json
import subprocess

class TestAzureNetworking:
    def test_resource_group_exists(self):
        """Test that resource group is created with correct naming"""
        result = subprocess.run([
            "terraform", "plan", 
            "-var-file=environments/dev.tfvars",
            "-json"
        ], capture_output=True, text=True)
        plan = json.loads(result.stdout)
        
        # Assert resource group will be created
        assert any(
            r["address"] == "azurerm_resource_group.main" 
            for r in plan.get("planned_values", {}).get("root_module", {}).get("resources", [])
        )
    
    def test_virtual_network_configuration(self):
        """Test VNet has correct address space"""
        # Test implementation
        pass
    
    def test_subnet_configuration(self):
        """Test subnets are correctly configured"""
        # Assert Jenkins subnet: 10.0.1.0/24
        # Assert Container subnet: 10.0.2.0/24
        pass
    
    def test_nsg_rules(self):
        """Test NSG has required security rules"""
        # Assert SSH, HTTPS, Jenkins ports
        pass
    
    def test_resource_tags(self):
        """Test all resources have required tags"""
        # Assert Environment, Owner, CostCenter, ManagedBy tags
        pass

# tests/integration/test_networking_integration.py
import pytest
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.resource import ResourceManagementClient

class TestNetworkingIntegration:
    @pytest.fixture
    def resource_client(self):
        # Setup Azure client
        pass
    
    def test_deployed_resource_group(self, resource_client):
        """Test actual deployed resource group"""
        rg = resource_client.resource_groups.get("rg-secdevops-cicd-dev")
        assert rg.location == "uksouth"
        assert rg.tags["Environment"] == "dev"
    
    def test_network_connectivity(self):
        """Test network connectivity between subnets"""
        pass
    
    def test_nsg_effectiveness(self):
        """Test NSG rules are actually blocking/allowing traffic"""
        pass
```

#### Step 2: Write Terraform Code
```hcl
# terraform/modules/networking/main.tf
# [Implement based on tests - see SPRINT-01-STORIES.md for full code]
```

#### Step 3: Create Test Runner
```bash
#!/bin/bash
# scripts/tests/test-terraform.sh

set -e

echo "🧪 Running Terraform Tests for Story 001-01..."

# Unit Tests - Terraform validation
echo "→ Running Terraform validation..."
cd terraform
terraform init -backend=false
terraform validate

# Terraform plan tests
echo "→ Running Terraform plan tests..."
terraform plan -var-file=environments/dev.tfvars -out=plan.tfplan

# Python unit tests
echo "→ Running Python unit tests..."
cd ..
pytest tests/unit/test_networking.py -v --tb=short

# Terratest (Go tests)
echo "→ Running Terratest..."
cd terraform/modules/networking/tests
go test -v -timeout 30m

echo "✅ All tests passed for Story 001-01"
```

#### Step 4: Documentation Update
```markdown
# docs/progress/sprint-01-progress.md

## Sprint 1 Progress Tracker

### STORY-001-01: Azure Resource Group and Networking
- **Status:** 🟡 In Progress
- **Started:** 2025-09-20 10:00
- **Developer:** [Your Name]

#### Test Status:
- [x] Unit tests written
- [x] Integration tests written
- [ ] Tests passing
- [ ] Code implemented
- [ ] Code reviewed
- [ ] Documentation updated

#### Implementation Notes:
- Using Terraform 1.5.x
- Azure Provider 3.x
- Network design follows hub-spoke pattern

#### Blockers:
- None

#### Commits:
- `feat(infra): add networking module tests` - abc123
- `feat(infra): implement networking module` - def456

---
```

---

## 🛠️ Required Tools Setup

### Install Prerequisites
```bash
# Install required tools
brew install terraform terragrunt tflint
brew install azure-cli
brew install python@3.11
brew install go
brew install pre-commit
brew install gh

# Python dependencies
pip install -r requirements-dev.txt

# Pre-commit hooks
pre-commit install
```

### requirements-dev.txt
```txt
pytest==7.4.0
pytest-cov==4.1.0
pytest-mock==3.11.1
pytest-terraform==0.6.0
azure-mgmt-network==23.0.0
azure-mgmt-resource==23.0.0
azure-identity==1.14.0
black==23.7.0
flake8==6.0.0
pylint==2.17.4
```

---

## 📝 Documentation Requirements

### For EACH story completion, update:

1. **Progress Tracker** (`docs/progress/sprint-01-progress.md`)
   - Story status (Not Started → In Progress → Testing → Complete)
   - Test results
   - Blockers encountered
   - Time spent

2. **Technical Docs** (`docs/architecture/`)
   - Architecture decisions
   - Configuration details
   - Security considerations

3. **Runbooks** (`docs/runbooks/`)
   - Deployment steps
   - Validation procedures
   - Rollback procedures

4. **Daily Updates** (`docs/progress/daily-updates.md`)
   ```markdown
   ## 2025-09-20
   - Started STORY-001-01
   - Completed networking tests
   - Blocked on: Azure permissions (resolved)
   - Tomorrow: Complete networking implementation
   ```

---

## 🎯 Success Criteria

### Story Completion Checklist
For each story to be considered DONE:

- [ ] All tests written FIRST (TDD)
- [ ] All tests passing (unit + integration)
- [ ] Code coverage > 80%
- [ ] Security scan passed
- [ ] Documentation updated
- [ ] Code reviewed (PR approved)
- [ ] Deployed to dev environment
- [ ] Validation script successful
- [ ] Progress tracker updated
- [ ] No technical debt introduced

---

## 🚀 Implementation Commands

### Makefile for Common Tasks
```makefile
# Makefile

.PHONY: test test-unit test-integration deploy validate clean

# Run all tests
test: test-unit test-integration

# Run unit tests only
test-unit:
	pytest tests/unit -v --cov=terraform --cov-report=html

# Run integration tests
test-integration:
	pytest tests/integration -v

# Terraform commands
init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan -var-file=environments/dev.tfvars -out=plan.tfplan

apply:
	cd terraform && terraform apply plan.tfplan

# Deploy infrastructure
deploy: init plan apply
	./scripts/setup/validate-infrastructure.sh

# Validate deployment
validate:
	./scripts/tests/test-connectivity.sh
	./scripts/tests/test-acr-access.sh

# Clean up
clean:
	cd terraform && terraform destroy -var-file=environments/dev.tfvars -auto-approve
	rm -rf terraform/.terraform
	rm -f terraform/plan.tfplan

# Documentation
docs-serve:
	cd docs && python -m http.server 8000

# Pre-commit
pre-commit:
	pre-commit run --all-files
```

---

## 🔄 Git Workflow

### Branch Strategy
```bash
# Create feature branch for each story
git checkout -b feature/STORY-001-01-networking

# Commit with TDD cycle markers
git commit -m "test(STORY-001-01): add networking unit tests"
git commit -m "feat(STORY-001-01): implement networking module"
git commit -m "refactor(STORY-001-01): optimize NSG rules"
git commit -m "docs(STORY-001-01): update deployment guide"

# Push and create PR
git push origin feature/STORY-001-01-networking
gh pr create --title "STORY-001-01: Azure Networking Setup" \
  --body "Implements networking infrastructure with full test coverage"
```

---

## 📊 Progress Reporting

### Daily Standup Template
```markdown
## Daily Update - [Date]

**Yesterday:**
- Completed tests for STORY-001-01
- Started implementation of networking module

**Today:**
- Complete networking implementation
- Start STORY-001-02 tests

**Blockers:**
- None / [Describe blocker]

**Story Status:**
- STORY-001-01: 75% complete (tests done, implementation in progress)
- STORY-001-02: Not started
```

---

## 🚨 Important Rules

1. **NEVER skip tests** - Write tests FIRST, always
2. **NEVER commit without tests** - Every commit must have passing tests
3. **NEVER merge without review** - All PRs need approval
4. **ALWAYS update documentation** - Docs are part of Definition of Done
5. **ALWAYS run security scans** - Before pushing code
6. **ALWAYS validate in dev** - Before marking story complete

---

## 🎮 Start Implementation

### Your First Commands:
```bash
# 1. Setup project structure
mkdir -p SecDevOps_CICD/{terraform,tests,scripts,docs}
cd SecDevOps_CICD

# 2. Initialize git
git init
git checkout -b feature/STORY-001-01-networking

# 3. Create first test file
touch tests/unit/test_networking.py

# 4. Start TDD cycle
pytest tests/unit/test_networking.py  # Should fail (RED)

# 5. Begin implementation...
```

---

## 📞 Support & Escalation

- **Blockers:** Update `docs/progress/sprint-01-progress.md` immediately
- **Questions:** Document in story notes for review
- **Security Issues:** Flag immediately, don't attempt fixes alone
- **Failed Tests:** Don't skip - fix the implementation

---

**YOU ARE NOW READY TO START SPRINT 1 IMPLEMENTATION**

Follow TDD strictly. Update documentation continuously. Deliver working, tested infrastructure.

Good luck! 🚀