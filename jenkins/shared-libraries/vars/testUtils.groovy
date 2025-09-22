#!/usr/bin/env groovy

def runUnitTests(Map config = [:]) {
    def framework = config.framework ?: detectTestFramework()
    def coverage = config.coverage ?: true
    def parallel = config.parallel ?: false
    def reportDir = config.reportDir ?: 'test-reports'
    
    echo "Running unit tests with ${framework}..."
    
    switch(framework) {
        case 'jest':
            runJestTests(config)
            break
        case 'pytest':
            runPytestTests(config)
            break
        case 'junit':
            runJUnitTests(config)
            break
        case 'mocha':
            runMochaTests(config)
            break
        case 'go':
            runGoTests(config)
            break
        case 'dotnet':
            runDotNetTests(config)
            break
        default:
            error "Unsupported test framework: ${framework}"
    }
    
    if (coverage) {
        publishCoverageReport(reportDir)
    }
}

def runIntegrationTests(Map config = [:]) {
    def environment = config.environment ?: 'test'
    def suite = config.suite ?: 'integration'
    def timeout = config.timeout ?: 30
    
    echo "Running integration tests in ${environment} environment..."
    
    withEnv([
        "TEST_ENV=${environment}",
        "TEST_SUITE=${suite}",
        "TEST_TIMEOUT=${timeout}"
    ]) {
        sh """
            # Setup test database
            docker-compose -f docker-compose.test.yml up -d db
            sleep 10
            
            # Run migrations
            npm run migrate:test
            
            # Run integration tests
            npm run test:integration -- --timeout ${timeout}000
            
            # Cleanup
            docker-compose -f docker-compose.test.yml down
        """
    }
}

def runE2ETests(Map config = [:]) {
    def browser = config.browser ?: 'chrome'
    def headless = config.headless ?: true
    def baseUrl = config.baseUrl
    def parallel = config.parallel ?: false
    
    if (!baseUrl) {
        error "Base URL is required for E2E tests"
    }
    
    echo "Running E2E tests against ${baseUrl}..."
    
    sh """
        # Install browser drivers
        npm install -g selenium-standalone
        selenium-standalone install
        
        # Start Selenium server
        selenium-standalone start &
        SELENIUM_PID=\$!
        sleep 5
        
        # Run E2E tests
        npm run test:e2e -- \
            --baseUrl ${baseUrl} \
            --browser ${browser} \
            ${headless ? '--headless' : ''} \
            ${parallel ? '--parallel' : ''}
        
        # Stop Selenium server
        kill \$SELENIUM_PID
    """
}

def runPerformanceTests(Map config = [:]) {
    def tool = config.tool ?: 'jmeter'
    def testPlan = config.testPlan
    def users = config.users ?: 10
    def duration = config.duration ?: 60
    def targetUrl = config.targetUrl
    
    if (!targetUrl) {
        error "Target URL is required for performance tests"
    }
    
    echo "Running performance tests against ${targetUrl}..."
    
    switch(tool) {
        case 'jmeter':
            runJMeterTests(config)
            break
        case 'k6':
            runK6Tests(config)
            break
        case 'gatling':
            runGatlingTests(config)
            break
        default:
            error "Unsupported performance testing tool: ${tool}"
    }
}

def runSecurityTests(Map config = [:]) {
    def targetUrl = config.targetUrl
    def scanType = config.scanType ?: 'baseline'
    
    if (!targetUrl) {
        error "Target URL is required for security tests"
    }
    
    echo "Running security tests against ${targetUrl}..."
    
    sh """
        # Run OWASP ZAP scan
        docker run -v \$(pwd):/zap/wrk/:rw \
            -t owasp/zap2docker-stable \
            zap-${scanType}-scan.py \
            -t ${targetUrl} \
            -r zap-report.html \
            -J zap-report.json
    """
    
    publishHTML(target: [
        allowMissing: false,
        alwaysLinkToLastBuild: true,
        keepAll: true,
        reportDir: '.',
        reportFiles: 'zap-report.html',
        reportName: 'OWASP ZAP Report'
    ])
}

def runContractTests(Map config = [:]) {
    def provider = config.provider
    def consumer = config.consumer
    def pactBrokerUrl = config.pactBrokerUrl ?: 'http://pact-broker:9292'
    
    echo "Running contract tests..."
    
    if (provider) {
        sh """
            npm run test:contract:provider -- \
                --provider "${provider}" \
                --pact-broker-url ${pactBrokerUrl}
        """
    }
    
    if (consumer) {
        sh """
            npm run test:contract:consumer -- \
                --consumer "${consumer}" \
                --pact-broker-url ${pactBrokerUrl}
        """
    }
}

def runJestTests(Map config) {
    def coverage = config.coverage ?: true
    def watchMode = config.watchMode ?: false
    def updateSnapshot = config.updateSnapshot ?: false
    
    sh """
        npm test -- \
            ${coverage ? '--coverage' : ''} \
            ${watchMode ? '--watch' : ''} \
            ${updateSnapshot ? '--updateSnapshot' : ''} \
            --reporters=default --reporters=jest-junit \
            --testResultsProcessor=jest-junit
    """
    
    junit 'junit.xml'
    
    if (coverage) {
        publishHTML(target: [
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'coverage/lcov-report',
            reportFiles: 'index.html',
            reportName: 'Code Coverage Report'
        ])
    }
}

