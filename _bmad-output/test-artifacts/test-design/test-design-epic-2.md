---
workflowStatus: 'completed'
totalSteps: 5
stepsCompleted: ['step-01-detect-mode', 'step-02-load-context', 'step-03-risk-and-testability', 'step-04-coverage-plan', 'step-05-generate-output']
lastStep: 'step-05-generate-output'
nextStep: ''
lastSaved: '2026-06-27'
epic: 'Epic 2: Staff Authentication & SSO Identity'
inputDocuments:
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/implementation-artifacts/sprint-status.yaml
  - .github/workflows/ci.yml
  - .claude/skills/bmad-testarch-test-design/resources/knowledge/risk-governance.md
  - .claude/skills/bmad-testarch-test-design/resources/knowledge/probability-impact.md
  - .claude/skills/bmad-testarch-test-design/resources/knowledge/test-levels-framework.md
  - .claude/skills/bmad-testarch-test-design/resources/knowledge/test-priorities-matrix.md
  - .claude/skills/bmad-testarch-test-design/resources/knowledge/nfr-criteria.md
---

# Test Design: Epic 2 — Staff Authentication & SSO Identity

**Date:** 2026-06-27
**Author:** Rawinan
**Status:** Draft

---

## Executive Summary

**Scope:** Epic-level test design for Epic 2 — Staff Authentication & SSO Identity. Covers 9 stories (2.1–2.9): canonical identity model, OIDC Auth Code+PKCE, signed tokens & JWKS, SSO session & logout, branded Deep Sea login theme, TOTP MFA hardening, brute-force protection, disable+revocation, and Login with ThaiD (brokered federation).

**Mode:** Epic-Level (stories with acceptance criteria; pre-implementation; all stories in `backlog`; architecture and Epic 1 foundation complete)

**Implementation note:** Epic 2 is almost entirely **Keycloak realm configuration** (JSON) + **native FreeMarker theme** — no custom application code. The test approach centers on integration tests against a live Keycloak stack (Docker Compose from Epic 1), with selective Playwright E2E for UI-critical surfaces.

**Risk Summary:**

- Total risks identified: 13
- High-priority risks (score ≥6): 7
- Critical categories: SEC (6), TECH (1)

**Coverage Summary:**

- P0 scenarios: 20 (~25–40 hours)
- P1 scenarios: 17 (~15–30 hours)
- P2 scenarios: 16 (~10–20 hours)
- P3 scenarios: 6 (~5–8 hours)
- **Total effort:** ~55–98 hours (~2–3 weeks solo)

---

## Not in Scope

| Item | Reasoning | Mitigation |
| ---- | --------- | ---------- |
| **Account activation flow (Epic 3)** | FR16 first-login activation is Epic 3/Story 3.3 | Epic 2 tests assume users are pre-created in `active` state via Admin REST API |
| **Self-service password reset (Epic 3)** | FR17, FR18 are Epic 3 stories | Epic 3 test design covers them |
| **MFA reset re-activation (Epic 3)** | FR15 re-enrollment flow is Epic 3/Story 3.5 | Epic 3 covers the HR-reset-triggered re-enroll path |
| **TOTP enrollment UX (Epic 3)** | Story 2.6 assumes enrollment is already complete; actual enrollment happens in activation (Story 3.3) | Integration test setup uses Keycloak Admin REST to configure TOTP directly |
| **HR Admin console (Epic 4)** | Admin SvelteKit app not built yet | Test setup uses Keycloak Admin REST API directly |
| **Audit event capture pipeline (Epic 5)** | FR35 authentication event logging is Epic 5 | Not validated here; Epic 5 test design covers it |
| **ThaiD DOPA production integration** | Real DOPA requires RP onboarding (open question OQ1/OQ3/OQ4) | All ThaiD tests use a mock OIDC IdP wired in Docker Compose/CI |
| **High-availability / multi-node** | Single instance to start; HA deferred per NFR17 | Not tested at this epic level |
| **Thai localization** | English-first; Thai deferred per NFR19 | Only externalized-string structure is validated |

---

## Risk Assessment

> Priority classifications: CRITICAL (score 9) → BLOCK; HIGH (score 6–8) → MITIGATE; MEDIUM (score 3–5) → MONITOR; LOW (score 1–2) → DOCUMENT.

### High-Priority Risks (Score ≥6)

