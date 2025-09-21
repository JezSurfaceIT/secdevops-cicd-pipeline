#!/bin/bash
set -e

echo "Installing Security Tools for SecDevOps CI/CD Pipeline..."
echo "=================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

install_anchore() {
    echo "Installing Anchore Engine..."
    
    cd "$PROJECT_ROOT/monitoring"
    
    cat > docker-compose.anchore.yml <<EOF
version: '3.8'

services:
  anchore-db:
    image: postgres:13
    container_name: anchore-db
    environment:
      POSTGRES_DB: anchore
      POSTGRES_USER: anchore
      POSTGRES_PASSWORD: anchore123
    volumes:
      - anchore-db-data:/var/lib/postgresql/data
    networks:
      - anchore-net
    restart: unless-stopped

  anchore-engine:
    image: anchore/anchore-engine:v1.0.0
    container_name: anchore-engine
    depends_on:
      - anchore-db
    environment:
      ANCHORE_DB_HOST: anchore-db
      ANCHORE_DB_USER: anchore
      ANCHORE_DB_PASSWORD: anchore123
      ANCHORE_DB_NAME: anchore
      ANCHORE_ADMIN_PASSWORD: admin123
      ANCHORE_CLI_USER: admin
      ANCHORE_CLI_PASS: admin123
      ANCHORE_ENABLE_METRICS: "true"
    ports:
      - "8228:8228"
      - "8338:8338"
    volumes:
      - ./anchore/config:/config
      - anchore-engine-data:/var/lib/anchore
    networks:
      - anchore-net
    restart: unless-stopped

volumes:
  anchore-db-data:
  anchore-engine-data:

networks:
  anchore-net:
    driver: bridge
EOF
    
    mkdir -p anchore/config
    
    cat > anchore/config/config.yaml <<EOF
services:
  apiext:
    enabled: true
    listen: "0.0.0.0"
    port: 8228
  catalog:
    enabled: true
  simplequeue:
    enabled: true
  analyzer:
    enabled: true
    cycle_timers:
      image_analyzer: 5
  policy_engine:
    enabled: true
    cycle_timers:
      policy_evaluation: 5

credentials:
  database:
    db_connect: "postgresql://anchore:anchore123@anchore-db:5432/anchore"

default_admin_password: admin123
default_admin_email: admin@example.com

log_level: INFO

metrics:
  enabled: true

webhooks:
  enabled: true
  
policy_bundles:
  - id: default_bundle
    name: "Default Security Policy"
    version: "1.0"
    policies:
      - id: default_policy
        name: "Default Policy"
        version: "1.0"
        rules:
          - action: STOP
            gate: vulnerabilities
            trigger: package
            params:
              - name: severity_comparison
                value: ">"
              - name: severity
                value: high
          - action: WARN
            gate: dockerfile
            trigger: no_healthcheck
          - action: WARN
            gate: dockerfile
            trigger: no_user
EOF
    
    echo "Starting Anchore Engine..."
    docker-compose -f docker-compose.anchore.yml up -d
    
    echo "Waiting for Anchore to be ready..."
    sleep 30
    
    echo "Installing Anchore CLI..."
    pip3 install --user anchorecli
    
    echo "Anchore Engine installed successfully!"
}

install_owasp_dependency_check() {
    echo "Installing OWASP Dependency Check..."
    
    OWASP_DC_VERSION="9.0.6"
    INSTALL_DIR="/opt/owasp-dependency-check"
    
    if [ ! -d "$INSTALL_DIR" ]; then
        sudo mkdir -p "$INSTALL_DIR"
        cd /tmp
        
        echo "Downloading OWASP Dependency Check v${OWASP_DC_VERSION}..."
        wget -q https://github.com/jeremylong/DependencyCheck/releases/download/v${OWASP_DC_VERSION}/dependency-check-${OWASP_DC_VERSION}-release.zip
        
        echo "Extracting..."
        sudo unzip -q dependency-check-${OWASP_DC_VERSION}-release.zip -d "$INSTALL_DIR"
        
        echo "Creating symlink..."
        sudo ln -sf "$INSTALL_DIR/dependency-check/bin/dependency-check.sh" /usr/local/bin/dependency-check
        
        echo "Downloading initial vulnerability database..."
        dependency-check --updateonly --data /var/lib/dependency-check-data
        
        rm dependency-check-${OWASP_DC_VERSION}-release.zip
        echo "OWASP Dependency Check installed successfully!"
    else
        echo "OWASP Dependency Check already installed"
    fi
}

