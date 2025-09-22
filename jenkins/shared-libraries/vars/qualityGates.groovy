#!/usr/bin/env groovy

def evaluateQualityGates(Map config = [:]) {
    def projectKey = config.projectKey ?: env.JOB_NAME
    def sonarQubeUrl = config.sonarQubeUrl ?: 'http://sonarqube:9000'
    def failOnQualityGate = config.failOnQualityGate ?: true
    def waitTime = config.waitTime ?: 300
    
    echo "Evaluating quality gates for project: ${projectKey}"
    
    def qualityGateStatus = checkSonarQubeQualityGate(
        projectKey: projectKey,
        sonarQubeUrl: sonarQubeUrl,
        waitTime: waitTime
    )
    
    def metricsStatus = checkMetricsThresholds(config)
    
    def overallStatus = qualityGateStatus && metricsStatus
    
    if (!overallStatus && failOnQualityGate) {
        error "Quality gates failed! Check the quality report for details."
    }
    
    return overallStatus
}

def checkSonarQubeQualityGate(Map config) {
    def projectKey = config.projectKey
    def sonarQubeUrl = config.sonarQubeUrl
    def waitTime = config.waitTime ?: 300
    
    echo "Checking SonarQube quality gate..."
    
    timeout(time: waitTime, unit: 'SECONDS') {
        def qualityGate = waitForQualityGate()
        
        if (qualityGate.status != 'OK') {
            echo "Quality gate status: ${qualityGate.status}"
            
            def report = getSonarQubeReport(projectKey, sonarQubeUrl)
            printQualityReport(report)
            
            return false
        }
    }
    
    echo "SonarQube quality gate passed!"
    return true
}

def checkMetricsThresholds(Map config) {
    def thresholds = config.thresholds ?: getDefaultThresholds()
    def metrics = collectMetrics(config)
    
    echo "Checking metrics against thresholds..."
    
    def failures = []
    
    thresholds.each { metric, threshold ->
        def value = metrics[metric]
        
        if (value != null) {
            if (!evaluateThreshold(value, threshold)) {
                failures.add("${metric}: ${value} (threshold: ${threshold})")
            }
        }
    }
    
    if (failures) {
        echo "Metrics that failed thresholds:"
        failures.each { echo "  - ${it}" }
        return false
    }
    
    echo "All metrics passed thresholds!"
    return true
}

def collectMetrics(Map config) {
    def metrics = [:]
    
    metrics.putAll(collectCodeMetrics())
    metrics.putAll(collectTestMetrics())
    metrics.putAll(collectSecurityMetrics())
    metrics.putAll(collectPerformanceMetrics())
    
    return metrics
}

def collectCodeMetrics() {
    def metrics = [:]
    
    if (fileExists('sonar-project.properties')) {
        def sonarMetrics = sh(
            script: """
                curl -s http://sonarqube:9000/api/measures/component \
                    -G --data-urlencode "component=${env.JOB_NAME}" \
                    --data-urlencode "metricKeys=coverage,code_smells,bugs,vulnerabilities,duplicated_lines_density,complexity" \
                    | jq -r '.component.measures[] | "\\(.metric)=\\(.value)"'
            """,
            returnStdout: true
        ).trim()
        
        sonarMetrics.split('\n').each { line ->
            def parts = line.split('=')
            if (parts.size() == 2) {
                metrics[parts[0]] = parts[1] as Double
            }
        }
    }
    
    return metrics
}

def collectTestMetrics() {
    def metrics = [:]
    
    if (fileExists('test-results.xml')) {
        def testResults = readFile('test-results.xml')
        def xml = new XmlSlurper().parseText(testResults)
        
        metrics['test_pass_rate'] = (xml.@tests.toInteger() - xml.@failures.toInteger()) / xml.@tests.toInteger() * 100
        metrics['test_count'] = xml.@tests.toInteger()
        metrics['test_failures'] = xml.@failures.toInteger()
    }
    
    if (fileExists('coverage/cobertura-coverage.xml')) {
        def coverage = sh(
            script: "grep 'line-rate' coverage/cobertura-coverage.xml | head -1 | grep -oP 'line-rate=\"\\K[0-9.]+'",
            returnStdout: true
        ).trim() as Double
        
        metrics['coverage'] = coverage * 100
    }
    
    return metrics
}

def collectSecurityMetrics() {
    def metrics = [:]
    
    def securityReport = "${env.WORKSPACE}/security-dashboard-*.json"
    def latestReport = sh(
        script: "ls -t ${securityReport} 2>/dev/null | head -1",
        returnStdout: true
    ).trim()
    
    if (latestReport) {
        def report = readJSON file: latestReport
        metrics['critical_vulnerabilities'] = report.summary.criticalIssues
        metrics['high_vulnerabilities'] = report.summary.highIssues
        metrics['security_score'] = calculateSecurityScore(report)
    }
    
    return metrics
}

