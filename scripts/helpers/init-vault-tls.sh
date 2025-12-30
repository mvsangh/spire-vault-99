#!/bin/bash
# Initialize and configure OpenBao with TLS
# This script:
# 1. Initializes OpenBao (generates unseal keys and root token)
# 2. Unseals OpenBao
# 3. Enables cert auth method
# 4. Configures cert auth with SPIRE trust bundle
# 5. Enables secrets engines
# 6. Creates policies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}OpenBao Initialization & Configuration${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Set BAO environment variables
export BAO_ADDR='https://openbao.openbao.svc.cluster.local:8200'
export BAO_SKIP_VERIFY='true'  # For demo with self-signed certs

# File to store init output
INIT_OUTPUT="/tmp/vault-init.json"
UNSEAL_KEYS_FILE="/tmp/vault-unseal-keys.txt"
ROOT_TOKEN_FILE="/tmp/vault-root-token.txt"

#
# Step 1: Check if already initialized
#
echo -e "${BLUE}📋 Step 1: Checking OpenBao Status${NC}"

if kubectl exec -n openbao deploy/openbao -- env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true bao status -format=json 2>/dev/null | jq -e '.initialized == true' > /dev/null; then
    echo -e "${YELLOW}⚠️  OpenBao is already initialized${NC}"
    echo -e "${YELLOW}If you want to reinitialize, delete the PVC and redeploy:${NC}"
    echo -e "${YELLOW}  kubectl delete pvc -n openbao openbao-data${NC}"
    echo -e "${YELLOW}  kubectl delete pod -n openbao -l app=openbao${NC}"

    read -p "Do you want to reconfigure existing OpenBao instance? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}ℹ️  Exiting without changes${NC}"
        exit 0
    fi

    # Ask for root token
    echo -e "${BLUE}Please enter the root token:${NC}"
    read -s ROOT_TOKEN
    export BAO_TOKEN="${ROOT_TOKEN}"

    SKIP_INIT=true
else
    echo -e "${GREEN}✅ OpenBao is not initialized - proceeding with initialization${NC}"
    SKIP_INIT=false
fi

#
# Step 2: Initialize OpenBao (if needed)
#
if [ "$SKIP_INIT" = false ]; then
    echo -e "\n${BLUE}📋 Step 2: Initializing OpenBao${NC}"

    # Initialize with 5 key shares and 3 key threshold (Shamir's Secret Sharing)
    kubectl exec -n openbao deploy/openbao -- \
        env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true \
        bao operator init \
        -key-shares=5 \
        -key-threshold=3 \
        -format=json > "${INIT_OUTPUT}"

    # Extract unseal keys and root token
    jq -r '.unseal_keys_b64[]' "${INIT_OUTPUT}" > "${UNSEAL_KEYS_FILE}"
    jq -r '.root_token' "${INIT_OUTPUT}" > "${ROOT_TOKEN_FILE}"

    ROOT_TOKEN=$(cat "${ROOT_TOKEN_FILE}")
    export BAO_TOKEN="${ROOT_TOKEN}"

    echo -e "${GREEN}✅ OpenBao initialized successfully${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT: Save these credentials securely!${NC}"
    echo -e "${YELLOW}Unseal keys saved to: ${UNSEAL_KEYS_FILE}${NC}"
    echo -e "${YELLOW}Root token saved to: ${ROOT_TOKEN_FILE}${NC}"
    echo ""
    echo -e "${YELLOW}Unseal Keys:${NC}"
    cat "${UNSEAL_KEYS_FILE}"
    echo ""
    echo -e "${YELLOW}Root Token:${NC}"
    cat "${ROOT_TOKEN_FILE}"
    echo ""

    #
    # Step 3: Unseal OpenBao
    #
    echo -e "\n${BLUE}📋 Step 3: Unsealing OpenBao${NC}"

    # Unseal with first 3 keys (threshold)
    COUNTER=1
    while read -r UNSEAL_KEY && [ $COUNTER -le 3 ]; do
        echo -e "${BLUE}Unsealing with key ${COUNTER}/3...${NC}"
        kubectl exec -n openbao deploy/openbao -- \
            env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true \
            bao operator unseal "${UNSEAL_KEY}" > /dev/null
        COUNTER=$((COUNTER + 1))
    done < "${UNSEAL_KEYS_FILE}"

    echo -e "${GREEN}✅ OpenBao unsealed successfully${NC}"

    # Wait for OpenBao to be ready
    echo -e "${BLUE}Waiting for OpenBao to be ready...${NC}"
    sleep 5
