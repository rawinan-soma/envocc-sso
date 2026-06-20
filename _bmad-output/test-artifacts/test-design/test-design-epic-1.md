---
workflowStatus: 'completed'
totalSteps: 5
stepsCompleted: ['step-01-detect-mode', 'step-02-load-context', 'step-03-risk-and-testability', 'step-04-coverage-plan', 'step-05-generate-output']
lastStep: 'step-05-generate-output'
nextStep: ''
lastSaved: '2026-06-20'
inputDocuments:
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/implementation-artifacts/sprint-status.yaml
  - _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-19/prd.md
---

# Test Design: Epic 1 — Keycloak IdP Foundation & SSO Core

**Date:** 2026-06-20
**Author:** Rawinan
**Status:** Draft

---

## Executive Summary

**Scope:** Epic-level test design for Epic 1 (8 stories, all `backlog` status)

Epic 1 establishes the entire authentication foundation: Keycloak stand-up, realm config-as-code, OIDC client hardening (Auth Code + PKCE only), RS256 realm keys with rotation, token/session lifecycle, password policy + brute-force protection, canonical identity model + work-email claim, and end-to-end SSO proof via a reference client. Every downstream epic depends on this foundation being correct and secure.

**Risk Summary:**

- Total risks identified: 14
- High-priority risks (score ≥ 6): 7
- Critical categories: SEC (5), OPS (3), TECH (3), DATA (2), PERF (1)

**Coverage Summary:**

- P0 scenarios: 22 (~44–55 hours)
- P1 scenarios: 18 (~18–27 hours)
- P2 scenarios: 14 (~7–14 hours)
- P3 scenarios: 5 (~1–3 hours)
- **Total effort**: ~70–99 hours (~9–12 days)

---

## Not in Scope

| Item | Reasoning | Mitigation |
| ---- | --------- | ---------- |
| **Ministry Bronze Keycloak theme** | Epic 2 owns all theme/branding work | Theme tested in Epic 2 test design |
| **First-login activation flow (end-to-end)** | Epic 2 owns activation UX + email action token hygiene | Story 1.5 tests pending state model only; transitions in Epic 2 |
| **Per-IP brute-force protection (Nginx)** | Nginx edge is Epic 6 scope | Epic 1 tests Keycloak per-account brute-force only |
| **Off-host WORM audit shipping** | Epic 5 owns the off-host sink wiring | Story 1.8 tests that events are enabled and captured locally |
| **Admin REST API (Rails layer)** | Epic 3 & 4 own the Rails admin app | Epic 1 tests Keycloak natively; no Rails code yet |
| **CSV bulk import, client registration UI** | Epics 3 & 4 | Not relevant to the IdP core |
| **HA/clustering** | Explicitly deferred by architecture | Single instance; revisit if NFR17 demands change |

---

## Risk Assessment

### High-Priority Risks (Score ≥ 6)

