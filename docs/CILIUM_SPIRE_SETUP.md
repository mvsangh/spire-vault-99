# Cilium SPIRE Integration Setup Guide

## Overview

This guide documents the complete setup process for integrating Cilium with SPIRE for SPIFFE-based service mesh and mTLS. This configuration enables Cilium to use SPIRE for workload identity management.

**Status:** Production-ready configuration for demo environments
**Prerequisites:** SPIRE server and agents deployed, Cilium installed via Helm

---

## Architecture

### SPIRE Delegated Identity API

Cilium uses two SPIRE socket types:

1. **Workload API Socket** (`/run/spire/sockets/agent.sock`)
   - Cilium gets its own SPIFFE identity
   - Required for authentication

2. **Delegated Identity API Socket** (`/run/spire/admin-sockets/admin.sock`)
   - Cilium requests identities for workloads it manages
   - Requires authorization via `authorized_delegates` configuration
   - **MUST** be in a separate directory from workload socket (security requirement)

### Trust Domain

- **Trust Domain:** `demo.local`
- **SPIRE Server:** `spire-server.spire-system.svc.cluster.local:8081`
- **Cilium Service Accounts:** `kube-system:cilium`, `kube-system:cilium-operator`

---

## Setup Steps

### Step 1: Configure SPIRE Agent (✅ ALREADY DONE)

The SPIRE agent DaemonSet has been updated with:

**File:** `infrastructure/spire/agent-daemonset.yaml`

```yaml
# Tolerations to run on control-plane nodes
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule

# Volume mounts for both sockets
volumeMounts:
  - name: spire-agent-socket
    mountPath: /run/spire/sockets
  - name: spire-admin-socket
    mountPath: /run/spire/admin-sockets

# Host path volumes
volumes:
  - name: spire-agent-socket
    hostPath:
      path: /run/spire/sockets
      type: DirectoryOrCreate
  - name: spire-admin-socket
    hostPath:
      path: /run/spire/admin-sockets
      type: DirectoryOrCreate
```

**Apply:**
```bash
kubectl apply -f infrastructure/spire/agent-daemonset.yaml
```

### Step 2: Update SPIRE Agent Configuration (✅ ALREADY DONE)

**File:** `infrastructure/spire/agent-configmap.yaml`

```yaml
agent {
  # ... existing config ...

  # Delegated Identity API for Cilium integration
  admin_socket_path = "/run/spire/admin-sockets/admin.sock"
  authorized_delegates = ["spiffe://demo.local/ns/kube-system/sa/cilium"]
}
```

**Apply:**
```bash
kubectl apply -f infrastructure/spire/agent-configmap.yaml
kubectl rollout restart daemonset/spire-agent -n spire-system
```

### Step 3: Update SPIRE Server Configuration (✅ ALREADY DONE)

**File:** `infrastructure/spire/server-configmap.yaml`

Add Cilium service accounts to the allow list:

```yaml
NodeAttestor "k8s_psat" {
  plugin_data {
    clusters = {
      "precinct-99" = {
        service_account_allow_list = [
          "spire-system:spire-agent",
          "kube-system:cilium",
          "kube-system:cilium-operator"
        ]
      }
    }
  }
}
```

**Apply:**
```bash
kubectl apply -f infrastructure/spire/server-configmap.yaml
kubectl rollout restart statefulset/spire-server -n spire-system
```

### Step 4: Configure Cilium Helm Values (⚠️ MANUAL STEP REQUIRED)

**File:** `infrastructure/cilium/values.yaml` (gitignored, changes NOT committed)

Add or update the SPIRE integration section:

```yaml
# SPIRE integration (Sprint 4 - Phase 4C)
authentication:
  mutual:
    spire:
      enabled: true
      install:
        enabled: false  # Use existing SPIRE installation
      # Connect to existing SPIRE server
      serverAddress: spire-server.spire-system.svc.cluster.local:8081
      trustDomain: "demo.local"
      # Socket paths for SPIRE agent communication
      # CRITICAL: admin socket must be in DIFFERENT directory than agent socket
      adminSocketPath: /run/spire/admin-sockets/admin.sock
      agentSocketPath: /run/spire/sockets/agent.sock
```

**Apply:**
```bash
helm upgrade cilium cilium/cilium \
  --version 1.15.7 \
  --namespace kube-system \
  -f infrastructure/cilium/values.yaml \
  --wait \
  --timeout 5m
```

### Step 5: Patch Cilium DaemonSet (❌ MANUAL STEP REQUIRED)

**Problem:** The Cilium Helm chart only creates the admin socket mount, not the workload socket mount.

**Solution:** Manually patch the DaemonSet to add the workload socket volume:

```bash
kubectl patch daemonset cilium -n kube-system --type='json' -p='[
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
]'
```