def collectPerformanceMetrics() {
    def metrics = [:]
    
    if (fileExists('performance-report.json')) {
        def report = readJSON file: 'performance-report.json'
        metrics['response_time_p95'] = report.metrics?.p95 ?: 0
        metrics['throughput'] = report.metrics?.throughput ?: 0
        metrics['error_rate'] = report.metrics?.errorRate ?: 0
    }
    
    return metrics
}

def getDefaultThresholds() {
    return [
        coverage: '>= 80',
        test_pass_rate: '>= 95',
        code_smells: '<= 10',
        bugs: '== 0',
        critical_vulnerabilities: '== 0',
        high_vulnerabilities: '<= 5',
        duplicated_lines_density: '<= 5',
        complexity: '<= 20',
        response_time_p95: '<= 1000',
        error_rate: '<= 1'
    ]
}

def evaluateThreshold(value, threshold) {
    def parts = threshold.split(' ')
    if (parts.size() != 2) {
        echo "Invalid threshold format: ${threshold}"
        return true
    }
    
    def operator = parts[0]
    def targetValue = parts[1] as Double
    def actualValue = value as Double
    
    switch(operator) {
        case '==':
            return actualValue == targetValue
        case '!=':
            return actualValue != targetValue
        case '>':
            return actualValue > targetValue
        case '>=':
            return actualValue >= targetValue
        case '<':
            return actualValue < targetValue
        case '<=':
            return actualValue <= targetValue
        default:
            echo "Unknown operator: ${operator}"
            return true
    }
}

def getSonarQubeReport(String projectKey, String sonarQubeUrl) {
    def report = [:]
    
    try {
        def measuresJson = sh(
            script: """
                curl -s ${sonarQubeUrl}/api/measures/component \
                    -G --data-urlencode "component=${projectKey}" \
                    --data-urlencode "metricKeys=alert_status,coverage,bugs,vulnerabilities,code_smells,duplicated_lines_density,security_rating,reliability_rating,maintainability_rating"
            """,
            returnStdout: true
        ).trim()
        
        def measures = readJSON(text: measuresJson)
        
        measures.component.measures.each { measure ->
            report[measure.metric] = measure.value
        }
    } catch (Exception e) {
        echo "Failed to get SonarQube report: ${e.message}"
    }
    
    return report
}

def printQualityReport(Map report) {
    echo """
    ╔════════════════════════════════════════════╗
    ║          QUALITY GATE REPORT               ║
    ╠════════════════════════════════════════════╣
    ║ Coverage:              ${report.coverage ?: 'N/A'}%
    ║ Bugs:                  ${report.bugs ?: '0'}
    ║ Vulnerabilities:       ${report.vulnerabilities ?: '0'}
    ║ Code Smells:           ${report.code_smells ?: '0'}
    ║ Duplicated Lines:      ${report.duplicated_lines_density ?: '0'}%
    ║ Security Rating:       ${report.security_rating ?: 'N/A'}
    ║ Reliability Rating:    ${report.reliability_rating ?: 'N/A'}
    ║ Maintainability Rating: ${report.maintainability_rating ?: 'N/A'}
    ╚════════════════════════════════════════════╝
    """
}

def calculateSecurityScore(report) {
    def score = 100
    
    score -= report.summary.criticalIssues * 10
    score -= report.summary.highIssues * 5
    score -= report.summary.mediumIssues * 2
    score -= report.summary.lowIssues * 0.5
    
    return Math.max(0, score)
}

def enforceGates(Map config = [:]) {
    def gates = config.gates ?: getDefaultGates()
    def continueOnFailure = config.continueOnFailure ?: false
    
    def results = [:]
    def failures = []
    
    gates.each { gateName, gateConfig ->
        echo "Evaluating gate: ${gateName}"
        
        def passed = evaluateGate(gateName, gateConfig)
        results[gateName] = passed
        
        if (!passed) {
            failures.add(gateName)
            
            if (!continueOnFailure && gateConfig.mandatory != false) {
                error "Mandatory gate '${gateName}' failed!"
            }
        }
    }
    
    if (failures) {
        echo "Failed gates: ${failures.join(', ')}"
        
        if (!continueOnFailure) {
            error "Quality gates failed!"
        }
    } else {
        echo "All quality gates passed!"
    }
    
    return results
}

def evaluateGate(String gateName, Map gateConfig) {
    switch(gateName) {
        case 'coverage':
            return evaluateCoverageGate(gateConfig)
        case 'security':
            return evaluateSecurityGate(gateConfig)
        case 'tests':
            return evaluateTestGate(gateConfig)
        case 'performance':
            return evaluatePerformanceGate(gateConfig)
        case 'code_quality':
            return evaluateCodeQualityGate(gateConfig)
        default:
            echo "Unknown gate: ${gateName}"
            return true
    }
}

def evaluateCoverageGate(Map config) {
    def threshold = config.threshold ?: 80
    def coverage = getCurrentCoverage()
    
    echo "Coverage: ${coverage}% (threshold: ${threshold}%)"
    return coverage >= threshold
}