| Risk ID | Category | Description | Probability | Impact | Score | Mitigation | Owner | Timeline |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ---------- | ----- | -------- |
| R-001 | SEC | Implicit or ROPC grants not disabled — weaker flows accessible if misconfigured | 2 | 3 | 6 | Automated API test asserts only `standard_flow_enabled=true`; all other flows `false`; regression on realm import | Dev/QA | Story 1.2 |
| R-002 | SEC | PKCE `S256` not enforced — PKCE `plain` or absent allowed by default in some KC versions | 2 | 3 | 6 | Test auth request without PKCE verifier and with `plain` method; assert rejection; check `pkceCodeChallengeMethod` realm client field | Dev/QA | Story 1.2 |
| R-003 | SEC | Wildcard or substring redirect URI accepted — OIDC redirect-URI hijacking vector | 2 | 3 | 6 | Test registration with `*`/subdomain wildcard; assert Keycloak rejects; test near-miss redirect URIs | Dev/QA | Story 1.2 |
| R-004 | SEC | `alg:none` or weak algorithm accepted for token validation — crypto bypass | 1 | 3 | 3 | Test token signed with `alg:none`; assert rejection; confirm JWKS returns only RS256 keys | Dev/QA | Story 1.3 |
| R-005 | SEC | Refresh token reuse — stolen refresh token allows unbounded session extension | 2 | 3 | 6 | Test refresh-token replay after first use; assert second use is rejected and the family is revoked | Dev/QA | Story 1.3 |
| R-006 | SEC | Secret committed to git (realm export includes credentials, `.env` committed) | 2 | 3 | 6 | gitleaks pre-commit + CI hook; test realm export is secrets-stripped; CI `gitleaks` scan asserts clean history | Dev/QA | Story 1.1 |
| R-007 | SEC | TOTP single-use not enforced — OTP replay within the drift window | 2 | 3 | 6 | Test immediate reuse of a valid OTP code; assert second use within step is rejected | Dev/QA | Story 1.6 |
| R-008 | OPS | Keycloak fails to start or import realm on `docker compose up` — blocks all dev | 2 | 3 | 6 | Smoke test: assert Keycloak health endpoint `200` + realm exists after `docker compose up`; run in CI | Dev/QA | Story 1.1 |
| R-009 | TECH | Realm config drift — `realm-export.json` diverges from the running instance | 2 | 2 | 4 | Realm-config lint in CI (compare key fields from exported JSON vs running instance via Admin API); alert on drift | Dev | Story 1.1 |
| R-010 | DATA | `sub` (user ID) accidentally reused on user delete+recreate — breaks reconciliation | 1 | 3 | 3 | Confirm Keycloak generates UUIDs not recycled IDs; add a test that verifies `sub` uniqueness after delete | Dev/QA | Story 1.5 |
| R-011 | OPS | SMTP dependency not mocked in CI — activation/reset tests fail flakily | 2 | 2 | 4 | Integrate mailpit in `docker compose`; CI uses mailpit SMTP endpoint; assert email delivery in tests | Dev | Epic 1/2 |
| R-012 | TECH | Access/ID token lifetime > 15 min — violates NFR2a; downstream apps have long exposure windows | 2 | 2 | 4 | Assert `accessTokenLifespan` ≤ 900 (15 min) in realm settings test | Dev/QA | Story 1.3 |
| R-013 | PERF | Argon2id params below OWASP floor — password verification too fast, offline cracking risk | 1 | 3 | 3 | Query realm password policy settings; assert Argon2id memory ≥ 19 MiB, iterations ≥ 2, parallelism = 1 | Dev/QA | Story 1.4 |
| R-014 | OPS | Key-loss scenario untested — realm key backup/recovery runbook never validated | 2 | 3 | 6 | Test: export realm + DB backup, delete realm key provider, restore, confirm JWKS and token issuance work | Dev | Story 1.3 |

### Medium-Priority Risks (Score 3–4)

| Risk ID | Category | Description | Probability | Impact | Score | Mitigation | Owner |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ---------- | ----- |
| R-009 | TECH | Realm config drift | 2 | 2 | 4 | Realm-config lint in CI | Dev |
| R-011 | OPS | SMTP dependency flakiness | 2 | 2 | 4 | mailpit in docker compose | Dev |
| R-012 | TECH | Token lifetime > 15 min | 2 | 2 | 4 | Realm settings assertion test | Dev/QA |
| R-004 | SEC | `alg:none` bypass | 1 | 3 | 3 | Token rejection test | Dev/QA |
| R-010 | DATA | Sub reuse after delete | 1 | 3 | 3 | Uniqueness assertion test | Dev/QA |
| R-013 | PERF | Argon2id below OWASP floor | 1 | 3 | 3 | Realm policy assertion | Dev/QA |

### Low-Priority Risks (Score 1–2)

| Risk ID | Category | Description | Probability | Impact | Score | Action |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ------ |
| R-015 | BUS | `.well-known` discovery returns stale cached data | 1 | 2 | 2 | Monitor |
| R-016 | OPS | Keycloak version unpin causes unexpected breaking change | 1 | 2 | 2 | Monitor |

### Risk Category Legend

- **TECH**: Technical/Architecture (flaws, integration, scalability)
- **SEC**: Security (access controls, auth, data exposure)
- **PERF**: Performance (SLA violations, degradation, resource limits)
- **DATA**: Data Integrity (loss, corruption, inconsistency)
- **BUS**: Business Impact (UX harm, logic errors, revenue)
- **OPS**: Operations (deployment, config, monitoring)

---

## NFR Planning

**Purpose:** Capture Epic 1 NFR thresholds, planned validation approach, and evidence to collect for later `nfr-assess`. Not a final PASS/FAIL audit.