| Risk ID | Category | Description | Probability | Impact | Score | Mitigation | Owner | Timeline |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ---------- | ----- | -------- |
| R-001 | SEC | OIDC grant type restrictions misconfigured — Implicit or ROPC grant inadvertently enabled in realm; PKCE not enforced at the realm level | 2 | 3 | 6 | Integration tests: attempt Implicit, ROPC, and PKCE-less flows; assert each is rejected | Rawinan | Story 2.2 |
| R-002 | SEC | Token signing misconfigured — `alg:none` accepted; wrong algorithm; JWKS missing `kid`; required claims absent from ID token | 2 | 3 | 6 | Integration tests: decode token header; assert RS256+kid; assert required claims; attempt `alg:none` rejection | Rawinan | Story 2.3 |
| R-003 | SEC | Token/session lifetimes not enforced — access/ID tokens exceed 15-min ceiling; refresh tokens do not rotate on use; replay detection absent; idle/absolute session limits not applied | 2 | 3 | 6 | Integration tests: assert `exp - iat ≤ 900s`; perform refresh rotation sequence; test replay revocation | Rawinan | Story 2.4 |
| R-004 | SEC | TOTP MFA enforcement bypassable — TOTP not required for active accounts; codes reusable within the same time step; clock-drift window undocumented; TOTP attempts not rate-limited | 2 | 3 | 6 | Integration tests: skip TOTP step and verify access denied; reuse same code in same step; burst TOTP attempts | Rawinan | Story 2.6 |
| R-005 | SEC | Brute-force protection disabled or misconfigured — no per-account or per-IP progressive delays on login or TOTP; enables credential stuffing and password spraying | 2 | 3 | 6 | Integration tests: burst 10+ failed attempts per account and per IP; assert progressive delay / lockout response | Rawinan | Story 2.7 |
| R-006 | SEC | Session revocation incomplete on account disable — outstanding refresh-token families or server-side sessions survive after the disable transition completes | 2 | 3 | 6 | Integration test: obtain session → disable account → assert token refresh fails (401) and silent re-auth blocked | Rawinan | Story 2.8 |
| R-007 | TECH | ThaiD broker misconfigured — first-broker-login PID linking fails; disabled accounts not blocked via ThaiD path; mock OIDC IdP absent in CI so ThaiD tests never run | 2 | 3 | 6 | Integration tests with mock OIDC IdP: first-link flow, re-use same identity, disabled-account block | Rawinan | Story 2.9 |

### Medium-Priority Risks (Score 3–5)

| Risk ID | Category | Description | Probability | Impact | Score | Mitigation | Owner |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ---------- | ----- |
| R-008 | SEC | Enumeration resistance broken — different response body or measurable timing difference between valid-email-wrong-password and non-existent-email login attempts | 2 | 2 | 4 | Timing comparison test (curl, ≥20 samples); assert response bodies identical; assert timing within ±50ms tolerance | Rawinan |
| R-009 | SEC | Anti-phishing theme gap — `frame-ancestors 'none'` not applied at theme level (supplementing Nginx edge); anti-phishing banner missing or dismissible on sign-in/MFA surfaces | 2 | 2 | 4 | curl `Content-Security-Policy` assertion on auth surfaces from Keycloak theme layer; Playwright test for banner presence and non-dismissibility | Rawinan |
| R-012 | SEC | Realm export after Epic 2 additions contains ThaiD broker client secret or TOTP config secrets — gitleaks gate exists but realm-lint may not cover new field paths | 1 | 3 | 3 | Extend realm-lint script to assert `identityProviders[].config.clientSecret` absent; run in existing realm-export-check CI job | Rawinan |

### Low-Priority Risks (Score 1–2)

| Risk ID | Category | Description | Probability | Impact | Score | Action |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ------ |
| R-010 | BUS | WCAG 2.1 AA failures on auth surfaces — contrast ratio below threshold; keyboard trap; missing aria-labels on TOTP code group | 1 | 2 | 2 | axe-core audit on sign-in and MFA pages; expected: 0 violations | Monitor |
| R-011 | TECH | Theme strings not externalized — hard-coded English text in FreeMarker templates blocks Thai localization | 1 | 2 | 2 | grep-based unit test: assert all display text uses `${msg(...)}` or message bundles; no hard-coded string literals | Monitor |
| R-013 | OPS | Mock OIDC IdP not integrated in CI Docker Compose by Story 2.9 — ThaiD flow never exercised in automated tests | 1 | 2 | 2 | CI smoke test: assert mock IdP responds to OIDC discovery before ThaiD test suite runs | Monitor |

### Risk Category Legend

- **TECH**: Technical / architecture (integration complexity, brokering flow, idempotency)
- **SEC**: Security (token hygiene, grant type restrictions, brute-force, revocation, enumeration)
- **PERF**: Performance (login latency — P3 only; not a primary Epic 2 risk)
- **DATA**: Data integrity (not primary risk at this epic level)
- **BUS**: Business / UX impact (WCAG, anti-phishing trust signal)
- **OPS**: Operations (CI/mock IdP availability)

---

## NFR Planning

**Purpose:** Capture Epic 2 NFR thresholds, planned validation, and expected evidence for later `nfr-assess`. No final PASS/CONCERNS/FAIL decisions here.

| NFR Category | Requirement / Threshold | Risk Link | Planned Validation | Evidence Needed |
| ------------ | ----------------------- | --------- | ------------------ | --------------- |
| Security — OIDC conformance | Auth Code+PKCE only; no Implicit/ROPC (NFR5, NFR8, FR1, FR3) | R-001 | Integration: attempt Implicit and ROPC grant types; assert rejected | curl exit codes + HTTP 400 response bodies |
| Security — Token signing | RS256 (or ES256), `alg:none` rejected, `kid` in JWKS, no credential values in tokens (NFR3, NFR8) | R-002 | Integration: decode token header; assert alg; fetch JWKS; validate kid presence | Token header assertions; JWKS JSON |
| Security — Token lifetimes | Access/ID tokens hard max ≤ 15 min (NFR2a); refresh rotates on use with family revocation on replay (FR9) | R-003 | Integration: assert `exp - iat ≤ 900s`; replay old refresh token; assert both revoked | Token payload assertions; 401 response on replay |
| Security — Credential custody | Passwords hashed (Argon2id-class); TOTP secrets encrypted at rest (NFR1, NFR2) | — | Realm config inspection: assert password hashing algorithm setting; verify no plaintext TOTP in realm export | Realm JSON field values; realm-lint CI output |
| Security — Brute-force | Per-account + per-IP progressive delays; TOTP rate-limited (NFR7, FR19, FR14) | R-004, R-005 | Integration: burst requests; assert 429/delay response | HTTP response codes and retry-after headers |
| Privacy — Data minimization | No PDPA §26 sensitive data stored; only minimal auth attributes (NFR12, NFR13, FR23) | — | Keycloak Admin REST: inspect user attribute schema; assert no sensitive fields present | User attribute listing from Admin API |
| Accessibility — WCAG AA | All auth surfaces meet WCAG 2.1 AA (UX-DR8) | R-010 | axe-core audit on sign-in + MFA pages; 0 critical/serious violations | axe-core JSON report |
| Performance — Login latency | p95 login/token-issuance ≤ 500 ms (NFR18) | — | P3 benchmark: k6 or shell-timed curl; measure 100-request sample | k6 output or timing log |

