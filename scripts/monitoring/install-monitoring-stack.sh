#!/bin/bash
set -e

echo "Installing Monitoring Stack for SecDevOps CI/CD Pipeline..."
echo "=========================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
MONITORING_DIR="$PROJECT_ROOT/monitoring"

create_directory_structure() {
    echo "Creating monitoring directory structure..."
    
    mkdir -p "$MONITORING_DIR"/{prometheus,grafana/{provisioning/{dashboards,datasources},dashboards},alertmanager,blackbox}
    
    echo "Directory structure created"
}

configure_prometheus() {
    echo "Configuring Prometheus..."
    
    cat > "$MONITORING_DIR/prometheus/prometheus.yml" <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'secdevops-monitor'
    environment: 'production'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          service: 'prometheus'

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          service: 'node-exporter'

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
        labels:
          service: 'cadvisor'

  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['jenkins:8080']
        labels:
          service: 'jenkins'

  - job_name: 'jenkins-exporter'
    static_configs:
      - targets: ['jenkins-exporter:9103']
        labels:
          service: 'jenkins-exporter'

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
        labels:
          service: 'grafana'

  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - http://jenkins:8080
        - http://sonarqube:9000
        - http://grafana:3000
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']
        labels:
          service: 'docker'

  - job_name: 'anchore'
    static_configs:
      - targets: ['anchore-engine:8338']
        labels:
          service: 'anchore'

  - job_name: 'sonarqube'
    static_configs:
      - targets: ['sonarqube:9000']
        labels:
          service: 'sonarqube'
EOF
    
    echo "Prometheus configured"
}