| NFR Category | Requirement / Threshold | Risk Link | Planned Validation | Evidence Needed |
| ------------ | ----------------------- | --------- | ------------------ | --------------- |
| **Security — Crypto** | Argon2id ≥ 19 MiB / ≥ 2 iter / p=1 (NFR1) | R-013 | Admin API: query realm password policy; assert params meet OWASP floor | Realm policy API response + test assertion |
| **Security — Token TTL** | Access/ID token ≤ 15 min (NFR2a) | R-012 | Assert `accessTokenLifespan` ≤ 900 in realm settings API | Realm settings JSON + test assertion |
| **Security — Signing** | RS256 only; `alg:none` rejected; active/passive key overlap ≥ token TTL (NFR3) | R-004, R-014 | JWKS fetch + `alg:none` token rejection test; key-rotation overlap config assertion | JWKS response; token-rejection test output; realm key-providers API |
| **Security — TLS/Cookies** | Secure/HttpOnly/SameSite cookies; CSP `frame-ancestors 'none'` (NFR4) | — | Response-header assertions on auth endpoints; cookie attribute checks in E2E | HTTP response headers from test run |
| **Security — Standards** | RFC 9700 / OIDC conformance; PKCE `S256` required (NFR5) | R-001, R-002 | OIDC flow conformance tests; Keycloak `.well-known` validation; reject Implicit/ROPC | Conformance test report |
| **Security — ASVS** | OWASP ASVS L2 on the Keycloak hardening config (NFR6) | R-001–R-007 | Manual hardening checklist + automated config assertions per ASVS L2 controls | ASVS checklist completion + test pass evidence |
| **Security — Password Policy** | NIST SP 800-63B: ≥12 chars, no composition rules, breached-password check (NFR7) | R-013 | Realm password policy assertion + negative tests: short passwords, breached passwords | Realm policy API + test pass/fail log |
| **Maintainability** | No hand-rolled crypto/token/session; audited gems only (NFR8) | — | `bundler-audit` + `brakeman` in CI; code review: no auth primitives re-implemented in Epic 1 | CI scan results |
| **Reliability** | `docker compose up` → Keycloak healthy + realm imported in < 2 min (no threshold stated) | R-008 | Smoke test timing in CI; health endpoint polling | CI timing + health check response |
| **Performance** | p95 ≤ 500 ms for login/token endpoints (NFR18) | — | Lightweight baseline timing in E2E (not a load test at this stage; deferred to Epic 6) | p95 timing from E2E runs (Epic 6 for formal load test) |

**Unknown thresholds:**
- Exact Keycloak startup time SLA — not defined in PRD/arch; UNKNOWN. Assumption: < 2 min in dev is acceptable for CI; no production boot-time gate until Epic 6.
- Formal p95 load-test threshold validation — deferred to Epic 6 (NFR18 is acknowledged but Epic 1 only collects a baseline).

---

## Entry Criteria

- [ ] Story acceptance criteria agreed upon by Dev and QA
- [ ] `docker compose up` stack available locally and in CI (Keycloak + Postgres + mailpit)
- [ ] Keycloak Admin API accessible at the configured URL
- [ ] `gitleaks` pre-commit hook installed and verified
- [ ] Test fixture user factories defined (credentials generated at runtime, never committed)
- [ ] Realm-config lint script available in CI
- [ ] RSpec + system-test harness scaffolded (Story 1.1 prerequisite)

## Exit Criteria

- [ ] All P0 tests passing (100%)
- [ ] All P1 tests passing (≥ 95%)
- [ ] All 7 high-risk items (score ≥ 6) mitigated with passing tests
- [ ] Security category tests passing 100%
- [ ] `gitleaks` CI scan returns clean on the Epic 1 branch
- [ ] `bundler-audit` + `brakeman` CI scans pass
- [ ] Reference client (Story 1.7) successfully completes an OIDC sign-in and validates the ID token
- [ ] Keycloak events captured (login + admin) confirmed via Admin API (Story 1.8)

---

## Test Coverage Plan

### P0 (Critical) — Run on every commit

**Criteria:** Blocks core auth journey + high risk (≥ 6) + no workaround

