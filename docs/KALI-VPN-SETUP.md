# Kali Linux VPN Connection Setup Guide

## Overview
This guide provides step-by-step instructions for connecting your Kali Linux penetration testing machine to the Azure test environment through a Point-to-Site VPN.

## Prerequisites
- Kali Linux machine at IP: 192.168.1.100
- OpenVPN client installed
- Access to Azure portal or Azure CLI
- VPN Gateway deployed in Azure (see `/scripts/setup-vpn-gateway.sh`)

## Network Architecture
```
Kali Linux (192.168.1.100) 
    ↓
VPN Connection (172.16.0.0/24)
    ↓
Azure VPN Gateway
    ↓
Test Environment (10.40.1.0/24)
    - Test App: 10.40.1.10
    - Test DB: 10.40.1.20
```

## Step 1: Install VPN Client Software

```bash
# Update package list
sudo apt-get update

# Install OpenVPN and NetworkManager plugins
sudo apt-get install -y openvpn 
sudo apt-get install -y network-manager-openvpn 
sudo apt-get install -y network-manager-openvpn-gnome
```

## Step 2: Generate and Install Certificates

### On the deployment machine:
```bash
# Generate certificates
cd /home/jez/code/SecDevOps_CICD/scripts
./generate-vpn-certs.sh

# Copy certs folder to Kali
scp -r certs/ kali@192.168.1.100:/tmp/
```

### On Kali machine:
```bash
# Install certificates
cd /tmp/certs
sudo mkdir -p /etc/openvpn/client
sudo cp vpn-client.crt /etc/openvpn/client/
sudo cp vpn-client.key /etc/openvpn/client/
sudo cp vpn-root.crt /etc/openvpn/client/ca.crt
sudo chmod 600 /etc/openvpn/client/vpn-client.key
```

## Step 3: Download VPN Client Configuration

### Using Azure CLI:
```bash
# Generate VPN client package
az network vnet-gateway vpn-client generate \
    --resource-group secdevops-rg \
    --name vpn-secdevops \
    --processor-architecture Amd64

# Download the configuration
az network vnet-gateway vpn-client show-url \
    --resource-group secdevops-rg \
    --name vpn-secdevops
```

### Using Azure Portal:
1. Navigate to: Azure Portal → Virtual Network Gateways → vpn-secdevops
2. Click "Point-to-site configuration"
3. Click "Download VPN client"
4. Extract the downloaded ZIP file

## Step 4: Configure OpenVPN Connection

### Extract and modify configuration:
```bash
# Extract downloaded package
unzip vpnclientconfiguration.zip
cd OpenVPN

# Copy the configuration file
sudo cp vpnconfig.ovpn /etc/openvpn/client/azure.conf

# Edit the configuration to use our certificates
sudo nano /etc/openvpn/client/azure.conf
```

Modify these lines in the configuration:
```
cert /etc/openvpn/client/vpn-client.crt
key /etc/openvpn/client/vpn-client.key
ca /etc/openvpn/client/ca.crt
```

## Step 5: Connect to VPN

### Method 1: Command Line
```bash
# Connect to VPN
sudo openvpn --config /etc/openvpn/client/azure.conf

# Run in background
sudo openvpn --config /etc/openvpn/client/azure.conf --daemon
```

### Method 2: NetworkManager GUI
1. Open NetworkManager settings
2. Add new VPN connection → Import from file
3. Select the `.ovpn` configuration file
4. Enter certificate paths when prompted
5. Connect through the network icon

## Step 6: Verify Connection

```bash
# Check VPN interface
ip addr show | grep tun

# You should see an interface like:
# tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> 
# inet 172.16.0.2/24 scope global tun0

# Test connectivity to test environment
ping 10.40.1.10  # Test app server
ping 10.40.1.20  # Test database

# Test web application
curl http://10.40.1.10/health

# Test with penetration tools
nmap -p 80,443,3306 10.40.1.10
```

## Step 7: Penetration Testing

Once connected, you can perform security testing:

```bash
# Network discovery
nmap -sn 10.40.1.0/24

# Service enumeration
nmap -sV -p- 10.40.1.10

# Web application scanning
nikto -h http://10.40.1.10

# SQL injection testing
sqlmap -u "http://10.40.1.10/api/users?id=1" --batch

# Metasploit framework
msfconsole
use auxiliary/scanner/http/dir_scanner
set RHOSTS 10.40.1.10
run
```

## Troubleshooting

### Connection Issues
```bash
# Check VPN logs
sudo journalctl -u openvpn@azure -f

# Verify certificate validity
openssl x509 -in /etc/openvpn/client/vpn-client.crt -text -noout

# Test DNS resolution
nslookup test-app.internal
```

### Permission Errors
```bash
# Fix certificate permissions
sudo chown root:root /etc/openvpn/client/*
sudo chmod 644 /etc/openvpn/client/*.crt
sudo chmod 600 /etc/openvpn/client/*.key
```

### Route Issues
```bash
# Check routing table
ip route | grep tun

# Add manual route if needed
sudo ip route add 10.40.1.0/24 dev tun0
```

## Disconnecting

```bash
# If running in foreground: Press Ctrl+C

# If running as daemon
sudo pkill openvpn

# Or using systemctl
sudo systemctl stop openvpn@azure
```

## Automation Script

Create `/usr/local/bin/connect-azure-vpn`:
```bash
#!/bin/bash
echo "🔌 Connecting to Azure Test Environment VPN..."
sudo openvpn --config /etc/openvpn/client/azure.conf --daemon
sleep 5
if ip addr show | grep -q "tun0"; then
    echo "✅ VPN connected successfully"
    echo "📍 VPN IP: $(ip addr show tun0 | grep inet | awk '{print $2}')"
    echo "🎯 Testing connectivity..."
    ping -c 1 10.40.1.10 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Can reach test environment"
    else
        echo "❌ Cannot reach test environment"
    fi
else
    echo "❌ VPN connection failed"
    exit 1
fi
```

Make it executable:
```bash
sudo chmod +x /usr/local/bin/connect-azure-vpn
```

## Security Notes

1. **Certificate Security**: Keep private keys secure and never share them
2. **Access Control**: VPN access is restricted to authorized penetration testing
3. **Audit Logging**: All VPN connections are logged in Azure
4. **Time Restrictions**: Disconnect when testing is complete
5. **Scope Limits**: Only test authorized systems within 10.40.1.0/24

## Support

For issues or questions:
- Check Azure VPN Gateway logs in Azure Portal
- Review OpenVPN client logs: `sudo journalctl -u openvpn -f`
- Verify network connectivity: `traceroute 10.40.1.10`