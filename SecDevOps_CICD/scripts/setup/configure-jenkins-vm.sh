#!/bin/bash
set -e

echo "======================================"
echo "Jenkins VM Configuration Script"
echo "======================================"

# Update system
echo "→ Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "→ Installing required packages..."
sudo apt install -y \
  curl \
  git \
  wget \
  software-properties-common \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release \
  unzip \
  jq

# Install Docker
echo "→ Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install Azure CLI
echo "→ Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Java (required for Jenkins)
echo "→ Installing Java 11..."
sudo apt install -y openjdk-11-jdk

# Add Jenkins repository and install Jenkins
echo "→ Installing Jenkins..."
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update
sudo apt install -y jenkins

# Configure firewall
echo "→ Configuring firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp
sudo ufw --force enable

# Configure Jenkins user
echo "→ Configuring Jenkins user..."
sudo usermod -aG docker jenkins

# Create Jenkins home directory structure
echo "→ Setting up Jenkins directories..."
sudo mkdir -p /var/jenkins_home
sudo chown -R jenkins:jenkins /var/jenkins_home

# Install Jenkins plugins (will be done via Jenkins UI or automation later)
echo "→ Creating plugin installation script..."
cat > /tmp/install-jenkins-plugins.sh << 'EOF'
#!/bin/bash
# This script will be used to install Jenkins plugins
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_TOKEN=""  # Will be set after initial setup

# List of essential plugins
PLUGINS=(
    "git"
    "github"
    "azure-credentials"
    "azure-container-registry-tasks"
    "docker-workflow"
    "pipeline"
    "workflow-aggregator"
    "credentials-binding"
    "timestamper"
    "ws-cleanup"
    "ant"
    "gradle"
    "nodejs"
)

echo "Plugins to be installed after Jenkins setup:"
for plugin in "${PLUGINS[@]}"; do
    echo "  - $plugin"
done
EOF
sudo chmod +x /tmp/install-jenkins-plugins.sh

# Install kubectl
echo "→ Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install Helm
echo "→ Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Terraform (for Jenkins to run Terraform jobs)
echo "→ Installing Terraform..."
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# Start and enable services
echo "→ Starting services..."
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Wait for Jenkins to start
echo "→ Waiting for Jenkins to start..."
sleep 30

# Get initial admin password
echo "======================================"
echo "Jenkins Initial Setup Information"
echo "======================================"
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "Initial Admin Password:"
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
    echo ""
    echo "Access Jenkins at: http://$(hostname -I | awk '{print $1}'):8080"
    echo "or using the FQDN configured in Azure"
else
    echo "Initial admin password file not found yet."
    echo "Check /var/lib/jenkins/secrets/initialAdminPassword after Jenkins fully starts"
fi

echo "======================================"
echo "VM Configuration Complete!"
echo "======================================"
echo ""
echo "Next Steps:"
echo "1. Access Jenkins web interface"
echo "2. Complete initial setup wizard"
echo "3. Install recommended plugins"
echo "4. Create admin user"
echo "5. Configure Azure credentials"
echo ""
echo "Security Reminder:"
echo "- Change default passwords"
echo "- Configure SSL/TLS"
echo "- Set up proper authentication"
echo "- Review and harden firewall rules"