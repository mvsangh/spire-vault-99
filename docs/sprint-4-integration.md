# 🔒 SUB-SPRINT 4: Integration & Security

**Project:** SPIRE-Vault-99 Zero-Trust Demo Platform
**Sprint Type:** Integration & Security Hardening
**Prerequisites:** Sprint 1 (Infrastructure), Sprint 2 (Backend), Sprint 3 (Frontend UI)
**Status:** 🟡 Planning Complete - Ready for Implementation

---

## 📋 Overview

### Purpose
Complete the zero-trust architecture by:
1. Fixing frontend architecture (CORS resolution via Next.js API routes)
2. Enabling internal-only backend access (ClusterIP)
3. Implementing automatic mTLS between workloads (Cilium + SPIRE)
4. Enforcing network policies based on SPIFFE identities

### Critical Issue from Sprint 3
**Problem:** Frontend browser directly calls backend via NodePort, causing CORS errors and violating zero-trust principles.

**Solution:** Implement Backend for Frontend (BFF) pattern using Next.js API routes as proxy layer.

### Architecture Transformation

**Before (Sprint 3 - BROKEN):**
```
Browser → Backend NodePort (localhost:30001)
    ↓
CORS errors, no mTLS, backend exposed externally
```

**After (Sprint 4 - CORRECT):**
```
Browser → Frontend NodePort (localhost:30000)
            ↓
    Next.js API Routes (/api/*)
            ↓
    Backend ClusterIP (internal only)
            ↓
    mTLS with SPIRE certificates
    SPIFFE-based network policies
```

---

## 🎯 Sprint Goals

### Primary Goals
- [ ] Fix CORS issue by implementing Next.js API route handlers
- [ ] Remove external backend access (NodePort → ClusterIP)
- [ ] Enable Cilium SPIFFE integration for automatic mTLS
- [ ] Enforce zero-trust network policies using SPIFFE IDs

### Success Criteria
- ✅ No CORS errors in browser console
- ✅ All authentication flows work (login, register, logout)
- ✅ Backend only accessible via internal cluster DNS
- ✅ Frontend ↔ Backend communication uses mTLS
- ✅ Network policies enforce SPIFFE-based access control
- ✅ All demo features functional (GitHub integration, dashboard)

---

## 📊 Phase Breakdown

| Phase | Description | Priority | Estimated Time | Dependencies |
|-------|-------------|----------|----------------|--------------|
| **4A** | Frontend Architecture Refactor | 🔴 CRITICAL | 2-3 hours | None |
| **4B** | Network Architecture Updates | 🟡 HIGH | 30 minutes | Phase 4A |
| **4C** | Cilium SPIFFE Integration | 🟡 HIGH | 1-2 hours | Phase 4B |
| **4D** | Network Policies & Testing | 🟢 MEDIUM | 1 hour | Phase 4C |

**Total Estimated Time:** 4.5-6.5 hours

---

## 🔧 Phase 4A: Frontend Architecture Refactor

### Overview
**Goal:** Fix CORS by implementing Next.js API Route handlers as proxy layer.

**Why This Fixes CORS:**
- Browser calls Next.js server (same origin: `localhost:30000`)
- Next.js server calls backend internally (cluster DNS)
- No cross-origin requests from browser perspective

### Tasks

#### Task 4A.1: Create Authentication API Routes

**Files to Create:**

1. **`frontend/app/api/auth/login/route.ts`**
   ```typescript
   import { NextRequest, NextResponse } from 'next/server';

   const BACKEND_URL = process.env.BACKEND_URL || 'http://backend.99-apps.svc.cluster.local:8000';

   export async function POST(request: NextRequest) {
     try {
       const body = await request.json();

       const response = await fetch(`${BACKEND_URL}/api/v1/auth/login`, {
         method: 'POST',
         headers: { 'Content-Type': 'application/json' },
         body: JSON.stringify(body),
       });

       const data = await response.json();

       if (!response.ok) {
         return NextResponse.json(data, { status: response.status });
       }

       const setCookieHeader = response.headers.get('set-cookie');
       const nextResponse = NextResponse.json(data);

       if (setCookieHeader) {
         nextResponse.headers.set('Set-Cookie', setCookieHeader);
       }

       return nextResponse;
     } catch (error) {
       return NextResponse.json(
         { detail: 'Internal server error' },
         { status: 500 }
       );
     }
   }
   ```

