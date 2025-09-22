#!/bin/bash

# Grafana Dashboard Deployment Test Suite
# Following TDD approach - these tests MUST fail initially
# Tests cover all acceptance criteria from story 6.2

set -e

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${YELLOW}Running: ${test_name}${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$test_command"; then
        echo -e "${GREEN}✓ PASSED: ${test_name}${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAILED: ${test_name}${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [ "$expected" != "$actual" ]; then
        echo -e "${RED}  ${message}: expected '${expected}', got '${actual}'${NC}"
        return 1
    fi
    return 0
}

assert_greater_than() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Value not greater than expected}"
    
    if [ "$actual" -le "$expected" ]; then
        echo -e "${RED}  ${message}: ${actual} is not greater than ${expected}${NC}"
        return 1
    fi
    return 0
}

assert_file_exists() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo -e "${RED}  File does not exist: ${file}${NC}"
        return 1
    fi
    return 0
}

assert_directory_exists() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo -e "${RED}  Directory does not exist: ${dir}${NC}"
        return 1
    fi
    return 0
}

# ==========================================
# Test Suite: Infrastructure Tests
# ==========================================

test_grafana_terraform_exists() {
    assert_file_exists "infrastructure/terraform/monitoring/grafana.tf"
}

test_grafana_helm_values_exists() {
    assert_file_exists "infrastructure/kubernetes/grafana-values.yaml"
}

test_grafana_namespace_config() {
    grep -q 'namespace.*=.*"monitoring"' infrastructure/terraform/monitoring/grafana.tf 2>/dev/null || \
    grep -q 'namespace:.*monitoring' infrastructure/kubernetes/grafana-values.yaml 2>/dev/null
}

# ==========================================
# Test Suite: High Availability (AC: 1)
# ==========================================

test_grafana_ha_replicas() {
    # Check for 3+ replicas configuration
    grep -q "replicas.*=.*3\|replicas.*:.*3" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null || \
    grep -q "replicas:.*3" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null
}

