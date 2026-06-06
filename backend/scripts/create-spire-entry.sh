#!/bin/bash
# Create SPIRE registration entry for backend service
# Dynamically discovers agent SPIFFE IDs so entries work on any node.

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SPIFFE_ID="spiffe://demo.local/ns/99-apps/sa/backend"
CONTAINER="-c spire-server"

echo -e "${YELLOW}Creating SPIRE registration entries for backend...${NC}"

if ! kubectl get pod -n spire-system spire-server-0 &>/dev/null; then
    echo -e "${RED}❌ SPIRE server not found${NC}"
    exit 1
fi

# Remove any stale entries for this SPIFFE ID
EXISTING=$(kubectl exec -n spire-system spire-server-0 $CONTAINER -- \
  /opt/spire/bin/spire-server entry show -spiffeID "$SPIFFE_ID" 2>/dev/null | grep "^Entry ID" | awk '{print $NF}')

for ENTRY_ID in $EXISTING; do
    echo "Deleting stale entry: $ENTRY_ID"
    kubectl exec -n spire-system spire-server-0 $CONTAINER -- \
      /opt/spire/bin/spire-server entry delete -entryID "$ENTRY_ID" 2>/dev/null || true
done

# Discover all registered agent SPIFFE IDs
AGENT_IDS=$(kubectl exec -n spire-system spire-server-0 $CONTAINER -- \
  /opt/spire/bin/spire-server agent list 2>/dev/null | grep "^SPIFFE ID" | awk '{print $NF}')

if [ -z "$AGENT_IDS" ]; then
    echo -e "${RED}❌ No SPIRE agents found. Ensure agents are running.${NC}"
    exit 1
fi

# Create one entry per agent (each agent = one node)
for AGENT_ID in $AGENT_IDS; do
    echo "Creating entry with parent: $AGENT_ID"
    kubectl exec -n spire-system spire-server-0 $CONTAINER -- \
      /opt/spire/bin/spire-server entry create \
        -spiffeID "$SPIFFE_ID" \
        -parentID "$AGENT_ID" \
        -selector k8s:ns:99-apps \
        -selector k8s:sa:backend \
        -x509SVIDTTL 3600 2>/dev/null || echo "  (entry may already exist for this agent)"
done

echo ""
echo -e "${GREEN}✅ Registration entries created${NC}"
echo ""
kubectl exec -n spire-system spire-server-0 $CONTAINER -- \
  /opt/spire/bin/spire-server entry show -spiffeID "$SPIFFE_ID"
