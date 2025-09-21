#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class SecurityDashboardAggregator {
    constructor() {
        this.results = {
            timestamp: new Date().toISOString(),
            project: 'Oversight MVP',
            summary: {
                totalIssues: 0,
                criticalIssues: 0,
                highIssues: 0,
                mediumIssues: 0,
                lowIssues: 0,
                passedChecks: 0,
                failedChecks: 0
            },
            tools: {}
        };
    }

    async aggregateResults() {
        console.log('Starting Security Dashboard Aggregation...');
        console.log('==========================================');

        await this.collectTruffleHogResults();
        await this.collectSnykResults();
        await this.collectTrivyResults();
        await this.collectSonarQubeResults();
        await this.collectSemgrepResults();
        await this.collectOWASPZAPResults();
        await this.collectAnchoreResults();
        await this.collectDependencyCheckResults();
        await this.collectGitLeaksResults();

        this.calculateSummary();
        this.generateReports();
        
        return this.results;
    }

    async collectTruffleHogResults() {
        console.log('\nCollecting TruffleHog results...');
        try {
            const reportPath = 'trufflehog-report.json';
            if (fs.existsSync(reportPath)) {
                const data = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
                this.results.tools.truffleHog = {
                    status: data.length === 0 ? 'PASS' : 'FAIL',
                    secretsFound: data.length,
                    details: data.slice(0, 10)
                };
                
                if (data.length > 0) {
                    this.results.summary.criticalIssues += data.length;
                }
            } else {
                this.results.tools.truffleHog = { status: 'NO_DATA', message: 'Report not found' };
            }
        } catch (error) {
            this.results.tools.truffleHog = { status: 'ERROR', error: error.message };
        }
    }

    async collectSnykResults() {
        console.log('Collecting Snyk results...');
        try {
            const reportPath = 'snyk-report.json';
            if (fs.existsSync(reportPath)) {
                const data = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
                const vulns = data.vulnerabilities || [];
                
                const critical = vulns.filter(v => v.severity === 'critical').length;
                const high = vulns.filter(v => v.severity === 'high').length;
                const medium = vulns.filter(v => v.severity === 'medium').length;
                const low = vulns.filter(v => v.severity === 'low').length;
                
                this.results.tools.snyk = {
                    status: critical > 0 || high > 0 ? 'FAIL' : 'PASS',
                    vulnerabilities: {
                        critical,
                        high,
                        medium,
                        low
                    },
                    totalVulnerabilities: vulns.length
                };
                
                this.results.summary.criticalIssues += critical;
                this.results.summary.highIssues += high;
                this.results.summary.mediumIssues += medium;
                this.results.summary.lowIssues += low;
            } else {
                this.results.tools.snyk = { status: 'NO_DATA', message: 'Report not found' };
            }
        } catch (error) {
            this.results.tools.snyk = { status: 'ERROR', error: error.message };
        }
    }

    async collectTrivyResults() {
        console.log('Collecting Trivy results...');
        try {
            const reportPath = 'trivy-report.json';
            if (fs.existsSync(reportPath)) {
                const data = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
                const results = data.Results || [];
                
                let critical = 0, high = 0, medium = 0, low = 0;
                
                results.forEach(result => {
                    if (result.Vulnerabilities) {
                        result.Vulnerabilities.forEach(vuln => {
                            switch(vuln.Severity) {
                                case 'CRITICAL': critical++; break;
                                case 'HIGH': high++; break;
                                case 'MEDIUM': medium++; break;
                                case 'LOW': low++; break;
                            }
                        });
                    }
                });
                
                this.results.tools.trivy = {
                    status: critical > 0 || high > 0 ? 'FAIL' : 'PASS',
                    vulnerabilities: {
                        critical,
                        high,
                        medium,
                        low
                    }
                };
                
                this.results.summary.criticalIssues += critical;
                this.results.summary.highIssues += high;
                this.results.summary.mediumIssues += medium;
                this.results.summary.lowIssues += low;
            } else {
                this.results.tools.trivy = { status: 'NO_DATA', message: 'Report not found' };
            }
        } catch (error) {
            this.results.tools.trivy = { status: 'ERROR', error: error.message };
        }
    }

    async collectSonarQubeResults() {
        console.log('Collecting SonarQube results...');
        try {
            const reportPath = 'sonarqube-report.json';
            if (fs.existsSync(reportPath)) {
                const data = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
                const issues = data.issues || [];
                
                const blocker = issues.filter(i => i.severity === 'BLOCKER').length;
                const critical = issues.filter(i => i.severity === 'CRITICAL').length;
                const major = issues.filter(i => i.severity === 'MAJOR').length;
                const minor = issues.filter(i => i.severity === 'MINOR').length;
                
                this.results.tools.sonarqube = {
                    status: blocker > 0 || critical > 0 ? 'FAIL' : 'PASS',
                    issues: {
                        blocker,
                        critical,
                        major,
                        minor
                    },
                    qualityGate: data.qualityGate || 'UNKNOWN',
                    coverage: data.coverage || 0
                };
                
                this.results.summary.criticalIssues += blocker + critical;
                this.results.summary.highIssues += major;
                this.results.summary.mediumIssues += minor;
            } else {
                this.results.tools.sonarqube = { status: 'NO_DATA', message: 'Report not found' };
            }
        } catch (error) {
            this.results.tools.sonarqube = { status: 'ERROR', error: error.message };
        }
    }

    async collectSemgrepResults() {
        console.log('Collecting Semgrep results...');
        try {
            const reportPath = 'semgrep-report.json';
            if (fs.existsSync(reportPath)) {
                const data = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
                const results = data.results || [];
                
                const error = results.filter(r => r.extra.severity === 'ERROR').length;
                const warning = results.filter(r => r.extra.severity === 'WARNING').length;
                const info = results.filter(r => r.extra.severity === 'INFO').length;
                
                this.results.tools.semgrep = {
                    status: error > 0 ? 'FAIL' : 'PASS',
                    findings: {
                        error,
                        warning,
                        info
                    },
                    totalFindings: results.length
                };
                
                this.results.summary.criticalIssues += error;
                this.results.summary.highIssues += warning;
                this.results.summary.lowIssues += info;
            } else {
                this.results.tools.semgrep = { status: 'NO_DATA', message: 'Report not found' };
            }
        } catch (error) {
            this.results.tools.semgrep = { status: 'ERROR', error: error.message };
        }
    }

    async collectOWASPZAPResults() {
        console.log('Collecting OWASP ZAP results...');
        try {
            const reportPath = 'zap-report.json';
            if (fs.existsSync(reportPath)) {
                const data = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
                const alerts = data.site?.[0]?.alerts || [];
                
                const high = alerts.filter(a => a.riskdesc.includes('High')).length;
                const medium = alerts.filter(a => a.riskdesc.includes('Medium')).length;
                const low = alerts.filter(a => a.riskdesc.includes('Low')).length;
                const info = alerts.filter(a => a.riskdesc.includes('Informational')).length;
                
                this.results.tools.owaspZap = {
                    status: high > 0 ? 'FAIL' : 'PASS',
                    alerts: {
                        high,
                        medium,
                        low,
                        informational: info
                    },
                    totalAlerts: alerts.length
                };
                
                this.results.summary.highIssues += high;
                this.results.summary.mediumIssues += medium;
                this.results.summary.lowIssues += low;
            } else {
                this.results.tools.owaspZap = { status: 'NO_DATA', message: 'Report not found' };
            }
        } catch (error) {
            this.results.tools.owaspZap = { status: 'ERROR', error: error.message };
        }
    }

    async collectAnchoreResults() {
        console.log('Collecting Anchore results...');
        try {
            const reportPath = 'anchore-report.json';
            if (fs.existsSync(reportPath)) {
                const data = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
                const vulns = data.vulnerabilities || [];
                
                const critical = vulns.filter(v => v.severity === 'Critical').length;
                const high = vulns.filter(v => v.severity === 'High').length;
                const medium = vulns.filter(v => v.severity === 'Medium').length;
                const low = vulns.filter(v => v.severity === 'Low').length;
                
                this.results.tools.anchore = {
                    status: critical > 0 || high > 0 ? 'FAIL' : 'PASS',
                    vulnerabilities: {
                        critical,
                        high,
                        medium,
                        low
                    },
                    policyStatus: data.policyStatus || 'UNKNOWN'
                };
                
                this.results.summary.criticalIssues += critical;
                this.results.summary.highIssues += high;
                this.results.summary.mediumIssues += medium;
                this.results.summary.lowIssues += low;
            } else {
                this.results.tools.anchore = { status: 'NO_DATA', message: 'Report not found' };
            }
        } catch (error) {
            this.results.tools.anchore = { status: 'ERROR', error: error.message };
        }
    }

    async collectDependencyCheckResults() {
        console.log('Collecting OWASP Dependency Check results...');
        try {
            const reportPath = 'dependency-check-report.json';
            if (fs.existsSync(reportPath)) {
                const data = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
                const dependencies = data.dependencies || [];
                
                let critical = 0, high = 0, medium = 0, low = 0;
                
                dependencies.forEach(dep => {
                    if (dep.vulnerabilities) {
                        dep.vulnerabilities.forEach(vuln => {
                            const cvss = vuln.cvssv3?.baseScore || vuln.cvssv2?.score || 0;
                            if (cvss >= 9.0) critical++;
                            else if (cvss >= 7.0) high++;
                            else if (cvss >= 4.0) medium++;
                            else low++;
                        });
                    }
                });
                
                this.results.tools.dependencyCheck = {
                    status: critical > 0 || high > 0 ? 'FAIL' : 'PASS',
                    vulnerabilities: {
                        critical,
                        high,
                        medium,
                        low
                    },
                    totalDependencies: dependencies.length
                };
                
                this.results.summary.criticalIssues += critical;
                this.results.summary.highIssues += high;
                this.results.summary.mediumIssues += medium;
                this.results.summary.lowIssues += low;
            } else {
                this.results.tools.dependencyCheck = { status: 'NO_DATA', message: 'Report not found' };
            }
        } catch (error) {
            this.results.tools.dependencyCheck = { status: 'ERROR', error: error.message };
        }
    }

    async collectGitLeaksResults() {
        console.log('Collecting GitLeaks results...');
        try {
            const reportPath = 'gitleaks-report.json';
            if (fs.existsSync(reportPath)) {
                const data = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
                const findings = data || [];
                
                this.results.tools.gitLeaks = {
                    status: findings.length === 0 ? 'PASS' : 'FAIL',
                    secretsFound: findings.length,
                    details: findings.slice(0, 5).map(f => ({
                        file: f.File,
                        line: f.StartLine,
                        rule: f.RuleID
                    }))
                };
                
                if (findings.length > 0) {
                    this.results.summary.criticalIssues += findings.length;
                }
            } else {
                this.results.tools.gitLeaks = { status: 'NO_DATA', message: 'Report not found' };
            }
        } catch (error) {
            this.results.tools.gitLeaks = { status: 'ERROR', error: error.message };
        }
    }

    calculateSummary() {
        console.log('\nCalculating summary...');
        
        this.results.summary.totalIssues = 
            this.results.summary.criticalIssues +
            this.results.summary.highIssues +
            this.results.summary.mediumIssues +
            this.results.summary.lowIssues;
        
        Object.values(this.results.tools).forEach(tool => {
            if (tool.status === 'PASS') {
                this.results.summary.passedChecks++;
            } else if (tool.status === 'FAIL') {
                this.results.summary.failedChecks++;
            }
        });
        
        this.results.overallStatus = 
            this.results.summary.criticalIssues > 0 ? 'CRITICAL' :
            this.results.summary.highIssues > 0 ? 'HIGH' :
            this.results.summary.mediumIssues > 0 ? 'MEDIUM' :
            this.results.summary.totalIssues > 0 ? 'LOW' : 'PASS';
    }

    generateReports() {
        console.log('\nGenerating reports...');
        
        this.generateJSONReport();
        this.generateHTMLReport();
        this.generateMarkdownReport();
        this.generatePrometheusMetrics();
    }

    generateJSONReport() {
        const filename = `security-dashboard-${Date.now()}.json`;
        fs.writeFileSync(filename, JSON.stringify(this.results, null, 2));
        console.log(`JSON report saved: ${filename}`);
    }

    generateHTMLReport() {
        const html = `
<!DOCTYPE html>
<html>
<head>
    <title>Security Dashboard - ${this.results.timestamp}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .metric { background: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #007bff; }
        .metric.critical { border-left-color: #dc3545; }
        .metric.high { border-left-color: #fd7e14; }
        .metric.medium { border-left-color: #ffc107; }
        .metric.low { border-left-color: #28a745; }
        .metric h3 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .metric .value { font-size: 24px; font-weight: bold; }
        .tools { margin: 20px 0; }
        .tool { background: #fff; border: 1px solid #ddd; border-radius: 5px; padding: 15px; margin: 10px 0; }
        .tool.pass { border-left: 5px solid #28a745; }
        .tool.fail { border-left: 5px solid #dc3545; }
        .tool.no-data { border-left: 5px solid #6c757d; }
        .status { display: inline-block; padding: 3px 8px; border-radius: 3px; color: white; font-weight: bold; font-size: 12px; }
        .status.pass { background: #28a745; }
        .status.fail { background: #dc3545; }
        .status.no-data { background: #6c757d; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Security Dashboard</h1>
        <p><strong>Project:</strong> ${this.results.project}</p>
        <p><strong>Scan Time:</strong> ${this.results.timestamp}</p>
        <p><strong>Overall Status:</strong> <span class="status ${this.results.overallStatus.toLowerCase()}">${this.results.overallStatus}</span></p>
        
        <h2>Summary</h2>
        <div class="summary">
            <div class="metric critical">
                <h3>Critical Issues</h3>
                <div class="value">${this.results.summary.criticalIssues}</div>
            </div>
            <div class="metric high">
                <h3>High Issues</h3>
                <div class="value">${this.results.summary.highIssues}</div>
            </div>
            <div class="metric medium">
                <h3>Medium Issues</h3>
                <div class="value">${this.results.summary.mediumIssues}</div>
            </div>
            <div class="metric low">
                <h3>Low Issues</h3>
                <div class="value">${this.results.summary.lowIssues}</div>
            </div>
            <div class="metric">
                <h3>Total Issues</h3>
                <div class="value">${this.results.summary.totalIssues}</div>
            </div>
            <div class="metric">
                <h3>Passed Checks</h3>
                <div class="value">${this.results.summary.passedChecks}</div>
            </div>
            <div class="metric">
                <h3>Failed Checks</h3>
                <div class="value">${this.results.summary.failedChecks}</div>
            </div>
        </div>
        
        <h2>Tool Results</h2>
        <div class="tools">
            ${Object.entries(this.results.tools).map(([name, data]) => `
                <div class="tool ${data.status.toLowerCase()}">
                    <h3>${name.replace(/([A-Z])/g, ' $1').trim()}</h3>
                    <span class="status ${data.status.toLowerCase()}">${data.status}</span>
                    <pre>${JSON.stringify(data, null, 2)}</pre>
                </div>
            `).join('')}
        </div>
        
        <div class="footer">
            Generated by SecDevOps Security Dashboard Aggregator
        </div>
    </div>
</body>
</html>`;
        
        const filename = `security-dashboard-${Date.now()}.html`;
        fs.writeFileSync(filename, html);
        console.log(`HTML report saved: ${filename}`);
    }

    generateMarkdownReport() {
        const md = `# Security Dashboard Report

**Project:** ${this.results.project}  
**Scan Time:** ${this.results.timestamp}  
**Overall Status:** ${this.results.overallStatus}

## Summary

| Severity | Count |
|----------|-------|
| Critical | ${this.results.summary.criticalIssues} |
| High | ${this.results.summary.highIssues} |
| Medium | ${this.results.summary.mediumIssues} |
| Low | ${this.results.summary.lowIssues} |
| **Total** | **${this.results.summary.totalIssues}** |

**Passed Checks:** ${this.results.summary.passedChecks}  
**Failed Checks:** ${this.results.summary.failedChecks}

## Tool Results

${Object.entries(this.results.tools).map(([name, data]) => `
### ${name.replace(/([A-Z])/g, ' $1').trim()}
- **Status:** ${data.status}
${data.status !== 'NO_DATA' && data.status !== 'ERROR' ? 
`- **Details:** ${JSON.stringify(data, null, 2)}` : 
`- **Message:** ${data.message || data.error}`}
`).join('\n')}

---
*Generated by SecDevOps Security Dashboard Aggregator*`;
        
        const filename = `security-dashboard-${Date.now()}.md`;
        fs.writeFileSync(filename, md);
        console.log(`Markdown report saved: ${filename}`);
    }

    generatePrometheusMetrics() {
        const metrics = `# HELP security_issues_total Total number of security issues
# TYPE security_issues_total gauge
security_issues_total{severity="critical"} ${this.results.summary.criticalIssues}
security_issues_total{severity="high"} ${this.results.summary.highIssues}
security_issues_total{severity="medium"} ${this.results.summary.mediumIssues}
security_issues_total{severity="low"} ${this.results.summary.lowIssues}

# HELP security_checks_total Total number of security checks
# TYPE security_checks_total gauge
security_checks_total{status="passed"} ${this.results.summary.passedChecks}
security_checks_total{status="failed"} ${this.results.summary.failedChecks}

# HELP security_tool_status Security tool execution status
# TYPE security_tool_status gauge
${Object.entries(this.results.tools).map(([name, data]) => 
`security_tool_status{tool="${name}",status="${data.status}"} ${data.status === 'PASS' ? 1 : 0}`
).join('\n')}
`;
        
        const filename = `security-metrics.prom`;
        fs.writeFileSync(filename, metrics);
        console.log(`Prometheus metrics saved: ${filename}`);
    }
}

if (require.main === module) {
    const aggregator = new SecurityDashboardAggregator();
    aggregator.aggregateResults().then(results => {
        console.log('\n==========================================');
        console.log('Security Dashboard Aggregation Complete!');
        console.log('==========================================');
        console.log(`Overall Status: ${results.overallStatus}`);
        console.log(`Total Issues: ${results.summary.totalIssues}`);
        console.log(`Critical: ${results.summary.criticalIssues}`);
        console.log(`High: ${results.summary.highIssues}`);
        console.log(`Medium: ${results.summary.mediumIssues}`);
        console.log(`Low: ${results.summary.lowIssues}`);
        
        process.exit(results.overallStatus === 'CRITICAL' || results.overallStatus === 'HIGH' ? 1 : 0);
    }).catch(error => {
        console.error('Error running aggregation:', error);
        process.exit(1);
    });
}

module.exports = SecurityDashboardAggregator;