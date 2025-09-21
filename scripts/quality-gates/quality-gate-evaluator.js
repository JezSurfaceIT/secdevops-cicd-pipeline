#!/usr/bin/env node

/**
 * Quality Gate Evaluator for SecDevOps CI/CD Pipeline
 * STORY-003-03: Implement Quality Gates
 * 
 * This script evaluates various quality metrics and enforces thresholds
 */

const fs = require('fs');
const path = require('path');

class QualityGateEvaluator {
    constructor() {
        this.thresholds = this.loadThresholds();
        this.results = {
            passed: true,
            timestamp: new Date().toISOString(),
            buildNumber: process.env.BUILD_NUMBER || 'local',
            branch: process.env.GIT_BRANCH || 'unknown',
            gates: {},
            violations: [],
            summary: {}
        };
    }

    loadThresholds() {
        const defaultThresholds = {
            security: {
                critical: 0,     // Zero tolerance for critical vulnerabilities
                high: 5,         // Maximum 5 high vulnerabilities
                medium: 20,      // Maximum 20 medium vulnerabilities
                low: 100         // Maximum 100 low vulnerabilities
            },
            coverage: {
                overall: 80,     // Minimum 80% code coverage
                newCode: 90,     // Minimum 90% coverage for new code
                branches: 75,    // Minimum 75% branch coverage
                functions: 80    // Minimum 80% function coverage
            },
            codeQuality: {
                bugs: 5,                  // Maximum 5 bugs
                vulnerabilities: 0,       // Zero code vulnerabilities
                codeSmells: 50,          // Maximum 50 code smells
                duplications: 5,         // Maximum 5% duplication
                complexity: 15,          // Maximum cyclomatic complexity
                maintainabilityIndex: 20 // Minimum maintainability index
            },
            performance: {
                buildTime: 600,          // Maximum 10 minutes build time (seconds)
                bundleSize: 5242880,     // Maximum 5MB bundle size (bytes)
                p95ResponseTime: 500,    // Maximum 500ms P95 response time
                errorRate: 1             // Maximum 1% error rate
            },
            tests: {
                passRate: 100,           // Minimum 100% test pass rate
                skipped: 5,              // Maximum 5% skipped tests
                minTests: 50             // Minimum 50 tests
            },
            dependencies: {
                outdated: 10,            // Maximum 10% outdated dependencies
                deprecated: 0,           // Zero deprecated dependencies
                unlicensed: 0            // Zero unlicensed dependencies
            }
        };

        // Load custom thresholds if exists
        const customThresholdsPath = path.join(__dirname, 'thresholds-config.json');
        if (fs.existsSync(customThresholdsPath)) {
            try {
                const customThresholds = JSON.parse(fs.readFileSync(customThresholdsPath, 'utf8'));
                return { ...defaultThresholds, ...customThresholds };
            } catch (error) {
                console.warn('Failed to load custom thresholds, using defaults:', error.message);
            }
        }

        return defaultThresholds;
    }

    async evaluateSecurityGate(reportPaths = {}) {
        console.log('🔐 Evaluating Security Gate...');
        
        const gate = {
            name: 'Security',
            passed: true,
            checks: [],
            metrics: {}
        };

        // Check Snyk report
        if (reportPaths.snyk && fs.existsSync(reportPaths.snyk)) {
            const snykResults = this.evaluateSnykReport(reportPaths.snyk);
            gate.checks.push(snykResults);
            if (!snykResults.passed) gate.passed = false;
        }

        // Check Trivy report
        if (reportPaths.trivy && fs.existsSync(reportPaths.trivy)) {
            const trivyResults = this.evaluateTrivyReport(reportPaths.trivy);
            gate.checks.push(trivyResults);
            if (!trivyResults.passed) gate.passed = false;
        }

        // Check SonarQube report
        if (reportPaths.sonar && fs.existsSync(reportPaths.sonar)) {
            const sonarResults = this.evaluateSonarReport(reportPaths.sonar);
            gate.checks.push(sonarResults);
            if (!sonarResults.passed) gate.passed = false;
        }

        // Check Semgrep report
        if (reportPaths.semgrep && fs.existsSync(reportPaths.semgrep)) {
            const semgrepResults = this.evaluateSemgrepReport(reportPaths.semgrep);
            gate.checks.push(semgrepResults);
            if (!semgrepResults.passed) gate.passed = false;
        }

        this.results.gates.security = gate;
        return gate;
    }

