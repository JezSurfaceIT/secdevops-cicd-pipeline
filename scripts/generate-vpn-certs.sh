#!/bin/bash

# Generate VPN certificates for Azure Point-to-Site connection

set -e

CERT_DIR="./certs"
ROOT_KEY="$CERT_DIR/vpn-root.key"
ROOT_CERT="$CERT_DIR/vpn-root.crt"
ROOT_CERT_B64="$CERT_DIR/vpn-root.cer"
CLIENT_KEY="$CERT_DIR/vpn-client.key"
CLIENT_CERT="$CERT_DIR/vpn-client.crt"
CLIENT_PFX="$CERT_DIR/vpn-client.pfx"

echo "🔑 Generating VPN certificates..."

# Create certificate directory
mkdir -p $CERT_DIR

# Generate root certificate private key
echo "📝 Generating root certificate..."
openssl genrsa -out $ROOT_KEY 4096

# Generate root certificate
openssl req -new -x509 -days 3650 -key $ROOT_KEY -out $ROOT_CERT \
    -subj "/C=US/ST=State/L=City/O=SecDevOps/CN=P2SRootCert"

# Convert root certificate to Base64 for Azure
openssl x509 -in $ROOT_CERT -outform der | base64 -w 0 > $ROOT_CERT_B64

echo "✅ Root certificate created: $ROOT_CERT"
echo "📄 Base64 root cert for Azure: $ROOT_CERT_B64"

# Generate client certificate private key
echo "📝 Generating client certificate..."
openssl genrsa -out $CLIENT_KEY 4096

# Generate client certificate request
openssl req -new -key $CLIENT_KEY -out $CERT_DIR/vpn-client.csr \
    -subj "/C=US/ST=State/L=City/O=SecDevOps/CN=P2SChildCert"

# Sign client certificate with root certificate
openssl x509 -req -in $CERT_DIR/vpn-client.csr -CA $ROOT_CERT -CAkey $ROOT_KEY \
    -CAcreateserial -out $CLIENT_CERT -days 365 \
    -extensions v3_req

# Create PFX for client (for Windows/Linux clients)
openssl pkcs12 -export -out $CLIENT_PFX \
    -inkey $CLIENT_KEY -in $CLIENT_CERT \
    -certfile $ROOT_CERT \
    -passout pass:secdevops

echo "✅ Client certificate created: $CLIENT_CERT"
echo "📦 Client PFX bundle: $CLIENT_PFX (password: secdevops)"

# Create Kali installation script
cat > $CERT_DIR/install-kali-vpn.sh << 'EOF'
#!/bin/bash

# Install VPN client certificates on Kali Linux

echo "📦 Installing OpenVPN and network-manager plugins..."
sudo apt-get update
sudo apt-get install -y openvpn network-manager-openvpn network-manager-openvpn-gnome

# Copy certificates to OpenVPN directory
sudo mkdir -p /etc/openvpn/client
sudo cp vpn-client.crt /etc/openvpn/client/
sudo cp vpn-client.key /etc/openvpn/client/
sudo cp vpn-root.crt /etc/openvpn/client/ca.crt

# Set permissions
sudo chmod 600 /etc/openvpn/client/vpn-client.key

echo "✅ Certificates installed"
echo "📝 Next steps:"
echo "1. Download VPN client configuration from Azure portal"
echo "2. Extract the OpenVPN configuration files"
echo "3. Import into Network Manager or use with openvpn command"
echo ""
echo "Manual connection command:"
echo "sudo openvpn --config <downloaded-config>.ovpn"
EOF

chmod +x $CERT_DIR/install-kali-vpn.sh

# Display certificate info
echo ""
echo "📋 Certificate Summary:"
echo "========================"
openssl x509 -in $ROOT_CERT -text -noout | grep -E "(Subject:|Not)"
echo ""
openssl x509 -in $CLIENT_CERT -text -noout | grep -E "(Subject:|Not)"
echo ""
echo "📁 All certificates saved in: $CERT_DIR/"
echo ""
echo "🔧 To install on Kali:"
echo "1. Copy $CERT_DIR to Kali machine"
echo "2. Run: cd $CERT_DIR && ./install-kali-vpn.sh"