| Story | Requirement | Scenario | Test Level | Risk Link | Test Count | Owner |
| ----- | ----------- | -------- | ---------- | --------- | ---------- | ----- |
| 1.1 | Keycloak starts + realm imports | `docker compose up` → health `/health/live` 200 + realm `envocc` exists | API/Smoke | R-008 | 2 | Dev |
| 1.1 | Secret hygiene | `gitleaks` scan: realm-export.json secrets-stripped; `.env` gitignored | CI | R-006 | 2 | Dev |
| 1.2 | Only Standard flow enabled | Admin API: assert `standardFlowEnabled=true`; `implicitFlowEnabled=false`; `directAccessGrantsEnabled=false` | API | R-001 | 3 | QA |
| 1.2 | PKCE S256 required | Auth request without PKCE → assert rejected; auth request with `plain` method → assert rejected | API | R-002 | 2 | QA |
| 1.2 | Exact redirect-URI match | Register client with wildcard `*` URI → assert Keycloak rejects; attempt redirect to unregistered near-miss URI → assert error | API | R-003 | 3 | QA |
| 1.2 | Authorization code single-use | Exchange code once → success; replay same code → assert 400/error | API | R-003 | 2 | QA |
| 1.3 | RS256 JWKS published with `kid` | `GET /realms/envocc/protocol/openid-connect/certs` → RS256 key with `kid` present | API | R-004 | 1 | QA |
| 1.3 | `alg:none` token rejected | Submit token signed with `alg:none` → assert introspect/userinfo rejects | API | R-004 | 1 | QA |
| 1.3 | Access token lifetime ≤ 15 min | Issue token; decode; assert `exp - iat ≤ 900` | API | R-012 | 1 | QA |
| 1.3 | Refresh-token reuse revocation | Use refresh token once → success; reuse same refresh token → assert rejected + family revoked | API | R-005 | 2 | QA |
| 1.5 | Stable `sub` per user | Create user → get `sub`; re-fetch → same `sub` | API | R-010 | 1 | QA |
| 1.5 | Work-email claim in ID token | Authenticate fixture user; decode ID token; assert work-email claim present + correct value | E2E/API | — | 1 | QA |
| 1.6 | Full sign-in: email + password + TOTP | E2E: fixture active user signs in → password step → OTP step → session established | E2E | R-007 | 1 | QA |
| 1.6 | TOTP replay within same step rejected | Submit valid OTP → success; immediately submit same OTP again (within step) → assert rejected | API | R-007 | 1 | QA |
| 1.7 | Reference client receives valid ID token | Reference client completes Auth Code + PKCE flow; validates signature via JWKS; asserts `iss`/`aud`/`exp`/`nonce`; displays work-email claim | E2E | — | 1 | Dev/QA |

**Total P0:** 27 test cases, ~44–55 hours (complex security setup per test)

---

### P1 (High) — Run on PR to main

**Criteria:** Important security/compliance features + medium risk (3–5) + common workflows

| Story | Requirement | Scenario | Test Level | Risk Link | Test Count | Owner |
| ----- | ----------- | -------- | ---------- | --------- | ---------- | ----- |
| 1.1 | Realm config lint | CI: compare `realm-export.json` key fields vs running Keycloak via Admin API; assert no drift | API/CI | R-009 | 2 | Dev |
| 1.1 | Pre-commit hook blocks secrets | Stage a file with a fake credential pattern → assert lefthook/gitleaks blocks commit | Integration | R-006 | 1 | Dev |
| 1.2 | `.well-known` discovery document valid | `GET /.well-known/openid-configuration` returns valid JSON with required endpoints | API | — | 1 | QA |
| 1.2 | `nonce` binding in ID token | Auth request with `nonce=xyz`; assert ID token contains `nonce=xyz` | API | — | 1 | QA |
| 1.2 | `state` parameter echoed in callback | Assert `state` value from auth request matches callback `state` | API | — | 1 | QA |
| 1.3 | Active/passive key overlap configured | Admin API: assert ≥ 2 realm key providers; at least one active + one passive | API | R-014 | 2 | QA |
| 1.3 | Key rotation + old tokens still valid | Rotate realm key to new active; verify token issued with old `kid` is still accepted during overlap | API | R-014 | 1 | QA |
| 1.3 | Realm backup/restore recovery | Export realm + pg_dump; delete key provider; restore from export + DB; confirm JWKS and token issuance | Integration | R-014 | 1 | Dev |
| 1.4 | SSO session spans two clients | Sign into client A → open client B without re-auth → assert session reused (SSO works) | E2E | — | 1 | QA |
| 1.4 | Absolute session timeout enforced | Set short absolute timeout; wait for expiry; attempt token refresh → assert rejected | API | — | 1 | QA |
| 1.4 | RP-initiated logout | Trigger end-session endpoint; assert Keycloak session terminated; assert post-logout redirect honored | E2E/API | — | 2 | QA |
| 1.4 | Session-id regenerated on auth transition | Compare session cookie before and after login step → assert session-id changed | E2E | — | 1 | QA |
| 1.4 | Brute-force: account lockout after N failures | Submit wrong password N times → assert lockout triggered (wait message / disabled); correct password also rejected during lockout | API | — | 1 | QA |
| 1.4 | Enumeration-resistant responses | Failed login for known user vs unknown user → assert HTTP status and body are identical | API | — | 1 | QA |
| 1.5 | Unique work email enforced | Attempt to create second user with same email → assert Keycloak rejects | API | — | 1 | QA |
| 1.5 | Pending lifecycle state correct | Create user with required actions `UPDATE_PASSWORD`+`CONFIGURE_TOTP` → Admin API asserts those actions set and `emailVerified=false` | API | — | 1 | QA |
| 1.6 | Invalid OTP code rejected generically | Submit wrong 6-digit OTP → assert rejected; response message is generic | API | — | 1 | QA |
| 1.8 | Login events captured | After sign-in flow; Admin API `GET /events` → assert login success event present with source IP | API | — | 1 | QA |
| 1.8 | Admin events captured | Perform an admin action (create user); Admin API `GET /admin/events` → assert action recorded | API | — | 1 | QA |