**Unknown thresholds to resolve during implementation:**

- **TOTP clock-drift window**: FR14 says "bounded" but no specific value. Keycloak default = ±1 period (±30s, lookAheadWindow/lookBehindWindow=1). Confirm during Story 2.6.
- **TOTP rate-limit threshold**: FR14 says "rate-limited" — exact failure count before lockout unspecified. Define during Story 2.6 and update test accordingly.
- **Idle session timeout**: FR8 requires enforcement but no numeric value in PRD. Set during Story 2.4 and assert in P2 test.
- **Absolute session lifetime**: Same as above. Define during Story 2.4.
- **Brute-force lockout threshold**: FR19 says "progressive delays" — how many failures before lockout, and delay schedule? Define during Story 2.7.

---

## Entry Criteria

- [ ] Epic 1 complete and stable (`epic-1: done` confirmed in sprint-status.yaml — satisfied)
- [ ] Docker Compose stack health-checks passing from clean checkout (Story 1.1 green)
- [ ] Realm config import from `keycloak/realm-export.json` verified (Story 1.2 green)
- [ ] Mock OIDC IdP service selected, containerized, and added to Docker Compose before Story 2.9 work begins
- [ ] Test user data creation strategy documented (Admin REST API or realm import fixture)
- [ ] Playwright (or equivalent) configured in CI for E2E tests on auth surfaces

## Exit Criteria

- [ ] All P0 tests passing
- [ ] All P1 tests passing (or failures triaged with documented waivers)
- [ ] No open R-001 through R-007 (all 7 high-priority risks mitigated)
- [ ] TOTP MFA verified required on all active accounts
- [ ] Token lifetime assertion green (≤15 min, rotation confirmed)
- [ ] Brute-force protection verified per-account and per-IP
- [ ] Disable-to-revocation test green (sessions + refresh tokens invalidated)
- [ ] ThaiD first-broker-login PID linking test green (mock OIDC IdP)
- [ ] Realm export passes gitleaks + realm-lint CI jobs (including new ThaiD broker fields)
- [ ] CI pipeline green on `epic-2` branch for all 9 stories

---

## Test Coverage Plan

> **Note:** P0/P1/P2/P3 = priority / risk level, NOT execution timing. Execution timing is defined in the Execution Strategy section.

### P0 — Critical

**Criteria:** Blocks core auth journey + High risk (≥6) + No workaround

| Req / AC | Test Level | Risk Link | Test Count | Owner | Notes |
| --------- | ---------- | --------- | ---------- | ----- | ----- |
| Story 2.2 AC-1: Implicit grant rejected (`response_type=token`) | Integration (curl) | R-001 | 1 | Dev | POST to authorization endpoint with `response_type=token`; assert HTTP 400 or error response |
| Story 2.2 AC-1: ROPC grant rejected | Integration (curl) | R-001 | 1 | Dev | POST to token endpoint with `grant_type=password`; assert HTTP 400 |
| Story 2.2 AC-1: PKCE required — no `code_challenge` rejected | Integration (curl) | R-001 | 1 | Dev | Auth request without `code_challenge`; assert rejected before redirect |
| Story 2.2 AC-4: Auth code replay detected — second use of same code fails | Integration (curl) | R-001 | 1 | Dev | Exchange code → success; replay same code → assert 400/invalid_grant |
| Story 2.2 AC-4: PKCE verifier binding enforced — wrong verifier rejected | Integration (curl) | R-001 | 1 | Dev | Exchange code with mismatched `code_verifier`; assert 400 |
| Story 2.3 AC-1: ID token signed RS256 (`alg:none` rejected) | Integration (Keycloak REST) | R-002 | 1 | Dev | Decode token header; assert `alg=RS256` (or ES256); separately assert `alg=none` variant rejected |
| Story 2.3 AC-1: Required claims in ID token (sub, email reconciliation key, iss, aud, exp, nonce) | Integration (Keycloak REST) | R-002 | 1 | Dev | Decode token payload; assert all required claims present |
| Story 2.3 AC-2: JWKS endpoint has `kid`; signing key type RSA/EC | Integration (curl) | R-002 | 1 | Dev | GET jwks_uri; assert `keys[0].kid` present; `keys[0].kty = RSA` or EC |
| Story 2.4 AC-2: Access/ID token lifetime ≤15 min | Integration (Keycloak REST) | R-003 | 1 | Dev | Assert `exp - iat ≤ 900` seconds on decoded token |
| Story 2.4 AC-2: Refresh token rotates on use; old token rejected | Integration (Keycloak REST) | R-003 | 1 | Dev | Exchange refresh token → new token; replay old refresh token → assert 400 |
| Story 2.4 AC-2: Refresh token family revocation on replay | Integration (Keycloak REST) | R-003 | 1 | Dev | Exchange refresh token twice in parallel; assert second exchange also fails (family revoked) |
| Story 2.6 AC-1: Active account requires TOTP after password — skipping TOTP step denied | Integration (curl/Keycloak) | R-004 | 1 | Dev | Complete password step; attempt to obtain token without TOTP step; assert access denied |
| Story 2.6 AC-1: Invalid TOTP code rejected — session not established | Integration (curl/Keycloak) | R-004 | 1 | Dev | Submit incorrect TOTP; assert login fails; assert no session cookie |
| Story 2.7 AC-1: Per-account brute-force — 10+ failed logins trigger lockout/delay | Integration (curl) | R-005 | 1 | Dev | Burst 10 failed login attempts for the same account; assert 429 or measurable delay on subsequent attempt |
| Story 2.7 AC-1: Per-IP brute-force — burst from one IP across accounts triggers throttle | Integration (curl) | R-005 | 1 | Dev | Burst failed attempts from one IP across multiple accounts; assert 429 or IP-level delay |
| Story 2.8 AC-2: Disable revokes all refresh-token families | Integration (Keycloak REST) | R-006 | 1 | Dev | Obtain refresh token → disable account → attempt refresh → assert 401 |
| Story 2.8 AC-2: Disable invalidates all server-side sessions | Integration (Keycloak REST) | R-006 | 1 | Dev | Obtain session → disable account → attempt silent re-auth → assert blocked |
| Story 2.9 AC-3: First-broker-login links ThaiD PID to pre-created account; same `sub` as password login | Integration (mock OIDC) | R-007 | 1 | Dev | First ThaiD login via mock IdP → assert `sub` matches pre-created account's Keycloak ID |
| Story 2.9 AC-3: Second ThaiD login uses same identity without re-link prompt | Integration (mock OIDC) | R-007 | 1 | Dev | Second ThaiD login → no first-broker-login prompt; same `sub` returned |
| Story 2.9 AC-5 (precondition): Mock OIDC IdP responds to OIDC discovery in CI | Integration (curl) | R-007 | 1 | Dev | CI smoke: curl mock IdP `/.well-known/openid-configuration` → valid JSON before ThaiD tests run |

