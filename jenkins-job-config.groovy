#!/usr/bin/env groovy

// Jenkins Job DSL script to create the SecDevOps CI/CD pipeline job

pipelineJob('SecDevOps-E2E-Pipeline') {
    description('End-to-end CI/CD pipeline for SecDevOps applications with security scanning and quality gates')
    
    parameters {
        stringParam('APP_NAME', 'dummy-app-e2e-test', 'Application name to build and deploy')
        stringParam('VERSION', 'v1.2', 'Version tag for the deployment')
        choiceParam('BRANCH', ['main', 'develop', 'feature/*'], 'Git branch to build from')
    }
    
    properties {
        // Keep only last 10 builds
        buildDiscarder {
            strategy {
                logRotator {
                    numToKeepStr('10')
                    artifactNumToKeepStr('5')
                }
            }
        }
        
        // GitHub project
        githubProjectUrl('file:///home/jez/code/dummy-app-e2e-test')
        
        // Build triggers
        triggers {
            // Poll SCM every 5 minutes
            scm('H/5 * * * *')
            
            // Trigger on push to main branch
            githubPush()
        }
    }
    
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('file:///home/jez/code/SecDevOps_CICD')
                        credentials('')
                    }
                    branches('*/main')
                }
            }
            scriptPath('Jenkinsfile')
        }
    }
}

// Create a view for SecDevOps pipelines
listView('SecDevOps Pipelines') {
    description('All SecDevOps CI/CD pipelines')
    jobs {
        regex('SecDevOps.*')
    }
    columns {
        status()
        weather()
        name()
        lastSuccess()
        lastFailure()
        lastDuration()
        buildButton()
    }
}

// Create a monitoring dashboard job
pipelineJob('SecDevOps-Monitoring-Dashboard') {
    description('Dashboard job to check all monitoring services')
    
    triggers {
        // Run every hour
        cron('0 * * * *')
    }
    
    definition {
        cps {
            script('''
pipeline {
    agent any
    
    stages {
        stage('Check Services') {
            parallel {
                stage('Jenkins Health') {
                    steps {
                        sh 'curl -f http://localhost:8080/login || exit 1'
                        echo 'Jenkins is running'
                    }
                }
                stage('Prometheus Health') {
                    steps {
                        sh 'curl -f http://localhost:9091/-/healthy || exit 1'
                        echo 'Prometheus is healthy'
                    }
                }
                stage('Grafana Health') {
                    steps {
                        sh 'curl -f http://localhost:3000/api/health || exit 1'
                        echo 'Grafana is healthy'
                    }
                }
                stage('Alertmanager Health') {
                    steps {
                        sh 'curl -f http://localhost:9093/-/healthy || exit 1'
                        echo 'Alertmanager is healthy'
                    }
                }
                stage('ACR Connectivity') {
                    steps {
                        sh 'az acr list --resource-group rg-secdevops-cicd-dev --output table'
                        echo 'Azure Container Registry is accessible'
                    }
                }
            }
        }
        
        stage('Collect Metrics') {
            steps {
                sh \'\'\'
                    # Collect Docker metrics
                    CONTAINERS=$(docker ps --format "table {{.Names}}\\t{{.Status}}" | tail -n +2 | wc -l)
                    echo "Running containers: $CONTAINERS"
                    
                    # Collect system metrics
                    LOAD=$(uptime | awk -F\'load average:\' \'{ print $2 }\' | awk \'{ print $1 }\' | sed \'s/,//\')
                    echo "System load: $LOAD"
                    
                    # Push metrics to Prometheus
                    echo "system_load $LOAD" | curl --data-binary @- http://localhost:9091/metrics/job/monitoring/instance/dashboard
                    echo "docker_containers_running $CONTAINERS" | curl --data-binary @- http://localhost:9091/metrics/job/monitoring/instance/dashboard
                \'\'\'
            }
        }
    }
    
    post {
        failure {
            echo 'One or more services are down! Sending alert...'
            sh \'\'\'
                curl -X POST http://localhost:9093/api/v1/alerts \
                    -H "Content-Type: application/json" \
                    -d \'[{
                        "labels": {
                            "alertname": "ServiceDown",
                            "severity": "critical",
                            "job": "monitoring-dashboard"
                        }
                    }]\'
            \'\'\'
        }
    }
}
            ''')
            sandbox()
        }
    }
}

// Create OWASP ZAP security scanning job
pipelineJob('SecDevOps-OWASP-ZAP-Scan') {
    description('OWASP ZAP Dynamic Application Security Testing (DAST)')
    
    parameters {
        stringParam('TARGET_URL', 'http://localhost:3001', 'Target URL to scan')
        choiceParam('SCAN_TYPE', ['baseline', 'full', 'api'], 'Type of ZAP scan to run')
    }
    
    definition {
        cps {
            script('''
pipeline {
    agent any
    
    stages {
        stage('Prepare ZAP') {
            steps {
                sh \'\'\'
                    # Pull latest ZAP Docker image
                    docker pull zaproxy/zap-stable:latest
                    
                    # Create results directory
                    mkdir -p zap-results
                \'\'\'
            }
        }
        
        stage('Run ZAP Scan') {
            steps {
                script {
                    def scanCommand = ""
                    switch(params.SCAN_TYPE) {
                        case "baseline":
                            scanCommand = "zap-baseline.py"
                            break
                        case "full":
                            scanCommand = "zap-full-scan.py"
                            break
                        case "api":
                            scanCommand = "zap-api-scan.py"
                            break
                    }
                    
                    sh """
                        docker run --rm \
                            -v \$(pwd)/zap-results:/zap/wrk:rw \
                            -t zaproxy/zap-stable \
                            ${scanCommand} \
                            -t ${params.TARGET_URL} \
                            -r zap_report.html \
                            -J zap_report.json \
                            || true
                    """
                }
            }
        }
        
        stage('Analyze Results') {
            steps {
                sh \'\'\'
                    if [ -f "zap-results/zap_report.json" ]; then
                        HIGH_RISKS=$(cat zap-results/zap_report.json | jq \'[.site[].alerts[] | select(.riskcode == "3")] | length\')
                        MEDIUM_RISKS=$(cat zap-results/zap_report.json | jq \'[.site[].alerts[] | select(.riskcode == "2")] | length\')
                        LOW_RISKS=$(cat zap-results/zap_report.json | jq \'[.site[].alerts[] | select(.riskcode == "1")] | length\')
                        
                        echo "Security Scan Results:"
                        echo "High Risk Issues: $HIGH_RISKS"
                        echo "Medium Risk Issues: $MEDIUM_RISKS"
                        echo "Low Risk Issues: $LOW_RISKS"
                        
                        if [ "$HIGH_RISKS" -gt "0" ]; then
                            echo "CRITICAL: High risk security issues found!"
                            exit 1
                        fi
                    fi
                \'\'\'
            }
        }
    }
    
    post {
        always {
            publishHTML([
                reportDir: 'zap-results',
                reportFiles: 'zap_report.html',
                reportName: 'ZAP Security Report'
            ])
            archiveArtifacts artifacts: 'zap-results/*', allowEmptyArchive: true
        }
    }
}
            ''')
            sandbox()
        }
    }
}