# OpenBao Production TLS Setup Guide

This guide explains how to deploy OpenBao with production-grade TLS configuration and enable SPIRE X.509 certificate authentication.

## Overview

The project supports two deployment modes for OpenBao:

### Dev Mode (HTTP - Default)
- **Protocol:** HTTP only
- **Authentication:** Root token
- **Storage:** In-memory (ephemeral)
- **TLS:** Disabled
- **Unsealing:** Auto-unsealed
- **Use case:** Quick development, testing

### Production Mode (HTTPS - TLS)
- **Protocol:** HTTPS with TLS
- **Authentication:** SPIRE X.509 certificates (mTLS)
- **Storage:** File-based persistent storage
- **TLS:** Enabled with proper certificates
- **Unsealing:** Manual unseal required after restart
- **Use case:** Production-like demo, security testing

## Architecture

```
┌──────────────┐
│   Backend    │
│   (Pod)      │
└──────┬───────┘
       │
       │ 1. Get X.509-SVID from SPIRE agent
       ▼
┌──────────────┐
│ SPIRE Agent  │
│ (DaemonSet)  │
└──────┬───────┘
       │ 2. Return X.509 certificate + private key
       ▼
┌──────────────┐
│   Backend    │ 3. Connect to OpenBao with SPIRE cert (mTLS)
└──────┬───────┘
       │
       │ HTTPS + Client Certificate
       ▼
┌──────────────┐
│   OpenBao    │ 4. Validate certificate against SPIRE trust bundle
│   (HTTPS)    │    Check SPIFFE ID matches policy
└──────┬───────┘
       │
       │ 5. Return Vault token
       ▼
┌──────────────┐
│   Backend    │ 6. Use token to access secrets
└──────────────┘
```

## Prerequisites

Before starting, ensure you have:
- ✅ Kubernetes cluster running (kind cluster "precinct-99")
- ✅ SPIRE deployed and healthy
- ✅ PostgreSQL deployed and initialized
- ✅ `kubectl`, `openssl` or `cfssl`, and `jq` installed

## Deployment Steps

### Step 1: Generate TLS Certificates

Generate self-signed CA and server certificates for OpenBao:

```bash
# Make script executable
chmod +x scripts/helpers/generate-vault-tls.sh

# Run certificate generation
./scripts/helpers/generate-vault-tls.sh
```

This script will:
- Create a self-signed CA certificate
- Generate server certificate for OpenBao with SANs:
  - `openbao`
  - `openbao.openbao`
  - `openbao.openbao.svc`
  - `openbao.openbao.svc.cluster.local`
  - `localhost`
- Create Kubernetes secret `openbao-tls` in `openbao` namespace
- Save CA certificate to `infrastructure/openbao/tls/ca.crt`

**Verification:**
```bash
kubectl get secret -n openbao openbao-tls
kubectl describe secret -n openbao openbao-tls
```

### Step 2: Create Vault CA ConfigMap

Create a ConfigMap with the OpenBao CA certificate for the backend to trust:

```bash
kubectl create configmap vault-ca \
  -n 99-apps \
  --from-file=ca.crt=infrastructure/openbao/tls/ca.crt
```

**Verification:**
```bash
kubectl get configmap -n 99-apps vault-ca
```

### Step 3: Deploy OpenBao with TLS

Deploy OpenBao in production mode with TLS:

```bash
# Apply configuration in order
kubectl apply -f infrastructure/openbao/pvc.yaml
kubectl apply -f infrastructure/openbao/config-configmap.yaml
kubectl apply -f infrastructure/openbao/deployment-tls.yaml
kubectl apply -f infrastructure/openbao/service.yaml
```

**Wait for pod to be ready:**
```bash
kubectl wait --for=condition=Ready pod -n openbao -l app=openbao --timeout=300s
```

**Check logs:**
```bash
kubectl logs -n openbao -l app=openbao --tail=50
```

You should see logs indicating OpenBao started in sealed state (not initialized yet).

### Step 4: Initialize and Configure OpenBao

Initialize OpenBao and configure all required auth methods and secrets engines:

```bash
# Make script executable
chmod +x scripts/helpers/init-vault-tls.sh

# Run initialization script
./scripts/helpers/init-vault-tls.sh
```

This script will:
1. ✅ Initialize OpenBao (generate 5 unseal keys + root token)
2. ✅ Unseal OpenBao (using 3 of 5 keys)
3. ✅ Enable cert auth method
4. ✅ Configure cert auth with SPIRE trust bundle
5. ✅ Enable KV v2 secrets engine at `secret/`
6. ✅ Enable database secrets engine
7. ✅ Configure PostgreSQL connection
8. ✅ Create database role `backend-role`
9. ✅ Create policy `backend-policy`
10. ✅ Test database credential generation