**Total P0:** 20 tests, ~25–40 hours

---

### P1 — High

**Criteria:** Important features + Medium risk (3–5) + Common authentication workflows

| Req / AC | Test Level | Risk Link | Test Count | Owner | Notes |
| --------- | ---------- | --------- | ---------- | ----- | ----- |
| Story 2.2 AC-2: Credentials submitted to IdP only; never transit RP | E2E (Playwright) | R-001 | 1 | Dev | Verify Playwright redirect flow — RP receives only auth code, never password field |
| Story 2.2 AC-3: Exact-match redirect URI — trailing-param variant rejected | Integration (curl) | R-001 | 1 | Dev | Request with `redirect_uri=https://app.example.com/callback?extra=1` → assert rejected |
| Story 2.2 AC-3: Exact-match redirect URI — subdomain variant rejected | Integration (curl) | R-001 | 1 | Dev | Request with `redirect_uri=https://evil.example.com/callback` → assert rejected |
| Story 2.3 AC-3: `state` and `nonce` binding enforced | Integration (curl) | R-002 | 1 | Dev | Initiate auth without `nonce`; assert behavior (Keycloak rejects or warns); document expected behavior |
| Story 2.3 AC-3: `nonce` verified exactly once — second validation of same nonce fails | Integration (curl) | R-002 | 1 | Dev | Replay ID token with same nonce to client validation logic; assert second check fails |
| Story 2.3 AC-4: OIDC discovery document complete | Integration (curl) | — | 1 | Dev | GET `.well-known/openid-configuration`; assert issuer, authorization_endpoint, token_endpoint, jwks_uri, token_endpoint_auth_methods all present |
| Story 2.4 AC-1: SSO — authenticated user reaches second app without re-auth | E2E (Playwright, 2 clients) | — | 1 | Dev | Authenticate in app A (reference client); open app B in same browser session; assert tokens received without login prompt |
| Story 2.4 AC-1: SSO — second app reaches correct user identity (same `sub`) | E2E (Playwright) | — | 1 | Dev | Assert `sub` from app B tokens matches `sub` from app A |
| Story 2.4 AC-3: Session ID regenerated on auth-state transition (post-MFA) | Integration (curl) | — | 1 | Dev | Capture session cookie before MFA step; assert new session cookie with different value after MFA success |
| Story 2.4 AC-4: RP-initiated logout terminates SSO session | E2E (Playwright) | — | 1 | Dev | Logout → attempt SSO-to-second-app in same browser → requires re-auth |
| Story 2.4 AC-4: Post-logout redirect honored to branded signed-out surface | E2E (Playwright) | — | 1 | Dev | Logout with valid `post_logout_redirect_uri` → assert redirect to signed-out surface |
| Story 2.6 AC-3: Same TOTP code rejected on second use within time step | Integration (curl) | R-004 | 1 | Dev | Submit valid TOTP code → success; immediately submit same code → assert rejected |
| Story 2.6 AC-3: TOTP rate-limit activates after burst incorrect codes | Integration (curl) | R-004 | 1 | Dev | Submit 5+ invalid TOTP codes in sequence; assert rate-limit response (threshold confirmed during implementation) |
| Story 2.7 AC-2: Enumeration-resistant — response body identical for valid-email-wrong-pass vs non-existent-email | Integration (curl) | R-008 | 1 | Dev | Compare response JSON bodies; assert identical error messages |
| Story 2.7 AC-2: Enumeration-resistant — timing indistinguishable (within ±50 ms tolerance) | Integration (curl, 20 samples) | R-008 | 1 | Dev | Measure mean response time for both cases over 20 requests; assert within tolerance |
| Story 2.8 AC-1: Disabled account blocked from new password+TOTP login | Integration (curl) | R-006 | 1 | Dev | Disable account; attempt standard login; assert auth rejected |
| Story 2.9 AC-4: Disabled account blocked from ThaiD login | Integration (mock OIDC) | R-007 | 1 | Dev | Disable account; ThaiD login via mock IdP; assert broker returns access denied |