def runPytestTests(Map config) {
    def coverage = config.coverage ?: true
    def parallel = config.parallel ?: false
    
    sh """
        pytest \
            ${coverage ? '--cov=. --cov-report=html --cov-report=xml' : ''} \
            ${parallel ? '-n auto' : ''} \
            --junitxml=junit.xml \
            --html=report.html \
            --self-contained-html
    """
    
    junit 'junit.xml'
    
    if (coverage) {
        publishHTML(target: [
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'htmlcov',
            reportFiles: 'index.html',
            reportName: 'Python Coverage Report'
        ])
    }
}

def runJUnitTests(Map config) {
    sh """
        mvn test \
            -Dmaven.test.failure.ignore=true \
            -DgenerateReports=true
    """
    
    junit '**/target/surefire-reports/*.xml'
    
    if (config.coverage) {
        sh "mvn jacoco:report"
        publishHTML(target: [
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'target/site/jacoco',
            reportFiles: 'index.html',
            reportName: 'JaCoCo Coverage Report'
        ])
    }
}

def runMochaTests(Map config) {
    sh """
        npm run test:mocha -- \
            --reporter mocha-junit-reporter \
            --reporter-options mochaFile=./test-results.xml
    """
    
    junit 'test-results.xml'
    
    if (config.coverage) {
        sh "npm run coverage"
        publishHTML(target: [
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'coverage',
            reportFiles: 'index.html',
            reportName: 'Coverage Report'
        ])
    }
}

def runGoTests(Map config) {
    sh """
        go test -v ./... \
            -coverprofile=coverage.out \
            -json > test-report.json
        
        go tool cover -html=coverage.out -o coverage.html
    """
    
    if (config.coverage) {
        publishHTML(target: [
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: '.',
            reportFiles: 'coverage.html',
            reportName: 'Go Coverage Report'
        ])
    }
}

def runDotNetTests(Map config) {
    sh """
        dotnet test \
            --logger "trx;LogFileName=test-results.trx" \
            --collect:"XPlat Code Coverage"
    """
    
    mstest testResultsFile: '**/*.trx'
    
    if (config.coverage) {
        sh "reportgenerator -reports:**/coverage.cobertura.xml -targetdir:coveragereport -reporttypes:Html"
        publishHTML(target: [
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'coveragereport',
            reportFiles: 'index.html',
            reportName: '.NET Coverage Report'
        ])
    }
}

def runJMeterTests(Map config) {
    def testPlan = config.testPlan ?: 'test-plan.jmx'
    def users = config.users ?: 10
    def duration = config.duration ?: 60
    
    sh """
        jmeter -n \
            -t ${testPlan} \
            -Jusers=${users} \
            -Jduration=${duration} \
            -l results.jtl \
            -e -o jmeter-report
    """
    
    publishHTML(target: [
        allowMissing: false,
        alwaysLinkToLastBuild: true,
        keepAll: true,
        reportDir: 'jmeter-report',
        reportFiles: 'index.html',
        reportName: 'JMeter Report'
    ])
}

def runK6Tests(Map config) {
    def script = config.script ?: 'load-test.js'
    def vus = config.users ?: 10
    def duration = config.duration ?: '60s'
    
    sh """
        k6 run \
            --vus ${vus} \
            --duration ${duration} \
            --out json=k6-results.json \
            ${script}
        
        # Convert results to HTML
        k6-reporter k6-results.json --out k6-report.html
    """
    
    publishHTML(target: [
        allowMissing: false,
        alwaysLinkToLastBuild: true,
        keepAll: true,
        reportDir: '.',
        reportFiles: 'k6-report.html',
        reportName: 'K6 Performance Report'
    ])
}

def runGatlingTests(Map config) {
    def simulation = config.simulation ?: 'BasicSimulation'
    
    sh """
        gatling.sh -s ${simulation} \
            -rf results
    """
    
    gatlingArchive()
}

def detectTestFramework() {
    if (fileExists('package.json')) {
        def packageJson = readJSON file: 'package.json'
        if (packageJson.devDependencies?.jest || packageJson.dependencies?.jest) {
            return 'jest'
        } else if (packageJson.devDependencies?.mocha || packageJson.dependencies?.mocha) {
            return 'mocha'
        }
    }
    
    if (fileExists('requirements.txt') || fileExists('setup.py')) {
        return 'pytest'
    }
    
    if (fileExists('pom.xml')) {
        return 'junit'
    }
    
    if (fileExists('go.mod')) {
        return 'go'
    }
    
    if (fileExists('*.csproj') || fileExists('*.sln')) {
        return 'dotnet'
    }
    
    return 'unknown'
}

def publishCoverageReport(String reportDir) {
    echo "Publishing coverage report from ${reportDir}"
    
    publishHTML(target: [
        allowMissing: false,
        alwaysLinkToLastBuild: true,
        keepAll: true,
        reportDir: reportDir,
        reportFiles: 'index.html',
        reportName: 'Test Coverage Report'
    ])
    
    if (fileExists("${reportDir}/cobertura-coverage.xml")) {
        cobertura coberturaReportFile: "${reportDir}/cobertura-coverage.xml"
    }
}

def validateTestResults(Map config = [:]) {
    def minCoverage = config.minCoverage ?: 80
    def maxFailures = config.maxFailures ?: 0
    
    def testResults = junit testResults: '**/test-results.xml', allowEmptyResults: false
    
    if (testResults.failCount > maxFailures) {
        error "Too many test failures: ${testResults.failCount} > ${maxFailures}"
    }
    
    def coverage = sh(
        script: "grep -oP 'Total Coverage: \\K[0-9]+' coverage-summary.txt || echo 0",
        returnStdout: true
    ).trim() as Integer
    
    if (coverage < minCoverage) {
        error "Coverage ${coverage}% is below minimum ${minCoverage}%"
    }
}

return this