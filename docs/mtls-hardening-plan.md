# mTLS Hardening Plan

Roadmap for moving every service-to-service path from "identity-only" or plain
HTTP/TCP to full mutual TLS, using SPIRE-issued X.509-SVIDs wherever a workload
identity exists. Work proceeds phase by phase; each phase is independently
verifiable.

## Current State

| Path | Crypto identity today |
|------|----------------------|
| Backend ↔ SPIRE agent | ✅ py-spiffe SDK, Unix socket attestation |
| Backend → OpenBao | ⚠️ JWT-SVID over **HTTP** (identity yes, wire encryption no); X.509 cert auth scripted but inactive |
| Frontend → Backend | ❌ plain HTTP |
| Backend → PostgreSQL | ❌ plain TCP (dynamic creds, no TLS) |

Key facts:
- Cilium SPIFFE mTLS is disabled (`infrastructure/cilium/values.yaml` →
  `authentication.mutual.spiffe.enabled: false`). Network policies are
  label-based L3/L4 only.
- No Envoy/sidecar anywhere — all identity is app-level via the SPIFFE SDK.
  This plan keeps that approach.
- OpenBao TLS deployment already exists but is not the active mode:
  `infrastructure/openbao/deployment-tls.yaml`,
  `scripts/helpers/generate-vault-tls.sh`,
  `scripts/helpers/init-vault-tls.sh` (configures `auth/cert/certs/backend-role`
  bound to `spiffe://demo.local/ns/99-apps/sa/backend`).
- Backend already exposes SVID material:
  `backend/app/core/spire.py` → `get_certificate_pem()`, `get_private_key_pem()`.
- Backend auth selection lives in `backend/app/core/vault.py`: HTTPS → cert
  auth path possible; HTTP → JWT-SVID, falling back to root token in dev mode.

## Phase 1 — Backend → OpenBao mTLS (X.509 cert auth)  ✅ COMPLETED (2026-06-06)

Implemented and verified live:
- OpenBao runs TLS mode (`deployment-tls.yaml`, file storage, Shamir 5/3)
- Backend authenticates via `auth/cert/login` presenting its X.509-SVID
  (`VAULT_AUTH_METHOD=cert`, new `_authenticate_with_cert()` in
  `backend/app/core/vault.py`); SVID re-fetched and re-login every 45 min
- DB credentials now issued to cert-authenticated token
  (usernames `v-cert-bac-backend-...`)

Gotchas hit (now fixed in scripts/manifests):
- **Empty CN breaks cert auth twice:** SVID leaf has no CN by default →
  (a) `allowed_common_names` constraint fails — removed from role;
  (b) OpenBao builds the entity alias from CN → "missing name in alias" 500.
  Fix: add `-dns backend.99-apps.svc.cluster.local` to the backend SPIRE
  registration entries; SPIRE sets leaf CN to the first DNS name.
- **`bao write` does not clear omitted fields** — `allowed_common_names`
  had to be explicitly reset with `allowed_common_names=""`.
- **OpenBao pod has `readOnlyRootFilesystem`** — `kubectl cp` of bundle and
  policy files fails; `init-vault-tls.sh` now passes bundle inline and pipes
  policy via stdin.
- **hostNetwork SPIRE agents blocked by Cilium policy:** agents carry
  `host`/`remote-node` entity identity, not pod namespace; added
  `fromEntities: [host, remote-node]` to `spire-server-ingress-policy`.

Original plan below for reference.

### Phase 1 plan (original)

Goal: backend authenticates to OpenBao over HTTPS presenting its SPIRE
X.509-SVID as client certificate; OpenBao verifies it against the SPIRE trust
bundle and binds the SPIFFE ID to `backend-policy`.

### 1.1 Switch OpenBao to TLS mode
- Generate server TLS cert: `./scripts/helpers/generate-vault-tls.sh`
- Deploy `infrastructure/openbao/deployment-tls.yaml` (file storage + PVC,
  manual unseal: 5 keys / threshold 3)
- Initialize + unseal, then run `./scripts/helpers/init-vault-tls.sh`
  (enables cert auth, KV v2, database engine, writes `backend-role` with
  `allowed_uri_sans="spiffe://demo.local/ns/99-apps/sa/backend"`)
- Follow `docs/setup-guides/openbao-tls-setup.md` for details

### 1.2 Wire backend to HTTPS + client cert
- `backend/k8s/configmap.yaml`:
  - `VAULT_ADDR: https://openbao.openbao.svc.cluster.local:8200`
  - `VAULT_CACERT: /etc/vault-tls/ca.crt`
