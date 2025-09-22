#!/bin/bash
# GitOps-Compliant Deployment Script for Oversight MVP
# This script ensures all deployments go through GitHub and Jenkins

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
GITHUB_ORG="JezSurfaceIT"
GITHUB_REPO="oversight-mvp"
JENKINS_URL="${JENKINS_URL:-http://vm-jenkins-dev:8080}"
APP_NAME="oversight-mvp"
LOCAL_PATH="/home/jez/code/Oversight-MVP-09-04"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  GitOps Deployment for Oversight MVP${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Function to print messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a git repository
check_git_status() {
    if [ ! -d "$LOCAL_PATH/.git" ]; then
        log_warn "No git repository found. Initializing..."
        cd "$LOCAL_PATH"
        git init
        git remote add origin "https://github.com/${GITHUB_ORG}/${GITHUB_REPO}.git"
        log_info "Git repository initialized"
    else
        cd "$LOCAL_PATH"
        log_info "Git repository found"
    fi
}

# Check for uncommitted changes
check_uncommitted_changes() {
    if [[ -n $(git status -s) ]]; then
        log_warn "You have uncommitted changes:"
        git status -s
        echo ""
        read -p "Do you want to commit these changes? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter commit message: " commit_msg
            git add .
            git commit -m "$commit_msg"
            log_info "Changes committed"
        else
            log_error "Cannot proceed with uncommitted changes"
            exit 1
        fi
    fi
}

# Push to GitHub
push_to_github() {
    local branch=$(git branch --show-current)
    
    if [ "$branch" == "main" ]; then
        log_warn "You're on the main branch. It's recommended to use feature branches."
        read -p "Continue with main branch? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter new branch name (feature/): " branch_name
            git checkout -b "feature/$branch_name"
            branch="feature/$branch_name"
        fi
    fi
    
    log_info "Pushing to GitHub (branch: $branch)..."
    git push -u origin "$branch"
    
    log_info "✅ Code pushed to GitHub successfully"
    echo ""
    
    if [ "$branch" != "main" ] && [ "$branch" != "develop" ]; then
        log_info "📝 Next step: Create a Pull Request"
        echo -e "${BLUE}Visit: https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/compare/${branch}?expand=1${NC}"
        echo ""
        log_info "After PR is merged, Jenkins will automatically:"
        echo "  1. Run security scans (TruffleHog, SonarQube)"
        echo "  2. Build Docker container"
        echo "  3. Run tests (5000+ test cases)"
        echo "  4. Scan container (Trivy)"
        echo "  5. Push to Azure Container Registry"
        echo "  6. Deploy to test environment"
        echo "  7. Run OWASP ZAP security tests"
    else
        log_info "🚀 Jenkins pipeline will be triggered automatically"
    fi
}

# Check Jenkins pipeline status
check_pipeline_status() {
    log_info "Checking Jenkins pipeline status..."
    
    # Try to get last build status
    if command -v curl &> /dev/null; then
        build_status=$(curl -s "${JENKINS_URL}/job/${APP_NAME}/lastBuild/api/json" | jq -r '.result' 2>/dev/null || echo "UNKNOWN")
        
        if [ "$build_status" != "UNKNOWN" ]; then
            echo -e "Pipeline Status: ${GREEN}${build_status}${NC}"
            echo -e "View details: ${BLUE}${JENKINS_URL}/job/${APP_NAME}${NC}"
        fi
    fi
}

# Main execution flow
main() {
    echo -e "${YELLOW}⚠️  IMPORTANT: This script ensures GitOps compliance${NC}"
    echo -e "${YELLOW}All deployments MUST go through GitHub → Jenkins → Azure${NC}"
    echo ""
    
    # Step 1: Check git status
    log_info "Step 1: Checking git repository status..."
    check_git_status
    
    # Step 2: Check for uncommitted changes
    log_info "Step 2: Checking for uncommitted changes..."
    check_uncommitted_changes
    
    # Step 3: Push to GitHub
    log_info "Step 3: Pushing to GitHub..."
    push_to_github
    
    # Step 4: Check pipeline status
    log_info "Step 4: Monitoring pipeline..."
    check_pipeline_status
    
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}✅ GitOps deployment initiated successfully${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo "📊 Monitor deployment:"
    echo "  - Jenkins: ${JENKINS_URL}/job/${APP_NAME}"
    echo "  - GitHub: https://github.com/${GITHUB_ORG}/${GITHUB_REPO}"
    echo "  - Azure Portal: https://portal.azure.com"
    echo ""
    echo "🔍 Check deployment status:"
    echo "  az container list --resource-group rg-secdevops-cicd-dev --output table"
    echo ""
}

# Show help if requested
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "GitOps Deployment Script for Oversight MVP"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "This script ensures all deployments follow GitOps principles:"
    echo "  1. Checks git repository status"
    echo "  2. Commits any uncommitted changes"
    echo "  3. Pushes to GitHub"
    echo "  4. Monitors Jenkins pipeline"
    echo ""
    echo "Environment Variables:"
    echo "  JENKINS_URL - Jenkins server URL (default: http://vm-jenkins-dev:8080)"
    echo ""
    exit 0
fi

# Run main function
main