    evaluateSnykReport(reportPath) {
        const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
        const vulnCounts = {
            critical: 0,
            high: 0,
            medium: 0,
            low: 0
        };

        if (report.vulnerabilities) {
            report.vulnerabilities.forEach(vuln => {
                const severity = vuln.severity.toLowerCase();
                if (vulnCounts.hasOwnProperty(severity)) {
                    vulnCounts[severity]++;
                }
            });
        }

        const check = {
            tool: 'Snyk',
            passed: true,
            vulnerabilities: vulnCounts,
            violations: []
        };

        // Check against thresholds
        Object.keys(vulnCounts).forEach(severity => {
            if (vulnCounts[severity] > this.thresholds.security[severity]) {
                check.passed = false;
                check.violations.push({
                    type: 'security',
                    severity,
                    count: vulnCounts[severity],
                    threshold: this.thresholds.security[severity],
                    message: `Found ${vulnCounts[severity]} ${severity} vulnerabilities (threshold: ${this.thresholds.security[severity]})`
                });
                this.results.violations.push(check.violations[check.violations.length - 1]);
            }
        });

        return check;
    }

    evaluateTrivyReport(reportPath) {
        const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
        const vulnCounts = {
            CRITICAL: 0,
            HIGH: 0,
            MEDIUM: 0,
            LOW: 0
        };

        if (report.Results) {
            report.Results.forEach(result => {
                if (result.Vulnerabilities) {
                    result.Vulnerabilities.forEach(vuln => {
                        if (vulnCounts.hasOwnProperty(vuln.Severity)) {
                            vulnCounts[vuln.Severity]++;
                        }
                    });
                }
            });
        }

        const check = {
            tool: 'Trivy',
            passed: true,
            vulnerabilities: vulnCounts,
            violations: []
        };

        // Map Trivy severities to our thresholds
        const severityMap = {
            'CRITICAL': 'critical',
            'HIGH': 'high',
            'MEDIUM': 'medium',
            'LOW': 'low'
        };

        Object.keys(vulnCounts).forEach(severity => {
            const mappedSeverity = severityMap[severity];
            if (vulnCounts[severity] > this.thresholds.security[mappedSeverity]) {
                check.passed = false;
                check.violations.push({
                    type: 'container-security',
                    severity: mappedSeverity,
                    count: vulnCounts[severity],
                    threshold: this.thresholds.security[mappedSeverity],
                    message: `Container has ${vulnCounts[severity]} ${mappedSeverity} vulnerabilities (threshold: ${this.thresholds.security[mappedSeverity]})`
                });
                this.results.violations.push(check.violations[check.violations.length - 1]);
            }
        });

        return check;
    }

    evaluateSonarReport(reportPath) {
        const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
        
        const check = {
            tool: 'SonarQube',
            passed: true,
            metrics: {},
            violations: []
        };

        if (report.metrics) {
            // Check code quality metrics
            const metrics = report.metrics;
            
            if (metrics.bugs > this.thresholds.codeQuality.bugs) {
                check.passed = false;
                check.violations.push({
                    type: 'code-quality',
                    metric: 'bugs',
                    value: metrics.bugs,
                    threshold: this.thresholds.codeQuality.bugs,
                    message: `Found ${metrics.bugs} bugs (threshold: ${this.thresholds.codeQuality.bugs})`
                });
            }

            if (metrics.vulnerabilities > this.thresholds.codeQuality.vulnerabilities) {
                check.passed = false;
                check.violations.push({
                    type: 'code-quality',
                    metric: 'vulnerabilities',
                    value: metrics.vulnerabilities,
                    threshold: this.thresholds.codeQuality.vulnerabilities,
                    message: `Found ${metrics.vulnerabilities} code vulnerabilities (threshold: ${this.thresholds.codeQuality.vulnerabilities})`
                });
            }

            check.metrics = metrics;
        }

        return check;
    }