2. **`frontend/app/api/auth/register/route.ts`**
   - Similar pattern to login
   - Proxies POST to `/api/v1/auth/register`

3. **`frontend/app/api/auth/logout/route.ts`**
   - Proxies POST to `/api/v1/auth/logout`
   - Clears auth cookie

4. **`frontend/app/api/auth/me/route.ts`**
   - Proxies GET to `/api/v1/auth/me`
   - Forwards cookies from browser request

#### Task 4A.2: Create GitHub Integration API Routes

**Files to Create:**

5. **`frontend/app/api/github/configure/route.ts`**
   - Proxies POST to `/api/v1/github/configure`
   - Forwards auth cookies

6. **`frontend/app/api/github/repos/route.ts`**
   - Proxies GET to `/api/v1/github/repos`

7. **`frontend/app/api/github/user/route.ts`**
   - Proxies GET to `/api/v1/github/user`

#### Task 4A.3: Create Health Check API Route

**Files to Create:**

8. **`frontend/app/api/health/ready/route.ts`**
   - Proxies GET to `/api/v1/health/ready`

**Total API Routes:** 8 files

#### Task 4A.4: Update Frontend API Client

**File to Modify:** `frontend/lib/api/client.ts`

**Change:**
```typescript
// BEFORE (calls backend directly - WRONG):
const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:30001';

// AFTER (calls Next.js API routes - CORRECT):
const API_URL = '/api'; // Relative path, same origin
```

**Impact:** All axios calls now go to `/api/*` instead of `http://localhost:30001/*`

#### Task 4A.5: Update Kubernetes Configuration

**File to Modify:** `frontend/k8s/configmap.yaml`

**Change:**
```yaml
# BEFORE:
data:
  NEXT_PUBLIC_API_URL: "http://localhost:30001"

# AFTER:
data:
  # Backend URL for server-side API calls (internal cluster DNS)
  BACKEND_URL: "http://backend.99-apps.svc.cluster.local:8000"

  # App metadata
  NEXT_PUBLIC_APP_NAME: "SPIRE-Vault-99"
  NEXT_PUBLIC_APP_VERSION: "1.0.0"
```

**Note:** `BACKEND_URL` is NOT prefixed with `NEXT_PUBLIC_` because it's used server-side only (not exposed to browser).

#### Task 4A.6: Rebuild and Deploy

**Steps:**
1. Build Docker image: `docker build -t frontend:latest .`
2. Load to kind cluster: `kind load docker-image frontend:latest --name precinct-99`
3. Restart deployment: `kubectl rollout restart -n 99-apps deployment/frontend`
4. Verify: `kubectl get pods -n 99-apps -l app=frontend`

### Testing for Phase 4A

**Test 1: CORS Resolution**
- Open browser to `http://localhost:30000/auth/login`
- Open DevTools → Network tab
- Enter credentials and submit
- **VERIFY:** Request goes to `http://localhost:30000/api/auth/login` (NOT 30001)
- **VERIFY:** No CORS errors in console
- **VERIFY:** Response status 200

**Test 2: Cookie Handling**
- After successful login
- Check Application → Cookies in DevTools
- **VERIFY:** Auth cookie present with `httpOnly` flag
- **VERIFY:** Subsequent requests include cookie

**Test 3: Protected Routes**
- After login, navigate to `/dashboard`
- **VERIFY:** Dashboard loads without errors
- **VERIFY:** User info displayed

**Test 4: GitHub Integration**
- Navigate to `/github`
- Configure token
- **VERIFY:** Token saved (check backend logs for Vault write)
- Load repositories
- **VERIFY:** Repos display correctly

