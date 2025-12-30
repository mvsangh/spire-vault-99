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
# 1. Enable Cert Auth Method
#
echo ""
echo "📋 Step 1: Enable Cert Auth Method"
if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao auth list | grep -q "cert/"; then
    echo -e "${YELLOW}✓ Cert auth already enabled${NC}"
else
    echo "Enabling cert auth..."
    kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao auth enable cert
    echo -e "${GREEN}✅ Cert auth enabled${NC}"
fi

#
# 2. Get SPIRE Trust Bundle
#
echo ""
echo "📋 Step 2: Extract SPIRE Trust Bundle"
kubectl get configmap -n spire-system spire-bundle -o jsonpath='{.data.bundle\.crt}' > /tmp/spire-bundle.crt
echo -e "${GREEN}✅ Trust bundle extracted${NC}"
cat /tmp/spire-bundle.crt

#
# 3. Configure Cert Auth with SPIRE CA
#
echo ""
echo "📋 Step 3: Configure Cert Auth with SPIRE CA"
kubectl exec -n openbao deploy/openbao -- sh -c "cat > /tmp/bundle.crt <<'EOF'
$(cat /tmp/spire-bundle.crt)
EOF"

# Check if backend-role exists
if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao list auth/cert/certs 2>/dev/null | grep -q "backend-role"; then
    echo -e "${YELLOW}✓ backend-role already exists${NC}"
else
    echo "Creating backend-role for cert auth..."
    kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao write auth/cert/certs/backend-role \
        certificate=@/tmp/bundle.crt \
        allowed_common_names="spiffe://demo.local/ns/99-apps/sa/backend" \
        token_policies="backend-policy" \
        token_ttl=3600 \
        token_max_ttl=7200
    echo -e "${GREEN}✅ backend-role created${NC}"
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
echo "  - Cert auth: ✅ Enabled with SPIRE trust bundle"
echo "  - KV v2:     ✅ Enabled at secret/"
echo "  - Database:  ✅ Enabled with PostgreSQL connection"
echo "  - Role:      ✅ backend-role created (1h TTL)"
echo "  - Policy:    ✅ backend-policy created"
echo ""
echo "Next: Deploy backend to test mTLS authentication!"

# Cleanup
rm -f /tmp/spire-bundle.crt
