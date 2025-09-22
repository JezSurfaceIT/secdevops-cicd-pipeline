#!/usr/bin/env groovy

def deployToEnvironment(Map config = [:]) {
    def environment = config.environment
    def imageName = config.imageName
    def imageTag = config.imageTag ?: 'latest'
    def namespace = config.namespace ?: 'default'
    def deploymentName = config.deploymentName ?: 'app-deployment'
    def serviceName = config.serviceName ?: 'app-service'
    def replicas = config.replicas ?: 1
    
    if (!environment || !imageName) {
        error "Environment and image name are required for deployment"
    }
    
    echo "Deploying ${imageName}:${imageTag} to ${environment} environment"
    
    switch(environment.toLowerCase()) {
        case 'dev':
        case 'development':
            deployToDev(config)
            break
        case 'test':
        case 'testing':
            deployToTest(config)
            break
        case 'staging':
            deployToStaging(config)
            break
        case 'prod':
        case 'production':
            deployToProduction(config)
            break
        default:
            error "Unknown environment: ${environment}"
    }
}

def deployToDev(Map config) {
    def imageName = config.imageName
    def imageTag = config.imageTag ?: 'latest'
    
    echo "Deploying to Development environment..."
    
    withCredentials([file(credentialsId: 'kubeconfig-dev', variable: 'KUBECONFIG')]) {
        sh """
            kubectl set image deployment/${config.deploymentName} \
                app=${imageName}:${imageTag} \
                --namespace=${config.namespace} \
                --record=true
            
            kubectl rollout status deployment/${config.deploymentName} \
                --namespace=${config.namespace} \
                --timeout=5m
        """
    }
    
    runSmokeTests(config)
}

def deployToTest(Map config) {
    def imageName = config.imageName
    def imageTag = config.imageTag ?: 'latest'
    
    echo "Deploying to Test environment..."
    
    withCredentials([file(credentialsId: 'kubeconfig-test', variable: 'KUBECONFIG')]) {
        sh """
            kubectl set image deployment/${config.deploymentName} \
                app=${imageName}:${imageTag} \
                --namespace=${config.namespace} \
                --record=true
            
            kubectl rollout status deployment/${config.deploymentName} \
                --namespace=${config.namespace} \
                --timeout=5m
        """
    }
    
    runIntegrationTests(config)
}

def deployToStaging(Map config) {
    def imageName = config.imageName
    def imageTag = config.imageTag ?: 'latest'
    
    echo "Deploying to Staging environment..."
    
    withCredentials([file(credentialsId: 'kubeconfig-staging', variable: 'KUBECONFIG')]) {
        sh """
            # Create canary deployment
            kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${config.deploymentName}-canary
  namespace: ${config.namespace}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${config.deploymentName}
      version: canary
  template:
    metadata:
      labels:
        app: ${config.deploymentName}
        version: canary
    spec:
      containers:
      - name: app
        image: ${imageName}:${imageTag}
        ports:
        - containerPort: 8080
EOF
            
            kubectl rollout status deployment/${config.deploymentName}-canary \
                --namespace=${config.namespace} \
                --timeout=5m
        """
    }
    
    runPerformanceTests(config)
}

def deployToProduction(Map config) {
    def imageName = config.imageName
    def imageTag = config.imageTag ?: 'latest'
    def approvalRequired = config.approvalRequired ?: true
    
    if (approvalRequired) {
        input message: "Deploy to Production?", 
              ok: "Deploy",
              submitter: "admin,devops-team"
    }
    
    echo "Deploying to Production environment..."
    
    withCredentials([file(credentialsId: 'kubeconfig-prod', variable: 'KUBECONFIG')]) {
        sh """
            # Blue-Green deployment
            kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${config.deploymentName}-green
  namespace: ${config.namespace}
spec:
  replicas: ${config.replicas}
  selector:
    matchLabels:
      app: ${config.deploymentName}
      version: green
  template:
    metadata:
      labels:
        app: ${config.deploymentName}
        version: green
    spec:
      containers:
      - name: app
        image: ${imageName}:${imageTag}
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
EOF
            
            kubectl rollout status deployment/${config.deploymentName}-green \
                --namespace=${config.namespace} \
                --timeout=10m
            
            # Switch traffic to green deployment
            kubectl patch service ${config.serviceName} \
                -p '{"spec":{"selector":{"version":"green"}}}' \
                --namespace=${config.namespace}
        """
    }
    
    verifyProduction(config)
}

def promoteToProduction(Map config = [:]) {
    def sourceEnv = config.sourceEnv ?: 'staging'
    def imageName = config.imageName
    def imageTag = config.imageTag
    
    if (!imageName || !imageTag) {
        error "Image name and tag are required for promotion"
    }
    
    echo "Promoting ${imageName}:${imageTag} from ${sourceEnv} to production"
    
    def promotionChecks = [
        checkSecurityScans(imageName, imageTag),
        checkQualityGates(imageName, imageTag),
        checkPerformanceMetrics(sourceEnv),
        checkBusinessApproval()
    ]
    
    if (promotionChecks.every { it }) {
        deployToProduction(config + [approvalRequired: false])
        
        tagProductionRelease(imageName, imageTag)
        
        notifyPromotion(imageName, imageTag)
    } else {
        error "Promotion checks failed"
    }
}

