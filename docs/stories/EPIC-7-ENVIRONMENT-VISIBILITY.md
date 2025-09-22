# Epic 7: Environment Visibility
## Components: 1100-1199

**Epic Number:** 7  
**Epic Title:** Environment Identification & Visibility  
**Priority:** HIGH  
**Status:** PLANNED  

---

## Epic Description

Implement clear environment identification mechanisms to ensure users and administrators can immediately identify which environment (dev, test, staging, prod) they are working in. This includes browser-visible headers, visual indicators, and environment-specific configurations.

---

## Business Value

- **Safety:** Prevent accidental production changes
- **Clarity:** Immediate environment identification
- **Compliance:** Clear audit trail of environment access
- **Training:** Helps new team members understand environment structure
- **Security:** Reduces risk of cross-environment mistakes

---

## Acceptance Criteria

1. Environment header visible in all browser requests (1101)
2. WAF adds environment-specific headers (1102)
3. Application displays environment banner (1103)
4. Browser developer tools show environment headers (1104)
5. Environment-specific color coding in UI (1105)
6. Environment name in page title
7. API responses include environment header
8. Health check endpoints report environment

---

## Stories

### Story 7.1: Implement Environment Headers
**Points:** 3  
**Description:** Configure WAF/Application Gateway to inject environment headers (1101)

### Story 7.2: Application Environment Banner
**Points:** 2  
**Description:** Add visual banner showing current environment (1103)

### Story 7.3: Browser Developer Tools Headers
**Points:** 2  
**Description:** Ensure headers visible in browser dev tools (1104)

### Story 7.4: Environment-Specific Styling
**Points:** 3  
**Description:** Implement color-coded UI based on environment (1105)

### Story 7.5: API Environment Headers
**Points:** 2  
**Description:** Add environment headers to all API responses

### Story 7.6: Health Check Environment Info
**Points:** 1  
**Description:** Include environment details in health endpoints

---

## Dependencies

- WAF/Application Gateway deployed
- Application deployment pipeline
- Environment configuration management
- CSS/UI framework in place

---

## Technical Requirements

### WAF/Application Gateway Headers (Component 1101)
```yaml
Headers to inject:
- X-Environment: [dev|test|staging|prod]
- X-Environment-Color: [green|yellow|orange|red]
- X-Environment-Region: [region-name]
- X-Deployment-Version: [version-number]
- X-Deployment-Date: [timestamp]
```

### Environment Banner Configuration (Component 1103)
```yaml
Banner settings:
  dev:
    color: green
    text: "DEVELOPMENT ENVIRONMENT"
    position: top
  test:
    color: yellow
    text: "TEST ENVIRONMENT"
    position: top
  staging:
    color: orange
    text: "STAGING ENVIRONMENT"
    position: top
  prod:
    color: red
    text: "PRODUCTION"
    position: hidden (unless debug mode)
```

### Browser Headers Display (Component 1104)
```yaml
Response headers visible in:
- Chrome DevTools Network tab
- Firefox Developer Tools
- Edge Developer Tools
- Safari Web Inspector
```

### Environment-Specific Styling (Component 1105)
```css
/* Example CSS classes */
.env-dev { border-top: 5px solid green; }
.env-test { border-top: 5px solid yellow; }
.env-staging { border-top: 5px solid orange; }
.env-prod { border-top: 5px solid red; }
```

### Implementation Approaches

#### Option 1: WAF/Application Gateway Rules
- Configure rewrite rules in WAF policy
- Add custom headers at gateway level
- Works for all applications behind gateway

#### Option 2: Environment Configuration
- Application reads environment variable
- Injects headers in middleware
- More flexible but requires app changes

#### Option 3: Combined Approach
- WAF adds security headers
- Application adds UI elements
- Best of both worlds

### Security Considerations
- Don't expose sensitive information in headers
- Production headers should be minimal
- Use CSP headers to prevent header injection attacks
- Validate environment variables server-side

---

## Definition of Done

- [ ] Headers visible in browser developer tools
- [ ] Environment banner displays correctly
- [ ] Color coding matches environment
- [ ] Headers present in API responses
- [ ] Health checks report environment
- [ ] Documentation updated
- [ ] Team trained on new indicators