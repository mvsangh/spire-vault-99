# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SPIRE-Vault-99 is a zero-trust security platform demonstrating production-grade workload identity, secrets management, and service mesh integration on Kubernetes. The project uses a Brooklyn Nine-Nine theme for demo data.

**Key Technologies:**
- SPIRE/SPIFFE - Workload identity (X.509-SVID with 1-hour TTL)
- OpenBao - Secrets management (static + dynamic)
- Cilium - Service mesh with SPIFFE-based network policies
- Kubernetes (kind) - Local cluster named "precinct-99"
- PostgreSQL - Database with dynamic credentials
- Next.js + FastAPI - Full-stack demo application (planned)

**Trust Domain:** `spiffe://demo.local`

## Common Commands

### Cluster Management

```bash
# Create cluster
kind create cluster --config infrastructure/kind/kind-config.yaml

# Delete cluster
kind delete cluster --name precinct-99

# Verify infrastructure health
./scripts/helpers/verify-infrastructure.sh
```

### Component Access

```bash
# SPIRE server health check
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server healthcheck

# List SPIRE agents
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server agent list

# List SPIRE registration entries
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show

# OpenBao status
kubectl exec -n openbao deploy/openbao -- bao status

# PostgreSQL console
kubectl exec -it -n 99-apps postgresql-0 -- \
  psql -U postgres -d appdb

# Cilium status
cilium status
```

### Service Endpoints

- **OpenBao UI:** http://localhost:8200 (login token: "root")
- **Frontend:** http://localhost:3000 (planned)
- **Backend API:** http://localhost:8000 (planned)

## Architecture

### Component Distribution

**Namespaces:**
- `spire-system` - SPIRE server + agent DaemonSet
- `openbao` - OpenBao (supports dev mode HTTP or production TLS)
- `99-apps` - PostgreSQL + Backend + Frontend
- `kube-system` - Cilium CNI

**Cluster:**
- 1 control-plane node: `precinct-99-control-plane`
- 2 worker nodes: `precinct-99-worker`, `precinct-99-worker2`

### Workload Identity Flow

1. **Backend Startup:** Obtains X.509-SVID from SPIRE agent (via Unix socket at `/run/spire/sockets/agent.sock`)
2. **Vault Authentication:** Authenticates to OpenBao using SPIRE certificate (mTLS)
3. **Database Credentials:** Requests dynamic PostgreSQL credentials from OpenBao
4. **Connection Pool:** Creates connection pool with Vault-issued credentials
5. **Credential Rotation:** Background task rotates credentials every 50 minutes (before 1-hour TTL)

### Database Connection Strategy

The backend uses **connection pooling with periodic credential rotation** (best practice):
- Initial credentials requested at startup
- Connection pool (10-20 connections) created with dynamic credentials
- Background task rotates credentials every 50 minutes
- Graceful migration to new pool with zero downtime
- OpenBao creates temporary PostgreSQL users (format: `v-token-backend-<uuid>`)

**NOT per-request credential fetching** - this would be inefficient and is not the design.

### SPIRE Trust Bundle Distribution

The project uses the **official best practice** for trust bundle distribution:
- SPIRE server has `k8sbundle` notifier enabled
- Server populates `spire-bundle` ConfigMap in `spire-system` namespace
- Agents mount this ConfigMap and use `trust_bundle_path` configuration
- **Does NOT use `insecure_bootstrap`** - this is a security anti-pattern

## Database Schema

**Demo Users (Brooklyn Nine-Nine theme):**
- Username format: First name (lowercase)
- Password format: `<username>-precinct99` (e.g., jake-precinct99, amy-precinct99)
- Users: jake, amy, rosa, terry, charles, gina
- All passwords are bcrypt hashed (cost factor 12)

**Tables:**
- `users` - User accounts with bcrypt password hashes
- `github_integrations` - GitHub token configuration tracking
- `audit_log` - Optional audit trail (JSONB details column)

## Critical Configuration Details

### SPIRE Configuration