def rollback(Map config = [:]) {
    def environment = config.environment
    def deploymentName = config.deploymentName ?: 'app-deployment'
    def namespace = config.namespace ?: 'default'
    def revision = config.revision
    
    if (!environment) {
        error "Environment is required for rollback"
    }
    
    echo "Rolling back deployment in ${environment}"
    
    def kubeconfigId = "kubeconfig-${environment.toLowerCase()}"
    
    withCredentials([file(credentialsId: kubeconfigId, variable: 'KUBECONFIG')]) {
        if (revision) {
            sh """
                kubectl rollout undo deployment/${deploymentName} \
                    --to-revision=${revision} \
                    --namespace=${namespace}
            """
        } else {
            sh """
                kubectl rollout undo deployment/${deploymentName} \
                    --namespace=${namespace}
            """
        }
        
        sh """
            kubectl rollout status deployment/${deploymentName} \
                --namespace=${namespace} \
                --timeout=5m
        """
    }
}

def deployToAzureContainerInstance(Map config = [:]) {
    def imageName = config.imageName
    def containerGroup = config.containerGroup ?: 'app-container-group'
    def resourceGroup = config.resourceGroup
    def location = config.location ?: 'eastus'
    def cpu = config.cpu ?: 1
    def memory = config.memory ?: 1.5
    
    if (!imageName || !resourceGroup) {
        error "Image name and resource group are required"
    }
    
    echo "Deploying to Azure Container Instance..."
    
    withCredentials([azureServicePrincipal('azure-sp')]) {
        sh """
            az login --service-principal \
                -u \$AZURE_CLIENT_ID \
                -p \$AZURE_CLIENT_SECRET \
                --tenant \$AZURE_TENANT_ID
            
            az container create \
                --resource-group ${resourceGroup} \
                --name ${containerGroup} \
                --image ${imageName} \
                --cpu ${cpu} \
                --memory ${memory} \
                --location ${location} \
                --restart-policy OnFailure \
                --ip-address Public
            
            az container show \
                --resource-group ${resourceGroup} \
                --name ${containerGroup} \
                --query instanceView.state
        """
    }
}

def deployToAzureWebApp(Map config = [:]) {
    def imageName = config.imageName
    def appName = config.appName
    def resourceGroup = config.resourceGroup
    def planName = config.planName
    
    if (!imageName || !appName || !resourceGroup) {
        error "Image name, app name, and resource group are required"
    }
    
    echo "Deploying to Azure Web App..."
    
    withCredentials([azureServicePrincipal('azure-sp')]) {
        sh """
            az login --service-principal \
                -u \$AZURE_CLIENT_ID \
                -p \$AZURE_CLIENT_SECRET \
                --tenant \$AZURE_TENANT_ID
            
            az webapp config container set \
                --name ${appName} \
                --resource-group ${resourceGroup} \
                --docker-custom-image-name ${imageName}
            
            az webapp restart \
                --name ${appName} \
                --resource-group ${resourceGroup}
        """
    }
}

def runSmokeTests(Map config) {
    echo "Running smoke tests..."
    
    sh """
        curl -f http://${config.serviceName}.${config.namespace}.svc.cluster.local/health || exit 1
        echo "Health check passed"
    """
}

def runIntegrationTests(Map config) {
    echo "Running integration tests..."
    
    sh """
        npm run test:integration || exit 1
    """
}

def runPerformanceTests(Map config) {
    echo "Running performance tests..."
    
    sh """
        npm run test:performance || exit 1
    """
}

def verifyProduction(Map config) {
    echo "Verifying production deployment..."
    
    sh """
        # Run production smoke tests
        npm run test:production:smoke
        
        # Check monitoring metrics
        curl -f http://prometheus:9090/api/v1/query?query=up{job='${config.deploymentName}'} || exit 1
    """
}

def checkSecurityScans(String imageName, String imageTag) {
    echo "Checking security scans for ${imageName}:${imageTag}"
    
    def scanResult = sh(
        script: "anchore-cli image get ${imageName}:${imageTag} | grep 'pass'",
        returnStatus: true
    )
    
    return scanResult == 0
}

def checkQualityGates(String imageName, String imageTag) {
    echo "Checking quality gates..."
    
    def qualityGate = sh(
        script: "curl -s http://sonarqube:9000/api/qualitygates/project_status?projectKey=${imageName} | jq -r '.projectStatus.status'",
        returnStdout: true
    ).trim()
    
    return qualityGate == 'OK'
}

def checkPerformanceMetrics(String environment) {
    echo "Checking performance metrics for ${environment}"
    
    def p95Latency = sh(
        script: "curl -s http://prometheus:9090/api/v1/query?query=http_request_duration_seconds{quantile='0.95',env='${environment}'} | jq -r '.data.result[0].value[1]'",
        returnStdout: true
    ).trim() as Double
    
    return p95Latency < 1.0
}

def checkBusinessApproval() {
    try {
        timeout(time: 24, unit: 'HOURS') {
            input message: "Business approval for production deployment",
                  ok: "Approve",
                  submitter: "product-owner,business-team"
        }
        return true
    } catch (Exception e) {
        return false
    }
}

def tagProductionRelease(String imageName, String imageTag) {
    def releaseTag = "prod-${new Date().format('yyyyMMdd-HHmmss')}"
    
    sh """
        docker tag ${imageName}:${imageTag} ${imageName}:${releaseTag}
        docker push ${imageName}:${releaseTag}
    """
}

def notifyPromotion(String imageName, String imageTag) {
    def message = "Successfully promoted ${imageName}:${imageTag} to production"
    
    slackSend(
        channel: '#deployments',
        color: 'good',
        message: message
    )
    
    emailext(
        subject: "Production Deployment: ${imageName}:${imageTag}",
        body: message,
        to: 'devops-team@example.com'
    )
}

return this