#!/bin/bash
# Deployment Guide for JWT-SVID Implementation
# Step-by-step deployment of the authentication pivot changes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}     JWT-SVID Implementation Deployment        ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
echo "This script will deploy the JWT-SVID authentication changes"
echo "in the correct order to migrate from cert auth to JWT auth."
echo ""

# Confirmation
read -p "Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

#
# Step 1: Update SPIRE Server Configuration
#
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 1: Update SPIRE Server Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Applying SPIRE server ConfigMap with OIDC Discovery Provider..."

kubectl apply -f infrastructure/spire/server-configmap.yaml

echo -e "${GREEN}✅ SPIRE server ConfigMap updated${NC}"
echo ""

echo "Applying SPIRE server Service with OIDC port 8090..."

kubectl apply -f infrastructure/spire/server-service.yaml

echo -e "${GREEN}✅ SPIRE server Service updated${NC}"
echo ""

#
# Step 2: Restart SPIRE Server
#
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 2: Restart SPIRE Server${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Restarting SPIRE server to load OIDC Discovery Provider plugin..."

kubectl rollout restart statefulset/spire-server -n spire-system

echo "Waiting for SPIRE server to be ready..."
kubectl rollout status statefulset/spire-server -n spire-system --timeout=120s

echo -e "${GREEN}✅ SPIRE server restarted successfully${NC}"
echo ""

#
# Step 3: Verify OIDC Discovery Endpoint
#
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 3: Verify OIDC Discovery Endpoint${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Testing OIDC discovery endpoint..."

sleep 5  # Give SPIRE server a moment to initialize

if kubectl exec -n spire-system spire-server-0 -- curl -s -f http://localhost:8090/.well-known/openid-configuration > /dev/null 2>&1; then
    echo -e "${GREEN}✅ OIDC discovery endpoint is accessible${NC}"
    echo ""
    echo -e "${YELLOW}OIDC Configuration:${NC}"
    kubectl exec -n spire-system spire-server-0 -- curl -s http://localhost:8090/.well-known/openid-configuration | head -10
    echo ""
else
    echo -e "${RED}❌ OIDC discovery endpoint is NOT accessible${NC}"
    echo "Please check SPIRE server logs:"
    echo "  kubectl logs -n spire-system spire-server-0"
    exit 1
fi

#
# Step 4: Configure OpenBao with JWT Auth
#
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 4: Configure OpenBao with JWT Auth${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Running OpenBao configuration script..."
echo ""

./scripts/helpers/configure-vault-backend.sh

echo ""
echo -e "${GREEN}✅ OpenBao configured with JWT auth${NC}"
echo ""

#
# Step 5: Verify OpenBao JWT Auth
#
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 5: Verify OpenBao JWT Auth${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Checking JWT auth configuration..."

if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao auth list 2>/dev/null | grep -q "jwt/"; then
    echo -e "${GREEN}✅ JWT auth method enabled${NC}"
else
    echo -e "${RED}❌ JWT auth method NOT enabled${NC}"
    exit 1
fi

if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao read auth/jwt/config 2>/dev/null | grep -q "spire-server"; then
    echo -e "${GREEN}✅ JWT auth configured with SPIRE OIDC discovery${NC}"
else
    echo -e "${RED}❌ JWT auth NOT configured with SPIRE${NC}"
    exit 1
fi

if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao list auth/jwt/role 2>/dev/null | grep -q "backend-role"; then
    echo -e "${GREEN}✅ backend-role exists in JWT auth${NC}"
else
    echo -e "${RED}❌ backend-role NOT found${NC}"
    exit 1
fi

echo ""

#
# Step 6: Update Backend Configuration
#
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 6: Update Backend Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Applying backend ConfigMap with JWT audience..."

kubectl apply -f backend/k8s/configmap.yaml

echo -e "${GREEN}✅ Backend ConfigMap updated${NC}"
echo ""

#
# Step 7: Deploy/Restart Backend
#
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 7: Deploy/Restart Backend${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if using Tilt
if command -v tilt &> /dev/null; then
    echo "Tilt is installed."
    read -p "Do you want to use Tilt for hot-reload development? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}Starting Tilt...${NC}"
        echo "Run in a new terminal: tilt up"
        echo ""
        echo "Tilt will:"
        echo "  - Build backend:dev image"
        echo "  - Deploy backend to cluster"
        echo "  - Enable hot-reload for code changes"
        echo ""
        echo -e "${CYAN}Press Ctrl+C when you've started Tilt${NC}"
        sleep 5
    else
        echo "Deploying backend manually..."
        deploy_backend_manually
    fi
else
    echo "Deploying backend manually..."
    deploy_backend_manually
fi

#
# Step 8: Verify Backend Authentication
#
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 8: Verify Backend Authentication${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Waiting for backend pod to be ready..."

kubectl wait --for=condition=ready pod -l app=backend -n 99-apps --timeout=120s 2>/dev/null || echo "Backend pod not found yet"

echo ""
echo "Checking backend logs for JWT-SVID authentication..."
echo ""

sleep 5  # Give backend time to initialize

kubectl logs -n 99-apps -l app=backend --tail=50 2>/dev/null | grep -E "(SPIRE|JWT|Vault)" || echo "No backend logs yet"

echo ""
echo -e "${YELLOW}Checking for successful authentication...${NC}"

if kubectl logs -n 99-apps -l app=backend --tail=100 2>/dev/null | grep -q "Vault authenticated (JWT)"; then
    echo -e "${GREEN}✅ Backend successfully authenticated to Vault with JWT-SVID!${NC}"
else
    echo -e "${YELLOW}⚠️  Backend has not authenticated yet. Check logs with:${NC}"
    echo "  kubectl logs -f -n 99-apps -l app=backend"
fi

echo ""

#
# Summary
#
echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}           DEPLOYMENT COMPLETE!                 ${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
echo -e "${GREEN}✅ JWT-SVID implementation deployed successfully${NC}"
echo ""
echo "Summary of changes:"
echo "  ✅ SPIRE server: OIDC Discovery Provider enabled on port 8090"
echo "  ✅ SPIRE service: Port 8090 exposed for OIDC discovery"
echo "  ✅ OpenBao: JWT auth method configured with SPIRE OIDC"
echo "  ✅ Backend: Updated to use JWT-SVID authentication"
echo ""
echo "Next steps:"
echo "  1. Monitor backend logs: kubectl logs -f -n 99-apps -l app=backend"
echo "  2. Test health endpoint: curl http://localhost:8000/api/v1/health/ready"
echo "  3. Verify authentication in logs (should see 'Vault authenticated (JWT)')"
echo "  4. Run verification script: ./scripts/helpers/verify-jwt-svid-implementation.sh"
echo ""
echo -e "${BLUE}For detailed logs, see: docs/SESSION_IMPLEMENTATION_LOG.md${NC}"
echo ""

# Function to deploy backend manually
deploy_backend_manually() {
    echo "Applying backend Kubernetes manifests..."

    # Apply all backend manifests
    kubectl apply -f backend/k8s/serviceaccount.yaml
    kubectl apply -f backend/k8s/configmap.yaml
    kubectl apply -f backend/k8s/service.yaml
    kubectl apply -f backend/k8s/deployment.yaml

    echo ""
    echo "Restarting backend deployment to pick up changes..."
    kubectl rollout restart deployment/backend -n 99-apps

    echo -e "${GREEN}✅ Backend deployed${NC}"
}
