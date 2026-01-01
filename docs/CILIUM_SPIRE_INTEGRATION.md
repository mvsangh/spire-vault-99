# Cilium + SPIRE Integration Guide for Production Use

**Document Version:** 1.0
**Last Updated:** 2026-01-02
**Target Environment:** Kubernetes 1.34, Cilium 1.15.7, SPIRE 1.9.6
**Trust Domain:** `demo.local`

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [SPIRE Configuration Requirements](#2-spire-configuration-requirements)
3. [Cilium Configuration Requirements](#3-cilium-configuration-requirements)
4. [Deployment Considerations](#4-deployment-considerations)
5. [Step-by-Step Implementation](#5-step-by-step-implementation)
6. [Verification and Testing](#6-verification-and-testing)
7. [Common Issues and Troubleshooting](#7-common-issues-and-troubleshooting)
8. [References](#8-references)

---

## 1. Architecture Overview

### 1.1 How Cilium + SPIRE Integration Works

Cilium's mutual authentication framework moves **the mutual authentication handshake out-of-band** for regular connections, using SPIFFE (Secure Production Identity Framework for Everyone) for identity management.

**Key Components:**

1. **SPIRE Server (Central Root of Trust)**
   - Forms the root of trust for the trust domain
   - Issues SPIFFE Verified Identity Documents (SVIDs) containing X.509 TLS keypairs
   - Deployed as a StatefulSet in the `spire-system` namespace

2. **SPIRE Agent (Per-Node Identity Provider)**
   - Runs as a DaemonSet (one per node)
   - Validates identity requests from workloads on each node
   - Confirms pod authenticity (node placement, label matching)
   - Requests identities from SPIRE server

3. **Cilium Agent (Identity Delegate)**
   - Cilium agents get a **common SPIFFE identity**
   - Can request identities **on behalf of other workloads** using the **Delegated Identity API**
   - This is different from standard SPIRE workflows where workloads request their own identities

4. **Cilium Operator (SPIRE Entry Manager)**
   - Creates SPIRE entries for Cilium Identities as they are created
   - Automatically registers workload identities in the SPIRE server
   - Manages the lifecycle of SPIFFE identities for workloads

### 1.2 Communication Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                        SPIRE Server                              │
│                  (spire-system namespace)                        │
│              Root of Trust for demo.local                        │
└─────────────────────────┬────────────────────────────────────────┘
                          │
                          │ 8081 (gRPC)
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│  SPIRE Agent  │ │  SPIRE Agent  │ │  SPIRE Agent  │
│   (Node 1)    │ │   (Node 2)    │ │   (Node 3)    │
└───────┬───────┘ └───────┬───────┘ └───────┬───────┘
        │                 │                 │
        │ Unix Socket     │ Unix Socket     │ Unix Socket
        │ (Admin API)     │ (Admin API)     │ (Admin API)
        │                 │                 │
        ▼                 ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│ Cilium Agent  │ │ Cilium Agent  │ │ Cilium Agent  │
│   (Node 1)    │ │   (Node 2)    │ │   (Node 3)    │
└───────┬───────┘ └───────┬───────┘ └───────┬───────┘
        │                 │                 │
        │ Watches via     │ Watches via     │ Watches via
        │ Delegated       │ Delegated       │ Delegated
        │ Identity API    │ Identity API    │ Identity API
        │                 │                 │
        ▼                 ▼                 ▼
   [Workloads]       [Workloads]       [Workloads]
```

**Authentication Flow:**

1. **Cilium Operator** creates SPIRE entries for new Cilium Security Identities
2. **Cilium Agent** watches the **Delegated Identity API** for identities matching selector `cilium: mutual-auth`
3. **SPIRE Agent** attests workloads and returns SVIDs to Cilium Agent
4. When a **network policy requires authentication**, Cilium agents perform **out-of-band TLS handshake**
5. If handshake succeeds, workloads are authenticated and traffic is allowed

### 1.3 SPIFFE Identity Format

Cilium uses a unique SPIFFE ID format based on **Cilium Security Identity IDs** rather than namespace/service account:

**Format:** `spiffe://spiffe.cilium/identity/$IDENTITY_ID`

**Examples:**
- `spiffe://spiffe.cilium/cilium-agent` (Cilium agent identity)
- `spiffe://spiffe.cilium/cilium-operator` (Cilium operator identity)
- `spiffe://spiffe.cilium/identity/17947` (Workload identity based on Cilium Identity ID)

**Note:** This differs from typical SPIRE deployments which use:
`spiffe://<trust-domain>/ns/<namespace>/sa/<service-account>`

### 1.4 Key Differences from Standard SPIRE

| Aspect | Standard SPIRE | Cilium + SPIRE |
|--------|----------------|----------------|
| **Identity Request** | Workload requests its own identity | Cilium agent requests on behalf of workload |
| **API Used** | Workload API | Delegated Identity API |
| **SPIFFE ID Format** | Based on namespace/SA | Based on Cilium Identity ID |
| **Trust Domain** | User-defined | Default: `spiffe.cilium` |
| **Integration Point** | Direct workload integration | Transparent (no workload changes) |

---

## 2. SPIRE Configuration Requirements

### 2.1 SPIRE Server Configuration

**File:** `infrastructure/spire/server-configmap.yaml`

**Required Additions:**

The SPIRE server configuration doesn't require additional changes beyond the standard setup for Cilium integration. The existing configuration is sufficient:

```yaml
server {
  bind_address = "0.0.0.0"
  bind_port = "8081"
  trust_domain = "demo.local"  # Your trust domain
  data_dir = "/run/spire/data"
  log_level = "DEBUG"
}

plugins {
  DataStore "sql" {
    plugin_data {
      database_type = "sqlite3"
      connection_string = "/run/spire/data/datastore.sqlite3"
    }
  }

  NodeAttestor "k8s_psat" {
    plugin_data {
      clusters = {
        "precinct-99" = {
          service_account_allow_list = [
            "spire-system:spire-agent",
            "kube-system:cilium",           # ADD THIS for Cilium
            "kube-system:cilium-operator"   # ADD THIS for Cilium Operator
          ]
        }
      }
    }
  }

  KeyManager "disk" {
    plugin_data {
      keys_path = "/run/spire/data/keys.json"
    }
  }

  Notifier "k8sbundle" {
    plugin_data {
      namespace = "spire-system"
    }
  }
}
```

**Key Changes:**
- Add `kube-system:cilium` and `kube-system:cilium-operator` to the service account allow list

### 2.2 SPIRE Agent Configuration

**File:** `infrastructure/spire/agent-configmap.yaml`

**Required Additions for Delegated Identity API:**

```yaml
agent {
  data_dir = "/run/spire"
  log_level = "DEBUG"
  server_address = "spire-server.spire-system"
  server_port = "8081"
  socket_path = "/run/spire/sockets/agent.sock"
  trust_domain = "demo.local"
  trust_bundle_path = "/run/spire/bundle/bundle.crt"

  # CRITICAL: Enable Delegated Identity API
  admin_socket_path = "/run/spire/sockets/admin.sock"

  # CRITICAL: Authorize Cilium agent to use Delegated Identity API
  authorized_delegates = [
    "spiffe://demo.local/ns/kube-system/sa/cilium"
  ]
}

plugins {
  NodeAttestor "k8s_psat" {
    plugin_data {
      cluster = "precinct-99"
    }
  }

  KeyManager "memory" {
    plugin_data {}
  }

  WorkloadAttestor "k8s" {
    plugin_data {
      skip_kubelet_verification = true
    }
  }
}

health_checks {
  listener_enabled = true
  bind_address = "0.0.0.0"
  bind_port = "8080"
  live_path = "/live"
  ready_path = "/ready"
}
```

**Critical Configuration Parameters:**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `admin_socket_path` | `/run/spire/sockets/admin.sock` | Unix socket for admin API (serves Delegated Identity API) |
| `authorized_delegates` | `["spiffe://demo.local/ns/kube-system/sa/cilium"]` | SPIFFE IDs authorized to use Delegated Identity API |

**Security Note:**
> The `authorized_delegates` configuration **explicitly grants the Cilium agent the ability to impersonate any workload** it can obtain SVIDs for. This is by design but requires careful security consideration.

### 2.3 SPIRE Agent DaemonSet Volume Mounts

**File:** `infrastructure/spire/agent-daemonset.yaml`

**Required Changes:**

Ensure the admin socket directory is properly mounted:

```yaml
volumeMounts:
  - name: spire-config
    mountPath: /run/spire/config
    readOnly: true
  - name: spire-bundle
    mountPath: /run/spire/bundle
    readOnly: true
  - name: spire-agent-socket
    mountPath: /run/spire/sockets      # Both agent.sock and admin.sock
  - name: spire-token
    mountPath: /var/run/secrets/tokens

volumes:
  - name: spire-agent-socket
    hostPath:
      path: /run/spire/sockets
      type: DirectoryOrCreate         # Creates both workload and admin sockets
```

**Important:** The `/run/spire/sockets` directory will contain:
- `agent.sock` - Workload API socket (for direct SPIRE integrations)
- `admin.sock` - Admin API socket (for Delegated Identity API - used by Cilium)

### 2.4 Required SPIRE Registration Entries

The Cilium operator will automatically create SPIRE entries for workload identities. However, you must manually create entries for the **Cilium agent and operator** themselves.

**Entry for Cilium Agent:**

```bash
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium \
  -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99/<node-name> \
  -selector k8s:ns:kube-system \
  -selector k8s:sa:cilium
```

**Entry for Cilium Operator:**

```bash
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium-operator \
  -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99/<node-name> \
  -selector k8s:ns:kube-system \
  -selector k8s:sa:cilium-operator
```

**Important Notes:**
1. Replace `<node-name>` with actual node names, or create wildcard entries
2. These entries must exist **before** enabling Cilium mutual authentication
3. In dynamic infrastructure (spot instances, autoscaling), consider using Cilium's built-in SPIRE server installation which handles this automatically

---

## 3. Cilium Configuration Requirements

### 3.1 Helm Values for SPIRE Integration

**Option 1: Using Cilium's Bundled SPIRE (Recommended for New Deployments)**

```bash
helm upgrade cilium cilium/cilium \
  --version 1.15.7 \
  --namespace kube-system \
  --set authentication.mutual.spire.enabled=true \
  --set authentication.mutual.spire.install.enabled=true \
  --set authentication.mutual.spire.install.server.dataStorage.enabled=true \
  --set cluster.name=precinct-99
```

**Option 2: Using Existing SPIRE Server (Our Case)**

```bash
helm upgrade cilium cilium/cilium \
  --version 1.15.7 \
  --namespace kube-system \
  --set authentication.mutual.spire.enabled=true \
  --set authentication.mutual.spire.install.enabled=false \
  --set authentication.mutual.spire.adminSocketPath=/run/spire/sockets/admin.sock \
  --set authentication.mutual.spire.agentSocketPath=/run/spire/sockets/agent.sock \
  --set authentication.mutual.spire.serverAddress=spire-server.spire-system.svc.cluster.local:8081 \
  --set authentication.mutual.spire.trustDomain=demo.local \
  --set cluster.name=precinct-99
```

### 3.2 Key Cilium Configuration Parameters

| Parameter | Value (Our Environment) | Description |
|-----------|------------------------|-------------|
| `authentication.mutual.spire.enabled` | `true` | Enable SPIRE-based mutual authentication |
| `authentication.mutual.spire.install.enabled` | `false` | Don't install bundled SPIRE (we have our own) |
| `authentication.mutual.spire.adminSocketPath` | `/run/spire/sockets/admin.sock` | Path to SPIRE admin socket (Delegated Identity API) |
| `authentication.mutual.spire.agentSocketPath` | `/run/spire/sockets/agent.sock` | Path to SPIRE agent socket (Workload API) |
| `authentication.mutual.spire.serverAddress` | `spire-server.spire-system.svc.cluster.local:8081` | SPIRE server address |
| `authentication.mutual.spire.trustDomain` | `demo.local` | SPIFFE trust domain |
| `cluster.name` | `precinct-99` | Cluster name (required for mutual auth) |

### 3.3 Cilium Agent Command-Line Flags

When Cilium is deployed with SPIRE integration, the following flags are automatically configured:

```bash
cilium-agent \
  --mesh-auth-enabled=true \
  --mesh-auth-spire-admin-socket=/run/spire/sockets/admin.sock \
  --mesh-auth-spiffe-trust-domain=demo.local \
  --mesh-auth-queue-size=1024 \
  --mesh-auth-gc-interval=1m
```

**Flag Reference:**

| Flag | Purpose |
|------|---------|
| `--mesh-auth-enabled` | Enable mutual authentication processing |
| `--mesh-auth-spire-admin-socket` | Path to SPIRE admin socket |
| `--mesh-auth-spiffe-trust-domain` | SPIFFE trust domain |
| `--mesh-auth-queue-size` | Buffer size for authentication events |
| `--mesh-auth-gc-interval` | Garbage collection interval for stale auth entries |

### 3.4 Socket Path Mounting Requirements

Cilium agents need access to SPIRE agent sockets via **hostPath** volumes.

**Cilium DaemonSet Configuration:**

When `authentication.mutual.spire.enabled=true`, Cilium automatically creates:

```yaml
volumes:
  - name: spire-agent-socket
    hostPath:
      path: /run/spire/sockets    # Must match SPIRE agent socket directory
      type: DirectoryOrCreate
```

**Volume Mount:**

```yaml
volumeMounts:
  - name: spire-agent-socket
    mountPath: /run/spire/sockets
```

**Critical Requirement:** The hostPath **must match** the SPIRE agent socket directory. Both components must use the same path.

### 3.5 Version Compatibility

| Component | Version | Compatibility Notes |
|-----------|---------|---------------------|
| **Cilium** | 1.15.7 | SPIRE integration supported (beta since 1.14) |
| **Cilium CLI** | ≥ 0.15 | Required for mutual authentication |
| **SPIRE** | 1.9.6 | Compatible (Cilium tested with 1.9.x) |
| **Kubernetes** | 1.34 | Fully supported |

**Important:**
- Cilium's mutual authentication is **beta** as of 1.15.7
- Only validated with SPIRE (not other SPIFFE implementations)
- Cluster Mesh is **not compatible** with mutual authentication

---

## 4. Deployment Considerations

### 4.1 RBAC Requirements

#### 4.1.1 Cilium Agent RBAC

The Cilium agent requires permissions to:
- Access the SPIRE agent admin socket (via hostPath)
- Read Kubernetes API for pod/node information

**ClusterRole (Partial - SPIRE-Related):**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cilium
rules:
  - apiGroups: [""]
    resources: ["pods", "nodes", "namespaces", "services", "endpoints"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods/finalizers"]
    verbs: ["update"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["get", "list", "watch"]
```

#### 4.1.2 Cilium Operator RBAC

The Cilium operator needs permissions to create SPIRE entries:

**Additional Permissions:**

```yaml
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["get", "list", "watch"]
```

#### 4.1.3 SPIRE Server RBAC

The SPIRE server needs permissions for:
- k8sbundle notifier (ConfigMap management)
- Token review (k8s_psat attestation)

**Existing RBAC is sufficient** with our current setup.

### 4.2 Network Requirements

| Source | Destination | Port | Protocol | Purpose |
|--------|-------------|------|----------|---------|
| Cilium Agent | SPIRE Agent (same node) | Unix socket | N/A | Delegated Identity API |
| SPIRE Agent | SPIRE Server | 8081 | gRPC/TLS | Identity attestation |
| Cilium Agent | Cilium Agent (other nodes) | Various | TCP | Out-of-band TLS handshake |

### 4.3 Trust Domain Configuration

**Decision Point:** Should you use the default `spiffe.cilium` or your existing `demo.local`?

**Recommendation for This Project:** Use **`demo.local`**

**Rationale:**
1. **Consistency**: Aligns with existing SPIRE infrastructure
2. **Unified Trust**: Single trust domain for all workloads (backend, frontend, Cilium)
3. **Simpler Certificate Management**: One CA root for all SPIFFE identities

**Trade-off:**
- Using `demo.local` means Cilium identities and application identities share the same trust domain
- This is acceptable for a demo/POC environment
- Production deployments might prefer separate trust domains for security boundaries

**Configuration:**

```bash
--set authentication.mutual.spire.trustDomain=demo.local
```

### 4.4 Storage Requirements

**For Cilium's Bundled SPIRE (Not Our Case):**
- SPIRE server requires PersistentVolumeClaim support
- Can be disabled with `authentication.mutual.spire.install.server.dataStorage.enabled=false`
- Disabling storage means data is lost on pod restart

**For Our Existing SPIRE:**
- Already using PVC-backed storage at `/run/spire/data`
- No additional storage requirements for Cilium integration

### 4.5 Limitations and Constraints

#### Beta Status Limitations

Cilium mutual authentication (as of 1.15.7) is **beta** with these limitations:

1. **Cluster Mesh Incompatibility**: Cannot combine Cluster Mesh with mutual authentication
2. **Single Cluster Only**: No multi-cluster trust domain support
3. **SPIRE Only**: Only validated with SPIRE (not other SPIFFE implementations)
4. **Incomplete Security Features**: Several planned security features not yet implemented

#### Performance Considerations

1. **First Packet Delay**: Authentication handshake may delay initial packets
2. **Memory Overhead**: Cilium agent caches identities for all watched workloads
3. **SPIRE Load**: Increased load on SPIRE server from Cilium operator creating entries

#### Operational Constraints

1. **Dynamic Infrastructure**: Manual SPIRE entry creation for cilium-agent/operator is unsustainable with spot instances/autoscaling
2. **Encryption Requirement**: **Strongly recommended** to use WireGuard or IPsec encryption alongside mutual authentication
3. **No Drop Guarantees**: Authentication doesn't guarantee zero packet loss during handshake

---

## 5. Step-by-Step Implementation

### Phase 1: Pre-Implementation Verification

**Step 1.1: Verify Current SPIRE Deployment**

```bash
# Check SPIRE server health
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server healthcheck

# Expected output: Server is healthy

# Check SPIRE agents
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server agent list

# Expected: One agent per node (3 agents for precinct-99)
```

**Step 1.2: Verify Cilium Current State**

```bash
# Check Cilium status
cilium status

# Check current Helm values
helm get values cilium -n kube-system

# Verify Cilium CLI version (must be ≥ 0.15)
cilium version
```

### Phase 2: SPIRE Configuration Updates

**Step 2.1: Backup Current Configuration**

```bash
# Backup SPIRE agent ConfigMap
kubectl get configmap spire-agent -n spire-system -o yaml > /tmp/spire-agent-backup.yaml

# Backup SPIRE server ConfigMap
kubectl get configmap spire-server -n spire-system -o yaml > /tmp/spire-server-backup.yaml
```

**Step 2.2: Update SPIRE Agent ConfigMap**

Edit `infrastructure/spire/agent-configmap.yaml`:

```yaml
agent {
  data_dir = "/run/spire"
  log_level = "DEBUG"
  server_address = "spire-server.spire-system"
  server_port = "8081"
  socket_path = "/run/spire/sockets/agent.sock"
  trust_domain = "demo.local"
  trust_bundle_path = "/run/spire/bundle/bundle.crt"

  # ADD THESE TWO LINES:
  admin_socket_path = "/run/spire/sockets/admin.sock"
  authorized_delegates = ["spiffe://demo.local/ns/kube-system/sa/cilium"]
}

# ... rest of configuration unchanged
```

**Apply the update:**

```bash
kubectl apply -f infrastructure/spire/agent-configmap.yaml

# Restart SPIRE agents to pick up new configuration
kubectl rollout restart daemonset/spire-agent -n spire-system

# Wait for rollout to complete
kubectl rollout status daemonset/spire-agent -n spire-system
```

**Step 2.3: Update SPIRE Server ConfigMap**

Edit `infrastructure/spire/server-configmap.yaml`:

```yaml
NodeAttestor "k8s_psat" {
  plugin_data {
    clusters = {
      "precinct-99" = {
        service_account_allow_list = [
          "spire-system:spire-agent",
          "kube-system:cilium",           # ADD THIS
          "kube-system:cilium-operator"   # ADD THIS
        ]
      }
    }
  }
}
```

**Apply the update:**

```bash
kubectl apply -f infrastructure/spire/server-configmap.yaml

# Restart SPIRE server to pick up new configuration
kubectl rollout restart statefulset/spire-server -n spire-system

# Wait for rollout to complete
kubectl rollout status statefulset/spire-server -n spire-system
```

**Step 2.4: Verify SPIRE Admin Socket**

```bash
# Check that admin socket is created
kubectl exec -n spire-system spire-agent-<pod-name> -- ls -la /run/spire/sockets/

# Expected output should show both:
# - agent.sock
# - admin.sock
```

### Phase 3: Create SPIRE Registration Entries for Cilium

**Step 3.1: Create Entry for Cilium Agent**

```bash
# Get a SPIRE agent pod
AGENT_POD=$(kubectl get pods -n spire-system -l app=spire-agent -o jsonpath='{.items[0].metadata.name}')

# Get the SPIRE agent's SPIFFE ID (needed as parent ID)
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server agent list

# Create entry for cilium agent
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium \
  -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99/$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') \
  -selector k8s:ns:kube-system \
  -selector k8s:sa:cilium \
  -ttl 3600

# Verify entry creation
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium
```

**Step 3.2: Create Entry for Cilium Operator**

```bash
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium-operator \
  -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99/$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') \
  -selector k8s:ns:kube-system \
  -selector k8s:sa:cilium-operator \
  -ttl 3600

# Verify entry creation
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium-operator
```

**Note:** For multi-node clusters, you may need to create entries for each node or use wildcard selectors. For a 3-node cluster (precinct-99), repeat for each node.

**Alternative: Create Entries for All Nodes**

```bash
# Get all node names
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')

# For each node, create cilium agent entry
for NODE in $NODES; do
  echo "Creating entry for cilium agent on node: $NODE"
  kubectl exec -n spire-system spire-server-0 -- \
    /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium \
    -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99/$NODE \
    -selector k8s:ns:kube-system \
    -selector k8s:sa:cilium \
    -selector k8s:node-name:$NODE \
    -ttl 3600
done
```

### Phase 4: Upgrade Cilium with SPIRE Integration

**Step 4.1: Backup Current Cilium Configuration**

```bash
# Export current Helm values
helm get values cilium -n kube-system > /tmp/cilium-values-backup.yaml

# Backup current Cilium DaemonSet
kubectl get daemonset cilium -n kube-system -o yaml > /tmp/cilium-ds-backup.yaml
```

**Step 4.2: Upgrade Cilium with SPIRE Integration**

```bash
# Upgrade Cilium with SPIRE integration enabled
helm upgrade cilium cilium/cilium \
  --version 1.15.7 \
  --namespace kube-system \
  --reuse-values \
  --set authentication.mutual.spire.enabled=true \
  --set authentication.mutual.spire.install.enabled=false \
  --set authentication.mutual.spire.adminSocketPath=/run/spire/sockets/admin.sock \
  --set authentication.mutual.spire.agentSocketPath=/run/spire/sockets/agent.sock \
  --set authentication.mutual.spire.serverAddress=spire-server.spire-system.svc.cluster.local:8081 \
  --set authentication.mutual.spire.trustDomain=demo.local \
  --set cluster.name=precinct-99

# Wait for Cilium rollout to complete
kubectl rollout status daemonset/cilium -n kube-system
kubectl rollout status deployment/cilium-operator -n kube-system
```

**Step 4.3: Verify Cilium Configuration**

```bash
# Check Cilium status
cilium status

# Verify SPIRE integration flags
kubectl exec -n kube-system cilium-<pod-name> -- cilium-agent --help | grep mesh-auth

# Check Cilium logs for SPIRE connection
kubectl logs -n kube-system cilium-<pod-name> | grep -i spire
```

### Phase 5: Test Mutual Authentication

**Step 5.1: Deploy Test Workloads**

```bash
# Deploy example workloads
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.15.7/examples/kubernetes/servicemesh/mutual-auth-example.yaml
```

**Step 5.2: Apply Network Policy Without Authentication**

```bash
# Apply basic network policy (no authentication)
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.15.7/examples/kubernetes/servicemesh/cnp-without-mutual-auth.yaml

# Test connectivity
kubectl exec -it pod-worker -- curl -s -o /dev/null -w "%{http_code}" http://echo:3000/headers

# Expected: 200 (success)
```

**Step 5.3: Apply Network Policy With Authentication**

```bash
# Apply network policy with mutual authentication
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.15.7/examples/kubernetes/servicemesh/cnp-with-mutual-auth.yaml

# Test connectivity again
kubectl exec -it pod-worker -- curl -s -o /dev/null -w "%{http_code}" http://echo:3000/headers

# Expected: 200 (success with authentication)
```

**Example Network Policy with Authentication:**

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: echo-ingress
spec:
  endpointSelector:
    matchLabels:
      name: echo
  ingress:
    - fromEndpoints:
        - matchLabels:
            name: pod-worker
      toPorts:
        - ports:
            - port: "3000"
              protocol: TCP
      authentication:
        mode: "required"  # This triggers mutual authentication
```

---

## 6. Verification and Testing

### 6.1 Verify SPIRE Integration

**Check SPIRE Server Entries:**

```bash
# List all SPIRE entries
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show

# Check for cilium-specific entries
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show \
  -selector cilium:mutual-auth

# Expected: Entries created by Cilium operator for workload identities
```

**Check Cilium Agent Identity:**

```bash
# Verify Cilium agent can authenticate to SPIRE
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium

# Expected: Entry exists with correct selectors
```

### 6.2 Verify Mutual Authentication

**Enable Debug Logging:**

```bash
# Enable debug mode on Cilium
cilium config set debug true

# Wait a few seconds for config to propagate
```

**Check Authentication Logs:**

```bash
# Get Cilium pod on the same node as the destination workload
CILIUM_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')

# Check for authentication events
kubectl logs -n kube-system $CILIUM_POD | grep -i "auth\|spire\|spiffe"

# Look for these messages:
# - "Policy is requiring authentication"
# - "Validating Server SNI"
# - "Validated certificate"
# - "Successfully authenticated"
```

**Detailed Log Inspection:**

```bash
# Check authentication logs with timestamps
kubectl -n kube-system logs $CILIUM_POD --timestamps=true | \
  grep "Policy is requiring authentication\|Validating Server SNI\|Validated certificate\|Successfully authenticated"

# Example successful authentication log:
# 2026-01-02T10:15:30.123456789Z Policy is requiring authentication authType=spire
# 2026-01-02T10:15:30.234567890Z Validating Server SNI uri-san="spiffe://demo.local/identity/17947"
# 2026-01-02T10:15:30.345678901Z Validated certificate uri-san="spiffe://demo.local/identity/17947"
# 2026-01-02T10:15:30.456789012Z Successfully authenticated remote-id=17947
```

### 6.3 Verify SPIFFE Identities

**Get Cilium Identity for a Pod:**

```bash
# Get pod labels
kubectl get pod echo -o jsonpath='{.metadata.labels}' | jq

# Get Cilium Identity ID
kubectl get ciliumendpoint -o jsonpath='{.items[?(@.metadata.name=="echo")].status.identity.id}'

# Example output: 17947
```

**Verify Corresponding SPIRE Entry:**

```bash
# Check if SPIRE entry exists for this identity
IDENTITY_ID=17947  # Replace with actual ID

kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show \
  -spiffeID spiffe://demo.local/identity/$IDENTITY_ID

# Expected: Entry created by Cilium operator
```

### 6.4 Test Network Policy Enforcement

**Test 1: Connection Without Authentication Policy**

```bash
# Apply policy without authentication
kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: test-no-auth
spec:
  endpointSelector:
    matchLabels:
      name: echo
  ingress:
    - fromEndpoints:
        - matchLabels:
            name: pod-worker
      toPorts:
        - ports:
            - port: "3000"
              protocol: TCP
EOF

# Test connectivity
kubectl exec -it pod-worker -- curl -s -o /dev/null -w "%{http_code}" http://echo:3000/headers

# Expected: 200 (allowed, no authentication required)
```

**Test 2: Connection With Authentication Policy**

```bash
# Apply policy with authentication
kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: test-with-auth
spec:
  endpointSelector:
    matchLabels:
      name: echo
  ingress:
    - fromEndpoints:
        - matchLabels:
            name: pod-worker
      toPorts:
        - ports:
            - port: "3000"
              protocol: TCP
      authentication:
        mode: "required"
EOF

# Test connectivity
kubectl exec -it pod-worker -- curl -s -o /dev/null -w "%{http_code}" http://echo:3000/headers

# Expected: 200 (allowed with authentication)
# Check logs to verify authentication occurred
```

**Test 3: Connection From Unauthorized Pod**

```bash
# Deploy unauthorized pod
kubectl run unauthorized --image=curlimages/curl --restart=Never -- sleep 3600

# Try to connect
kubectl exec -it unauthorized -- curl -s -o /dev/null -w "%{http_code}" http://echo:3000/headers

# Expected: Connection blocked (no network policy allows this pod)
```

### 6.5 Performance Testing

**Measure Authentication Overhead:**

```bash
# Test latency without authentication
kubectl exec -it pod-worker -- sh -c 'for i in {1..100}; do curl -s -o /dev/null -w "%{time_total}\n" http://echo:3000/headers; done' | awk '{sum+=$1} END {print "Average: " sum/NR " seconds"}'

# Apply authentication policy and test again
# Compare average latency

# Note: First request may be slower due to authentication handshake
```

---

## 7. Common Issues and Troubleshooting

### 7.1 SPIRE Agent Issues

#### Issue: Admin Socket Not Created

**Symptoms:**
- `/run/spire/sockets/admin.sock` does not exist
- Cilium logs show "failed to connect to SPIRE admin socket"

**Solution:**

```bash
# Verify admin_socket_path in agent config
kubectl get configmap spire-agent -n spire-system -o yaml | grep admin_socket_path

# If missing, add it and restart agents
kubectl rollout restart daemonset/spire-agent -n spire-system

# Verify socket creation
kubectl exec -n spire-system spire-agent-<pod> -- ls -la /run/spire/sockets/
```

#### Issue: Cilium Not in Authorized Delegates

**Symptoms:**
- Cilium logs show "permission denied" or "unauthorized delegate"
- SPIRE agent logs show "delegate not authorized"

**Solution:**

```bash
# Check authorized_delegates in agent config
kubectl get configmap spire-agent -n spire-system -o yaml | grep -A5 authorized_delegates

# Should contain: "spiffe://demo.local/ns/kube-system/sa/cilium"

# If missing, update config and restart
kubectl apply -f infrastructure/spire/agent-configmap.yaml
kubectl rollout restart daemonset/spire-agent -n spire-system
```

### 7.2 Cilium Integration Issues

#### Issue: Cilium Cannot Find SPIRE Socket

**Symptoms:**
- Cilium logs: "failed to connect to SPIRE admin socket at /run/spire/sockets/admin.sock"
- Error: "no such file or directory"

**Root Cause:**
- hostPath mismatch between SPIRE and Cilium
- SPIRE socket not accessible to Cilium pods

**Solution:**

```bash
# Verify SPIRE socket path
kubectl exec -n spire-system spire-agent-<pod> -- ls -la /run/spire/sockets/

# Verify Cilium hostPath mount
kubectl get daemonset cilium -n kube-system -o yaml | grep -A10 "name: spire-agent-socket"

# Should show:
#   hostPath:
#     path: /run/spire/sockets
#     type: DirectoryOrCreate

# If incorrect, update Cilium Helm values and upgrade
helm upgrade cilium cilium/cilium --reuse-values \
  --set authentication.mutual.spire.adminSocketPath=/run/spire/sockets/admin.sock
```

#### Issue: No Authentication Logs

**Symptoms:**
- Network policy with `authentication.mode: required` applied
- No authentication logs in Cilium agent logs
- Traffic works but no evidence of authentication

**Troubleshooting:**

```bash
# 1. Enable debug logging
cilium config set debug true

# 2. Check if authentication is actually enabled
kubectl exec -n kube-system cilium-<pod> -- cilium-agent --help | grep mesh-auth

# 3. Verify policy is applied correctly
kubectl get cnp <policy-name> -o yaml

# 4. Check for authentication events
kubectl logs -n kube-system cilium-<pod> | grep -i "auth"

# 5. Verify SPIRE entries exist for the workloads
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show -selector cilium:mutual-auth
```

### 7.3 SPIRE Registration Issues

#### Issue: Cilium Operator Not Creating SPIRE Entries

**Symptoms:**
- Workload identities not appearing in SPIRE server
- No entries with selector `cilium:mutual-auth`

**Solution:**

```bash
# 1. Check Cilium operator logs
kubectl logs -n kube-system deployment/cilium-operator | grep -i spire

# 2. Verify Cilium operator can connect to SPIRE server
kubectl logs -n kube-system deployment/cilium-operator | grep -i "connection\|failed"

# 3. Check SPIRE server allows cilium-operator
kubectl get configmap spire-server -n spire-system -o yaml | grep -A10 service_account_allow_list

# Should include: "kube-system:cilium-operator"

# 4. Verify cilium-operator SPIRE entry exists
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium-operator
```

#### Issue: Parent ID Not Found

**Symptoms:**
- Error creating SPIRE entry: "parent ID not found"

**Solution:**

```bash
# 1. List all SPIRE agents
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server agent list

# 2. Note the exact SPIFFE IDs (parent IDs)
# Format: spiffe://demo.local/spire/agent/k8s_psat/precinct-99/<node-name>

# 3. Use the correct parent ID when creating entries
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
  -spiffeID spiffe://demo.local/ns/kube-system/sa/cilium \
  -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99/<exact-node-name> \
  -selector k8s:ns:kube-system \
  -selector k8s:sa:cilium
```

### 7.4 Trust Domain Mismatch

#### Issue: Trust Domain Conflict

**Symptoms:**
- Authentication fails with "trust domain mismatch"
- Cilium using `spiffe.cilium` but SPIRE using `demo.local`

**Solution:**

```bash
# Ensure consistent trust domain across all components

# 1. Check SPIRE server trust domain
kubectl get configmap spire-server -n spire-system -o yaml | grep trust_domain

# 2. Check SPIRE agent trust domain
kubectl get configmap spire-agent -n spire-system -o yaml | grep trust_domain

# 3. Check Cilium trust domain
helm get values cilium -n kube-system | grep trustDomain

# All should match: demo.local

# 4. If Cilium trust domain is wrong, update:
helm upgrade cilium cilium/cilium --reuse-values \
  --set authentication.mutual.spire.trustDomain=demo.local

# 5. Restart Cilium
kubectl rollout restart daemonset/cilium -n kube-system
kubectl rollout restart deployment/cilium-operator -n kube-system
```

### 7.5 Performance Issues

#### Issue: High Latency After Enabling Mutual Auth

**Symptoms:**
- Significantly increased latency for pod-to-pod communication
- First packet delays

**Investigation:**

```bash
# 1. Check authentication handshake time
kubectl logs -n kube-system cilium-<pod> | grep "authentication.*time"

# 2. Verify SPIRE server performance
kubectl top pod -n spire-system spire-server-0

# 3. Check for SPIRE agent bottlenecks
kubectl top pods -n spire-system -l app=spire-agent

# 4. Review Cilium mesh-auth queue size
kubectl exec -n kube-system cilium-<pod> -- cilium config | grep mesh-auth
```

**Mitigation:**

```bash
# Increase mesh-auth queue size
helm upgrade cilium cilium/cilium --reuse-values \
  --set meshAuth.queueSize=2048 \
  --set meshAuth.gcInterval=30s

# Consider enabling connection caching (if available in your version)
```

### 7.6 Debugging Commands Reference

**Quick Diagnostic Script:**

```bash
#!/bin/bash

echo "=== SPIRE Server Health ==="
kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server healthcheck

echo "\n=== SPIRE Agents ==="
kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server agent list

echo "\n=== SPIRE Entries ==="
kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server entry show | head -50

echo "\n=== Cilium Status ==="
cilium status

echo "\n=== Cilium SPIRE Configuration ==="
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}') -- cilium-agent --help | grep mesh-auth

echo "\n=== Recent Cilium Authentication Logs ==="
kubectl logs -n kube-system $(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}') --tail=100 | grep -i "auth\|spire"

echo "\n=== Cilium Network Policies with Authentication ==="
kubectl get cnp -A -o json | jq '.items[] | select(.spec.ingress[]?.authentication.mode == "required") | {name: .metadata.name, namespace: .metadata.namespace}'
```

**Save as:** `/home/mandrix-murdock/code/spire-spife/test-vault/scripts/helpers/diagnose-cilium-spire.sh`

---

## 8. References

### Official Documentation

1. **Cilium Mutual Authentication (Latest)**
   - [https://docs.cilium.io/en/latest/network/servicemesh/mutual-authentication/mutual-authentication/](https://docs.cilium.io/en/latest/network/servicemesh/mutual-authentication/mutual-authentication/)

2. **Cilium Mutual Authentication (Stable 1.18.5)**
   - [https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/mutual-authentication/](https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/mutual-authentication/)

3. **Cilium Mutual Authentication Example**
   - [https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/mutual-authentication-example/](https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/mutual-authentication-example/)

4. **SPIRE Agent Configuration Reference**
   - [https://spiffe.io/docs/latest/deploying/spire_agent/](https://spiffe.io/docs/latest/deploying/spire_agent/)

5. **SPIRE Delegated Identity API Documentation**
   - [https://github.com/spiffe/spire/blob/main/doc/spire_agent.md](https://github.com/spiffe/spire/blob/main/doc/spire_agent.md)

### Community Resources

6. **AccuKnox Cilium SPIRE Tutorials**
   - [https://github.com/accuknox/cilium-spire-tutorials](https://github.com/accuknox/cilium-spire-tutorials)

7. **Cilium Design CFP: Mutual Authentication for Service Mesh**
   - [https://github.com/cilium/design-cfps/blob/main/cilium/CFP-22215-mutual-auth-for-service-mesh.md](https://github.com/cilium/design-cfps/blob/main/cilium/CFP-22215-mutual-auth-for-service-mesh.md)

8. **AccuKnox: SPIFFE Workload Identity Integration With Cilium**
   - [https://accuknox.com/blog/spiffe-workload-identity-integration-with-cilium](https://accuknox.com/blog/spiffe-workload-identity-integration-with-cilium)

9. **AccuKnox: Protecting Workloads in Kubernetes with mTLS, SPIFFE/SPIRE, and Cilium**
   - [https://accuknox.com/blog/protecting-workloads-kubernetes-mtls-spiffe-spire-cilium](https://accuknox.com/blog/protecting-workloads-kubernetes-mtls-spiffe-spire-cilium)

### GitHub Issues and Discussions

10. **Cilium Mutual Auth: Update SPIRE DelegatedIdentity API usage**
    - [https://github.com/cilium/cilium/issues/31430](https://github.com/cilium/cilium/issues/31430)

11. **Cilium SPIRE Integration Lacks Automatic Entry Creation**
    - [https://github.com/cilium/cilium/issues/41250](https://github.com/cilium/cilium/issues/41250)

12. **Cilium Agent Support for DelegatedIdentity SPIFFE API**
    - [https://github.com/cilium/cilium/issues/23804](https://github.com/cilium/cilium/issues/23804)

13. **Create SPIFFE Identity When Cilium Identity is Created**
    - [https://github.com/cilium/cilium/issues/23802](https://github.com/cilium/cilium/issues/23802)

### Blog Posts and Articles

14. **Cilium 1.14 Release - Effortless Mutual Authentication**
    - [https://isovalent.com/blog/post/cilium-release-114/](https://isovalent.com/blog/post/cilium-release-114/)

15. **Next-Generation Mutual Authentication (mTLS) with Cilium Service Mesh**
    - [https://isovalent.com/blog/post/2022-05-03-servicemesh-security/](https://isovalent.com/blog/post/2022-05-03-servicemesh-security/)

16. **Cilium Mutual Auth DIY (Medium)**
    - [https://xxradar.medium.com/cilium-mutual-auth-diy-5d5036a82cf9](https://xxradar.medium.com/cilium-mutual-auth-diy-5d5036a82cf9)

### Project-Specific Documentation

17. **SPIRE/SPIFFE Official Documentation**
    - [https://spiffe.io/docs/latest/](https://spiffe.io/docs/latest/)

18. **Cilium Documentation - Helm Reference**
    - [https://docs.cilium.io/en/stable/helm-reference/](https://docs.cilium.io/en/stable/helm-reference/)

19. **Cilium CLI Reference - cilium-agent**
    - [https://docs.cilium.io/en/stable/cmdref/cilium-agent/](https://docs.cilium.io/en/stable/cmdref/cilium-agent/)

20. **Cilium CLI Reference - cilium-operator**
    - [https://docs.cilium.io/en/stable/cmdref/cilium-operator/](https://docs.cilium.io/en/stable/cmdref/cilium-operator/)

---

## Appendix A: Configuration File Templates

### A.1 SPIRE Agent ConfigMap (Complete)

**File:** `infrastructure/spire/agent-configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: spire-agent
  namespace: spire-system
data:
  agent.conf: |
    agent {
      data_dir = "/run/spire"
      log_level = "DEBUG"
      server_address = "spire-server.spire-system"
      server_port = "8081"
      socket_path = "/run/spire/sockets/agent.sock"
      trust_domain = "demo.local"
      trust_bundle_path = "/run/spire/bundle/bundle.crt"

      # Cilium Integration: Enable Delegated Identity API
      admin_socket_path = "/run/spire/sockets/admin.sock"

      # Cilium Integration: Authorize Cilium agent
      authorized_delegates = [
        "spiffe://demo.local/ns/kube-system/sa/cilium"
      ]
    }

    plugins {
      NodeAttestor "k8s_psat" {
        plugin_data {
          cluster = "precinct-99"
        }
      }

      KeyManager "memory" {
        plugin_data {}
      }

      WorkloadAttestor "k8s" {
        plugin_data {
          skip_kubelet_verification = true
        }
      }
    }

    health_checks {
      listener_enabled = true
      bind_address = "0.0.0.0"
      bind_port = "8080"
      live_path = "/live"
      ready_path = "/ready"
    }
```

### A.2 SPIRE Server ConfigMap (Complete)

**File:** `infrastructure/spire/server-configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: spire-server
  namespace: spire-system
data:
  server.conf: |
    server {
      bind_address = "0.0.0.0"
      bind_port = "8081"
      trust_domain = "demo.local"
      data_dir = "/run/spire/data"
      log_level = "DEBUG"

      ca_subject = {
        country = ["US"],
        organization = ["SPIFFE"],
        common_name = "demo.local",
      }
    }

    plugins {
      DataStore "sql" {
        plugin_data {
          database_type = "sqlite3"
          connection_string = "/run/spire/data/datastore.sqlite3"
        }
      }

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

      KeyManager "disk" {
        plugin_data {
          keys_path = "/run/spire/data/keys.json"
        }
      }

      Notifier "k8sbundle" {
        plugin_data {
          namespace = "spire-system"
        }
      }
    }

    health_checks {
      listener_enabled = true
      bind_address = "0.0.0.0"
      bind_port = "8080"
      live_path = "/live"
      ready_path = "/ready"
    }
```

### A.3 Cilium Helm Values (SPIRE Integration)

**File:** `cilium-spire-values.yaml`

```yaml
# Cilium Helm values for SPIRE integration
# Use with: helm upgrade cilium cilium/cilium -f cilium-spire-values.yaml

# Cluster identification
cluster:
  name: precinct-99

# SPIRE-based mutual authentication
authentication:
  mutual:
    spire:
      enabled: true
      install:
        enabled: false  # Using existing SPIRE deployment
      # Connection to existing SPIRE
      adminSocketPath: /run/spire/sockets/admin.sock
      agentSocketPath: /run/spire/sockets/agent.sock
      serverAddress: spire-server.spire-system.svc.cluster.local:8081
      trustDomain: demo.local

# Optional: Enable encryption (recommended with mutual auth)
# encryption:
#   enabled: true
#   type: wireguard

# Optional: Enable Hubble for observability
# hubble:
#   enabled: true
#   relay:
#     enabled: true
#   ui:
#     enabled: true
```

### A.4 Example CiliumNetworkPolicy with Authentication

**File:** `example-cnp-with-auth.yaml`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-api-auth
  namespace: 99-apps
spec:
  endpointSelector:
    matchLabels:
      app: backend-api
  ingress:
    # Allow from frontend with authentication
    - fromEndpoints:
        - matchLabels:
            app: frontend
            namespace: 99-apps
      toPorts:
        - ports:
            - port: "8000"
              protocol: TCP
      authentication:
        mode: "required"  # Enforce mutual TLS authentication

    # Allow health checks without authentication
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s-app: cilium
      toPorts:
        - ports:
            - port: "8000"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/health"
```

---

## Appendix B: Quick Reference Commands

### SPIRE Commands

```bash
# Health check
kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server healthcheck

# List agents
kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server agent list

# List all entries
kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server entry show

# List entries with specific selector
kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server entry show -selector cilium:mutual-auth

# Create entry
kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server entry create \
  -spiffeID <spiffe-id> \
  -parentID <parent-spiffe-id> \
  -selector <selector> \
  -ttl <seconds>

# Delete entry
kubectl exec -n spire-system spire-server-0 -- /opt/spire/bin/spire-server entry delete -entryID <id>
```

### Cilium Commands

```bash
# Status
cilium status

# Enable debug logging
cilium config set debug true

# Disable debug logging
cilium config set debug false

# View configuration
kubectl exec -n kube-system cilium-<pod> -- cilium config

# View identities
cilium identity list

# View network policies
kubectl get cnp -A

# View Cilium endpoints
kubectl get ciliumendpoints -A
```

### Helm Commands

```bash
# List Cilium installation
helm list -n kube-system

# Get current values
helm get values cilium -n kube-system

# Upgrade Cilium
helm upgrade cilium cilium/cilium --version 1.15.7 -n kube-system --reuse-values --set <key>=<value>

# Rollback Cilium
helm rollback cilium -n kube-system
```

### Kubectl Commands

```bash
# Restart SPIRE agents
kubectl rollout restart daemonset/spire-agent -n spire-system

# Restart SPIRE server
kubectl rollout restart statefulset/spire-server -n spire-system

# Restart Cilium
kubectl rollout restart daemonset/cilium -n kube-system
kubectl rollout restart deployment/cilium-operator -n kube-system

# Check rollout status
kubectl rollout status daemonset/cilium -n kube-system

# View logs
kubectl logs -n kube-system cilium-<pod> -c cilium-agent --tail=100 -f
kubectl logs -n kube-system deployment/cilium-operator --tail=100 -f
kubectl logs -n spire-system spire-server-0 --tail=100 -f
kubectl logs -n spire-system spire-agent-<pod> --tail=100 -f
```

---

## Document Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-02 | Initial comprehensive guide created |

---

**End of Document**
