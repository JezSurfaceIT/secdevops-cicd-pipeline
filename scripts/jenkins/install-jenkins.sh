#!/bin/bash
#
# Jenkins Installation Script
# STORY-003-01: Install and Configure Jenkins Master
# 
# This script installs Jenkins LTS on Ubuntu and configures it for production use
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Function to wait for Jenkins to be ready
wait_for_jenkins() {
    log_info "Waiting for Jenkins to start..."
    local timeout=300
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if curl -s http://localhost:8080/login > /dev/null 2>&1; then
            log_info "Jenkins is ready!"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    
    log_error "Jenkins failed to start within ${timeout} seconds"
    return 1
}

# Function to backup existing Jenkins if it exists
backup_existing_jenkins() {
    if [ -d "/var/lib/jenkins" ]; then
        log_warning "Existing Jenkins installation found. Creating backup..."
        local backup_dir="/var/backups/jenkins-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        cp -r /var/lib/jenkins/* "$backup_dir/" 2>/dev/null || true
        log_info "Backup created at: $backup_dir"
    fi
}

# Main installation function
install_jenkins() {
    log_info "Starting Jenkins installation..."
    
    # Update system
    log_info "Updating system packages..."
    apt-get update
    apt-get upgrade -y
    
    # Install required packages
    log_info "Installing required packages..."
    apt-get install -y \
        curl \
        git \
        wget \
        gnupg \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        lsb-release \
        net-tools
    
    # Install Java 17
    log_info "Installing OpenJDK 17..."
    apt-get install -y openjdk-17-jdk openjdk-17-jre
    
    # Verify Java installation
    java_version=$(java -version 2>&1 | head -n 1)
    log_info "Java installed: $java_version"
    
    # Set JAVA_HOME
    echo "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" >> /etc/environment
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
    
    # Add Jenkins repository
    log_info "Adding Jenkins repository..."
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
        /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
        https://pkg.jenkins.io/debian-stable binary/" | tee \
        /etc/apt/sources.list.d/jenkins.list > /dev/null
    
    # Update package list
    apt-get update
    
    # Install Jenkins
    log_info "Installing Jenkins..."
    apt-get install -y jenkins
    
    # Stop Jenkins for configuration
    systemctl stop jenkins
    
    log_info "Jenkins installation completed"
}

# Configure Jenkins settings
configure_jenkins() {
    log_info "Configuring Jenkins..."
    
    # Create Jenkins configuration directory
    mkdir -p /etc/systemd/system/jenkins.service.d
    
    # Configure Jenkins JVM options
    cat > /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Xmx2g -XX:+UseG1GC -Djenkins.install.runSetupWizard=false"
Environment="JENKINS_OPTS=--httpPort=8080 --prefix=/jenkins"
EOF
    
    # Update Jenkins default configuration
    cat > /etc/default/jenkins <<EOF
# Jenkins configuration
JAVA_ARGS="-Djava.awt.headless=true -Xmx2g -XX:+UseG1GC"
JENKINS_HOME=/var/lib/jenkins
JENKINS_USER=jenkins
JENKINS_GROUP=jenkins
JENKINS_PORT=8080
JENKINS_PREFIX=/jenkins
JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpPort=\$JENKINS_PORT --prefix=\$JENKINS_PREFIX"
EOF
    
    log_info "Jenkins configuration completed"
}