**Total P1:** 17 tests, ~15–30 hours

---

### P2 — Medium

**Criteria:** Secondary features + Low/medium risk (1–4) + Edge cases and UX validation

| Req / AC | Test Level | Risk Link | Test Count | Owner | Notes |
| --------- | ---------- | --------- | ---------- | ----- | ----- |
| Story 2.1 AC-1: Stable `sub` across multiple logins | Integration (Keycloak REST) | — | 1 | Dev | Login twice with same account; assert `sub` claim identical |
| Story 2.1 AC-1: Work-email as unique reconciliation claim | Integration (Keycloak REST) | — | 1 | Dev | Assert email claim in ID token matches work email on user record |
| Story 2.1 AC-2: Data minimization — no PDPA §26 sensitive fields in user attributes | Integration (Admin REST) | — | 1 | Dev | GET user from Keycloak Admin REST; assert no sensitive fields (national ID stored only in linked broker reference, not as user attribute) |
| Story 2.1 AC-3: Lifecycle pending → active transition blocks login until active | Integration (Keycloak REST) | — | 1 | Dev | Create user in pending (email-not-verified) state; attempt login; assert blocked |
| Story 2.1 AC-3: Lifecycle active → disabled transition (Story 2.8 complement) | Integration (Keycloak REST) | — | 1 | Dev | Verify user state field reflects `disabled` after disable call |
| Story 2.4 AC-2: Idle session timeout enforced — realm setting reflects intended value | Integration (Admin REST) | R-003 | 1 | Dev | Assert realm `ssoSessionIdleTimeout` matches Story 2.4 implementation decision |
| Story 2.4 AC-2: Absolute session lifetime enforced — realm setting reflects intended value | Integration (Admin REST) | R-003 | 1 | Dev | Assert realm `ssoSessionMaxLifespan` matches Story 2.4 implementation decision |
| Story 2.5 AC-1: Auth surfaces served with `frame-ancestors 'none'` CSP (theme layer) | Integration (curl) | R-009 | 1 | Dev | GET login page through Nginx edge; assert `Content-Security-Policy` header includes `frame-ancestors 'none'` |
| Story 2.5 AC-1: Login page uses Deep Sea CSS variables (spot check) | Integration (curl/grep) | R-009 | 1 | Dev | Fetch login page HTML; assert `deep-sea.css` or CSS variables linked in `<head>` |
| Story 2.5 AC-2: Anti-phishing banner present on sign-in surface | E2E (Playwright) | R-009 | 1 | Dev | Assert anti-phishing banner element visible and in DOM |
| Story 2.5 AC-2: Anti-phishing banner present on MFA/verification-code surface | E2E (Playwright) | R-009 | 1 | Dev | Navigate to TOTP step; assert banner still present |
| Story 2.5 AC-3: All theme display text uses `${msg(...)}` — no hard-coded strings | Unit (grep) | R-011 | 1 | Dev | Grep FreeMarker templates for bare string literals outside message-bundle calls; assert 0 matches |
| Story 2.5 AC-4: WCAG 2.1 AA — sign-in surface 0 axe-core violations | E2E (Playwright + axe) | R-010 | 1 | Dev | Run axe-core on sign-in page; assert 0 critical/serious violations |
| Story 2.5 AC-4: WCAG 2.1 AA — TOTP verification surface 0 axe-core violations | E2E (Playwright + axe) | R-010 | 1 | Dev | Run axe-core on MFA page; assert 0 critical/serious violations |
| Story 2.6 AC-2: TOTP code input is a single labeled 6-digit group (aria semantics) | E2E (Playwright) | — | 1 | Dev | Assert code input has accessible label; grouped as one logical field in assistive tech |
| Story 2.9 AC-1: "Login with ThaiD" button present below form after "or" divider | E2E (Playwright) | — | 1 | Dev | Load sign-in page; assert ThaiD button visible; assert "or" divider present above it |

**Total P2:** 16 tests, ~10–20 hours

---

### P3 — Low

**Criteria:** Nice-to-have + Exploratory + Performance benchmarks

| Req / AC | Test Level | Test Count | Owner | Notes |
| --------- | ---------- | ---------- | ----- | ----- |
| Login/token-issuance p95 latency baseline (target ≤500 ms, NFR18) | Benchmark (shell/k6) | 1 | Dev | Run 100-request sample; record p95; reference baseline for regression in later epics |
| Exploratory: ThaiD error paths — mock IdP unavailable | Exploratory | 1 | Dev | Bring down mock IdP; attempt ThaiD login; verify Keycloak returns clean error to user, not raw 502 |
| Exploratory: ThaiD error path — PID not linked to any account | Exploratory | 1 | Dev | ThaiD identity with unrecognized PID; verify first-broker-login does not create a phantom account |
| Exploratory: ThaiD error path — account already linked to different ThaiD identity | Exploratory | 1 | Dev | Attempt to link a second ThaiD PID to an already-linked account; verify broker rejects gracefully |
| Realm config idempotency after Epic 2 additions | Integration (shell) | 1 | Dev | Export realm after Epic 2 config → clean stack bring-up → import → assert TOTP policy and ThaiD broker present |
| SSO session persistence across Keycloak restart | Exploratory | 1 | Dev | Authenticate → restart Keycloak container → assert session survives (PostgreSQL-backed) |