def evaluateSecurityGate(Map config) {
    def maxCritical = config.maxCritical ?: 0
    def maxHigh = config.maxHigh ?: 5
    
    def securityMetrics = collectSecurityMetrics()
    
    def critical = securityMetrics.critical_vulnerabilities ?: 0
    def high = securityMetrics.high_vulnerabilities ?: 0
    
    echo "Security: Critical=${critical} (max: ${maxCritical}), High=${high} (max: ${maxHigh})"
    
    return critical <= maxCritical && high <= maxHigh
}

def evaluateTestGate(Map config) {
    def minPassRate = config.minPassRate ?: 95
    def metrics = collectTestMetrics()
    
    def passRate = metrics.test_pass_rate ?: 0
    
    echo "Test pass rate: ${passRate}% (minimum: ${minPassRate}%)"
    return passRate >= minPassRate
}

def evaluatePerformanceGate(Map config) {
    def maxResponseTime = config.maxResponseTime ?: 1000
    def maxErrorRate = config.maxErrorRate ?: 1
    
    def metrics = collectPerformanceMetrics()
    
    def responseTime = metrics.response_time_p95 ?: 0
    def errorRate = metrics.error_rate ?: 0
    
    echo "Performance: Response time=${responseTime}ms (max: ${maxResponseTime}ms), Error rate=${errorRate}% (max: ${maxErrorRate}%)"
    
    return responseTime <= maxResponseTime && errorRate <= maxErrorRate
}

def evaluateCodeQualityGate(Map config) {
    def maxComplexity = config.maxComplexity ?: 20
    def maxDuplication = config.maxDuplication ?: 5
    
    def metrics = collectCodeMetrics()
    
    def complexity = metrics.complexity ?: 0
    def duplication = metrics.duplicated_lines_density ?: 0
    
    echo "Code quality: Complexity=${complexity} (max: ${maxComplexity}), Duplication=${duplication}% (max: ${maxDuplication}%)"
    
    return complexity <= maxComplexity && duplication <= maxDuplication
}

def getCurrentCoverage() {
    if (fileExists('coverage.txt')) {
        return sh(
            script: "grep -oP 'Total coverage: \\K[0-9.]+' coverage.txt || echo 0",
            returnStdout: true
        ).trim() as Double
    }
    return 0
}

def getDefaultGates() {
    return [
        coverage: [
            threshold: 80,
            mandatory: true
        ],
        security: [
            maxCritical: 0,
            maxHigh: 5,
            mandatory: true
        ],
        tests: [
            minPassRate: 95,
            mandatory: true
        ],
        performance: [
            maxResponseTime: 1000,
            maxErrorRate: 1,
            mandatory: false
        ],
        code_quality: [
            maxComplexity: 20,
            maxDuplication: 5,
            mandatory: false
        ]
    ]
}

def generateQualityReport(Map config = [:]) {
    def format = config.format ?: 'html'
    def outputFile = config.outputFile ?: 'quality-report.html'
    
    def metrics = collectMetrics(config)
    def gates = enforceGates(config + [continueOnFailure: true])
    
    switch(format) {
        case 'html':
            generateHTMLReport(metrics, gates, outputFile)
            break
        case 'json':
            generateJSONReport(metrics, gates, outputFile)
            break
        case 'markdown':
            generateMarkdownReport(metrics, gates, outputFile)
            break
        default:
            error "Unsupported report format: ${format}"
    }
    
    echo "Quality report generated: ${outputFile}"
    return outputFile
}

def generateHTMLReport(Map metrics, Map gates, String outputFile) {
    def html = """
<!DOCTYPE html>
<html>
<head>
    <title>Quality Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .metric { margin: 10px 0; padding: 10px; border-left: 3px solid #007bff; background: #f8f9fa; }
        .pass { border-left-color: #28a745; }
        .fail { border-left-color: #dc3545; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border: 1px solid #ddd; }
        th { background: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Quality Report</h1>
    <h2>Quality Gates</h2>
    ${gates.collect { gate, passed ->
        "<div class='metric ${passed ? 'pass' : 'fail'}'>${gate}: ${passed ? 'PASSED' : 'FAILED'}</div>"
    }.join('\n')}
    
    <h2>Metrics</h2>
    <table>
        <tr><th>Metric</th><th>Value</th></tr>
        ${metrics.collect { metric, value ->
            "<tr><td>${metric}</td><td>${value}</td></tr>"
        }.join('\n')}
    </table>
</body>
</html>
"""
    
    writeFile file: outputFile, text: html
}

def generateJSONReport(Map metrics, Map gates, String outputFile) {
    def report = [
        timestamp: new Date().toISOString(),
        gates: gates,
        metrics: metrics
    ]
    
    writeJSON file: outputFile, json: report, pretty: 4
}

def generateMarkdownReport(Map metrics, Map gates, String outputFile) {
    def markdown = """
# Quality Report

## Quality Gates

${gates.collect { gate, passed ->
    "- **${gate}**: ${passed ? '✅ PASSED' : '❌ FAILED'}"
}.join('\n')}

## Metrics

| Metric | Value |
|--------|-------|
${metrics.collect { metric, value ->
    "| ${metric} | ${value} |"
}.join('\n')}

---
*Generated: ${new Date()}*
"""
    
    writeFile file: outputFile, text: markdown
}

return this