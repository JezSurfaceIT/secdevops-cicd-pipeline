#!/bin/bash
#
# Jenkins SSL/TLS Configuration Script
# STORY-003-01: Configure HTTPS access for Jenkins
#
# This script sets up Nginx as a reverse proxy with SSL/TLS for Jenkins
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration variables
DOMAIN_NAME="${JENKINS_DOMAIN:-jenkins.local}"
JENKINS_PORT="${JENKINS_PORT:-8080}"
SSL_CERT_DIR="/etc/nginx/ssl"
NGINX_SITES_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Install Nginx if not present
install_nginx() {
    log_info "Checking Nginx installation..."
    
    if ! command -v nginx >/dev/null 2>&1; then
        log_info "Installing Nginx..."
        apt-get update
        apt-get install -y nginx certbot python3-certbot-nginx
    else
        log_info "Nginx is already installed"
    fi
    
    # Ensure Nginx is stopped during configuration
    systemctl stop nginx || true
}

# Generate self-signed certificate for testing
generate_self_signed_cert() {
    log_info "Generating self-signed SSL certificate for testing..."
    
    mkdir -p ${SSL_CERT_DIR}
    
    # Generate private key and certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ${SSL_CERT_DIR}/jenkins.key \
        -out ${SSL_CERT_DIR}/jenkins.crt \
        -subj "/C=GB/ST=London/L=London/O=SecDevOps/OU=IT/CN=${DOMAIN_NAME}"
    
    # Generate Diffie-Hellman parameters for enhanced security
    if [ ! -f ${SSL_CERT_DIR}/dhparam.pem ]; then
        log_info "Generating Diffie-Hellman parameters (this may take a while)..."
        openssl dhparam -out ${SSL_CERT_DIR}/dhparam.pem 2048
    fi
    
    # Set appropriate permissions
    chmod 600 ${SSL_CERT_DIR}/jenkins.key
    chmod 644 ${SSL_CERT_DIR}/jenkins.crt
    chmod 644 ${SSL_CERT_DIR}/dhparam.pem
    
    log_info "Self-signed certificate generated"
}

