# Quick Deployment Guide - SPIRE-Vault-99 with JWT-SVID

Complete deployment from scratch (cluster deletion to working backend).

## Prerequisites

- Docker, kubectl, kind, Tilt, Helm installed
- No existing `precinct-99` cluster

## Step 1: Create Cluster

```bash
cd /home/mandrix-murdock/code/spire-spife/test-vault

# Create kind cluster
kind create cluster --config infrastructure/kind/kind-config.yaml

# Verify nodes (will be NotReady until CNI installed)
kubectl get nodes
```

## Step 2: Install Cilium (CNI)

```bash
# Install Cilium
helm install cilium cilium/cilium \
  --version 1.15.7 \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true

# Wait for Cilium to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cilium-agent -n kube-system --timeout=120s

# Verify nodes are Ready
kubectl get nodes
```

## Step 3: Deploy SPIRE

```bash
# Create namespace
kubectl create namespace spire-system

# Deploy SPIRE server
kubectl apply -f infrastructure/spire/server-configmap.yaml
kubectl apply -f infrastructure/spire/server-statefulset.yaml
kubectl apply -f infrastructure/spire/server-service.yaml
kubectl apply -f infrastructure/spire/server-rbac.yaml

# Wait for SPIRE server
kubectl wait --for=condition=ready pod -l app=spire-server -n spire-system --timeout=120s

# Deploy SPIRE agent
kubectl apply -f infrastructure/spire/agent-configmap.yaml
kubectl apply -f infrastructure/spire/agent-daemonset.yaml
kubectl apply -f infrastructure/spire/agent-rbac.yaml

# Wait for agents
kubectl wait --for=condition=ready pod -l app=spire-agent -n spire-system --timeout=120s

# Verify OIDC Discovery endpoint (both containers should be 2/2)
kubectl get pods -n spire-system -l app=spire-server
```

## Step 4: Deploy PostgreSQL

```bash
# Create namespace
kubectl create namespace 99-apps

# Deploy PostgreSQL
kubectl apply -f infrastructure/postgres/pvc.yaml
kubectl apply -f infrastructure/postgres/init-configmap.yaml
kubectl apply -f infrastructure/postgres/statefulset.yaml
kubectl apply -f infrastructure/postgres/service.yaml

# Wait for PostgreSQL
kubectl wait --for=condition=ready pod -l app=postgresql -n 99-apps --timeout=120s
```

## Step 5: Deploy OpenBao with TLS

```bash
# Create namespace
kubectl create namespace openbao

# Generate TLS certificates
chmod +x scripts/helpers/generate-vault-tls.sh
./scripts/helpers/generate-vault-tls.sh

# Create Vault CA ConfigMap for backend
kubectl create configmap vault-ca \
  -n 99-apps \
  --from-file=ca.crt=infrastructure/openbao/tls/ca.crt

# Deploy OpenBao
kubectl apply -f infrastructure/openbao/pvc.yaml
kubectl apply -f infrastructure/openbao/config-configmap.yaml
kubectl apply -f infrastructure/openbao/deployment-tls.yaml
kubectl apply -f infrastructure/openbao/service.yaml

# Wait for OpenBao
kubectl wait --for=condition=ready pod -l app=openbao -n openbao --timeout=120s
```

## Step 6: Initialize and Configure OpenBao

```bash
# Initialize OpenBao (save the output!)
chmod +x scripts/helpers/init-vault-tls.sh
./scripts/helpers/init-vault-tls.sh

# IMPORTANT: Root token and unseal keys saved to:
# - /tmp/vault-root-token.txt
# - /tmp/vault-unseal-keys.txt

# Configure JWT auth
export ROOT_TOKEN=$(cat /tmp/vault-root-token.txt)

# Enable JWT auth
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao auth enable jwt

# Configure JWT auth with SPIRE OIDC
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao write auth/jwt/config \
    jwks_url="http://spire-server.spire-system.svc.cluster.local:8090/keys"

# Create JWT role for backend
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao write auth/jwt/role/backend-role \
    role_type="jwt" \
    bound_audiences="openbao,vault" \
    bound_subject="spiffe://demo.local/ns/99-apps/sa/backend" \
    user_claim="sub" \
    policies="backend-policy" \
    ttl="1h" \
    max_ttl="2h"

# Enable KV v2 secrets engine
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao secrets enable -version=2 -path=secret kv

# Enable database secrets engine
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao secrets enable database

# Configure PostgreSQL
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="backend-role" \
    connection_url="postgresql://{{username}}:{{password}}@postgresql.99-apps.svc.cluster.local:5432/appdb?sslmode=disable" \
    username="postgres" \
    password="postgres"

# Create database role
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao write database/roles/backend-role \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="2h"

# Create backend policy
cat > /tmp/backend-policy.hcl <<'EOF'
path "secret/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/*" {
  capabilities = ["list", "read", "delete"]
}
path "database/creds/backend-role" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

cat /tmp/backend-policy.hcl | kubectl exec -i -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao policy write backend-policy -

# Test database credential generation
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao read database/creds/backend-role
```

