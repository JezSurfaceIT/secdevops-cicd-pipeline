#!/bin/bash
set -e

# SonarQube Code Quality and Security Analysis Script

PROJECT_KEY="${1:-secdevops-cicd}"
PROJECT_NAME="${2:-SecDevOps-CICD}"
SONAR_HOST="${SONAR_HOST:-http://localhost:9000}"
SONAR_TOKEN="${SONAR_TOKEN:-}"

echo "========================================="
echo "SonarQube Code Analysis"
echo "========================================="
echo "Project: $PROJECT_NAME ($PROJECT_KEY)"
echo "SonarQube Server: $SONAR_HOST"
echo ""

# Check if SonarQube is running
echo "Checking SonarQube availability..."
if ! curl -s -f "$SONAR_HOST/api/system/status" > /dev/null; then
    echo "Starting SonarQube..."
    docker-compose -f docker-compose.sonarqube.yml up -d
    
    echo "Waiting for SonarQube to be ready (this may take a few minutes)..."
    while ! curl -s -f "$SONAR_HOST/api/system/status" > /dev/null; do
        echo -n "."
        sleep 5
    done
    echo " Ready!"
fi

# Generate token if not provided
if [ -z "$SONAR_TOKEN" ]; then
    echo "Generating SonarQube token..."
    # Default admin credentials (change in production!)
    SONAR_TOKEN=$(curl -s -u admin:admin \
        -X POST "$SONAR_HOST/api/user_tokens/generate" \
        -d "name=cicd-token-$(date +%s)" \
        | jq -r '.token' 2>/dev/null || echo "")
    
    if [ -z "$SONAR_TOKEN" ]; then
        echo "Warning: Could not generate token. Using default credentials."
        SONAR_AUTH="-Dsonar.login=admin -Dsonar.password=admin"
    else
        echo "Token generated successfully"
        SONAR_AUTH="-Dsonar.login=$SONAR_TOKEN"
    fi
else
    SONAR_AUTH="-Dsonar.login=$SONAR_TOKEN"
fi

# Create project if it doesn't exist
echo "Ensuring project exists in SonarQube..."
curl -s -X POST "$SONAR_HOST/api/projects/create" \
    -u admin:admin \
    -d "key=$PROJECT_KEY&name=$PROJECT_NAME" > /dev/null 2>&1 || true

# Run analysis based on project type
if [ -f "package.json" ]; then
    echo "Detected Node.js project"
    
    # Install dependencies if needed
    [ -d "node_modules" ] || npm install
    
    # Run tests with coverage if available
    if grep -q '"test"' package.json; then
        echo "Running tests with coverage..."
        npm test -- --coverage --watchAll=false || true
    fi
    
    # Run SonarQube scanner
    echo "Running SonarQube analysis..."
    docker run --rm \
        --network host \
        -v "$(pwd):/usr/src" \
        -w /usr/src \
        sonarsource/sonar-scanner-cli \
        -Dsonar.host.url=$SONAR_HOST \
        -Dsonar.projectKey=$PROJECT_KEY \
        -Dsonar.projectName="$PROJECT_NAME" \
        -Dsonar.sources=. \
        -Dsonar.exclusions="**/node_modules/**,**/coverage/**,**/dist/**,**/*.test.js,**/*.spec.js" \
        -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \
        $SONAR_AUTH

elif [ -f "pom.xml" ]; then
    echo "Detected Maven project"
    mvn clean verify sonar:sonar \
        -Dsonar.host.url=$SONAR_HOST \
        -Dsonar.projectKey=$PROJECT_KEY \
        $SONAR_AUTH

elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    echo "Detected Gradle project"
    ./gradlew sonarqube \
        -Dsonar.host.url=$SONAR_HOST \
        -Dsonar.projectKey=$PROJECT_KEY \
        $SONAR_AUTH

else
    echo "Running generic SonarQube analysis..."
    docker run --rm \
        --network host \
        -v "$(pwd):/usr/src" \
        -w /usr/src \
        sonarsource/sonar-scanner-cli \
        -Dsonar.host.url=$SONAR_HOST \
        -Dsonar.projectKey=$PROJECT_KEY \
        -Dsonar.projectName="$PROJECT_NAME" \
        -Dsonar.sources=. \
        $SONAR_AUTH
fi

# Wait for analysis to complete
echo ""
echo "Waiting for quality gate results..."
sleep 10

# Check quality gate status
QG_STATUS=$(curl -s "$SONAR_HOST/api/qualitygates/project_status?projectKey=$PROJECT_KEY" \
    | jq -r '.projectStatus.status' 2>/dev/null || echo "UNKNOWN")

# Get metrics
echo ""
echo "========================================="
echo "Code Quality Metrics"
echo "========================================="

# Fetch metrics
METRICS=$(curl -s "$SONAR_HOST/api/measures/component?component=$PROJECT_KEY&metricKeys=coverage,bugs,vulnerabilities,code_smells,security_hotspots,duplicated_lines_density" 2>/dev/null || echo "{}")

if [ "$METRICS" != "{}" ]; then
    echo "$METRICS" | jq -r '.component.measures[] | "\(.metric): \(.value)"' 2>/dev/null || echo "Could not parse metrics"
fi

echo ""
echo "========================================="
echo "Quality Gate Status: $QG_STATUS"
echo "========================================="

# Generate report link
echo ""
echo "📊 View detailed report: $SONAR_HOST/dashboard?id=$PROJECT_KEY"

# Exit based on quality gate
if [ "$QG_STATUS" = "ERROR" ] || [ "$QG_STATUS" = "FAILED" ]; then
    echo "❌ Quality gate failed! Please fix the issues before proceeding."
    exit 1
elif [ "$QG_STATUS" = "OK" ] || [ "$QG_STATUS" = "PASSED" ]; then
    echo "✅ Quality gate passed!"
    exit 0
else
    echo "⚠️  Could not determine quality gate status"
    exit 0
fi