else
    echo -e "\n${BLUE}📋 Step 2-3: Skipped (already initialized)${NC}"
fi

#
# Step 4: Enable Cert Auth Method
#
echo -e "\n${BLUE}📋 Step 4: Enabling Cert Auth Method${NC}"

if kubectl exec -n openbao deploy/openbao -- \
    env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true BAO_TOKEN="${BAO_TOKEN}" \
    bao auth list -format=json | jq -e '.["cert/"]' > /dev/null 2>&1; then
    echo -e "${YELLOW}✓ Cert auth already enabled${NC}"
else
    echo -e "${BLUE}Enabling cert auth...${NC}"
    kubectl exec -n openbao deploy/openbao -- \
        env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true BAO_TOKEN="${BAO_TOKEN}" \
        bao auth enable cert
    echo -e "${GREEN}✅ Cert auth enabled${NC}"
fi

#
# Step 5: Configure Cert Auth with SPIRE Trust Bundle
#
echo -e "\n${BLUE}📋 Step 5: Configuring Cert Auth with SPIRE Trust Bundle${NC}"

# Get SPIRE trust bundle from ConfigMap
echo -e "${BLUE}Fetching SPIRE trust bundle...${NC}"
kubectl get configmap -n spire-system spire-bundle -o jsonpath='{.data.bundle\.crt}' > /tmp/spire-bundle.crt

if [ ! -s /tmp/spire-bundle.crt ]; then
    echo -e "${RED}❌ Failed to fetch SPIRE trust bundle${NC}"
    echo -e "${YELLOW}Make sure SPIRE is running and the spire-bundle ConfigMap exists${NC}"
    exit 1
fi

echo -e "${GREEN}✅ SPIRE trust bundle fetched${NC}"

# Copy bundle to OpenBao pod
kubectl cp /tmp/spire-bundle.crt openbao/$(kubectl get pod -n openbao -l app=openbao -o jsonpath='{.items[0].metadata.name}'):/tmp/bundle.crt

# Configure cert auth role for backend
echo -e "${BLUE}Configuring backend-role for cert auth...${NC}"

kubectl exec -n openbao deploy/openbao -- \
    env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true BAO_TOKEN="${BAO_TOKEN}" \
    bao write auth/cert/certs/backend-role \
    certificate=@/tmp/bundle.crt \
    allowed_common_names="spiffe://demo.local/ns/99-apps/sa/backend" \
    allowed_uri_sans="spiffe://demo.local/ns/99-apps/sa/backend" \
    token_policies="backend-policy" \
    token_ttl=3600 \
    token_max_ttl=7200

echo -e "${GREEN}✅ Cert auth configured for backend${NC}"

#
# Step 6: Enable KV v2 Secrets Engine
#
echo -e "\n${BLUE}📋 Step 6: Enabling KV v2 Secrets Engine${NC}"

if kubectl exec -n openbao deploy/openbao -- \
    env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true BAO_TOKEN="${BAO_TOKEN}" \
    bao secrets list -format=json | jq -e '.["secret/"]' > /dev/null 2>&1; then
    echo -e "${YELLOW}✓ KV v2 already enabled at secret/${NC}"
else
    echo -e "${BLUE}Enabling KV v2 at secret/...${NC}"
    kubectl exec -n openbao deploy/openbao -- \
        env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true BAO_TOKEN="${BAO_TOKEN}" \
        bao secrets enable -version=2 -path=secret kv
    echo -e "${GREEN}✅ KV v2 enabled${NC}"
fi

#
# Step 7: Enable Database Secrets Engine
#
echo -e "\n${BLUE}📋 Step 7: Enabling Database Secrets Engine${NC}"

if kubectl exec -n openbao deploy/openbao -- \
    env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true BAO_TOKEN="${BAO_TOKEN}" \
    bao secrets list -format=json | jq -e '.["database/"]' > /dev/null 2>&1; then
    echo -e "${YELLOW}✓ Database secrets engine already enabled${NC}"
