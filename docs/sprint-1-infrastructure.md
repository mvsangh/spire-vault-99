# 🏗️ SUB-SPRINT 1: Infrastructure Foundation
**SPIRE + OpenBao + PostgreSQL + Cilium on kind**

## 📊 Overview

**Objective:** Deploy and configure the complete infrastructure foundation for the zero-trust demo platform on a local kind cluster.

**Duration:** ASAP
**Prerequisites:** Docker, kubectl, basic Kubernetes knowledge
**Success Criteria:** All infrastructure services running and healthy, ready for application deployment

---

## 🎯 Deliverables

- ✅ Multi-node kind cluster (1 control-plane + 2 workers)
- ✅ SPIRE server and agent deployed and issuing SVIDs
- ✅ OpenBao deployed, initialized, and accessible
- ✅ PostgreSQL deployed with schema and demo users seeded
- ✅ Cilium service mesh installed and healthy
- ✅ All services verified and connectivity tested

---

## 🗂️ Namespace Strategy

| Namespace | Components | Purpose |
|-----------|------------|---------|
| `spire-system` | SPIRE server + agent | Identity infrastructure |
| `openbao` | OpenBao | Secrets management |
| `99-apps` | PostgreSQL + Backend + Frontend | Application workloads |
| `kube-system` | Cilium | Service mesh (Helm default) |

---

## 📋 Phase Breakdown

### **Phase 1: Prerequisites & Environment Setup**
### **Phase 2: Kubernetes Cluster Setup (kind)**
### **Phase 3: SPIRE Deployment**
### **Phase 4: OpenBao Deployment**
### **Phase 5: PostgreSQL Deployment**
### **Phase 6: Cilium Installation**
### **Phase 7: Integration Verification & Testing**

---

## 🔧 Phase 1: Prerequisites & Environment Setup

**Objective:** Ensure local environment has all required tools and prepare directory structure.

### **Tasks:**

#### **Task 1.1: Verify Required Tools**

**Description:** Check that all necessary CLI tools are installed and meet minimum version requirements.

**Required Tools:**
- Docker Desktop (or Docker Engine)
- kubectl (v1.27+)
- kind (v0.20+)
- Helm (v3.12+)
- curl/wget
- jq (optional, but helpful)

**Commands:**
```bash
# Check Docker
docker --version
docker ps  # Verify Docker daemon is running

# Check kubectl
kubectl version --client

# Check kind
kind version

# Check Helm
helm version

# Check curl
curl --version

# Check jq (optional)
jq --version
```

**Expected Output:**
- All tools installed and accessible in PATH
- Docker daemon running

**Success Criteria:**
- ✅ All required tools installed
- ✅ Versions meet minimum requirements
- ✅ No errors when running version commands

---

#### **Task 1.2: Create Directory Structure**

**Description:** Create organized directory structure for Kubernetes manifests and scripts.

**Commands:**
```bash
cd /home/mandrix-murdock/code/spire-spife/test-vault

# Create infrastructure directories
mkdir -p infrastructure/kind
mkdir -p infrastructure/spire
mkdir -p infrastructure/openbao
mkdir -p infrastructure/postgres
mkdir -p infrastructure/cilium

# Create scripts directory
mkdir -p scripts/helpers

# Verify structure
tree infrastructure/ -L 2
```

**Expected Directory Structure:**
```
infrastructure/
├── kind/
│   └── kind-config.yaml
├── spire/
│   ├── namespace.yaml
│   ├── server-account.yaml
│   ├── server-configmap.yaml
│   ├── server-statefulset.yaml
│   ├── server-service.yaml
│   ├── agent-account.yaml
│   ├── agent-configmap.yaml
│   └── agent-daemonset.yaml
├── openbao/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── postgres/
│   ├── namespace.yaml
│   ├── statefulset.yaml
│   ├── service.yaml
│   └── init-db.sql
└── cilium/
    └── values.yaml
```

**Success Criteria:**
- ✅ All directories created
- ✅ Structure ready for manifests

---

#### **Task 1.3: Download Reference Documentation**

**Description:** Download or bookmark key reference documentation for offline access.

**Documentation Links:**
- SPIRE Kubernetes Quickstart: https://spiffe.io/docs/latest/try/getting-started-k8s/
- OpenBao Documentation: https://openbao.org/docs/
- Cilium Installation: https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/

**Action:**
- Bookmark these URLs
- Optional: Download PDFs for offline reference

**Success Criteria:**
- ✅ Documentation accessible
- ✅ Reference materials ready

---

### 📋 EXECUTION LOG - Phase 1

**Date:** 2025-12-29
**Status:** ✅ COMPLETED

**Summary of Implementation:**
- Verified all required tools (Docker, kubectl, kind, Helm, curl, jq)
- Created complete directory structure for infrastructure manifests
- All prerequisites met and environment ready

**Tool Versions Verified:**
- Docker 29.1.3 (daemon running)
- kubectl v1.34.1 (exceeds minimum v1.27+)
- kind v0.30.0 (exceeds minimum v0.20+)
- Helm v4.0.4 (exceeds minimum v3.12+)
- curl 8.5.0
- jq 1.7

**Issues Faced:**
- None

**Important Decisions/Changes:**
- All tool versions exceed minimum requirements
- Directory structure created successfully with proper organization

**Next Phase:** Phase 2 - Kubernetes Cluster Setup

---

## ☸️ Phase 2: Kubernetes Cluster Setup (kind)

**Objective:** Deploy a multi-node kind cluster configured for our demo platform.

### **Tasks:**

#### **Task 2.1: Create kind Configuration File**

**Description:** Create kind configuration file for multi-node cluster with port mappings.

**File:** `infrastructure/kind/kind-config.yaml`

**Content:**
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: precinct-99

# Multi-node cluster configuration
nodes:
  # Control plane node
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      # Frontend (Next.js)
      - containerPort: 30000
        hostPort: 3000
        protocol: TCP
      # Backend (FastAPI)
      - containerPort: 30001
        hostPort: 8000
        protocol: TCP
      # OpenBao UI
      - containerPort: 30002
        hostPort: 8200
        protocol: TCP

  # Worker node 1
  - role: worker

  # Worker node 2
  - role: worker

