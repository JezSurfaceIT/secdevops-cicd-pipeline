#!/bin/bash
set -e

echo "Configuring Anchore Engine for SecDevOps Pipeline..."
echo "===================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ANCHORE_URL="http://localhost:8228/v1"
ANCHORE_USER="admin"
ANCHORE_PASS="admin123"

wait_for_anchore() {
    echo "Waiting for Anchore Engine to be ready..."
    for i in {1..60}; do
        if curl -s -u "$ANCHORE_USER:$ANCHORE_PASS" "$ANCHORE_URL/system/status" > /dev/null 2>&1; then
            echo "Anchore Engine is ready!"
            return 0
        fi
        echo -n "."
        sleep 5
    done
    echo "Anchore Engine failed to start!"
    return 1
}

configure_anchore_cli() {
    echo "Configuring Anchore CLI..."
    
    cat > ~/.anchorecli.yaml <<EOF
anchore:
  url: "$ANCHORE_URL"
  username: "$ANCHORE_USER"
  password: "$ANCHORE_PASS"
  ssl_verify: false
EOF
    
    echo "Anchore CLI configured"
}

create_custom_policies() {
    echo "Creating custom security policies..."
    
    mkdir -p "$PROJECT_ROOT/anchore-policies"
    
    cat > "$PROJECT_ROOT/anchore-policies/secdevops-policy.json" <<'EOF'
{
  "id": "secdevops_policy",
  "name": "SecDevOps Security Policy",
  "version": "1.0",
  "description": "Security policy for Oversight MVP containers",
  "last_updated": "2025-09-20",
  "policies": [
    {
      "id": "production_policy",
      "name": "Production Environment Policy",
      "comment": "Strict policy for production deployments",
      "rules": [
        {
          "gate": "vulnerabilities",
          "trigger": "package",
          "action": "stop",
          "params": [
            {"name": "severity_comparison", "value": ">="},
            {"name": "severity", "value": "high"}
          ]
        },
        {
          "gate": "dockerfile",
          "trigger": "no_healthcheck",
          "action": "warn",
          "params": []
        },
        {
          "gate": "dockerfile",
          "trigger": "no_user",
          "action": "stop",
          "params": []
        },
        {
          "gate": "dockerfile",
          "trigger": "sudo_usage",
          "action": "stop",
          "params": []
        },
        {
          "gate": "secret_scans",
          "trigger": "content_regex_checks",
          "action": "stop",
          "params": []
        },
        {
          "gate": "licenses",
          "trigger": "denylist",
          "action": "stop",
          "params": [
            {"name": "licenses", "value": "GPL-3.0,AGPL-3.0"}
          ]
        }
      ]
    },
    {
      "id": "development_policy",
      "name": "Development Environment Policy",
      "comment": "Relaxed policy for development",
      "rules": [
        {
          "gate": "vulnerabilities",
          "trigger": "package",
          "action": "warn",
          "params": [
            {"name": "severity_comparison", "value": ">="},
            {"name": "severity", "value": "critical"}
          ]
        },
        {
          "gate": "dockerfile",
          "trigger": "no_healthcheck",
          "action": "warn",
          "params": []
        },
        {
          "gate": "secret_scans",
          "trigger": "content_regex_checks",
          "action": "warn",
          "params": []
        }
      ]
    }
  ],
  "mappings": [
    {
      "name": "default",
      "registry": "*",
      "repository": "*",
      "image": {"type": "tag", "value": "*"},
      "policy_id": "development_policy"
    },
    {
      "name": "production",
      "registry": "*",
      "repository": "*",
      "image": {"type": "tag", "value": "prod-*"},
      "policy_id": "production_policy"
    }
  ]
}
EOF
    
    echo "Custom policies created"
}

