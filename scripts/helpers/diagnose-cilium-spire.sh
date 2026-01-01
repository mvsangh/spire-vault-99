#!/bin/bash

# Cilium + SPIRE Integration Diagnostic Script
# This script checks the health and configuration of Cilium + SPIRE integration
# Usage: ./diagnose-cilium-spire.sh

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== Cilium + SPIRE Integration Diagnostics ===${NC}\n"

# Check if required commands exist
for cmd in kubectl jq; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        exit 1
    fi
done

# Check if cilium CLI is available
if command -v cilium &> /dev/null; then
    CILIUM_CLI=true
else
    echo -e "${YELLOW}Warning: cilium CLI not found, some checks will be skipped${NC}\n"
    CILIUM_CLI=false
fi

echo -e "${BOLD}1. SPIRE Server Health${NC}"
echo "----------------------------------------"
if kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server healthcheck 2>/dev/null; then
    echo -e "${GREEN}✓ SPIRE server is healthy${NC}\n"
else
    echo -e "${RED}✗ SPIRE server health check failed${NC}\n"
fi

echo -e "${BOLD}2. SPIRE Agents${NC}"
echo "----------------------------------------"
AGENT_COUNT=$(kubectl get pods -n spire-system -l app=spire-agent --no-headers 2>/dev/null | wc -l)
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
echo "SPIRE Agents: $AGENT_COUNT"
echo "Cluster Nodes: $NODE_COUNT"
if [ "$AGENT_COUNT" -eq "$NODE_COUNT" ]; then
    echo -e "${GREEN}✓ One SPIRE agent per node${NC}\n"
else
    echo -e "${RED}✗ SPIRE agent count mismatch${NC}\n"
fi

kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server agent list 2>/dev/null || echo -e "${RED}Failed to list agents${NC}\n"

echo -e "\n${BOLD}3. SPIRE Registration Entries${NC}"
echo "----------------------------------------"
echo "Total entries:"
kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server entry show 2>/dev/null | grep "Entry ID" | wc -l

echo -e "\nCilium-related entries:"
kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server entry show -selector cilium:mutual-auth 2>/dev/null | grep "Entry ID" | wc -l || echo "0"

echo -e "\nCilium agent entry:"
if kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server entry show -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium 2>/dev/null | grep -q "Entry ID"; then
    echo -e "${GREEN}✓ Cilium agent SPIRE entry exists${NC}"
else
    echo -e "${RED}✗ Cilium agent SPIRE entry not found${NC}"
fi

echo -e "\nCilium operator entry:"
if kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server entry show -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium-operator 2>/dev/null | grep -q "Entry ID"; then
    echo -e "${GREEN}✓ Cilium operator SPIRE entry exists${NC}"
else
    echo -e "${RED}✗ Cilium operator SPIRE entry not found${NC}"
fi