**Total P3:** 6 scenarios, ~5–8 hours

---

## Execution Strategy

**Philosophy:** Run everything on every PR unless genuinely expensive or long-running. With parallelization, the ~53 functional tests complete well under 15 minutes (Docker Compose stack already available from Epic 1 setup).

| Trigger | Suite | Expected Duration | Rationale |
| ------- | ----- | ----------------- | --------- |
| **Every PR / push** | All functional tests (P0 + P1 + P2): grant-type assertions, token structure, TOTP enforcement, brute-force, revocation, ThaiD broker, theme headers, anti-phishing, WCAG, enumeration-resistance, SSO session | ~10–15 min | Cheap tests on an already-running stack; catches regressions immediately |
| **Every PR / push** | Existing Epic 1 regression suite (bring-up, header assertions, gitleaks, realm-lint) | ~5–8 min | Epic 2 realm additions must not break Epic 1 foundation |
| **Nightly** | P3 benchmarks (login latency), Semgrep full scan | ~20–30 min | Timing-sensitive benchmarks need low-noise environment |
| **On-demand** | Exploratory scenarios (ThaiD error paths, SSO restart resilience) | N/A | Manual; run when changing broker config or session settings |

---

## Resource Estimates

| Priority | Count | Hours (range) | Notes |
| -------- | ----- | ------------- | ----- |
| P0 | 20 | ~25–40 | Auth flow integration setup, mock OIDC IdP, token assertion tooling |
| P1 | 17 | ~15–30 | Playwright SSO E2E, enumeration timing tests, redirect URI edge cases |
| P2 | 16 | ~10–20 | WCAG axe-core, anti-phishing Playwright, grep tests, realm setting assertions |
| P3 | 6 | ~5–8 | Benchmarks, exploratory |
| **Total** | **59** | **~55–98 hours** | **~2–3 weeks solo** |

**Test Data & Prerequisites:**

- Keycloak Admin REST API service account (least-privilege) for test setup and assertion
- Test user factory: at least 3 user states — `pending`, `active-with-TOTP`, `disabled`
- Mock OIDC IdP container (e.g., `node-oidc-provider` or `oauth2-mock-server`) added to Docker Compose
- Playwright configured with base URL pointing at Keycloak (through Nginx edge)
- axe-core integrated into Playwright test suite for WCAG assertions
- `wait-for-it.sh` or equivalent to await mock OIDC IdP readiness in CI

**Tooling:**

- `curl` — auth flow assertions (grant type, redirect URI, headers)
- Keycloak Admin REST API — state setup (create users, configure TOTP, disable accounts) and assertions
- Playwright — E2E: SSO session, logout redirect, anti-phishing banner, TOTP UX, WCAG
- axe-core (Playwright plugin) — WCAG 2.1 AA audits
- k6 or shell timing — latency benchmark (P3)
- grep / shell script — FreeMarker externalization check
- Docker Compose (from Epic 1) — test environment

**Environment:**

- Local: Docker Compose stack with Keycloak, PostgreSQL, Nginx, and mock OIDC IdP
- CI: GitHub Actions `ubuntu-latest` with Docker Compose service containers
- No external services required (DOPA/ThaiD is fully mocked)

---

## Quality Gate Criteria

### Pass/Fail Thresholds

- **P0 pass rate:** 100% (no exceptions — all 7 high-risk security properties must be verified before story merge)
- **P1 pass rate:** ≥95% (waivers require documented rationale and owner sign-off)
- **P2/P3 pass rate:** ≥90% (informational; failures tracked not blocked)
- **High-risk mitigations (R-001 through R-007):** 100% complete or approved waivers before epic branch merge

### Coverage Targets

- **Critical auth security paths (grant types, token signing, TOTP enforcement, revocation):** 100%
- **OIDC protocol compliance (PKCE, nonce, state, code replay):** 100%
- **Brute-force protection:** 100%
- **ThaiD broker flow (mock IdP):** 100%
- **UX/accessibility (WCAG AA, anti-phishing):** 100%
- **NFR evidence identified:** All 8 NFR categories in scope have planned evidence artifact

### Non-Negotiable Requirements

- [ ] All P0 tests pass
- [ ] TOTP MFA enforcement verified: cannot skip MFA step to obtain access token
- [ ] Token lifetime ≤15 min verified
- [ ] Refresh rotation + replay revocation verified
- [ ] Account disable → token/session revocation verified
- [ ] Implicit + ROPC grants confirmed rejected
- [ ] ThaiD PID linking test green (mock OIDC IdP)
- [ ] No R-001 through R-007 risks open at epic close
- [ ] Realm export passes gitleaks + extended realm-lint (ThaiD broker secret fields asserted absent)

---

## Mitigation Plans

### R-001: OIDC Grant Type Restrictions Misconfigured (Score: 6)

