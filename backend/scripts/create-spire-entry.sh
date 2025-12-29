#!/bin/bash
# Create SPIRE registration entry for backend service
# Run this script after deploying backend to Kubernetes

set -e

echo "🔐 Creating SPIRE registration entry for backend service..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if SPIRE server is running
if ! kubectl get pod -n spire-system spire-server-0 &>/dev/null; then
    echo -e "${RED}❌ SPIRE server not found${NC}"
    echo "Please ensure SPIRE is deployed to the cluster"
    exit 1
fi

echo -e "${YELLOW}Creating registration entry...${NC}"

# Create registration entry for backend
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://demo.local/ns/99-apps/sa/backend \
    -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99 \
    -selector k8s:ns:99-apps \
    -selector k8s:sa:backend \
    -ttl 3600

echo ""
echo -e "${GREEN}✅ Registration entry created${NC}"
echo ""
echo "Verifying entry..."

# Verify entry created
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show \
    -spiffeID spiffe://demo.local/ns/99-apps/sa/backend

echo ""
echo -e "${GREEN}✅ Backend SPIRE entry configured successfully!${NC}"
