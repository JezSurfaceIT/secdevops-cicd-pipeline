# Epic 1: Secure Access Infrastructure
## Components: 201, 801, 802, 803, 811, 401

**Epic Number:** 1  
**Epic Title:** Secure Access Infrastructure with IP Restrictions  
**Priority:** HIGH  
**Status:** READY  

---

## Epic Description

Establish the secure network foundation with strict IP allowlisting, WAF protection, and routing through Application Gateway to a dummy test application. This epic implements the critical security perimeter that protects all internal resources.

---

## Business Value

- **Security:** Prevents unauthorized access to infrastructure
- **Compliance:** Meets security requirements for restricted access
- **Foundation:** Enables secure deployment of all other components
- **Testing:** Provides immediate validation of secure routing

---

## Acceptance Criteria

1. Only whitelisted IPs can access the infrastructure (GitHub webhooks, Azure DevOps, admin IPs)
2. All traffic must pass through WAF with OWASP rules enabled
3. Application Gateway successfully routes to dummy test app
4. Azure Firewall controls all internal traffic flow
5. No public IPs on internal resources (except App Gateway)
6. Test app responds with "Hello Secure World" when accessed through gateway
7. All infrastructure code has passing tests before deployment
8. Network Security Groups deny all traffic by default

---

## Stories

### Story 1.1: TDD Infrastructure Test Suite Setup
**Points:** 3  
**Description:** Set up Terraform testing framework with Terratest for TDD approach

### Story 1.2: Create Network Foundation with IP Restrictions
**Points:** 5  
**Description:** Implement VNet, subnets, and NSG with strict IP allowlist (Component 801)

### Story 1.3: Deploy WAF and Application Gateway
**Points:** 5  
**Description:** Configure WAF with OWASP rules and Application Gateway (Components 802, 803)

### Story 1.4: Implement Azure Firewall
**Points:** 5  
**Description:** Deploy and configure Azure Firewall for internal traffic control (Component 811)

### Story 1.5: Deploy Dummy Test Application
**Points:** 3  
**Description:** Create and deploy simple container app for testing secure routing (Component 401)

---

## Dependencies

- Azure subscription with appropriate permissions
- GitHub repository configured (Component 201)
- Terraform and Azure CLI installed
- Test framework (Terratest) configured

---

## Technical Requirements

### Network Architecture
```
Internet -> IP Check (801) -> WAF (802) -> App Gateway (803) -> Firewall (811) -> Test App (401)
```

### IP Allowlist (Component 801)
- GitHub Webhooks: 140.82.112.0/20, 143.55.64.0/20
- Azure DevOps: 13.107.6.0/24
- Admin IPs: To be configured
- Default: DENY ALL

### Resource Groups (V8 Standard)
- `rg-oversight-shared-network-eastus` - Network components
- `rg-oversight-test-acs-eastus` - Test application

---

## Test Strategy (TDD)

1. **Infrastructure Tests First**
   - Write tests for network creation
   - Write tests for security rules
   - Write tests for routing

2. **Security Tests**
   - Test IP blocking (non-whitelisted IPs)
   - Test IP allowing (whitelisted IPs)
   - Test WAF rules

3. **Integration Tests**
   - End-to-end routing test
   - Security penetration test
   - Load test through gateway

---

## Definition of Done

- [ ] All Terratest tests passing
- [ ] Infrastructure deployed successfully
- [ ] Security scan shows no vulnerabilities
- [ ] Dummy app accessible only through secure path
- [ ] Documentation updated
- [ ] Code reviewed and merged
- [ ] Monitoring configured