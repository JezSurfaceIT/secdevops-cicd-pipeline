# Azure Test Environment - HashiCorp Vault Configuration
## Runtime Secrets Management for Test Environment

**Version:** 1.0  
**Date:** 2025-09-21  
**Status:** Implementation Ready

---

## 🔐 HashiCorp Vault Setup for Azure Test

### Vault Deployment in Azure

```yaml
# vault-azure-deployment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: vault-system
---
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: vault-system
spec:
  type: LoadBalancer
  ports:
    - port: 8200
      targetPort: 8200
      name: vault
    - port: 8201
      targetPort: 8201
      name: cluster
  selector:
    app: vault
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vault
  namespace: vault-system
spec:
  serviceName: vault
  replicas: 1
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      containers:
      - name: vault
        image: vault:1.13.3
        command:
          - vault
          - server
          - -config=/vault/config/vault.hcl
        env:
        - name: VAULT_API_ADDR
          value: "http://0.0.0.0:8200"
        - name: SKIP_CHOWN
          value: "true"
        - name: SKIP_SETCAP
          value: "true"
        - name: VAULT_CLUSTER_ADDR
          value: "http://vault:8201"
        - name: VAULT_LOG_LEVEL
          value: "info"
        ports:
        - containerPort: 8200
          name: vault
        - containerPort: 8201
          name: cluster
        volumeMounts:
        - name: vault-config
          mountPath: /vault/config
        - name: vault-data
          mountPath: /vault/data
        livenessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true
            port: 8200
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true
            port: 8200
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: vault-config
        configMap:
          name: vault-config
  volumeClaimTemplates:
  - metadata:
      name: vault-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: managed-premium
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: vault-system
data:
  vault.hcl: |
    ui = true
    
    listener "tcp" {
      tls_disable = 1
      address = "[::]:8200"
      cluster_address = "[::]:8201"
    }
    
    storage "file" {
      path = "/vault/data"
    }
    
    # Azure auth backend configuration
    auth "azure" {
      mount_path = "auth/azure"
      config = {
        tenant_id = "${AZURE_TENANT_ID}"
        resource = "https://management.azure.com/"
        client_id = "${AZURE_CLIENT_ID}"
        client_secret = "${AZURE_CLIENT_SECRET}"
      }
    }
```

### Initialize and Configure Vault

```bash
#!/bin/bash
# scripts/vault/initialize-vault-azure-test.sh

set -e

VAULT_POD=$(kubectl get pod -n vault-system -l app=vault -o jsonpath='{.items[0].metadata.name}')
VAULT_SERVICE_IP=$(kubectl get service vault -n vault-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "🔐 Initializing HashiCorp Vault for Azure Test Environment"
echo "Vault Service IP: $VAULT_SERVICE_IP"

# Initialize Vault
kubectl exec -n vault-system $VAULT_POD -- vault operator init \
    -key-shares=5 \
    -key-threshold=3 \
    -format=json > vault-init.json

# Extract root token and unseal keys
export VAULT_ROOT_TOKEN=$(jq -r '.root_token' vault-init.json)
export UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' vault-init.json)
export UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' vault-init.json)
export UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' vault-init.json)

# Unseal Vault
echo "Unsealing Vault..."
kubectl exec -n vault-system $VAULT_POD -- vault operator unseal $UNSEAL_KEY_1
kubectl exec -n vault-system $VAULT_POD -- vault operator unseal $UNSEAL_KEY_2
kubectl exec -n vault-system $VAULT_POD -- vault operator unseal $UNSEAL_KEY_3

# Configure Vault
export VAULT_ADDR="http://$VAULT_SERVICE_IP:8200"
export VAULT_TOKEN=$VAULT_ROOT_TOKEN

echo "Configuring Vault policies and secrets..."

# Enable KV secrets engine
vault secrets enable -path=oversight-test kv-v2

# Create test environment secrets
vault kv put oversight-test/config \
    db_host="postgres-test.postgres.database.azure.com" \
    db_port="5432" \
    db_name="oversight_test" \
    db_user="oversight_app" \
    db_password="$(openssl rand -base64 32)" \
    jwt_secret="$(openssl rand -base64 64)" \
    session_secret="$(openssl rand -base64 32)" \
    api_key="$(uuidgen)" \
    file_storage_connection="DefaultEndpointsProtocol=https;AccountName=oversightstorage;AccountKey=$(openssl rand -base64 32)" \
    redis_url="redis://redis-test:6379"

# Create policy for test application
cat > test-app-policy.hcl << EOF
path "oversight-test/*" {
  capabilities = ["read", "list"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

vault policy write oversight-test-app test-app-policy.hcl

# Create role for Kubernetes service account
vault auth enable kubernetes

vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"

vault write auth/kubernetes/role/oversight-test \
    bound_service_account_names=oversight-app \
    bound_service_account_namespaces=test-environment \
    policies=oversight-test-app \
    ttl=24h

echo "✅ Vault initialized and configured for Azure Test Environment"
echo ""
echo "Vault Address: $VAULT_ADDR"
echo "Root Token: $VAULT_ROOT_TOKEN (store securely)"
echo ""
echo "Save vault-init.json in a secure location!"
```

