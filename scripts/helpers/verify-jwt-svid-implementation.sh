#!/bin/bash
# Verification Script for JWT-SVID Implementation
# Tests all components of the authentication pivot

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  JWT-SVID Implementation Verification Script  ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Track results
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function for test results
pass_test() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

fail_test() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

warn_test() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
}

#
# Test 1: SPIRE Server OIDC Discovery Plugin
#
echo ""
echo -e "${BLUE}Test 1: SPIRE Server OIDC Discovery Plugin${NC}"
echo "Checking if SPIRE server has OIDC discovery plugin configured..."

if kubectl get configmap -n spire-system spire-server -o yaml | grep -q "oidc_discovery"; then
    pass_test "OIDC discovery plugin configured in SPIRE server ConfigMap"
else
    fail_test "OIDC discovery plugin NOT found in SPIRE server ConfigMap"
fi

#
# Test 2: SPIRE Server Service - OIDC Port
#
echo ""
echo -e "${BLUE}Test 2: SPIRE Server Service - OIDC Port${NC}"
echo "Checking if SPIRE server service exposes port 8090..."

if kubectl get service -n spire-system spire-server -o yaml | grep -q "8090"; then
    pass_test "SPIRE server service exposes port 8090 for OIDC"
else
    fail_test "SPIRE server service does NOT expose port 8090"
fi

#
# Test 3: SPIRE Server Pod Status
#
echo ""
echo -e "${BLUE}Test 3: SPIRE Server Pod Status${NC}"
echo "Checking if SPIRE server pod is running..."

if kubectl get pods -n spire-system -l app=spire-server -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
    pass_test "SPIRE server pod is Running"

    # Check if OIDC endpoint is accessible
    echo "Testing OIDC discovery endpoint..."
    if kubectl exec -n spire-system spire-server-0 -- curl -s -f http://localhost:8090/.well-known/openid-configuration > /dev/null 2>&1; then
        pass_test "OIDC discovery endpoint is accessible"

        # Show the OIDC configuration
        echo -e "${YELLOW}OIDC Discovery Configuration:${NC}"
        kubectl exec -n spire-system spire-server-0 -- curl -s http://localhost:8090/.well-known/openid-configuration | head -20
    else
        fail_test "OIDC discovery endpoint is NOT accessible"
        warn_test "SPIRE server may need to be restarted to load OIDC plugin"
    fi
else
    fail_test "SPIRE server pod is NOT running"
fi

#
# Test 4: OpenBao JWT Auth Method
#
echo ""
echo -e "${BLUE}Test 4: OpenBao JWT Auth Method${NC}"
echo "Checking if OpenBao has JWT auth enabled..."

if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao auth list 2>/dev/null | grep -q "jwt/"; then
    pass_test "OpenBao JWT auth method is enabled"
else
    fail_test "OpenBao JWT auth method is NOT enabled"
    warn_test "Run: ./scripts/helpers/configure-vault-backend.sh"
fi

#
# Test 5: OpenBao JWT Auth Configuration
#
echo ""
echo -e "${BLUE}Test 5: OpenBao JWT Auth Configuration${NC}"
echo "Checking OpenBao JWT auth configuration..."

if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao read auth/jwt/config 2>/dev/null | grep -q "spire-server"; then
    pass_test "OpenBao JWT auth configured with SPIRE OIDC discovery"

    echo -e "${YELLOW}JWT Auth Config:${NC}"
    kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao read auth/jwt/config 2>/dev/null | grep -E "(oidc_discovery_url|bound_issuer)"
else
    fail_test "OpenBao JWT auth NOT configured with SPIRE"
    warn_test "Run: ./scripts/helpers/configure-vault-backend.sh"
fi

#
# Test 6: OpenBao JWT Auth Role
#
echo ""
echo -e "${BLUE}Test 6: OpenBao JWT Auth Role${NC}"
echo "Checking if backend-role exists in JWT auth..."

if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao list auth/jwt/role 2>/dev/null | grep -q "backend-role"; then
    pass_test "backend-role exists in JWT auth"

    echo -e "${YELLOW}Backend Role Config:${NC}"
    kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao read auth/jwt/role/backend-role 2>/dev/null | grep -E "(bound_audiences|bound_subject|policies)"
else
    fail_test "backend-role NOT found in JWT auth"
    warn_test "Run: ./scripts/helpers/configure-vault-backend.sh"
fi

#
# Test 7: Backend Application Code Changes
#
echo ""
echo -e "${BLUE}Test 7: Backend Application Code Changes${NC}"
echo "Checking if backend code has JWT-SVID support..."

