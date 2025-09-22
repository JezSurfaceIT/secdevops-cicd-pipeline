// securityUtils.groovy - Security scanning utility functions for Jenkins pipeline

def scanForSecrets() {
    echo "🔍 Scanning for secrets with TruffleHog..."
    
    sh '''
        mkdir -p reports
        
        # Run TruffleHog scan
        docker run --rm -v $(pwd):/repo \
            trufflesecurity/trufflehog:latest \
            git file:///repo \
            --json \
            --no-update \
            > reports/trufflehog-scan.json 2>/dev/null || true
        
        # Check for verified secrets
        VERIFIED_SECRETS=$(jq '[.[] | select(.verified==true)]' reports/trufflehog-scan.json | jq length)
        
        if [ "$VERIFIED_SECRETS" -gt 0 ]; then
            echo "❌ CRITICAL: Verified secrets found in code!"
            jq '.[] | select(.verified==true) | {file: .path, line: .line_number, type: .detector_name, redacted: .redacted}' reports/trufflehog-scan.json
            exit 1
        fi
        
        # Check for potential secrets
        POTENTIAL_SECRETS=$(jq '[.[] | select(.verified==false)]' reports/trufflehog-scan.json | jq length)
        
        if [ "$POTENTIAL_SECRETS" -gt 0 ]; then
            echo "⚠️ Warning: Potential secrets found (unverified)"
            jq '.[] | select(.verified==false) | {file: .path, type: .detector_name}' reports/trufflehog-scan.json | head -10
        fi
        
        echo "✅ Secret scan completed"
    '''
}

def runSonarQube() {
    echo "📊 Running SonarQube analysis..."
    
    withSonarQubeEnv('SonarQube') {
        sh '''
            # Create sonar project properties if not exists
            if [ ! -f sonar-project.properties ]; then
                cat > sonar-project.properties <<EOF
sonar.projectKey=secdevops-oversight
sonar.projectName=SecDevOps Oversight MVP
sonar.projectVersion=${VERSION}
sonar.sources=src
sonar.tests=tests
sonar.exclusions=node_modules/**,coverage/**,dist/**,build/**,.next/**,**/*.spec.js,**/*.test.js
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.testExecutionReportPaths=reports/test-report.xml
sonar.sourceEncoding=UTF-8
EOF
            fi
            
            # Run SonarScanner
            sonar-scanner \
                -Dsonar.projectVersion=${VERSION} \
                -Dsonar.branch.name=${GIT_BRANCH}
        '''
    }
    
    // Wait for Quality Gate
    timeout(time: 10, unit: 'MINUTES') {
        def qg = waitForQualityGate()
        if (qg.status != 'OK') {
            unstable("SonarQube Quality Gate Status: ${qg.status}")
        }
    }
}

def runSnyk() {
    echo "🛡️ Running Snyk security scan..."
    
    sh '''
        mkdir -p reports
        
        # Authenticate Snyk
        snyk auth ${SNYK_TOKEN}
        
        # Test for vulnerabilities
        echo "Testing dependencies for vulnerabilities..."
        snyk test \
            --severity-threshold=high \
            --json-file-output=reports/snyk-vulnerabilities.json \
            || true
        
        # Test for license issues
        echo "Checking licenses..."
        snyk test \
            --license \
            --json-file-output=reports/snyk-licenses.json \
            || true
        
        # Monitor project (send to Snyk dashboard)
        snyk monitor \
            --project-name="SecDevOps-${GIT_BRANCH}" \
            --org=secdevops-org \
            || true
        
        # Parse and display results
        if [ -f reports/snyk-vulnerabilities.json ]; then
            echo "Vulnerability Summary:"
            jq '.summary' reports/snyk-vulnerabilities.json
            
            # Count critical and high vulnerabilities
            CRITICAL=$(jq '[.vulnerabilities[] | select(.severity=="critical")] | length' reports/snyk-vulnerabilities.json)
            HIGH=$(jq '[.vulnerabilities[] | select(.severity=="high")] | length' reports/snyk-vulnerabilities.json)
            
            echo "Critical vulnerabilities: $CRITICAL"
            echo "High vulnerabilities: $HIGH"
            
            if [ "$CRITICAL" -gt 0 ]; then
                echo "❌ Critical vulnerabilities found!"
                jq '.vulnerabilities[] | select(.severity=="critical") | {title, severity, packageName, version}' reports/snyk-vulnerabilities.json
                exit 1
            fi
        fi
        
        echo "✅ Snyk scan completed"
    '''
}

