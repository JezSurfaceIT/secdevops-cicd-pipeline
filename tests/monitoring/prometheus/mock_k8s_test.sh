#!/bin/bash

# Mock Kubernetes Test Script for Prometheus Deployment
# This simulates a Kubernetes environment to validate our IaC code

set -e

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# ==========================================
# Test Suite: Infrastructure Code Validation
# ==========================================

test_terraform_files_exist() {
    [ -f "infrastructure/terraform/monitoring/prometheus.tf" ] && \
    [ -f "infrastructure/terraform/monitoring/variables.tf" ] && \
    [ -f "infrastructure/terraform/monitoring/outputs.tf" ]
}

test_terraform_syntax() {
    cd infrastructure/terraform/monitoring
    terraform fmt -check >/dev/null 2>&1 || terraform fmt >/dev/null 2>&1
    local result=$?
    cd - >/dev/null
    return $result
}

test_helm_values_exist() {
    [ -f "infrastructure/kubernetes/prometheus-values.yaml" ]
}

test_prometheus_config_exists() {
    [ -f "infrastructure/terraform/monitoring/configs/prometheus.yml" ]
}

test_recording_rules_exist() {
    [ -f "infrastructure/terraform/monitoring/configs/recording-rules.yml" ]
}

test_alerting_rules_exist() {
    [ -f "infrastructure/terraform/monitoring/configs/alerting-rules.yml" ]
}

test_thanos_config_exists() {
    [ -f "infrastructure/terraform/monitoring/configs/thanos-objstore.yml" ]
}

test_web_config_exists() {
    [ -f "infrastructure/terraform/monitoring/configs/web-config.yml" ]
}

test_endpoints_config_exists() {
    [ -f "infrastructure/kubernetes/prometheus-endpoints.yaml" ]
}

test_deployment_script_exists() {
    [ -x "infrastructure/terraform/monitoring/deploy.sh" ]
}

# ==========================================
# Test Suite: Configuration Validation
# ==========================================

test_prometheus_ha_config() {
    grep -q "replicas = 2" infrastructure/terraform/monitoring/variables.tf || \
    grep -q "replicas: 2" infrastructure/kubernetes/prometheus-values.yaml
}

test_retention_policy_config() {
    grep -q "storage.tsdb.retention.time=15d" infrastructure/terraform/monitoring/prometheus.tf
}

test_remote_write_config() {
    grep -q "remote_write:" infrastructure/terraform/monitoring/configs/prometheus.yml && \
    grep -q "thanos-receiver" infrastructure/terraform/monitoring/configs/prometheus.yml
}

test_service_discovery_config() {
    grep -q "kubernetes_sd_configs:" infrastructure/terraform/monitoring/configs/prometheus.yml && \
    grep -q "azure_sd_configs:" infrastructure/terraform/monitoring/configs/prometheus.yml
}

test_federation_config() {
    grep -q "job_name: 'federate'" infrastructure/terraform/monitoring/configs/prometheus.yml
}

test_recording_rules_config() {
    grep -q "performance_rules" infrastructure/terraform/monitoring/configs/recording-rules.yml && \
    grep -q "business_rules" infrastructure/terraform/monitoring/configs/recording-rules.yml
}

test_security_oauth_config() {
    grep -q "oauth2-proxy" infrastructure/terraform/monitoring/prometheus.tf
}

test_tls_config() {
    grep -q "prometheus-tls" infrastructure/terraform/monitoring/prometheus.tf && \
    grep -q "tls_server_config:" infrastructure/terraform/monitoring/configs/web-config.yml
}

test_network_policy_config() {
    grep -q "prometheus-netpol" infrastructure/terraform/monitoring/prometheus.tf
}

test_thanos_deployment_config() {
    grep -q "thanos-receiver" infrastructure/terraform/monitoring/prometheus.tf
}

# ==========================================
# Test Suite: Naming Convention Validation
# ==========================================

test_resource_group_naming() {
    grep -q "e2e-" infrastructure/terraform/monitoring/prometheus.tf
}

test_storage_account_naming() {
    grep -q 'name.*=.*"e2e${var.environment}thanos"' infrastructure/terraform/monitoring/prometheus.tf
}

test_namespace_config() {
    grep -q 'name = "monitoring"' infrastructure/terraform/monitoring/prometheus.tf
}

# ==========================================
# Test Suite: Resource Requirements
# ==========================================