configure_jenkins_integration() {
    echo "Creating Jenkins integration script..."
    
    cat > "$SCRIPT_DIR/jenkins-anchore-scan.sh" <<'EOF'
#!/bin/bash
set -e

IMAGE_NAME=$1
ENVIRONMENT=${2:-development}
FAIL_ON_POLICY=${3:-true}

if [ -z "$IMAGE_NAME" ]; then
    echo "Error: Image name is required"
    echo "Usage: $0 <image-name> [environment] [fail-on-policy]"
    exit 1
fi

echo "========================================="
echo "Anchore Security Scan"
echo "Image: $IMAGE_NAME"
echo "Environment: $ENVIRONMENT"
echo "Fail on Policy: $FAIL_ON_POLICY"
echo "========================================="

export ANCHORE_CLI_URL="${ANCHORE_URL:-http://localhost:8228/v1}"
export ANCHORE_CLI_USER="${ANCHORE_USER:-admin}"
export ANCHORE_CLI_PASS="${ANCHORE_PASS:-admin123}"

echo "Adding image to Anchore..."
anchore-cli image add "$IMAGE_NAME" --wait --force

echo "Waiting for analysis to complete..."
anchore-cli image wait "$IMAGE_NAME"

echo "Getting vulnerability report..."
anchore-cli image vuln "$IMAGE_NAME" all > vulnerability-report.txt

echo "Getting policy evaluation..."
POLICY_ID="development_policy"
if [ "$ENVIRONMENT" = "production" ]; then
    POLICY_ID="production_policy"
fi

anchore-cli evaluate check "$IMAGE_NAME" --detail --policy "$POLICY_ID" > policy-evaluation.txt

EVAL_STATUS=$(anchore-cli evaluate check "$IMAGE_NAME" --policy "$POLICY_ID" --json | jq -r '.[0][0][6]')

echo "========================================="
echo "Scan Results Summary:"
echo "========================================="

CRITICAL=$(anchore-cli image vuln "$IMAGE_NAME" all --json | jq '[.vulnerabilities[] | select(.severity == "Critical")] | length')
HIGH=$(anchore-cli image vuln "$IMAGE_NAME" all --json | jq '[.vulnerabilities[] | select(.severity == "High")] | length')
MEDIUM=$(anchore-cli image vuln "$IMAGE_NAME" all --json | jq '[.vulnerabilities[] | select(.severity == "Medium")] | length')
LOW=$(anchore-cli image vuln "$IMAGE_NAME" all --json | jq '[.vulnerabilities[] | select(.severity == "Low")] | length')

echo "Vulnerabilities Found:"
echo "  Critical: $CRITICAL"
echo "  High: $HIGH"
echo "  Medium: $MEDIUM"
echo "  Low: $LOW"
echo ""
echo "Policy Evaluation: $EVAL_STATUS"

if [ "$FAIL_ON_POLICY" = "true" ] && [ "$EVAL_STATUS" = "fail" ]; then
    echo "Policy evaluation failed! See policy-evaluation.txt for details."
    exit 1
fi

echo "Scan completed successfully!"
EOF
    chmod +x "$SCRIPT_DIR/jenkins-anchore-scan.sh"
    
    echo "Jenkins integration script created"
}

