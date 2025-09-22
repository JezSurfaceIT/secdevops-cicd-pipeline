#!/usr/bin/env groovy

def buildImage(Map config = [:]) {
    def imageName = config.imageName ?: 'app'
    def imageTag = config.imageTag ?: 'latest'
    def dockerfile = config.dockerfile ?: 'Dockerfile'
    def buildContext = config.buildContext ?: '.'
    def buildArgs = config.buildArgs ?: []
    def registry = config.registry ?: ''
    
    echo "Building Docker image: ${imageName}:${imageTag}"
    
    def fullImageName = registry ? "${registry}/${imageName}" : imageName
    
    def buildCommand = "docker build -t ${fullImageName}:${imageTag}"
    
    if (dockerfile != 'Dockerfile') {
        buildCommand += " -f ${dockerfile}"
    }
    
    buildArgs.each { arg ->
        buildCommand += " --build-arg ${arg}"
    }
    
    buildCommand += " ${buildContext}"
    
    sh buildCommand
    
    return "${fullImageName}:${imageTag}"
}

def scanWithTrivy(Map config = [:]) {
    def imageName = config.imageName
    def severity = config.severity ?: 'HIGH,CRITICAL'
    def exitCode = config.exitCode ?: '1'
    def format = config.format ?: 'json'
    def outputFile = config.outputFile ?: 'trivy-report.json'
    
    if (!imageName) {
        error "Image name is required for Trivy scan"
    }
    
    echo "Scanning image ${imageName} with Trivy..."
    
    sh """
        trivy image \
            --severity ${severity} \
            --exit-code ${exitCode} \
            --format ${format} \
            --output ${outputFile} \
            ${imageName}
    """
    
    if (format == 'json' && fileExists(outputFile)) {
        def report = readJSON file: outputFile
        def vulnerabilities = []
        
        report.Results?.each { result ->
            result.Vulnerabilities?.each { vuln ->
                vulnerabilities.add([
                    package: vuln.PkgName,
                    severity: vuln.Severity,
                    vulnerability: vuln.VulnerabilityID,
                    description: vuln.Description
                ])
            }
        }
        
        if (vulnerabilities.size() > 0) {
            echo "Found ${vulnerabilities.size()} vulnerabilities"
            vulnerabilities.each { vuln ->
                echo "  ${vuln.severity}: ${vuln.package} - ${vuln.vulnerability}"
            }
        } else {
            echo "No vulnerabilities found"
        }
        
        return vulnerabilities
    }
}

def scanWithAnchore(Map config = [:]) {
    def imageName = config.imageName
    def policyBundle = config.policyBundle ?: 'default'
    def bailOnFail = config.bailOnFail ?: true
    def outputFile = config.outputFile ?: 'anchore-report.json'
    
    if (!imageName) {
        error "Image name is required for Anchore scan"
    }
    
    echo "Scanning image ${imageName} with Anchore..."
    
    sh """
        ${env.WORKSPACE}/scripts/security/jenkins-anchore-scan.sh \
            ${imageName} \
            ${env.BRANCH_NAME == 'main' ? 'production' : 'development'} \
            ${bailOnFail}
    """
    
    if (fileExists('vulnerability-report.txt')) {
        def vulnReport = readFile 'vulnerability-report.txt'
        echo "Vulnerability Report:\n${vulnReport}"
    }
    
    if (fileExists('policy-evaluation.txt')) {
        def policyReport = readFile 'policy-evaluation.txt'
        echo "Policy Evaluation:\n${policyReport}"
    }
}

def pushToRegistry(Map config = [:]) {
    def imageName = config.imageName
    def registry = config.registry
    def credentials = config.credentials ?: 'acr-credentials'
    def tag = config.tag ?: 'latest'
    
    if (!imageName || !registry) {
        error "Image name and registry are required for push"
    }
    
    echo "Pushing ${imageName}:${tag} to ${registry}"
    
    withCredentials([usernamePassword(
        credentialsId: credentials,
        usernameVariable: 'REGISTRY_USER',
        passwordVariable: 'REGISTRY_PASS'
    )]) {
        sh """
            echo \$REGISTRY_PASS | docker login ${registry} -u \$REGISTRY_USER --password-stdin
            docker tag ${imageName}:${tag} ${registry}/${imageName}:${tag}
            docker push ${registry}/${imageName}:${tag}
            docker logout ${registry}
        """
    }
    
    return "${registry}/${imageName}:${tag}"
}