def runSemgrep() {
    echo "🔍 Running Semgrep SAST analysis..."
    
    sh '''
        mkdir -p reports
        
        # Run Semgrep with multiple rulesets
        docker run --rm -v $(pwd):/src \
            returntocorp/semgrep:latest \
            --config=auto \
            --config=p/security-audit \
            --config=p/owasp-top-ten \
            --json \
            --output=/src/reports/semgrep-report.json \
            /src
        
        # Parse results
        if [ -f reports/semgrep-report.json ]; then
            echo "Semgrep findings summary:"
            
            # Count by severity
            ERROR_COUNT=$(jq '[.results[] | select(.extra.severity=="ERROR")] | length' reports/semgrep-report.json)
            WARNING_COUNT=$(jq '[.results[] | select(.extra.severity=="WARNING")] | length' reports/semgrep-report.json)
            
            echo "Errors: $ERROR_COUNT"
            echo "Warnings: $WARNING_COUNT"
            
            if [ "$ERROR_COUNT" -gt 0 ]; then
                echo "⚠️ Security issues found:"
                jq '.results[] | select(.extra.severity=="ERROR") | {file: .path, line: .start.line, message: .extra.message, rule: .check_id}' reports/semgrep-report.json | head -10
            fi
        fi
        
        echo "✅ Semgrep analysis completed"
    '''
}

def runOwaspDependencyCheck() {
    echo "🔍 Running OWASP Dependency Check..."
    
    sh '''
        mkdir -p reports
        
        # Run OWASP Dependency Check
        docker run --rm \
            -v $(pwd):/src \
            -v $(pwd)/reports:/report \
            owasp/dependency-check:latest \
            --scan /src \
            --format "ALL" \
            --project "SecDevOps-Oversight" \
            --out /report \
            --suppression /src/.dependency-check-suppressions.xml \
            || true
        
        # Check for vulnerabilities
        if [ -f reports/dependency-check-report.json ]; then
            echo "OWASP Dependency Check completed"
            # Parse JSON report for summary
        fi
    '''
}

def checkSecurityHeaders() {
    echo "🔒 Checking security headers configuration..."
    
    sh '''
        # Check for security headers in configuration
        echo "Checking for security headers in application configuration..."
        
        # Look for security headers in Next.js config
        if [ -f "next.config.js" ] || [ -f "next.config.ts" ]; then
            echo "Checking Next.js security headers..."
            grep -q "securityHeaders" next.config.* || echo "⚠️ Security headers not found in Next.js config"
        fi
        
        # Check for Helmet.js in Express apps
        if [ -f "package.json" ]; then
            grep -q "helmet" package.json || echo "⚠️ Helmet.js not found in dependencies"
        fi
        
        echo "✅ Security headers check completed"
    '''
}

def runDAST(environment) {
    echo "🔒 Running DAST security testing with OWASP ZAP..."
    
    def targetUrl = getEnvironmentUrl(environment)
    
    sh """
        mkdir -p reports
        
        echo "Running OWASP ZAP scan against: ${targetUrl}"
        
        # Run OWASP ZAP baseline scan
        docker run --rm -v \$(pwd)/reports:/zap/wrk:rw \
            owasp/zap2docker-stable zap-baseline.py \
            -t ${targetUrl} \
            -r zap-report.html \
            -J zap-report.json \
            -x zap-report.xml \
            || true
        
        # Parse results
        if [ -f reports/zap-report.json ]; then
            echo "ZAP scan completed. Analyzing results..."
            
            # Count alerts by risk level
            HIGH_RISK=\$(jq '[.alerts[] | select(.risk=="High")] | length' reports/zap-report.json)
            MEDIUM_RISK=\$(jq '[.alerts[] | select(.risk=="Medium")] | length' reports/zap-report.json)
            
            echo "High risk alerts: \$HIGH_RISK"
            echo "Medium risk alerts: \$MEDIUM_RISK"
            
            if [ "\$HIGH_RISK" -gt 0 ]; then
                echo "⚠️ High risk vulnerabilities found:"
                jq '.alerts[] | select(.risk=="High") | {name, risk, confidence, description}' reports/zap-report.json
            fi
        fi
        
        echo "✅ DAST scan completed"
    """
}