- Mount OpenBao CA cert into backend pod (Secret or ConfigMap volume)
- `backend/app/core/vault.py`:
  - When `is_https`, write SVID cert/key from `spire_client` to tmpfs files
    (hvac/requests need file paths) and call `auth/cert/login` with
    `cert=(cert_path, key_path)` and `verify=VAULT_CACERT`
  - Keep JWT-SVID path as fallback; remove root-token path when TLS active
- **SVID rotation caveat:** SVID TTL is 1 hour. Re-write cert/key files and
  re-login in the existing 45-minute refresh task (token TTL renewal alone is
  not enough once the client cert rotates).

### 1.3 Keep OpenBao trust bundle fresh
- Cert auth validates against the SPIRE bundle uploaded at init time. SPIRE CA
  rotation would break logins.
- Demo: document re-running the bundle upload step.
- Stretch: CronJob or sidecar-less watcher syncing `spire-bundle` ConfigMap →
  `auth/cert/certs/backend-role`.

### 1.4 Verify
- `bao read auth/cert/certs/backend-role` shows SPIFFE ID binding
- Backend logs show cert-auth login (no root token, no JWT path)
- `bao token lookup` on backend token → policy `backend-policy`, auth method `cert`
- Negative test: pod without backend SA / SVID cannot log in

## Phase 2 — Backend → PostgreSQL TLS

Goal: encrypt DB traffic; server-auth TLS first (Postgres can't consume
SPIFFE SVIDs natively without cert mapping).

- Generate Postgres server cert (reuse vault-tls script pattern or dedicated CA)
- StatefulSet: mount cert/key, set `ssl=on`, `ssl_cert_file`, `ssl_key_file`
- `pg_hba.conf`: `hostssl` entries only (reject non-TLS)
- Backend `asyncpg` pool: `ssl=ssl_context` with CA verification
  (`sslmode=verify-full` semantics)
- Stretch (true mTLS): `clientcert=verify-full` + map SVID SAN → dynamic
  usernames — hard because OpenBao-generated users (`v-token-backend-<uuid>`)
  are ephemeral; document tradeoff, likely keep password auth over TLS.

## Phase 3 — Frontend → Backend

Frontend (Next.js server) is a workload too — can get its own SVID.

Options (choose one):
- **A. App-level mTLS via SPIFFE SDK (consistent with project):**
  - SPIRE registration entry for `spiffe://demo.local/ns/99-apps/sa/frontend`
  - Backend: run uvicorn with TLS + `ssl_cert_reqs=CERT_REQUIRED`, trust =
    SPIRE bundle; verify client SPIFFE ID in middleware
  - Frontend Next.js API routes: `https.Agent` with SVID cert/key + SPIRE CA
  - Node has no workload-API client as mature as py-spiffe — fetch SVID via
    `spiffe-helper` sidecar-less init or small fetch script writing to shared
    volume
- **B. Enable Cilium SPIFFE mutual auth (`authentication.mutual.spiffe.enabled: true`):**
  - Transparent, no app changes, plus `authentication.mode: required` in
    CiliumNetworkPolicy
  - Note: Cilium mutual auth authenticates node/identity handshake; payload
    encryption requires also enabling WireGuard/IPsec — document precisely to
    avoid overclaiming "mTLS"
- Recommendation: A for demo value (visible SVIDs end-to-end), B as
  infrastructure showcase. Decide at phase start.

## Phase 4 — Cilium SPIFFE-based network policies

- Flip `authentication.mutual.spiffe.enabled: true` in Cilium values (requires
  Cilium ≥1.14 and pointing Cilium at the existing SPIRE server — see
  `docs/setup-guides/cilium-spire-integration.md`)
- Add `authentication.mode: required` to existing policies in
  `infrastructure/cilium/network-policies.yaml`
- Replace/augment label selectors with SPIFFE-aware enforcement
- Update `/demo` scenarios page: probes should now show identity-based blocks,
  not just label-based

## Sequencing & Effort

| Phase | Scope | Effort | Depends on |
|-------|-------|--------|-----------|
| 1 | OpenBao TLS + cert auth | S–M (infra exists, backend wiring + rotation) | — |
| 2 | Postgres TLS | S | — |
| 3 | Frontend↔Backend mTLS | M–L (Node SVID plumbing or Cilium) | Phase 4 if option B |
| 4 | Cilium SPIFFE auth | M (cluster reconfig) | — |

## Definition of Done (overall)

Every row in the current-state table reads ✅; demo page demonstrates at least
one mTLS handshake failure for an unauthorized identity; docs updated
(`CLAUDE.md` security model section + this file marked complete per phase).
