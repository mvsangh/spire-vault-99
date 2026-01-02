# 🎯 MASTER SPRINT: Zero-Trust Demo Platform
**SPIRE/SPIFFE + Vault + Cilium Integration**

## 📊 Project Overview

**Objective:** Build a comprehensive demo platform showcasing zero-trust architecture using SPIRE/SPIFFE for workload identity, HashiCorp Vault for secrets management, and Cilium for service mesh with SPIFFE-based network policies.

**Platform:** Kubernetes (kind cluster)
**Timeline:** ASAP (Deadline passed, but manageable)
**Audience:** Technical team

---

## 🎪 Demo Capabilities

This platform will demonstrate:

1. ✅ **Workload Identity**: SPIRE/SPIFFE SVIDs for workload authentication
2. ✅ **Secrets Management**:
   - Static secrets (GitHub API tokens)
   - Dynamic secrets (PostgreSQL credentials with auto-rotation)
3. ✅ **User Authentication**: Traditional PostgreSQL-based authentication with JWT tokens
4. ✅ **Service Mesh**: Cilium with mTLS and SPIFFE-based network policies
5. ✅ **Real Application**: User management + GitHub integration

---

## 🏛️ Application Architecture

This demo platform consists of **2 applications** plus supporting infrastructure:

### **Applications (2 Total)**

#### **1. Frontend Application**
- **Technology:** Next.js 16 (App Router) + TypeScript + Tailwind CSS
- **Purpose:** User interface and interaction
- **Port:** 3000 (exposed for browser access)
- **Key Features:**
  - User authentication UI (login/registration)
  - Dashboard/home page
  - GitHub integration pages (configure token, view repos, user profile)
  - Protected routes with JWT validation
- **Deployment:** Kubernetes Deployment + Service
- **SPIRE Integration:** Indirect via Cilium (receives SPIFFE ID for service mesh mTLS in Sprint 4, does not interact with SPIRE Workload API or Vault directly)

#### **2. Backend Application**
- **Technology:** Python 3.11+ with FastAPI framework
- **Purpose:** API server, business logic, and integration hub
- **Port:** 8000 (internal service)
- **Key Features:**
  - User authentication (PostgreSQL + JWT)
  - SPIRE client integration (obtains X.509-SVID)
  - Vault client (authenticates with SPIRE cert via mTLS)
  - GitHub API integration
  - PostgreSQL database operations
  - RESTful API endpoints
- **Deployment:** Kubernetes Deployment + Service + ServiceAccount
- **SPIRE Integration:** Yes (gets SVID from agent, uses for Vault auth)

### **Why 2 Applications is Sufficient**

✅ **Complete Demo Coverage:**
- Single backend can demonstrate all Vault capabilities (static + dynamic secrets)
- Clear separation between user-facing (frontend) and integration logic (backend)
- Showcases SPIRE workload identity for backend service
- Demonstrates Cilium network policies (frontend blocked from Vault, backend allowed)

✅ **Simplicity:**
- Easier to build within ASAP timeline
- Simpler to explain to technical audience
- Focused demo narrative

✅ **Extensibility:**
- Can add more microservices later if needed
- Architecture supports future expansion

### **Infrastructure Components (Not Applications)**

These are supporting services, not custom applications:
- **SPIRE:** Identity provider (server + agent)
- **Vault:** Secrets manager
- **PostgreSQL:** Database
- **Cilium:** Service mesh and network policy enforcement

---

## ⚙️ Technical Configuration Details

### **SPIRE Configuration**

| Setting | Value | Rationale |
|---------|-------|-----------|
| **Trust Domain** | `spiffe://demo.local` | Single trust domain for demo simplicity |
| **Agent Deployment** | DaemonSet | One agent per node, workloads access via Unix socket |
| **Node Attestor** | `k8s_psat` | Projected Service Account Token attestation (recommended for K8s) |
| **Workload Attestor** | `k8s` | Reads pod metadata (namespace, service account, labels) |
| **SVID Type** | X.509-SVID | Certificate-based identity for mTLS |
| **SVID TTL** | 1 hour | Auto-rotated by agent |
| **Agent Socket Path** | `/run/spire/sockets/agent.sock` | Mounted as volume in backend pod |

**SPIFFE IDs:**
- Backend: `spiffe://demo.local/ns/99-apps/sa/backend` (used for Vault JWT auth + Cilium mTLS)
- Frontend: `spiffe://demo.local/ns/99-apps/sa/frontend` (used for Cilium mTLS only)

**Note:** Frontend receives SPIFFE ID via Cilium service mesh for automatic mTLS with backend but does not interact with SPIRE Workload API in application code. Backend directly integrates with SPIRE for Vault authentication and secret management.

### **Vault Configuration**