**Total P1:** 22 test cases, ~22–33 hours

---

### P2 (Medium) — Run nightly

**Criteria:** Secondary flows + lower risk (1–2) + edge cases

| Story | Requirement | Scenario | Test Level | Risk Link | Test Count | Owner |
| ----- | ----------- | -------- | ---------- | --------- | ---------- | ----- |
| 1.1 | `.gitignore` coverage | Assert `.env`, `master.key`, `*.pem`, `*.key`, `.kamal/secrets` are gitignored | Integration | R-006 | 1 | Dev |
| 1.1 | `.env.example` no real values | Scan `.env.example` for secret-like patterns → assert none found | CI | R-006 | 1 | Dev |
| 1.2 | Redirect URI must be exact — trailing slash | Test registered URI vs URI + trailing slash → assert rejected | API | R-003 | 1 | QA |
| 1.3 | Token claims completeness | Decode access token; assert `iss`, `aud`, `azp`, `sub`, `email` claims present | API | — | 1 | QA |
| 1.3 | Argon2id password hash params | Query realm password credential settings; assert Argon2id type + OWASP params | API | R-013 | 1 | QA |
| 1.4 | Idle session timeout enforced | Set short idle timeout; leave session idle; assert subsequent access rejected | API | — | 1 | QA |
| 1.4 | TOTP brute-force rate limit | Submit wrong OTP repeatedly → assert throttle applied | API | — | 1 | QA |
| 1.4 | Password min-length policy enforced | Attempt password < 12 chars → assert Keycloak rejects | API | — | 1 | QA |
| 1.4 | Breached password rejected | Submit a known breached password (if HIBP policy configured) → assert rejected | API | R-013 | 1 | QA |
| 1.5 | Minimal User Profile attributes | Inspect user profile schema; assert only minimal attributes configured; no PDPA §26 sensitive fields | API | — | 1 | QA |
| 1.5 | Disabled user cannot authenticate | Set `enabled=false` on fixture user; attempt login → assert rejected | API | — | 1 | QA |
| 1.6 | TOTP drift window limited | Submit OTP from 2+ steps ahead → assert rejected outside drift window | API | — | 1 | QA |
| 1.7 | Reference client validates `exp` claim | Modify `exp` to expired value; assert client rejects token | Unit | — | 1 | Dev |
| 1.8 | Event retention period set | Admin API: assert event retention > 0 (bounded, not indefinite) | API | — | 1 | QA |

**Total P2:** 14 test cases, ~7–14 hours

---

### P3 (Low) — Run on-demand

**Criteria:** Exploratory, observability, benchmarks

| Story | Requirement | Scenario | Test Level | Test Count | Owner | Notes |
| ----- | ----------- | -------- | ---------- | ---------- | ----- | ----- |
| 1.3 | Token latency baseline | Measure time from auth request to token issuance; record p50/p95 baseline | Perf/API | 1 | Dev | Not a gate at Epic 1; baseline for Epic 6 |
| 1.4 | Concurrency: parallel login attempts | 10 concurrent auth requests; assert no race condition in session creation | Integration | 1 | Dev | Low risk at this scale |
| 1.7 | Reference client → JWKS cache TTL | Rotate key; observe reference client uses new `kid` within bounded window | Manual | 1 | Dev | Manual exploration |
| 1.8 | Admin event completeness | Enumerate admin event types; confirm all expected types captured | Exploratory | 1 | QA | — |
| Cross | ASVS L2 manual hardening review | Work through OWASP ASVS L2 checklist for Keycloak config section | Manual | 1 | Dev/QA | Before pilot |

**Total P3:** 5 test cases, ~3–6 hours

---

## Execution Order

### Smoke Tests (< 5 min, every commit)