**Server (`infrastructure/spire/server-configmap.yaml`):**
- Trust domain: `demo.local`
- Node attestation: `k8s_psat` (Projected Service Account Token)
- Data store: SQLite (demo only)
- **k8sbundle notifier:** Configured with `namespace = "spire-system"` to populate trust bundle ConfigMap

**Agent (`infrastructure/spire/agent-configmap.yaml`):**
- Server address: `spire-server.spire-system:8081`
- Socket path: `/run/spire/sockets/agent.sock`
- Workload attestation: `k8s` (pod metadata)
- **Trust bundle:** Uses `trust_bundle_path = "/run/spire/bundle/bundle.crt"` (mounted from ConfigMap)

**RBAC Requirements:**
- SPIRE server needs ConfigMap permissions (get, list, create, update, patch) in spire-system namespace
- Separate ClusterRole for cluster-wide permissions (nodes, pods, tokenreviews)
- Separate Role for namespace-scoped permissions (ConfigMaps)

### OpenBao Configuration

The project supports **two deployment modes** for OpenBao:

#### Dev Mode (HTTP - Quick Start)
- **Protocol:** HTTP (port 8200)
- **Storage:** In-memory (ephemeral, data lost on restart)
- **Unsealing:** Auto-unsealed
- **Authentication:** Root token ("root")
- **Backend Auth:** Fallback to root token (cert auth requires TLS)
- **Use case:** Quick development, initial testing
- **Deployment:** `infrastructure/openbao/deployment.yaml`

