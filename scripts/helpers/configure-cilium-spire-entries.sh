#!/bin/bash
# Configure SPIRE Registration Entries for Cilium
# Creates workload identity entries for Cilium components across all SPIRE agents
#
# Usage: ./scripts/helpers/configure-cilium-spire-entries.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SPIRE_NAMESPACE="spire-system"
SPIRE_SERVER_POD="spire-server-0"
SPIRE_SERVER_CONTAINER="spire-server"
TRUST_DOMAIN="demo.local"
CILIUM_NAMESPACE="kube-system"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Cilium SPIRE Registration Entry Configuration${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Function to check if SPIRE server is ready
check_spire_server() {
    echo -e "${YELLOW}[1/5]${NC} Checking SPIRE server status..."

    if ! kubectl get pod "$SPIRE_SERVER_POD" -n "$SPIRE_NAMESPACE" &>/dev/null; then
        echo -e "${RED}ERROR: SPIRE server pod not found${NC}"
        echo "Expected pod: $SPIRE_SERVER_POD in namespace: $SPIRE_NAMESPACE"
        exit 1
    fi

    if ! kubectl wait --for=condition=ready pod/"$SPIRE_SERVER_POD" -n "$SPIRE_NAMESPACE" --timeout=30s &>/dev/null; then
        echo -e "${RED}ERROR: SPIRE server not ready${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ SPIRE server is ready${NC}"
    echo ""
}

# Function to get list of SPIRE agent SPIFFE IDs
get_spire_agents() {
    echo -e "${YELLOW}[2/5]${NC} Fetching SPIRE agent list..."

    local agent_list
    agent_list=$(kubectl exec -n "$SPIRE_NAMESPACE" "$SPIRE_SERVER_POD" -c "$SPIRE_SERVER_CONTAINER" -- \
        /opt/spire/bin/spire-server agent list 2>/dev/null)

    # Extract SPIFFE IDs from agent list
    local agent_ids
    agent_ids=$(echo "$agent_list" | grep "^SPIFFE ID" | awk '{print $NF}')

    if [ -z "$agent_ids" ]; then
        echo -e "${RED}ERROR: No SPIRE agents found${NC}"
        echo "Make sure SPIRE agents are deployed and attested"
        exit 1
    fi

    local agent_count
    agent_count=$(echo "$agent_ids" | wc -l)

    echo -e "${GREEN}✓ Found $agent_count SPIRE agent(s)${NC}"
    echo "$agent_ids" | while read -r agent_id; do
        echo "  - $agent_id"
    done
    echo ""

    echo "$agent_ids"
}

# Function to delete existing Cilium entries (cleanup)
cleanup_existing_entries() {
    echo -e "${YELLOW}[3/5]${NC} Cleaning up existing Cilium entries..."

    local cilium_entry_ids
    cilium_entry_ids=$(kubectl exec -n "$SPIRE_NAMESPACE" "$SPIRE_SERVER_POD" -c "$SPIRE_SERVER_CONTAINER" -- \
        /opt/spire/bin/spire-server entry show -spiffeID "spiffe://$TRUST_DOMAIN/ns/$CILIUM_NAMESPACE/sa/cilium" 2>/dev/null | \
        grep "^Entry ID" | awk '{print $NF}' || true)

    local operator_entry_ids
    operator_entry_ids=$(kubectl exec -n "$SPIRE_NAMESPACE" "$SPIRE_SERVER_POD" -c "$SPIRE_SERVER_CONTAINER" -- \
        /opt/spire/bin/spire-server entry show -spiffeID "spiffe://$TRUST_DOMAIN/ns/$CILIUM_NAMESPACE/sa/cilium-operator" 2>/dev/null | \
        grep "^Entry ID" | awk '{print $NF}' || true)

    local deleted_count=0

    # Delete cilium entries
    if [ -n "$cilium_entry_ids" ]; then
        while read -r entry_id; do
            if [ -n "$entry_id" ]; then
                kubectl exec -n "$SPIRE_NAMESPACE" "$SPIRE_SERVER_POD" -c "$SPIRE_SERVER_CONTAINER" -- \
                    /opt/spire/bin/spire-server entry delete -entryID "$entry_id" &>/dev/null
                ((deleted_count++))
            fi
        done <<< "$cilium_entry_ids"
    fi

    # Delete cilium-operator entries
    if [ -n "$operator_entry_ids" ]; then
        while read -r entry_id; do
            if [ -n "$entry_id" ]; then
                kubectl exec -n "$SPIRE_NAMESPACE" "$SPIRE_SERVER_POD" -c "$SPIRE_SERVER_CONTAINER" -- \
                    /opt/spire/bin/spire-server entry delete -entryID "$entry_id" &>/dev/null
                ((deleted_count++))
            fi
        done <<< "$operator_entry_ids"
    fi

    if [ $deleted_count -gt 0 ]; then
        echo -e "${GREEN}✓ Deleted $deleted_count existing entry/entries${NC}"
    else
        echo -e "${GREEN}✓ No existing entries to clean up${NC}"
    fi
    echo ""
}

# Function to create registration entries for Cilium
create_cilium_entries() {
    local agent_ids=$1

    echo -e "${YELLOW}[4/5]${NC} Creating SPIRE registration entries..."

    local created_count=0
    local failed_count=0

    # Create entries for each agent
    while read -r agent_id; do
        if [ -z "$agent_id" ]; then
            continue
        fi

        # Extract node identifier from agent SPIFFE ID (last part after /)
        local node_id
        node_id=$(echo "$agent_id" | awk -F'/' '{print $NF}')

        # Create entry for cilium service account
        echo "  Creating cilium entry for agent: ${node_id:0:8}..."
        if kubectl exec -n "$SPIRE_NAMESPACE" "$SPIRE_SERVER_POD" -c "$SPIRE_SERVER_CONTAINER" -- \
            /opt/spire/bin/spire-server entry create \
            -spiffeID "spiffe://$TRUST_DOMAIN/ns/$CILIUM_NAMESPACE/sa/cilium" \
            -parentID "$agent_id" \
            -selector "k8s:ns:$CILIUM_NAMESPACE" \
            -selector "k8s:sa:cilium" &>/dev/null; then
            ((created_count++))
            echo -e "  ${GREEN}✓ Created cilium entry${NC}"
        else
            ((failed_count++))
            echo -e "  ${RED}✗ Failed to create cilium entry${NC}"
        fi

        # Create entry for cilium-operator service account
        echo "  Creating cilium-operator entry for agent: ${node_id:0:8}..."
        if kubectl exec -n "$SPIRE_NAMESPACE" "$SPIRE_SERVER_POD" -c "$SPIRE_SERVER_CONTAINER" -- \
            /opt/spire/bin/spire-server entry create \
            -spiffeID "spiffe://$TRUST_DOMAIN/ns/$CILIUM_NAMESPACE/sa/cilium-operator" \
            -parentID "$agent_id" \
            -selector "k8s:ns:$CILIUM_NAMESPACE" \
            -selector "k8s:sa:cilium-operator" &>/dev/null; then
            ((created_count++))
            echo -e "  ${GREEN}✓ Created cilium-operator entry${NC}"
        else
            ((failed_count++))
            echo -e "  ${RED}✗ Failed to create cilium-operator entry${NC}"
        fi

        echo ""
    done <<< "$agent_ids"

    echo -e "${GREEN}✓ Created $created_count registration entries${NC}"
    if [ $failed_count -gt 0 ]; then
        echo -e "${RED}✗ Failed to create $failed_count entries${NC}"
    fi
    echo ""
}

# Function to verify entries were created
verify_entries() {
    echo -e "${YELLOW}[5/5]${NC} Verifying registration entries..."

    # Count cilium entries
    local cilium_count
    cilium_count=$(kubectl exec -n "$SPIRE_NAMESPACE" "$SPIRE_SERVER_POD" -c "$SPIRE_SERVER_CONTAINER" -- \
        /opt/spire/bin/spire-server entry show -spiffeID "spiffe://$TRUST_DOMAIN/ns/$CILIUM_NAMESPACE/sa/cilium" 2>/dev/null | \
        grep -c "^Entry ID" || true)

    # Count cilium-operator entries
    local operator_count
    operator_count=$(kubectl exec -n "$SPIRE_NAMESPACE" "$SPIRE_SERVER_POD" -c "$SPIRE_SERVER_CONTAINER" -- \
        /opt/spire/bin/spire-server entry show -spiffeID "spiffe://$TRUST_DOMAIN/ns/$CILIUM_NAMESPACE/sa/cilium-operator" 2>/dev/null | \
        grep -c "^Entry ID" || true)

    echo -e "${GREEN}✓ Cilium entries: $cilium_count${NC}"
    echo -e "${GREEN}✓ Cilium-operator entries: $operator_count${NC}"
    echo ""

    # Show sample entry
    echo "Sample entry:"
    kubectl exec -n "$SPIRE_NAMESPACE" "$SPIRE_SERVER_POD" -c "$SPIRE_SERVER_CONTAINER" -- \
        /opt/spire/bin/spire-server entry show -spiffeID "spiffe://$TRUST_DOMAIN/ns/$CILIUM_NAMESPACE/sa/cilium" 2>/dev/null | \
        head -n 8 | sed 's/^/  /'
    echo ""
}

# Function to provide next steps
show_next_steps() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}Next Steps${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo "1. Restart Cilium pods to pick up new SPIRE identities:"
    echo "   kubectl rollout restart ds/cilium -n kube-system"
    echo ""
    echo "2. Check Cilium status (should show no SPIRE errors):"
    echo "   cilium status"
    echo ""
    echo "3. Verify SPIRE integration in Cilium logs:"
    echo "   kubectl logs -n kube-system -l k8s-app=cilium --tail=20 | grep -i spire"
    echo ""
    echo -e "${GREEN}SPIRE registration entries configured successfully!${NC}"
}

# Main execution
main() {
    check_spire_server

    local agent_ids
    agent_ids=$(get_spire_agents)

    cleanup_existing_entries

    create_cilium_entries "$agent_ids"

    verify_entries

    show_next_steps
}

# Run main function
main