# Setup data disk for Jenkins home
setup_data_disk() {
    log_info "Setting up data disk for Jenkins home..."
    
    # Check if data disk exists (usually /dev/sdc on Azure)
    if [ -b /dev/sdc ]; then
        log_info "Data disk /dev/sdc found. Configuring..."
        
        # Create filesystem if not already present
        if ! blkid /dev/sdc | grep -q TYPE; then
            mkfs.ext4 /dev/sdc
        fi
        
        # Create mount point
        mkdir -p /mnt/jenkins
        
        # Mount the disk
        mount /dev/sdc /mnt/jenkins
        
        # Add to fstab for persistent mounting
        if ! grep -q "/dev/sdc" /etc/fstab; then
            echo "/dev/sdc /mnt/jenkins ext4 defaults,nofail 0 2" >> /etc/fstab
        fi
        
        # Move Jenkins home to data disk
        if [ -d "/var/lib/jenkins" ] && [ ! -L "/var/lib/jenkins" ]; then
            systemctl stop jenkins
            mv /var/lib/jenkins /mnt/jenkins/
            ln -s /mnt/jenkins/jenkins /var/lib/jenkins
            chown -R jenkins:jenkins /mnt/jenkins/jenkins
            chown -h jenkins:jenkins /var/lib/jenkins
        fi
        
        log_info "Data disk setup completed"
    else
        log_warning "No data disk found at /dev/sdc. Using default location."
    fi
}

# Install required Jenkins plugins
install_plugins() {
    log_info "Creating plugin installation list..."
    
    cat > /var/lib/jenkins/plugins.txt <<EOF
ace-editor
antisamy-markup-formatter
apache-httpcomponents-client-4-api
authentication-tokens
azure-credentials
azure-container-agents
blueocean
bootstrap5-api
bouncycastle-api
branch-api
build-timeout
caffeine-api
checks-api
cloudbees-folder
command-launcher
credentials
credentials-binding
display-url-api
docker-commons
docker-workflow
durable-task
echarts-api
email-ext
font-awesome-api
git
git-client
git-server
github
github-api
github-branch-source
gradle
handlebars
jackson2-api
javax-activation-api
javax-mail-api
jaxb
jdk-tool
jjwt-api
jquery3-api
jsch
junit
ldap
lockable-resources
mailer
matrix-auth
matrix-project
okhttp-api
pam-auth
pipeline-build-step
pipeline-github-lib
pipeline-graph-analysis
pipeline-input-step
pipeline-milestone-step
pipeline-model-api
pipeline-model-definition
pipeline-model-extensions
pipeline-rest-api
pipeline-stage-step
pipeline-stage-tags-metadata
pipeline-stage-view
plain-credentials
plugin-util-api
resource-disposer
scm-api
script-security
snakeyaml-api
sonar
ssh-credentials
ssh-slaves
sshd
structs
timestamper
token-macro
trilead-api
variant
workflow-aggregator
workflow-api
workflow-basic-steps
workflow-cps
workflow-durable-task-step
workflow-job
workflow-multibranch
workflow-scm-step
workflow-step-api
workflow-support
ws-cleanup
EOF
    
    # Create plugin installation script
    cat > /var/lib/jenkins/install-plugins.groovy <<'EOF'
import jenkins.model.*
import java.util.logging.Logger

def logger = Logger.getLogger("")
def installed = false
def pluginFile = new File('/var/lib/jenkins/plugins.txt')

if (pluginFile.exists()) {
    def plugins = pluginFile.readLines()
    def instance = Jenkins.getInstance()
    def pm = instance.getPluginManager()
    def uc = instance.getUpdateCenter()
    
    plugins.each { pluginName ->
        pluginName = pluginName.trim()
        if (pluginName && !pm.getPlugin(pluginName)) {
            logger.info("Installing plugin: ${pluginName}")
            def plugin = uc.getPlugin(pluginName)
            if (plugin) {
                plugin.deploy()
                installed = true
            }
        }
    }
    
    if (installed) {
        instance.save()
        logger.info("Plugins installation scheduled. Restart required.")
    }
}
EOF
    
    chown jenkins:jenkins /var/lib/jenkins/plugins.txt
    chown jenkins:jenkins /var/lib/jenkins/install-plugins.groovy
    
    log_info "Plugin list created. Plugins will be installed on first startup."
}