## Step 7: Create SPIRE Registration Entry for Backend

```bash
# Create registration entry
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://demo.local/ns/99-apps/sa/backend \
    -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99 \
    -selector k8s:ns:99-apps \
    -selector k8s:sa:backend \
    -ttl 3600

# Verify entry
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show \
    -spiffeID spiffe://demo.local/ns/99-apps/sa/backend
```

## Step 8: Deploy Backend

```bash
# Build and load Docker image
docker build -t backend:dev -f backend/Dockerfile.dev backend/
kind load docker-image backend:dev --name precinct-99

# Deploy backend
kubectl apply -f backend/k8s/serviceaccount.yaml
kubectl apply -f backend/k8s/configmap.yaml
kubectl apply -f backend/k8s/deployment.yaml
kubectl apply -f backend/k8s/service.yaml

# Wait for backend
kubectl wait --for=condition=ready pod -l app=backend -n 99-apps --timeout=120s

# Check logs for JWT-SVID authentication
kubectl logs -n 99-apps -l app=backend --tail=30 | grep -E "(SPIRE|JWT-SVID|Vault authenticated)"
```

## Step 9: Verify End-to-End

```bash
# Check health endpoint
kubectl run test-health --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -s http://backend.99-apps.svc.cluster.local:8000/api/v1/health/ready

# Expected output:
# {"status":"ready","version":"1.0.0","spire":"ready","vault":"ready","database":"ready"}
```

## Common Issues & Fixes

### OpenBao pod restarts - sealed

```bash
# Unseal OpenBao after pod restart
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

### Backend fails with "invalid issuer"

```bash
# Remove bound_issuer constraint from JWT config
ROOT_TOKEN=$(cat /tmp/vault-root-token.txt)
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao write auth/jwt/config \
    jwks_url="http://spire-server.spire-system.svc.cluster.local:8090/keys"

# Restart backend
kubectl rollout restart deployment/backend -n 99-apps
```

### SPIRE agent not connecting

```bash
# Check SPIRE server has both containers running (2/2)
kubectl get pods -n spire-system -l app=spire-server

# If only 1/2, check logs
kubectl logs -n spire-system spire-server-0 -c oidc-discovery-provider

# Verify SPIRE bundle ConfigMap exists
kubectl get configmap -n spire-system spire-bundle
```

## Verification Checklist

- [ ] Cluster created with 3 nodes (1 control-plane, 2 workers)
- [ ] Cilium installed, all nodes Ready
- [ ] SPIRE server running 2/2 (server + OIDC sidecar)
- [ ] SPIRE agents running on all nodes (DaemonSet)
- [ ] OIDC discovery endpoint accessible on port 8090
- [ ] PostgreSQL running with demo data
- [ ] OpenBao running in TLS mode
- [ ] OpenBao initialized and unsealed
- [ ] JWT auth configured with JWKS URL
- [ ] All secrets engines enabled (KV v2, database)
- [ ] Backend policy created
- [ ] Backend SPIRE registration entry exists
- [ ] Backend pod running 1/1
- [ ] Backend logs show "✅ Vault authenticated (JWT)"
- [ ] Database username starts with `v-jwt-spif-`
- [ ] Health endpoint returns all "ready"

## Development with Tilt (Optional)

```bash
# Start Tilt for hot-reload development
tilt up

# Open Tilt UI
open http://localhost:10350

# Backend accessible at
open http://localhost:8000/docs
```

## Clean Up

```bash
# Delete cluster
kind delete cluster --name precinct-99

# Clean up saved credentials
rm -f /tmp/vault-root-token.txt /tmp/vault-unseal-keys.txt
```

## Time Estimates

- Cluster creation: 2 minutes
- Cilium installation: 2 minutes
- SPIRE deployment: 2 minutes
- PostgreSQL deployment: 1 minute
- OpenBao deployment: 1 minute
- OpenBao configuration: 3 minutes
- Backend deployment: 2 minutes
- **Total: ~15 minutes**

## Important Credentials

After Step 6, save these securely:

- **OpenBao Root Token**: `/tmp/vault-root-token.txt`
- **OpenBao Unseal Keys**: `/tmp/vault-unseal-keys.txt` (need 3 of 5 to unseal)
- **OpenBao CA Certificate**: `infrastructure/openbao/tls/ca.crt`

## Demo Users (Pre-seeded in PostgreSQL)

| Username | Password | Email |
|----------|----------|-------|
| jake | jake-precinct99 | jake@precinct99.local |
| amy | amy-precinct99 | amy@precinct99.local |
| rosa | rosa-precinct99 | rosa@precinct99.local |
| terry | terry-precinct99 | terry@precinct99.local |
| charles | charles-precinct99 | charles@precinct99.local |
| gina | gina-precinct99 | gina@precinct99.local |
