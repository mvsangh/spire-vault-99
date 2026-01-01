# OpenBao JWT Authentication Troubleshooting Guide

## Problem: Backend Pod CrashLooping Due to JWT Authentication Failure

### Symptoms
- Backend pod status: `CrashLoopBackOff` or continuous restarts
- Health probes failing: `connection refused` on port 8000
- Error in logs: `permission denied` or `could not load configuration` when authenticating to OpenBao

### Quick Diagnosis

```bash
# Check pod status
kubectl get pods -n 99-apps -l app=backend

# Check recent logs
kubectl logs -n 99-apps -l app=backend --tail=50 | grep -i "vault\|error"
```

**Common Error Messages:**
1. `permission denied, on post https://openbao.../v1/auth/jwt/login` - JWT auth not enabled
2. `could not load configuration` - JWT auth enabled but not configured
3. `invalid issuer (iss) claim` - Issuer mismatch in configuration
4. `error checking oidc discovery URL` - OIDC discovery not working
5. `a user claim must be defined on the role` - Missing user_claim parameter

---

## Root Cause

After OpenBao re-initialization, authentication methods need to be reconfigured. The backend uses **JWT authentication** with SPIRE JWT-SVIDs, but this may not be set up after a fresh OpenBao init.

---

## Resolution Steps

### Prerequisites

Get the current root token:
```bash
# From init output or saved file
ROOT_TOKEN=$(cat /tmp/vault-root-token.txt)
```

Or if you have it saved elsewhere:
```bash
ROOT_TOKEN="s.xxxxxxxxxxxxxx"  # Update with your actual token
```

### Step 1: Verify OpenBao Status

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao status
```

Expected output:
- `Sealed: false` - If sealed, unseal first with 3 keys
- `Initialized: true`

### Step 2: Check Current Auth Methods

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao auth list
```

Look for `jwt/` in the output. If missing, proceed to Step 3.

### Step 3: Enable JWT Auth Method

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao auth enable jwt
```

Expected: `Success! Enabled jwt auth method at: jwt/`

### Step 4: Configure JWT Auth with SPIRE

**Important:** Use JWKS URL, NOT OIDC discovery (OIDC discovery has issues with HTTP/HTTPS mismatches).

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao write auth/jwt/config \
    jwks_url="http://spire-server.spire-system.svc.cluster.local:8090/keys"
```

**Note:** Do NOT set `bound_issuer` - it causes issues with SPIRE's issuer format.

Expected: `Success! Data written to: auth/jwt/config`

### Step 5: Create JWT Role for Backend

**CRITICAL:** The `user_claim="sub"` parameter is **REQUIRED**. This tells OpenBao which JWT claim to use as the user identity.

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao write auth/jwt/role/backend-role \
    role_type="jwt" \
    bound_audiences="openbao,vault" \
    bound_subject="spiffe://demo.local/ns/99-apps/sa/backend" \
    user_claim="sub" \
    token_policies="backend-policy" \
    token_ttl=3600 \
    token_max_ttl=7200
```

**Common mistake:** Omitting `user_claim="sub"` will result in error:
```
Error writing data to auth/jwt/role/backend-role: Error making API request.
Code: 400. Errors:
* a user claim must be defined on the role
```

Expected: `Success! Data written to: auth/jwt/role/backend-role`

### Step 6: Verify JWT Configuration

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao read auth/jwt/config
```

Verify:
- `jwks_url` is set to SPIRE endpoint
- `bound_issuer` is either empty or matches SPIRE issuer

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao read auth/jwt/role/backend-role
```

Verify:
- `user_claim` is set to `"sub"`
- `bound_subject` matches: `spiffe://demo.local/ns/99-apps/sa/backend`
- `token_policies` includes: `backend-policy`

### Step 7: Verify Backend Policy Exists

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao policy read backend-policy
```

If policy doesn't exist, recreate it:

```bash
cat > /tmp/backend-policy.hcl <<'EOF'
# Backend policy - allows access to secrets and database credentials

# Read/write access to KV v2 secrets (GitHub tokens)
path "secret/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

