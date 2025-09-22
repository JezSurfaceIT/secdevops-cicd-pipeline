// buildUtils.groovy - Build utility functions for Jenkins pipeline

def validateEnvironment() {
    echo "🔍 Validating build environment..."
    
    // Check required tools
    def requiredCommands = ['node', 'npm', 'docker', 'git', 'az']
    def missingCommands = []
    
    requiredCommands.each { cmd ->
        def result = sh(
            script: "which ${cmd}",
            returnStatus: true
        )
        if (result != 0) {
            missingCommands.add(cmd)
        }
    }
    
    if (missingCommands.size() > 0) {
        error "Required commands not found: ${missingCommands.join(', ')}"
    }
    
    // Check Node version
    def nodeVersion = sh(
        script: "node --version",
        returnStdout: true
    ).trim()
    
    echo "Node.js version: ${nodeVersion}"
    
    if (!nodeVersion.matches("v(18|20)\\..*")) {
        error "Node.js version must be 18 or 20, found: ${nodeVersion}"
    }
    
    // Check Docker
    def dockerVersion = sh(
        script: "docker --version",
        returnStdout: true
    ).trim()
    echo "Docker version: ${dockerVersion}"
    
    // Validate Azure CLI
    def azVersion = sh(
        script: "az --version | head -n 1",
        returnStdout: true
    ).trim()
    echo "Azure CLI version: ${azVersion}"
    
    echo "✅ Environment validation passed"
}

def checkoutCode() {
    echo "📥 Checking out code..."
    
    checkout([
        $class: 'GitSCM',
        branches: scm.branches,
        extensions: [
            [$class: 'CleanBeforeCheckout'],
            [$class: 'CloneOption', depth: 0, noTags: false, shallow: false]
        ],
        userRemoteConfigs: scm.userRemoteConfigs
    ])
    
    // Get commit information
    env.GIT_COMMIT_SHORT = sh(
        script: "git rev-parse --short HEAD",
        returnStdout: true
    ).trim()
    
    env.GIT_COMMIT_MESSAGE = sh(
        script: "git log -1 --pretty=%B",
        returnStdout: true
    ).trim()
    
    env.GIT_AUTHOR = sh(
        script: "git log -1 --pretty=format:'%an <%ae>'",
        returnStdout: true
    ).trim()
    
    env.GIT_BRANCH = sh(
        script: "git rev-parse --abbrev-ref HEAD",
        returnStdout: true
    ).trim()
    
    echo "Branch: ${env.GIT_BRANCH}"
    echo "Commit: ${env.GIT_COMMIT_SHORT}"
    echo "Author: ${env.GIT_AUTHOR}"
    echo "Message: ${env.GIT_COMMIT_MESSAGE}"
}

def displayBuildInfo() {
    echo """
    ╔════════════════════════════════════════════════════════════════╗
    ║                      BUILD INFORMATION                         ║
    ╠════════════════════════════════════════════════════════════════╣
    ║ Build Number:    ${env.BUILD_NUMBER}
    ║ Job Name:        ${env.JOB_NAME}
    ║ Branch:          ${env.GIT_BRANCH}
    ║ Commit:          ${env.GIT_COMMIT_SHORT}
    ║ Author:          ${env.GIT_AUTHOR}
    ║ Environment:     ${env.NODE_ENV}
    ║ Version:         ${env.VERSION}
    ║ Workspace:       ${env.WORKSPACE}
    ╚════════════════════════════════════════════════════════════════╝
    """
}

def installDependencies() {
    echo "📦 Installing dependencies..."
    
    // Clean install to ensure consistency
    sh '''
        # Remove existing node_modules and package-lock
        rm -rf node_modules package-lock.json
        
        # Install dependencies
        npm ci --legacy-peer-deps
        
        # Audit dependencies (non-blocking)
        npm audit --audit-level=high || true
        
        # List installed packages
        npm list --depth=0
    '''
    
    echo "✅ Dependencies installed successfully"
}