# Networking configuration
networking:
  # Disable default CNI (we'll install Cilium)
  disableDefaultCNI: true
  # Pod subnet
  podSubnet: "10.244.0.0/16"
  # Service subnet
  serviceSubnet: "10.96.0.0/12"
```

**Explanation:**
- **Multi-node:** 1 control-plane + 2 workers (realistic for DaemonSet testing)
- **Port Mappings:** Expose frontend (3000), backend (8000), OpenBao UI (8200)
- **Disable Default CNI:** We'll install Cilium as the CNI
- **Custom Subnets:** Standard Kubernetes pod/service CIDRs

**Success Criteria:**
- ✅ File created at `infrastructure/kind/kind-config.yaml`
- ✅ YAML is valid (can validate with `yamllint` if available)

---

#### **Task 2.2: Deploy kind Cluster**

**Description:** Create the kind cluster using the configuration file.

**Commands:**
```bash
# Deploy cluster
kind create cluster --config infrastructure/kind/kind-config.yaml

# Wait for cluster to be ready
kubectl wait --for=condition=Ready nodes --all --timeout=300s
```

**Expected Output:**
```
Creating cluster "precinct-99" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-precinct-99"
You can now use your cluster with:

kubectl cluster-info --context kind-precinct-99
```

**Success Criteria:**
- ✅ Cluster created successfully
- ✅ 3 nodes (1 control-plane + 2 workers)
- ✅ kubectl context set to new cluster

---

#### **Task 2.3: Verify Cluster Health**

**Description:** Verify that the cluster is healthy and all nodes are ready.

**Commands:**
```bash
# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes -o wide

# Check system pods (should be minimal without CNI)
kubectl get pods -n kube-system
```

**Expected Output:**
```
NAME                         STATUS   ROLES           AGE   VERSION
precinct-99-control-plane    Ready    control-plane   2m    v1.27.3
precinct-99-worker           Ready    <none>          2m    v1.27.3
precinct-99-worker2          Ready    <none>          2m    v1.27.3
```

**Success Criteria:**
- ✅ All 3 nodes in Ready state
- ✅ kubectl can communicate with cluster
- ✅ No critical errors in system logs

---

#### **Task 2.4: Create Application Namespaces**

**Description:** Create the namespaces for our infrastructure and application components.

**Commands:**
```bash
# Create namespaces
kubectl create namespace spire-system
kubectl create namespace openbao
kubectl create namespace 99-apps

# Verify namespaces
kubectl get namespaces
```

**Expected Output:**
```
NAME              STATUS   AGE
default           Active   3m
kube-node-lease   Active   3m
kube-public       Active   3m
kube-system       Active   3m
spire-system      Active   10s
openbao           Active   10s
99-apps           Active   10s
```

**Alternative:** Create namespace YAML files in respective directories and apply them.

**Success Criteria:**
- ✅ All namespaces created
- ✅ Namespaces visible in `kubectl get ns`

---

### 📋 EXECUTION LOG - Phase 2

**Date:** 2025-12-29
**Status:** ✅ COMPLETED

**Summary of Implementation:**
- Created kind configuration file with multi-node setup (1 control-plane + 2 workers)
- Deployed kind cluster "precinct-99" successfully
- Configured port mappings for Frontend (3000), Backend (8000), OpenBao UI (8200)
- Created all required namespaces: spire-system, openbao, 99-apps

**Cluster Details:**
- Cluster Name: precinct-99
- Kubernetes Version: v1.34.0
- Nodes: 3 nodes (precinct-99-control-plane, precinct-99-worker, precinct-99-worker2)
- Node Status: NotReady (expected - CNI not yet installed, will be resolved in Phase 6)
- Control Plane Components: All Running (etcd, apiserver, controller-manager, scheduler)
- Namespaces: spire-system, openbao, 99-apps (all Active)

**Issues Faced:**
- None

**Important Decisions/Changes:**
- Nodes showing "NotReady" is expected behavior since we disabled default CNI
- Cilium will be installed in Phase 6 to provide CNI functionality
- CoreDNS pods are Pending (expected without CNI)

**Next Phase:** Phase 3 - SPIRE Deployment

---

## 🔐 Phase 3: SPIRE Deployment

**Objective:** Deploy SPIRE server and agent to provide workload identity infrastructure.

**Reference:** https://spiffe.io/docs/latest/try/getting-started-k8s/

**Note:** For production deployments, consider using the official SPIRE Helm chart: https://github.com/spiffe/helm-charts-hardened

### **Tasks:**

#### **Task 3.1: Create SPIRE Server ServiceAccount and RBAC**

**Description:** Create ServiceAccount, ClusterRole, and ClusterRoleBinding for SPIRE server.

**File:** `infrastructure/spire/server-account.yaml`

**Content:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: spire-server
  namespace: spire-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: spire-server-cluster-role
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  - apiGroups: ["authentication.k8s.io"]
    resources: ["tokenreviews"]
    verbs: ["create"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: spire-server-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: spire-server-cluster-role
subjects:
  - kind: ServiceAccount
    name: spire-server
    namespace: spire-system
```

**Apply:**
```bash
kubectl apply -f infrastructure/spire/server-account.yaml
```

**Success Criteria:**
- ✅ ServiceAccount created in `spire-system`
- ✅ ClusterRole and binding created

---

#### **Task 3.2: Create SPIRE Server ConfigMap**

**Description:** Configure SPIRE server with trust domain and plugins.

**File:** `infrastructure/spire/server-configmap.yaml`

**Content:**
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
              service_account_allow_list = ["spire-system:spire-agent"]
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
        plugin_data {}
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

**Key Configuration Points:**
- **Trust Domain:** `demo.local` (matches our architecture)
- **Node Attestor:** `k8s_psat` (Projected Service Account Token)
- **Data Store:** SQLite (simple for demo)
- **Health Checks:** Enabled for liveness/readiness probes

**Apply:**
```bash
kubectl apply -f infrastructure/spire/server-configmap.yaml
```

**Success Criteria:**
- ✅ ConfigMap created in `spire-system`
- ✅ Configuration is valid

---

#### **Task 3.3: Create SPIRE Server StatefulSet**

**Description:** Deploy SPIRE server as a StatefulSet with persistent storage.

**File:** `infrastructure/spire/server-statefulset.yaml`

**Content:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: spire-server
  namespace: spire-system
  labels:
    app: spire-server
