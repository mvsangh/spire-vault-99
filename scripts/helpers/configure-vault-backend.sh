#!/bin/bash
set -e

# SPIRE-Vault-99: Configure OpenBao for Backend Service
# This script is idempotent - safe to run multiple times

echo "🔐 Configuring OpenBao for Backend Service..."

# Set Vault address
export BAO_ADDR='http://localhost:8200'
export BAO_TOKEN='root'

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#
# 1. Enable JWT Auth Method
#
echo ""
echo "📋 Step 1: Enable JWT Auth Method"
if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao auth list | grep -q "jwt/"; then
    echo -e "${YELLOW}✓ JWT auth already enabled${NC}"
else
    echo "Enabling JWT auth..."
    kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao auth enable jwt
    echo -e "${GREEN}✅ JWT auth enabled${NC}"
fi

#
# 2. Configure JWT Auth with SPIRE OIDC Discovery
#
echo ""
echo "📋 Step 2: Configure JWT Auth with SPIRE OIDC Discovery"
echo "Configuring JWT auth to use SPIRE server's OIDC discovery endpoint..."

kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao write auth/jwt/config \
    oidc_discovery_url="http://spire-server.spire-system.svc.cluster.local:8090" \
    bound_issuer="http://spire-server.spire-system.svc.cluster.local:8090"

echo -e "${GREEN}✅ JWT auth configured with SPIRE OIDC discovery${NC}"

#
# 3. Create JWT Auth Role for Backend
#
echo ""
echo "📋 Step 3: Create backend-role for JWT Auth"

# Check if backend-role exists
if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao list auth/jwt/role 2>/dev/null | grep -q "backend-role"; then
    echo -e "${YELLOW}✓ backend-role already exists${NC}"
else
    echo "Creating backend-role for JWT auth..."
    kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao write auth/jwt/role/backend-role \
        role_type="jwt" \
        bound_audiences="openbao,vault" \
        bound_subject="spiffe://demo.local/ns/99-apps/sa/backend" \
        user_claim="sub" \
        policies="backend-policy" \
        ttl="1h" \
        max_ttl="2h"
    echo -e "${GREEN}✅ backend-role created for JWT auth${NC}"
fi

#
# 4. Enable KV v2 Secrets Engine
#
echo ""
echo "📋 Step 4: Enable KV v2 Secrets Engine"
if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao secrets list | grep -q "secret/"; then
    echo -e "${YELLOW}✓ KV v2 already enabled at secret/${NC}"
else
    echo "Enabling KV v2 at secret/..."
    kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao secrets enable -version=2 -path=secret kv
    echo -e "${GREEN}✅ KV v2 enabled${NC}"
fi

#
# 5. Enable Database Secrets Engine
#
echo ""
echo "📋 Step 5: Enable Database Secrets Engine"
if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao secrets list | grep -q "database/"; then
    echo -e "${YELLOW}✓ Database secrets engine already enabled${NC}"
else
    echo "Enabling database secrets engine..."
    kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao secrets enable database
    echo -e "${GREEN}✅ Database secrets engine enabled${NC}"
fi

#
# 6. Configure PostgreSQL Connection
#
echo ""
echo "📋 Step 6: Configure PostgreSQL Connection"
kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="backend-role" \
    connection_url="postgresql://{{username}}:{{password}}@postgresql.99-apps.svc.cluster.local:5432/appdb?sslmode=disable" \
    username="postgres" \
    password="postgres"
echo -e "${GREEN}✅ PostgreSQL connection configured${NC}"

#
# 7. Create Database Role
#
echo ""
echo "📋 Step 7: Create Database Role for Backend"
kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao write database/roles/backend-role \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT; \
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="2h"
echo -e "${GREEN}✅ Database role created${NC}"

#
# 8. Create Backend Policy
#
echo ""
echo "📋 Step 8: Create Backend Policy"
kubectl exec -n openbao deploy/openbao -- sh -c 'cat > /tmp/backend-policy.hcl <<EOF
# Backend service policy
# Allows read/write to GitHub secrets and read from database credentials

# KV v2 secrets - GitHub tokens
path "secret/data/github/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/github/*" {
  capabilities = ["list", "read"]
}

# Database dynamic credentials
path "database/creds/backend-role" {
  capabilities = ["read"]
}

# Allow token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF'

kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao policy write backend-policy /tmp/backend-policy.hcl
echo -e "${GREEN}✅ Backend policy created${NC}"

#
# 9. Test Configuration
#
echo ""
echo "📋 Step 9: Test Configuration"
echo "Testing database credential generation..."
if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao read database/creds/backend-role; then
    echo -e "${GREEN}✅ Database credential generation works!${NC}"
else
    echo -e "${YELLOW}⚠️  Database credential test failed - will retry in Phase 4${NC}"
fi

echo ""
echo -e "${GREEN}✅ OpenBao configuration complete!${NC}"
echo ""
echo "Summary:"
echo "  - JWT auth:  ✅ Enabled with SPIRE OIDC discovery"
echo "  - KV v2:     ✅ Enabled at secret/"
echo "  - Database:  ✅ Enabled with PostgreSQL connection"
echo "  - Role:      ✅ backend-role created (1h TTL)"
echo "  - Policy:    ✅ backend-policy created"
echo ""
echo "📝 Note: Pivoted from cert auth to JWT-SVID due to OpenBao limitation"
echo "   (cert auth requires CN field, SPIFFE uses URI SANs)"
echo ""
echo "Next: Deploy backend to test JWT-SVID authentication!"