install_gitleaks() {
    echo "Installing GitLeaks..."
    
    GITLEAKS_VERSION="8.18.1"
    
    if ! command -v gitleaks &> /dev/null; then
        cd /tmp
        wget -q https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz
        tar -xzf gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz
        sudo mv gitleaks /usr/local/bin/
        sudo chmod +x /usr/local/bin/gitleaks
        rm gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz
        echo "GitLeaks installed successfully!"
    else
        echo "GitLeaks already installed"
    fi
    
    cat > "$PROJECT_ROOT/.gitleaks.toml" <<EOF
title = "gitleaks config"

[allowlist]
description = "global allow lists"
paths = [
    '''\.lock$''',
    '''node_modules''',
    '''vendor''',
]

[[rules]]
description = "AWS Access Key"
regex = '''(A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{16}'''
tags = ["aws", "credentials"]

[[rules]]
description = "Azure Storage Account Key"
regex = '''[a-zA-Z0-9+/]{86}=='''
tags = ["azure", "credentials"]

[[rules]]
description = "GitHub Token"
regex = '''ghp_[a-zA-Z0-9]{36}'''
tags = ["github", "token"]

[[rules]]
description = "Private Key"
regex = '''-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----'''
tags = ["key", "private"]

[[rules]]
description = "Generic API Key"
regex = '''(?i)(api[_\-\s]?key|apikey|api_secret|api[_\-\s]?token)[\s]*[:=][\s]*["']?([a-zA-Z0-9\-_]{32,})["']?'''
tags = ["api", "key"]
EOF
}

install_container_diff() {
    echo "Installing Container-diff for image analysis..."
    
    if ! command -v container-diff &> /dev/null; then
        cd /tmp
        wget -q https://storage.googleapis.com/container-diff/latest/container-diff-linux-amd64
        sudo mv container-diff-linux-amd64 /usr/local/bin/container-diff
        sudo chmod +x /usr/local/bin/container-diff
        echo "Container-diff installed successfully!"
    else
        echo "Container-diff already installed"
    fi
}

create_security_wrapper_scripts() {
    echo "Creating security tool wrapper scripts..."
    
    cat > "$SCRIPT_DIR/run-anchore-scan.sh" <<'EOF'
#!/bin/bash
set -e

IMAGE=$1
if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image-name>"
    exit 1
fi

echo "Running Anchore scan on $IMAGE..."

export ANCHORE_CLI_URL=http://localhost:8228/v1
export ANCHORE_CLI_USER=admin
export ANCHORE_CLI_PASS=admin123

anchore-cli image add "$IMAGE" --wait
anchore-cli image vuln "$IMAGE" all
anchore-cli evaluate check "$IMAGE" --detail

VULNERABILITIES=$(anchore-cli image vuln "$IMAGE" all --json | jq '[.vulnerabilities[] | select(.severity == "Critical" or .severity == "High")] | length')

if [ "$VULNERABILITIES" -gt 0 ]; then
    echo "Found $VULNERABILITIES critical/high vulnerabilities!"
    exit 1
fi

echo "Anchore scan passed!"
EOF
    chmod +x "$SCRIPT_DIR/run-anchore-scan.sh"
    
    cat > "$SCRIPT_DIR/run-dependency-check.sh" <<'EOF'
#!/bin/bash
set -e

PROJECT_PATH=${1:-.}
OUTPUT_FORMAT=${2:-HTML}

echo "Running OWASP Dependency Check on $PROJECT_PATH..."

dependency-check \
    --scan "$PROJECT_PATH" \
    --format "$OUTPUT_FORMAT" \
    --out ./dependency-check-report \
    --suppression ./dependency-check-suppression.xml \
    --enableExperimental \
    --nvdApiKey "${NVD_API_KEY:-}" \
    --failOnCVSS 7

echo "Dependency Check completed!"
EOF
    chmod +x "$SCRIPT_DIR/run-dependency-check.sh"
    
    cat > "$SCRIPT_DIR/run-gitleaks.sh" <<'EOF'
#!/bin/bash
set -e

SCAN_PATH=${1:-.}
OUTPUT_FILE=${2:-gitleaks-report.json}

echo "Running GitLeaks scan on $SCAN_PATH..."

gitleaks detect \
    --source "$SCAN_PATH" \
    --report-format json \
    --report-path "$OUTPUT_FILE" \
    --verbose

if [ $? -ne 0 ]; then
    echo "Secrets detected! Check $OUTPUT_FILE for details."
    exit 1
fi

echo "GitLeaks scan passed!"
EOF
    chmod +x "$SCRIPT_DIR/run-gitleaks.sh"
}

echo "Security Tools Installation Starting..."
echo "======================================="

install_anchore
install_owasp_dependency_check
install_gitleaks
install_container_diff
create_security_wrapper_scripts

echo ""
echo "======================================="
echo "Security Tools Installation Complete!"
echo ""
echo "Installed Tools:"
echo "- Anchore Engine (Container Compliance)"
echo "- OWASP Dependency Check"
echo "- GitLeaks (Secret Scanner)"
echo "- Container-diff (Image Analysis)"
echo ""
echo "Wrapper scripts created in: $SCRIPT_DIR"
echo ""
echo "To verify installations:"
echo "  docker ps | grep anchore"
echo "  dependency-check --version"
echo "  gitleaks version"
echo "  container-diff version"