# Generate database credentials
path "database/creds/backend-role" {
  capabilities = ["read"]
}

# Allow revoking leases (for credential rotation cleanup)
path "sys/leases/revoke" {
  capabilities = ["update"]
}

# Renew own token
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

cat /tmp/backend-policy.hcl | kubectl exec -i -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao policy write backend-policy -
```

### Step 8: Verify Secrets Engines

Check KV v2 and database secrets engines are enabled:

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao secrets list
```

**Expected output should include:**
- `secret/` - KV v2 secrets engine (for GitHub tokens)
- `database/` - Database secrets engine (for dynamic PostgreSQL credentials)

#### If KV v2 secrets engine is missing:

**Error you might see in backend logs:**
```
ERROR - ❌ Failed to write secret to secret/data/github/user-7/token:
no handler for route "secret/data/github/user-7/token". route entry not found.
```

**Fix:**
```bash
# Enable KV v2 secrets engine at path "secret/"
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao secrets enable -path=secret kv-v2
```

Expected output: `Success! Enabled the kv-v2 secrets engine at: secret/`

#### If database secrets engine is missing:

```bash
# Enable database secrets engine
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao secrets enable database

# Configure PostgreSQL connection
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="backend-role" \
    connection_url="postgresql://{{username}}:{{password}}@postgresql.99-apps.svc.cluster.local:5432/appdb?sslmode=disable" \
    username="postgres" \
    password="postgres"

# Create database role
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao write database/roles/backend-role \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="2h"
```

### Step 9: Restart Backend Pod

```bash
kubectl delete pod -n 99-apps -l app=backend
```

Wait 10-15 seconds for the pod to restart.

### Step 10: Verify Backend Startup

```bash
kubectl logs -n 99-apps -l app=backend --tail=50 | grep -i "vault\|✅\|error"
```

Expected log sequence:
```
✅ SPIRE connected - SPIFFE ID: spiffe://demo.local/ns/99-apps/sa/backend
Connecting to Vault with SPIRE JWT-SVID (JWT auth)...
✅ JWT-SVID fetched successfully
✅ Vault authenticated (JWT) - Token TTL: 3600s
Vault policies: ['backend-policy', 'default']
✅ Database credentials obtained - User: v-jwt-spif-backend-...
✅ Database connected - Pool size: 10
✅ Credential rotation task started
```

### Step 11: Check Pod Status

```bash
kubectl get pods -n 99-apps -l app=backend
```

Expected:
- `STATUS: Running`
- `READY: 1/1`
- `RESTARTS: 0` (or low number)

---

## Troubleshooting Common Issues

### Issue 1: "a user claim must be defined on the role"

**Cause:** Missing `user_claim` parameter in JWT role creation

**Fix:**
```bash
# Delete the role and recreate with user_claim
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao delete auth/jwt/role/backend-role

# Recreate with user_claim="sub"
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao write auth/jwt/role/backend-role \
    role_type="jwt" \
    bound_audiences="openbao,vault" \
    bound_subject="spiffe://demo.local/ns/99-apps/sa/backend" \
    user_claim="sub" \
    token_policies="backend-policy" \
    token_ttl=3600 \
    token_max_ttl=7200
```

### Issue 2: "error checking oidc discovery URL"

**Cause:** Using `oidc_discovery_url` instead of `jwks_url`

**Fix:**
```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao write auth/jwt/config \
    jwks_url="http://spire-server.spire-system.svc.cluster.local:8090/keys"
```

### Issue 3: "invalid issuer (iss) claim"

**Cause:** `bound_issuer` doesn't match the actual JWT issuer

**Fix:** Remove bound_issuer from config:
```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao write auth/jwt/config \
    jwks_url="http://spire-server.spire-system.svc.cluster.local:8090/keys"
```

### Issue 4: "permission denied" after successful authentication

**Cause:** Policy not attached to JWT role or policy doesn't exist

**Fix:** Verify JWT role has correct policy:
```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao read auth/jwt/role/backend-role
```

Look for `token_policies: [backend-policy]`. If missing, recreate role (Step 5).

### Issue 5: SPIRE OIDC endpoint not accessible