    evaluateSemgrepReport(reportPath) {
        const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
        
        const check = {
            tool: 'Semgrep',
            passed: true,
            findings: 0,
            violations: []
        };

        if (report.results) {
            const errorFindings = report.results.filter(r => r.extra && r.extra.severity === 'ERROR');
            
            if (errorFindings.length > 0) {
                check.passed = false;
                check.findings = errorFindings.length;
                check.violations.push({
                    type: 'sast',
                    severity: 'error',
                    count: errorFindings.length,
                    message: `Semgrep found ${errorFindings.length} security issues`
                });
            }
        }

        return check;
    }

    async evaluateCoverageGate(coverageReport) {
        console.log('📊 Evaluating Coverage Gate...');
        
        const gate = {
            name: 'Coverage',
            passed: true,
            metrics: {},
            violations: []
        };

        if (!fs.existsSync(coverageReport)) {
            gate.passed = false;
            gate.violations.push({
                type: 'coverage',
                message: 'Coverage report not found'
            });
            this.results.gates.coverage = gate;
            return gate;
        }

        const coverage = JSON.parse(fs.readFileSync(coverageReport, 'utf8'));
        
        if (coverage.total) {
            gate.metrics = {
                lines: coverage.total.lines.pct,
                branches: coverage.total.branches.pct,
                functions: coverage.total.functions.pct,
                statements: coverage.total.statements.pct
            };

            // Check overall coverage
            if (gate.metrics.lines < this.thresholds.coverage.overall) {
                gate.passed = false;
                gate.violations.push({
                    type: 'coverage',
                    metric: 'overall',
                    value: gate.metrics.lines,
                    threshold: this.thresholds.coverage.overall,
                    message: `Line coverage is ${gate.metrics.lines}% (threshold: ${this.thresholds.coverage.overall}%)`
                });
                this.results.violations.push(gate.violations[gate.violations.length - 1]);
            }

            // Check branch coverage
            if (gate.metrics.branches < this.thresholds.coverage.branches) {
                gate.passed = false;
                gate.violations.push({
                    type: 'coverage',
                    metric: 'branches',
                    value: gate.metrics.branches,
                    threshold: this.thresholds.coverage.branches,
                    message: `Branch coverage is ${gate.metrics.branches}% (threshold: ${this.thresholds.coverage.branches}%)`
                });
            }

            // Check function coverage
            if (gate.metrics.functions < this.thresholds.coverage.functions) {
                gate.passed = false;
                gate.violations.push({
                    type: 'coverage',
                    metric: 'functions',
                    value: gate.metrics.functions,
                    threshold: this.thresholds.coverage.functions,
                    message: `Function coverage is ${gate.metrics.functions}% (threshold: ${this.thresholds.coverage.functions}%)`
                });
            }
        }

        this.results.gates.coverage = gate;
        return gate;
    }

    async evaluateTestGate(testReport) {
        console.log('🧪 Evaluating Test Gate...');
        
        const gate = {
            name: 'Tests',
            passed: true,
            metrics: {},
            violations: []
        };

        if (!fs.existsSync(testReport)) {
            gate.passed = false;
            gate.violations.push({
                type: 'tests',
                message: 'Test report not found'
            });
            this.results.gates.tests = gate;
            return gate;
        }

        const report = JSON.parse(fs.readFileSync(testReport, 'utf8'));
        
        if (report.stats) {
            const passRate = (report.stats.passes / report.stats.tests) * 100;
            const skipRate = (report.stats.pending / report.stats.tests) * 100;
            
            gate.metrics = {
                total: report.stats.tests,
                passed: report.stats.passes,
                failed: report.stats.failures,
                skipped: report.stats.pending,
                passRate: passRate,
                skipRate: skipRate,
                duration: report.stats.duration
            };

            // Check pass rate
            if (passRate < this.thresholds.tests.passRate) {
                gate.passed = false;
                gate.violations.push({
                    type: 'tests',
                    metric: 'passRate',
                    value: passRate,
                    threshold: this.thresholds.tests.passRate,
                    message: `Test pass rate is ${passRate.toFixed(2)}% (threshold: ${this.thresholds.tests.passRate}%)`
                });
                this.results.violations.push(gate.violations[gate.violations.length - 1]);
            }

            // Check minimum tests
            if (report.stats.tests < this.thresholds.tests.minTests) {
                gate.passed = false;
                gate.violations.push({
                    type: 'tests',
                    metric: 'minTests',
                    value: report.stats.tests,
                    threshold: this.thresholds.tests.minTests,
                    message: `Only ${report.stats.tests} tests found (minimum: ${this.thresholds.tests.minTests})`
                });
            }
        }

        this.results.gates.tests = gate;
        return gate;
    }

