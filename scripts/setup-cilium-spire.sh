#!/bin/bash
# Complete Cilium SPIRE Integration Setup
# Performs all steps needed to integrate Cilium with SPIRE
#
# Usage: ./scripts/setup-cilium-spire.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   Cilium SPIRE Integration Setup                        ║
║   Automated configuration for SPIFFE-based service mesh  ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
echo -e "${YELLOW}[Prerequisites]${NC} Checking environment..."

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl not found${NC}"
    exit 1
fi

# Check cilium CLI
if ! command -v cilium &> /dev/null; then
    echo -e "${YELLOW}WARNING: cilium CLI not found - status checks will be skipped${NC}"
    CILIUM_CLI_AVAILABLE=false
else
    CILIUM_CLI_AVAILABLE=true
fi

# Check helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}ERROR: helm not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites satisfied${NC}"
echo ""

# Step 1: Verify SPIRE is deployed and ready
echo -e "${BLUE}[Step 1/6]${NC} Verifying SPIRE deployment..."

if ! kubectl get namespace spire-system &>/dev/null; then
    echo -e "${RED}ERROR: spire-system namespace not found${NC}"
    echo "Please deploy SPIRE first using: kubectl apply -f infrastructure/spire/"
    exit 1
fi

if ! kubectl wait --for=condition=ready pod/spire-server-0 -n spire-system --timeout=30s &>/dev/null; then
    echo -e "${RED}ERROR: SPIRE server not ready${NC}"
    exit 1
fi

if ! kubectl wait --for=condition=ready pod -l app=spire-agent -n spire-system --timeout=30s &>/dev/null; then
    echo -e "${RED}ERROR: SPIRE agents not ready${NC}"
    exit 1
fi

agent_count=$(kubectl get pods -n spire-system -l app=spire-agent --no-headers | wc -l)
echo -e "${GREEN}✓ SPIRE is ready ($agent_count agents running)${NC}"
echo ""

# Step 2: Verify Cilium values file exists
echo -e "${BLUE}[Step 2/6]${NC} Checking Cilium configuration..."

if [ ! -f "infrastructure/cilium/values.yaml" ]; then
    echo -e "${RED}ERROR: infrastructure/cilium/values.yaml not found${NC}"
    exit 1
fi

# Check if SPIRE integration is configured in values
if ! grep -q "authentication:" infrastructure/cilium/values.yaml; then
    echo -e "${YELLOW}WARNING: SPIRE configuration not found in Cilium values${NC}"
    echo "Make sure infrastructure/cilium/values.yaml has the SPIRE integration section"
    echo ""
    echo "Expected configuration:"
    cat << 'EOF'
authentication:
  mutual:
    spire:
      enabled: true
      install:
        enabled: false
      serverAddress: spire-server.spire-system.svc.cluster.local:8081
      trustDomain: "demo.local"
      adminSocketPath: /run/spire/admin-sockets/admin.sock
      agentSocketPath: /run/spire/sockets/agent.sock
EOF
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}✓ Cilium configuration exists${NC}"
echo ""

# Step 3: Upgrade Cilium with SPIRE configuration
echo -e "${BLUE}[Step 3/6]${NC} Upgrading Cilium with SPIRE integration..."

if helm upgrade cilium cilium/cilium \
    --version 1.15.7 \
    --namespace kube-system \
    -f infrastructure/cilium/values.yaml \
    --wait \
    --timeout 5m &>/dev/null; then
    echo -e "${GREEN}✓ Cilium upgraded successfully${NC}"
else
    echo -e "${RED}ERROR: Cilium upgrade failed${NC}"
    exit 1
fi
echo ""

# Step 4: Patch Cilium DaemonSet for workload socket
echo -e "${BLUE}[Step 4/6]${NC} Patching Cilium DaemonSet for workload socket..."

# Check if patch is already applied
if kubectl get ds cilium -n kube-system -o yaml | grep -q "spire-workload-socket"; then
    echo -e "${YELLOW}ℹ Workload socket already configured, skipping patch${NC}"