**Test connectivity:**
```bash
kubectl exec -n openbao deploy/openbao -- \
  wget -O- http://spire-server.spire-system.svc.cluster.local:8090/.well-known/openid-configuration
```

If this fails:
1. Check SPIRE server is running: `kubectl get pods -n spire-system`
2. Verify SPIRE has OIDC provider sidecar:
   ```bash
   kubectl get pod -n spire-system spire-server-0 -o jsonpath='{.spec.containers[*].name}'
   ```
   - Should show: `spire-server oidc-discovery-provider`
3. Check SPIRE server logs:
   ```bash
   kubectl logs -n spire-system spire-server-0 -c oidc-discovery-provider
   ```

---

## Automated Configuration Script

Use the automated script to configure JWT auth:

```bash
chmod +x scripts/helpers/configure-openbao-jwt.sh
./scripts/helpers/configure-openbao-jwt.sh
```

This script handles all the steps above automatically.

---

## Complete Re-initialization Checklist

After re-initializing OpenBao, configure:

1. ✅ JWT auth method (for backend)
2. ✅ Cert auth method (optional, for X.509 certificates)
3. ✅ KV v2 secrets engine (for static secrets)
4. ✅ Database secrets engine (for dynamic credentials)
5. ✅ Backend policy
6. ✅ Database PostgreSQL connection
7. ✅ Database role

Use `scripts/helpers/init-vault-tls.sh` which handles most of this automatically.

---

## Quick Reference Commands

```bash
# Check OpenBao status
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao status

# Check JWT auth methods
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao auth list

# Check JWT configuration
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao read auth/jwt/config

# Check JWT role
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN="${ROOT_TOKEN}" \
  bao read auth/jwt/role/backend-role

# Check backend logs
kubectl logs -n 99-apps -l app=backend --tail=50

# Check backend pod status
kubectl get pods -n 99-apps -l app=backend

# Restart backend
kubectl delete pod -n 99-apps -l app=backend
```

---

## Understanding user_claim Parameter

The `user_claim` parameter specifies which claim from the JWT should be used as the user identity in OpenBao's audit logs and policies.

For SPIRE JWT-SVIDs:
- **`sub` (subject):** Contains the SPIFFE ID (e.g., `spiffe://demo.local/ns/99-apps/sa/backend`)
- **`aud` (audience):** List of intended audiences (e.g., `["openbao", "vault"]`)
- **`exp` (expiration):** Token expiration timestamp

**Why `sub`?**
- The SPIFFE ID in the `sub` claim uniquely identifies the workload
- It's the standard practice for SPIRE + Vault/OpenBao integration
- It provides meaningful identity in audit logs

**Example JWT payload from SPIRE:**
```json
{
  "sub": "spiffe://demo.local/ns/99-apps/sa/backend",
  "aud": ["openbao", "vault"],
  "exp": 1704153600,
  "iat": 1704150000
}
```

---

## Notes

- **Root token security:** In production, never use root token for application auth. This guide uses it for admin configuration only.
- **OIDC vs JWKS:** SPIRE's OIDC discovery has HTTP/HTTPS mismatches. Always use `jwks_url` instead.
- **Issuer validation:** SPIRE's JWT issuer format can vary. Removing `bound_issuer` allows more flexibility.
- **Demo environment:** These instructions are for the demo/test environment. Production requires proper secret management, auto-unseal, and HA configuration.

---

## Success Indicators

Backend is working correctly when:
1. Pod status: `Running` with `1/1` ready
2. No restarts or low restart count
3. Logs show: `✅ Vault authenticated (JWT)`
4. Logs show: `✅ Database credentials obtained`
5. Logs show: `✅ Database connected`
6. Health probes passing (no `connection refused` errors)
7. Health endpoint returns: `{"status":"ready","spire":"ready","vault":"ready","database":"ready"}`

---

**Last Updated:** 2026-01-01
**Tested With:** OpenBao 2.0.1, SPIRE 1.x, Kubernetes 1.x
**Related Docs:** `docs/QUICKSTART_DEPLOYMENT.md`, `docs/OPENBAO_TLS_SETUP.md`