configure_alert_rules() {
    echo "Configuring alert rules..."
    
    cat > "$MONITORING_DIR/prometheus/alert_rules.yml" <<'EOF'
groups:
  - name: jenkins_alerts
    interval: 30s
    rules:
      - alert: JenkinsDown
        expr: up{job="jenkins"} == 0
        for: 5m
        labels:
          severity: critical
          service: jenkins
        annotations:
          summary: "Jenkins is down"
          description: "Jenkins has been down for more than 5 minutes"

      - alert: HighBuildFailureRate
        expr: rate(jenkins_builds_failed_total[5m]) > 0.3
        for: 10m
        labels:
          severity: warning
          service: jenkins
        annotations:
          summary: "High build failure rate"
          description: "Build failure rate is above 30% for the last 10 minutes"

      - alert: LongRunningBuild
        expr: jenkins_job_duration_seconds > 1800
        for: 5m
        labels:
          severity: warning
          service: jenkins
        annotations:
          summary: "Long running build detected"
          description: "Build {{ $labels.job }} has been running for more than 30 minutes"

  - name: security_alerts
    interval: 60s
    rules:
      - alert: CriticalVulnerabilitiesFound
        expr: security_issues_total{severity="critical"} > 0
        for: 1m
        labels:
          severity: critical
          service: security
        annotations:
          summary: "Critical security vulnerabilities detected"
          description: "{{ $value }} critical vulnerabilities found in the latest scan"

      - alert: HighVulnerabilitiesFound
        expr: security_issues_total{severity="high"} > 5
        for: 5m
        labels:
          severity: warning
          service: security
        annotations:
          summary: "High number of high-severity vulnerabilities"
          description: "{{ $value }} high-severity vulnerabilities found"

      - alert: SecretsDetected
        expr: security_tool_status{tool="truffleHog",status="FAIL"} == 0
        for: 1m
        labels:
          severity: critical
          service: security
        annotations:
          summary: "Secrets detected in code"
          description: "TruffleHog has detected secrets in the codebase"

  - name: infrastructure_alerts
    interval: 30s
    rules:
      - alert: HighCPUUsage
        expr: (100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 80
        for: 10m
        labels:
          severity: warning
          service: infrastructure
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% on {{ $labels.instance }}"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 90
        for: 5m
        labels:
          severity: warning
          service: infrastructure
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 90% on {{ $labels.instance }}"

      - alert: DiskSpaceLow
        expr: node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100 < 10
        for: 5m
        labels:
          severity: critical
          service: infrastructure
        annotations:
          summary: "Low disk space"
          description: "Less than 10% disk space remaining on {{ $labels.instance }}"

      - alert: ContainerDown
        expr: up{job=~".*-exporter"} == 0
        for: 5m
        labels:
          severity: warning
          service: infrastructure
        annotations:
          summary: "Container is down"
          description: "{{ $labels.job }} container has been down for more than 5 minutes"

  - name: quality_alerts
    interval: 60s
    rules:
      - alert: LowCodeCoverage
        expr: sonarqube_coverage < 80
        for: 5m
        labels:
          severity: warning
          service: quality
        annotations:
          summary: "Code coverage below threshold"
          description: "Code coverage is {{ $value }}%, below the 80% threshold"

      - alert: QualityGateFailed
        expr: quality_gate_status == 0
        for: 1m
        labels:
          severity: warning
          service: quality
        annotations:
          summary: "Quality gate failed"
          description: "SonarQube quality gate has failed"
EOF
    
    echo "Alert rules configured"
}

configure_alertmanager() {
    echo "Configuring Alertmanager..."
    
    cat > "$MONITORING_DIR/alertmanager/config.yml" <<EOF
global:
  resolve_timeout: 5m
  slack_api_url: '\${SLACK_WEBHOOK_URL}'

route:
  group_by: ['alertname', 'severity', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'
  
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
      continue: true
    
    - match:
        service: security
      receiver: 'security-alerts'
      continue: true
    
    - match:
        service: jenkins
      receiver: 'jenkins-alerts'

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://localhost:5001/webhook'
        send_resolved: true

  - name: 'critical-alerts'
    slack_configs:
      - channel: '#critical-alerts'
        title: '🚨 Critical Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.description }}{{ end }}'
        send_resolved: true
    email_configs:
      - to: 'devops-team@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'alertmanager@example.com'
        auth_password: '\${EMAIL_PASSWORD}'

  - name: 'security-alerts'
    slack_configs:
      - channel: '#security'
        title: '🔒 Security Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.description }}{{ end }}'
        send_resolved: true

  - name: 'jenkins-alerts'
    slack_configs:
      - channel: '#jenkins'
        title: '🔧 Jenkins Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.description }}{{ end }}'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'service']
EOF
    
    echo "Alertmanager configured"
}

configure_blackbox() {
    echo "Configuring Blackbox exporter..."
    
    cat > "$MONITORING_DIR/blackbox/config.yml" <<EOF
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: []
      method: GET
      no_follow_redirects: false
      fail_if_ssl: false
      fail_if_not_ssl: false
      tls_config:
        insecure_skip_verify: true

  http_post_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      method: POST

  tcp_connect:
    prober: tcp
    timeout: 5s

  icmp:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: "ip4"

  ssh_banner:
    prober: tcp
    timeout: 5s
    tcp:
      query_response:
        - expect: "^SSH-2.0-"

  http_jenkins:
    prober: http
    timeout: 5s
    http:
      valid_status_codes: [200, 403]
      method: GET
      headers:
        Accept: "*/*"
      basic_auth:
        username: "monitoring"
        password: "monitoring123"
EOF
    
    echo "Blackbox exporter configured"
}

configure_grafana() {
    echo "Configuring Grafana..."
    
    cat > "$MONITORING_DIR/grafana/provisioning/datasources/prometheus.yml" <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Alertmanager
    type: alertmanager
    access: proxy
    url: http://alertmanager:9093
    editable: true
EOF
    
    cat > "$MONITORING_DIR/grafana/provisioning/dashboards/dashboard.yml" <<EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF
    
    echo "Grafana configured"
}

start_monitoring_stack() {
    echo "Starting monitoring stack..."
    
    cd "$MONITORING_DIR"
    
    docker-compose -f docker-compose.monitoring.yml pull
    docker-compose -f docker-compose.monitoring.yml up -d
    
    echo "Waiting for services to start..."
    sleep 20
    
    echo "Checking service status..."
    docker-compose -f docker-compose.monitoring.yml ps
}

verify_installation() {
    echo "Verifying installation..."
    
    services=(
        "prometheus:9090"
        "grafana:3000"
        "alertmanager:9093"
        "node-exporter:9100"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r name port <<< "$service"
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" | grep -q "200\|302"; then
            echo "✓ $name is running on port $port"
        else
            echo "✗ $name is not responding on port $port"
        fi
    done
}

echo "Monitoring Stack Installation Starting..."
echo "========================================"

create_directory_structure
configure_prometheus
configure_alert_rules
configure_alertmanager
configure_blackbox
configure_grafana
start_monitoring_stack
verify_installation

echo ""
echo "========================================"
echo "Monitoring Stack Installation Complete!"
echo ""
echo "Access URLs:"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana: http://localhost:3000 (admin/admin123)"
echo "- Alertmanager: http://localhost:9093"
echo ""
echo "To import dashboards:"
echo "1. Log into Grafana"
echo "2. Go to Dashboards > Import"
echo "3. Use the JSON files from $MONITORING_DIR/grafana/dashboards/"
echo ""
echo "To view metrics:"
echo "- Node metrics: http://localhost:9100/metrics"
echo "- Container metrics: http://localhost:8080/metrics"
echo "- Jenkins metrics: http://localhost:8080/prometheus"