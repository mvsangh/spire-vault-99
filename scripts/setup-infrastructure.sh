#!/bin/bash
# Automated Infrastructure Setup for SPIRE-Vault-99
# Deploys: kind cluster, Cilium, SPIRE, OpenBao, PostgreSQL
# Usage: ./scripts/setup-infrastructure.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking Prerequisites"

    local missing_tools=()

    if ! command -v kind &> /dev/null; then
        missing_tools+=("kind")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi

    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing tools before continuing"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

# Clean up existing cluster
cleanup_existing() {
    log_step "Checking for Existing Cluster"

    if kind get clusters 2>/dev/null | grep -q "precinct-99"; then
        log_warning "Found existing 'precinct-99' cluster"
        read -p "Delete existing cluster and redeploy? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            kind delete cluster --name precinct-99
            log_success "Cluster deleted"
        else
            log_error "Aborted by user"
            exit 1
        fi
    else
        log_info "No existing cluster found"
    fi
}

# Create kind cluster
create_cluster() {
    log_step "Phase 1: Creating kind Cluster (precinct-99)"

    log_info "Creating cluster with config: infrastructure/kind/kind-config.yaml"
    kind create cluster --config infrastructure/kind/kind-config.yaml

    log_info "Cluster created (nodes will be Ready after Cilium installation)"
    kubectl get nodes

    log_success "Cluster created successfully"
}

# Install Cilium CNI
install_cilium() {
    log_step "Phase 2: Installing Cilium CNI"

    log_info "Adding Cilium Helm repository..."
    helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
    helm repo update

    log_info "Installing Cilium v1.15.7..."
    helm install cilium cilium/cilium \
        --version 1.15.7 \
        --namespace kube-system \
        --values infrastructure/cilium/values.yaml

    log_info "Waiting for Cilium to be ready (may take 2-3 minutes)..."
    kubectl wait --for=condition=Ready pods -n kube-system -l k8s-app=cilium --timeout=300s

    log_success "Cilium installed successfully"
    kubectl get pods -n kube-system -l k8s-app=cilium
}

# Create namespaces
create_namespaces() {
    log_step "Creating Namespaces"

    log_info "Creating spire-system namespace..."
    kubectl create namespace spire-system 2>/dev/null || log_warning "spire-system already exists"

    log_info "Creating openbao namespace..."
    kubectl create namespace openbao 2>/dev/null || log_warning "openbao already exists"

    log_info "Creating 99-apps namespace..."
    kubectl create namespace 99-apps 2>/dev/null || log_warning "99-apps already exists"

    log_success "Namespaces created"
    kubectl get namespaces | grep -E "spire-system|openbao|99-apps"
}

# Deploy SPIRE
deploy_spire() {
    log_step "Phase 3: Deploying SPIRE"

    log_info "Deploying SPIRE Server..."
    kubectl apply -f infrastructure/spire/server-account.yaml
    kubectl apply -f infrastructure/spire/server-configmap.yaml
    kubectl apply -f infrastructure/spire/server-statefulset.yaml
    kubectl apply -f infrastructure/spire/server-service.yaml

    log_info "Waiting for SPIRE Server to be ready..."
    kubectl wait --for=condition=Ready pod -n spire-system -l app=spire-server --timeout=300s

    log_info "Deploying SPIRE Agent (DaemonSet)..."
    kubectl apply -f infrastructure/spire/agent-account.yaml
    kubectl apply -f infrastructure/spire/agent-configmap.yaml
    kubectl apply -f infrastructure/spire/agent-daemonset.yaml

    log_info "Waiting for SPIRE Agents to be ready..."
    sleep 10  # Give agents time to start
    kubectl wait --for=condition=Ready pods -n spire-system -l app=spire-agent --timeout=300s

    log_success "SPIRE deployed successfully"
    kubectl get pods -n spire-system

    # Verify SPIRE health
    log_info "Verifying SPIRE Server health..."
    kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server healthcheck
    log_success "SPIRE Server is healthy"
}

# Deploy OpenBao
deploy_openbao() {
    log_step "Phase 4: Deploying OpenBao (Vault)"

    log_info "Deploying OpenBao in dev mode..."
    kubectl apply -f infrastructure/openbao/deployment.yaml
    kubectl apply -f infrastructure/openbao/service.yaml

    log_info "Waiting for OpenBao to be ready..."
    kubectl wait --for=condition=Ready pod -n openbao -l app=openbao --timeout=300s

    log_success "OpenBao deployed successfully"
    kubectl get pods -n openbao

    # Verify OpenBao health
    log_info "Verifying OpenBao health..."
    kubectl exec -n openbao deploy/openbao -- bao status || true
    log_success "OpenBao is running (dev mode)"
}

# Deploy PostgreSQL
deploy_postgres() {
    log_step "Phase 5: Deploying PostgreSQL"

    log_info "Deploying PostgreSQL with init script..."
    kubectl apply -f infrastructure/postgres/init-configmap.yaml
    kubectl apply -f infrastructure/postgres/service.yaml
    kubectl apply -f infrastructure/postgres/statefulset.yaml

    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=Ready pod -n 99-apps -l app=postgresql --timeout=300s

    log_success "PostgreSQL deployed successfully"
    kubectl get pods -n 99-apps

    # Verify PostgreSQL
    log_info "Verifying PostgreSQL and demo users..."
    sleep 5  # Give init script time to run
    kubectl exec -n 99-apps postgresql-0 -- psql -U postgres -d appdb -c "SELECT username FROM users;" || log_warning "Could not verify users (may still be initializing)"
}

# Verify deployment
verify_deployment() {
    log_step "Phase 6: Verification"

    log_info "Checking all pods..."
    kubectl get pods -A

    echo ""
    log_info "Infrastructure Summary:"
    echo "  - Cluster: precinct-99 (kind)"
    echo "  - Nodes: $(kubectl get nodes --no-headers | wc -l)"
    echo "  - Namespaces: spire-system, openbao, 99-apps, kube-system"
    echo "  - SPIRE Server: $(kubectl get pods -n spire-system -l app=spire-server --no-headers | wc -l) pod(s)"
    echo "  - SPIRE Agents: $(kubectl get pods -n spire-system -l app=spire-agent --no-headers | wc -l) pod(s)"
    echo "  - OpenBao: $(kubectl get pods -n openbao -l app=openbao --no-headers | wc -l) pod(s)"
    echo "  - PostgreSQL: $(kubectl get pods -n 99-apps -l app=postgresql --no-headers | wc -l) pod(s)"

    echo ""
    log_success "Infrastructure deployment complete!"
    log_info "Next steps:"
    echo "  1. Run Vault configuration: ./scripts/helpers/configure-vault-backend.sh"
    echo "  2. Create SPIRE entry: ./backend/scripts/create-spire-entry.sh"
    echo "  3. Deploy backend: tilt up"
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     SPIRE-Vault-99 Infrastructure Setup              ║"
    echo "║     Automated Deployment Script                       ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"

    check_prerequisites
    cleanup_existing
    create_cluster
    install_cilium
    create_namespaces
    deploy_spire
    deploy_openbao
    deploy_postgres
    verify_deployment

    echo ""
    log_success "🎉 Setup complete! Infrastructure is ready for backend deployment."
}

# Run main function
main "$@"
