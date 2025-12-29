# 🚔 SPIRE-Vault-99

> **"Cool, cool, cool, cool, cool, no doubt, no doubt."** - Zero-trust architecture, probably

A comprehensive **zero-trust security platform** demonstrating production-grade workload identity, secrets management, and service mesh integration on Kubernetes.

*Inspired by Brooklyn Nine-Nine's 99th Precinct - because security should be as organized as Captain Holt and as fun as Jake Peralta.*

---

## 📊 Project Overview

This platform showcases a complete zero-trust architecture implementation using industry-standard tools:

- 🔐 **SPIRE/SPIFFE** - Workload identity and authentication
- 🔑 **OpenBao** - Secrets management (static + dynamic)
- 🌐 **Cilium** - Service mesh with SPIFFE-based network policies
- ☸️ **Kubernetes** - Container orchestration (kind cluster)
- 🐘 **PostgreSQL** - Database with dynamic credentials
- ⚛️ **Next.js + FastAPI** - Full-stack demo application

**Platform:** Kubernetes (kind)
**Timeline:** ASAP
**Audience:** Technical teams

---

## 🎯 What This Demo Proves

### **Core Capabilities**

✅ **Workload Identity (SPIRE/SPIFFE)**
- No static API keys or credentials in code
- X.509 certificate-based service authentication
- Automatic certificate rotation (1-hour TTL)

✅ **Secrets Management (OpenBao)**
- **Static secrets:** GitHub API tokens stored securely
- **Dynamic secrets:** PostgreSQL credentials generated on-demand
- Automatic credential rotation every 50 minutes
- Zero downtime during credential rotation

✅ **Service Mesh Security (Cilium)**
- Automatic mTLS between all services
- SPIFFE-based network policies (not just pod labels!)
- Only backend with correct SPIFFE ID can access OpenBao/DB

✅ **Real Application**
- User authentication (PostgreSQL + JWT)
- GitHub integration (store tokens, fetch repos)
- Production-like connection pooling
- Zero static secrets

---

## 🏗️ Architecture

### **Applications (2)**

1. **Frontend** - Next.js 14 (TypeScript + Tailwind CSS)
   - User authentication UI
   - GitHub integration pages
   - Protected routes

2. **Backend** - Python FastAPI
   - SPIRE client (obtains X.509-SVID)
   - OpenBao client (mTLS authentication)
   - GitHub API integration
   - PostgreSQL operations

### **Infrastructure**

- **SPIRE:** Identity provider (trust domain: `spiffe://demo.local`)
- **OpenBao:** Secrets manager (cert auth + KV v2 + database engine)
- **PostgreSQL:** Database (credentials managed by OpenBao)
- **Cilium:** Service mesh (mTLS + SPIFFE policies)

### **Architecture Diagram**

```
┌─────────────────────────────────────────────────────────┐
│  Kubernetes Cluster (kind)                              │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ SPIRE Server │  │   OpenBao    │  │  PostgreSQL  │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                  │                  │         │
│  ┌──────▼──────────────────▼──────────────────▼──────┐ │
│  │         SPIRE Agent (DaemonSet)                    │ │
│  └──────┬─────────────────────────────────────────────┘ │
│         │                                                │
│  ┌──────▼──────────┐              ┌────────────────┐   │
│  │  Backend        │◄─────────────┤  Frontend      │   │
│  │  (FastAPI)      │              │  (Next.js)     │   │
│  │                 │              │                │   │
│  │ 1. Get SVID     │              │ - Auth UI      │   │
│  │ 2. Auth OpenBao │              │ - GitHub pages │   │
│  │ 3. Get secrets  │              │                │   │
│  │ 4. Call GitHub  │              │                │   │
│  └─────────────────┘              └────────────────┘   │
│         │                                                │
│  ┌──────▼────────────────────────────────────────────┐ │
│  │  Cilium (mTLS + SPIFFE Network Policies)         │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### **Prerequisites**

- Docker
- kubectl
- kind
- Helm (optional)

### **One-Command Setup** *(Coming Soon)*

```bash
./scripts/setup.sh
```

This will:
1. Create kind cluster
2. Deploy SPIRE (server + agent)
3. Deploy OpenBao and configure it
4. Deploy PostgreSQL
5. Install Cilium with SPIRE integration
6. Deploy frontend and backend applications
7. Seed demo data

### **Access the Application**

```bash
# Frontend
http://localhost:3000

# Backend API
http://localhost:8000