- [ ] Keycloak health endpoint `200` (15 s)
- [ ] Realm `envocc` exists via Admin API (15 s)
- [ ] `gitleaks` scan clean (30 s)
- [ ] `.well-known` openid-configuration returns 200 (10 s)

**Total:** 4 scenarios

### P0 Tests (< 15 min)

- [ ] OIDC grant-type enforcement (Implicit/ROPC/PKCE tests) — API (3 min)
- [ ] Redirect-URI exact-match tests — API (2 min)
- [ ] Auth-code single-use replay — API (1 min)
- [ ] RS256 JWKS + `alg:none` rejection — API (1 min)
- [ ] Token lifetime assertion — API (30 s)
- [ ] Refresh-token reuse revocation — API (2 min)
- [ ] `sub` stability + work-email claim — API (1 min)
- [ ] TOTP single-use enforcement — API (1 min)
- [ ] Full E2E sign-in flow (email + password + TOTP) — E2E (3 min)
- [ ] Reference client SSO end-to-end — E2E (3 min)

**Total:** 27 test cases, target < 15 min in CI

### P1 Tests (< 30 min)

- [ ] Realm-config lint — CI (2 min)
- [ ] Key-rotation overlap + old-kid token validity — API (3 min)
- [ ] Realm backup/restore — Integration (10 min)
- [ ] SSO session spanning two clients — E2E (3 min)
- [ ] Session timeout + RP logout — API/E2E (3 min)
- [ ] Brute-force lockout + enumeration resistance — API (3 min)
- [ ] Lifecycle state assertions (pending/active/disabled) — API (2 min)
- [ ] Event capture (login + admin) — API (2 min)

**Total:** 22 test cases, target < 30 min in CI

### P2/P3 Tests (nightly / on-demand)

- [ ] Extended edge-case suite (redirect URI variants, OTP drift, idle timeout, etc.)
- [ ] ASVS L2 manual checklist (pre-pilot gate)
- [ ] Token latency baseline recording

**Total:** 19 test cases

---

## Resource Estimates

### Test Development Effort

| Priority | Count | Hours/Test (avg) | Total Hours | Notes |
| -------- | ----- | ---------------- | ----------- | ----- |
| P0 | 27 | 1.8 | ~44–55 | Security tests require Keycloak setup, fixture management, assertion complexity |
| P1 | 22 | 1.0–1.5 | ~22–33 | Integration tests with Admin API; one backup/restore scenario |
| P2 | 14 | 0.5 | ~7–14 | Shorter scenarios; realm-policy assertions |
| P3 | 5 | 0.5–1.5 | ~3–6 | Exploratory + manual |
| **Total** | **68** | — | **~76–108** | **~10–14 days** |

### Prerequisites

**Test Data:**

- Fixture user factory: generates `email`, `password`, TOTP secret at runtime via Keycloak Admin API; auto-deletes after test run. Never commits credentials.
- Realm snapshot fixture: snapshot of the baseline realm for known-state reset between test suites.
- Negative-test data: list of 5 known breached passwords (from HIBP top-10k list subset, openly published — not credentials).

**Tooling:**

- RSpec + system tests against a running Keycloak (CI uses Docker Compose service)
- Faraday (or `net/http`) for Admin API assertions in integration tests
- `jwt` gem for decoding/verifying token claims in tests
- mailpit SMTP trap (for activation/reset email verification in Epic 2+; wired in CI from Epic 1 start)
- `gitleaks` (pre-commit + CI)
- `bundler-audit` + `brakeman` (CI)
- Realm-config lint script (custom, in `keycloak/` scripts)

**Environment:**

- Docker Compose stack: `keycloak`, `postgres`, `mailpit` (no Rails required for Epic 1 tests)
- Keycloak Admin API accessible at `http://localhost:8080` in CI
- Pinned Keycloak version confirmed before test harness is written
- Test realm import runs on `docker compose up`

---

## Quality Gate Criteria

### Pass/Fail Thresholds

- **P0 pass rate:** 100% (no exceptions — any failure blocks merge)
- **P1 pass rate:** ≥ 95% (one waivers require documented sign-off)
- **P2/P3 pass rate:** ≥ 90% (informational; regressions tracked)
- **High-risk mitigations (R-001 through R-008, R-014):** 100% — each must have a corresponding passing test

### Coverage Targets

- **Critical security scenarios (SEC category):** 100%
- **Core OIDC flows (FR1–FR11):** ≥ 90%
- **NFR assertions (crypto params, token TTL, cookie headers):** 100% of known thresholds
- **Business logic (lifecycle states, claim mapping):** ≥ 80%
- **Edge cases (redirect URI variants, OTP drift, enumeration):** ≥ 60%

