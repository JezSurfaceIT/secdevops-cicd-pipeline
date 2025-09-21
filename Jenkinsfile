pipeline {
    agent any
    
    parameters {
        string(name: 'APP_NAME', defaultValue: 'dummy-app-e2e-test', description: 'Application name')
        string(name: 'VERSION', defaultValue: 'v1.2', description: 'Version tag for deployment')
        string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to build')
    }
    
    environment {
        AZURE_SUBSCRIPTION = '80265df9-bba2-4ad2-88af-e002fd2ca230'
        RESOURCE_GROUP = 'rg-secdevops-cicd-dev'
        ACR_NAME = 'acrsecdevopsdev'
        SONARQUBE_URL = 'http://localhost:9000'
        MONITORING_PROMETHEUS = 'http://localhost:9091'
        MONITORING_GRAFANA = 'http://localhost:3000'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "Checking out ${params.BRANCH} branch..."
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${params.BRANCH}"]],
                    userRemoteConfigs: [[
                        url: "file:///home/jez/code/${params.APP_NAME}"
                    ]]
                ])
            }
        }
        
        stage('Code Quality Analysis') {
            parallel {
                stage('Lint Check') {
                    steps {
                        echo 'Running ESLint checks...'
                        sh '''
                            if [ -f "package.json" ]; then
                                npm install
                                npm run lint || true
                            fi
                        '''
                    }
                }
                
                stage('Security Scan - Dependencies') {
                    steps {
                        echo 'Running npm audit for security vulnerabilities...'
                        sh '''
                            if [ -f "package.json" ]; then
                                npm audit --audit-level=moderate || true
                            fi
                        '''
                    }
                }
                
                stage('SAST - Trivy') {
                    steps {
                        echo 'Running Trivy security scan on source code...'
                        sh '''
                            docker run --rm -v $(pwd):/src \
                                aquasec/trivy:latest fs \
                                --severity HIGH,CRITICAL \
                                --no-progress \
                                --format json \
                                --output trivy-results.json \
                                /src || true
                        '''
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                echo 'Running unit tests with coverage...'
                sh '''
                    if [ -f "package.json" ]; then
                        npm test -- --coverage --watchAll=false || true
                        
                        # Check coverage threshold
                        COVERAGE=$(grep -o '"lines":[0-9.]*' coverage/coverage-summary.json | cut -d: -f2 | head -1)
                        echo "Code coverage: ${COVERAGE}%"
                        
                        if (( $(echo "$COVERAGE < 80" | bc -l) )); then
                            echo "WARNING: Code coverage below 80%"
                        fi
                    fi
                '''
            }
            post {
                always {
                    publishHTML([
                        reportDir: 'coverage/lcov-report',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo "Building Docker image ${params.APP_NAME}:${params.VERSION}..."
                sh """
                    docker build -t ${params.APP_NAME}:${params.VERSION} .
                    docker tag ${params.APP_NAME}:${params.VERSION} ${ACR_NAME}.azurecr.io/${params.APP_NAME}:${params.VERSION}
                """
            }
        }
        
        stage('Container Security Scan') {
            steps {
                echo 'Scanning Docker image for vulnerabilities...'
                sh """
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image \
                        --severity HIGH,CRITICAL \
                        --no-progress \
                        --format json \
                        --output trivy-image-results.json \
                        ${params.APP_NAME}:${params.VERSION} || true
                """
            }
        }
        
        stage('Push to Registry') {
            steps {
                echo 'Pushing image to Azure Container Registry...'
                sh """
                    # Login to ACR
                    az acr login --name ${ACR_NAME}
                    
                    # Push image
                    docker push ${ACR_NAME}.azurecr.io/${params.APP_NAME}:${params.VERSION}
                """
            }
        }
        
        stage('Deploy to Test') {
            steps {
                echo 'Deploying to Azure Container Instance (Test Environment)...'
                sh """
                    # Deploy using our autonomous script
                    /home/jez/code/SecDevOps_CICD/run-e2e-pipeline.sh ${params.APP_NAME} ${params.VERSION}
                """
            }
        }
        
        stage('Run E2E Tests') {
            steps {
                echo 'Running end-to-end tests...'
                sh '''
                    # Wait for deployment to be ready
                    sleep 30
                    
                    # Get container IP
                    CONTAINER_IP=$(az container show \
                        --resource-group ${RESOURCE_GROUP} \
                        --name ${APP_NAME}-test \
                        --query ipAddress.ip -o tsv)
                    
                    # Run basic health check
                    curl -f http://${CONTAINER_IP}:3001/health || exit 1
                    
                    # Run API tests
                    curl -f http://${CONTAINER_IP}:3001/api/users || exit 1
                '''
            }
        }
        
        stage('Performance Testing') {
            when {
                expression { params.VERSION.contains('release') }
            }
            steps {
                echo 'Running performance tests with Apache Bench...'
                sh '''
                    CONTAINER_IP=$(az container show \
                        --resource-group ${RESOURCE_GROUP} \
                        --name ${APP_NAME}-test \
                        --query ipAddress.ip -o tsv)
                    
                    # Run load test (1000 requests, 10 concurrent)
                    docker run --rm jordi/ab -n 1000 -c 10 http://${CONTAINER_IP}:3001/ || true
                '''
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            input {
                message "Deploy to production?"
                ok "Deploy"
                parameters {
                    choice(name: 'DEPLOYMENT_STRATEGY', choices: ['blue-green', 'canary', 'rolling'], description: 'Deployment strategy')
                }
            }
            steps {
                echo "Deploying to production using ${DEPLOYMENT_STRATEGY} strategy..."
                sh """
                    # Deploy to production slot
                    az container create \
                        --resource-group ${RESOURCE_GROUP} \
                        --name ${APP_NAME}-prod \
                        --image ${ACR_NAME}.azurecr.io/${APP_NAME}:${params.VERSION} \
                        --cpu 2 \
                        --memory 4 \
                        --ports 80 443 \
                        --environment-variables NODE_ENV=production \
                        --dns-name-label ${APP_NAME}-prod \
                        --location eastus \
                        --restart-policy Always || \
                    az container update \
                        --resource-group ${RESOURCE_GROUP} \
                        --name ${APP_NAME}-prod \
                        --image ${ACR_NAME}.azurecr.io/${APP_NAME}:${params.VERSION}
                """
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up workspace...'
            sh '''
                # Clean up Docker images
                docker rmi ${APP_NAME}:${VERSION} || true
                docker rmi ${ACR_NAME}.azurecr.io/${APP_NAME}:${VERSION} || true
            '''
            
            // Archive test results
            archiveArtifacts artifacts: '**/trivy-*.json', allowEmptyArchive: true
            
            // Send notifications to monitoring
            sh """
                curl -X POST ${MONITORING_PROMETHEUS}/metrics/job/jenkins/instance/pipeline \
                    -d "pipeline_status{job='${JOB_NAME}',build='${BUILD_NUMBER}',status='${currentBuild.result}'} 1" || true
            """
        }
        success {
            echo "Pipeline completed successfully! Version ${params.VERSION} deployed."
        }
        failure {
            echo "Pipeline failed. Check the logs for details."
            // Send alert
            sh """
                curl -X POST http://localhost:9093/api/v1/alerts \
                    -H "Content-Type: application/json" \
                    -d '[{
                        "labels": {
                            "alertname": "JenkinsPipelineFailed",
                            "job": "${JOB_NAME}",
                            "build": "${BUILD_NUMBER}"
                        }
                    }]' || true
            """
        }
    }
}