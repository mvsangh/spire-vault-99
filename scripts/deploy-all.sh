#!/bin/bash
set -e

# SPIRE-Vault-99 Complete Deployment Script
# Deploys everything from scratch

echo "🚀 SPIRE-Vault-99 Complete Deployment"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Step 1: Create Cluster
echo -e "${BLUE}Step 1: Creating kind cluster...${NC}"
kind create cluster --config infrastructure/kind/kind-config.yaml
echo -e "${GREEN}✅ Cluster created${NC}"
echo ""

# Step 2: Install Cilium
echo -e "${BLUE}Step 2: Installing Cilium CNI...${NC}"
helm install cilium cilium/cilium \
  --version 1.15.7 \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true

echo "Waiting for Cilium..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cilium-agent -n kube-system --timeout=120s
echo -e "${GREEN}✅ Cilium installed${NC}"
echo ""

# Step 3: Deploy SPIRE
echo -e "${BLUE}Step 3: Deploying SPIRE...${NC}"
kubectl create namespace spire-system

kubectl apply -f infrastructure/spire/server-configmap.yaml
kubectl apply -f infrastructure/spire/server-statefulset.yaml
kubectl apply -f infrastructure/spire/server-service.yaml
kubectl apply -f infrastructure/spire/server-rbac.yaml

kubectl wait --for=condition=ready pod -l app=spire-server -n spire-system --timeout=120s

kubectl apply -f infrastructure/spire/agent-configmap.yaml
kubectl apply -f infrastructure/spire/agent-daemonset.yaml
kubectl apply -f infrastructure/spire/agent-rbac.yaml

kubectl wait --for=condition=ready pod -l app=spire-agent -n spire-system --timeout=120s
echo -e "${GREEN}✅ SPIRE deployed${NC}"
echo ""

# Step 4: Deploy PostgreSQL
echo -e "${BLUE}Step 4: Deploying PostgreSQL...${NC}"
kubectl create namespace 99-apps

kubectl apply -f infrastructure/postgres/pvc.yaml
kubectl apply -f infrastructure/postgres/init-configmap.yaml
kubectl apply -f infrastructure/postgres/statefulset.yaml
kubectl apply -f infrastructure/postgres/service.yaml

kubectl wait --for=condition=ready pod -l app=postgresql -n 99-apps --timeout=120s
echo -e "${GREEN}✅ PostgreSQL deployed${NC}"
echo ""

# Step 5: Deploy OpenBao
echo -e "${BLUE}Step 5: Deploying OpenBao with TLS...${NC}"
kubectl create namespace openbao

./scripts/helpers/generate-vault-tls.sh

kubectl create configmap vault-ca \
  -n 99-apps \
  --from-file=ca.crt=infrastructure/openbao/tls/ca.crt

kubectl apply -f infrastructure/openbao/pvc.yaml
kubectl apply -f infrastructure/openbao/config-configmap.yaml
kubectl apply -f infrastructure/openbao/deployment-tls.yaml
kubectl apply -f infrastructure/openbao/service.yaml

kubectl wait --for=condition=ready pod -l app=openbao -n openbao --timeout=120s
echo -e "${GREEN}✅ OpenBao deployed${NC}"
echo ""

# Step 6: Initialize OpenBao
echo -e "${BLUE}Step 6: Initializing OpenBao...${NC}"
./scripts/helpers/init-vault-tls.sh

echo -e "${YELLOW}⚠️  IMPORTANT: Save these credentials!${NC}"
echo -e "${YELLOW}Root token: $(cat /tmp/vault-root-token.txt)${NC}"
echo -e "${YELLOW}Unseal keys saved to: /tmp/vault-unseal-keys.txt${NC}"
echo ""

# Step 7: Configure OpenBao JWT Auth
echo -e "${BLUE}Step 7: Configuring OpenBao JWT Auth...${NC}"

export ROOT_TOKEN=$(cat /tmp/vault-root-token.txt)

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao auth enable jwt 2>/dev/null || echo "JWT auth already enabled"

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao write auth/jwt/config \
    jwks_url="http://spire-server.spire-system.svc.cluster.local:8090/keys"

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

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao secrets enable -version=2 -path=secret kv 2>/dev/null || echo "KV v2 already enabled"

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao secrets enable database 2>/dev/null || echo "Database engine already enabled"

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="backend-role" \
    connection_url="postgresql://{{username}}:{{password}}@postgresql.99-apps.svc.cluster.local:5432/appdb?sslmode=disable" \
    username="postgres" \
    password="postgres"

kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao write database/roles/backend-role \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="2h"

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

echo -e "${GREEN}✅ OpenBao configured${NC}"
echo ""

# Step 8: Create SPIRE Registration Entry
echo -e "${BLUE}Step 8: Creating SPIRE registration entry...${NC}"
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://demo.local/ns/99-apps/sa/backend \
    -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99 \
    -selector k8s:ns:99-apps \
    -selector k8s:sa:backend \
    -ttl 3600

echo -e "${GREEN}✅ SPIRE entry created${NC}"
echo ""

# Step 9: Deploy Backend
echo -e "${BLUE}Step 9: Deploying backend...${NC}"
docker build -t backend:dev -f backend/Dockerfile.dev backend/
kind load docker-image backend:dev --name precinct-99

kubectl apply -f backend/k8s/serviceaccount.yaml
kubectl apply -f backend/k8s/configmap.yaml
kubectl apply -f backend/k8s/deployment.yaml
kubectl apply -f backend/k8s/service.yaml

kubectl wait --for=condition=ready pod -l app=backend -n 99-apps --timeout=120s
echo -e "${GREEN}✅ Backend deployed${NC}"
echo ""

# Verification
echo -e "${BLUE}Step 10: Verification...${NC}"
echo ""
echo "Backend logs (JWT-SVID authentication):"
kubectl logs -n 99-apps -l app=backend --tail=10 | grep -E "(SPIRE|JWT-SVID|Vault authenticated)" || true
echo ""

echo "Testing health endpoint..."
kubectl run test-health --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -s http://backend.99-apps.svc.cluster.local:8000/api/v1/health/ready

echo ""
echo -e "${GREEN}======================================"
echo "✅ Deployment Complete!"
echo -e "======================================${NC}"
echo ""
echo "Summary:"
echo "  - Cluster: precinct-99"
echo "  - SPIRE: ✅ (with OIDC Discovery Provider)"
echo "  - OpenBao: ✅ (TLS mode, JWT auth)"
echo "  - PostgreSQL: ✅ (with demo users)"
echo "  - Backend: ✅ (JWT-SVID authenticated)"
echo ""
echo "Credentials saved to:"
echo "  - Root token: /tmp/vault-root-token.txt"
echo "  - Unseal keys: /tmp/vault-unseal-keys.txt"
echo ""
echo "Access points:"
echo "  - Backend API: http://localhost:30001/docs"
echo "  - Health: http://localhost:30001/api/v1/health/ready"
echo ""
echo "Next steps:"
echo "  - Start Tilt for hot-reload: tilt up"
echo "  - View logs: kubectl logs -f -n 99-apps -l app=backend"
echo ""