**Wait for rollout:**
```bash
kubectl rollout status ds/cilium -n kube-system --timeout=3m
```

### Step 6: Create SPIRE Registration Entries (❌ MANUAL STEP REQUIRED)

**Problem:** Entries must be created AFTER cluster is running because they use dynamic agent UUIDs.

**Solution:** Use the automated script (recommended) or manual commands.

#### Option A: Automated Script (Recommended)

```bash
./scripts/helpers/configure-cilium-spire-entries.sh
```

#### Option B: Manual Commands

First, get the list of SPIRE agents:

```bash
kubectl exec -n spire-system spire-server-0 -c spire-server -- \
  /opt/spire/bin/spire-server agent list
```

For each agent SPIFFE ID, create entries for Cilium:

```bash
# Replace <AGENT_SPIFFE_ID> with actual agent ID from the list above

# Create entry for cilium service account
kubectl exec -n spire-system spire-server-0 -c spire-server -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium \
  -parentID <AGENT_SPIFFE_ID> \
  -selector k8s:ns:kube-system \
  -selector k8s:sa:cilium

# Create entry for cilium-operator service account
kubectl exec -n spire-system spire-server-0 -c spire-server -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium-operator \
  -parentID <AGENT_SPIFFE_ID> \
  -selector k8s:ns:kube-system \
  -selector k8s:sa:cilium-operator
```

**Note:** You need to create entries for EACH agent (one entry per node).

### Step 7: Verify Integration

```bash
# Check Cilium status (should show no SPIRE errors)
cilium status

# Check Cilium logs for SPIRE connection
kubectl logs -n kube-system -l k8s-app=cilium --tail=20 | grep -i spire

# Verify SPIRE entries were created
kubectl exec -n spire-system spire-server-0 -c spire-server -- \
  /opt/spire/bin/spire-server entry show -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium
```

**Expected Results:**
- Cilium status: OK (no errors)
- No "no identity issued" errors in logs
- SPIRE entries visible for cilium and cilium-operator

---

## Cluster Recreation Procedure

If the cluster is destroyed and recreated, follow these steps:

### Phase 1: Infrastructure Deployment

```bash
# 1. Create kind cluster
kind create cluster --config infrastructure/kind/kind-config.yaml

# 2. Install Cilium (basic, without SPIRE first)
helm install cilium cilium/cilium \
  --version 1.15.7 \
  --namespace kube-system \
  -f infrastructure/cilium/values.yaml

# 3. Deploy SPIRE (with updated configurations)
kubectl apply -f infrastructure/spire/
```

### Phase 2: Wait for SPIRE Readiness

```bash
# Wait for SPIRE server to be ready
kubectl wait --for=condition=ready pod/spire-server-0 -n spire-system --timeout=5m

# Wait for SPIRE agents to be ready (should have 3 agents)
kubectl wait --for=condition=ready pod -l app=spire-agent -n spire-system --timeout=5m

# Verify 3 agents are registered
kubectl exec -n spire-system spire-server-0 -c spire-server -- \
  /opt/spire/bin/spire-server agent list | grep "Found"
```

### Phase 3: Configure Cilium SPIRE Integration

```bash
# 1. Upgrade Cilium with SPIRE configuration
helm upgrade cilium cilium/cilium \
  --version 1.15.7 \
  --namespace kube-system \
  -f infrastructure/cilium/values.yaml \
  --wait \
  --timeout 5m

# 2. Patch Cilium DaemonSet for workload socket
kubectl patch daemonset cilium -n kube-system --type='json' -p='[
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
]'

# 3. Wait for Cilium rollout
kubectl rollout status ds/cilium -n kube-system --timeout=3m
```

### Phase 4: Create SPIRE Entries

```bash
# Use automated script (creates entries for all agents dynamically)
./scripts/helpers/configure-cilium-spire-entries.sh
```

### Phase 5: Verify

```bash
# Check everything is working
cilium status
kubectl get pods -A
```

---

## Automation Scripts

### Script: `scripts/helpers/configure-cilium-spire-entries.sh`

This script automatically creates SPIRE registration entries for all Cilium components across all nodes.

**Usage:**
```bash
./scripts/helpers/configure-cilium-spire-entries.sh
```

**What it does:**
1. Fetches list of all SPIRE agents dynamically
2. Creates registration entries for `cilium` service account (one per agent)
3. Creates registration entries for `cilium-operator` service account (one per agent)
4. Verifies entries were created successfully

---

## Troubleshooting

### Issue: "admin socket does not exist"

**Symptoms:**
- Cilium status shows errors
- Logs show: `SPIRE admin socket (/run/spire/admin-sockets/admin.sock) does not exist`