**Mitigation Strategy:**
1. Story 2.2 implementation: disable Implicit and Direct Grant (ROPC) explicitly in realm config-as-code; enable PKCE enforcement (`pkceCodeChallengeMethod=S256`)
2. P0 integration tests assert each rejected grant type (Implicit, ROPC, PKCE-less) before story is considered done
3. Extend realm-lint script to assert `directGrantFlow`, `implicitFlowEnabled=false`, `directAccessGrantsEnabled=false` on all non-internal clients

**Owner:** Rawinan
**Timeline:** Story 2.2 implementation
**Status:** Planned
**Verification:** P0 tests green (5 tests); realm-lint CI job green

---

### R-002: Token Signing Misconfigured (Score: 6)

**Mitigation Strategy:**
1. Story 2.3 implementation: assert Keycloak realm uses RS256 (or ES256) signing algorithm; disable `alg:none` path (Keycloak rejects this by default — verify in tests)
2. P0 tests: decode ID token header and assert `alg`; fetch JWKS and assert `kid` present
3. P0 test: assert `alg=none` token rejected by Keycloak token endpoint
4. Extend realm-lint: assert `defaultSignatureAlgorithm` is RS256/ES256; assert no `none` algorithm configured

**Owner:** Rawinan
**Timeline:** Story 2.3 implementation
**Status:** Planned
**Verification:** P0 tests green (3 tests); token header assertion archived as evidence

---

### R-003: Token/Session Lifetimes Not Enforced (Score: 6)

**Mitigation Strategy:**
1. Story 2.4 implementation: set realm `accessTokenLifespan ≤ 900` (15 min); enable refresh token rotation; enable revoke-refresh-token; enable reuse-detection
2. P0 tests: assert `exp - iat ≤ 900`; assert old refresh token rejected post-rotation; assert family revocation on parallel replay
3. Confirm idle/absolute session timeout values in Story 2.4 and add to realm-lint assertions

**Owner:** Rawinan
**Timeline:** Story 2.4 implementation
**Status:** Planned
**Verification:** P0 tests green (3 tests); realm `accessTokenLifespan` value verified in Admin REST

---

### R-004: TOTP MFA Enforcement Bypassable (Score: 6)

**Mitigation Strategy:**
1. Story 2.6 implementation: configure browser auth flow to require OTP for all non-temporary accounts; set `otpPolicy.lookAheadWindow` and `lookBehindWindow` values (confirm during implementation); enable OTP rate-limiting via Keycloak brute-force or custom authenticator settings
2. P0 tests: attempt to obtain token by skipping TOTP step; submit invalid TOTP; assert access denied in both cases
3. P1 tests: code reuse detection; TOTP rate-limit burst

**Owner:** Rawinan
**Timeline:** Story 2.6 implementation
**Status:** Planned
**Verification:** P0 tests green (2 tests); P1 tests green (2 tests)

---

### R-005: Brute-Force Protection Disabled (Score: 6)

**Mitigation Strategy:**
1. Story 2.7 implementation: enable Keycloak brute-force protection (`bruteForceProtected=true`); configure `failureFactor`, `waitIncrementSeconds`, `maxFailureWaitSeconds`, `permanentLockout` as documented during implementation
2. P0 tests: burst 10+ failed login attempts per account and per IP; assert progressive delay or 429 response
3. Confirm threshold values during implementation and encode in realm-lint assertions

**Owner:** Rawinan
**Timeline:** Story 2.7 implementation
**Status:** Planned
**Verification:** P0 tests green (2 tests); brute-force settings in realm config verified

---

### R-006: Session Revocation Incomplete on Disable (Score: 6)

**Mitigation Strategy:**
1. Story 2.8 implementation: use Keycloak Admin REST `PUT /admin/realms/{realm}/users/{id}/logout` + `DELETE /admin/realms/{realm}/users/{id}/sessions` to immediately revoke all sessions on disable; revoke-refresh-token (from R-003 mitigation) also handles token families
2. P0 tests: obtain session → disable account → assert refresh token fails (401) and session cookie rejected
3. Verify Keycloak `revokeRefreshToken=true` is active (covers refresh family revocation on token use, but explicit disable must also revoke active families)

**Owner:** Rawinan
**Timeline:** Story 2.8 implementation
**Status:** Planned
**Verification:** P0 tests green (2 tests); Admin REST `GET /sessions` returns empty after disable

---

### R-007: ThaiD Broker Misconfigured (Score: 6)

**Mitigation Strategy:**
1. Story 2.9 implementation: configure ThaiD as an external OIDC Identity Provider in realm config-as-code; set `firstBrokerLoginFlowAlias` to a custom flow that maps PID to an existing account
2. Add `mock-oidc-provider` service to Docker Compose; wire `THAID_IDP_URL` to mock in dev/CI
3. P0 tests: first-link flow with mock IdP; re-use confirms same `sub`; mock IdP CI smoke before ThaiD tests
4. Extend realm-lint to assert ThaiD IDP client secret absent from realm export

**Owner:** Rawinan
**Timeline:** Story 2.9 implementation
**Status:** Planned
**Verification:** P0 tests green (3 tests); realm-lint green; mock IdP CI smoke green

---

## Assumptions and Dependencies

### Assumptions