### Test Application Configuration with Vault

```yaml
# oversight-test-deployment-with-vault.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: oversight-app
  namespace: test-environment
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oversight-mvp-test
  namespace: test-environment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: oversight-mvp
  template:
    metadata:
      labels:
        app: oversight-mvp
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/agent-inject-secret-config: "oversight-test/config"
        vault.hashicorp.com/agent-inject-template-config: |
          {{- with secret "oversight-test/config" -}}
          export DB_HOST="{{ .Data.data.db_host }}"
          export DB_PORT="{{ .Data.data.db_port }}"
          export DB_NAME="{{ .Data.data.db_name }}"
          export DB_USER="{{ .Data.data.db_user }}"
          export DB_PASSWORD="{{ .Data.data.db_password }}"
          export JWT_SECRET="{{ .Data.data.jwt_secret }}"
          export SESSION_SECRET="{{ .Data.data.session_secret }}"
          export API_KEY="{{ .Data.data.api_key }}"
          export FILE_STORAGE_CONNECTION="{{ .Data.data.file_storage_connection }}"
          export REDIS_URL="{{ .Data.data.redis_url }}"
          {{- end }}
        vault.hashicorp.com/role: "oversight-test"
    spec:
      serviceAccountName: oversight-app
      containers:
      - name: oversight-app
        image: acrsecdevopsdev.azurecr.io/oversight-mvp:latest
        command: ["/bin/sh"]
        args: 
        - -c
        - |
          source /vault/secrets/config
          node server.js
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "test"
        - name: PORT
          value: "3000"
        - name: VAULT_ADDR
          value: "http://vault.vault-system:8200"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
```

### Runtime Secret Injection Script

