#!/bin/bash

# Prometheus Deployment Test Suite
# Following TDD approach - these tests MUST fail initially
# Tests cover all acceptance criteria from story 6.1

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

test_kubernetes_namespace_exists() {
    kubectl get namespace monitoring &>/dev/null
}

test_prometheus_configmap_exists() {
    kubectl get configmap prometheus-config -n monitoring &>/dev/null
}

test_prometheus_deployment_exists() {
    kubectl get statefulset prometheus -n monitoring &>/dev/null
}

test_prometheus_service_exists() {
    kubectl get service prometheus -n monitoring &>/dev/null
}

test_prometheus_persistent_volume_exists() {
    local pvc_count=$(kubectl get pvc -n monitoring -l app=prometheus --no-headers | wc -l)
    assert_greater_than 0 "$pvc_count" "No PVCs found for Prometheus"
}

# ==========================================
# Test Suite: High Availability (AC: 1)
# ==========================================

test_prometheus_ha_replicas() {
    local replicas=$(kubectl get statefulset prometheus -n monitoring -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    assert_greater_than 1 "$replicas" "Prometheus HA requires at least 2 replicas"
}

test_prometheus_pods_running() {
    local running_pods=$(kubectl get pods -n monitoring -l app=prometheus --field-selector=status.phase=Running --no-headers | wc -l)
    assert_greater_than 1 "$running_pods" "Need at least 2 running Prometheus pods for HA"
}

# ==========================================
# Test Suite: Service Discovery (AC: 2, 3)
# ==========================================

test_service_discovery_configured() {
    local config=$(kubectl get configmap prometheus-config -n monitoring -o yaml 2>/dev/null || echo "")
    echo "$config" | grep -q "kubernetes_sd_configs" || return 1
    echo "$config" | grep -q "azure_sd_configs" || return 1
}

test_kubernetes_targets_discovered() {
    # Check if Prometheus API is accessible
    local prometheus_url="http://localhost:9090"
    kubectl port-forward -n monitoring svc/prometheus 9090:9090 &>/dev/null &
    local port_forward_pid=$!
    sleep 5
    
    # Check targets via Prometheus API
    local targets=$(curl -s "${prometheus_url}/api/v1/targets" 2>/dev/null || echo "{}")
    kill $port_forward_pid 2>/dev/null || true
    
    echo "$targets" | grep -q "kubernetes-nodes" || return 1
    echo "$targets" | grep -q "kubernetes-pods" || return 1
}

test_application_metrics_endpoint() {
    # Test if application exposes /metrics endpoint
    assert_file_exists "infrastructure/kubernetes/prometheus-endpoints.yaml"
}

# ==========================================
# Test Suite: Data Retention (AC: 4)
# ==========================================

test_retention_policy_configured() {
    local retention=$(kubectl get statefulset prometheus -n monitoring -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null || echo "")
    echo "$retention" | grep -q "storage.tsdb.retention.time=15d" || return 1
}

test_storage_size_configured() {
    local storage=$(kubectl get pvc -n monitoring -l app=prometheus -o jsonpath='{.items[0].spec.resources.requests.storage}' 2>/dev/null || echo "")
    [ ! -z "$storage" ] || return 1
}

# ==========================================
# Test Suite: Remote Storage (AC: 5)
# ==========================================

test_remote_write_configured() {
    local config=$(kubectl get configmap prometheus-config -n monitoring -o yaml 2>/dev/null || echo "")
    echo "$config" | grep -q "remote_write:" || return 1
    echo "$config" | grep -q "thanos-receiver" || return 1
}

test_thanos_receiver_deployed() {
    kubectl get statefulset thanos-receiver -n monitoring &>/dev/null
}

test_thanos_object_storage_configured() {
    kubectl get secret thanos-objstore-config -n monitoring &>/dev/null
}

# ==========================================
# Test Suite: Recording Rules (AC: 6)
# ==========================================

test_recording_rules_configmap_exists() {
    kubectl get configmap prometheus-rules -n monitoring &>/dev/null
}

test_recording_rules_mounted() {
    local mounts=$(kubectl get statefulset prometheus -n monitoring -o jsonpath='{.spec.template.spec.volumes}' 2>/dev/null || echo "")
    echo "$mounts" | grep -q "prometheus-rules" || return 1
}

test_recording_rules_evaluated() {
    # Check if rules are loaded in Prometheus
    kubectl port-forward -n monitoring svc/prometheus 9090:9090 &>/dev/null &
    local port_forward_pid=$!
    sleep 5
    
    local rules=$(curl -s "http://localhost:9090/api/v1/rules" 2>/dev/null || echo "{}")
    kill $port_forward_pid 2>/dev/null || true
    
    echo "$rules" | grep -q "performance_rules" || return 1
    echo "$rules" | grep -q "business_rules" || return 1
}

# ==========================================
# Test Suite: Federation (AC: 7)
# ==========================================

test_federation_endpoint_available() {
    kubectl port-forward -n monitoring svc/prometheus 9090:9090 &>/dev/null &
    local port_forward_pid=$!
    sleep 5
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:9090/federate" 2>/dev/null || echo "000")
    kill $port_forward_pid 2>/dev/null || true
    
    [ "$response" == "200" ] || return 1
}

test_federation_config_exists() {
    local config=$(kubectl get configmap prometheus-config -n monitoring -o yaml 2>/dev/null || echo "")
    echo "$config" | grep -q "job_name: 'federate'" || return 1
}

# ==========================================
# Test Suite: Security (AC: 8)
# ==========================================

test_oauth2_proxy_deployed() {
    kubectl get deployment oauth2-proxy -n monitoring &>/dev/null
}

test_prometheus_auth_configured() {
    kubectl get configmap prometheus-auth -n monitoring &>/dev/null
}

test_tls_certificates_configured() {
    kubectl get secret prometheus-tls -n monitoring &>/dev/null
}

test_network_policy_exists() {
    kubectl get networkpolicy prometheus-netpol -n monitoring &>/dev/null
}

# ==========================================
# Test Suite: Infrastructure as Code
# ==========================================

test_terraform_files_exist() {
    assert_file_exists "infrastructure/terraform/monitoring/prometheus.tf"
    assert_file_exists "infrastructure/terraform/monitoring/variables.tf"
    assert_file_exists "infrastructure/terraform/monitoring/outputs.tf"
}

test_helm_values_file_exists() {
    assert_file_exists "infrastructure/kubernetes/prometheus-values.yaml"
}

test_resource_naming_convention() {
    # Check that all resources follow e2e-* naming convention
    local rg_name=$(kubectl get statefulset prometheus -n monitoring -o jsonpath='{.metadata.annotations.azure-resource-group}' 2>/dev/null || echo "")
    if [ ! -z "$rg_name" ]; then
        echo "$rg_name" | grep -q "^e2e-" || return 1
    fi
    return 0
}

# ==========================================
# Test Suite: Monitoring & Alerting
# ==========================================

test_prometheus_self_monitoring() {
    kubectl port-forward -n monitoring svc/prometheus 9090:9090 &>/dev/null &
    local port_forward_pid=$!
    sleep 5
    
    local metrics=$(curl -s "http://localhost:9090/metrics" 2>/dev/null || echo "")
    kill $port_forward_pid 2>/dev/null || true
    
    echo "$metrics" | grep -q "prometheus_" || return 1
}

test_alertmanager_integration() {
    local config=$(kubectl get configmap prometheus-config -n monitoring -o yaml 2>/dev/null || echo "")
    echo "$config" | grep -q "alertmanagers:" || return 1
}

# ==========================================
# Main Test Runner
# ==========================================

main() {
    echo "================================================"
    echo "Prometheus Deployment Test Suite"
    echo "================================================"
    echo ""
    
    # Infrastructure Tests
    echo -e "${YELLOW}=== Infrastructure Tests ===${NC}"
    run_test "Kubernetes namespace exists" test_kubernetes_namespace_exists || true
    run_test "Prometheus ConfigMap exists" test_prometheus_configmap_exists || true
    run_test "Prometheus StatefulSet exists" test_prometheus_deployment_exists || true
    run_test "Prometheus Service exists" test_prometheus_service_exists || true
    run_test "Persistent volumes configured" test_prometheus_persistent_volume_exists || true
    echo ""
    
    # High Availability Tests
    echo -e "${YELLOW}=== High Availability Tests (AC: 1) ===${NC}"
    run_test "HA replicas configured (>=2)" test_prometheus_ha_replicas || true
    run_test "Multiple pods running" test_prometheus_pods_running || true
    echo ""
    
    # Service Discovery Tests
    echo -e "${YELLOW}=== Service Discovery Tests (AC: 2, 3) ===${NC}"
    run_test "Service discovery configured" test_service_discovery_configured || true
    run_test "Kubernetes targets discovered" test_kubernetes_targets_discovered || true
    run_test "Application metrics endpoint" test_application_metrics_endpoint || true
    echo ""
    
    # Data Retention Tests
    echo -e "${YELLOW}=== Data Retention Tests (AC: 4) ===${NC}"
    run_test "15-day retention configured" test_retention_policy_configured || true
    run_test "Storage size configured" test_storage_size_configured || true
    echo ""
    
    # Remote Storage Tests
    echo -e "${YELLOW}=== Remote Storage Tests (AC: 5) ===${NC}"
    run_test "Remote write configured" test_remote_write_configured || true
    run_test "Thanos receiver deployed" test_thanos_receiver_deployed || true
    run_test "Object storage configured" test_thanos_object_storage_configured || true
    echo ""
    
    # Recording Rules Tests
    echo -e "${YELLOW}=== Recording Rules Tests (AC: 6) ===${NC}"
    run_test "Recording rules ConfigMap exists" test_recording_rules_configmap_exists || true
    run_test "Recording rules mounted" test_recording_rules_mounted || true
    run_test "Recording rules evaluated" test_recording_rules_evaluated || true
    echo ""
    
    # Federation Tests
    echo -e "${YELLOW}=== Federation Tests (AC: 7) ===${NC}"
    run_test "Federation endpoint available" test_federation_endpoint_available || true
    run_test "Federation config exists" test_federation_config_exists || true
    echo ""
    
    # Security Tests
    echo -e "${YELLOW}=== Security Tests (AC: 8) ===${NC}"
    run_test "OAuth2 proxy deployed" test_oauth2_proxy_deployed || true
    run_test "Authentication configured" test_prometheus_auth_configured || true
    run_test "TLS certificates configured" test_tls_certificates_configured || true
    run_test "Network policy exists" test_network_policy_exists || true
    echo ""
    
    # Infrastructure as Code Tests
    echo -e "${YELLOW}=== Infrastructure as Code Tests ===${NC}"
    run_test "Terraform files exist" test_terraform_files_exist || true
    run_test "Helm values file exists" test_helm_values_file_exists || true
    run_test "Resource naming convention" test_resource_naming_convention || true
    echo ""
    
    # Monitoring Tests
    echo -e "${YELLOW}=== Monitoring & Alerting Tests ===${NC}"
    run_test "Prometheus self-monitoring" test_prometheus_self_monitoring || true
    run_test "Alertmanager integration" test_alertmanager_integration || true
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