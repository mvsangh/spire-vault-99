# OpenBao TLS Mode - Manual Command Reference

Complete command guide for OpenBao initialization, unsealing, and configuration in TLS mode.

---

## 📋 Table of Contents

1. [Initial Deployment](#1-initial-deployment)
2. [Health Check & Status](#2-health-check--status)
3. [Initialize OpenBao](#3-initialize-openbao-first-time-only)
4. [Unseal OpenBao](#4-unseal-openbao-required-after-every-restart)
5. [Login & Authentication](#5-login--authentication)
6. [Configure Cert Auth (SPIRE)](#6-configure-cert-auth-spire)
7. [Configure Database Secrets Engine](#7-configure-database-secrets-engine)
8. [Configure KV Secrets Engine](#8-configure-kv-secrets-engine)
9. [Test Backend Connection](#9-test-backend-connection)
10. [Troubleshooting Commands](#10-troubleshooting-commands)
11. [Daily Operations](#11-daily-operations)

---

## 1. Initial Deployment

### Deploy OpenBao with TLS

```bash
# Apply TLS deployment
kubectl apply -f infrastructure/openbao/deployment-tls.yaml

# Check pod status
kubectl get pods -n openbao

# Watch pod logs
kubectl logs -n openbao -l app=openbao -f
```

### Port Forward for Local Access

```bash
# Port forward OpenBao (run in background or separate terminal)
kubectl port-forward -n openbao svc/openbao 8200:8200

# Set environment variables (in your terminal)
export VAULT_ADDR='https://127.0.0.1:8200'
export VAULT_SKIP_VERIFY='true'  # For self-signed certs
```

---

## 2. Health Check & Status

### Check OpenBao Status

```bash
# Check if OpenBao is initialized and sealed
kubectl exec -n openbao deploy/openbao -- bao status

# Expected output when sealed:
# Sealed: true
# Initialized: false (first time) or true (after init)
```

### Check via API

```bash
# Health endpoint (returns 503 when sealed, 200 when unsealed)
curl -k https://localhost:8200/v1/sys/health

# Sys/seal-status
curl -k https://localhost:8200/v1/sys/seal-status
```

---

## 3. Initialize OpenBao (First Time Only)

### Initialize with Shamir's Secret Sharing

```bash
# Initialize OpenBao (5 keys, 3 threshold)
kubectl exec -n openbao deploy/openbao -- bao operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > openbao-init-keys.json

# Display the keys and root token
cat openbao-init-keys.json | jq '.'
```

**Output will contain:**
- `unseal_keys_b64`: Array of 5 base64-encoded unseal keys
- `root_token`: Root authentication token

### Extract Keys for Easy Access

```bash
# Extract individual unseal keys
export UNSEAL_KEY_1=$(cat openbao-init-keys.json | jq -r '.unseal_keys_b64[0]')
export UNSEAL_KEY_2=$(cat openbao-init-keys.json | jq -r '.unseal_keys_b64[1]')
export UNSEAL_KEY_3=$(cat openbao-init-keys.json | jq -r '.unseal_keys_b64[2]')
export UNSEAL_KEY_4=$(cat openbao-init-keys.json | jq -r '.unseal_keys_b64[3]')
export UNSEAL_KEY_5=$(cat openbao-init-keys.json | jq -r '.unseal_keys_b64[4]')

# Extract root token
export ROOT_TOKEN=$(cat openbao-init-keys.json | jq -r '.root_token')

# Display for verification
echo "Root Token: $ROOT_TOKEN"
echo "Unseal Key 1: $UNSEAL_KEY_1"
echo "Unseal Key 2: $UNSEAL_KEY_2"
echo "Unseal Key 3: $UNSEAL_KEY_3"
```

### ⚠️ IMPORTANT: Backup Keys Securely

```bash
# Copy keys to a secure location (DO NOT COMMIT TO GIT)
cp openbao-init-keys.json ~/.openbao-keys-backup.json
chmod 600 ~/.openbao-keys-backup.json

# Or manually save the keys in a password manager
```

---

## 4. Unseal OpenBao (Required After Every Restart)

OpenBao starts **sealed** after every pod restart. You need 3 out of 5 keys to unseal.

### Unseal Commands

```bash
# Unseal with key 1
kubectl exec -n openbao deploy/openbao -- bao operator unseal $UNSEAL_KEY_1

# Unseal with key 2
kubectl exec -n openbao deploy/openbao -- bao operator unseal $UNSEAL_KEY_2

# Unseal with key 3 (OpenBao will be unsealed after this)
kubectl exec -n openbao deploy/openbao -- bao operator unseal $UNSEAL_KEY_3

# Verify unsealed status
kubectl exec -n openbao deploy/openbao -- bao status
# Should show: Sealed: false
```

### Quick Unseal Script

```bash
# If keys are in environment variables
for key in $UNSEAL_KEY_1 $UNSEAL_KEY_2 $UNSEAL_KEY_3; do
  kubectl exec -n openbao deploy/openbao -- bao operator unseal $key
done
```

---

## 5. Login & Authentication

### Login with Root Token

```bash
# Login to OpenBao
kubectl exec -n openbao deploy/openbao -- bao login $ROOT_TOKEN

# Or via port-forward
export VAULT_TOKEN=$ROOT_TOKEN
bao login $ROOT_TOKEN
```

---

## 6. Configure Cert Auth (SPIRE)

### Enable and Configure Certificate Authentication

```bash
# Enable cert auth method
kubectl exec -n openbao deploy/openbao -- bao auth enable cert

# Get SPIRE trust bundle (CA certificate)
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server bundle show -format pem > spire-bundle.pem

# Create cert auth role for backend
kubectl exec -n openbao deploy/openbao -- bao write auth/cert/certs/backend \
  certificate=@/dev/stdin \
  allowed_common_names="backend.99-apps" \
  token_ttl=3600 \
  token_policies="backend-policy" < spire-bundle.pem

# Verify cert auth is enabled
kubectl exec -n openbao deploy/openbao -- bao auth list
```

---

## 7. Configure Database Secrets Engine

### Enable and Configure PostgreSQL Dynamic Credentials

```bash
# Enable database secrets engine
kubectl exec -n openbao deploy/openbao -- bao secrets enable database

# Configure PostgreSQL connection
kubectl exec -n openbao deploy/openbao -- bao write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  allowed_roles="backend-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgresql.99-apps.svc.cluster.local:5432/appdb?sslmode=disable" \
  username="postgres" \
  password="postgres"

# Test connection
kubectl exec -n openbao deploy/openbao -- bao write -f database/rotate-root/postgresql

# Create backend role for dynamic credentials
kubectl exec -n openbao deploy/openbao -- bao write database/roles/backend-role \
  db_name=postgresql \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT CONNECT ON DATABASE appdb TO \"{{name}}\"; \
    GRANT USAGE ON SCHEMA public TO \"{{name}}\"; \
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Test credential generation
kubectl exec -n openbao deploy/openbao -- bao read database/creds/backend-role
```

---

## 8. Configure KV Secrets Engine

### Enable and Configure Key-Value v2 Secrets

```bash
# Enable KV v2 secrets engine
kubectl exec -n openbao deploy/openbao -- bao secrets enable -path=secret kv-v2

# Test: Write a sample secret
kubectl exec -n openbao deploy/openbao -- bao kv put secret/test key=value

# Test: Read the secret
kubectl exec -n openbao deploy/openbao -- bao kv get secret/test
```

---

## 9. Test Backend Connection

### Create Backend Policy

```bash
# Create policy for backend service
kubectl exec -n openbao deploy/openbao -- bao policy write backend-policy - <<EOF
# Database dynamic credentials
path "database/creds/backend-role" {
  capabilities = ["read"]
}

# KV v2 secrets (GitHub tokens, etc.)
path "secret/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/*" {
  capabilities = ["list", "read", "delete"]
}
EOF

# Verify policy
kubectl exec -n openbao deploy/openbao -- bao policy read backend-policy
```

### Restart Backend Pod

```bash
# Delete backend pod to trigger restart and reconnection
kubectl delete pod -n 99-apps -l app=backend

# Watch backend logs
kubectl logs -n 99-apps -l app=backend -f

# Expected: Should connect to OpenBao successfully
```

---

## 10. Troubleshooting Commands

### Check OpenBao Status

```bash
# Pod status
kubectl get pods -n openbao

# Detailed pod info
kubectl describe pod -n openbao -l app=openbao

# Logs
kubectl logs -n openbao -l app=openbao --tail=100

# Previous logs (if crashed)
kubectl logs -n openbao -l app=openbao --previous
```

### Check Seal Status

```bash
# Inside pod
kubectl exec -n openbao deploy/openbao -- bao status

# Via API
curl -k https://localhost:8200/v1/sys/seal-status | jq '.'
```

### Check Secrets Engines

```bash
# List all secrets engines
kubectl exec -n openbao deploy/openbao -- bao secrets list

# List all auth methods
kubectl exec -n openbao deploy/openbao -- bao auth list
```

### Check Policies

```bash
# List policies
kubectl exec -n openbao deploy/openbao -- bao policy list

# Read specific policy
kubectl exec -n openbao deploy/openbao -- bao policy read backend-policy
```

### Test Database Credentials

```bash
# Generate credentials
CREDS=$(kubectl exec -n openbao deploy/openbao -- bao read -format=json database/creds/backend-role)

# Extract username and password
DB_USER=$(echo $CREDS | jq -r '.data.username')
DB_PASS=$(echo $CREDS | jq -r '.data.password')

# Test connection
kubectl exec -n 99-apps postgresql-0 -- \
  psql -U $DB_USER -d appdb -c "SELECT current_user, current_database();"
```

### Check Backend Connectivity

```bash
# Check if backend can reach OpenBao
kubectl exec -n 99-apps -l app=backend -- \
  curl -k https://openbao.openbao.svc.cluster.local:8200/v1/sys/health

# Check backend logs for Vault errors
kubectl logs -n 99-apps -l app=backend | grep -i vault
```

---

## 11. Daily Operations

### Morning Checklist (After Cluster Restart)

```bash
# 1. Check if OpenBao is sealed
kubectl exec -n openbao deploy/openbao -- bao status

# 2. If sealed, unseal (requires 3 keys)
kubectl exec -n openbao deploy/openbao -- bao operator unseal $UNSEAL_KEY_1
kubectl exec -n openbao deploy/openbao -- bao operator unseal $UNSEAL_KEY_2
kubectl exec -n openbao deploy/openbao -- bao operator unseal $UNSEAL_KEY_3

# 3. Verify unsealed
kubectl exec -n openbao deploy/openbao -- bao status

# 4. Restart backend if needed
kubectl rollout restart -n 99-apps deployment/backend
```

### Quick Status Check

```bash
# One-liner status check
kubectl exec -n openbao deploy/openbao -- bao status && \
kubectl get pods -n openbao && \
kubectl get pods -n 99-apps
```

---

## 📝 Key Files Reference

| File | Purpose |
|------|---------|
| `openbao-init-keys.json` | **CRITICAL** - Contains unseal keys and root token |
| `~/.openbao-keys-backup.json` | Backup of init keys (secure location) |
| `spire-bundle.pem` | SPIRE CA certificate for cert auth |
| `infrastructure/openbao/deployment-tls.yaml` | OpenBao deployment manifest |
| `infrastructure/openbao/config-tls.yaml` | OpenBao configuration |

---

## 🔐 Security Best Practices

1. **Never commit** `openbao-init-keys.json` to git
2. **Backup unseal keys** to multiple secure locations
3. **Rotate root token** after initial setup
4. **Use policies** instead of root token for applications
5. **Enable audit logging** in production
6. **Use auto-unseal** (cloud KMS) in production

---

## 🚨 Emergency Recovery

### Lost Unseal Keys

If you lose unseal keys, you have two options:

1. **Restore from backup**: Use backed up `openbao-init-keys.json`
2. **Complete data loss**: Delete PVC and reinitialize (loses all secrets)

```bash
# Complete reset (DESTROYS ALL DATA)
kubectl delete pvc -n openbao openbao-data
kubectl delete pod -n openbao -l app=openbao
# Then reinitialize from scratch
```

### OpenBao Won't Start

```bash
# Check events
kubectl describe pod -n openbao -l app=openbao

# Check logs
kubectl logs -n openbao -l app=openbao

# Check TLS certificates
kubectl get secret -n openbao openbao-tls
kubectl exec -n openbao deploy/openbao -- ls -la /vault/tls

# Check config
kubectl get configmap -n openbao openbao-config -o yaml
```

---

## 📚 Additional Resources

- [OpenBao Documentation](https://openbao.org/docs/)
- [Vault Documentation](https://developer.hashicorp.com/vault/docs) (OpenBao is a fork)
- [SPIRE Integration Guide](https://spiffe.io/docs/latest/keyless/vault/)
- Project Docs: `docs/OPENBAO_TLS_SETUP.md`

---

**Generated:** 2025-12-31
**Project:** SPIRE-Vault-99
**Version:** OpenBao 2.0.1
