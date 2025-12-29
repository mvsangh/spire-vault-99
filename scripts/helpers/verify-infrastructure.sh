#!/bin/bash
set -e

echo "🔍 Verifying SPIRE-Vault-99 Infrastructure..."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_pods() {
  echo "📦 Checking pods in $1 namespace..."
  kubectl get pods -n $1 | grep -v NAME | awk '{print "  - " $1 ": " $3}'
  echo ""
}

# Check cluster
echo "☸️  Checking cluster nodes..."
kubectl get nodes
echo ""

# Check namespaces
echo "📁 Checking namespaces..."
kubectl get ns | grep -E "(spire-system|openbao|99-apps)"
echo ""

# Check pods
check_pods "spire-system"
check_pods "openbao"
check_pods "99-apps"

# Check SPIRE health
echo "🔐 Checking SPIRE server health..."
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server healthcheck
echo ""

# Check SPIRE agents
echo "🔐 Checking SPIRE agents..."
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server agent list | grep "Found"
echo ""

# Check OpenBao health
echo "🔑 Checking OpenBao health..."
curl -s http://localhost:8200/v1/sys/health | jq -r '"  Status: Initialized=\(.initialized), Sealed=\(.sealed)"'
echo ""

# Check PostgreSQL
echo "🐘 Checking PostgreSQL..."
kubectl exec -n 99-apps postgresql-0 -- \
  psql -U postgres -d appdb -c "SELECT COUNT(*) as user_count FROM users;" -t | xargs echo "  Demo users seeded:"
echo ""

# Check Cilium
echo "🌐 Checking Cilium..."
kubectl get pods -n kube-system -l k8s-app=cilium | grep -c Running | xargs echo "  Cilium agents running:"
kubectl get pods -n kube-system -l io.cilium/app=operator | grep -c Running | xargs echo "  Cilium operator running:"
echo ""

echo -e "${GREEN}✅ Infrastructure verification complete!${NC}"
