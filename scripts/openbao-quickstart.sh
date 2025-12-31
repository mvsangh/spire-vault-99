#!/bin/bash
set -e

# OpenBao TLS Mode Quick Start Script
# Provides common operations for OpenBao management

NAMESPACE="openbao"
POD_LABEL="app=openbao"
KEYS_FILE="openbao-init-keys.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get pod name
get_pod() {
    kubectl get pod -n $NAMESPACE -l $POD_LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Check status
check_status() {
    log_info "Checking OpenBao status..."
    POD=$(get_pod)
    if [ -z "$POD" ]; then
        log_error "OpenBao pod not found"
        return 1
    fi

    kubectl exec -n $NAMESPACE $POD -- bao status || true
}

# Initialize OpenBao
init_vault() {
    log_info "Initializing OpenBao..."

    if [ -f "$KEYS_FILE" ]; then
        log_warn "Keys file already exists: $KEYS_FILE"
        read -p "Overwrite? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log_info "Aborted"
            return 1
        fi
    fi

    POD=$(get_pod)
    log_info "Initializing with 5 keys, threshold 3..."
    kubectl exec -n $NAMESPACE $POD -- bao operator init \
        -key-shares=5 \
        -key-threshold=3 \
        -format=json > $KEYS_FILE

    chmod 600 $KEYS_FILE
    log_info "✅ Initialized! Keys saved to: $KEYS_FILE"
    log_warn "⚠️  BACKUP THIS FILE SECURELY!"

    # Display keys
    echo ""
    log_info "Root Token: $(cat $KEYS_FILE | jq -r '.root_token')"
    log_info "Unseal keys saved in: $KEYS_FILE"
}

# Unseal OpenBao
unseal_vault() {
    log_info "Unsealing OpenBao..."

    if [ ! -f "$KEYS_FILE" ]; then
        log_error "Keys file not found: $KEYS_FILE"
        log_info "Please initialize first or restore from backup"
        return 1
    fi

    POD=$(get_pod)

    # Extract 3 keys
    KEY1=$(cat $KEYS_FILE | jq -r '.unseal_keys_b64[0]')
    KEY2=$(cat $KEYS_FILE | jq -r '.unseal_keys_b64[1]')
    KEY3=$(cat $KEYS_FILE | jq -r '.unseal_keys_b64[2]')

    log_info "Unsealing with key 1/3..."
    kubectl exec -n $NAMESPACE $POD -- bao operator unseal $KEY1

    log_info "Unsealing with key 2/3..."
    kubectl exec -n $NAMESPACE $POD -- bao operator unseal $KEY2

    log_info "Unsealing with key 3/3..."
    kubectl exec -n $NAMESPACE $POD -- bao operator unseal $KEY3

    log_info "✅ OpenBao unsealed!"
    check_status
}

# Login
login_vault() {
    log_info "Logging in to OpenBao..."

    if [ ! -f "$KEYS_FILE" ]; then
        log_error "Keys file not found: $KEYS_FILE"
        return 1
    fi

    POD=$(get_pod)
    ROOT_TOKEN=$(cat $KEYS_FILE | jq -r '.root_token')

    kubectl exec -n $NAMESPACE $POD -- bao login $ROOT_TOKEN
    log_info "✅ Logged in successfully"
}

# Port forward
port_forward() {
    log_info "Setting up port forward to OpenBao..."
    log_info "Access at: https://localhost:8200"
    log_info "Press Ctrl+C to stop"

    export VAULT_ADDR='https://127.0.0.1:8200'
    export VAULT_SKIP_VERIFY='true'

    kubectl port-forward -n $NAMESPACE svc/openbao 8200:8200
}

# Show usage
usage() {
    cat <<EOF
OpenBao TLS Mode Quick Start

Usage: $0 <command>

Commands:
    status          Check OpenBao status
    init            Initialize OpenBao (first time only)
    unseal          Unseal OpenBao (required after restart)
    login           Login to OpenBao with root token
    port-forward    Port forward OpenBao to localhost:8200
    setup           Complete setup (init + unseal + login)
    restart         Restart OpenBao pod

Examples:
    # First time setup
    $0 init
    $0 unseal
    $0 login

    # After pod restart
    $0 unseal

    # Quick setup
    $0 setup

Keys file: $KEYS_FILE
EOF
}

# Complete setup
setup() {
    log_info "Starting complete OpenBao setup..."

    # Check if already initialized
    POD=$(get_pod)
    if kubectl exec -n $NAMESPACE $POD -- bao status 2>&1 | grep -q "Initialized.*true"; then
        log_warn "OpenBao already initialized"
        unseal_vault
    else
        init_vault
        sleep 2
        unseal_vault
    fi

    log_info "✅ Setup complete!"
}

# Restart pod
restart_pod() {
    log_info "Restarting OpenBao pod..."
    kubectl delete pod -n $NAMESPACE -l $POD_LABEL
    log_info "Waiting for new pod..."
    kubectl wait --for=condition=ready pod -n $NAMESPACE -l $POD_LABEL --timeout=60s
    log_info "✅ Pod restarted"
}

# Main
case "${1:-}" in
    status)
        check_status
        ;;
    init)
        init_vault
        ;;
    unseal)
        unseal_vault
        ;;
    login)
        login_vault
        ;;
    port-forward)
        port_forward
        ;;
    setup)
        setup
        ;;
    restart)
        restart_pod
        ;;
    *)
        usage
        exit 1
        ;;
esac