**Solution:**
1. Verify SPIRE agent has admin socket volume mount:
   ```bash
   kubectl get ds -n spire-system spire-agent -o yaml | grep -A 5 spire-admin-socket
   ```

2. Verify socket exists on host:
   ```bash
   kubectl exec -n spire-system ds/spire-agent -- ls -la /run/spire/admin-sockets/
   ```

3. Restart SPIRE agents if needed:
   ```bash
   kubectl rollout restart ds/spire-agent -n spire-system
   ```

### Issue: "no identity issued" (PermissionDenied)

**Symptoms:**
- Cilium logs show: `rpc error: code = PermissionDenied desc = no identity issued`

**Causes:**
1. SPIRE registration entries missing
2. SPIRE registration entries have wrong parentID
3. Cilium doesn't have access to workload socket

**Solution:**

1. Check if entries exist:
   ```bash
   kubectl exec -n spire-system spire-server-0 -c spire-server -- \
     /opt/spire/bin/spire-server entry show
   ```

2. Verify Cilium has workload socket mount:
   ```bash
   kubectl get ds -n kube-system cilium -o yaml | grep -A 2 spire-workload-socket
   ```

3. Recreate entries with correct agent UUIDs:
   ```bash
   ./scripts/helpers/configure-cilium-spire-entries.sh
   ```

### Issue: Cilium pods on control-plane node failing

**Symptoms:**
- Cilium pod on control-plane shows SPIRE errors
- No SPIRE agent on control-plane node

**Solution:**
Verify SPIRE agent DaemonSet has control-plane tolerations:
```bash
kubectl get ds -n spire-system spire-agent -o yaml | grep -A 3 tolerations
```

Should show:
```yaml
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
```

### Issue: Entries lost after cluster recreation

**Cause:**
SPIRE registration entries are stored in SPIRE server's datastore (SQLite), which is ephemeral in this demo setup.

**Solution:**
Always run the entry creation script after cluster recreation:
```bash
./scripts/helpers/configure-cilium-spire-entries.sh
```

---

## Technical Notes

### Why Two Sockets?

1. **Workload Socket** - Standard SPIRE Workload API
   - Cilium authenticates itself to SPIRE
   - Gets its own SPIFFE identity
   - Required before using Delegated Identity API

2. **Admin Socket** - SPIRE Delegated Identity API
   - Cilium requests identities for OTHER workloads
   - Requires prior authentication via Workload API
   - Enables Cilium to manage identities for pods

### Why Separate Directories?

SPIRE requires admin and workload sockets in separate directories for security:
- Prevents privilege escalation
- Ensures only authorized delegates can access admin API
- Follows SPIRE security best practices

### Agent UUID Problem

**Problem:** SPIRE agents use random UUIDs in their SPIFFE IDs:
- Format: `spiffe://demo.local/spire/agent/k8s_psat/precinct-99/<UUID>`
- UUIDs change on every cluster recreation
- Registration entries MUST use these UUIDs as parentIDs

**Solution:** Dynamic entry creation script that fetches current agent UUIDs

### Alternative Approach (Not Implemented)

Instead of per-agent entries, you could use a single entry with node-based selectors:

```bash
kubectl exec -n spire-system spire-server-0 -c spire-server -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium \
  -parentID spiffe://demo.local/spire/server \
  -selector k8s:ns:kube-system \
  -selector k8s:sa:cilium \
  -node
```

This is NOT recommended because it bypasses agent-based attestation.

---

## Files Modified

### Committed to Git:
- `infrastructure/spire/agent-daemonset.yaml` - Admin socket, tolerations
- `infrastructure/spire/agent-configmap.yaml` - Delegated Identity API config
- `infrastructure/spire/server-configmap.yaml` - Service account allow list

### NOT Committed (Gitignored):
- `infrastructure/cilium/values.yaml` - SPIRE socket paths

### Cluster State (Ephemeral):
- SPIRE registration entries (created via kubectl exec)
- Cilium DaemonSet patch (applied via kubectl patch)

---

## Quick Start Script

For convenience, use the all-in-one setup script:

```bash
./scripts/setup-cilium-spire.sh
```

This script performs all steps automatically:
1. Verifies SPIRE is ready
2. Upgrades Cilium with SPIRE configuration
3. Patches Cilium DaemonSet
4. Creates SPIRE registration entries
5. Verifies integration

**Note:** This script assumes SPIRE is already deployed.

---

## References

- [SPIRE Delegated Identity API](https://spiffe.io/docs/latest/spire/using/delegated_identity_api/)
- [Cilium SPIRE Integration](https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/spire/)
- [SPIFFE Trust Domain](https://spiffe.io/docs/latest/spiffe/concepts/)

---

**Last Updated:** 2026-01-02
**Sprint:** Sprint 4, Phase 4C
**Status:** Production-ready for demo environments