### Success Criteria for Phase 4A
- ✅ No CORS errors
- ✅ Login/register/logout work
- ✅ httpOnly cookies function correctly
- ✅ All API calls go to `/api/*`
- ✅ GitHub integration functional

---

## 🌐 Phase 4B: Network Architecture Updates

### Overview
**Goal:** Remove external backend access, enforce internal-only communication.

### Tasks

#### Task 4B.1: Change Backend Service Type

**File to Modify:** `backend/k8s/service.yaml`

**Change:**
```yaml
# BEFORE (exposed via NodePort):
spec:
  type: NodePort
  ports:
  - port: 8000
    targetPort: 8000
    nodePort: 30001  # ← REMOVE

# AFTER (internal only):
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: http
```

**Impact:** Backend NO LONGER accessible at `http://localhost:30001`

#### Task 4B.2: Apply Changes

**Steps:**
```bash
kubectl apply -f backend/k8s/service.yaml
kubectl get svc -n 99-apps backend
```

**Verify:** Service type changed to ClusterIP (no NodePort listed)

### Testing for Phase 4B

**Test 1: External Access Blocked**
```bash
curl http://localhost:30001/api/v1/health
# Expected: Connection refused
```

**Test 2: Internal Access Works**
```bash
kubectl run curl-test --image=curlimages/curl:latest --rm -it --restart=Never -- \
  curl -s http://backend.99-apps.svc.cluster.local:8000/api/v1/health
# Expected: {"status":"ready",...}
```

**Test 3: Frontend Still Works**
- Open browser to `http://localhost:30000`
- Login and test all features
- **VERIFY:** Everything works (frontend proxies to backend internally)

### Success Criteria for Phase 4B
- ✅ Backend not accessible externally (localhost:30001 fails)
- ✅ Backend accessible via cluster DNS
- ✅ Frontend continues to work normally

---

## 🔐 Phase 4C: Cilium SPIFFE Integration

### Overview
**Goal:** Enable automatic mTLS between frontend ↔ backend using SPIRE certificates.

### Architecture

**How Cilium SPIFFE Integration Works:**
1. Cilium connects to SPIRE server
2. Each pod gets SPIFFE ID via SPIRE agent
3. Cilium intercepts traffic between pods
4. Cilium fetches X.509-SVIDs from SPIRE for both source and destination
5. Cilium establishes mTLS tunnel automatically
6. Application code unchanged (transparent mTLS)

### Tasks

#### Task 4C.1: Create Cilium SPIFFE Configuration

**File to Create:** `infrastructure/cilium/spiffe-values.yaml`

```yaml
# Cilium Helm values for SPIFFE integration

authentication:
  mutual:
    spiffe:
      enabled: true
      install:
        enabled: false  # Use existing SPIRE installation
        server:
          address: spire-server.spire-system.svc.cluster.local:8081
          trustDomain: "demo.local"

# Enable Hubble for SPIFFE observability
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true

# Existing config (preserve)
operator:
  replicas: 1

ipam:
  mode: kubernetes

policyEnforcementMode: default
```

#### Task 4C.2: Upgrade Cilium

**Command:**
```bash
helm upgrade cilium cilium/cilium \
  --version 1.15.7 \
  --namespace kube-system \
  -f infrastructure/cilium/spiffe-values.yaml
```

**Verify:**
```bash
kubectl exec -n kube-system ds/cilium -- cilium status | grep -i spiffe
# Expected: SPIFFE enabled, connected to SPIRE server
```

#### Task 4C.3: Create SPIRE Registration Entry for Frontend

**Command:**
```bash
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://demo.local/ns/99-apps/sa/frontend \
    -parentID spiffe://demo.local/spire/agent/k8s_psat/precinct-99 \
    -selector k8s:ns:99-apps \
    -selector k8s:sa:frontend \
    -ttl 3600
```