def tagImage(Map config = [:]) {
    def sourceImage = config.sourceImage
    def targetImage = config.targetImage
    def sourceTag = config.sourceTag ?: 'latest'
    def targetTag = config.targetTag ?: 'latest'
    
    if (!sourceImage || !targetImage) {
        error "Source and target images are required for tagging"
    }
    
    sh "docker tag ${sourceImage}:${sourceTag} ${targetImage}:${targetTag}"
    
    return "${targetImage}:${targetTag}"
}

def pullImage(Map config = [:]) {
    def imageName = config.imageName
    def tag = config.tag ?: 'latest'
    def registry = config.registry ?: ''
    def credentials = config.credentials
    
    def fullImageName = registry ? "${registry}/${imageName}" : imageName
    
    if (credentials) {
        withCredentials([usernamePassword(
            credentialsId: credentials,
            usernameVariable: 'REGISTRY_USER',
            passwordVariable: 'REGISTRY_PASS'
        )]) {
            sh """
                echo \$REGISTRY_PASS | docker login ${registry} -u \$REGISTRY_USER --password-stdin
                docker pull ${fullImageName}:${tag}
                docker logout ${registry}
            """
        }
    } else {
        sh "docker pull ${fullImageName}:${tag}"
    }
    
    return "${fullImageName}:${tag}"
}

def cleanupImages(Map config = [:]) {
    def keepLast = config.keepLast ?: 3
    def imageName = config.imageName
    
    echo "Cleaning up old Docker images..."
    
    if (imageName) {
        sh """
            # Remove all but the last N images
            docker images ${imageName} --format '{{.ID}}' | tail -n +${keepLast + 1} | xargs -r docker rmi -f
        """
    }
    
    sh """
        # Remove dangling images
        docker image prune -f
        
        # Remove unused images older than 24h
        docker image prune -a -f --filter "until=24h"
    """
}

def runContainer(Map config = [:]) {
    def imageName = config.imageName
    def containerName = config.containerName ?: 'test-container'
    def ports = config.ports ?: []
    def envVars = config.envVars ?: [:]
    def volumes = config.volumes ?: []
    def network = config.network ?: 'bridge'
    def detached = config.detached ?: false
    
    if (!imageName) {
        error "Image name is required to run container"
    }
    
    def runCommand = "docker run"
    
    if (detached) {
        runCommand += " -d"
    }
    
    runCommand += " --name ${containerName}"
    runCommand += " --network ${network}"
    
    ports.each { port ->
        runCommand += " -p ${port}"
    }
    
    envVars.each { key, value ->
        runCommand += " -e ${key}='${value}'"
    }
    
    volumes.each { volume ->
        runCommand += " -v ${volume}"
    }
    
    runCommand += " ${imageName}"
    
    sh runCommand
    
    return containerName
}

def stopContainer(String containerName) {
    sh "docker stop ${containerName} || true"
    sh "docker rm ${containerName} || true"
}

def getContainerLogs(String containerName, int lines = 100) {
    def logs = sh(
        script: "docker logs --tail ${lines} ${containerName}",
        returnStdout: true
    ).trim()
    
    return logs
}

def inspectImage(String imageName) {
    def inspection = sh(
        script: "docker inspect ${imageName}",
        returnStdout: true
    ).trim()
    
    return readJSON(text: inspection)[0]
}

def analyzeWithContainerDiff(Map config = [:]) {
    def image1 = config.image1
    def image2 = config.image2
    def analysisType = config.analysisType ?: 'size'
    
    if (!image1) {
        error "At least one image is required for analysis"
    }
    
    def command = "container-diff analyze ${image1}"
    
    if (image2) {
        command = "container-diff diff ${image1} ${image2}"
    }
    
    command += " --type ${analysisType}"
    
    def result = sh(
        script: command,
        returnStdout: true
    ).trim()
    
    echo "Container analysis result:\n${result}"
    
    return result
}

return this