spec:
  serviceName: spire-server
  replicas: 1
  selector:
    matchLabels:
      app: spire-server
  template:
    metadata:
      labels:
        app: spire-server
    spec:
      serviceAccountName: spire-server
      containers:
        - name: spire-server
          image: ghcr.io/spiffe/spire-server:1.9.6
          args:
            - -config
            - /run/spire/config/server.conf
          ports:
            - containerPort: 8081
              name: grpc
              protocol: TCP
            - containerPort: 8080
              name: health
              protocol: TCP
          volumeMounts:
            - name: spire-config
              mountPath: /run/spire/config
              readOnly: true
            - name: spire-data
              mountPath: /run/spire/data
          livenessProbe:
            httpGet:
              path: /live
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: spire-config
          configMap:
            name: spire-server
  volumeClaimTemplates:
    - metadata:
        name: spire-data
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
```

**Apply:**
```bash
kubectl apply -f infrastructure/spire/server-statefulset.yaml
```

**Success Criteria:**
- ✅ StatefulSet created
- ✅ PVC automatically created
- ✅ Pod starting (may take 30-60 seconds)

---

#### **Task 3.4: Create SPIRE Server Service**

**Description:** Expose SPIRE server for agent communication.

**File:** `infrastructure/spire/server-service.yaml`

**Content:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: spire-server
  namespace: spire-system
spec:
  type: ClusterIP
  ports:
    - name: grpc
      port: 8081
      targetPort: 8081
      protocol: TCP
  selector:
    app: spire-server
```

**Apply:**
```bash
kubectl apply -f infrastructure/spire/server-service.yaml
```

**Success Criteria:**
- ✅ Service created
- ✅ Service has ClusterIP assigned

---

#### **Task 3.5: Verify SPIRE Server Health**

**Description:** Verify that SPIRE server is running and healthy.

**Commands:**
```bash
# Check pod status
kubectl get pods -n spire-system -l app=spire-server

# Check logs
kubectl logs -n spire-system spire-server-0 --tail=50

# Check server health
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server healthcheck
```

**Expected Output:**
```
Server is healthy.
```

**Success Criteria:**
- ✅ Pod is Running
- ✅ Health check passes
- ✅ No critical errors in logs

---

#### **Task 3.6: Create SPIRE Agent ServiceAccount and RBAC**

**Description:** Create ServiceAccount and RBAC for SPIRE agent.

**File:** `infrastructure/spire/agent-account.yaml`

**Content:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: spire-agent
  namespace: spire-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: spire-agent-cluster-role
rules:
  - apiGroups: [""]
    resources: ["pods", "nodes"]
    verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: spire-agent-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: spire-agent-cluster-role
subjects:
  - kind: ServiceAccount
    name: spire-agent
    namespace: spire-system
```

**Apply:**
```bash
kubectl apply -f infrastructure/spire/agent-account.yaml
```

**Success Criteria:**
- ✅ ServiceAccount created
- ✅ ClusterRole and binding created

---

#### **Task 3.7: Create SPIRE Agent ConfigMap**

**Description:** Configure SPIRE agent to connect to server.

**File:** `infrastructure/spire/agent-configmap.yaml`

**Content:**
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

**Apply:**
```bash
kubectl apply -f infrastructure/spire/agent-configmap.yaml
```

**Success Criteria:**
- ✅ ConfigMap created

---

#### **Task 3.8: Create SPIRE Agent DaemonSet**

**Description:** Deploy SPIRE agent as DaemonSet (one per node).

**File:** `infrastructure/spire/agent-daemonset.yaml`

**Content:**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: spire-agent
  namespace: spire-system
  labels:
    app: spire-agent
spec:
  selector:
    matchLabels:
      app: spire-agent
  template:
    metadata:
      labels:
        app: spire-agent
    spec:
      serviceAccountName: spire-agent
      hostPID: true
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      initContainers:
        - name: init
          image: ghcr.io/spiffe/spire-agent:1.9.6
          command:
            - /bin/sh
            - -c
            - |
              rm -rf /run/spire/sockets/*
          volumeMounts:
            - name: spire-agent-socket
              mountPath: /run/spire/sockets
      containers:
        - name: spire-agent
          image: ghcr.io/spiffe/spire-agent:1.9.6
          args:
            - -config
            - /run/spire/config/agent.conf
          volumeMounts:
            - name: spire-config
              mountPath: /run/spire/config
              readOnly: true
            - name: spire-agent-socket
              mountPath: /run/spire/sockets
            - name: spire-token
              mountPath: /var/run/secrets/tokens
          livenessProbe:
            httpGet:
              path: /live
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: spire-config
          configMap:
            name: spire-agent
        - name: spire-agent-socket
          hostPath:
            path: /run/spire/sockets
            type: DirectoryOrCreate
        - name: spire-token
          projected:
            sources:
              - serviceAccountToken:
                  path: spire-agent
                  expirationSeconds: 7200
                  audience: spire-server
```

**Apply:**
```bash
kubectl apply -f infrastructure/spire/agent-daemonset.yaml
```

**Success Criteria:**
- ✅ DaemonSet created
- ✅ 2 agent pods (one per worker node)
- ✅ Pods in Running state

---

#### **Task 3.9: Verify SPIRE Agent Health**

**Description:** Verify agents are healthy and connected to server.

**Commands:**
```bash
# Check agent pods
kubectl get pods -n spire-system -l app=spire-agent

# Check agent logs
kubectl logs -n spire-system -l app=spire-agent --tail=20

# Verify agents registered with server
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server agent list
```

**Expected Output:**
```
Found 2 attested agents:

SPIFFE ID         : spiffe://demo.local/spire/agent/k8s_psat/...
Attestation type  : k8s_psat
Expiration time   : ...
Serial number     : ...
```

**Success Criteria:**
- ✅ All agent pods Running
- ✅ Agents registered with server
- ✅ No critical errors

**Note:** SPIRE registration entries for workloads will be created in Sub-Sprint 2 (Backend Development) and Sub-Sprint 4 (Integration) when the actual services are deployed.

---

### 📋 EXECUTION LOG - Phase 3 (Partial)

**Date:** 2025-12-29
**Status:** ⏸️ PAUSED - Dependency Issue Discovered

