#!/bin/bash
set -e

# OWASP ZAP Security Scanning Script
# Performs Dynamic Application Security Testing (DAST)

TARGET_URL="${1:-http://localhost:3001}"
SCAN_TYPE="${2:-baseline}"  # baseline, full, or api
REPORT_DIR="./security-reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "========================================="
echo "OWASP ZAP Security Scan"
echo "========================================="
echo "Target: $TARGET_URL"
echo "Scan Type: $SCAN_TYPE"
echo "Timestamp: $TIMESTAMP"
echo ""

# Create report directory
mkdir -p "$REPORT_DIR/zap"

# Pull latest ZAP image
echo "Pulling latest OWASP ZAP Docker image..."
docker pull zaproxy/zap-stable:latest

# Determine scan command based on type
case "$SCAN_TYPE" in
    "baseline")
        SCAN_CMD="zap-baseline.py"
        SCAN_TIME="5-10 minutes"
        ;;
    "full")
        SCAN_CMD="zap-full-scan.py"
        SCAN_TIME="30-60 minutes"
        ;;
    "api")
        SCAN_CMD="zap-api-scan.py"
        SCAN_TIME="10-20 minutes"
        ;;
    *)
        echo "Invalid scan type. Use: baseline, full, or api"
        exit 1
        ;;
esac

echo "Starting $SCAN_TYPE scan (estimated time: $SCAN_TIME)..."

# Run ZAP scan
docker run --rm \
    -v $(pwd)/$REPORT_DIR/zap:/zap/wrk:rw \
    -t zaproxy/zap-stable \
    $SCAN_CMD \
    -t "$TARGET_URL" \
    -r "zap_report_${TIMESTAMP}.html" \
    -J "zap_report_${TIMESTAMP}.json" \
    -x "zap_report_${TIMESTAMP}.xml" \
    -m 5 \
    -z "-config api.disablekey=true" || SCAN_EXIT_CODE=$?

# Analyze results
if [ -f "$REPORT_DIR/zap/zap_report_${TIMESTAMP}.json" ]; then
    echo ""
    echo "Analyzing scan results..."
    
    # Install jq if not present
    which jq > /dev/null || sudo apt-get install -y jq
    
    # Parse results
    HIGH_RISKS=$(cat "$REPORT_DIR/zap/zap_report_${TIMESTAMP}.json" | jq '[.site[].alerts[] | select(.riskcode == "3")] | length' 2>/dev/null || echo 0)
    MEDIUM_RISKS=$(cat "$REPORT_DIR/zap/zap_report_${TIMESTAMP}.json" | jq '[.site[].alerts[] | select(.riskcode == "2")] | length' 2>/dev/null || echo 0)
    LOW_RISKS=$(cat "$REPORT_DIR/zap/zap_report_${TIMESTAMP}.json" | jq '[.site[].alerts[] | select(.riskcode == "1")] | length' 2>/dev/null || echo 0)
    INFO_RISKS=$(cat "$REPORT_DIR/zap/zap_report_${TIMESTAMP}.json" | jq '[.site[].alerts[] | select(.riskcode == "0")] | length' 2>/dev/null || echo 0)
    
    echo ""
    echo "========================================="
    echo "Security Scan Results Summary"
    echo "========================================="
    echo "🔴 High Risk Issues: $HIGH_RISKS"
    echo "🟠 Medium Risk Issues: $MEDIUM_RISKS"
    echo "🟡 Low Risk Issues: $LOW_RISKS"
    echo "🔵 Informational: $INFO_RISKS"
    echo ""
    
    # Show high risk details if any
    if [ "$HIGH_RISKS" -gt "0" ]; then
        echo "⚠️  HIGH RISK VULNERABILITIES DETECTED:"
        cat "$REPORT_DIR/zap/zap_report_${TIMESTAMP}.json" | jq -r '.site[].alerts[] | select(.riskcode == "3") | "  - \(.name): \(.description | split("\n")[0])"' 2>/dev/null
        echo ""
    fi
    
    # Quality gate
    if [ "$HIGH_RISKS" -gt "0" ]; then
        echo "❌ FAILED: High risk security issues found!"
        echo "   Please review the detailed report at: $REPORT_DIR/zap/zap_report_${TIMESTAMP}.html"
        exit 1
    elif [ "$MEDIUM_RISKS" -gt "5" ]; then
        echo "⚠️  WARNING: Multiple medium risk issues found!"
        echo "   Please review the detailed report at: $REPORT_DIR/zap/zap_report_${TIMESTAMP}.html"
        exit 0
    else
        echo "✅ PASSED: No critical security issues found."
        echo "   Detailed report available at: $REPORT_DIR/zap/zap_report_${TIMESTAMP}.html"
    fi
else
    echo "⚠️  Warning: Could not find scan results file"
    exit ${SCAN_EXIT_CODE:-1}
fi

echo ""
echo "Reports generated:"
echo "  - HTML: $REPORT_DIR/zap/zap_report_${TIMESTAMP}.html"
echo "  - JSON: $REPORT_DIR/zap/zap_report_${TIMESTAMP}.json"
echo "  - XML: $REPORT_DIR/zap/zap_report_${TIMESTAMP}.xml"