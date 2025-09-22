#!/bin/bash

# OWASP ZAP DAST Scanning Script
# Usage: ./run-dast-scan.sh <target-url> <scan-type> [output-format]

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
ZAP_HOST="${ZAP_HOST:-localhost}"
ZAP_PORT="${ZAP_PORT:-8080}"
ZAP_API_KEY="${ZAP_API_KEY:-secdevops-api-key}"
REPORT_DIR="./zap/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to print colored output
log() {
    echo -e "${2:-$NC}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to wait for ZAP to be ready
wait_for_zap() {
    log "⏳ Waiting for ZAP to be ready..." "$YELLOW"
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "http://${ZAP_HOST}:${ZAP_PORT}/JSON/core/view/version/?apikey=${ZAP_API_KEY}" > /dev/null 2>&1; then
            log "✅ ZAP is ready!" "$GREEN"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    log "❌ ZAP failed to start after 60 seconds" "$RED"
    return 1
}

# Function to run baseline scan
run_baseline_scan() {
    local target=$1
    local report_name="${REPORT_DIR}/baseline_${TIMESTAMP}"
    
    log "🔍 Running baseline scan on: $target" "$BLUE"
    
    docker run --rm \
        --network secdevops-network \
        -v $(pwd)/zap/reports:/zap/wrk:rw \
        -t ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
        -t "$target" \
        -r "${report_name}.html" \
        -J "${report_name}.json" \
        -x "${report_name}.xml" \
        -I
    
    log "✅ Baseline scan complete" "$GREEN"
    echo "${report_name}"
}

# Function to run full scan
run_full_scan() {
    local target=$1
    local report_name="${REPORT_DIR}/full_${TIMESTAMP}"
    
    log "🔍 Running full scan on: $target" "$BLUE"
    log "⚠️  This may take 30+ minutes..." "$YELLOW"
    
    # Start spider
    log "🕷️  Starting spider..." "$BLUE"
    spider_id=$(curl -s "http://${ZAP_HOST}:${ZAP_PORT}/JSON/spider/action/scan/?apikey=${ZAP_API_KEY}&url=${target}&maxChildren=10&recurse=true" | jq -r '.scan')
    
    # Wait for spider to complete
    while true; do
        progress=$(curl -s "http://${ZAP_HOST}:${ZAP_PORT}/JSON/spider/view/status/?apikey=${ZAP_API_KEY}&scanId=${spider_id}" | jq -r '.status')
        if [ "$progress" = "100" ]; then
            break
        fi
        echo -ne "\r🕷️  Spider progress: ${progress}%"
        sleep 5
    done
    echo ""
    log "✅ Spider scan complete" "$GREEN"
    
    # Start active scan
    log "⚔️  Starting active scan..." "$BLUE"
    scan_id=$(curl -s "http://${ZAP_HOST}:${ZAP_PORT}/JSON/ascan/action/scan/?apikey=${ZAP_API_KEY}&url=${target}&recurse=true&inScopeOnly=false&scanPolicyName=&method=&postData=" | jq -r '.scan')
    
    # Wait for active scan to complete
    while true; do
        progress=$(curl -s "http://${ZAP_HOST}:${ZAP_PORT}/JSON/ascan/view/status/?apikey=${ZAP_API_KEY}&scanId=${scan_id}" | jq -r '.status')
        if [ "$progress" = "100" ]; then
            break
        fi
        echo -ne "\r⚔️  Active scan progress: ${progress}%"
        sleep 10
    done
    echo ""
    log "✅ Active scan complete" "$GREEN"
    
    # Generate reports
    generate_reports "$report_name"
    echo "${report_name}"
}

# Function to run API scan
run_api_scan() {
    local target=$1
    local api_spec=${2:-""}
    local report_name="${REPORT_DIR}/api_${TIMESTAMP}"
    
    log "🔍 Running API scan on: $target" "$BLUE"
    
    if [ -n "$api_spec" ] && [ -f "$api_spec" ]; then
        log "📄 Using API specification: $api_spec" "$BLUE"
        
        # Import OpenAPI definition
        curl -s -X POST "http://${ZAP_HOST}:${ZAP_PORT}/JSON/openapi/action/importFile/?apikey=${ZAP_API_KEY}" \
            -F "file=@${api_spec}" \
            -F "target=${target}"
    fi
    
    docker run --rm \
        --network secdevops-network \
        -v $(pwd)/zap/reports:/zap/wrk:rw \
        -v $(pwd):/workspace:ro \
        -t ghcr.io/zaproxy/zaproxy:stable zap-api-scan.py \
        -t "$target" \
        -f openapi \
        -r "${report_name}.html" \
        -J "${report_name}.json" \
        -x "${report_name}.xml"
    
    log "✅ API scan complete" "$GREEN"
    echo "${report_name}"
}

# Function to generate reports
generate_reports() {
    local report_base=$1
    
    log "📊 Generating reports..." "$BLUE"
    
    # HTML Report
    curl -s "http://${ZAP_HOST}:${ZAP_PORT}/OTHER/core/other/htmlreport/?apikey=${ZAP_API_KEY}" > "${report_base}.html"
    
    # JSON Report
    curl -s "http://${ZAP_HOST}:${ZAP_PORT}/JSON/core/view/alerts/?apikey=${ZAP_API_KEY}&baseurl=${target}" > "${report_base}.json"
    
    # XML Report
    curl -s "http://${ZAP_HOST}:${ZAP_PORT}/OTHER/core/other/xmlreport/?apikey=${ZAP_API_KEY}" > "${report_base}.xml"
    
    log "✅ Reports generated" "$GREEN"
}

# Function to parse results
parse_results() {
    local report_file=$1
    
    if [ ! -f "${report_file}.json" ]; then
        log "⚠️  Report file not found: ${report_file}.json" "$YELLOW"
        return 1
    fi
    
    log "📋 Scan Results Summary:" "$BLUE"
    
    # Parse JSON report for findings
    local high=$(jq '[.alerts[] | select(.risk=="High")] | length' "${report_file}.json")
    local medium=$(jq '[.alerts[] | select(.risk=="Medium")] | length' "${report_file}.json")
    local low=$(jq '[.alerts[] | select(.risk=="Low")] | length' "${report_file}.json")
    local info=$(jq '[.alerts[] | select(.risk=="Informational")] | length' "${report_file}.json")
    
    echo -e "${RED}🔴 High: $high${NC}"
    echo -e "${YELLOW}🟡 Medium: $medium${NC}"
    echo -e "${BLUE}🔵 Low: $low${NC}"
    echo -e "${NC}⚪ Info: $info${NC}"
    
    # Check thresholds
    if [ "$high" -gt 0 ]; then
        log "❌ FAILED: High severity vulnerabilities found!" "$RED"
        return 1
    elif [ "$medium" -gt 5 ]; then
        log "⚠️  WARNING: Too many medium severity issues" "$YELLOW"
        return 2
    else
        log "✅ PASSED: No critical issues found" "$GREEN"
        return 0
    fi
}

# Main function
main() {
    if [ $# -lt 2 ]; then
        log "Usage: $0 <target-url> <baseline|full|api> [api-spec-file]" "$RED"
        log "Examples:" "$NC"
        log "  $0 http://test-app:8080 baseline" "$NC"
        log "  $0 http://test-app:8080 full" "$NC"
        log "  $0 http://test-app:8080 api openapi.yaml" "$NC"
        exit 1
    fi
    
    local TARGET_URL=$1
    local SCAN_TYPE=$2
    local API_SPEC=${3:-""}
    
    # Create report directory
    mkdir -p "$REPORT_DIR"
    
    log "🚀 OWASP ZAP Security Scan" "$BLUE"
    log "Target: $TARGET_URL" "$BLUE"
    log "Type: $SCAN_TYPE" "$BLUE"
    
    # Ensure ZAP is running
    if ! wait_for_zap; then
        log "⚠️  Starting ZAP container..." "$YELLOW"
        docker-compose -f docker-compose.zap.yml up -d zap
        wait_for_zap || exit 1
    fi
    
    # Run appropriate scan
    case "$SCAN_TYPE" in
        baseline)
            report=$(run_baseline_scan "$TARGET_URL")
            ;;
        full)
            report=$(run_full_scan "$TARGET_URL")
            ;;
        api)
            report=$(run_api_scan "$TARGET_URL" "$API_SPEC")
            ;;
        *)
            log "❌ Invalid scan type. Use: baseline, full, or api" "$RED"
            exit 1
            ;;
    esac
    
    # Parse and display results
    parse_results "$report"
    result=$?
    
    # Output report locations
    log "" "$NC"
    log "📁 Reports generated:" "$BLUE"
    log "├── HTML: ${report}.html" "$NC"
    log "├── JSON: ${report}.json" "$NC"
    log "└── XML: ${report}.xml" "$NC"
    
    # Exit with appropriate code
    exit $result
}

# Run main function
main "$@"