**Summary of Implementation:**
- Created SPIRE Server ServiceAccount, ClusterRole, and ClusterRoleBinding
- Created SPIRE Server ConfigMap with trust domain "demo.local"
- Created SPIRE Server StatefulSet and Service
- Applied all SPIRE server manifests successfully

**Issues Faced:**
- **Critical Dependency Issue:** SPIRE server pod cannot be scheduled
- Pod status: Pending with error "0/3 nodes are available: 2 node(s) had untolerated taint {node.kubernetes.io/not-ready}"
- Worker nodes have `not-ready` taint because CNI (Cilium) is not installed yet
- Cannot proceed with SPIRE Agent deployment without CNI

**Important Decisions/Changes:**
- **Phase Order Change Required:** Phase 6 (Cilium Installation) must be completed BEFORE Phases 3, 4, and 5
- This is a chicken-and-egg problem: no CNI → nodes not ready → pods can't be scheduled
- New recommended order: Phase 1 → Phase 2 → **Phase 6** → Phase 3 → Phase 4 → Phase 5 → Phase 7

**Files Created:**
- infrastructure/spire/server-account.yaml
- infrastructure/spire/server-configmap.yaml
- infrastructure/spire/server-statefulset.yaml
- infrastructure/spire/server-service.yaml

**Next Steps:**
1. Complete Phase 6: Cilium Installation first
2. Once nodes are Ready, resume Phase 3 to complete SPIRE deployment
3. Then proceed with Phase 4 (OpenBao) and Phase 5 (PostgreSQL)

---

## 🔑 Phase 4: OpenBao Deployment

**Objective:** Deploy OpenBao in dev mode for secrets management.

**Reference:** https://openbao.org/docs/

**Note:** For production deployments, consider using Helm charts or the official OpenBao operator. Dev mode (used here) is NOT suitable for production as it uses in-memory storage and is auto-unsealed.

### **Tasks:**

#### **Task 4.1: Create OpenBao Deployment**

**Description:** Deploy OpenBao in dev mode (single instance, in-memory storage).

**File:** `infrastructure/openbao/deployment.yaml`

**Content:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openbao
  namespace: openbao
  labels:
    app: openbao
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openbao
  template:
    metadata:
      labels:
        app: openbao
    spec:
      containers:
        - name: openbao
          image: quay.io/openbao/openbao:2.0.1
          args:
            - server
            - -dev
            - -dev-root-token-id=root
            - -dev-listen-address=0.0.0.0:8200
          ports:
            - containerPort: 8200
              name: http
              protocol: TCP
          env:
            - name: BAO_DEV_ROOT_TOKEN_ID
              value: "root"
            - name: BAO_ADDR
              value: "http://0.0.0.0:8200"
            - name: BAO_LOG_LEVEL
              value: "debug"
          readinessProbe:
            httpGet:
              path: /v1/sys/health
              port: 8200
              scheme: HTTP
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /v1/sys/health
              port: 8200
              scheme: HTTP
            initialDelaySeconds: 15
            periodSeconds: 20
```

**Important Notes:**
- **Dev Mode:** NOT for production! In-memory storage, auto-unsealed, root token = "root"
- **Root Token:** Hardcoded as "root" for demo convenience
- **Auto-Unsealed:** No manual unseal required in dev mode

**Apply:**
```bash
kubectl apply -f infrastructure/openbao/deployment.yaml
```

**Success Criteria:**
- ✅ Deployment created
- ✅ Pod starting

---

#### **Task 4.2: Create OpenBao Service**

**Description:** Expose OpenBao via ClusterIP and NodePort (for UI access).

**File:** `infrastructure/openbao/service.yaml`

**Content:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: openbao
  namespace: openbao
spec:
  type: NodePort
  ports:
    - name: http
      port: 8200
      targetPort: 8200
      nodePort: 30002
      protocol: TCP
  selector:
    app: openbao
```

**Apply:**
```bash
kubectl apply -f infrastructure/openbao/service.yaml
```

**Success Criteria:**
- ✅ Service created
- ✅ NodePort 30002 assigned

---

#### **Task 4.3: Verify OpenBao Access**

**Description:** Verify OpenBao is accessible and responding.

**Commands:**
```bash
# Check pod status
kubectl get pods -n openbao

# Check logs
kubectl logs -n openbao -l app=openbao --tail=30

# Test API access (from within cluster)
kubectl run curl-test --image=curlimages/curl:latest --rm -it --restart=Never -- \
  curl -s http://openbao.openbao.svc.cluster.local:8200/v1/sys/health | jq

# Test from localhost
curl -s http://localhost:8200/v1/sys/health | jq
```

**Expected Output:**
```json
{
  "initialized": true,
  "sealed": false,
  "standby": false,
  ...
}
```

**Success Criteria:**
- ✅ OpenBao pod Running
- ✅ API responding on port 8200
- ✅ Health check returns `initialized: true, sealed: false`
- ✅ UI accessible at http://localhost:8200 (login with token "root")

---

#### **Task 4.4: Initialize OpenBao for Demo (Dev Mode)**

**Description:** In dev mode, OpenBao is already initialized. Verify basic functionality.

**Commands:**
```bash
# Set environment variables for bao CLI (if installed locally)
export BAO_ADDR='http://localhost:8200'
export BAO_TOKEN='root'

# Or use kubectl exec
kubectl exec -n openbao deploy/openbao -- bao status

# Enable KV v2 secrets engine (if not already enabled in dev mode)
kubectl exec -n openbao deploy/openbao -- \
  bao secrets enable -version=2 -path=secret kv || true

# Test write/read
kubectl exec -n openbao deploy/openbao -- \
  bao kv put secret/test message="Hello from OpenBao"

kubectl exec -n openbao deploy/openbao -- \
  bao kv get secret/test
```

**Success Criteria:**
- ✅ OpenBao status shows unsealed
- ✅ Can write and read secrets

---

## 🐘 Phase 5: PostgreSQL Deployment

**Objective:** Deploy PostgreSQL with application schema and Brooklyn Nine-Nine demo users.

**Note:** For production, consider:
- Using managed PostgreSQL (cloud provider)
- Or PostgreSQL Helm chart (e.g., Bitnami) with proper backups, HA, monitoring
- Creating a dedicated OpenBao database admin user (not postgres superuser)
- Configuring proper resource limits and storage classes

### **Tasks:**

#### **Task 5.1: Create PostgreSQL StatefulSet**