### Non-Negotiable Requirements

- [ ] All P0 tests pass
- [ ] No high-risk (score ≥ 6) items unmitigated at merge
- [ ] `gitleaks` CI scan clean (no secrets in history)
- [ ] `brakeman` and `bundler-audit` pass in CI
- [ ] Reference client (Story 1.7) end-to-end SSO verified
- [ ] Keycloak event capture confirmed (Story 1.8)
- [ ] NFR2a (≤ 15 min token TTL) assertion passing
- [ ] NFR3 (RS256 + `alg:none` rejection) assertion passing
- [ ] NFR1 (Argon2id params) assertion passing or CONCERNS filed

---

## Mitigation Plans

### R-001 & R-002: Implicit/ROPC enabled or PKCE not enforced (Score: 6 each)

**Mitigation Strategy:** Automated Admin API test on every CI run: query `/admin/realms/envocc/clients/{id}` and assert `implicitFlowEnabled=false`, `directAccessGrantsEnabled=false`, `standardFlowEnabled=true`, `attributes.pkce.code.challenge.method=S256`. Realm-config lint also validates these fields from `realm-export.json`. Any drift in the realm export or running instance fails the build.
**Owner:** Dev + QA
**Timeline:** Story 1.2
**Status:** Planned
**Verification:** P0 test cases `1.2.grant-type` and `1.2.pkce-enforcement` pass on green build

### R-003: Wildcard redirect URI accepted (Score: 6)

**Mitigation Strategy:** Test attempts to register a client with `*` and `*.example.com`; assert Keycloak returns 400/validation-error. Additionally test that an auth request with a redirect URI that has a near-match (extra path segment, different port) is rejected. Embedded in realm-config lint (no wildcard `validRedirectUris` in committed JSON).
**Owner:** Dev + QA
**Timeline:** Story 1.2
**Status:** Planned
**Verification:** P0 test cases `1.2.redirect-uri-*` pass

### R-005: Refresh-token reuse (Score: 6)

**Mitigation Strategy:** Integration test: complete auth flow; obtain refresh token; use it once (success); replay it immediately; assert 400 `invalid_grant`; additionally assert that the subsequent legitimate token for that user is also invalidated (family revocation). Realm config: `revokeRefreshToken=true`, `refreshTokenMaxReuse=0` asserted.
**Owner:** QA
**Timeline:** Story 1.3
**Status:** Planned
**Verification:** P0 test case `1.3.refresh-reuse` passes

### R-006: Secret committed to git (Score: 6)

**Mitigation Strategy:** (1) `gitleaks` pre-commit hook via `lefthook` — blocks commit on any secret match. (2) CI step 1: `gitleaks` full history scan — fails build on any secret. (3) Test: run `jq` on `realm-export.json` to assert all credential/secret fields are null/empty or replaced with placeholder. (4) `.gitignore` test: assert `.env`, `master.key`, etc. are not tracked.
**Owner:** Dev
**Timeline:** Story 1.1
**Status:** Planned
**Verification:** P0 and P1 secret-hygiene tests pass; `gitleaks` CI clean

### R-007: TOTP single-use not enforced (Score: 6)

**Mitigation Strategy:** Integration test: complete password step; capture valid OTP from test TOTP secret; submit it (success → session token); replay the same OTP within the same time step; assert Keycloak returns auth error. OTP policy `lookAheadWindow` and `otpPolicyAlgorithm` asserted.
**Owner:** QA
**Timeline:** Story 1.6
**Status:** Planned
**Verification:** P0 test case `1.6.totp-single-use` passes

### R-008: Keycloak fails to start / realm not imported (Score: 6)

**Mitigation Strategy:** Smoke test runs before any other test in CI: poll `/health/live` until 200 or timeout (60 s); then assert realm `envocc` exists via Admin API. If this smoke fails, the entire CI run fails fast.
**Owner:** Dev
**Timeline:** Story 1.1
**Status:** Planned
**Verification:** Smoke tests `1.1.healthcheck` and `1.1.realm-exists` pass on every CI run

### R-014: Key-loss scenario untested (Score: 6)

**Mitigation Strategy:** Integration test (P1, nightly): snapshot pg_dump + realm export; delete the active signing key provider via Admin API; attempt token issuance (expect failure); restore DB and realm import; confirm JWKS returns correct key and new token issuance succeeds. Documents the recovery runbook procedurally.
**Owner:** Dev
**Timeline:** Story 1.3
**Status:** Planned
**Verification:** P1 test case `1.3.key-recovery` passes on nightly run