# Check spire.py for fetch_jwt_svid method
if grep -q "fetch_jwt_svid" backend/app/core/spire.py; then
    pass_test "backend/app/core/spire.py has fetch_jwt_svid() method"
else
    fail_test "backend/app/core/spire.py missing fetch_jwt_svid() method"
fi

# Check vault.py for JWT auth
if grep -q "auth.jwt.login" backend/app/core/vault.py; then
    pass_test "backend/app/core/vault.py uses JWT authentication"
else
    fail_test "backend/app/core/vault.py still using cert auth"
fi

# Check config.py for JWT audience
if grep -q "JWT_SVID_AUDIENCE" backend/app/config.py; then
    pass_test "backend/app/config.py has JWT_SVID_AUDIENCE config"
else
    fail_test "backend/app/config.py missing JWT_SVID_AUDIENCE"
fi

#
# Test 8: Backend ConfigMap
#
echo ""
echo -e "${BLUE}Test 8: Backend ConfigMap${NC}"
echo "Checking if backend ConfigMap has JWT audience..."

if kubectl get configmap -n 99-apps backend-config -o yaml 2>/dev/null | grep -q "JWT_SVID_AUDIENCE"; then
    pass_test "Backend ConfigMap has JWT_SVID_AUDIENCE"

    AUDIENCE=$(kubectl get configmap -n 99-apps backend-config -o jsonpath='{.data.JWT_SVID_AUDIENCE}' 2>/dev/null)
    echo -e "${YELLOW}Configured audiences: ${AUDIENCE}${NC}"
else
    fail_test "Backend ConfigMap missing JWT_SVID_AUDIENCE"
    warn_test "Apply: kubectl apply -f backend/k8s/configmap.yaml"
fi

#
# Test 9: Backend Pod Status (if exists)
#
echo ""
echo -e "${BLUE}Test 9: Backend Pod Status${NC}"
echo "Checking if backend pod exists and is running..."

if kubectl get pods -n 99-apps -l app=backend &>/dev/null; then
    if kubectl get pods -n 99-apps -l app=backend -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
        pass_test "Backend pod is Running"

        # Check logs for JWT-SVID authentication
        echo "Checking backend logs for JWT-SVID authentication..."
        sleep 2

        if kubectl logs -n 99-apps -l app=backend --tail=100 2>/dev/null | grep -q "JWT-SVID"; then
            pass_test "Backend logs show JWT-SVID activity"
        else
            warn_test "Backend logs don't show JWT-SVID yet (may need restart)"
        fi

        if kubectl logs -n 99-apps -l app=backend --tail=100 2>/dev/null | grep -q "Vault authenticated (JWT)"; then
            pass_test "Backend successfully authenticated to Vault with JWT"
        else
            warn_test "Backend has not authenticated to Vault yet"
        fi
    else
        fail_test "Backend pod is NOT running"
    fi
else
    warn_test "Backend pod not deployed yet"
fi

#
# Test 10: Documentation Updates
#
echo ""
echo -e "${BLUE}Test 10: Documentation Updates${NC}"
echo "Checking if documentation reflects JWT-SVID pivot..."

if grep -q "JWT auth" docs/MASTER_SPRINT.md; then
    pass_test "MASTER_SPRINT.md updated with JWT auth"
else
    fail_test "MASTER_SPRINT.md still shows cert auth"
fi

if grep -q "PIVOT NOTE" docs/sprint-2-backend.md; then
    pass_test "sprint-2-backend.md has pivot note"
else
    fail_test "sprint-2-backend.md missing pivot note"
fi

#
# Summary
#
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}                TEST SUMMARY                   ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Tests Passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Tests Failed: ${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. If backend is not deployed, deploy it with: tilt up"
    echo "  2. Test authentication with: kubectl logs -f -n 99-apps -l app=backend"
    echo "  3. Verify Vault secrets work: curl http://localhost:8000/api/v1/health/ready"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo ""
    echo "Recommended fixes:"

    if kubectl exec -n spire-system spire-server-0 -- curl -s -f http://localhost:8090/.well-known/openid-configuration > /dev/null 2>&1; then
        :
    else
        echo "  - Restart SPIRE server: kubectl rollout restart statefulset/spire-server -n spire-system"
    fi

    if kubectl exec -n openbao deploy/openbao -- env BAO_TOKEN=root bao auth list 2>/dev/null | grep -q "jwt/"; then
        :
    else
        echo "  - Configure OpenBao: ./scripts/helpers/configure-vault-backend.sh"
    fi

    if kubectl get configmap -n 99-apps backend-config -o yaml 2>/dev/null | grep -q "JWT_SVID_AUDIENCE"; then
        :
    else
        echo "  - Apply backend config: kubectl apply -f backend/k8s/configmap.yaml"
    fi

    exit 1
fi