| Setting | Value | Rationale |
|---------|-------|-----------|
| **Deployment Mode** | Standalone | Single instance, sufficient for demo |
| **Topology** | Centralized | One Vault instance serves all workloads |
| **Storage Backend** | File (local) | Simple for demo, not production-ready |
| **Auth Methods** | ~~Cert auth~~ **JWT auth** | Backend authenticates with SPIRE JWT-SVID (pivoted from X.509 cert auth due to OpenBao limitation - see note below) |
| **Secrets Engines** | KV v2, Database | Static (GitHub tokens) + Dynamic (DB creds) |
| **Seal Type** | Shamir | Manual unseal (auto-unseal not needed for demo) |

**⚠️ IMPORTANT: Authentication Method Pivot (Dec 2025)**

Originally planned to use X.509-SVID certificate authentication via OpenBao's `cert` auth method. During implementation (Sprint 2, Phase 3), we encountered a known OpenBao limitation: the cert auth method requires a Common Name (CN) field for entity alias creation, but SPIFFE certificates only contain URI Subject Alternative Names (URI SANs) for identity.

**Error encountered:** `"missing name in alias"` when attempting cert auth login.

**Root cause:** OpenBao cert auth expects CN field; SPIFFE uses URI SANs (`spiffe://demo.local/ns/99-apps/sa/backend`).