**Verify:**
```bash
kubectl exec -n spire-system spire-server-0 -- \
  /opt/spire/bin/spire-server entry show | grep frontend
# Expected: spiffe://demo.local/ns/99-apps/sa/frontend
```

### Testing for Phase 4C

**Test 1: Verify SPIFFE Integration**
```bash
kubectl exec -n kube-system ds/cilium -- cilium status
# Look for: SPIFFE: enabled
```

**Test 2: Observe mTLS with Hubble**
```bash
kubectl exec -n kube-system ds/cilium -- \
  hubble observe --from-label app=frontend --to-label app=backend --last 10
# Expected: TLS handshake visible, SPIFFE IDs shown
```

**Test 3: Application Still Works**
- Open browser, login, test all features
- **VERIFY:** No errors (mTLS is transparent)

**Test 4: Verify Encryption**
```bash
# Get backend pod IP
BACKEND_IP=$(kubectl get pod -n 99-apps -l app=backend -o jsonpath='{.items[0].status.podIP}')

# Capture traffic (should see encrypted TLS)
kubectl exec -n 99-apps <frontend-pod> -- \
  tcpdump -i any -n host $BACKEND_IP -A -c 20
# Expected: TLS handshake, encrypted data (gibberish)
```

### Success Criteria for Phase 4C
- ✅ Cilium shows SPIFFE enabled
- ✅ Frontend has SPIFFE ID assigned
- ✅ Hubble shows mTLS traffic
- ✅ Traffic is encrypted (tcpdump verification)
- ✅ Application works normally

---

## 🛡️ Phase 4D: Network Policies & Integration Testing

### Overview
**Goal:** Enforce zero-trust network policies using SPIFFE identities.

### Tasks

#### Task 4D.1: Create Network Policies

**File to Create:** `infrastructure/cilium/network-policies.yaml`

```yaml
---
# Policy 1: Only Frontend can access Backend
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: backend-ingress-policy
  namespace: 99-apps
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "8000"
        protocol: TCP
  # SPIFFE-based rule
  - fromSPIFFE:
    - "spiffe://demo.local/ns/99-apps/sa/frontend"
    toPorts:
    - ports:
      - port: "8000"
        protocol: TCP

---
# Policy 2: Only Backend can access PostgreSQL
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: postgresql-ingress-policy
  namespace: 99-apps
spec:
  endpointSelector:
    matchLabels:
      app: postgresql
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: backend
    toPorts:
    - ports:
      - port: "5432"
        protocol: TCP
  # SPIFFE-based rule
  - fromSPIFFE:
    - "spiffe://demo.local/ns/99-apps/sa/backend"
    toPorts:
    - ports:
      - port: "5432"
        protocol: TCP

---
# Policy 3: Only Backend can access OpenBao
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: openbao-ingress-policy
  namespace: openbao
spec:
  endpointSelector:
    matchLabels:
      app: openbao
  ingress:
  - fromEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: 99-apps
        app: backend
    toPorts:
    - ports:
      - port: "8200"
        protocol: TCP
  # SPIFFE-based rule
  - fromSPIFFE:
    - "spiffe://demo.local/ns/99-apps/sa/backend"
    toPorts:
    - ports:
      - port: "8200"
        protocol: TCP
```

#### Task 4D.2: Apply Network Policies

**Command:**
```bash
kubectl apply -f infrastructure/cilium/network-policies.yaml
```

**Verify:**
```bash
kubectl get ciliumnetworkpolicies -n 99-apps
kubectl get ciliumnetworkpolicies -n openbao
```

### Testing for Phase 4D

**Test 1: Allowed Connections Work**
```bash
# Frontend → Backend (ALLOWED)
kubectl exec -n 99-apps <frontend-pod> -- \
  wget -qO- http://backend.99-apps:8000/api/v1/health

# Backend → PostgreSQL (ALLOWED)
kubectl exec -n 99-apps <backend-pod> -- \
  pg_isready -h postgresql.99-apps -p 5432

# Backend → OpenBao (ALLOWED)
kubectl exec -n 99-apps <backend-pod> -- \
  wget -qO- http://openbao.openbao:8200/v1/sys/health
```