**Description:** Deploy PostgreSQL as a StatefulSet with persistent storage.

**File:** `infrastructure/postgres/statefulset.yaml`

**Content:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: 99-apps
  labels:
    app: postgresql
spec:
  serviceName: postgresql
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
        - name: postgresql
          image: postgres:15-alpine
          ports:
            - containerPort: 5432
              name: postgres
          env:
            - name: POSTGRES_DB
              value: "appdb"
            - name: POSTGRES_USER
              value: "postgres"
            - name: POSTGRES_PASSWORD
              value: "postgres"
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
            - name: init-scripts
              mountPath: /docker-entrypoint-initdb.d
          livenessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - postgres
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - postgres
            initialDelaySeconds: 5
            periodSeconds: 5
      volumes:
        - name: init-scripts
          configMap:
            name: postgres-init-script
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
```

**Success Criteria:**
- ✅ Manifest created

---

#### **Task 5.2: Create Database Initialization Script**

**Description:** Create SQL script to initialize schema and seed demo users.

**File:** `infrastructure/postgres/init-db.sql`

**Content:**
```sql
-- Database initialization script for SPIRE-Vault-99 demo
-- Brooklyn Nine-Nine themed user data

-- Enable password encryption
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Users table (stores user accounts)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- GitHub integration metadata
CREATE TABLE IF NOT EXISTS github_integrations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    is_configured BOOLEAN DEFAULT FALSE,
    configured_at TIMESTAMP,
    last_accessed TIMESTAMP,
    UNIQUE(user_id)
);

