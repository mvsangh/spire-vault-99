#!/bin/bash
set -e

# Configure OpenBao with JWT Auth for SPIRE JWT-SVID
# Run this after OpenBao is initialized and unsealed

echo "🔐 Configuring OpenBao JWT Auth for Backend..."

# Read root token
if [ -f /tmp/vault-root-token.txt ]; then
    ROOT_TOKEN=$(cat /tmp/vault-root-token.txt)
    echo "✅ Using root token from /tmp/vault-root-token.txt"
else
    echo "❌ Root token not found at /tmp/vault-root-token.txt"
    echo "Please provide the root token as first argument"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Enable JWT Auth
echo ""
echo "📋 Step 1: Enable JWT Auth Method"
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao auth enable jwt 2>/dev/null && echo -e "${GREEN}✅ JWT auth enabled${NC}" || echo -e "${YELLOW}⚠️  JWT auth already enabled${NC}"

# Step 2: Configure JWT Auth with SPIRE OIDC Discovery
echo ""
echo "📋 Step 2: Configure JWT Auth with SPIRE OIDC Discovery"
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao write auth/jwt/config \
    oidc_discovery_url="http://spire-server.spire-system.svc.cluster.local:8090" \
    bound_issuer="https://spire-server.spire-system.svc.cluster.local:8090"

echo -e "${GREEN}✅ JWT auth configured with SPIRE OIDC discovery${NC}"

# Step 3: Create JWT Role for Backend
echo ""
echo "📋 Step 3: Create backend-role for JWT Auth"
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

echo -e "${GREEN}✅ backend-role created for JWT auth${NC}"

# Step 4: Enable KV v2
echo ""
echo "📋 Step 4: Enable KV v2 Secrets Engine"
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao secrets enable -version=2 -path=secret kv 2>/dev/null && echo -e "${GREEN}✅ KV v2 enabled${NC}" || echo -e "${YELLOW}⚠️  KV v2 already enabled${NC}"

# Step 5: Enable Database Secrets Engine
echo ""
echo "📋 Step 5: Enable Database Secrets Engine"
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao secrets enable database 2>/dev/null && echo -e "${GREEN}✅ Database engine enabled${NC}" || echo -e "${YELLOW}⚠️  Database engine already enabled${NC}"

# Step 6: Configure PostgreSQL
echo ""
echo "📋 Step 6: Configure PostgreSQL Connection"
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="backend-role" \
    connection_url="postgresql://{{username}}:{{password}}@postgresql.99-apps.svc.cluster.local:5432/appdb?sslmode=disable" \
    username="postgres" \
    password="postgres"

echo -e "${GREEN}✅ PostgreSQL connection configured${NC}"

# Step 7: Create Database Role
echo ""
echo "📋 Step 7: Create Database Role"
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao write database/roles/backend-role \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="2h"

echo -e "${GREEN}✅ Database role created${NC}"

# Step 8: Create Backend Policy
echo ""
echo "📋 Step 8: Create Backend Policy"
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  sh -c 'cat > /tmp/backend-policy.hcl <<EOF
# Backend service policy
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
env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN='$ROOT_TOKEN' bao policy write backend-policy /tmp/backend-policy.hcl'

echo -e "${GREEN}✅ Backend policy created${NC}"

# Step 9: Test Database Credentials
echo ""
echo "📋 Step 9: Test Database Credential Generation"
kubectl exec -n openbao deploy/openbao -- \
  env BAO_ADDR=https://127.0.0.1:8200 BAO_SKIP_VERIFY=true BAO_TOKEN=$ROOT_TOKEN \
  bao read database/creds/backend-role

echo ""
echo -e "${GREEN}✅ OpenBao JWT Auth Configuration Complete!${NC}"
echo ""
echo "Summary:"
echo "  - JWT auth: ✅ Enabled with SPIRE OIDC discovery"
echo "  - KV v2:    ✅ Enabled at secret/"
echo "  - Database: ✅ Enabled with PostgreSQL connection"
echo "  - Role:     ✅ backend-role created (1h TTL)"
echo "  - Policy:   ✅ backend-policy created"
echo ""
echo "Next: Update backend ConfigMap to use HTTPS and restart"