```typescript
// scripts/vault/vault-secret-injector.ts
import { VaultClient } from 'node-vault';

export class VaultSecretInjector {
  private client: VaultClient;
  
  constructor() {
    this.client = new VaultClient({
      endpoint: process.env.VAULT_ADDR || 'http://vault:8200',
      token: process.env.VAULT_TOKEN
    });
  }
  
  async injectSecrets(environment: string = 'test') {
    console.log('🔐 Fetching secrets from HashiCorp Vault...');
    
    try {
      // Get secrets from Vault
      const response = await this.client.read(`oversight-${environment}/config`);
      const secrets = response.data.data;
      
      // Inject into process environment
      Object.keys(secrets).forEach(key => {
        const envKey = key.toUpperCase();
        process.env[envKey] = secrets[key];
        console.log(`✓ Injected ${envKey}`);
      });
      
      // Build DATABASE_URL from components
      process.env.DATABASE_URL = `postgresql://${secrets.db_user}:${secrets.db_password}@${secrets.db_host}:${secrets.db_port}/${secrets.db_name}?sslmode=require`;
      
      console.log('✅ All secrets injected successfully');
      
      // Setup auto-renewal
      this.setupAutoRenewal();
      
    } catch (error) {
      console.error('❌ Failed to fetch secrets from Vault:', error);
      throw error;
    }
  }
  
  private setupAutoRenewal() {
    // Renew token before expiry
    setInterval(async () => {
      try {
        await this.client.tokenRenewSelf();
        console.log('🔄 Vault token renewed');
      } catch (error) {
        console.error('Failed to renew token:', error);
      }
    }, 3600000); // Every hour
  }
  
  async rotateSecrets() {
    console.log('🔄 Rotating secrets...');
    
    // Generate new secrets
    const newSecrets = {
      db_password: this.generatePassword(),
      jwt_secret: this.generateSecret(),
      session_secret: this.generateSecret(),
      api_key: this.generateUUID()
    };
    
    // Update in Vault
    await this.client.write('oversight-test/config', newSecrets);
    
    // Re-inject new secrets
    await this.injectSecrets('test');
    
    console.log('✅ Secrets rotated successfully');
  }
  
  private generatePassword(): string {
    return require('crypto').randomBytes(32).toString('base64');
  }
  
  private generateSecret(): string {
    return require('crypto').randomBytes(64).toString('base64');
  }
  
  private generateUUID(): string {
    return require('uuid').v4();
  }
}

// Use in application startup
const secretInjector = new VaultSecretInjector();
await secretInjector.injectSecrets('test');

// Export for use in app
export default secretInjector;
```

### Jenkins Pipeline Integration

```groovy
// Jenkinsfile - Vault integration for test environment
stage('Deploy to Test with Vault') {
    steps {
        script {
            withCredentials([
                string(credentialsId: 'vault-token', variable: 'VAULT_TOKEN')
            ]) {
                sh '''
                    # Set Vault address
                    export VAULT_ADDR="http://vault.vault-system:8200"
                    
                    # Deploy application with Vault integration
                    kubectl apply -f oversight-test-deployment-with-vault.yaml
                    
                    # Wait for Vault sidecar to inject secrets
                    sleep 10
                    
                    # Verify deployment
                    kubectl wait --for=condition=ready pod \
                        -l app=oversight-mvp \
                        -n test-environment \
                        --timeout=300s
                '''
            }
        }
    }
}
```

### Vault UI Access

```yaml
# vault-ui-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault-ui
  namespace: vault-system
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - vault-test.oversight.io
    secretName: vault-ui-tls
  rules:
  - host: vault-test.oversight.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: vault
            port:
              number: 8200
```

---

## 🚀 Quick Commands

### Access Vault UI
```bash
# Port forward for local access
kubectl port-forward -n vault-system service/vault 8200:8200

# Open browser
open http://localhost:8200

# Or use public URL if ingress configured
open https://vault-test.oversight.io
```

### Manage Secrets
```bash
# Login to Vault
export VAULT_ADDR="http://vault-test.oversight.io"
vault login $VAULT_TOKEN

# View secrets
vault kv get oversight-test/config

# Update a secret
vault kv patch oversight-test/config db_password="new-password"

# Rotate all secrets
./scripts/vault/rotate-test-secrets.sh
```

### Monitor Vault
```bash
# Check Vault status
vault status

# View audit logs
vault audit list

# Check token TTL
vault token lookup
```

---

## 🔐 Security Best Practices

1. **Never store Vault root token in code**
2. **Use Kubernetes service accounts for authentication**
3. **Enable audit logging**
4. **Rotate secrets regularly**
5. **Use least privilege policies**
6. **Enable TLS in production**
7. **Backup Vault data regularly**
8. **Monitor token expiration**

---

This configuration ensures the Azure test environment uses HashiCorp Vault for runtime secrets management, maintaining consistency with the CBE approach while keeping SaaS on Azure Secrets Manager.