# Setup Jenkins backup
setup_backup() {
    log_info "Setting up Jenkins backup..."
    
    # Create backup script
    cat > /usr/local/bin/backup-jenkins.sh <<'EOF'
#!/bin/bash
#
# Jenkins Backup Script
#

BACKUP_DIR="/var/backups/jenkins"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="jenkins-backup-${TIMESTAMP}"
JENKINS_HOME="/var/lib/jenkins"
RETENTION_DAYS=7

# Create backup directory
mkdir -p ${BACKUP_DIR}

# Create backup
tar -czf ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz \
    --exclude='${JENKINS_HOME}/workspace' \
    --exclude='${JENKINS_HOME}/caches' \
    --exclude='${JENKINS_HOME}/logs' \
    ${JENKINS_HOME}

# Remove old backups
find ${BACKUP_DIR} -name "jenkins-backup-*.tar.gz" -mtime +${RETENTION_DAYS} -delete

echo "Backup completed: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
EOF
    
    chmod +x /usr/local/bin/backup-jenkins.sh
    
    # Create cron job for daily backup
    cat > /etc/cron.d/jenkins-backup <<EOF
# Jenkins daily backup at 2 AM
0 2 * * * root /usr/local/bin/backup-jenkins.sh >> /var/log/jenkins-backup.log 2>&1
EOF
    
    log_info "Backup configuration completed"
}

# Setup monitoring for Jenkins
setup_monitoring() {
    log_info "Setting up Jenkins monitoring..."
    
    # Create monitoring script
    cat > /usr/local/bin/monitor-jenkins.sh <<'EOF'
#!/bin/bash
#
# Jenkins Monitoring Script
#

JENKINS_URL="http://localhost:8080"
ALERT_EMAIL="admin@example.com"

# Check if Jenkins is running
if ! systemctl is-active --quiet jenkins; then
    echo "Jenkins service is not running" | mail -s "Jenkins Alert: Service Down" ${ALERT_EMAIL}
    systemctl start jenkins
fi

# Check if Jenkins is responding
if ! curl -s ${JENKINS_URL}/login > /dev/null; then
    echo "Jenkins is not responding on ${JENKINS_URL}" | mail -s "Jenkins Alert: Not Responding" ${ALERT_EMAIL}
fi

# Check disk usage
DISK_USAGE=$(df /var/lib/jenkins | tail -1 | awk '{print $5}' | sed 's/%//')
if [ ${DISK_USAGE} -gt 80 ]; then
    echo "Jenkins disk usage is ${DISK_USAGE}%" | mail -s "Jenkins Alert: High Disk Usage" ${ALERT_EMAIL}
fi
EOF
    
    chmod +x /usr/local/bin/monitor-jenkins.sh
    
    # Add to crontab for every 5 minutes
    cat > /etc/cron.d/jenkins-monitor <<EOF
# Monitor Jenkins every 5 minutes
*/5 * * * * root /usr/local/bin/monitor-jenkins.sh >> /var/log/jenkins-monitor.log 2>&1
EOF
    
    log_info "Monitoring setup completed"
}

# Main execution
main() {
    log_info "==================================="
    log_info "Jenkins Installation Script"
    log_info "==================================="
    
    # Check prerequisites
    check_root
    
    # Backup existing installation
    backup_existing_jenkins
    
    # Install Jenkins
    install_jenkins
    
    # Configure Jenkins
    configure_jenkins
    
    # Setup data disk
    setup_data_disk
    
    # Install plugins
    install_plugins
    
    # Setup backup
    setup_backup
    
    # Setup monitoring
    setup_monitoring
    
    # Reload systemd and start Jenkins
    log_info "Starting Jenkins service..."
    systemctl daemon-reload
    systemctl enable jenkins
    systemctl start jenkins
    
    # Wait for Jenkins to be ready
    if wait_for_jenkins; then
        # Get initial admin password
        if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
            log_info "==================================="
            log_info "Jenkins Initial Admin Password:"
            cat /var/lib/jenkins/secrets/initialAdminPassword
            log_info "==================================="
        fi
        
        log_info "Jenkins installation completed successfully!"
        log_info "Access Jenkins at: http://$(hostname -I | awk '{print $1}'):8080"
    else
        log_error "Jenkins installation completed but service failed to start properly"
        log_error "Check logs: journalctl -u jenkins -n 50"
        exit 1
    fi
}

# Run main function
main "$@"