---

## Assumptions and Dependencies

### Assumptions

1. Keycloak version will be pinned before test harness is written; tests reference a specific Admin API version.
2. The TOTP fixture secret is generated by the test harness at runtime and never committed; the reference implementation uses RFC 6238 TOTP with a seeded secret.
3. mailpit is available at `http://localhost:1025` (SMTP) and `http://localhost:8025` (web) in the Docker Compose dev stack from Story 1.1.
4. `gitleaks` v8+ is used; `.gitleaks.toml` exists at the repo root with project-specific rules.
5. The reference client (Story 1.7) is a minimal Ruby or Node app (implementation detail for Dev); tests assert OIDC contract, not specific framework.
6. The Admin API uses `master` realm admin credentials in CI (supplied via CI secrets, not committed).

### Dependencies

1. Story 1.1 complete (Keycloak running + realm imported) — required before any other story's tests can run
2. Docker Compose stack with mailpit — required for E2E flows that trigger email (Epic 2+, but wired from Epic 1)
3. `gitleaks` + `lefthook` configured in repo — required for R-006 mitigation; Story 1.1
4. CI pipeline (`rubocop` + `brakeman` + `bundler-audit` + RSpec with Keycloak) — required before Story 1.2 tests run in CI

### Risks to Plan

- **Risk:** Keycloak Admin API schema changes between minor versions — test assertions against specific field names may break on upgrade
  - **Impact:** CI test failures on Keycloak version bump
  - **Contingency:** Pin Keycloak version in `Dockerfile`; assert version in CI; run a test that validates Admin API response schema shape before upgrade

- **Risk:** TOTP drift-window timing sensitivity in CI — tests that depend on exact time-step boundaries may flake
  - **Impact:** Flaky P2 tests
  - **Contingency:** Use a test TOTP library that accepts an injected clock; avoid wall-clock-dependent assertions

---

## Interworking & Regression

| Service/Component | Impact | Regression Scope |
| ----------------- | ------ | ---------------- |
| **Epic 2 (Keycloak theme + activation)** | Theme wraps the same auth flows tested here | P0 E2E sign-in must still pass with theme applied; theme tests run on top of Epic 1 config |
| **Epic 3 (Rails HR Admin)** | Rails calls Admin API for user lifecycle | Epic 1 establishes the Admin API user model; Rails tests in Epic 3 must run against a Keycloak instance that passes all Epic 1 assertions |
| **Epic 5 (Audit shipping)** | Epic 1 enables event capture; Epic 5 ships it | Story 1.8 event-capture test is the precondition for Epic 5 off-host shipping tests |
| **Reference client (Story 1.7 → Epic 6)** | Epic 6 productionizes the reference client | Epic 6 test design extends from the Epic 1 reference-client passing state |

---

## Follow-on Workflows (Manual)

- Run `/bmad-testarch-atdd` to generate failing P0 tests for stories 1.1–1.8 (separate workflow; not auto-run here).
- Run `/bmad-testarch-automate` for broader P1/P2 coverage automation once Keycloak is running in CI.
- Run `/bmad-testarch-nfr` to perform the full NFR evidence assessment after implementation evidence exists.

---

## Approval

**Test Design Approved By:**

- [ ] Tech Lead: — Date: —
- [ ] QA Lead: — Date: —
- [ ] Product Manager (Rawinan): — Date: —

**Comments:** Initial draft; awaiting implementation start (all stories in `backlog`).

---

## Appendix

### Knowledge Base References

- `risk-governance.md` — Risk classification framework (P × I scoring, TECH/SEC/PERF/DATA/BUS/OPS categories)
- `probability-impact.md` — Risk scoring methodology (1–3 probability, 1–3 impact, 1–9 score; gate thresholds)
- `test-levels-framework.md` — Test level selection (E2E / API / Integration / Unit)
- `test-priorities-matrix.md` — P0–P3 prioritization rules
- `nfr-criteria.md` — NFR category definitions and validation approaches

### Related Documents

- PRD: `_bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-19/prd.md`
- Epics: `_bmad-output/planning-artifacts/epics.md`
- Architecture: `_bmad-output/planning-artifacts/architecture.md`
- Sprint Status: `_bmad-output/implementation-artifacts/sprint-status.yaml`
- Sprint Change Proposal: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-20.md`

---

**Generated by:** BMad TEA Agent — Test Architect Module (Master Test Architect)
**Workflow:** `bmad-testarch-test-design`
**Version:** 4.0 (BMad v6)
**Project:** envocc-sso
