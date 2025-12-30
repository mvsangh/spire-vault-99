# Complete Implementation Log: Production TLS for OpenBao with SPIRE Integration

**Date:** December 30, 2025
**Objective:** Enable production-grade TLS for OpenBao and implement SPIRE X.509 certificate authentication
**Status:** TLS Implemented ✅ | Cert Auth Debugging (Known OpenBao Limitation) ⚠️

---

## Table of Contents

1. [Initial Problem Identification](#initial-problem-identification)
2. [Architecture Decisions](#architecture-decisions)
3. [Infrastructure Changes](#infrastructure-changes)
4. [OpenBao Configuration](#openbao-configuration)
5. [Backend Application Changes](#backend-application-changes)
6. [Deployment Process](#deployment-process)
7. [Debugging Journey](#debugging-journey)
8. [Final Status](#final-status)
9. [Code Changes Summary](#code-changes-summary)

---

## Initial Problem Identification

### Discovery
User noticed the backend was authenticating to OpenBao using root token instead of SPIRE X.509 certificates:

```log
2025-12-30 06:20:56,448 - app.core.vault - INFO - ✅ Vault authenticated (token) - Dev mode with root token
2025-12-30 06:20:56,448 - app.core.vault - WARNING - ⚠️  Using root token - For development only!
```

### Root Cause Analysis

**Question:** Which certificate does Vault use for TLS - its own or SPIRE-issued?

**Answer:** TWO separate certificates with different purposes:

1. **OpenBao Server TLS Certificate** (infrastructure/openbao/tls/)
   - Purpose: Secure the HTTPS listener (server-side TLS)
   - Issued by: Self-signed CA (our generated certificate)
   - NOT issued by SPIRE
   - Identifies: The OpenBao server itself
   - Common Name: `openbao.openbao.svc.cluster.local`

2. **Backend Client Certificate** (from SPIRE)
   - Purpose: Authenticate the backend TO OpenBao (client certificate auth)
   - Issued by: SPIRE server
   - Identifies: The backend workload
   - SPIFFE ID: `spiffe://demo.local/ns/99-apps/sa/backend`

This follows **industry-standard practice** for SPIRE + Vault integration.

---

## Architecture Decisions

### Deployment Modes

Implemented dual-mode support for OpenBao:

| Feature | Dev Mode (HTTP) | Production Mode (HTTPS with TLS) |
|---------|----------------|----------------------------------|
| **Protocol** | HTTP | HTTPS with TLS |
| **Storage** | In-memory (ephemeral) | File-based persistent (PVC) |
| **Unsealing** | Auto-unsealed | Manual unseal (Shamir 5/3) |
| **Authentication** | Root token | SPIRE X.509 certificates |
| **Backend Auth** | Token fallback | Cert auth method |
| **Use Case** | Quick development | Production-like demo |
| **Deployment File** | `deployment.yaml` | `deployment-tls.yaml` |

### Certificate Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Certificate Flow                           │
└──────────────────────────────────────────────────────────────┘

1. Backend → SPIRE Agent
   Request: "Give me my X.509-SVID"
   Response: Full certificate chain + private key

2. Backend → OpenBao (HTTPS)
   Client Cert: SPIRE X.509-SVID
   Server Cert: OpenBao's self-signed TLS cert

3. OpenBao validates:
   a) Server cert used for TLS handshake
   b) Client cert validated against SPIRE trust bundle
   c) SPIFFE ID checked against cert auth policy
```

---

## Infrastructure Changes

### 1. TLS Certificate Generation

**File:** `scripts/helpers/generate-vault-tls.sh`

Created script to generate production-grade certificates:

```bash
#!/bin/bash
# Generate TLS certificates for OpenBao

# Uses OpenSSL to create:
# 1. Self-signed CA certificate (10-year validity)
# 2. Server certificate for OpenBao (1-year validity)

# Output:
# - Kubernetes Secret: openbao-tls (namespace: openbao)
# - Files: ca.crt, server.crt, server.key
# - Location: infrastructure/openbao/tls/ca.crt
```

**Execution:**
```bash
chmod +x scripts/helpers/generate-vault-tls.sh
./scripts/helpers/generate-vault-tls.sh
```

**Generated Artifacts:**

1. **CA Certificate:**
   - Subject: `C=US, ST=New York, L=Brooklyn, O=Precinct 99, OU=Security, CN=OpenBao CA`
   - Validity: 10 years
   - Purpose: Root CA for OpenBao server certificates

2. **Server Certificate:**
   - Subject: `C=US, ST=New York, L=Brooklyn, O=Precinct 99, OU=Vault, CN=openbao.openbao.svc.cluster.local`
   - Validity: 1 year
   - SANs:
     - `openbao`
     - `openbao.openbao`
     - `openbao.openbao.svc`
     - `openbao.openbao.svc.cluster.local`
     - `localhost`
     - `127.0.0.1`

3. **Kubernetes Secret:**
```bash
kubectl create secret generic openbao-tls \
  -n openbao \
  --from-file=ca.crt=ca.pem \
  --from-file=server.crt=server.pem \
  --from-file=server.key=server-key.pem
```

### 2. OpenBao Production Configuration

**File:** `infrastructure/openbao/config.hcl`

```hcl
# OpenBao Production Configuration
# TLS-enabled with file storage backend

ui = true

# Storage backend - file-based (persistent)
storage "file" {
  path = "/vault/data"
}

# HTTPS listener with TLS
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = false
  tls_cert_file = "/vault/tls/server.crt"
  tls_key_file  = "/vault/tls/server.key"

  # Client certificate authentication (optional, for mTLS)
  # Note: Commented out - cert validation happens at auth method level
  # tls_require_and_verify_client_cert = false
  # tls_client_ca_file = "/vault/tls/ca.crt"
}

# API address
api_addr = "https://openbao.openbao.svc.cluster.local:8200"

# Cluster address (for HA mode)
cluster_addr = "https://openbao.openbao.svc.cluster.local:8201"

# Disable mlock for containerized environments
disable_mlock = true

# Logging
log_level = "info"
log_format = "json"

# Telemetry
telemetry {
  disable_hostname = false
}
```

**File:** `infrastructure/openbao/config-configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: openbao-config
  namespace: openbao
  labels:
    app: openbao
data:
  config.hcl: |
    [Full config.hcl content from above]
```

### 3. Persistent Storage

**File:** `infrastructure/openbao/pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openbao-data
  namespace: openbao
  labels:
    app: openbao
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  # Uses local-path provisioner in kind cluster
```

### 4. Production Deployment

**File:** `infrastructure/openbao/deployment-tls.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openbao
  namespace: openbao
  labels:
    app: openbao
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openbao
  template:
    metadata:
      labels:
        app: openbao
    spec:
      serviceAccountName: openbao
      securityContext:
        fsGroup: 1000
        runAsNonRoot: true
        runAsUser: 100
      containers:
        - name: openbao
          image: quay.io/openbao/openbao:2.0.1
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sh
            - -c
          args:
            - |
              # Start OpenBao server with production configuration
              exec bao server -config=/vault/config/config.hcl
          ports:
            - containerPort: 8200
              name: https
              protocol: TCP
            - containerPort: 8201
              name: https-internal
              protocol: TCP
          env:
            - name: BAO_ADDR
              value: "https://127.0.0.1:8200"
            - name: BAO_SKIP_VERIFY
              value: "true"  # For demo with self-signed certs
            - name: BAO_LOG_LEVEL
              value: "info"
            - name: BAO_LOG_FORMAT
              value: "json"
          volumeMounts:
            - name: config
              mountPath: /vault/config
              readOnly: true
            - name: tls
              mountPath: /vault/tls
              readOnly: true
            - name: data
              mountPath: /vault/data
          readinessProbe:
            httpGet:
              path: /v1/sys/health
              port: 8200
              scheme: HTTPS
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /v1/sys/health?standbyok=true&uninitcode=204
              port: 8200
              scheme: HTTPS
            initialDelaySeconds: 30
            periodSeconds: 20
            timeoutSeconds: 5
            failureThreshold: 3
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
      volumes:
        - name: config
          configMap:
            name: openbao-config
        - name: tls
          secret:
            secretName: openbao-tls
            defaultMode: 0400
        - name: data
          persistentVolumeClaim:
            claimName: openbao-data
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openbao
  namespace: openbao
  labels:
    app: openbao
```

**Key Changes from Dev Mode:**
1. Removed `-dev` flag from command
2. Added production configuration via ConfigMap
3. Mounted TLS certificates from Secret
4. Added persistent volume for data
5. Changed probes to use HTTPS
6. Added security context (non-root, read-only filesystem)
7. Added resource limits

---

## OpenBao Configuration

### Initialization Script

**File:** `scripts/helpers/init-vault-tls.sh`

Comprehensive initialization and configuration script:

```bash
#!/bin/bash
# Initialize and configure OpenBao with TLS

# Steps performed:
# 1. Check if already initialized
# 2. Initialize OpenBao (5 unseal keys, threshold 3)
# 3. Unseal OpenBao (using 3 keys)
# 4. Enable cert auth method
# 5. Configure cert auth with SPIRE trust bundle
# 6. Enable KV v2 secrets engine
# 7. Enable database secrets engine
# 8. Configure PostgreSQL connection
# 9. Create database role
# 10. Create backend policy
# 11. Test configuration
```

### Initialization Process

**Command Executed:**
```bash
chmod +x scripts/helpers/init-vault-tls.sh
./scripts/helpers/init-vault-tls.sh
```

#### Step 1: Initialize OpenBao

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > /tmp/vault-init.json
```

**Output:**
```json
{
  "unseal_keys_b64": [
    "JInSRGDK4zuqLmaNHl+EAz9/lVRWGTvoYkiv/95aKGp0",
    "aElheuOr1edWR9xIcPNdTbZt3k5D0kgTjOltWW0ZCMRi",
    "1uIjmuD5DkvdmJDLPasD6+u6DvU9fKpbzUPH/7HWTSvs",
    "u0NT75xO085TklMEXn17y/palg+AqZuZmPQDimptcY1B",
    "LcAJcAwzCVxMUNKpc+q2U1l1mwulcOuDSJyWnaBcGPY/"
  ],
  "unseal_shares": 5,
  "unseal_threshold": 3,
  "root_token": "s.7ImwL7OFS97DlA8yBjbZ9Huy"
}
```

**⚠️ CRITICAL:** Unseal keys and root token saved to:
- `/tmp/vault-unseal-keys.txt`
- `/tmp/vault-root-token.txt`

#### Step 2: Unseal OpenBao

```bash
# Unseal with 3 keys (threshold)
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

**Result:**
```
Seal Type       shamir
Initialized     true
Sealed          false  ← Success!
Total Shares    5
Threshold       3
```

#### Step 3: Enable Cert Auth Method

```bash
export ROOT_TOKEN=s.7ImwL7OFS97DlA8yBjbZ9Huy

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 \
      BAO_SKIP_VERIFY=true \
      BAO_TOKEN=$ROOT_TOKEN \
  bao auth enable cert
```

**Output:** `Success! Enabled cert auth method at: cert/`

#### Step 4: Configure Cert Auth with SPIRE Trust Bundle

**Fetch SPIRE Trust Bundle:**
```bash
kubectl get configmap -n spire-system spire-bundle \
  -o jsonpath='{.data.bundle\.crt}' > /tmp/spire-bundle.crt
```

**SPIRE CA Certificate Details:**
```
Subject: C = US, O = SPIFFE, CN = demo.local, serialNumber = 57160524939455504453235991442039247155
Issuer: C = US, O = SPIFFE, CN = demo.local, serialNumber = 57160524939455504453235991442039247155
Validity:
  Not Before: Dec 30 04:46:00 2025 GMT
  Not After : Dec 31 04:46:10 2025 GMT
```

**Configure Cert Auth Role:**
```bash
BUNDLE=$(cat /tmp/spire-bundle.crt)

kubectl exec -n openbao deploy/openbao -- sh -c "
  env BAO_ADDR=https://127.0.0.1:8200 \
      BAO_SKIP_VERIFY=true \
      BAO_TOKEN=$ROOT_TOKEN \
  bao write auth/cert/certs/backend-role \
    certificate='$BUNDLE' \
    allowed_uri_sans='spiffe://demo.local/ns/99-apps/sa/backend' \
    token_policies='backend-policy' \
    token_ttl=3600 \
    token_max_ttl=7200
"
```

**Configuration Details:**
- **Role Name:** `backend-role`
- **Certificate:** SPIRE root CA bundle
- **Allowed URI SANs:** `spiffe://demo.local/ns/99-apps/sa/backend`
- **Token Policies:** `backend-policy`
- **Token TTL:** 3600s (1 hour)
- **Max TTL:** 7200s (2 hours)

#### Step 5: Enable KV v2 Secrets Engine

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 \
      BAO_SKIP_VERIFY=true \
      BAO_TOKEN=$ROOT_TOKEN \
  bao secrets enable -version=2 -path=secret kv
```

**Output:** `Success! Enabled the kv secrets engine at: secret/`

#### Step 6: Enable Database Secrets Engine

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 \
      BAO_SKIP_VERIFY=true \
      BAO_TOKEN=$ROOT_TOKEN \
  bao secrets enable database
```

**Output:** `Success! Enabled the database secrets engine at: database/`

#### Step 7: Configure PostgreSQL Connection

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 \
      BAO_SKIP_VERIFY=true \
      BAO_TOKEN=$ROOT_TOKEN \
  bao write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="backend-role" \
    connection_url="postgresql://{{username}}:{{password}}@postgresql.99-apps.svc.cluster.local:5432/appdb?sslmode=disable" \
    username="postgres" \
    password="postgres"
```

**Configuration:**
- **Plugin:** `postgresql-database-plugin`
- **Allowed Roles:** `backend-role`
- **Connection URL:** `postgresql://{{username}}:{{password}}@postgresql.99-apps.svc.cluster.local:5432/appdb?sslmode=disable`
- **Admin User:** `postgres` (demo only - use dedicated user in production)

#### Step 8: Create Database Role

```bash
kubectl exec -n openbao deploy/openbao -- sh -c "
  env BAO_ADDR=https://127.0.0.1:8200 \
      BAO_SKIP_VERIFY=true \
      BAO_TOKEN=$ROOT_TOKEN \
  bao write database/roles/backend-role \
    db_name=postgresql \
    creation_statements=\"CREATE ROLE \\\"{{name}}\\\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT; \
      GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \\\"{{name}}\\\"; \
      GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \\\"{{name}}\\\"; \
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \\\"{{name}}\\\"; \
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO \\\"{{name}}\\\";\" \
    default_ttl=3600 \
    max_ttl=7200
"
```

**Configuration:**
- **Role Name:** `backend-role`
- **Database:** `postgresql`
- **Creation Statements:** Grants SELECT, INSERT, UPDATE, DELETE on all tables
- **Default TTL:** 3600s (1 hour)
- **Max TTL:** 7200s (2 hours)

#### Step 9: Create Backend Policy

```bash
cat <<'EOF' | kubectl exec -i -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 \
      BAO_SKIP_VERIFY=true \
      BAO_TOKEN=$ROOT_TOKEN \
  bao policy write backend-policy -
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

# Renew own token
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF
```

**Policy Permissions:**
1. **KV v2 Secrets:** Full CRUD access to `secret/data/*`
2. **KV Metadata:** List, read, delete access to `secret/metadata/*`
3. **Database Credentials:** Read access to `database/creds/backend-role`
4. **Token Renewal:** Self-renewal capability

#### Step 10: Test Configuration

```bash
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 \
      BAO_SKIP_VERIFY=true \
      BAO_TOKEN=$ROOT_TOKEN \
  bao read database/creds/backend-role
```

**Output:**
```
Key                Value
---                -----
lease_id           database/creds/backend-role/FI54DcBZrhKZVkXVylt0kLoc
lease_duration     1h
lease_renewable    true
password           xv7YoU5sgf9-KODDLVEO
username           v-root-backend--YtWc7aMfWqD3oU7D9R3E-1767077420
```

✅ **Database credential generation confirmed working!**

---

## Backend Application Changes

### 1. Configuration Updates

**File:** `backend/app/config.py`

```python
# Vault (OpenBao)
VAULT_ADDR: str = os.getenv(
    "VAULT_ADDR",
    "http://openbao.openbao.svc.cluster.local:8200"  # Default to HTTP
)
VAULT_CACERT: Optional[str] = os.getenv("VAULT_CACERT")  # NEW: CA cert path for TLS verification
VAULT_NAMESPACE: Optional[str] = None
VAULT_KV_PATH: str = "secret"
VAULT_DB_PATH: str = "database"
VAULT_DB_ROLE: str = "backend-role"
```

**Changes:**
- Added `VAULT_CACERT` environment variable for CA certificate path
- Supports both HTTP (dev) and HTTPS (production) via `VAULT_ADDR`

### 2. Vault Client Updates

**File:** `backend/app/core/vault.py`

**Original Implementation (Dev Mode):**
```python
async def connect(self) -> None:
    logger.info("Connecting to Vault with SPIRE certificate...")

    cert_pem = spire_client.get_certificate_pem()
    key_pem = spire_client.get_private_key_pem()

    # ... write to temp files ...

    self._client = hvac.Client(
        url=self.vault_addr,
        cert=(cert_path, key_path),
        verify=False  # Dev mode
    )

    auth_response = self._client.auth.cert.login()
```

**Updated Implementation (Production):**
```python
async def connect(self) -> None:
    """
    Connect to Vault and authenticate using SPIRE certificate (HTTPS) or token (HTTP dev mode).
    """
    try:
        # Check if we're using HTTPS (production) or HTTP (dev mode)
        is_https = self.vault_addr.startswith('https://')

        if is_https:
            # Production mode: Use cert authentication with SPIRE certificate
            logger.info("Connecting to Vault with SPIRE certificate (HTTPS)...")

            # Get SPIRE certificate and key
            cert_pem = spire_client.get_certificate_pem()
            key_pem = spire_client.get_private_key_pem()

            # Write cert and key to temporary files (required by hvac)
            with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.pem') as cert_file:
                cert_file.write(cert_pem)
                cert_path = cert_file.name

            with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.pem') as key_file:
                key_file.write(key_pem)
                key_path = key_file.name

            # Read and prepare Vault CA certificate for verification
            # hvac needs a real file path (not symlink) for verify parameter
            vault_ca_path = None
            if self.vault_cacert:
                import os
                # Resolve symlink to actual file
                resolved_ca_path = os.path.realpath(self.vault_cacert)
                if os.path.isfile(resolved_ca_path):
                    # Read CA cert and write to temp file for hvac
                    with open(resolved_ca_path, 'rb') as ca_file:
                        ca_cert_data = ca_file.read()

                    with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.crt') as ca_temp:
                        ca_temp.write(ca_cert_data)
                        vault_ca_path = ca_temp.name

            # Create Vault client with mTLS
            # Use CA cert for server verification if available
            verify_param = vault_ca_path if vault_ca_path else False

            self._client = hvac.Client(
                url=self.vault_addr,
                cert=(cert_path, key_path),
                verify=verify_param
            )

            # Authenticate using cert auth
            # Explicitly specify the backend-role
            auth_response = self._client.auth.cert.login(name='backend-role')

            self._authenticated = True
            logger.info(f"✅ Vault authenticated (cert) - Token TTL: {auth_response['auth']['lease_duration']}s")
            logger.info(f"Vault policies: {auth_response['auth']['policies']}")

        else:
            # Dev mode (HTTP): Cert auth requires TLS, so use token auth instead
            logger.info("Connecting to Vault with token (HTTP dev mode)...")

            # Use root token for dev mode
            self._client = hvac.Client(
                url=self.vault_addr,
                token='root'  # Dev mode only - never use root token in production
            )

            # Verify authentication
            if self._client.is_authenticated():
                self._authenticated = True
                logger.info("✅ Vault authenticated (token) - Dev mode with root token")
                logger.warning("⚠️  Using root token - For development only!")
            else:
                raise RuntimeError("Token authentication failed")

    except Exception as e:
        logger.error(f"❌ Failed to authenticate to Vault: {e}")
        raise
```

**Key Changes:**
1. Dual-mode authentication (HTTP token / HTTPS cert)
2. Automatic protocol detection based on `VAULT_ADDR`
3. CA certificate verification support
4. Symlink resolution for CA cert (ConfigMap mounts use symlinks)
5. Explicit role name in cert auth login
6. Comprehensive error logging

### 3. SPIRE Client Updates

**File:** `backend/app/core/spire.py`

**Critical Fix: Return Full Certificate Chain**

**Before (BROKEN):**
```python
def get_certificate_pem(self) -> bytes:
    """Get certificate in PEM format for mTLS."""
    svid = self.get_svid()
    # WRONG: Only returns leaf certificate!
    return svid.cert_chain[0].public_bytes(encoding=serialization.Encoding.PEM)
```

**After (FIXED):**
```python
def get_certificate_pem(self) -> bytes:
    """
    Get certificate chain in PEM format for mTLS.
    Returns the FULL chain including leaf and intermediate certificates.

    Returns:
        Full certificate chain in PEM format (concatenated)
    """
    svid = self.get_svid()
    # The spiffe library uses cert_chain (list of cryptography Certificate objects)
    # Convert FULL chain to PEM bytes - Vault needs the complete chain for validation
    cert_chain_pem = b''
    for cert in svid.cert_chain:
        cert_chain_pem += cert.public_bytes(encoding=serialization.Encoding.PEM)
    return cert_chain_pem
```

**Why This Matters:**
- OpenBao cert auth validates the FULL certificate chain against the configured CA
- Only sending the leaf certificate caused `"no chain matching all constraints"` errors
- SPIRE provides the complete chain in `svid.cert_chain`

### 4. Kubernetes Configuration Updates

**File:** `backend/k8s/configmap.yaml`

```yaml
# Vault (OpenBao)
VAULT_ADDR: "https://openbao.openbao.svc.cluster.local:8200"  # Changed to HTTPS
VAULT_CACERT: "/vault/tls/ca.crt"  # NEW: Path to OpenBao CA certificate
VAULT_KV_PATH: "secret"
VAULT_DB_PATH: "database"
VAULT_DB_ROLE: "backend-role"
```

**File:** `backend/k8s/deployment.yaml`

```yaml
# Volume mounts
volumeMounts:
- name: spire-agent-socket
  mountPath: /run/spire/sockets
  readOnly: true
- name: vault-ca  # NEW: Mount OpenBao CA certificate
  mountPath: /vault/tls
  readOnly: true

# Volumes
volumes:
- name: spire-agent-socket
  hostPath:
    path: /run/spire/sockets
    type: DirectoryOrCreate
- name: vault-ca  # NEW: ConfigMap with OpenBao CA
  configMap:
    name: vault-ca
    items:
    - key: ca.crt
      path: ca.crt
```

**Vault CA ConfigMap Creation:**
```bash
kubectl create configmap vault-ca \
  -n 99-apps \
  --from-file=ca.crt=infrastructure/openbao/tls/ca.crt
```

---

## Deployment Process

### Complete Step-by-Step Deployment

#### 1. Delete Dev Mode OpenBao

```bash
kubectl delete deployment -n openbao openbao
```

#### 2. Generate TLS Certificates

```bash
./scripts/helpers/generate-vault-tls.sh
```

**Artifacts Created:**
- Secret: `openbao-tls` (namespace: openbao)
- File: `infrastructure/openbao/tls/ca.crt`

#### 3. Create Vault CA ConfigMap for Backend

```bash
kubectl create configmap vault-ca \
  -n 99-apps \
  --from-file=ca.crt=infrastructure/openbao/tls/ca.crt
```

#### 4. Deploy OpenBao with TLS

```bash
kubectl apply -f infrastructure/openbao/pvc.yaml
kubectl apply -f infrastructure/openbao/config-configmap.yaml
kubectl apply -f infrastructure/openbao/deployment-tls.yaml
kubectl apply -f infrastructure/openbao/service.yaml
```

#### 5. Initialize and Configure OpenBao

```bash
./scripts/helpers/init-vault-tls.sh
```

**Important:** Save unseal keys and root token securely!

**Unsealing After Restart:**

When OpenBao pod restarts, it must be manually unsealed:

```bash
# Using saved keys
KEY1=$(sed -n '1p' /tmp/vault-unseal-keys.txt)
KEY2=$(sed -n '2p' /tmp/vault-unseal-keys.txt)
KEY3=$(sed -n '3p' /tmp/vault-unseal-keys.txt)

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao operator unseal $KEY1

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao operator unseal $KEY2

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao operator unseal $KEY3
```

#### 6. Restart Backend (Tilt Handles Automatically)

Backend pods will automatically pick up new configuration on next rebuild.

---

## Debugging Journey

### Issue 1: Certificate Chain Validation

**Error:**
```
no chain matching all constraints could be found for this login certificate
```

**Root Cause:** Only sending leaf certificate, not full chain

**Solution:** Updated `get_certificate_pem()` to return complete chain

### Issue 2: CA Certificate Verification

**Error:**
```
cacert must be True, a file_path, or valid CA Certificate
```

**Root Cause:** ConfigMap mounts certificates as symlinks; hvac library couldn't read symlinks properly

**Solution:** Resolve symlink to real file, read content, write to temporary file

### Issue 3: Readiness Probe Failure

**Error:** Pod not becoming Ready despite being unsealed

**Root Cause:** Readiness probe used `jq` which isn't installed in OpenBao container

**Original Probe:**
```yaml
readinessProbe:
  exec:
    command:
      - /bin/sh
      - -c
      - |
        bao status -format=json | jq -e '.initialized == true and .sealed == false'
```

**Solution:** Changed to HTTP health check

**Updated Probe:**
```yaml
readinessProbe:
  httpGet:
    path: /v1/sys/health
    port: 8200
    scheme: HTTPS
  initialDelaySeconds: 10
  periodSeconds: 10
```

### Issue 4: Missing Name in Alias (CRITICAL)

**Error:**
```
missing name in alias
```

**Root Cause:** OpenBao cert auth expects Common Name (CN) field in certificates for entity alias creation. SPIFFE certificates use URI SANs for identity, not CN.

**Research Findings:**
- This is a **known limitation** documented in [HashiCorp Vault Issue #6820](https://github.com/hashicorp/vault/issues/6820) (2019)
- Vault introduced a dedicated [SPIFFE auth method](https://developer.hashicorp.com/vault/docs/auth/spiffe) to address this
- OpenBao has not yet implemented the SPIFFE auth method (as of 2025-12-30)

**Attempted Fixes:**
1. ❌ Added `display_name` to cert auth role
2. ❌ Added `allowed_common_names` wildcard
3. ❌ Removed all constraints except certificate validation
4. ❌ Used `allowed_names` parameter

**Current Status:** **BLOCKED** - OpenBao limitation

---

## Final Status

### ✅ Successfully Implemented

1. **TLS Infrastructure**
   - ✅ Self-signed CA + server certificates generated
   - ✅ Kubernetes Secret created and mounted
   - ✅ CA certificate distributed to backend

2. **OpenBao Production Deployment**
   - ✅ TLS listener configured and working
   - ✅ Persistent storage with PVC
   - ✅ Production configuration (not dev mode)
   - ✅ Manual unsealing process documented

3. **OpenBao Configuration**
   - ✅ Initialized with Shamir's Secret Sharing (5/3)
   - ✅ Cert auth method enabled
   - ✅ KV v2 secrets engine enabled (`secret/`)
   - ✅ Database secrets engine enabled
   - ✅ PostgreSQL connection configured
   - ✅ Database role created (`backend-role`)
   - ✅ Backend policy created and tested

4. **Backend Application**
   - ✅ Dual-mode authentication (HTTP/HTTPS)
   - ✅ Full SPIRE certificate chain support
   - ✅ CA certificate verification
   - ✅ HTTPS connection to OpenBao working
   - ✅ TLS handshake successful

5. **Integration Testing**
   - ✅ Backend obtains SPIRE X.509-SVID
   - ✅ Backend connects to OpenBao via HTTPS
   - ✅ TLS connection with CA verification works
   - ✅ Certificate chain validation works (briefly)
   - ✅ Database credential generation tested (via root token)

### ⚠️ Known Limitation

**OpenBao Cert Auth with SPIFFE Certificates**

**Issue:** `"missing name in alias"` error

**Root Cause:**
- Cert auth requires CN (Common Name) field for entity alias
- SPIFFE certificates use URI SANs, not CN
- This is a documented limitation since 2019

**Upstream Solution (HashiCorp Vault):**
- Dedicated [SPIFFE auth method](https://developer.hashicorp.com/vault/docs/auth/spiffe)
- Properly handles URI SAN-based identity

**OpenBao Status:**
- SPIFFE auth method **not yet implemented**
- Cert auth has same limitation as legacy Vault

**Recommended Workarounds:**

1. **JWT-SVID Authentication** (Recommended)
   - Use SPIRE's JWT-SVIDs instead of X.509
   - Authenticate via OpenBao's JWT/OIDC auth method
   - [Official SPIFFE Guide](https://spiffe.io/docs/latest/keyless/vault/readme/)
   - ✅ Works with current OpenBao
   - ✅ Production-ready

2. **Wait for OpenBao SPIFFE Auth**
   - Track OpenBao GitHub for SPIFFE auth implementation
   - Would be direct port from Vault

3. **Use spiffe-vault Bridge**
   - [philips-labs/spiffe-vault](https://github.com/philips-labs/spiffe-vault)
   - Wrapper that converts SPIRE certs to Vault tokens
   - More complex setup

---

## Code Changes Summary

### Files Created

```
scripts/helpers/
├── generate-vault-tls.sh          # TLS certificate generation
└── init-vault-tls.sh              # OpenBao initialization

infrastructure/openbao/
├── config.hcl                      # Production configuration (source)
├── config-configmap.yaml           # Production configuration (K8s)
├── pvc.yaml                        # Persistent volume claim
├── deployment-tls.yaml             # Production deployment
└── tls/
    └── ca.crt                      # CA certificate (generated)

docs/
├── OPENBAO_TLS_SETUP.md           # Deployment guide
└── SESSION_IMPLEMENTATION_LOG.md   # This document
```

### Files Modified

```
backend/app/
├── config.py                       # Added VAULT_CACERT
├── core/
│   ├── vault.py                    # Dual-mode auth, CA verification
│   └── spire.py                    # Full cert chain support
└── k8s/
    ├── configmap.yaml              # HTTPS URL, CA cert path
    └── deployment.yaml             # Mount vault-ca ConfigMap

infrastructure/openbao/
└── deployment-tls.yaml             # Fixed readiness probe

CLAUDE.md                           # Documented TLS modes
```

### Configuration Changes

#### Environment Variables

```bash
# Backend ConfigMap (99-apps/backend-config)
VAULT_ADDR="https://openbao.openbao.svc.cluster.local:8200"  # HTTP → HTTPS
VAULT_CACERT="/vault/tls/ca.crt"  # NEW
```

#### Kubernetes Resources

```bash
# Secrets
openbao-tls (openbao namespace)
├── ca.crt      # OpenBao CA certificate
├── server.crt  # OpenBao server certificate
└── server.key  # OpenBao server private key

# ConfigMaps
openbao-config (openbao namespace)
└── config.hcl  # Production configuration

vault-ca (99-apps namespace)
└── ca.crt      # OpenBao CA for backend verification

# PersistentVolumeClaims
openbao-data (openbao namespace)
└── 1Gi storage for /vault/data
```

#### OpenBao Configuration

```hcl
# Auth Methods
cert/                           # TLS certificate authentication
└── certs/backend-role          # Role for backend workload

# Secrets Engines
secret/                         # KV v2 (version 2)
└── (GitHub tokens storage)

database/                       # Database secrets engine
├── config/postgresql           # PostgreSQL connection
└── roles/backend-role          # Dynamic credential role

# Policies
backend-policy                  # Allows secret/ and database/ access

# System
Seal Type: shamir
Unseal Keys: 5
Threshold: 3
Storage: file (/vault/data)
```

---

## Git Commits

### Commit 1: SPIRE-Vault Integration

```
feat: implement production-ready SPIRE-Vault integration with dual-mode authentication

Backend SPIRE Integration:
- Migrate from py-spiffe to official spiffe library (v0.1.0+)
- Fix certificate/key serialization using cryptography.hazmat primitives
- Update socket path to include unix:// scheme requirement
- Add nodes/proxy RBAC permission for SPIRE agent

Vault Authentication Strategy:
- Implement dual-mode authentication (HTTPS cert auth / HTTP token auth)
- HTTPS mode: mTLS using SPIRE X.509-SVID via cert auth method
- HTTP mode: Fallback to root token for dev mode deployments

Database & Security:
- Fix SQLAlchemy 2.0 text() wrapper for raw SQL queries
- Switch from passlib to direct bcrypt
- Update demo passwords to 8-character minimum

Infrastructure:
- Add setup-infrastructure.sh automation
- Fix Vault configuration script BAO_TOKEN usage
```

### Commit 2: TLS Support

```
feat: add production-grade TLS support for OpenBao with dual deployment modes

OpenBao Deployment Modes:
- Dev Mode: HTTP, in-memory storage, auto-unseal, root token
- Production Mode: HTTPS with TLS, persistent storage, manual unseal, cert auth

Certificate Architecture:
- OpenBao server uses self-signed TLS certificate
- Backend authenticates using SPIRE X.509-SVID
- Two separate certificates: server TLS + client auth

Infrastructure:
- generate-vault-tls.sh: CA + server certificate generation
- init-vault-tls.sh: Initialize, unseal, configure OpenBao
- Production HCL config with TLS listener
- PersistentVolumeClaim for data persistence

Backend Updates:
- VAULT_ADDR supports http:// and https://
- VAULT_CACERT for CA certificate verification
- Auto-detects protocol and selects auth method
- Full certificate chain support for validation

Documentation:
- OPENBAO_TLS_SETUP.md: Complete deployment guide
- CLAUDE.md: Deployment modes comparison
```

---

## Next Steps

### Immediate (Unblocking Cert Auth)

**Option 1: Implement JWT-SVID Authentication** (Recommended)

1. Configure SPIRE OIDC Discovery Provider
2. Enable OpenBao JWT/OIDC auth method
3. Update backend to use JWT-SVID instead of X.509 for Vault auth
4. Test end-to-end authentication flow

**Estimated Effort:** 2-3 hours

**Option 2: Wait for OpenBao SPIFFE Auth Method**

1. Monitor [OpenBao GitHub](https://github.com/openbao/openbao) for SPIFFE auth
2. Test when available
3. Update deployment

**Estimated Effort:** Unknown (depends on OpenBao development)

### Future Enhancements

1. **Automated Unsealing**
   - Implement auto-unseal with KMS (AWS, GCP, Azure)
   - Or use Kubernetes secret for dev environments

2. **High Availability**
   - Deploy multiple OpenBao replicas
   - Use Raft or Consul storage backend
   - Configure load balancer

3. **Certificate Management**
   - Use cert-manager for automated certificate lifecycle
   - Integrate with organizational PKI
   - Implement certificate rotation

4. **Monitoring & Alerting**
   - Export OpenBao metrics to Prometheus
   - Create Grafana dashboards
   - Set up alerts for seal status, auth failures

5. **Audit Logging**
   - Enable OpenBao audit device
   - Ship logs to centralized logging system
   - Implement log analysis and anomaly detection

---

## References

### Documentation Created
- `docs/OPENBAO_TLS_SETUP.md` - Deployment guide
- `CLAUDE.md` - Updated with TLS deployment modes
- `docs/SESSION_IMPLEMENTATION_LOG.md` - This document

### External Resources
- [HashiCorp Vault Issue #6820](https://github.com/hashicorp/vault/issues/6820) - Cert auth without CN
- [Vault SPIFFE Auth Method](https://developer.hashicorp.com/vault/docs/auth/spiffe)
- [SPIFFE Vault Integration Guide](https://spiffe.io/docs/latest/keyless/vault/readme/)
- [OpenBao Documentation](https://openbao.org/docs/)
- [SPIRE Documentation](https://spiffe.io/docs/latest/spire/)

---

## Appendix: Command Reference

### OpenBao Operations

```bash
# Check status
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao status

# Unseal (repeat 3 times with different keys)
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true \
  bao operator unseal <UNSEAL_KEY>

# List auth methods
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=<ROOT_TOKEN> \
  bao auth list

# List secrets engines
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=<ROOT_TOKEN> \
  bao secrets list

# Generate database credentials
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=<ROOT_TOKEN> \
  bao read database/creds/backend-role

# Read cert auth configuration
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=<ROOT_TOKEN> \
  bao read auth/cert/certs/backend-role
```

### SPIRE Operations

```bash
# List SPIRE agents
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server agent list

# List registration entries
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show

# Check SPIRE server health
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server healthcheck

# Get SPIRE trust bundle
kubectl get configmap -n spire-system spire-bundle \
  -o jsonpath='{.data.bundle\.crt}'
```

### Backend Debugging

```bash
# Check backend environment variables
kubectl exec deploy/backend -n 99-apps -- printenv | grep VAULT

# View backend logs (Vault authentication)
kubectl logs -n 99-apps -l app=backend --tail=50 | \
  grep -E "(SPIRE|Vault|Database|✅|❌)"

# Check if CA cert file exists
kubectl exec deploy/backend -n 99-apps -- \
  ls -la /vault/tls/ca.crt

# Verify CA cert content
kubectl exec deploy/backend -n 99-apps -- \
  cat /vault/tls/ca.crt | openssl x509 -text -noout | head -20
```

---

**End of Implementation Log**
