# Epic 5: CBE Package & Distribution
## Components: 900-999, 860-899

**Epic Number:** 5  
**Epic Title:** Customer Deployment Package System  
**Priority:** MEDIUM  
**Status:** PLANNED  

---

## Epic Description

Build complete customer deployment system including package builder, customer portal for distribution, and internal CBE mimic for testing. Integrates with existing customer portal at `/home/jez/code/customer-portal-v2`.

---

## Business Value

- **Customer Enablement:** Self-service deployment packages
- **Quality Assurance:** Test CBE deployments internally
- **Automation:** Automated package generation
- **Support:** Reduced deployment support tickets
- **Flexibility:** Customer-specific configurations

---

## Acceptance Criteria

1. Package builder creates complete CBE packages (901)
2. Customer portal allows secure package download (902)
3. CBE Mimic validates packages internally (860)
4. Packages include all required components (911-914)
5. HashiCorp Vault configured for CBE (871)
6. Apache Guacamole provides browser access (873)
7. Integration with `/home/jez/code/customer-portal-v2`
8. Package versioning and release notes

---

## Stories

### Story 5.1: Implement Package Builder
**Points:** 5  
**Description:** Create automated CBE package builder (901) with versioning

### Story 5.2: Deploy Customer Portal
**Points:** 5  
**Description:** Setup customer portal (902) integrated with existing codebase

### Story 5.3: Setup CBE Mimic Environment
**Points:** 5  
**Description:** Deploy internal CBE test instance (860) for validation

### Story 5.4: Configure CBE HashiCorp Vault
**Points:** 3  
**Description:** Setup Vault (871) for CBE secret management

### Story 5.5: Deploy Apache Guacamole
**Points:** 3  
**Description:** Configure Guacamole (873) for browser-based access

### Story 5.6: Create Package Components
**Points:** 3  
**Description:** Build package components (911-914) with documentation

---

## Dependencies

- Production environment stable (Epic 4)
- Customer portal codebase at `/home/jez/code/customer-portal-v2`
- Package signing certificates
- Customer authentication system

---

## Technical Requirements

### Package Builder (Component 901)
```yaml
Package contents:
- Docker images
- docker-compose.yml
- PostgreSQL migration scripts
- Vault configuration
- Deployment scripts
- Configuration templates
- Documentation
```

### Customer Portal Integration
- Codebase: `/home/jez/code/customer-portal-v2`
- Subnet: 10.80.4.0/24
- Authentication: Azure AD B2C
- Package storage: Azure Blob

### CBE Mimic Configuration (Component 860)
- Subnet: 10.80.1.0/24
- Components:
  - HashiCorp Vault (10.80.2.0/24)
  - PostgreSQL Container (10.80.3.0/24)
  - Apache Guacamole (10.80.5.0/24)
  - NGINX Reverse Proxy

### Package Versioning
```
Format: v{major}.{minor}.{patch}-{build}
Example: v2.1.0-20250922
```

---

## Definition of Done

- [ ] Package builder automated
- [ ] Customer portal functional
- [ ] CBE Mimic validates packages
- [ ] Guacamole access working
- [ ] Documentation complete
- [ ] Customer onboarding guide created