-- Audit log (optional - for demo purposes)
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource VARCHAR(100),
    timestamp TIMESTAMP DEFAULT NOW(),
    details JSONB
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_github_integrations_user_id ON github_integrations(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON audit_log(timestamp DESC);

-- Seed demo users (Brooklyn Nine-Nine characters)
-- Passwords are bcrypt hashed with cost factor 12
-- Password format: <username>99 (e.g., jake99, amy99, etc.)
-- Generated with: python3 -c "import bcrypt; print(bcrypt.hashpw(b'jake99', bcrypt.gensalt(12)).decode())"

INSERT INTO users (username, email, password_hash) VALUES
  ('jake', 'jake.peralta@99.precinct', '$2b$12$ynvd/p1hHWdM3MwBpv6Xh.kEN4vU9KCBZYUIkXLRyaX5o.ArCoyzi'),
  ('amy', 'amy.santiago@99.precinct', '$2b$12$kUQXIo3KUl0munUJfwVcSOKXwlzJYC33DBBlAF6TbFFWVraRlkiv2'),
  ('rosa', 'rosa.diaz@99.precinct', '$2b$12$.8rTuqEY.hemd08NXDG31eGi3A8J6kbPWMgz1pKdxG4/PGQsbxaS2'),
  ('terry', 'terry.jeffords@99.precinct', '$2b$12$cfbURIWuw5/OKTNR4nAMyOF/sxMotsDDQwh/OXIo2ZEG07xtyPJju'),
  ('charles', 'charles.boyle@99.precinct', '$2b$12$PWxz4OBsyV4vW5ixnTJz5.E.Zn9rPDk.wnkL4/CJQpMbHLsBgLNdS'),
  ('gina', 'gina.linetti@99.precinct', '$2b$12$jqLkaxLiPyYaMGvH705LQu9meczkpsLnJz8/xhjxyISUBHAXJxPXW')
ON CONFLICT (username) DO NOTHING;

-- Log the initialization
DO $$
BEGIN
    RAISE NOTICE 'Database initialized successfully!';
    RAISE NOTICE 'Demo users created: jake, amy, rosa, terry, charles, gina';
    RAISE NOTICE 'Password format: <username>99 (e.g., jake99)';
END $$;
```

**Note:**
- These are REAL bcrypt hashes for demo passwords (username99 pattern)
- For production, use higher cost factor (14+) and enforce strong password policies
- For production, create a dedicated OpenBao admin user instead of using postgres superuser

**Success Criteria:**
- ✅ SQL file created

---

#### **Task 5.3: Create PostgreSQL Init Script ConfigMap**

**Description:** Create ConfigMap YAML manifest containing the initialization script. This approach is better for GitOps and version control compared to `kubectl create configmap`.

**File:** `infrastructure/postgres/init-configmap.yaml`

**Content:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init-script
  namespace: 99-apps
data:
  init-db.sql: |
    -- Database initialization script for SPIRE-Vault-99 demo
    -- Brooklyn Nine-Nine themed user data

    -- Enable password encryption
    CREATE EXTENSION IF NOT EXISTS pgcrypto;

    -- Users table (stores user accounts)
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        email VARCHAR(100) UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
    );

    -- GitHub integration metadata
    CREATE TABLE IF NOT EXISTS github_integrations (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        is_configured BOOLEAN DEFAULT FALSE,
        configured_at TIMESTAMP,
        last_accessed TIMESTAMP,
        UNIQUE(user_id)
    );

    -- Audit log (optional - for demo purposes)
    CREATE TABLE IF NOT EXISTS audit_log (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        action VARCHAR(100) NOT NULL,
        resource VARCHAR(100),
        timestamp TIMESTAMP DEFAULT NOW(),
        details JSONB
    );

    -- Indexes for performance
    CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
    CREATE INDEX IF NOT EXISTS idx_github_integrations_user_id ON github_integrations(user_id);
    CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON audit_log(timestamp DESC);

    -- Seed demo users (Brooklyn Nine-Nine characters)
    -- Passwords are bcrypt hashed with cost factor 12
    -- Password format: <username>99 (e.g., jake99, amy99, etc.)

    INSERT INTO users (username, email, password_hash) VALUES
      ('jake', 'jake.peralta@99.precinct', '$2b$12$ynvd/p1hHWdM3MwBpv6Xh.kEN4vU9KCBZYUIkXLRyaX5o.ArCoyzi'),
      ('amy', 'amy.santiago@99.precinct', '$2b$12$kUQXIo3KUl0munUJfwVcSOKXwlzJYC33DBBlAF6TbFFWVraRlkiv2'),
      ('rosa', 'rosa.diaz@99.precinct', '$2b$12$.8rTuqEY.hemd08NXDG31eGi3A8J6kbPWMgz1pKdxG4/PGQsbxaS2'),
      ('terry', 'terry.jeffords@99.precinct', '$2b$12$cfbURIWuw5/OKTNR4nAMyOF/sxMotsDDQwh/OXIo2ZEG07xtyPJju'),
      ('charles', 'charles.boyle@99.precinct', '$2b$12$PWxz4OBsyV4vW5ixnTJz5.E.Zn9rPDk.wnkL4/CJQpMbHLsBgLNdS'),
      ('gina', 'gina.linetti@99.precinct', '$2b$12$jqLkaxLiPyYaMGvH705LQu9meczkpsLnJz8/xhjxyISUBHAXJxPXW')
    ON CONFLICT (username) DO NOTHING;

    -- Log the initialization
    DO $$
    BEGIN
        RAISE NOTICE 'Database initialized successfully!';
        RAISE NOTICE 'Demo users created: jake, amy, rosa, terry, charles, gina';
        RAISE NOTICE 'Password format: <username>99 (e.g., jake99)';
    END $$;
```

**Apply:**
```bash
kubectl apply -f infrastructure/postgres/init-configmap.yaml
```

**Success Criteria:**
- ✅ ConfigMap created in `99-apps` namespace
- ✅ YAML manifest committed to version control

---

#### **Task 5.4: Create PostgreSQL Service**

**Description:** Expose PostgreSQL within the cluster.

**File:** `infrastructure/postgres/service.yaml`

**Content:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: 99-apps
spec:
  type: ClusterIP
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
      protocol: TCP
  selector:
    app: postgresql
```

**Apply:**
```bash
kubectl apply -f infrastructure/postgres/service.yaml
```

**Success Criteria:**
- ✅ Service created

---

#### **Task 5.5: Deploy PostgreSQL**

**Description:** Deploy PostgreSQL StatefulSet.

**Commands:**
```bash
kubectl apply -f infrastructure/postgres/statefulset.yaml

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/postgresql-0 -n 99-apps --timeout=300s
```

**Success Criteria:**
- ✅ Pod running
- ✅ PVC created and bound
- ✅ Initialization script executed

---

#### **Task 5.6: Verify PostgreSQL and Demo Users**

**Description:** Verify PostgreSQL is running and demo users are seeded.

**Commands:**
```bash
# Check pod status
kubectl get pods -n 99-apps

# Check logs for initialization
kubectl logs -n 99-apps postgresql-0 | grep "database system is ready"

# Connect to PostgreSQL and verify users
kubectl exec -it -n 99-apps postgresql-0 -- \
  psql -U postgres -d appdb -c "SELECT username, email FROM users;"
```

**Expected Output:**
```
 username |            email
----------+-----------------------------
 jake     | jake.peralta@99.precinct
 amy      | amy.santiago@99.precinct
 rosa     | rosa.diaz@99.precinct
 terry    | terry.jeffords@99.precinct
 charles  | charles.boyle@99.precinct
 gina     | gina.linetti@99.precinct
(6 rows)
```

**Test Login (verify password hashing works):**
```bash
# This will be tested properly in Sprint 2 with backend
# For now, just verify the table structure
kubectl exec -it -n 99-apps postgresql-0 -- \
  psql -U postgres -d appdb -c "\d users"
```

**Success Criteria:**
- ✅ PostgreSQL running and healthy
- ✅ Database `appdb` created
- ✅ All tables created (users, github_integrations, audit_log)
- ✅ 6 demo users seeded
- ✅ Password hashes stored correctly

---

## 🌐 Phase 6: Cilium Installation

**Objective:** Install Cilium service mesh using Helm (basic mode, SPIRE integration in Sprint 4).

**Reference:** https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/

### **Tasks:**

#### **Task 6.1: Install Cilium CLI**

**Description:** Install Cilium CLI tool for easier management.

**Commands:**
```bash
# Download and install Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64

curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Verify installation
cilium version --client
```

**Success Criteria:**
- ✅ Cilium CLI installed
- ✅ Version command works

---

#### **Task 6.2: Create Cilium Helm Values File**

**Description:** Create Helm values file for Cilium installation (basic mode).

**File:** `infrastructure/cilium/values.yaml`

**Content:**
```yaml
# Cilium Helm values for SPIRE-Vault-99 demo
# Basic installation (SPIRE integration will be added in Sprint 4)

# Operator configuration
operator:
  replicas: 1

# Enable Hubble for observability
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true

# IPv4 settings
ipam:
  mode: kubernetes

# Enable local redirect policy
localRedirectPolicy: true

# Kubernetes configuration
k8sServiceHost: precinct-99-control-plane
k8sServicePort: 6443

# Monitoring
prometheus:
  enabled: false

# Encryption (for future use)
encryption:
  enabled: false
  type: wireguard

# Security Identity Allocation
identityAllocationMode: crd

# Cilium Agent
image:
  pullPolicy: IfNotPresent

# Enable policy enforcement
policyEnforcementMode: default

# Note: SPIRE integration will be added in Sprint 4
# authentication:
#   mutual:
#     spire:
#       enabled: true
#       install:
#         enabled: false
```

**Success Criteria:**
- ✅ Values file created

---

#### **Task 6.3: Install Cilium Using Helm**

**Description:** Deploy Cilium to the cluster.

**Commands:**
```bash
# Add Cilium Helm repository
helm repo add cilium https://helm.cilium.io/
helm repo update

# Install Cilium
helm install cilium cilium/cilium \
  --version 1.15.7 \
  --namespace kube-system \
  --values infrastructure/cilium/values.yaml

# Wait for Cilium to be ready
kubectl wait --for=condition=Ready pods -n kube-system -l k8s-app=cilium --timeout=300s
```

**Success Criteria:**
- ✅ Cilium installed successfully
- ✅ Cilium pods running in kube-system

---

#### **Task 6.4: Verify Cilium Installation**

**Description:** Verify Cilium is functioning correctly.

**Commands:**
```bash
# Check Cilium status
cilium status --wait

# Run connectivity test (optional, takes a few minutes)
cilium connectivity test --test-concurrency 1
```

**Expected Output:**
```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:         OK
 \__/¯¯\__/    Operator:       OK
 /¯¯\__/¯¯\    Hubble:         OK
 \__/¯¯\__/    ClusterMesh:    disabled
    \__/

Deployment        cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
DaemonSet         cilium             Desired: 3, Ready: 3/3, Available: 3/3
Containers:       cilium             Running: 3
                  cilium-operator    Running: 1
Cluster Pods:     3/3 managed by Cilium
```

**Success Criteria:**
- ✅ Cilium status shows all components OK
- ✅ All Cilium pods running
- ✅ Connectivity test passes (if run)

---

#### **Task 6.5: Enable Hubble UI (Optional)**

**Description:** Port-forward Hubble UI for network observability.

**Commands:**
```bash
# Port-forward Hubble UI
cilium hubble ui

# This will open http://localhost:12000 in your browser
```

**Success Criteria:**
- ✅ Hubble UI accessible
- ✅ Can see network flows (will be minimal until apps are deployed)

---

### 📋 EXECUTION LOG - Phase 6

**Date:** 2025-12-29
**Status:** ✅ COMPLETED

**Summary of Implementation:**
- Downloaded and extracted Cilium CLI v0.18.9 locally
- Created Cilium Helm values file (basic mode, SPIRE integration deferred to Sprint 4)
- Installed Cilium v1.15.7 via Helm to kube-system namespace
- All Cilium core components deployed successfully
- **Critical Success:** All 3 nodes transitioned from NotReady → Ready after Cilium installation

**Cilium Components Status:**
- Cilium DaemonSet: 3/3 Ready (one per node)
- Cilium Operator: 1/1 Ready
- Hubble Relay: Pending (optional observability component)
- Hubble UI: Pending (optional observability component)
- **Core CNI Functionality:** ✅ Working (6/6 cluster pods managed by Cilium)

**Issues Faced:**
- **Root Cause Identified:** Phase 6 should have been executed BEFORE Phases 3, 4, 5
- Worker nodes had `node.kubernetes.io/not-ready` taint without CNI
- SPIRE/OpenBao/PostgreSQL pods could not be scheduled without CNI
- Hubble Relay and UI pods remain Pending (not critical - these are optional observability components)

**Important Decisions/Changes:**
- **Corrected Phase Order:** The actual implementation order is Phase 1 → 2 → **6** → 3 → 4 → 5 → 7
- Reason: CNI must be installed before application workloads can be scheduled on worker nodes
- Hubble components are optional and will not block progress
- Can now proceed to complete paused phases (3, 4, 5) as nodes are Ready

**Files Created:**
- infrastructure/cilium/values.yaml

**Next Steps:**
1. Resume Phase 3: Complete SPIRE Server and Agent deployment
2. Then proceed with Phase 4: OpenBao
3. Then proceed with Phase 5: PostgreSQL
4. Finally Phase 7: Integration verification

---

## ✅ Phase 7: Integration Verification & Testing

**Objective:** Verify all infrastructure components are healthy and can communicate.

### **Tasks:**

#### **Task 7.1: Verify All Pods Are Running**

**Description:** Check that all infrastructure pods are in Running state.

**Commands:**
```bash
# Check all namespaces
kubectl get pods --all-namespaces

# Check specific namespaces
kubectl get pods -n spire-system
kubectl get pods -n openbao
kubectl get pods -n 99-apps
kubectl get pods -n kube-system | grep cilium
```

**Expected State:**
- ✅ SPIRE server: 1/1 Running
- ✅ SPIRE agent: 2/2 Running (DaemonSet on 2 worker nodes)
- ✅ OpenBao: 1/1 Running
- ✅ PostgreSQL: 1/1 Running
- ✅ Cilium: 3/3 Running (DaemonSet on all 3 nodes)
- ✅ Cilium operator: 1/1 Running
- ✅ Hubble relay: 1/1 Running (if enabled)

**Success Criteria:**
- ✅ All pods in Running state
- ✅ No CrashLoopBackOff or Error states
- ✅ All PVCs bound

---

#### **Task 7.2: Test SPIRE SVID Issuance**

**Description:** Verify SPIRE can issue SVIDs to workloads.

**Commands:**
```bash
# List registered agents
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server agent list

# List registration entries
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show

# Check SPIRE server logs
kubectl logs -n spire-system spire-server-0 --tail=50
```

**Success Criteria:**
- ✅ Agents registered
- ✅ At least one test entry exists
- ✅ No critical errors in logs

---

#### **Task 7.3: Test OpenBao Accessibility**

**Description:** Verify OpenBao is accessible and can store/retrieve secrets.

**Commands:**
```bash
# Test from within cluster
kubectl run bao-test --image=quay.io/openbao/openbao:2.0.0 --rm -it --restart=Never -- \
  bao kv put -address=http://openbao.openbao.svc.cluster.local:8200 \
    -header="X-Vault-Token: root" \
    secret/test/hello message="Hello from cluster"

kubectl run bao-test --image=quay.io/openbao/openbao:2.0.0 --rm -it --restart=Never -- \
  bao kv get -address=http://openbao.openbao.svc.cluster.local:8200 \
    -header="X-Vault-Token: root" \
    secret/test/hello

# Test from localhost
curl -H "X-Vault-Token: root" http://localhost:8200/v1/sys/health | jq
```

**Success Criteria:**
- ✅ Can write secrets
- ✅ Can read secrets
- ✅ API accessible from cluster and localhost

---

#### **Task 7.4: Test PostgreSQL Connectivity**

**Description:** Verify PostgreSQL is accessible and data is correct.

**Commands:**
```bash
# Test connection from within cluster
kubectl run psql-test --image=postgres:15-alpine --rm -it --restart=Never -- \
  psql -h postgresql.99-apps.svc.cluster.local -U postgres -d appdb -c "SELECT COUNT(*) FROM users;"

# Expected output: 6 rows

# Verify all demo users
kubectl exec -it -n 99-apps postgresql-0 -- \
  psql -U postgres -d appdb -c "SELECT username, email FROM users ORDER BY id;"
```

**Success Criteria:**
- ✅ Can connect to PostgreSQL
- ✅ 6 demo users exist
- ✅ All tables created correctly

---

#### **Task 7.5: Test Network Connectivity (Cilium)**

**Description:** Verify Cilium is providing network connectivity between pods.

**Commands:**
```bash
# Test pod-to-pod connectivity
kubectl run curl-test --image=curlimages/curl:latest --rm -it --restart=Never -- \
  curl -s http://openbao.openbao.svc.cluster.local:8200/v1/sys/health

# Check Cilium endpoints
cilium endpoint list

# View network flows in Hubble (if UI is running)
cilium hubble observe --follow
```

**Success Criteria:**
- ✅ Pod-to-pod communication works
- ✅ Service DNS resolution works
- ✅ Cilium endpoints show healthy status

---

#### **Task 7.6: Verify Port Forwarding for Local Access**

**Description:** Verify localhost can access services via kind port mappings.

**Commands:**
```bash
# Test OpenBao UI
curl -s http://localhost:8200/v1/sys/health | jq

# Open in browser
# http://localhost:8200 (OpenBao UI - login with token "root")
```

**Expected:**
- ✅ OpenBao UI accessible at http://localhost:8200
- ✅ Can login with token "root"

**Success Criteria:**
- ✅ All localhost URLs responding
- ✅ Port mappings working correctly

---

#### **Task 7.7: Create Infrastructure Verification Script**

**Description:** Create a helper script to verify all infrastructure is healthy.

**File:** `scripts/helpers/verify-infrastructure.sh`

**Content:**
```bash
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

# Check OpenBao health
echo "🔑 Checking OpenBao health..."
curl -s http://localhost:8200/v1/sys/health | jq -r '"  Status: \(.initialized), Sealed: \(.sealed)"'
echo ""

# Check PostgreSQL
echo "🐘 Checking PostgreSQL..."
kubectl exec -n 99-apps postgresql-0 -- \
  psql -U postgres -d appdb -c "SELECT COUNT(*) as user_count FROM users;" -t
echo "  Demo users seeded ✓"
echo ""

# Check Cilium
echo "🌐 Checking Cilium..."
cilium status --brief
echo ""

echo -e "${GREEN}✅ Infrastructure verification complete!${NC}"
```

**Make executable:**
```bash
chmod +x scripts/helpers/verify-infrastructure.sh
```

**Run:**
```bash
./scripts/helpers/verify-infrastructure.sh
```

**Success Criteria:**
- ✅ Script runs without errors
- ✅ All checks pass

---

#### **Task 7.8: Document Known Issues and Troubleshooting**

**Description:** Document any issues encountered and their solutions.

**File:** `docs/TROUBLESHOOTING.md` (create if issues arise)

**Common Issues:**
1. **Cilium pods not starting:** Check that default CNI is disabled in kind config
2. **SPIRE agents not connecting:** Verify server service is accessible
3. **PostgreSQL init script not running:** Check ConfigMap is mounted correctly
4. **OpenBao health check failing:** Verify dev mode args are correct

**Success Criteria:**
- ✅ Issues documented
- ✅ Solutions provided

---

## 📊 Phase 7 Completion Checklist

**Infrastructure Health:**
- [ ] All pods Running (SPIRE, OpenBao, PostgreSQL, Cilium)
- [ ] All PVCs Bound
- [ ] All services have ClusterIP assigned

**SPIRE Verification:**
- [ ] SPIRE server healthy
- [ ] SPIRE agents registered (2 agents)
- [ ] Can create registration entries
- [ ] Test entry created for backend service

**OpenBao Verification:**
- [ ] OpenBao unsealed and initialized
- [ ] Can write/read secrets via API
- [ ] UI accessible at http://localhost:8200
- [ ] Can login with token "root"

**PostgreSQL Verification:**
- [ ] Database `appdb` created
- [ ] All tables exist (users, github_integrations, audit_log)
- [ ] 6 demo users seeded correctly
- [ ] Can query database from within cluster

**Cilium Verification:**
- [ ] Cilium status shows OK
- [ ] All Cilium pods running
- [ ] Hubble enabled (optional)
- [ ] Basic connectivity working

**Network Verification:**
- [ ] Pod-to-pod communication works
- [ ] Service DNS resolution works
- [ ] Localhost can access OpenBao UI (port 8200)

---

## 🎯 Sub-Sprint 1 Success Criteria

The infrastructure foundation is complete when:

- ✅ Multi-node kind cluster deployed (1 control + 2 workers)
- ✅ All namespaces created (spire-system, openbao, 99-apps)
- ✅ SPIRE server and agents deployed and healthy
- ✅ SPIRE issuing SVIDs (test entry verified)
- ✅ OpenBao deployed and accessible (dev mode)
- ✅ PostgreSQL deployed with schema and demo users
- ✅ Cilium installed and providing network connectivity
- ✅ All services accessible (API + UI where applicable)
- ✅ Verification script passes all checks
- ✅ No critical errors in any component logs

---

## 📝 Next Steps

After completing Sub-Sprint 1:

1. **Commit infrastructure manifests** to git
2. **Proceed to Sub-Sprint 2:** Backend Application Development
3. **Reference:** The backend will use this infrastructure to:
   - Get SPIRE SVIDs from the agent
   - Authenticate to OpenBao using certificates
   - Access PostgreSQL for user authentication
   - Store/retrieve GitHub tokens in OpenBao

---

## 🔗 References

- **SPIRE Kubernetes Quickstart:** https://spiffe.io/docs/latest/try/getting-started-k8s/
- **OpenBao Documentation:** https://openbao.org/docs/
- **Cilium Installation Guide:** https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
- **kind Documentation:** https://kind.sigs.k8s.io/docs/user/quick-start/
- **PostgreSQL Docker Image:** https://hub.docker.com/_/postgres

---

**Document Version:** 1.1
**Last Updated:** 2025-12-29
**Status:** ✅ Ready for Implementation
**Prerequisite:** Master Sprint (docs/MASTER_SPRINT.md)
**Next:** Sub-Sprint 2 - Backend Development

**Changelog:**
- v1.1 (2025-12-29):
  - Updated cluster name to `precinct-99` (Brooklyn Nine-Nine theme)
  - Added real bcrypt password hashes for demo users
  - Updated to latest versions (SPIRE 1.9.6, OpenBao 2.0.1, Cilium 1.15.7)
  - Changed ConfigMap creation to YAML manifest approach (GitOps best practice)
  - Added production deployment notes for SPIRE, OpenBao, PostgreSQL
  - Removed Task 3.10 (SPIRE test registration) - will be done in Sprint 2/4
- v1.0 (2025-12-29): Initial version

---

**End of Sub-Sprint 1: Infrastructure Foundation**