# OpenBao UI (dev mode)
http://localhost:8200
```

---

## 👥 Demo Users (Brooklyn Nine-Nine Squad)

All users authenticate via PostgreSQL (bcrypt hashed passwords):

| Username | Password | Email | Role |
|----------|----------|-------|------|
| **jake** | jake99 | jake.peralta@99.precinct | Detective |
| **amy** | amy99 | amy.santiago@99.precinct | Detective |
| **rosa** | rosa99 | rosa.diaz@99.precinct | Detective |
| **terry** | terry99 | terry.jeffords@99.precinct | Sergeant |
| **charles** | charles99 | charles.boyle@99.precinct | Detective |
| **gina** | gina99 | gina.linetti@99.precinct | Civilian Admin |

> **Note:** Passwords are stored securely in PostgreSQL (bcrypt hashed). OpenBao is NOT used for user authentication - it's used exclusively for backend workload authentication and secrets management.

---

## 🎬 Demo Flow (25 minutes)

### **Part 1: Application & User Login (3 min)**
- Show user login (Jake - traditional PostgreSQL auth)
- Navigate to dashboard

### **Part 2: Backend Workload Authentication - THE CORE DEMO (5 min)**
- Show backend pod getting SPIRE SVID (X.509 certificate)
- Demonstrate backend authenticating to OpenBao using SPIRE cert (mTLS)
- Show OpenBao logs validating the SPIFFE ID
- Explain zero-trust workload identity

### **Part 3: GitHub Integration - Static Secrets (5 min)**
- Configure GitHub API token via UI
- Show backend storing token in OpenBao (using SPIRE auth)
- Retrieve token from OpenBao
- Fetch GitHub repositories using the token
- Display repos in UI

### **Part 4: Database Access - Dynamic Secrets (5 min)**
- Show backend requesting DB credentials from OpenBao
- OpenBao creates temporary PostgreSQL user (v-token-backend-xyz)
- Backend uses temp credentials to query database
- Show credential expiration/rotation
- Verify temp user deleted after TTL

### **Part 5: Cilium Network Security (5 min)**
- Show Hubble flow with SPIFFE IDs
- Demonstrate mTLS between services
- Show SPIFFE-based network policy enforcement
- Attempt unauthorized OpenBao access from frontend pod (denied)

### **Part 6: Q&A (2 min)**
- Answer technical questions
- Show code snippets
- Discuss production considerations

---

## 📁 Repository Structure

```
spire-vault-99/
├── docs/                          # Documentation
│   ├── MASTER_SPRINT.md          # Master sprint planning
│   ├── sprint-1-infrastructure.md
│   ├── sprint-2-backend.md
│   ├── sprint-3-frontend.md
│   ├── sprint-4-integration.md
│   └── sprint-5-documentation.md
├── infrastructure/                # Kubernetes manifests
│   ├── kind-config.yaml
│   ├── spire/
│   ├── openbao/
│   ├── postgres/
│   └── cilium/
├── backend/                       # Python FastAPI app
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app/
│   └── k8s/
├── frontend/                      # Next.js app
│   ├── Dockerfile
│   ├── package.json
│   ├── src/
│   └── k8s/
├── scripts/                       # Automation scripts
│   ├── setup.sh                  # One-command setup
│   ├── demo.sh                   # Demo walkthrough
│   └── teardown.sh               # Cleanup
└── README.md                      # This file
```

---

## 📚 Documentation

**Start here:**
- [Master Sprint Plan](docs/MASTER_SPRINT.md) - Complete architecture and planning

**Implementation guides:**
- Sprint 1: Infrastructure Foundation *(coming soon)*
- Sprint 2: Backend Development *(coming soon)*
- Sprint 3: Frontend Development *(coming soon)*
- Sprint 4: Integration & Security *(coming soon)*
- Sprint 5: Documentation & Demo *(coming soon)*

---

## 🔧 Technology Stack

### **Infrastructure**
| Technology | Version | Purpose |
|------------|---------|---------|
| Kubernetes | 1.27+ | Container orchestration (kind) |
| SPIRE | Latest | Workload identity (X.509-SVID) |
| Vault | 1.15+ | Secrets management |
| PostgreSQL | 15+ | Application database |
| Cilium | 1.14+ | Service mesh + network policies |

### **Backend**
| Technology | Version | Purpose |
|------------|---------|---------|
| Python | 3.11+ | Runtime |
| FastAPI | Latest | Web framework |
| py-spiffe | Latest | SPIRE client library |
| hvac | Latest | Vault client library |
| asyncpg | Latest | PostgreSQL driver |
| SQLAlchemy | Latest | ORM |

### **Frontend**
| Technology | Version | Purpose |
|------------|---------|---------|
| Next.js | 14 | React framework (App Router) |
| TypeScript | Latest | Type safety |
| Tailwind CSS | Latest | Styling |
| Axios | Latest | HTTP client |

---

## 🔐 Security Highlights

### **Zero Static Secrets**
- ✅ No hardcoded API keys
- ✅ No static database passwords
- ✅ No long-lived credentials in config files

### **Automatic Rotation**
- ✅ SPIRE SVIDs: 1-hour TTL (auto-rotated)
- ✅ Database credentials: 1-hour TTL (rotated every 50 minutes)
- ✅ Connection pool migration: Zero downtime

### **Network Security**
- ✅ mTLS between all services (Cilium)
- ✅ SPIFFE-based network policies
- ✅ Only backend can access OpenBao/DB
- ✅ Frontend isolated from sensitive services

### **Audit & Compliance**
- ✅ OpenBao audit logs (all secret access)
- ✅ SPIRE audit logs (all SVID issuance)
- ✅ PostgreSQL logs (dynamic user creation/deletion)

---

## 🎯 Best Practices Demonstrated

### **Database Connection Strategy**
- ✅ Connection pooling (5-20 connections)
- ✅ OpenBao-issued dynamic credentials
- ✅ Graceful rotation (no downtime)
- ✅ Retry logic with exponential backoff

### **Secrets Management**
- ✅ Static secrets: GitHub tokens (user-provided)
- ✅ Dynamic secrets: DB credentials (OpenBao-generated)
- ✅ Separation of concerns (identity vs secrets)

### **Production-Ready Patterns**
- ✅ Health checks and readiness probes
- ✅ Structured logging
- ✅ Error handling and retry logic
- ✅ Resource limits and requests

---

## 🚧 Current Status

**Phase:** Planning & Architecture
**Document Version:** 2.1
**Last Updated:** 2025-12-29

**Progress:**
- [x] Master sprint planning complete
- [ ] Sub-sprint 1: Infrastructure (not started)
- [ ] Sub-sprint 2: Backend (not started)
- [ ] Sub-sprint 3: Frontend (not started)
- [ ] Sub-sprint 4: Integration (not started)
- [ ] Sub-sprint 5: Documentation (not started)

---

## 📖 Learning Resources

### **SPIRE/SPIFFE**
- [SPIFFE Specification](https://github.com/spiffe/spiffe)
- [SPIRE Documentation](https://spiffe.io/docs/latest/)
- [SPIRE Kubernetes Quickstart](https://spiffe.io/docs/latest/try/getting-started-k8s/)

### **OpenBao**
- [OpenBao Official Website](https://openbao.org/)
- [OpenBao Documentation](https://openbao.org/docs/)
- [OpenBao Database Secrets Engine](https://openbao.org/docs/secrets/databases/postgresql/)
- [OpenBao Cert Auth Method](https://openbao.org/docs/auth/cert/)
- [OpenBao vs HashiCorp Vault](https://digitalis.io/post/choosing-a-secrets-storage-hashicorp-vault-vs-openbao)

### **Cilium**
- [Cilium Documentation](https://docs.cilium.io/)
- [Cilium Service Mesh](https://docs.cilium.io/en/stable/network/servicemesh/)
- [Cilium + SPIRE Integration](https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/)

### **Integration Guides**
- [SPIRE + Vault/OpenBao](https://spiffe.io/docs/latest/keyless/vault/)
- [Cilium + SPIFFE](https://isovalent.com/blog/post/cilium-spiffe-spire/)

---

## 🤝 Contributing

This is a demo/POC project. Contributions, issues, and feature requests are welcome!

**Areas for improvement:**
- Additional microservices (show multi-service mTLS)
- Multi-language support (Go backend, demonstrate go-spiffe)
- Observability stack (Prometheus, Grafana, Jaeger)
- GitOps deployment (Flux/ArgoCD)
- Production hardening guide

---

## 📝 Notes

- This is a **demo/POC** environment, not production-ready
- Focus is on showcasing zero-trust architecture patterns
- All credentials are demo credentials (not secure for production)
- Infrastructure runs on local kind cluster (not cloud)
- Brooklyn Nine-Nine theme makes it fun and memorable! 🚔

---

## 📞 Contact & Support

For questions or issues:
- Review the [Master Sprint documentation](docs/MASTER_SPRINT.md)
- Check the troubleshooting guide *(coming soon)*
- Consult official documentation (links above)

---

## 🎉 Acknowledgments

- **Brooklyn Nine-Nine** - For making security fun (and organized)
- **CNCF SPIFFE/SPIRE** - For workload identity done right
- **OpenBao Community** - For open-source secrets management excellence
- **Cilium** - For next-gen service mesh
- **The 99th Precinct** - For inspiration

---

**"NINE-NINE!"** 🚔

---

**License:** MIT *(or your preferred license)*

**Author:** [mvsangh](https://github.com/mvsangh)
**Repository:** [spire-vault-99](https://github.com/mvsangh/spire-vault-99)