def buildApplication() {
    echo "🔨 Building application..."
    
    try {
        sh '''
            # Set build environment
            export BUILD_NUMBER=${BUILD_NUMBER}
            export GIT_COMMIT=${GIT_COMMIT}
            export BUILD_TIMESTAMP=$(date -Iseconds)
            
            # Run linting
            echo "Running linter..."
            npm run lint || exit 1
            
            # Run type checking (if TypeScript)
            if [ -f "tsconfig.json" ]; then
                echo "Running type check..."
                npm run type-check || exit 1
            fi
            
            # Build application
            echo "Building application..."
            npm run build:production
            
            # Verify build output
            if [ ! -d "dist" ] && [ ! -d "build" ] && [ ! -d ".next" ]; then
                echo "Build output directory not found!"
                exit 1
            fi
            
            # Generate build info file
            cat > build-info.json <<EOF
{
    "buildNumber": "${BUILD_NUMBER}",
    "commit": "${GIT_COMMIT}",
    "commitShort": "${GIT_COMMIT_SHORT}",
    "branch": "${GIT_BRANCH}",
    "timestamp": "$(date -Iseconds)",
    "environment": "${NODE_ENV}",
    "version": "${VERSION}"
}
EOF
            
            # Copy build info to output directory
            if [ -d "dist" ]; then
                cp build-info.json dist/
            elif [ -d "build" ]; then
                cp build-info.json build/
            elif [ -d ".next" ]; then
                cp build-info.json .next/
            fi
        '''
        
        echo "✅ Application build completed successfully"
        
    } catch (Exception e) {
        error "❌ Build failed: ${e.message}"
    }
}

def createBuildArtifact() {
    echo "📦 Creating build artifact..."
    
    def artifactName = "${env.JOB_NAME}-${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}.tar.gz"
    
    sh """
        # Determine build directory
        if [ -d "dist" ]; then
            BUILD_DIR="dist"
        elif [ -d "build" ]; then
            BUILD_DIR="build"
        elif [ -d ".next" ]; then
            BUILD_DIR=".next"
        else
            echo "No build directory found"
            exit 1
        fi
        
        # Create artifact
        tar -czf ${artifactName} \${BUILD_DIR} package.json package-lock.json
        
        # Generate checksum
        sha256sum ${artifactName} > ${artifactName}.sha256
        
        echo "Artifact created: ${artifactName}"
    """
    
    // Archive the artifact
    archiveArtifacts artifacts: "${artifactName}*", fingerprint: true
    
    echo "✅ Build artifact created and archived"
}

def cleanBuildEnvironment() {
    echo "🧹 Cleaning build environment..."
    
    sh '''
        # Remove build artifacts
        rm -rf dist build .next
        
        # Remove test artifacts
        rm -rf coverage reports
        
        # Remove node_modules (optional, based on strategy)
        # rm -rf node_modules
        
        echo "Build environment cleaned"
    '''
}

def tagBuild(tagName) {
    echo "🏷️ Tagging build as ${tagName}..."
    
    sh """
        git config user.email "jenkins@secdevops.local"
        git config user.name "Jenkins CI"
        
        # Create tag
        git tag -a "${tagName}" -m "Build ${BUILD_NUMBER} - ${GIT_COMMIT_SHORT}"
        
        # Push tag to origin
        git push origin "${tagName}"
    """
    
    echo "✅ Build tagged as ${tagName}"
}

def generateBuildReport() {
    echo "📊 Generating build report..."
    
    def report = [
        buildNumber: env.BUILD_NUMBER,
        jobName: env.JOB_NAME,
        branch: env.GIT_BRANCH,
        commit: env.GIT_COMMIT_SHORT,
        author: env.GIT_AUTHOR,
        timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ss'Z'"),
        duration: currentBuild.durationString,
        result: currentBuild.result ?: 'SUCCESS'
    ]
    
    writeJSON file: 'reports/build-report.json', json: report
    
    echo "✅ Build report generated"
}