**⚠️ IMPORTANT:** The script will output unseal keys and root token. Save these securely!

The unseal keys and root token will be saved to:
- `/tmp/vault-unseal-keys.txt`
- `/tmp/vault-root-token.txt`

**For demo purposes**, you can save these to a safe location:

```bash
mkdir -p ~/.vault-demo
cp /tmp/vault-unseal-keys.txt ~/.vault-demo/
cp /tmp/vault-root-token.txt ~/.vault-demo/
chmod 600 ~/.vault-demo/*
```

### Step 5: Verify OpenBao Status

Check OpenBao is initialized and unsealed:

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao status
```

Expected output:
```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    5
Threshold       3
Version         2.0.1
```

### Step 6: Verify Cert Auth Configuration

Check cert auth is configured correctly:

```bash
# List auth methods
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao auth list

# Check cert auth role
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao read auth/cert/certs/backend-role
```

### Step 7: Update Backend Configuration

The backend configuration has already been updated to use HTTPS:
- `VAULT_ADDR=https://openbao.openbao.svc.cluster.local:8200`
- `VAULT_CACERT=/vault/tls/ca.crt`

Verify the ConfigMap:

```bash
kubectl get configmap -n 99-apps backend-config -o yaml
```

### Step 8: Deploy/Restart Backend

If using Tilt:

```bash
# Tilt will automatically rebuild and redeploy
# Just save any file or manually trigger rebuild
tilt trigger backend
```

If deploying manually:

```bash
kubectl delete pod -n 99-apps -l app=backend
kubectl wait --for=condition=Ready pod -n 99-apps -l app=backend --timeout=300s
```

### Step 9: Verify Backend Authentication

Check backend logs to verify it's authenticating with SPIRE certificate:

```bash
kubectl logs -n 99-apps -l app=backend --tail=100 | grep -i vault
```

Expected log messages:
```
INFO - Connecting to Vault with SPIRE certificate (HTTPS)...
INFO - ✅ Vault authenticated (cert) - Token TTL: 3600s
INFO - Vault policies: ['backend-policy']
INFO - ✅ Database credentials obtained - User: v-cert-backend-...
```

## Testing Authentication

### Test 1: Verify SPIRE Certificate

Check the backend has a valid SPIRE certificate:

```bash
# Get pod name
POD=$(kubectl get pod -n 99-apps -l app=backend -o jsonpath='{.items[0].metadata.name}')

# Check SPIFFE ID
kubectl exec -n 99-apps $POD -- \
  env SPIFFE_ENDPOINT_SOCKET=unix:///run/spire/sockets/agent.sock \
  /opt/spire/bin/spire-agent api fetch x509 -socketPath /run/spire/sockets/agent.sock
```

### Test 2: Test API Endpoints

```bash
# Health check
kubectl exec -n 99-apps $POD -- curl -s http://localhost:8000/api/v1/health | jq

# Database connection (via dynamic credentials)
kubectl exec -n 99-apps $POD -- curl -s http://localhost:8000/api/v1/health/ready | jq
```

### Test 3: Verify Database Credentials

Check that dynamic credentials are being generated:

```bash
# Check current database connections
kubectl exec -n 99-apps postgresql-0 -- \
  psql -U postgres -d appdb -c "SELECT usename, application_name FROM pg_stat_activity WHERE usename LIKE 'v-cert-%';"
```

You should see users like `v-cert-backend-role-<random>`.

## Unsealing After Restart

**Important:** Unlike dev mode, production OpenBao requires manual unsealing after each pod restart.

If OpenBao pod restarts (or you redeploy), it will start in sealed state:

```bash
# Check status
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao status

# Output will show: Sealed: true
```

To unseal:

```bash
# Unseal with 3 keys (you need to run this 3 times with different keys)
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao operator unseal <KEY_1>

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao operator unseal <KEY_2>

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao operator unseal <KEY_3>
```

Or use the helper script:

```bash
# Create unseal helper
cat > /tmp/unseal-vault.sh <<'EOF'
#!/bin/bash
export BAO_ADDR=https://127.0.0.1:8200
export BAO_SKIP_VERIFY=true

KEYS_FILE="${1:-$HOME/.vault-demo/vault-unseal-keys.txt}"

if [ ! -f "$KEYS_FILE" ]; then
    echo "Error: Unseal keys file not found: $KEYS_FILE"
    exit 1
fi

echo "Unsealing OpenBao..."
COUNTER=1
while read -r KEY && [ $COUNTER -le 3 ]; do
    echo "Unsealing with key $COUNTER/3..."
    kubectl exec -n openbao deploy/openbao -- \
        env BAO_ADDR=$BAO_ADDR BAO_SKIP_VERIFY=$BAO_SKIP_VERIFY \
        bao operator unseal "$KEY"
    COUNTER=$((COUNTER + 1))
done < "$KEYS_FILE"

echo "✅ OpenBao unsealed"
EOF

chmod +x /tmp/unseal-vault.sh
/tmp/unseal-vault.sh
```