#### Production Mode (HTTPS with TLS)
- **Protocol:** HTTPS with TLS (port 8200)
- **Storage:** File-based persistent storage (PVC)
- **Unsealing:** Manual unseal required (Shamir's Secret Sharing: 5 keys, 3 threshold)
- **Authentication:** SPIRE X.509 certificate (mTLS)
- **Backend Auth:** Cert auth method with SPIRE trust bundle
- **Use case:** Production-like demo, security testing
- **Deployment:** `infrastructure/openbao/deployment-tls.yaml`
- **Setup Guide:** See `docs/OPENBAO_TLS_SETUP.md`

**Configured Features (Both Modes):**
- ✅ Cert auth method for backend workload authentication (TLS mode only)
- ✅ KV v2 secrets engine for static secrets (GitHub tokens)
- ✅ Database secrets engine for dynamic PostgreSQL credentials
- ✅ Policy: `backend-policy` allowing access to both engines

**Certificate Architecture (TLS Mode):**
- OpenBao server uses self-signed TLS certificate (generated by `scripts/helpers/generate-vault-tls.sh`)
- Backend authenticates using SPIRE X.509-SVID (issued by SPIRE server)
- Two separate certificates: server TLS cert (OpenBao) + client auth cert (SPIRE)
- This follows industry-standard practice for Vault + SPIRE integration

### PostgreSQL Configuration

- Database: `appdb`
- Admin user: `postgres` / `postgres` (demo only)
- Image: `postgres:15-alpine`
- Storage: 1Gi PVC
- Init script: Mounted via ConfigMap at `/docker-entrypoint-initdb.d`

### Cilium Configuration

Currently basic mode (SPIRE integration planned for Sprint 4):
- Installed via Helm (v1.15.7)
- Hubble enabled for observability
- IPAM mode: kubernetes
- SPIFFE integration will be added in Sprint 4 for mTLS and SPIFFE-based network policies

## Development Workflow

### Phase Execution Order

**Critical:** CNI must be installed before application workloads can be scheduled.

Correct order: Phase 1 (Prerequisites) → Phase 2 (kind cluster) → **Phase 6 (Cilium)** → Phase 3 (SPIRE) → Phase 4 (OpenBao) → Phase 5 (PostgreSQL) → Phase 7 (Verification)

This order differs from documentation sequence because nodes require CNI to become Ready.

### Sprint Planning

The project follows a 5-sprint structure:
1. **Sprint 1:** Infrastructure Foundation (COMPLETED)
2. **Sprint 2:** Backend Application Development
3. **Sprint 3:** Frontend Application Development
4. **Sprint 4:** Integration & Security (Vault config, SPIRE entries, Cilium policies)
5. **Sprint 5:** Documentation & Demo Preparation

Refer to `docs/MASTER_SPRINT.md` for complete architecture and `docs/sprint-1-infrastructure.md` for infrastructure implementation details.

### When Working on SPIRE

- Always check server and agent logs for debugging
- SPIRE server stores data in `/run/spire/data` (PVC-backed)
- Registration entries will be created in Sprint 2 (Backend) and Sprint 4 (Integration)
- SPIFFE ID format: `spiffe://demo.local/ns/<namespace>/sa/<serviceaccount>`

### When Working on OpenBao

- Dev mode is ephemeral - data lost on pod restart
- For production considerations, refer to OpenBao documentation
- Admin operations use root token in dev mode
- Backend will use cert auth (mTLS) for workload authentication

### When Working on Database

- Init script only runs on first container start (PostgreSQL behavior)
- To reset database: Delete PVC and recreate StatefulSet
- Demo users are pre-seeded via init script
- Dynamic credentials will be created by OpenBao database engine (Sprint 2)

## Important Notes

### Security Model

- **User Authentication:** Traditional PostgreSQL + JWT (NOT using OpenBao)
- **Workload Authentication:** SPIRE X.509-SVID → OpenBao cert auth
- **Static Secrets:** GitHub API tokens stored in OpenBao KV v2
- **Dynamic Secrets:** PostgreSQL credentials generated by OpenBao database engine
- **Network Security:** Cilium mTLS + SPIFFE-based network policies (Sprint 4)

### Migration from HashiCorp Vault to OpenBao

This project originally used HashiCorp Vault but migrated to OpenBao (open-source fork, MPL 2.0 license). Key differences:
- CLI command: `bao` instead of `vault`
- Image: `quay.io/openbao/openbao` instead of `hashicorp/vault`
- API compatibility maintained
- Environment variables: `BAO_*` instead of `VAULT_*`

### Demo vs Production

This is a **demo/POC environment**. Production deployments should:
- Use HA SPIRE deployment (multiple server replicas)
- Use production-grade OpenBao with proper storage backend (not dev mode)
- Use managed PostgreSQL or HA PostgreSQL with backups
- Create dedicated OpenBao database admin user (not postgres superuser)
- Increase bcrypt cost factor (14+) and enforce strong password policies
- Use proper TLS certificates (not dev mode auto-generated)
- Implement monitoring, logging, and alerting
- Use GitOps for deployment (Flux/ArgoCD)

## Troubleshooting

### Nodes NotReady
- **Cause:** CNI not installed
- **Solution:** Install Cilium first (Phase 6 before Phase 3)

### SPIRE Server CrashLoopBackOff
- **Cause:** Missing ConfigMap permissions for k8sbundle notifier
- **Solution:** Ensure Role and RoleBinding exist with ConfigMap permissions

### SPIRE Agent Not Connecting
- **Cause:** Trust bundle not available or incorrect path
- **Solution:** Verify spire-bundle ConfigMap exists and is mounted in agent pods

### PostgreSQL Init Script Not Running
- **Cause:** PVC has existing data from previous deployment
- **Solution:** Delete PVC and recreate StatefulSet, or manually run init script

### OpenBao Health Check Failing
- **Cause:** Dev mode arguments incorrect or port mismatch
- **Solution:** Verify args include `-dev`, `-dev-root-token-id=root`, `-dev-listen-address=0.0.0.0:8200`

## Documentation

- **Master Sprint Plan:** `docs/MASTER_SPRINT.md` - Complete architecture and planning
- **Sprint 1 (Infrastructure):** `docs/sprint-1-infrastructure.md` - Detailed implementation with execution logs
- **README:** Project overview and quick start (when setup.sh is complete)
- **Official Docs:** SPIRE (spiffe.io), OpenBao (openbao.org), Cilium (docs.cilium.io)