else
    if kubectl patch daemonset cilium -n kube-system --type='json' -p='[
      {
        "op": "add",
        "path": "/spec/template/spec/volumes/-",
        "value": {
          "name": "spire-workload-socket",
          "hostPath": {
            "path": "/run/spire/sockets",
            "type": "DirectoryOrCreate"
          }
        }
      },
      {
        "op": "add",
        "path": "/spec/template/spec/containers/0/volumeMounts/-",
        "value": {
          "name": "spire-workload-socket",
          "mountPath": "/run/spire/sockets"
        }
      }
    ]' &>/dev/null; then
        echo -e "${GREEN}✓ Cilium DaemonSet patched${NC}"
    else
        echo -e "${RED}ERROR: Failed to patch Cilium DaemonSet${NC}"
        exit 1
    fi
fi

# Wait for Cilium rollout
echo "  Waiting for Cilium rollout..."
if kubectl rollout status ds/cilium -n kube-system --timeout=3m &>/dev/null; then
    echo -e "${GREEN}✓ Cilium rollout complete${NC}"
else
    echo -e "${RED}ERROR: Cilium rollout failed${NC}"
    exit 1
fi
echo ""

# Step 5: Create SPIRE registration entries
echo -e "${BLUE}[Step 5/6]${NC} Creating SPIRE registration entries..."

if [ -f "scripts/helpers/configure-cilium-spire-entries.sh" ]; then
    if bash scripts/helpers/configure-cilium-spire-entries.sh; then
        echo -e "${GREEN}✓ SPIRE entries configured${NC}"
    else
        echo -e "${RED}ERROR: Failed to create SPIRE entries${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}WARNING: Entry configuration script not found${NC}"
    echo "Please run manually: ./scripts/helpers/configure-cilium-spire-entries.sh"
fi
echo ""

# Step 6: Restart Cilium to pick up identities
echo -e "${BLUE}[Step 6/6]${NC} Restarting Cilium to apply SPIRE identities..."

if kubectl rollout restart ds/cilium -n kube-system &>/dev/null; then
    echo "  Waiting for Cilium restart..."
    if kubectl rollout status ds/cilium -n kube-system --timeout=3m &>/dev/null; then
        echo -e "${GREEN}✓ Cilium restarted successfully${NC}"
    else
        echo -e "${RED}ERROR: Cilium restart failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}ERROR: Failed to restart Cilium${NC}"
    exit 1
fi
echo ""

# Verification
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║ Verification                                              ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check Cilium status
if [ "$CILIUM_CLI_AVAILABLE" = true ]; then
    echo "Cilium Status:"
    echo "─────────────────────────────────────────────────────────────"
    cilium status 2>&1 | head -20
    echo ""
fi

# Check for SPIRE errors in logs
echo "Checking Cilium logs for SPIRE errors..."
echo "─────────────────────────────────────────────────────────────"
spire_errors=$(kubectl logs -n kube-system -l k8s-app=cilium --tail=50 --since=1m 2>/dev/null | \
    grep -i "spire.*error" | grep -v "Defaulted container" || true)

if [ -z "$spire_errors" ]; then
    echo -e "${GREEN}✓ No SPIRE errors found in recent logs${NC}"
else
    echo -e "${YELLOW}⚠ Found SPIRE-related errors:${NC}"
    echo "$spire_errors"
fi
echo ""

# Pod status
echo "Pod Status:"
echo "─────────────────────────────────────────────────────────────"
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
echo ""
kubectl get pods -n spire-system -o wide
echo ""

# Summary
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║ Setup Complete!                                           ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Cilium SPIRE integration configured successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Monitor Cilium status: cilium status"
echo "  2. Check SPIRE integration: kubectl logs -n kube-system -l k8s-app=cilium | grep -i spire"
echo "  3. View SPIRE entries: kubectl exec -n spire-system spire-server-0 -c spire-server -- /opt/spire/bin/spire-server entry show"
echo ""
echo "Documentation: docs/CILIUM_SPIRE_SETUP.md"