    async evaluatePerformanceGate(perfReport) {
        console.log('⚡ Evaluating Performance Gate...');
        
        const gate = {
            name: 'Performance',
            passed: true,
            metrics: {},
            violations: []
        };

        // Check build time
        const buildDuration = process.env.BUILD_DURATION || 0;
        if (buildDuration > this.thresholds.performance.buildTime) {
            gate.passed = false;
            gate.violations.push({
                type: 'performance',
                metric: 'buildTime',
                value: buildDuration,
                threshold: this.thresholds.performance.buildTime,
                message: `Build took ${buildDuration}s (threshold: ${this.thresholds.performance.buildTime}s)`
            });
        }

        if (perfReport && fs.existsSync(perfReport)) {
            const report = JSON.parse(fs.readFileSync(perfReport, 'utf8'));
            
            gate.metrics = report.metrics || {};
            
            // Check response time
            if (report.p95 && report.p95 > this.thresholds.performance.p95ResponseTime) {
                gate.passed = false;
                gate.violations.push({
                    type: 'performance',
                    metric: 'p95ResponseTime',
                    value: report.p95,
                    threshold: this.thresholds.performance.p95ResponseTime,
                    message: `P95 response time is ${report.p95}ms (threshold: ${this.thresholds.performance.p95ResponseTime}ms)`
                });
            }

            // Check error rate
            if (report.errorRate && report.errorRate > this.thresholds.performance.errorRate) {
                gate.passed = false;
                gate.violations.push({
                    type: 'performance',
                    metric: 'errorRate',
                    value: report.errorRate,
                    threshold: this.thresholds.performance.errorRate,
                    message: `Error rate is ${report.errorRate}% (threshold: ${this.thresholds.performance.errorRate}%)`
                });
            }
        }

        this.results.gates.performance = gate;
        return gate;
    }

    async evaluateAll(reportPaths) {
        console.log('🎯 Starting Quality Gate Evaluation...');
        console.log('═'.repeat(50));

        // Security gate
        await this.evaluateSecurityGate(reportPaths);

        // Coverage gate
        if (reportPaths.coverage) {
            await this.evaluateCoverageGate(reportPaths.coverage);
        }

        // Test gate
        if (reportPaths.tests) {
            await this.evaluateTestGate(reportPaths.tests);
        }

        // Performance gate
        if (reportPaths.performance) {
            await this.evaluatePerformanceGate(reportPaths.performance);
        }

        // Determine overall pass/fail
        this.results.passed = Object.values(this.results.gates).every(gate => gate.passed);

        // Generate and save report
        this.generateReport();

        return this.results;
    }