## Switching Back to Dev Mode

If you need to switch back to dev mode (HTTP + auto-unseal):

```bash
# Delete production deployment
kubectl delete -f infrastructure/openbao/deployment-tls.yaml
kubectl delete -f infrastructure/openbao/config-configmap.yaml
kubectl delete pvc -n openbao openbao-data

# Deploy dev mode
kubectl apply -f infrastructure/openbao/deployment.yaml
kubectl apply -f infrastructure/openbao/service.yaml

# Update backend config
kubectl patch configmap -n 99-apps backend-config \
  --type merge \
  -p '{"data":{"VAULT_ADDR":"http://openbao.openbao.svc.cluster.local:8200"}}'

# Restart backend
kubectl delete pod -n 99-apps -l app=backend

# Reconfigure Vault (dev mode)
./scripts/helpers/configure-vault-backend.sh
```

## Troubleshooting

### Issue: OpenBao Pod CrashLoopBackOff

**Cause:** Missing TLS certificates or incorrect configuration.

**Solution:**
```bash
# Check if TLS secret exists
kubectl get secret -n openbao openbao-tls

# Check configmap
kubectl get configmap -n openbao openbao-config

# Check pod logs
kubectl logs -n openbao -l app=openbao
```

### Issue: Backend Can't Connect to Vault

**Cause:** Certificate verification failing or CA not mounted.

**Solution:**
```bash
# Check if vault-ca configmap exists in backend namespace
kubectl get configmap -n 99-apps vault-ca

# Check backend pod has volume mounted
kubectl describe pod -n 99-apps -l app=backend | grep -A 5 "vault-ca"

# Check backend logs
kubectl logs -n 99-apps -l app=backend | grep -i vault
```

### Issue: Cert Auth Login Failed

**Cause:** SPIRE trust bundle not configured or backend SPIFFE ID doesn't match policy.

**Solution:**
```bash
# Check SPIRE bundle is populated
kubectl get configmap -n spire-system spire-bundle -o yaml

# Check backend SPIFFE ID
kubectl exec -n 99-apps $POD -- cat /run/spire/sockets/agent.sock # Should exist

# Check cert auth configuration
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=<root-token> \
  bao read auth/cert/certs/backend-role
```

## Security Considerations

### For Production Deployments

This demo uses self-signed certificates and simplified configuration. For production:

1. **Use Proper PKI:**
   - Replace self-signed CA with certificates from your organization's PKI
   - Use cert-manager or external CA for automated certificate management
   - Implement certificate rotation

2. **Vault High Availability:**
   - Deploy multiple OpenBao replicas with Raft or Consul storage
   - Use load balancer for OpenBao service
   - Implement automated unsealing (Transit seal, Cloud KMS)

3. **Secure Unseal Keys:**
   - Use Shamir's Secret Sharing with distributed key holders
   - Store keys in hardware security modules (HSM)
   - Implement automated unsealing with cloud KMS (AWS KMS, Azure Key Vault, GCP KMS)

4. **TLS Configuration:**
   - Enable `verify=True` with proper CA bundle
   - Use production-grade certificates (not self-signed)
   - Enable mTLS for all connections

5. **RBAC and Policies:**
   - Create fine-grained policies (not wildcard access)
   - Implement least-privilege access
   - Use namespaces for multi-tenancy

6. **Monitoring and Auditing:**
   - Enable audit logging
   - Monitor OpenBao metrics
   - Set up alerts for seal status, auth failures, etc.

## Additional Resources

- [OpenBao Documentation](https://openbao.org/docs/)
- [SPIRE Documentation](https://spiffe.io/docs/latest/spire/)
- [SPIFFE Cert Auth](https://spiffe.io/docs/latest/keyless/vault/)
- [Vault Production Hardening](https://www.vaultproject.io/docs/platform/k8s/helm/configuration)

## Summary

You now have:
- ✅ Production-grade OpenBao with TLS
- ✅ SPIRE X.509 certificate authentication (mTLS)
- ✅ Persistent storage for OpenBao data
- ✅ Backend authenticating with workload identity (not root token)
- ✅ Dynamic database credentials via Vault
- ✅ Zero-trust security architecture

This demonstrates production-ready workload identity and secrets management in a Kubernetes environment!