**Resolution:** Pivoted to JWT-SVID authentication using OpenBao's `jwt` auth method with SPIRE's OIDC Discovery Provider. This is the **official SPIFFE-recommended approach** for Vault/OpenBao integration (see: https://spiffe.io/docs/latest/keyless/vault/).

**Implementation details:** See `docs/SESSION_IMPLEMENTATION_LOG.md` for complete investigation, attempted solutions, and decision rationale.

**Benefits of JWT-SVID approach:**
- ✅ Officially supported by SPIFFE for Vault integration
- ✅ No CN field requirement - uses SPIFFE ID directly
- ✅ Industry-standard OIDC/JWT authentication
- ✅ Production-ready and well-documented

**Vault Paths:**
- GitHub token: `secret/data/github/api-token`
- Database role: `database/creds/backend-role`

**Vault Policies:**
- `backend-policy`: Allows read/write to `secret/github/*`, read from `database/creds/backend-role`

### **PostgreSQL Configuration**

| Setting | Value | Rationale |
|---------|-------|-----------|
| **Version** | PostgreSQL 15+ | Latest stable |
| **Deployment** | StatefulSet | Persistent storage for data |
| **Storage** | 1Gi PVC | Sufficient for demo data |
| **Access** | Internal only | Only backend can connect |
| **Admin User** | `postgres` | Default superuser |
| **App User** | Dynamic (created by Vault) | Vault database secrets engine creates temp users |

### **Cilium Configuration**

| Setting | Value | Rationale |
|---------|-------|-----------|
| **Mode** | Service Mesh | mTLS + network policies |
| **SPIRE Integration** | Enabled | Uses SPIRE-issued certificates for mTLS |
| **mTLS** | Automatic | All service-to-service communication encrypted |
| **Network Policies** | SPIFFE-based | Policies use SPIFFE IDs instead of pod labels |
| **Hubble** | Enabled | Flow visibility with SPIFFE IDs |

**Network Policy Rules:**
- Vault: Only accessible by workloads with SPIFFE ID `spiffe://demo.local/ns/default/sa/backend`
- PostgreSQL: Only accessible by backend
- Frontend: Cannot access Vault or PostgreSQL directly

### **JWT Token Configuration**

| Setting | Value | Rationale |
|---------|-------|-----------|
| **Algorithm** | HS256 | Symmetric signing, simple for demo |
| **Access Token Expiry** | 1 hour | Balance between security and demo convenience |
| **Refresh Tokens** | Not implemented | Not needed for demo |
| **Storage** | Frontend localStorage | Standard for demo apps |
| **Claims** | `user_id`, `username`, `exp`, `iat` | Minimal required claims |

### **User Authentication**

| Setting | Value | Rationale |
|---------|-------|-----------|
| **Storage** | PostgreSQL | Traditional approach, NOT Vault |
| **Password Hashing** | bcrypt (cost 12) | Industry standard |
| **Password Requirements** | Min 6 characters | Demo-friendly, not production-grade |
| **Session Management** | JWT tokens | Stateless authentication |
| **User Registration** | Enabled | Both pre-seeded users AND registration UI |

### **Database Connection Strategy**

| Setting | Value | Rationale |
|---------|-------|-----------|
| **Credential Source** | Vault Database Secrets Engine | Dynamic, short-lived credentials |
| **Connection Method** | Connection Pool | Best practice for performance and reliability |
| **Credential Rotation** | Every 50 minutes | Proactive renewal before 1-hour TTL expires |
| **Pool Size** | 10-20 connections | Sufficient for demo load |
| **Rotation Strategy** | Graceful migration | Create new pool → migrate → close old pool |
| **Failure Handling** | Retry with backoff | If Vault unavailable, retry before failing |

**How it works:**
1. **At Backend Startup:**
   - Backend gets SPIRE SVID
   - Authenticates to Vault with certificate
   - Requests database credentials (TTL: 1 hour)
   - Vault creates temporary PostgreSQL user (`v-token-backend-xyz`)
   - Backend creates connection pool with these credentials

2. **During Normal Operation:**
   - All database queries use the connection pool
   - No per-request Vault calls for database access
   - Fast, efficient, production-like

3. **Credential Rotation (Background Task):**
   - Every 50 minutes (before 1-hour TTL expires)
   - Request new credentials from Vault
   - Vault creates new PostgreSQL user
   - Create new connection pool
   - Gracefully migrate connections
   - Close old pool
   - Vault revokes old credentials
   - PostgreSQL drops old user

**Security Benefits:**
- ✅ No static database credentials
- ✅ Credentials rotate automatically every hour
- ✅ Compromised credentials only valid for max 1 hour
- ✅ Vault audit log tracks all credential issuance
- ✅ Can revoke credentials instantly if needed

**Performance Benefits:**
- ✅ Connection pooling reduces overhead
- ✅ No Vault call per database query
- ✅ Realistic production pattern
- ✅ Graceful degradation if Vault temporarily unavailable

---

## 🗄️ Database Schema

### **PostgreSQL Tables**

```sql
-- Users table (stores user accounts)
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- GitHub integration metadata
CREATE TABLE github_integrations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    is_configured BOOLEAN DEFAULT FALSE,
    configured_at TIMESTAMP,
    last_accessed TIMESTAMP,
    UNIQUE(user_id)
);

-- Audit log (optional - for demo purposes)
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource VARCHAR(100),
    timestamp TIMESTAMP DEFAULT NOW(),
    details JSONB
);

-- Indexes for performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_github_integrations_user_id ON github_integrations(user_id);
CREATE INDEX idx_audit_log_timestamp ON audit_log(timestamp DESC);
```

**Pre-seeded Data:**
```sql
-- Demo users (passwords hashed with bcrypt)
INSERT INTO users (username, email, password_hash) VALUES
  ('jake', 'jake.peralta@99.precinct', '$2b$12$...'), -- password: jake99
  ('amy', 'amy.santiago@99.precinct', '$2b$12$...'),  -- password: amy99
  ('rosa', 'rosa.diaz@99.precinct', '$2b$12$...'),    -- password: rosa99
  ('terry', 'terry.jeffords@99.precinct', '$2b$12$...'), -- password: terry99
  ('charles', 'charles.boyle@99.precinct', '$2b$12$...'), -- password: charles99
  ('gina', 'gina.linetti@99.precinct', '$2b$12$...');  -- password: gina99
```

---

## 🔄 Application Flow Diagrams

### **Flow 1: Backend Startup & Database Connection Pool Initialization**

```
┌──────────────────────────────────────────────────────────┐
│  Backend Application Starts                              │
└────┬─────────────────────────────────────────────────────┘
     │ 1. Initialization
     ▼
┌──────────────┐
│   Backend    │ 2. Request SPIRE SVID
└────┬─────────┘
     │
     ▼
┌──────────────┐
│ SPIRE Agent  │ 3. Returns X.509-SVID
│              │    (SPIFFE ID: spiffe://demo.local/ns/default/sa/backend)
└────┬─────────┘
     │
     ▼
┌──────────────┐
│   Backend    │ 4. Authenticate to Vault with certificate (mTLS)
└────┬─────────┘
     │
     ▼
┌──────────────┐
│    Vault     │ 5. Validates SPIFFE ID against cert auth policy
└────┬─────────┘
     │ 6. Vault authenticated
     ▼
┌──────────────┐
│   Backend    │ 7. Request DB credentials:
│              │    GET database/creds/backend-role
└────┬─────────┘
     │
     ▼
┌──────────────────────────────────────────────────────────┐
│              Vault Database Secrets Engine               │
│                                                          │
│  1. Connect to PostgreSQL as admin (postgres user)      │
│  2. CREATE ROLE "v-token-backend-abc123"                │
│     WITH LOGIN PASSWORD 'random-32-char-password'       │
│     VALID UNTIL NOW() + INTERVAL '1 hour';              │
│  3. GRANT SELECT, INSERT, UPDATE, DELETE                │
│     ON ALL TABLES IN SCHEMA public                      │
│     TO "v-token-backend-abc123";                        │
│  4. Create lease with TTL: 3600 seconds (1 hour)        │
└────┬─────────────────────────────────────────────────────┘
     │ 8. Returns credentials:
     │    {
     │      "username": "v-token-backend-abc123",
     │      "password": "A1B2C3...",
     │      "lease_id": "database/creds/backend-role/xyz",
     │      "lease_duration": 3600
     │    }
     ▼
┌──────────────────────────────────────────────────────────┐
│              Backend                                     │
│                                                          │
│  9. Create database connection pool:                    │
│     - Min connections: 5                                │
│     - Max connections: 20                               │
│     - Host: postgresql.default.svc.cluster.local        │
│     - Database: appdb                                   │
│     - User: v-token-backend-abc123                      │
│     - Password: A1B2C3...                               │
│                                                          │
│  10. Start background task: credential_renewal()        │
│      - Runs every 50 minutes                            │
│      - Renews credentials before 1-hour expiry          │
└────┬─────────────────────────────────────────────────────┘
     │ 11. Backend ready to serve requests
     ▼
┌──────────────┐
│   Backend    │ ✅ Application healthy
│              │ ✅ Database pool connected
│              │ ✅ Credentials valid for 1 hour
└──────────────┘
```

### **Flow 2: User Login (Using Connection Pool)**

```
┌─────────┐
│  User   │ 1. Enters username/password
└────┬────┘
     ▼
┌─────────────┐
│  Frontend   │ 2. POST /api/auth/login
│             │    { username: "jake", password: "jake99" }
└────┬────────┘
     ▼
┌──────────────────────────────────────────────────────────┐
│              Backend                                     │
│                                                          │
│  3. Validate request                                    │
│  4. Acquire connection from pool                        │
│     (already authenticated with Vault-issued creds)     │
└────┬─────────────────────────────────────────────────────┘
     │ 5. Connection acquired (using v-token-backend-abc123)
     ▼
┌──────────────┐
│  PostgreSQL  │ 6. Execute query:
│              │    SELECT id, username, password_hash, email
│              │    FROM users
│              │    WHERE username = 'jake'
└────┬─────────┘
     │ 7. Returns user record
     ▼
┌──────────────┐
│   Backend    │ 8. Verify password:
│              │    bcrypt.compare('jake99', password_hash)
└────┬─────────┘
     │ 9. Password valid ✅
     ▼
┌──────────────┐
│   Backend    │ 10. Generate JWT token:
│              │     {
│              │       "user_id": 1,
│              │       "username": "jake",
│              │       "exp": now + 1 hour,
│              │       "iat": now
│              │     }
└────┬─────────┘
     │ 11. Release connection back to pool
     │ 12. Return response
     ▼
┌─────────────┐
│  Frontend   │ 13. Receive JWT token
│             │ 14. Store in localStorage
│             │ 15. Redirect to dashboard
└─────────────┘

Total time: ~100ms (fast, no Vault call per request)
```

### **Flow 3: Database Credential Rotation (Background Task)**

```
┌──────────────────────────────────────────────────────────┐
│  Background Task (runs every 50 minutes)                 │
└────┬─────────────────────────────────────────────────────┘
     │ 1. Timer triggers rotation
     ▼
┌──────────────┐
│   Backend    │ 2. Get fresh SPIRE SVID (may have rotated)
└────┬─────────┘
     │
     ▼
┌──────────────┐
│ SPIRE Agent  │ 3. Returns current X.509-SVID
└────┬─────────┘
     │
     ▼
┌──────────────┐
│   Backend    │ 4. Authenticate to Vault with cert
└────┬─────────┘
     │
     ▼
┌──────────────┐
│    Vault     │ 5. Request NEW database credentials
└────┬─────────┘
     │
     ▼
┌──────────────────────────────────────────────────────────┐
│              Vault Database Secrets Engine               │
│                                                          │
│  6. CREATE ROLE "v-token-backend-def456"                │
│     (new user with different random password)           │
└────┬─────────────────────────────────────────────────────┘
     │ 7. Returns new credentials:
     │    { "username": "v-token-backend-def456", ... }
     ▼
┌──────────────────────────────────────────────────────────┐
│              Backend                                     │
│                                                          │
│  8. Create NEW connection pool with new credentials     │
│  9. Wait for active queries on old pool to complete     │
│  10. Gradually migrate traffic to new pool              │
│  11. Close old connection pool                          │
└────┬─────────────────────────────────────────────────────┘
     │ 12. Revoke old Vault lease (optional, will auto-expire)
     ▼
┌──────────────┐
│    Vault     │ 13. Lease revoked or expired
└────┬─────────┘
     │ 14. Trigger PostgreSQL to drop old user
     ▼
┌──────────────┐
│  PostgreSQL  │ 15. DROP ROLE "v-token-backend-abc123"
│              │     (old user removed)
└──────────────┘

Result:
- Old user (v-token-backend-abc123): ❌ Deleted
- New user (v-token-backend-def456): ✅ Active
- Zero downtime for application
- Credentials rotated successfully
```

### **Flow 4: GitHub Token Storage (Static Secret)**

```
┌─────────┐
│  User   │ Enters GitHub Personal Access Token
└────┬────┘
     ▼
┌─────────────┐
│  Frontend   │ POST /api/github/configure
└────┬────────┘    (with JWT in Authorization header)
     ▼
┌──────────────────────────────────────────┐
│            Backend                       │
│                                          │
│  1. Validate JWT token                  │
│  2. Extract user_id from JWT            │
└────┬─────────────────────────────────────┘
     │ 3. Get SPIRE SVID
     ▼
┌──────────────┐
│ SPIRE Agent  │
│ Returns      │
│ X.509-SVID   │
└────┬─────────┘
     │ 4. X.509 certificate (SPIFFE ID: spiffe://demo.local/ns/default/sa/backend)
     ▼
┌──────────────────────────────────────────┐
│            Backend                       │
│  5. Authenticate to Vault with cert     │
│     (mTLS handshake)                     │
└────┬─────────────────────────────────────┘
     │ 6. mTLS connection
     ▼
┌──────────────┐
│    Vault     │
│              │
│  - Validates │
│    SPIFFE ID │
│  - Checks    │
│    policy    │
└────┬─────────┘
     │ 7. Vault authenticated
     ▼
┌──────────────────────────────────────────┐
│            Backend                       │
│  8. Write secret:                        │
│     PUT secret/data/github/api-token     │
│     { "token": "ghp_xxxxx" }             │
└────┬─────────────────────────────────────┘
     │ 9. Secret stored
     ▼
┌──────────────┐
│    Vault     │
│  (GitHub     │
│   token      │
│   encrypted  │
│   at rest)   │
└────┬─────────┘
     │ 10. Success response
     ▼
┌──────────────┐
│   Backend    │ Update github_integrations table
└────┬─────────┘
     │
     ▼
┌──────────────┐
│  PostgreSQL  │ is_configured = true, configured_at = NOW()
└────┬─────────┘
     │ 11. Return success
     ▼
┌─────────────┐
│  Frontend   │ Display "GitHub token saved securely"
└─────────────┘
```

### **Flow 5: Fetch GitHub Repositories (Read Static Secret)**

```
┌─────────┐
│  User   │ Clicks "View My Repos"
└────┬────┘
     ▼
┌─────────────┐
│  Frontend   │ GET /api/github/repos (with JWT)
└────┬────────┘
     ▼
┌──────────────┐
│   Backend    │ Validate JWT, get SPIRE SVID
└────┬─────────┘
     │
     ▼
┌──────────────┐
│ SPIRE Agent  │ Returns X.509-SVID
└────┬─────────┘
     │
     ▼
┌──────────────┐
│   Backend    │ Authenticate to Vault with cert (mTLS)
└────┬─────────┘
     │
     ▼
┌──────────────┐
│    Vault     │ Validates SPIFFE ID
└────┬─────────┘
     │
     ▼
┌──────────────┐
│   Backend    │ Read secret: GET secret/data/github/api-token
└────┬─────────┘
     │
     ▼
┌──────────────┐
│    Vault     │ Returns: { "token": "ghp_xxxxx" }
└────┬─────────┘
     │
     ▼
┌──────────────┐
│   Backend    │ Call GitHub API with token
└────┬─────────┘
     │ GET https://api.github.com/user/repos
     │ Authorization: token ghp_xxxxx
     ▼
┌──────────────┐
│  GitHub API  │ Returns repository list
└────┬─────────┘
     │
     ▼
┌──────────────┐
│   Backend    │ Return repos to frontend
└────┬─────────┘
     │
     ▼
┌─────────────┐
│  Frontend   │ Display repos in UI
└─────────────┘
```

### **Flow 6: Summary - How Dynamic DB Credentials Work**

**Key Point:** Database credentials are obtained ONCE at startup and rotated every 50 minutes. All application queries (login, registration, GitHub metadata, etc.) use the connection pool.

```
┌─────────────────────────────────────────────────────────┐
│  Vault Database Secrets Engine - Complete Picture       │
└─────────────────────────────────────────────────────────┘

STARTUP (Flow 1):
  Backend → SPIRE → Vault → PostgreSQL user created → Connection pool ready

NORMAL OPERATION (Flows 2, 4, 5):
  User login/queries → Use connection pool → Fast response (no Vault call)

BACKGROUND ROTATION (Flow 3):
  Every 50 min → Get new credentials → New pool → Migrate → Old user deleted

DEMO OBSERVATION POINTS:
  1. Show PostgreSQL users:
     SELECT usename, valuntil FROM pg_user WHERE usename LIKE 'v-token%';

  2. At T=0:    v-token-backend-abc123 (valid until T+60min)
     At T=50:   v-token-backend-def456 (valid until T+110min) ← NEW
     At T=60:   v-token-backend-abc123 ← DELETED
                v-token-backend-def456 ← ACTIVE
```

**Security Properties:**
- ✅ No static database credentials in config files
- ✅ Credentials rotate automatically every hour
- ✅ Compromised credentials expire quickly (max 1 hour)
- ✅ Vault tracks all credential issuance in audit log
- ✅ Can revoke credentials instantly if compromise detected
- ✅ Different backend instances get different credentials
- ✅ Follows principle of least privilege (grants only needed permissions)

### **Flow 7: Cilium Network Policy Enforcement**

```
┌─────────────┐
│  Frontend   │ Attempts: curl https://vault:8200
│  Pod        │
└────┬────────┘
     │
     ▼
┌──────────────────────────────────────────┐
│          Cilium Agent                    │
│  1. Intercept connection attempt         │
│  2. Check SPIFFE ID of source pod:       │
│     spiffe://demo.local/ns/default/sa/frontend
│  3. Check network policy for Vault:      │
│     Allowed SPIFFE IDs: [.../sa/backend] │
│  4. Frontend SPIFFE ID NOT in allow list │
└────┬─────────────────────────────────────┘
     │ 5. CONNECTION DENIED
     ▼
┌─────────────┐
│  Frontend   │ Connection refused
│  Pod        │
└─────────────┘


┌─────────────┐
│  Backend    │ Attempts: curl https://vault:8200
│  Pod        │
└────┬────────┘
     │
     ▼
┌──────────────────────────────────────────┐
│          Cilium Agent                    │
│  1. Intercept connection attempt         │
│  2. Check SPIFFE ID of source pod:       │
│     spiffe://demo.local/ns/default/sa/backend
│  3. Check network policy for Vault:      │
│     Allowed SPIFFE IDs: [.../sa/backend] │
│  4. Backend SPIFFE ID IS in allow list   │
│  5. Establish mTLS tunnel using SPIRE    │
│     certificates                          │
└────┬─────────────────────────────────────┘
     │ 6. CONNECTION ALLOWED (mTLS)
     ▼
┌──────────────┐
│    Vault     │ Connection established
└──────────────┘
```

---

## 🗂️ Sub-Sprints Overview

### **Sub-Sprint 1: Infrastructure Foundation**
**Focus:** Core infrastructure setup - SPIRE, Vault, PostgreSQL, Cilium on kind cluster

**Key Deliverables:**
- kind cluster with proper configuration
- SPIRE server and agent deployment
- Vault deployment and initialization
- PostgreSQL database deployment
- Cilium service mesh installation
- Basic connectivity verification

**Success Criteria:**
- All services running and healthy
- SPIRE issuing SVIDs successfully
- Vault accessible and unsealed
- PostgreSQL accepting connections
- Cilium policies enforceable

**Detailed Document:** `sprint-1-infrastructure.md`

---

### **Sub-Sprint 2: Backend Application Development**
**Focus:** Python FastAPI backend with SPIRE integration, authentication, and Vault client

**Key Deliverables:**
- FastAPI application structure
- SPIRE client integration (py-spiffe)
- Vault client implementation (hvac)
- User authentication system (PostgreSQL + JWT)
- GitHub API integration
- PostgreSQL ORM setup
- API endpoints for all features

**Success Criteria:**
- Backend authenticates to Vault using SPIRE certs (mTLS)
- User authentication working (login/registration)
- Can write/read GitHub tokens to/from Vault
- Can request dynamic DB credentials from Vault
- All API endpoints functional

**Detailed Document:** `sprint-2-backend.md`

---

### **Sub-Sprint 3: Frontend Application Development**
**Focus:** Next.js frontend with authentication UI and GitHub integration features

**Key Deliverables:**
- Next.js 16 application (App Router)
- Authentication pages:
  - Login page
  - Registration page
- Protected routes and middleware
- GitHub integration UI:
  - Token configuration page
  - Repositories display page
  - User profile page
- Dashboard/home page
- JWT token management
- API client setup

**Success Criteria:**
- Users can register/login successfully
- GitHub token can be configured via UI
- Repos fetched and displayed correctly
- JWT tokens managed properly
- Responsive UI with Tailwind CSS

**Detailed Document:** `sprint-3-frontend.md`

---

### **Sub-Sprint 4: Integration & Security**
**Focus:** Vault configuration, SPIRE registration, Cilium policies, end-to-end testing

**Key Deliverables:**
- Vault authentication methods configuration:
  - Cert auth (for backend workload with SPIRE)
- Vault secrets engines setup:
  - KV v2 (for GitHub tokens)
  - Database (for PostgreSQL creds)
- Vault policies and roles
- SPIRE registration entries for all workloads
- Cilium network policies (SPIFFE-based)
- Service-to-service mTLS verification
- End-to-end testing
- Pre-seeded demo users (Brooklyn Nine-Nine characters)

**Success Criteria:**
- Backend can authenticate to Vault with SPIRE cert
- Backend can write/read secrets from Vault
- Dynamic DB credentials generated and rotated
- Network policies enforced (only backend can access Vault/DB)
- mTLS verified between services
- All demo users can login and use application

**Detailed Document:** `sprint-4-integration.md`

---

### **Sub-Sprint 5: Documentation & Demo Preparation**
**Focus:** Complete documentation, demo scripts, troubleshooting guides

**Key Deliverables:**
- Master README with architecture diagram
- Quick start guide (`setup.sh` one-command deployment)
- Demo walkthrough script (`demo.sh`)
- Individual component documentation
- Troubleshooting guide
- Architecture diagrams
- Demo presentation notes
- Observability setup (optional):
  - Logs with SPIFFE IDs
  - Hubble flow visualization
  - Basic metrics

**Success Criteria:**
- Anyone can deploy with one command
- Demo script runs smoothly
- All features documented
- Common issues addressed
- Clear talking points for technical audience

**Detailed Document:** `sprint-5-documentation.md`

---

## 🏗️ Technology Stack

### **Infrastructure**
- **Kubernetes:** kind (local cluster)
- **SPIRE:** Server + Agent (DaemonSet)
- **Vault:** Standalone deployment
- **PostgreSQL:** Single instance
- **Cilium:** Service mesh + network policies

### **Backend**
- **Language:** Python 3.11+
- **Framework:** FastAPI
- **SPIRE Client:** py-spiffe
- **Vault Client:** hvac
- **Database:** asyncpg + SQLAlchemy
- **Auth:** python-jose (JWT), passlib (bcrypt)
- **GitHub Client:** httpx

### **Frontend**
- **Framework:** Next.js 16 (App Router)
- **Language:** TypeScript
- **Styling:** Tailwind CSS
- **HTTP Client:** Axios
- **State Management:** React Context (simple)

---

## 📦 Repository Structure

```
test-vault/
├── docs/                          # Documentation
│   ├── MASTER_SPRINT.md          # This document
│   ├── sprint-1-infrastructure.md
│   ├── sprint-2-backend.md
│   ├── sprint-3-frontend.md
│   ├── sprint-4-integration.md
│   └── sprint-5-documentation.md
├── infrastructure/                # Kubernetes manifests
│   ├── kind-config.yaml
│   ├── spire/
│   │   ├── namespace.yaml
│   │   ├── server.yaml
│   │   └── agent.yaml
│   ├── vault/
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── postgres/
│   │   ├── statefulset.yaml
│   │   └── service.yaml
│   └── cilium/
│       └── policies.yaml
├── backend/                       # Python FastAPI app
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app/
│   │   ├── main.py
│   │   ├── api/
│   │   ├── auth/
│   │   ├── spire/
│   │   ├── vault/
│   │   └── models/
│   └── k8s/
│       ├── deployment.yaml
│       └── service.yaml
├── frontend/                      # Next.js app
│   ├── Dockerfile
│   ├── package.json
│   ├── src/
│   │   ├── app/
│   │   ├── components/
│   │   └── lib/
│   └── k8s/
│       ├── deployment.yaml
│       └── service.yaml
├── scripts/                       # Automation scripts
│   ├── setup.sh                  # One-command setup
│   ├── demo.sh                   # Demo walkthrough
│   ├── teardown.sh               # Cleanup
│   └── helpers/
│       ├── vault-config.sh
│       └── spire-register.sh
└── README.md                      # Main documentation
```

---

## 🎯 Demo Users (Brooklyn Nine-Nine Theme)

All users authenticate via traditional PostgreSQL authentication:

| Username | Password | Email | Role |
|----------|----------|-------|------|
| jake | jake99 | jake.peralta@99.precinct | Detective |
| amy | amy99 | amy.santiago@99.precinct | Detective |
| rosa | rosa99 | rosa.diaz@99.precinct | Detective |
| terry | terry99 | terry.jeffords@99.precinct | Sergeant |
| charles | charles99 | charles.boyle@99.precinct | Detective |
| gina | gina99 | gina.linetti@99.precinct | Civilian Admin |

**Note:** User passwords are stored securely in PostgreSQL (bcrypt hashed). OpenBao is NOT used for user authentication - it is used exclusively for backend workload authentication and secrets management.

---

## 🔄 Execution Flow

1. **Read Master Sprint** (this document) - Understand overall project
2. **Review Sub-Sprint 1** - Infrastructure details
3. **Execute Sub-Sprint 1** - Build infrastructure
4. **Review Sub-Sprint 2** - Backend details
5. **Execute Sub-Sprint 2** - Build backend
6. **Review Sub-Sprint 3** - Frontend details
7. **Execute Sub-Sprint 3** - Build frontend
8. **Review Sub-Sprint 4** - Integration details
9. **Execute Sub-Sprint 4** - Complete integration
10. **Review Sub-Sprint 5** - Documentation details
11. **Execute Sub-Sprint 5** - Finalize documentation
12. **Demo Ready!** 🎉

---

## 📊 Progress Tracking

| Sub-Sprint | Status | Start Date | Completion Date |
|------------|--------|------------|-----------------|
| 1. Infrastructure | ✅ Complete | 2025-12-28 | 2025-12-29 |
| 2. Backend | ✅ Complete | 2025-12-29 | 2025-12-30 |
| 3. Frontend | Not Started | - | - |
| 4. Integration | 🟡 Partial | 2025-12-30 | - |
| 5. Documentation | 🟡 In Progress | 2025-12-29 | - |

**Current Status:** Sprint 2 Complete - Backend Fully Operational | Ready for Sprint 3 (Frontend Development)

---

## ✅ Definition of Done

The project is complete when:

- ✅ All infrastructure deployed and healthy on kind cluster
- ✅ Backend application running with SPIRE + OpenBao integration
- ✅ Frontend application with full UI functionality
- ✅ User authentication working (login/registration)
- ✅ Backend authenticates to OpenBao using SPIRE certificates (mTLS)
- ✅ GitHub integration functional (store + retrieve tokens from OpenBao)
- ✅ Dynamic database credentials working and rotating
- ✅ Cilium mTLS and SPIFFE policies enforced
- ✅ All demo users can login and use features
- ✅ `setup.sh` deploys everything with one command
- ✅ `demo.sh` provides guided walkthrough
- ✅ Documentation complete and clear
- ✅ Demo ready for technical team presentation

---

## 🎬 Demo Flow Overview

### **Part 1: Application & User Login (3 minutes)**
1. Show user login (Jake/Amy - traditional PostgreSQL auth)
2. Navigate to dashboard
3. Brief overview of application features

### **Part 2: Backend Workload Authentication (THE CORE DEMO - 5 minutes)**
4. Show backend pod getting SPIRE SVID (X.509 certificate)
5. Demonstrate backend authenticating to OpenBao using SPIRE cert (mTLS)
6. Show OpenBao logs validating the SPIFFE ID
7. Explain zero-trust workload identity

### **Part 3: GitHub Integration - Static Secrets (5 minutes)**
8. Configure GitHub API token via UI
9. Show backend storing token in OpenBao (using SPIRE auth)
10. Retrieve token from OpenBao
11. Fetch GitHub repositories using the token
12. Display repos in UI

### **Part 4: Database Access - Dynamic Secrets (5 minutes)**
13. Show backend requesting DB credentials from OpenBao
14. OpenBao creates temporary PostgreSQL user (v-token-backend-xyz)
15. Backend uses temp credentials to query database
16. Show credential expiration/rotation
17. Verify temp user deleted after TTL

### **Part 5: Cilium Network Security (5 minutes)**
18. Show Hubble flow with SPIFFE IDs
19. Demonstrate mTLS between services
20. Show SPIFFE-based network policy enforcement
21. Attempt unauthorized OpenBao access from frontend pod (denied)

### **Part 6: Q&A**
22. Answer technical questions
23. Show code snippets
24. Discuss production considerations

---

## 🚀 Next Steps

After reviewing this Master Sprint:

1. **Approve the overall plan**
2. **Proceed to Sub-Sprint 1 detailed document**
3. **Begin implementation of Sub-Sprint 1**
4. **Iterate through all sub-sprints**
5. **Deliver working demo**

---

## 📝 Notes

- This is a **demo/POC** environment, not production-ready
- Focus is on showcasing zero-trust architecture patterns
- ASAP timeline requires focused execution
- Technical audience allows for showing code/configs
- Brooklyn Nine-Nine theme makes it fun and memorable! 🚔
- All credentials are demo credentials (not secure for production)
- Infrastructure runs on local kind cluster (not cloud)

---

## 🔗 References

### **SPIRE/SPIFFE**
- SPIFFE Specification: https://github.com/spiffe/spiffe
- SPIRE Documentation: https://spiffe.io/docs/latest/
- SPIRE Kubernetes Quickstart: https://spiffe.io/docs/latest/try/getting-started-k8s/

### **OpenBao**
- OpenBao Official Website: https://openbao.org/
- OpenBao Documentation: https://openbao.org/docs/
- OpenBao GitHub Repository: https://github.com/openbao/openbao
- OpenBao Database Secrets Engine: https://openbao.org/docs/secrets/databases/postgresql/
- OpenBao Cert Auth Method: https://openbao.org/docs/auth/cert/
- OpenBao KV Secrets Engine: https://openbao.org/docs/secrets/kv/

### **Cilium**
- Cilium Documentation: https://docs.cilium.io/
- Cilium Service Mesh: https://docs.cilium.io/en/stable/network/servicemesh/
- Cilium + SPIRE: https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/

### **Integration Guides**
- SPIRE + Vault/OpenBao (OIDC): https://spiffe.io/docs/latest/keyless/vault/
- Cilium + SPIFFE: https://isovalent.com/blog/post/cilium-spiffe-spire/
- OpenBao vs HashiCorp Vault: https://digitalis.io/post/choosing-a-secrets-storage-hashicorp-vault-vs-openbao

---

**Document Version:** 2.2
**Last Updated:** 2025-12-29
**Author:** Development Team
**Status:** ✅ Master Sprint Complete - Best Practice Architecture - Ready for Sub-Sprint 1

**Changelog:**
- v2.2 (2025-12-29): Migrated from HashiCorp Vault to OpenBao (open-source fork, MPL 2.0 license)
- v2.1 (2025-12-29): Updated database connection strategy to use connection pool with periodic credential rotation (best practice)
- v2.0 (2025-12-29): Added Application Architecture, Technical Configuration Details, Database Schema, Application Flow Diagrams
- v1.0 (2025-12-29): Initial master sprint with sub-sprints overview

---

## 📞 Contact & Support

For questions or issues during implementation:
- Review the specific sub-sprint document
- Check troubleshooting guide (Sprint 5)
- Consult official documentation (links above)
- Demo deadline: ASAP

---

**End of Master Sprint Document**