create_report_generator() {
    echo "Creating HTML report generator..."
    
    cat > "$SCRIPT_DIR/generate-anchore-report.py" <<'EOF'
#!/usr/bin/env python3
import json
import sys
import subprocess
from datetime import datetime

def get_scan_results(image_name):
    try:
        vuln_cmd = f"anchore-cli image vuln {image_name} all --json"
        vuln_result = subprocess.run(vuln_cmd, shell=True, capture_output=True, text=True)
        vulnerabilities = json.loads(vuln_result.stdout) if vuln_result.returncode == 0 else {}
        
        eval_cmd = f"anchore-cli evaluate check {image_name} --detail --json"
        eval_result = subprocess.run(eval_cmd, shell=True, capture_output=True, text=True)
        evaluation = json.loads(eval_result.stdout) if eval_result.returncode == 0 else []
        
        return vulnerabilities, evaluation
    except Exception as e:
        print(f"Error getting scan results: {e}")
        return {}, []

def generate_html_report(image_name, vulnerabilities, evaluation):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    vuln_by_severity = {
        "Critical": [],
        "High": [],
        "Medium": [],
        "Low": [],
        "Negligible": []
    }
    
    if 'vulnerabilities' in vulnerabilities:
        for vuln in vulnerabilities['vulnerabilities']:
            severity = vuln.get('severity', 'Unknown')
            if severity in vuln_by_severity:
                vuln_by_severity[severity].append(vuln)
    
    html = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Anchore Security Report - {image_name}</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        h1 {{ color: #333; }}
        .summary {{ background: #f4f4f4; padding: 15px; border-radius: 5px; margin: 20px 0; }}
        .critical {{ color: #d32f2f; font-weight: bold; }}
        .high {{ color: #f57c00; font-weight: bold; }}
        .medium {{ color: #fbc02d; }}
        .low {{ color: #689f38; }}
        table {{ border-collapse: collapse; width: 100%; margin: 20px 0; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background: #f2f2f2; }}
        .pass {{ background: #c8e6c9; }}
        .fail {{ background: #ffcdd2; }}
    </style>
</head>
<body>
    <h1>Anchore Security Report</h1>
    <div class="summary">
        <p><strong>Image:</strong> {image_name}</p>
        <p><strong>Scan Date:</strong> {timestamp}</p>
    </div>
    
    <h2>Vulnerability Summary</h2>
    <table>
        <tr>
            <th>Severity</th>
            <th>Count</th>
        </tr>
        <tr class="critical">
            <td>Critical</td>
            <td>{len(vuln_by_severity['Critical'])}</td>
        </tr>
        <tr class="high">
            <td>High</td>
            <td>{len(vuln_by_severity['High'])}</td>
        </tr>
        <tr class="medium">
            <td>Medium</td>
            <td>{len(vuln_by_severity['Medium'])}</td>
        </tr>
        <tr class="low">
            <td>Low</td>
            <td>{len(vuln_by_severity['Low'])}</td>
        </tr>
    </table>
    
    <h2>Detailed Vulnerabilities</h2>
"""
    
    for severity in ['Critical', 'High', 'Medium', 'Low']:
        if vuln_by_severity[severity]:
            html += f"<h3 class='{severity.lower()}'>{severity} Severity</h3>"
            html += "<table>"
            html += "<tr><th>Package</th><th>CVE</th><th>Description</th><th>Fix</th></tr>"
            for vuln in vuln_by_severity[severity]:
                html += f"""
                <tr>
                    <td>{vuln.get('package', 'N/A')}</td>
                    <td>{vuln.get('vuln', 'N/A')}</td>
                    <td>{vuln.get('package_type', 'N/A')}</td>
                    <td>{vuln.get('fix', 'No fix available')}</td>
                </tr>
                """
            html += "</table>"
    
    html += """
</body>
</html>
"""
    
    with open(f"anchore-report-{datetime.now().strftime('%Y%m%d-%H%M%S')}.html", "w") as f:
        f.write(html)
    
    print(f"Report generated: anchore-report-{datetime.now().strftime('%Y%m%d-%H%M%S')}.html")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 generate-anchore-report.py <image-name>")
        sys.exit(1)
    
    image_name = sys.argv[1]
    vulnerabilities, evaluation = get_scan_results(image_name)
    generate_html_report(image_name, vulnerabilities, evaluation)
EOF
    chmod +x "$SCRIPT_DIR/generate-anchore-report.py"
    
    echo "Report generator created"
}

setup_automated_scanning() {
    echo "Setting up automated scanning rules..."
    
    cat > "$PROJECT_ROOT/anchore-policies/scan-config.yaml" <<EOF
scan_config:
  registries:
    - name: "dockerhub"
      type: "docker_v2"
      url: "https://index.docker.io"
      verify_ssl: true
    - name: "acr"
      type: "docker_v2"
      url: "oversightmvp.azurecr.io"
      verify_ssl: true
  
  auto_scan:
    enabled: true
    frequency: "hourly"
    
  notifications:
    webhook:
      enabled: true
      url: "${WEBHOOK_URL:-http://jenkins:8080/anchore-webhook}"
      
  retention:
    images:
      days: 30
    reports:
      days: 90
EOF
    
    echo "Automated scanning configured"
}

echo "Starting Anchore configuration..."
echo "================================="

wait_for_anchore
configure_anchore_cli
create_custom_policies
configure_jenkins_integration
create_report_generator
setup_automated_scanning

echo ""
echo "================================="
echo "Anchore Configuration Complete!"
echo ""
echo "Configuration Summary:"
echo "- CLI configured at ~/.anchorecli.yaml"
echo "- Custom policies created in $PROJECT_ROOT/anchore-policies/"
echo "- Jenkins integration script: $SCRIPT_DIR/jenkins-anchore-scan.sh"
echo "- Report generator: $SCRIPT_DIR/generate-anchore-report.py"
echo ""
echo "To test the configuration:"
echo "  anchore-cli system status"
echo "  anchore-cli policy list"
echo ""
echo "To scan an image:"
echo "  $SCRIPT_DIR/jenkins-anchore-scan.sh <image-name>"