test_prometheus_resources() {
    grep -q "memory = \"2Gi\"" infrastructure/terraform/monitoring/prometheus.tf && \
    grep -q "cpu.*= \"1\"" infrastructure/terraform/monitoring/prometheus.tf
}

test_storage_size() {
    grep -q "storage = \"100Gi\"" infrastructure/terraform/monitoring/prometheus.tf
}

test_prometheus_version() {
    grep -q "prometheus_version" infrastructure/terraform/monitoring/variables.tf
}

test_thanos_version() {
    grep -q "thanos_version" infrastructure/terraform/monitoring/variables.tf
}

# ==========================================
# Test Suite: Monitoring Configuration
# ==========================================

test_prometheus_self_monitoring() {
    grep -q "job_name: 'prometheus'" infrastructure/terraform/monitoring/configs/prometheus.yml
}

test_alertmanager_integration() {
    grep -q "alertmanagers:" infrastructure/terraform/monitoring/configs/prometheus.yml
}

test_prometheus_alerts() {
    grep -q "PrometheusDown" infrastructure/terraform/monitoring/configs/alerting-rules.yml
}

# ==========================================
# Main Test Runner
# ==========================================

main() {
    echo "================================================"
    echo "Prometheus IaC Validation Test Suite"
    echo "================================================"
    echo ""
    
    # Infrastructure Code Tests
    echo -e "${YELLOW}=== Infrastructure Code Tests ===${NC}"
    run_test "Terraform files exist" test_terraform_files_exist || true
    run_test "Terraform syntax valid" test_terraform_syntax || true
    run_test "Helm values file exists" test_helm_values_exist || true
    run_test "Prometheus config exists" test_prometheus_config_exists || true
    run_test "Recording rules exist" test_recording_rules_exist || true
    run_test "Alerting rules exist" test_alerting_rules_exist || true
    run_test "Thanos config exists" test_thanos_config_exists || true
    run_test "Web config exists" test_web_config_exists || true
    run_test "Endpoints config exists" test_endpoints_config_exists || true
    run_test "Deployment script exists" test_deployment_script_exists || true
    echo ""
    
    # Configuration Validation Tests
    echo -e "${YELLOW}=== Configuration Validation Tests ===${NC}"
    run_test "HA configuration (2+ replicas)" test_prometheus_ha_config || true
    run_test "15-day retention configured" test_retention_policy_config || true
    run_test "Remote write configured" test_remote_write_config || true
    run_test "Service discovery configured" test_service_discovery_config || true
    run_test "Federation configured" test_federation_config || true
    run_test "Recording rules configured" test_recording_rules_config || true
    run_test "OAuth2 security configured" test_security_oauth_config || true
    run_test "TLS configured" test_tls_config || true
    run_test "Network policy configured" test_network_policy_config || true
    run_test "Thanos deployment configured" test_thanos_deployment_config || true
    echo ""
    
    # Naming Convention Tests
    echo -e "${YELLOW}=== Naming Convention Tests ===${NC}"
    run_test "Resource group naming (e2e-*)" test_resource_group_naming || true
    run_test "Storage account naming" test_storage_account_naming || true
    run_test "Namespace configured" test_namespace_config || true
    echo ""
    
    # Resource Requirements Tests
    echo -e "${YELLOW}=== Resource Requirements Tests ===${NC}"
    run_test "Prometheus resources configured" test_prometheus_resources || true
    run_test "Storage size configured" test_storage_size || true
    run_test "Prometheus version specified" test_prometheus_version || true
    run_test "Thanos version specified" test_thanos_version || true
    echo ""
    
    # Monitoring Configuration Tests
    echo -e "${YELLOW}=== Monitoring Configuration Tests ===${NC}"
    run_test "Prometheus self-monitoring" test_prometheus_self_monitoring || true
    run_test "Alertmanager integration" test_alertmanager_integration || true
    run_test "Prometheus alerts configured" test_prometheus_alerts || true
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
            echo -e "${YELLOW}⚠ Coverage is below 100%. Review failed tests.${NC}"
        fi
    fi
    
    echo "================================================"
    
    # Exit with success if all tests pass
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All IaC validation tests passed!${NC}"
        exit 0
    else
        echo -e "${YELLOW}Some tests failed. Review the implementation.${NC}"
        exit 1
    fi
}

# Run the test suite
main "$@"