    generateReport() {
        // Save JSON report
        const reportPath = path.join('reports', 'quality-gate-report.json');
        fs.mkdirSync(path.dirname(reportPath), { recursive: true });
        fs.writeFileSync(reportPath, JSON.stringify(this.results, null, 2));

        // Console output
        console.log('\n' + '═'.repeat(50));
        console.log('📊 QUALITY GATE EVALUATION RESULTS');
        console.log('═'.repeat(50));
        console.log(`Build: ${this.results.buildNumber}`);
        console.log(`Branch: ${this.results.branch}`);
        console.log(`Overall Status: ${this.results.passed ? '✅ PASSED' : '❌ FAILED'}`);
        console.log('─'.repeat(50));

        // Display gate results
        Object.entries(this.results.gates).forEach(([gateName, gate]) => {
            console.log(`\n${gate.name}: ${gate.passed ? '✅' : '❌'}`);
            
            if (gate.violations && gate.violations.length > 0) {
                gate.violations.forEach(violation => {
                    console.log(`  ⚠️  ${violation.message}`);
                });
            }
            
            if (gate.metrics && Object.keys(gate.metrics).length > 0) {
                console.log('  Metrics:', JSON.stringify(gate.metrics, null, 2).split('\n').join('\n  '));
            }
        });

        // Display all violations
        if (this.results.violations.length > 0) {
            console.log('\n' + '─'.repeat(50));
            console.log('❌ VIOLATIONS SUMMARY:');
            this.results.violations.forEach((violation, index) => {
                console.log(`${index + 1}. ${violation.message}`);
            });
        }

        console.log('\n' + '═'.repeat(50));
        console.log(`Report saved to: reports/quality-gate-report.json`);
        console.log('═'.repeat(50));

        // Generate HTML report
        this.generateHtmlReport();
    }

    generateHtmlReport() {
        const htmlContent = `
<!DOCTYPE html>
<html>
<head>
    <title>Quality Gate Report - Build ${this.results.buildNumber}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: ${this.results.passed ? '#4CAF50' : '#f44336'}; color: white; padding: 20px; border-radius: 5px; }
        .gate { background: white; margin: 10px 0; padding: 15px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .gate-passed { border-left: 5px solid #4CAF50; }
        .gate-failed { border-left: 5px solid #f44336; }
        .violation { color: #f44336; margin: 5px 0; }
        .metric { color: #666; margin: 5px 0; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Quality Gate Report</h1>
        <p>Build: ${this.results.buildNumber} | Branch: ${this.results.branch}</p>
        <h2>Status: ${this.results.passed ? '✅ PASSED' : '❌ FAILED'}</h2>
    </div>
    
    ${Object.entries(this.results.gates).map(([name, gate]) => `
        <div class="gate ${gate.passed ? 'gate-passed' : 'gate-failed'}">
            <h3>${gate.name}: ${gate.passed ? '✅' : '❌'}</h3>
            ${gate.violations && gate.violations.length > 0 ? `
                <div class="violations">
                    ${gate.violations.map(v => `<div class="violation">⚠️ ${v.message}</div>`).join('')}
                </div>
            ` : ''}
            ${gate.metrics && Object.keys(gate.metrics).length > 0 ? `
                <table>
                    ${Object.entries(gate.metrics).map(([key, value]) => `
                        <tr><td>${key}</td><td>${value}</td></tr>
                    `).join('')}
                </table>
            ` : ''}
        </div>
    `).join('')}
    
    <div style="margin-top: 20px; color: #666;">
        Generated: ${this.results.timestamp}
    </div>
</body>
</html>
        `;

        fs.writeFileSync(path.join('reports', 'quality-gate-report.html'), htmlContent);
    }

    checkOverride() {
        const override = process.env.OVERRIDE_QUALITY_GATES === 'true';
        if (override) {
            console.log('⚠️  WARNING: Quality gates override is enabled!');
            this.results.overridden = true;
        }
        return override;
    }
}

// Main execution
if (require.main === module) {
    const evaluator = new QualityGateEvaluator();
    
    // Parse command line arguments or use defaults
    const reportPaths = {
        snyk: process.env.SNYK_REPORT || 'reports/snyk-vulnerabilities.json',
        trivy: process.env.TRIVY_REPORT || 'reports/trivy-scan.json',
        sonar: process.env.SONAR_REPORT || 'reports/sonar-report.json',
        semgrep: process.env.SEMGREP_REPORT || 'reports/semgrep-report.json',
        coverage: process.env.COVERAGE_REPORT || 'coverage/coverage-final.json',
        tests: process.env.TEST_REPORT || 'reports/test-report.json',
        performance: process.env.PERF_REPORT || 'reports/performance-report.json'
    };

    evaluator.evaluateAll(reportPaths).then(results => {
        if (!results.passed && !evaluator.checkOverride()) {
            process.exit(1);
        }
    }).catch(error => {
        console.error('❌ Quality gate evaluation failed:', error);
        process.exit(1);
    });
}

module.exports = QualityGateEvaluator;