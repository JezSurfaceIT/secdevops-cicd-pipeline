<!-- Powered by BMAD™ Core -->

# TDD & IaC Compliance Checklist

## Purpose
Ensure all stories and epics enforce Test-Driven Development (TDD) and Infrastructure as Code (IaC) principles with zero tolerance for direct environment modifications.

## CRITICAL MANDATES

### Test-Driven Development (TDD) Requirements
**ALL code development MUST follow this sequence:**

- [ ] **Test First:** Write failing test BEFORE any implementation code
- [ ] **Red Phase:** Verify test fails with expected error
- [ ] **Green Phase:** Write MINIMAL code to make test pass
- [ ] **Refactor Phase:** Improve code while keeping tests green
- [ ] **Coverage:** 100% code coverage achieved - NO EXCEPTIONS
- [ ] **No Skipping:** NEVER write implementation before tests

### Infrastructure as Code (IaC) Requirements
**ALL infrastructure changes MUST follow these rules:**

- [ ] **IaC Only:** ALL Azure resources created/modified via Terraform/ARM/Bicep
- [ ] **No Portal Changes:** Azure Portal used for READ-ONLY viewing
- [ ] **No CLI Direct Changes:** Azure CLI used ONLY to run IaC deployments
- [ ] **Fix Forward:** If issue in Azure, fix the IaC code and redeploy
- [ ] **Version Control:** All IaC code in git with proper versioning
- [ ] **Plan Before Apply:** Always run terraform plan/what-if before deployment

### Resource Group Naming Convention
**MANDATORY hierarchical naming structure:**

- [ ] **Format Applied:** e2e-{environment}-{region}-{project}-{component}-{instance}
- [ ] **Environment:** dev, test, staging, or prod used correctly
- [ ] **Region:** Standard abbreviation (eus, wus, neu, weu, etc.)
- [ ] **Project:** Abbreviated name (max 10 characters)
- [ ] **Component:** app, data, network, security, shared, or monitoring
- [ ] **Instance:** 001, 002, 003 for multiple instances
- [ ] **Child Resources:** Follow similar hierarchical pattern
- [ ] **Consistency:** Naming consistent across all environments

## Story Compliance Checklist

### Pre-Development Phase
- [ ] Story explicitly states TDD requirement in tasks
- [ ] Story explicitly states IaC-only requirement for infrastructure
- [ ] Test files/locations identified in story
- [ ] IaC modules/files identified if infrastructure changes needed
- [ ] Developer acknowledges TDD/IaC requirements

### Development Phase
- [ ] Each feature has corresponding test file created FIRST
- [ ] Tests written and failing before implementation starts
- [ ] Implementation code written to satisfy tests only
- [ ] Infrastructure changes made in IaC files only
- [ ] No Azure Portal modifications performed
- [ ] IaC plan reviewed before apply

### Validation Phase
- [ ] Test coverage report shows 100% coverage
- [ ] All tests passing
- [ ] Git history shows test commits before implementation
- [ ] IaC code reviewed for best practices
- [ ] Infrastructure state managed by IaC only
- [ ] No manual Azure resource modifications detected

## Epic Compliance Checklist

### Epic Planning
- [ ] Epic description includes TDD mandate
- [ ] Epic description includes IaC-first mandate
- [ ] All child stories inherit TDD/IaC requirements
- [ ] Definition of Done includes TDD/IaC validation

### Epic Execution
- [ ] Each story follows TDD approach verified
- [ ] All infrastructure changes via IaC verified
- [ ] No direct environment modifications occurred
- [ ] Test suite comprehensive and passing
- [ ] IaC deployments successful and tracked

## Enforcement & Consequences

### Violations Result In:
1. **Code Rejection:** Non-TDD code must be rewritten
2. **Infrastructure Rollback:** Direct Azure changes must be reverted
3. **Story Incomplete:** Story cannot be marked done until compliant
4. **Process Review:** Team discussion on why violation occurred

### Success Indicators:
1. **Git History:** Shows tests before implementation consistently
2. **Coverage Reports:** Consistently above 100%
3. **IaC State:** All infrastructure tracked in state files
4. **Azure Audit:** Shows no manual modifications
5. **Team Velocity:** Improves as TDD/IaC becomes habit

## Common Pitfalls to Avoid

### TDD Pitfalls:
- [ ] Writing tests after code "to save time" (always slower)
- [ ] Writing implementation "to understand problem" first
- [ ] Skipping tests for "simple" functions
- [ ] Not running tests before writing code
- [ ] Writing too much code to pass one test

### IaC Pitfalls:
- [ ] "Quick fix" in Azure Portal (never quick, always problematic)
- [ ] Testing in Azure then updating IaC (causes drift)
- [ ] Not using variables/modules (causes duplication)
- [ ] Skipping plan phase (causes surprises)
- [ ] Not tracking state properly (causes conflicts)

## Validation Commands

### TDD Validation:
```bash
# Check test coverage
npm test -- --coverage
pytest --cov=. --cov-report=html

# Verify test-first in git
git log --oneline | grep -E "(test|spec)" 

# Run test suite
npm test
pytest
```

### IaC Validation:
```bash
# Terraform validation
terraform fmt -check
terraform validate
terraform plan

# ARM validation
az deployment group validate --resource-group <rg> --template-file <file>

# Bicep validation
az bicep build --file <file>
```

## Scrum Master Responsibilities

As Scrum Master, you MUST:
1. **Enforce:** Never compromise on TDD/IaC requirements
2. **Educate:** Help team understand why these practices matter
3. **Support:** Provide resources and guidance for TDD/IaC
4. **Track:** Monitor compliance across all stories
5. **Report:** Surface violations immediately for correction
6. **Protect:** Shield team from pressure to skip TDD/IaC

## Developer Agreement

By working on this story/epic, I acknowledge:
- [ ] I will write tests BEFORE implementation code
- [ ] I will NEVER modify Azure resources directly
- [ ] I will fix IaC code when Azure issues arise
- [ ] I understand violations will result in rework
- [ ] I commit to TDD and IaC-first practices

---

**Remember:** TDD and IaC are not optional - they are fundamental to our engineering excellence and system reliability.