echo -e "\n${BOLD}4. SPIRE Agent Admin Socket${NC}"
echo "----------------------------------------"
SPIRE_AGENT_POD=$(kubectl get pods -n spire-system -l app=spire-agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$SPIRE_AGENT_POD" ]; then
    echo "Checking socket on $SPIRE_AGENT_POD:"
    kubectl exec -n spire-system $SPIRE_AGENT_POD -- ls -la /run/spire/sockets/ 2>/dev/null || echo -e "${RED}Failed to list sockets${NC}"

    if kubectl exec -n spire-system $SPIRE_AGENT_POD -- ls /run/spire/sockets/admin.sock 2>/dev/null; then
        echo -e "${GREEN}✓ Admin socket exists${NC}"
    else
        echo -e "${RED}✗ Admin socket not found${NC}"
    fi
else
    echo -e "${RED}No SPIRE agent pod found${NC}"
fi

echo -e "\n${BOLD}5. SPIRE Agent Configuration${NC}"
echo "----------------------------------------"
echo "Checking for Delegated Identity API configuration:"
if kubectl get configmap spire-agent -n spire-system -o yaml 2>/dev/null | grep -q "admin_socket_path"; then
    echo -e "${GREEN}✓ admin_socket_path configured${NC}"
    kubectl get configmap spire-agent -n spire-system -o yaml 2>/dev/null | grep "admin_socket_path"
else
    echo -e "${RED}✗ admin_socket_path not configured${NC}"
fi

if kubectl get configmap spire-agent -n spire-system -o yaml 2>/dev/null | grep -q "authorized_delegates"; then
    echo -e "${GREEN}✓ authorized_delegates configured${NC}"
    kubectl get configmap spire-agent -n spire-system -o yaml 2>/dev/null | grep -A3 "authorized_delegates"
else
    echo -e "${RED}✗ authorized_delegates not configured${NC}"
fi

echo -e "\n${BOLD}6. Cilium Status${NC}"
echo "----------------------------------------"
if [ "$CILIUM_CLI" = true ]; then
    cilium status || echo -e "${RED}Cilium status check failed${NC}"
else
    echo "Checking Cilium pods:"
    kubectl get pods -n kube-system -l k8s-app=cilium
fi

echo -e "\n${BOLD}7. Cilium SPIRE Integration Configuration${NC}"
echo "----------------------------------------"
echo "Checking Helm values for SPIRE integration:"
if helm get values cilium -n kube-system 2>/dev/null | grep -q "spire"; then
    echo -e "${GREEN}✓ SPIRE configuration found in Helm values${NC}"
    helm get values cilium -n kube-system 2>/dev/null | grep -A10 "spire:"
else
    echo -e "${YELLOW}⚠ No SPIRE configuration in Helm values${NC}"
fi

echo -e "\n${BOLD}8. Cilium Agent SPIRE Configuration${NC}"
echo "----------------------------------------"
CILIUM_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$CILIUM_POD" ]; then
    echo "Checking mesh-auth flags on $CILIUM_POD:"
    kubectl exec -n kube-system $CILIUM_POD -- cilium-agent --help 2>/dev/null | grep "mesh-auth" | head -5 || echo -e "${YELLOW}Could not retrieve mesh-auth flags${NC}"
else
    echo -e "${RED}No Cilium pod found${NC}"
fi

echo -e "\n${BOLD}9. Cilium DaemonSet Volume Mounts${NC}"
echo "----------------------------------------"
echo "Checking for SPIRE socket mount:"
if kubectl get daemonset cilium -n kube-system -o yaml 2>/dev/null | grep -q "spire"; then
    echo -e "${GREEN}✓ SPIRE-related volumes found${NC}"
    kubectl get daemonset cilium -n kube-system -o yaml 2>/dev/null | grep -A5 "name: spire"
else
    echo -e "${YELLOW}⚠ No SPIRE-related volumes found in Cilium DaemonSet${NC}"
fi

echo -e "\n${BOLD}10. Recent Cilium Authentication Logs${NC}"
echo "----------------------------------------"
if [ -n "$CILIUM_POD" ]; then
    echo "Last 20 authentication-related log entries from $CILIUM_POD:"
    kubectl logs -n kube-system $CILIUM_POD --tail=200 2>/dev/null | grep -i "auth\|spire\|spiffe" | tail -20 || echo -e "${YELLOW}No authentication logs found${NC}"
else
    echo -e "${RED}No Cilium pod found${NC}"
fi

echo -e "\n${BOLD}11. Cilium Network Policies with Authentication${NC}"
echo "----------------------------------------"
AUTH_POLICIES=$(kubectl get cnp -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.ingress[]?.authentication.mode == "required" or .spec.egress[]?.authentication.mode == "required") | "\(.metadata.namespace)/\(.metadata.name)"' | wc -l)
if [ "$AUTH_POLICIES" -gt 0 ]; then
    echo -e "${GREEN}Found $AUTH_POLICIES network policies with authentication enabled:${NC}"
    kubectl get cnp -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.ingress[]?.authentication.mode == "required" or .spec.egress[]?.authentication.mode == "required") | "\(.metadata.namespace)/\(.metadata.name)"'
else
    echo -e "${YELLOW}⚠ No network policies with authentication enabled${NC}"
fi

echo -e "\n${BOLD}12. Cilium Identity Summary${NC}"
echo "----------------------------------------"
if [ "$CILIUM_CLI" = true ]; then
    echo "Total Cilium identities:"
    cilium identity list 2>/dev/null | grep -v "IDENTITY" | wc -l || echo "Unable to retrieve"
else
    echo "Cilium CLI not available, skipping identity check"
fi

echo -e "\n${BOLD}13. Trust Domain Consistency Check${NC}"
echo "----------------------------------------"
SPIRE_SERVER_TD=$(kubectl get configmap spire-server -n spire-system -o yaml 2>/dev/null | grep "trust_domain" | head -1 | awk '{print $3}' | tr -d '"')
SPIRE_AGENT_TD=$(kubectl get configmap spire-agent -n spire-system -o yaml 2>/dev/null | grep "trust_domain" | head -1 | awk '{print $3}' | tr -d '"')
CILIUM_TD=$(helm get values cilium -n kube-system 2>/dev/null | grep "trustDomain" | awk '{print $2}')

echo "SPIRE Server trust domain: $SPIRE_SERVER_TD"
echo "SPIRE Agent trust domain: $SPIRE_AGENT_TD"
echo "Cilium trust domain: $CILIUM_TD"

if [ "$SPIRE_SERVER_TD" = "$SPIRE_AGENT_TD" ] && [ "$SPIRE_SERVER_TD" = "$CILIUM_TD" ]; then
    echo -e "${GREEN}✓ Trust domains are consistent${NC}"
elif [ -z "$CILIUM_TD" ]; then
    echo -e "${YELLOW}⚠ Cilium trust domain not configured (using default: spiffe.cilium)${NC}"
else
    echo -e "${RED}✗ Trust domain mismatch detected${NC}"
fi

echo -e "\n${BOLD}=== Diagnostic Summary ===${NC}"
echo "----------------------------------------"
echo "This diagnostic script has checked:"
echo "  - SPIRE server and agent health"
echo "  - SPIRE registration entries for Cilium"
echo "  - Delegated Identity API configuration"
echo "  - Cilium SPIRE integration settings"
echo "  - Network policies with authentication"
echo "  - Trust domain consistency"
echo ""
echo "Review the output above for any errors or warnings."
echo "For detailed troubleshooting, see: docs/CILIUM_SPIRE_INTEGRATION.md"
echo ""