def scanContainerImage(imageName) {
    echo "🐳 Scanning container image for vulnerabilities..."
    
    // Scan with Trivy
    sh """
        mkdir -p reports
        
        echo "Scanning ${imageName} with Trivy..."
        
        # Update Trivy database
        docker run --rm aquasec/trivy:latest image --download-db-only
        
        # Scan image
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:latest image \
            --severity HIGH,CRITICAL \
            --format json \
            --output reports/trivy-scan.json \
            ${imageName} || true
        
        # Generate HTML report
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
            -v \$(pwd)/reports:/reports \
            aquasec/trivy:latest image \
            --severity HIGH,CRITICAL \
            --format template \
            --template "@contrib/html.tpl" \
            --output /reports/trivy-report.html \
            ${imageName} || true
        
        # Parse results
        if [ -f reports/trivy-scan.json ]; then
            CRITICAL_COUNT=\$(jq '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' reports/trivy-scan.json)
            HIGH_COUNT=\$(jq '[.Results[].Vulnerabilities[]? | select(.Severity=="HIGH")] | length' reports/trivy-scan.json)
            
            echo "Critical vulnerabilities: \$CRITICAL_COUNT"
            echo "High vulnerabilities: \$HIGH_COUNT"
            
            if [ "\$CRITICAL_COUNT" -gt 0 ]; then
                echo "❌ Critical vulnerabilities found in container!"
                jq '.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL") | {id: .VulnerabilityID, package: .PkgName, severity: .Severity, title: .Title}' reports/trivy-scan.json
                exit 1
            fi
        fi
        
        echo "✅ Container scan completed"
    """
}

def generateSecurityReport() {
    echo "📊 Generating comprehensive security report..."
    
    sh '''
        mkdir -p reports
        
        cat > reports/security-summary.json <<EOF
{
    "buildNumber": "${BUILD_NUMBER}",
    "timestamp": "$(date -Iseconds)",
    "branch": "${GIT_BRANCH}",
    "commit": "${GIT_COMMIT_SHORT}",
    "scans": {
        "secrets": {
            "tool": "TruffleHog",
            "status": "$([ -f reports/trufflehog-scan.json ] && echo "completed" || echo "skipped")"
        },
        "sast": {
            "sonarqube": "$([ -f reports/sonar-report.json ] && echo "completed" || echo "skipped")",
            "semgrep": "$([ -f reports/semgrep-report.json ] && echo "completed" || echo "skipped")"
        },
        "sca": {
            "snyk": "$([ -f reports/snyk-vulnerabilities.json ] && echo "completed" || echo "skipped")",
            "owasp": "$([ -f reports/dependency-check-report.json ] && echo "completed" || echo "skipped")"
        },
        "container": {
            "trivy": "$([ -f reports/trivy-scan.json ] && echo "completed" || echo "skipped")"
        },
        "dast": {
            "zap": "$([ -f reports/zap-report.json ] && echo "completed" || echo "skipped")"
        }
    }
}
EOF
        
        echo "Security report generated: reports/security-summary.json"
    '''
    
    archiveArtifacts artifacts: 'reports/security-*', allowEmptyArchive: true
}

private def getEnvironmentUrl(environment) {
    switch(environment) {
        case 'dev':
            return 'https://dev.oversight.local'
        case 'test':
            return 'https://test.oversight.local'
        case 'staging':
            return 'https://staging.oversight.local'
        case 'prod':
            return 'https://app.oversight.com'
        default:
            return 'https://localhost'
    }
}