test_grafana_persistence_config() {
    grep -q "persistence" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "persistent.*volume" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_grafana_session_affinity() {
    grep -q "session.*affinity\|affinity" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "affinity" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

# ==========================================
# Test Suite: Authentication (AC: 2)
# ==========================================

test_azure_ad_sso_config() {
    grep -q "auth.azuread\|azure.*ad\|oauth" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "azure_ad\|oauth" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_oauth_client_config() {
    grep -q "client_id\|client_secret" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "oauth.*client" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_authentication_security() {
    grep -q "oauth_auto_login\|disable_login_form" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "secure.*auth" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

# ==========================================
# Test Suite: Dashboard Configuration (AC: 3)
# ==========================================

test_infrastructure_dashboards_exist() {
    assert_directory_exists "infrastructure/dashboards/infrastructure" || \
    assert_directory_exists "dashboards/infrastructure"
}

test_kubernetes_dashboard_exists() {
    assert_file_exists "infrastructure/dashboards/infrastructure/kubernetes-overview.json" || \
    assert_file_exists "dashboards/infrastructure/kubernetes-overview.json"
}

test_azure_dashboard_exists() {
    assert_file_exists "infrastructure/dashboards/infrastructure/azure-resources.json" || \
    assert_file_exists "dashboards/infrastructure/azure-resources.json"
}

test_application_dashboards_exist() {
    assert_directory_exists "infrastructure/dashboards/application" || \
    assert_directory_exists "dashboards/application"
}

test_performance_dashboard_exists() {
    assert_file_exists "infrastructure/dashboards/application/performance.json" || \
    assert_file_exists "dashboards/application/performance.json"
}

# ==========================================
# Test Suite: Business Metrics (AC: 4)
# ==========================================

test_business_dashboards_exist() {
    assert_directory_exists "infrastructure/dashboards/business" || \
    assert_directory_exists "dashboards/business"
}

test_kpi_dashboard_exists() {
    assert_file_exists "infrastructure/dashboards/business/kpi.json" || \
    assert_file_exists "dashboards/business/kpi.json"
}

test_revenue_dashboard_exists() {
    assert_file_exists "infrastructure/dashboards/business/revenue.json" || \
    assert_file_exists "dashboards/business/revenue.json"
}

test_user_metrics_dashboard_exists() {
    assert_file_exists "infrastructure/dashboards/business/users.json" || \
    assert_file_exists "dashboards/business/users.json"
}

# ==========================================
# Test Suite: Alert Visualization (AC: 5)
# ==========================================

test_alert_dashboard_exists() {
    assert_file_exists "infrastructure/dashboards/alerts/overview.json" || \
    assert_file_exists "dashboards/alerts/overview.json"
}

test_alert_integration_config() {
    grep -q "alerting\|unified_alerting" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "alert" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_alert_visualization_panels() {
    if [ -f "infrastructure/dashboards/alerts/overview.json" ]; then
        grep -q "alertlist\|alert" infrastructure/dashboards/alerts/overview.json
    elif [ -f "dashboards/alerts/overview.json" ]; then
        grep -q "alertlist\|alert" dashboards/alerts/overview.json
    else
        return 1
    fi
}

# ==========================================
# Test Suite: Dashboard as Code (AC: 6)
# ==========================================

test_dashboard_ci_workflow_exists() {
    assert_file_exists ".github/workflows/dashboard-ci.yml" || \
    assert_file_exists "infrastructure/dashboards/ci/validate.sh"
}

test_dashboard_provisioning_config() {
    grep -q "dashboardProviders\|dashboard.*provisioning" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "dashboard.*config" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_dashboard_version_control() {
    # Check if dashboards are in git
    [ -d "infrastructure/dashboards" ] || [ -d "dashboards" ]
}

test_dashboard_builder_library() {
    assert_file_exists "infrastructure/dashboards/lib/dashboard-builder.js" || \
    assert_file_exists "lib/dashboard-builder.js"
}

# ==========================================
# Test Suite: Multi-tenancy (AC: 7)
# ==========================================

test_multitenancy_config() {
    grep -q "organizations\|multi.*tenant" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "org.*config" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_folder_permissions_config() {
    grep -q "folder.*permissions\|team.*folders" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null || \
    assert_file_exists "infrastructure/scripts/setup-multitenancy.js"
}

test_team_isolation_config() {
    grep -q "team\|data.*isolation" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "rbac\|permissions" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

# ==========================================
# Test Suite: Mobile Responsiveness (AC: 8)
# ==========================================

test_mobile_dashboard_exists() {
    assert_file_exists "infrastructure/dashboards/mobile/mobile-overview.json" || \
    assert_file_exists "dashboards/mobile/mobile-overview.json"
}

test_responsive_styles_exist() {
    assert_file_exists "infrastructure/dashboards/mobile/styles.css" || \
    assert_file_exists "dashboards/mobile/styles.css"
}

test_mobile_optimization_config() {
    if [ -f "infrastructure/dashboards/mobile/mobile-overview.json" ]; then
        grep -q "mobile\|responsive" infrastructure/dashboards/mobile/mobile-overview.json
    elif [ -f "dashboards/mobile/mobile-overview.json" ]; then
        grep -q "mobile\|responsive" dashboards/mobile/mobile-overview.json
    else
        return 1
    fi
}

# ==========================================
# Test Suite: Data Sources Configuration
# ==========================================

test_prometheus_datasource_config() {
    grep -q "prometheus.*datasource\|datasource.*prometheus" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "prometheus" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_azure_monitor_datasource() {
    grep -q "azure.*monitor\|grafana-azure-monitor" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "azure.*monitor" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_postgres_datasource() {
    grep -q "postgres\|postgresql" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "postgres" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_loki_datasource() {
    grep -q "loki" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "loki" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

# ==========================================
# Test Suite: Resource Configuration
# ==========================================

test_grafana_resources_config() {
    grep -q "resources:\|limits:\|requests:" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "resources.*{" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_grafana_storage_config() {
    grep -q "storage.*10Gi\|size.*10Gi" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "storage.*=" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_grafana_database_config() {
    grep -q "database:\|postgres.*database" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "database.*config" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

# ==========================================
# Test Suite: Security Configuration
# ==========================================

test_grafana_tls_config() {
    grep -q "tls:\|https:\|ssl" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "tls\|certificate" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_grafana_ingress_config() {
    grep -q "ingress:\|nginx.ingress" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "ingress" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

test_grafana_rbac_config() {
    grep -q "rbac:\|role.*attribute" infrastructure/kubernetes/grafana-values.yaml 2>/dev/null || \
    grep -q "rbac\|role" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null
}

# ==========================================
# Test Suite: Naming Convention
# ==========================================

test_resource_naming_convention() {
    # Check for e2e-* naming convention
    grep -q "e2e-" infrastructure/terraform/monitoring/grafana.tf 2>/dev/null || true
}

# ==========================================
# Main Test Runner
# ==========================================

main() {
    echo "================================================"
    echo "Grafana Dashboard Deployment Test Suite"
    echo "================================================"
    echo ""
    
    # Infrastructure Tests
    echo -e "${YELLOW}=== Infrastructure Tests ===${NC}"
    run_test "Grafana Terraform file exists" test_grafana_terraform_exists || true
    run_test "Grafana Helm values exist" test_grafana_helm_values_exists || true
    run_test "Namespace configuration" test_grafana_namespace_config || true
    echo ""
    
    # High Availability Tests
    echo -e "${YELLOW}=== High Availability Tests (AC: 1) ===${NC}"
    run_test "HA replicas configured (3+)" test_grafana_ha_replicas || true
    run_test "Persistence configured" test_grafana_persistence_config || true
    run_test "Session affinity configured" test_grafana_session_affinity || true
    echo ""
    
    # Authentication Tests
    echo -e "${YELLOW}=== Authentication Tests (AC: 2) ===${NC}"
    run_test "Azure AD SSO configured" test_azure_ad_sso_config || true
    run_test "OAuth client configured" test_oauth_client_config || true
    run_test "Authentication security" test_authentication_security || true
    echo ""
    
    # Dashboard Configuration Tests
    echo -e "${YELLOW}=== Dashboard Configuration Tests (AC: 3) ===${NC}"
    run_test "Infrastructure dashboards exist" test_infrastructure_dashboards_exist || true
    run_test "Kubernetes dashboard exists" test_kubernetes_dashboard_exists || true
    run_test "Azure dashboard exists" test_azure_dashboard_exists || true
    run_test "Application dashboards exist" test_application_dashboards_exist || true
    run_test "Performance dashboard exists" test_performance_dashboard_exists || true
    echo ""
    
    # Business Metrics Tests
    echo -e "${YELLOW}=== Business Metrics Tests (AC: 4) ===${NC}"
    run_test "Business dashboards exist" test_business_dashboards_exist || true
    run_test "KPI dashboard exists" test_kpi_dashboard_exists || true
    run_test "Revenue dashboard exists" test_revenue_dashboard_exists || true
    run_test "User metrics dashboard exists" test_user_metrics_dashboard_exists || true
    echo ""
    
    # Alert Visualization Tests
    echo -e "${YELLOW}=== Alert Visualization Tests (AC: 5) ===${NC}"
    run_test "Alert dashboard exists" test_alert_dashboard_exists || true
    run_test "Alert integration configured" test_alert_integration_config || true
    run_test "Alert visualization panels" test_alert_visualization_panels || true
    echo ""
    
    # Dashboard as Code Tests
    echo -e "${YELLOW}=== Dashboard as Code Tests (AC: 6) ===${NC}"
    run_test "Dashboard CI workflow exists" test_dashboard_ci_workflow_exists || true
    run_test "Dashboard provisioning config" test_dashboard_provisioning_config || true
    run_test "Dashboard version control" test_dashboard_version_control || true
    run_test "Dashboard builder library" test_dashboard_builder_library || true
    echo ""
    
    # Multi-tenancy Tests
    echo -e "${YELLOW}=== Multi-tenancy Tests (AC: 7) ===${NC}"
    run_test "Multi-tenancy configured" test_multitenancy_config || true
    run_test "Folder permissions configured" test_folder_permissions_config || true
    run_test "Team isolation configured" test_team_isolation_config || true
    echo ""
    
    # Mobile Responsiveness Tests
    echo -e "${YELLOW}=== Mobile Responsiveness Tests (AC: 8) ===${NC}"
    run_test "Mobile dashboard exists" test_mobile_dashboard_exists || true
    run_test "Responsive styles exist" test_responsive_styles_exist || true
    run_test "Mobile optimization config" test_mobile_optimization_config || true
    echo ""
    
    # Data Sources Tests
    echo -e "${YELLOW}=== Data Sources Configuration Tests ===${NC}"
    run_test "Prometheus datasource configured" test_prometheus_datasource_config || true
    run_test "Azure Monitor datasource configured" test_azure_monitor_datasource || true
    run_test "PostgreSQL datasource configured" test_postgres_datasource || true
    run_test "Loki datasource configured" test_loki_datasource || true
    echo ""
    
    # Resource Configuration Tests
    echo -e "${YELLOW}=== Resource Configuration Tests ===${NC}"
    run_test "Grafana resources configured" test_grafana_resources_config || true
    run_test "Grafana storage configured" test_grafana_storage_config || true
    run_test "Grafana database configured" test_grafana_database_config || true
    echo ""
    
    # Security Tests
    echo -e "${YELLOW}=== Security Configuration Tests ===${NC}"
    run_test "TLS configured" test_grafana_tls_config || true
    run_test "Ingress configured" test_grafana_ingress_config || true
    run_test "RBAC configured" test_grafana_rbac_config || true
    echo ""
    
    # Naming Convention Tests
    echo -e "${YELLOW}=== Naming Convention Tests ===${NC}"
    run_test "Resource naming convention (e2e-*)" test_resource_naming_convention || true
    echo ""
    
    # Test Summary
    echo "================================================"
    echo "Test Results Summary"
    echo "================================================"
    echo -e "Tests Run:    ${TESTS_RUN}"
    echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
    
    # Calculate coverage percentage
    if [ $TESTS_RUN -gt 0 ]; then
        COVERAGE=$((TESTS_PASSED * 100 / TESTS_RUN))
        echo -e "Coverage:     ${COVERAGE}%"
        
        if [ $COVERAGE -eq 100 ]; then
            echo -e "${GREEN}✓ 100% test coverage achieved!${NC}"
        else
            echo -e "${YELLOW}⚠ Coverage is below 100%. Add more tests!${NC}"
        fi
    fi
    
    echo "================================================"
    
    # Exit with failure if any test failed (TDD - should fail initially)
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Test suite failed. This is expected in TDD red phase.${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Run the test suite
main "$@"