else
    echo -e "${BLUE}Enabling database secrets engine...${NC}"
    kubectl exec -n openbao deploy/openbao -- \
        env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true BAO_TOKEN="${BAO_TOKEN}" \
        bao secrets enable database
    echo -e "${GREEN}✅ Database secrets engine enabled${NC}"
fi

#
# Step 8: Configure PostgreSQL Connection
#
echo -e "\n${BLUE}📋 Step 8: Configuring PostgreSQL Connection${NC}"

kubectl exec -n openbao deploy/openbao -- \
    env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true BAO_TOKEN="${BAO_TOKEN}" \
    bao write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    allowed_roles="backend-role" \
    connection_url="postgresql://{{username}}:{{password}}@postgresql.99-apps.svc.cluster.local:5432/appdb?sslmode=disable" \
    username="postgres" \
    password="postgres"

echo -e "${GREEN}✅ PostgreSQL connection configured${NC}"

#
# Step 9: Create Database Role
#
echo -e "\n${BLUE}📋 Step 9: Creating Database Role${NC}"

kubectl exec -n openbao deploy/openbao -- \
    env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true BAO_TOKEN="${BAO_TOKEN}" \
    bao write database/roles/backend-role \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT; \
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\"; \
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"{{name}}\"; \
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO \"{{name}}\";" \
    default_ttl=3600 \
    max_ttl=7200

echo -e "${GREEN}✅ Database role created${NC}"

#
# Step 10: Create Backend Policy
#
echo -e "\n${BLUE}📋 Step 10: Creating Backend Policy${NC}"

kubectl exec -n openbao deploy/openbao -- sh -c "cat > /tmp/backend-policy.hcl <<'EOF'
# Backend policy - allows access to secrets and database credentials

# Read/write access to KV v2 secrets (GitHub tokens)
path \"secret/data/*\" {
  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]
}

path \"secret/metadata/*\" {
  capabilities = [\"list\", \"read\", \"delete\"]
}

# Generate database credentials
path \"database/creds/backend-role\" {
  capabilities = [\"read\"]
}

# Renew own token
path \"auth/token/renew-self\" {
  capabilities = [\"update\"]
}
EOF"

kubectl exec -n openbao deploy/openbao -- \
    env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true BAO_TOKEN="${BAO_TOKEN}" \
    bao policy write backend-policy /tmp/backend-policy.hcl

echo -e "${GREEN}✅ Backend policy created${NC}"

#
# Step 11: Test Configuration
#
echo -e "\n${BLUE}📋 Step 11: Testing Configuration${NC}"

echo -e "${BLUE}Testing database credential generation...${NC}"
if kubectl exec -n openbao deploy/openbao -- \
    env BAO_ADDR="${BAO_ADDR}" BAO_SKIP_VERIFY=true BAO_TOKEN="${BAO_TOKEN}" \
    bao read database/creds/backend-role; then
    echo -e "${GREEN}✅ Database credential generation works!${NC}"
else
    echo -e "${YELLOW}⚠️  Database credential test failed${NC}"
fi

#
# Summary
#
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✅ OpenBao Configuration Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Configuration summary:"
echo "  - OpenBao initialized and unsealed"
echo "  - Cert auth method enabled and configured with SPIRE trust bundle"
echo "  - KV v2 secrets engine enabled at secret/"
echo "  - Database secrets engine enabled"
echo "  - PostgreSQL connection configured"
echo "  - Database role 'backend-role' created"
echo "  - Policy 'backend-policy' created"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Securely store the unseal keys and root token!${NC}"
echo "  Unseal keys: ${UNSEAL_KEYS_FILE}"
echo "  Root token: ${ROOT_TOKEN_FILE}"
echo ""
echo "For demo purposes, root token:"
echo "  $(cat ${ROOT_TOKEN_FILE} 2>/dev/null || echo 'N/A')"
echo ""
echo "Next steps:"
echo "  1. Update backend configuration to use HTTPS: VAULT_ADDR=https://openbao.openbao.svc.cluster.local:8200"
echo "  2. Restart backend pods to use new configuration"
echo "  3. Verify cert auth works with SPIRE certificates"