# Configure Nginx reverse proxy
configure_nginx_proxy() {
    log_info "Configuring Nginx reverse proxy for Jenkins..."
    
    # Create Jenkins Nginx configuration
    cat > ${NGINX_SITES_DIR}/jenkins <<EOF
# Upstream Jenkins server
upstream jenkins {
    keepalive 32;
    server 127.0.0.1:${JENKINS_PORT} max_fails=3 fail_timeout=30s;
}

# Map for WebSocket upgrade
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME};
    
    # Redirect all HTTP traffic to HTTPS
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server configuration
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN_NAME};
    
    # SSL Certificate configuration
    ssl_certificate ${SSL_CERT_DIR}/jenkins.crt;
    ssl_certificate_key ${SSL_CERT_DIR}/jenkins.key;
    
    # SSL Security configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Diffie-Hellman parameter
    ssl_dhparam ${SSL_CERT_DIR}/dhparam.pem;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Logging
    access_log /var/log/nginx/jenkins_access.log;
    error_log /var/log/nginx/jenkins_error.log;
    
    # Proxy configuration
    location / {
        proxy_pass http://jenkins;
        proxy_http_version 1.1;
        
        # Headers for Jenkins
        proxy_set_header Host \$host:\$server_port;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # WebSocket support for Jenkins CLI and Blue Ocean
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        
        # Increase timeouts for long-running Jenkins operations
        proxy_connect_timeout 90;
        proxy_send_timeout 90;
        proxy_read_timeout 90;
        
        # Disable buffering for Jenkins real-time console output
        proxy_buffering off;
        proxy_request_buffering off;
        
        # Increase buffer sizes
        proxy_buffer_size 4k;
        proxy_buffers 4 32k;
        proxy_busy_buffers_size 64k;
        
        # Maximum upload size (for plugins, artifacts, etc.)
        client_max_body_size 100M;
    }
    
    # Jenkins CLI endpoint
    location ~ "^/cli" {
        proxy_pass http://jenkins;
        proxy_http_version 1.1;
        proxy_set_header Host \$host:\$server_port;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Static resources caching
    location ~ "^/static/[0-9a-fA-F]{8}/(.*)" {
        proxy_pass http://jenkins;
        
        # Cache static resources
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    log_info "Nginx configuration created"
}

# Enable the Jenkins site
enable_jenkins_site() {
    log_info "Enabling Jenkins site..."
    
    # Remove default site if it exists
    rm -f ${NGINX_ENABLED_DIR}/default
    
    # Create symbolic link to enable Jenkins site
    ln -sf ${NGINX_SITES_DIR}/jenkins ${NGINX_ENABLED_DIR}/jenkins
    
    # Test Nginx configuration
    if nginx -t; then
        log_info "Nginx configuration test passed"
    else
        log_error "Nginx configuration test failed"
        exit 1
    fi
}

# Configure firewall rules
configure_firewall() {
    log_info "Configuring firewall rules..."
    
    # Check if ufw is installed and active
    if command -v ufw >/dev/null 2>&1; then
        # Allow SSH (should already be allowed)
        ufw allow 22/tcp
        
        # Allow HTTP and HTTPS
        ufw allow 80/tcp
        ufw allow 443/tcp
        
        # Deny direct access to Jenkins port from outside
        ufw deny ${JENKINS_PORT}/tcp
        
        log_info "Firewall rules configured"
    else
        log_warning "UFW not found. Please configure firewall manually."
    fi
}

# Create Let's Encrypt setup script for production
create_letsencrypt_script() {
    log_info "Creating Let's Encrypt setup script for production use..."
    
    cat > /usr/local/bin/setup-letsencrypt-jenkins.sh <<'EOF'
#!/bin/bash
#
# Let's Encrypt Certificate Setup for Jenkins
# Run this script when you have a valid domain pointing to this server
#

DOMAIN=$1
EMAIL=$2

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Usage: $0 <domain> <email>"
    echo "Example: $0 jenkins.example.com admin@example.com"
    exit 1
fi

# Install certbot if not present
apt-get update
apt-get install -y certbot python3-certbot-nginx

# Obtain certificate
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect

# Setup auto-renewal
cat > /etc/cron.d/letsencrypt-renewal <<CRON
# Renew Let's Encrypt certificates twice daily
0 0,12 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
CRON

echo "Let's Encrypt certificate setup completed for $DOMAIN"
EOF
    
    chmod +x /usr/local/bin/setup-letsencrypt-jenkins.sh
    
    log_info "Let's Encrypt setup script created at /usr/local/bin/setup-letsencrypt-jenkins.sh"
}

# Update Jenkins configuration for reverse proxy
update_jenkins_config() {
    log_info "Updating Jenkins configuration for reverse proxy..."
    
    # Update Jenkins arguments to work behind reverse proxy
    if [ -f /etc/default/jenkins ]; then
        # Backup original configuration
        cp /etc/default/jenkins /etc/default/jenkins.bak
        
        # Add proxy configuration
        if ! grep -q "httpListenAddress" /etc/default/jenkins; then
            echo 'JENKINS_ARGS="$JENKINS_ARGS --httpListenAddress=127.0.0.1"' >> /etc/default/jenkins
        fi
    fi
    
    # Restart Jenkins to apply changes
    systemctl restart jenkins
    
    log_info "Jenkins configuration updated"
}

# Verify SSL configuration
verify_ssl_setup() {
    log_info "Verifying SSL setup..."
    
    # Start Nginx
    systemctl start nginx
    systemctl enable nginx
    
    # Wait for services to be ready
    sleep 5
    
    # Test HTTPS connection
    if curl -k -s -o /dev/null -w "%{http_code}" https://localhost | grep -q "200\|403\|502"; then
        log_info "HTTPS connection successful"
    else
        log_warning "HTTPS connection test failed. Please check configuration."
    fi
    
    # Display SSL certificate information
    log_info "SSL Certificate Information:"
    openssl x509 -in ${SSL_CERT_DIR}/jenkins.crt -noout -subject -dates
}

# Main execution
main() {
    log_info "==================================="
    log_info "Jenkins SSL/TLS Configuration"
    log_info "==================================="
    
    check_root
    install_nginx
    generate_self_signed_cert
    configure_nginx_proxy
    enable_jenkins_site
    configure_firewall
    create_letsencrypt_script
    update_jenkins_config
    verify_ssl_setup
    
    log_info "==================================="
    log_info "SSL/TLS configuration completed!"
    log_info "==================================="
    log_info "Access Jenkins at: https://${DOMAIN_NAME}"
    log_info ""
    log_info "For production with a real domain:"
    log_info "Run: /usr/local/bin/setup-letsencrypt-jenkins.sh <domain> <email>"
    log_info ""
    log_info "To add the domain to your local hosts file:"
    log_info "echo '$(hostname -I | awk '{print $1}') ${DOMAIN_NAME}' >> /etc/hosts"
    log_info "==================================="
}

# Run main function
main "$@"