1. The Docker Compose stack from Epic 1 is the test environment; no additional infrastructure is needed for Epic 2 testing beyond the mock OIDC IdP container.
2. Keycloak 26.6.x enforces `alg:none` rejection by default — the P0 test confirms this rather than having to configure it.
3. Keycloak's built-in brute-force protection is sufficient for FR19 (per-account + per-IP progressive delays); no custom authenticator is needed.
4. ThaiD PID is stored as a Keycloak identity provider link attribute, not as a top-level user attribute — consistent with data minimization (NFR13) and PDPA §26 (NFR12).
5. The reference client used for SSO session tests (P1, Story 2.4 AC-1) is the same minimal reference client from Epic 6/Story 6.1 (may need to be developed earlier or mocked with a simple Playwright-driven OIDC flow).
6. TOTP enrollment setup for test users will use the Keycloak Admin REST API (`PUT /admin/realms/{realm}/users/{id}/configure-totp`) rather than E2E enrollment, so tests can target Story 2.6 in isolation from the activation flow (Epic 3).

### Dependencies

1. **Mock OIDC IdP** — Required for all Story 2.9 P0/P1 tests; must be chosen, containerized, and added to Docker Compose before Story 2.9 implementation begins. Owner: Rawinan; target: pre-Story 2.9.
2. **Reference/sample OIDC client** — Required for SSO session E2E test (Story 2.4 P1). Minimal implementation (redirect + token exchange) needed before Story 2.4 E2E test. Owner: Rawinan; target: pre-Story 2.4 E2E work.
3. **axe-core Playwright integration** — Required for WCAG P2 tests. Install as dev dependency in Playwright test project before Story 2.5 test authoring.
4. **TOTP clock-drift and rate-limit thresholds** — Must be defined in Story 2.6 implementation before P1 TOTP rate-limit test can be written with a specific threshold.
5. **Idle/absolute session timeout values** — Must be defined in Story 2.4 implementation before P2 session-setting assertion tests.

### Risks to Plan

- **Risk:** Mock OIDC IdP not integrated before Story 2.9 begins
  - **Impact:** ThaiD broker P0 tests cannot run; Story 2.9 cannot merge (P0 gate fails)
  - **Contingency:** Use a minimal in-process OIDC mock (e.g., a single Express endpoint returning minimal discovery + tokens) if a full container is not ready in time

- **Risk:** Keycloak Admin REST API used for test setup changes behavior between 26.6.x minor versions
  - **Impact:** TOTP setup or session revocation calls may break with a minor Keycloak update
  - **Contingency:** Pin Keycloak to exact digest (already done in Epic 1 Story 1.1); re-test after any version bump

- **Risk:** Enumeration timing test (P1, R-008) is inherently noisy in CI environments
  - **Impact:** Timing tolerance (±50 ms) may produce flaky results on shared GitHub Actions runners
  - **Contingency:** Increase sample size to 50 requests; use median not mean; widen tolerance to ±100 ms and document as implementation-level best-effort

---

## Interworking & Regression

| Service / Component | Impact | Regression Scope |
| ------------------- | ------ | ---------------- |
| **Epic 1 — Nginx edge** | Epic 2 theme must not loosen `frame-ancestors 'none'` set by Nginx; CSP must remain intact | Re-run Story 1.3 header assertion test after theme deployment |
| **Epic 1 — Realm import** | Epic 2 adds realm settings (auth flows, TOTP policy, ThaiD broker, token lifetimes) to `realm-export.json` | Story 1.2 realm import test must still pass on clean stack with Epic 2 additions |
| **Epic 1 — CI gate** | ThaiD broker IDP client secret must not appear in realm export | realm-export-check + extended realm-lint must cover new broker fields |
| **Epic 1 — Deep Sea CSS** | Story 2.5 theme imports `design-tokens/deep-sea.css` — token drift would affect theme visually | Story 1.4 token cross-check re-run if DESIGN.md amended |
| **Epic 3 (later)** | First-login activation (3.3) and password reset (3.4) depend on Epic 2's identity model and auth flows | Epic 2 canonical identity (Story 2.1) and OIDC flow (Story 2.2) must be stable and tested before Epic 3 begins |
| **Epic 4 (later)** | Admin OIDC sign-in (Story 4.2) depends on Epic 2 OIDC flow and Keycloak realm | Epic 2 must be complete and test-green before Epic 4 Story 4.2 implementation |

---

## Follow-on Workflows

- Run `*atdd` to generate failing P0 tests before implementation (separate workflow; not auto-run).
- Run `*automate` for broader test coverage once implementation exists.
- Run `*framework` to configure Playwright test project (if not already configured for this project).
- Run `*ci` to add Epic 2 test jobs to the GitHub Actions pipeline.

---

## Appendix

### Knowledge Base References

- `risk-governance.md` — risk classification framework (TECH/SEC/PERF/DATA/BUS/OPS, P×I scoring)
- `probability-impact.md` — probability and impact scale definitions
- `test-levels-framework.md` — unit / integration / E2E selection criteria
- `test-priorities-matrix.md` — P0–P3 prioritization criteria
- `nfr-criteria.md` — non-functional requirement validation planning (security, privacy, accessibility)

### Related Documents

- Epic: `_bmad-output/planning-artifacts/epics.md` — Epic 2 stories and acceptance criteria (lines 356–573)
- Architecture: `_bmad-output/planning-artifacts/architecture.md` — AR1–AR8, Decision 1 (Keycloak), Decision 2 (ThaiD brokering)
- UX Design: `_bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/DESIGN.md` — Deep Sea tokens
- Sprint Status: `_bmad-output/implementation-artifacts/sprint-status.yaml`
- Existing CI: `.github/workflows/ci.yml`
- Epic 1 Test Design: `_bmad-output/test-artifacts/test-design/test-design-epic-1.md`

---

**Generated by:** BMad TEA Agent — Test Architect Module
**Workflow:** `bmad-testarch-test-design`
**Version:** 4.0 (BMad v6)