**Test 2: Denied Connections Blocked**
```bash
# Frontend → PostgreSQL (DENIED)
kubectl exec -n 99-apps <frontend-pod> -- \
  timeout 5 wget -qO- http://postgresql.99-apps:5432
# Expected: Timeout or connection refused

# Frontend → OpenBao (DENIED)
kubectl exec -n 99-apps <frontend-pod> -- \
  timeout 5 wget -qO- http://openbao.openbao:8200
# Expected: Timeout or connection refused
```

**Test 3: Hubble Policy Verdicts**
```bash
kubectl exec -n kube-system ds/cilium -- \
  hubble observe --verdict DENIED --last 20
# Expected: See denied connections from frontend to DB/Vault
```

### End-to-End Integration Tests

**Scenario 1: Complete User Journey**
1. Navigate to `http://localhost:30000`
2. Register new user
3. Login
4. View dashboard
5. Configure GitHub token
6. Load repositories
7. View profile
8. Logout

**Scenario 2: Security Verification**
- Verify backend not accessible externally
- Verify mTLS between frontend ↔ backend
- Verify network policies enforce access control

### Success Criteria for Phase 4D
- ✅ All network policies applied
- ✅ Allowed traffic works
- ✅ Denied traffic blocked
- ✅ Hubble shows policy enforcement
- ✅ End-to-end user flows work

---

## 📝 Implementation Checklist

### Phase 4A: Frontend Refactor
- [ ] Create 8 Next.js API route handlers
- [ ] Update `lib/api/client.ts` (baseURL to `/api`)
- [ ] Update `k8s/configmap.yaml` (add BACKEND_URL)
- [ ] Rebuild and deploy frontend
- [ ] Test CORS resolution
- [ ] Test authentication flows
- [ ] Test GitHub integration

### Phase 4B: Network Architecture
- [ ] Change backend service to ClusterIP
- [ ] Apply service changes
- [ ] Test external access blocked
- [ ] Test internal access works
- [ ] Test frontend still functional

### Phase 4C: Cilium SPIFFE
- [ ] Create Cilium SPIFFE values file
- [ ] Upgrade Cilium with SPIFFE enabled
- [ ] Create frontend SPIRE registration entry
- [ ] Verify SPIFFE integration
- [ ] Test mTLS establishment
- [ ] Verify encryption with tcpdump

### Phase 4D: Network Policies
- [ ] Create network policy manifests
- [ ] Apply policies
- [ ] Test allowed connections
- [ ] Test denied connections
- [ ] Verify with Hubble
- [ ] End-to-end testing

---

## 🎯 Overall Success Criteria

### Functional Requirements
- ✅ All user-facing features work (login, register, dashboard, GitHub)
- ✅ No CORS errors
- ✅ httpOnly cookies work correctly
- ✅ Protected routes enforce authentication

### Security Requirements
- ✅ Backend not accessible externally
- ✅ Frontend ↔ Backend uses mTLS with SPIRE certificates
- ✅ Network policies enforce SPIFFE-based access control
- ✅ Only backend can access PostgreSQL and OpenBao

### Zero-Trust Demonstration
- ✅ Workload identity (SPIFFE IDs) assigned to all pods
- ✅ Automatic mTLS between workloads (Cilium + SPIRE)
- ✅ Network policies based on workload identity (not pod labels)
- ✅ Observable security (Hubble shows SPIFFE IDs and mTLS)

---

## 📚 References

- [Next.js API Routes](https://nextjs.org/docs/app/building-your-application/routing/route-handlers)
- [Cilium SPIFFE Integration](https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/)
- [SPIRE + Vault Integration](https://spiffe.io/docs/latest/keyless/vault/)
- [Cilium Network Policies](https://docs.cilium.io/en/stable/security/policy/)

---

**Document Version:** 1.0
**Created:** 2026-01-02
**Status:** Ready for Implementation
