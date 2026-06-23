---
workflowStatus: 'completed'
totalSteps: 5
stepsCompleted: ['step-01-detect-mode', 'step-02-load-context', 'step-03-risk-and-testability', 'step-04-coverage-plan', 'step-05-generate-output']
lastStep: 'step-05-generate-output'
nextStep: ''
lastSaved: '2026-06-23'
epic: 'Epic 1 — Secure Platform Foundation'
inputDocuments:
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/implementation-artifacts/sprint-status.yaml
  - _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-21/prd.md
---

# Test Design: Epic 1 — Secure Platform Foundation

**Date:** 2026-06-23
**Author:** Rawinan
**Status:** Draft

---

## Executive Summary

**Scope:** Epic-level test design for Epic 1 — Secure Platform Foundation (Stories 1.1–1.5).

Epic 1 establishes the hardened, version-pinned identity platform: Keycloak 26.6.x + PostgreSQL (two databases) + single Nginx security edge, running on-prem via Docker Compose, with realm config-as-code, secret hygiene, a shared Deep Sea design-token stylesheet, and an agentic-build/CI security gate. Stories 1.1 and 1.2 are already **done**; Stories 1.3, 1.4, and 1.5 are **backlog**.

**Risk Summary:**

- Total risks identified: 11
- High-priority risks (score ≥6): 5
- Critical categories: SEC (3 high), OPS (1 high), TECH (1 high)

**Coverage Summary:**

- P0 scenarios: 9 (~20–35 hours)
- P1 scenarios: 14 (~25–40 hours)
- P2 scenarios: 10 (~10–20 hours)
- P3 scenarios: 4 (~3–8 hours)
- **Total effort estimate:** ~58–103 hours (~1.5–3 weeks, solo operator)

---

## Not in Scope

| Item | Reasoning | Mitigation |
| --- | --- | --- |
| **OIDC authentication flows** | Covered in Epic 2 (Story 2.2 et al.); Keycloak's auth engine is not yet exercised in Epic 1 | Epic 2 test design covers all auth flows end-to-end |
| **Admin app (SvelteKit)** | Admin scaffold is Epic 4 (Story 4.1); does not exist yet | Epic 4 test design covers admin app |
| **Performance / load testing** | Platform targets ~150 users; no SLA thresholds defined in Epic 1 scope | Will be addressed in Epic 7 / NFR-assess after implementation evidence exists |
| **PDPA / DPO compliance gates** | Epic 7 (Story 7.1–7.2) owns compliance documentation and sign-off | Epic 7 test design |
| **Stories 1.1 and 1.2 regression** | Already done; existing acceptance criteria should be spot-verified, not re-designed | AC-based smoke test in P1 covers regression detection |
| **Audit pipeline (off-host WORM sink)** | Epic 5 scope; no audit sink exists in Epic 1 | Epic 5 test design |
| **ThaiD broker integration** | Epic 2 (Story 2.9); no ThaiD config in Epic 1 realm export | Epic 2 test design |

---

## Risk Assessment

> **Note:** P0/P1/P2/P3 in the Coverage Plan = risk-driven priority, NOT execution timing. Execution timing is defined separately in the Execution Strategy section.

### High-Priority Risks (Score ≥6)

| Risk ID | Category | Description | Probability | Impact | Score | Mitigation | Owner | Timeline |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| R-001 | SEC | Nginx TLS/header misconfiguration ships without automated assertion — HSTS, CSP `frame-ancestors 'none'`, and security headers could be absent or wrong in the deployed edge config | 2 | 3 | **6** | Automated `curl`-based header assertion in CI against a running stack; checked on every PR touching Nginx config | Rawinan | Before Story 1.3 done |
| R-002 | SEC | Secrets committed to git — `.env` or realm export contains key material; gitleaks not yet enforced in CI | 2 | 3 | **6** | gitleaks in pre-commit hook + CI gate (Story 1.5 AC); also validate that `realm-export.json` contains no client secrets or passwords (Story 1.2 AC) | Rawinan | Before Story 1.5 done |
| R-003 | SEC | Realm config-as-code import silently leaves insecure defaults — e.g., Implicit grant enabled, brute-force off, token lifetimes too long | 2 | 3 | **6** | Realm-config lint script asserts security settings post-import; manual AC check on import output | Rawinan | Before Story 1.2 regression run |
| R-004 | OPS | Docker Compose brings up unhealthy Keycloak silently — no health-check assertion in CI means a broken stack ships to later stories | 3 | 2 | **6** | CI smoke test: `docker compose up` → assert Keycloak health endpoint (`/health/ready`) returns 200 and admin console reachable; run on every PR | Rawinan | Before Story 1.1 regression run |
| R-005 | TECH | Version pin drift — `keycloak/` or `postgres/` image digest not pinned (`:latest` or floating tag) is not caught by CI | 2 | 3 | **6** | Compose lint step asserts no `:latest` and that digests are present; run in CI gate (Story 1.5) | Rawinan | Before Story 1.5 done |

### Medium-Priority Risks (Score 3–4)

| Risk ID | Category | Description | Probability | Impact | Score | Mitigation | Owner |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-006 | OPS | Rate-limiting misconfiguration — Nginx rate-limit zone is too permissive or incorrectly configured, allowing abuse through the edge | 2 | 2 | 4 | Test rate-limiting with repeated requests in a controlled environment; verify HTTP 429 response | Rawinan |
| R-007 | TECH | JWKS/discovery caching headers absent — clients cannot self-configure efficiently; fingerprint for future epics | 2 | 2 | 4 | Assert `Cache-Control` or `Expires` header on `/auth/realms/{realm}/.well-known/openid-configuration` and `/auth/realms/{realm}/protocol/openid-connect/certs` | Rawinan |
| R-008 | SEC | Deep Sea CSS token stylesheet does not achieve WCAG AA contrast for all documented pairings — silent accessibility regression | 2 | 2 | 4 | Automated contrast check using `axe-core` or manual check of documented text/background pairs against WCAG AA 4.5:1 threshold | Rawinan |
| R-009 | OPS | Two-database constraint not enforced — `admin` and `keycloak` databases share a role or single DB, breaking least-privilege (NFR1, AR4) | 1 | 3 | 3 | Assert two distinct databases exist and that each DB role cannot connect to the other's database | Rawinan |
| R-010 | TECH | CI gate language-specific checks (ESLint/tsc/svelte-check/bun audit) fail on a non-existent admin app and block CI | 2 | 2 | 4 | Story 1.5 AC explicitly requires these checks to no-op gracefully until admin app lands; verified in CI pipeline run | Rawinan |

### Low-Priority Risks (Score 1–2)

| Risk ID | Category | Description | Probability | Impact | Score | Action |
| --- | --- | --- | --- | --- | --- | --- |
| R-011 | OPS | `.env.example` is out of sync with actual required env vars, causing new contributor bring-up failures | 1 | 2 | 2 | Monitor — check `.env.example` covers all required keys during code review; low urgency |

### Risk Category Legend

- **TECH**: Technical/Architecture (image pinning, integration, CI wiring)
- **SEC**: Security (header misconfiguration, secret leakage, insecure realm defaults)
- **PERF**: Performance (not in scope for Epic 1)
- **DATA**: Data Integrity (not a primary concern for infra/config layer)
- **BUS**: Business Impact (not applicable at this infrastructure layer)
- **OPS**: Operations (deployment, health checks, database isolation, rate-limiting)

---

## NFR Planning

**Purpose:** Identify Epic 1 NFR thresholds, planned validation, and evidence sources. This is a planning document — final PASS/CONCERNS/FAIL is deferred to `nfr-assess` after implementation evidence exists.

| NFR Category | Requirement / Threshold | Risk Link | Planned Validation | Evidence Needed |
| --- | --- | --- | --- | --- |
| **Security — TLS/Headers** | TLS/HSTS on all requests; CSP `frame-ancestors 'none'` on auth surfaces; standard security headers (NFR4) | R-001 | `curl -I` assertions in CI against running Nginx stack | CI test output showing header assertions pass |
| **Security — Secret hygiene** | No secrets/key material in git; `.env.example` committed; real `.env` git-ignored (NFR9) | R-002 | gitleaks scan in pre-commit + CI; realm-export inspection | gitleaks CI scan report; realm-export diff shows no secrets |
| **Security — Realm defaults** | No Implicit/ROPC grants; brute-force enabled; token lifetimes ≤15 min; NFR8-aligned config (NFR8, NFR9) | R-003 | Realm-config lint script; post-import AC verification | Lint script output; Keycloak admin console screenshot or API assertion |
| **Security — Image pinning** | All images pinned by exact version/digest; no `:latest` (AR1, AR2) | R-005 | Compose file lint in CI; grep for `:latest` | CI lint output; compose.yaml diff |
| **Reliability — Stack health** | Keycloak starts healthy against PostgreSQL on `docker compose up` (AR1) | R-004 | CI smoke test: health endpoint assertion | CI log showing `/health/ready` → 200 |
| **Maintainability — CI gate** | Pre-commit + CI gate runs Prettier, Semgrep, gitleaks, bun audit, realm-config lint; language checks no-op gracefully (AR8, NFR9) | R-010 | Full CI pipeline run; pre-commit hook invocation test | CI pipeline pass logs; pre-commit hook output |
| **Accessibility — Design tokens** | Every documented text/background pairing in Deep Sea stylesheet meets WCAG AA (≥4.5:1 contrast ratio) (UX-DR1) | R-008 | Automated contrast check or documented manual audit | Axe-core or contrast-checker output for documented pairings |

**Unknown thresholds:**

- No quantitative performance SLA for Epic 1 (deferred; platform is infra-only at this stage — NFR performance thresholds apply to auth flows in Epic 2+).
- SMTP/email delivery not in Epic 1 scope; no email NFR threshold applies here.
- Backup/restore RTO/RPO (NFR17) — deferred to Epic 7 (Story 7.3).

---

## Entry Criteria

- [ ] Stories 1.3, 1.4, 1.5 acceptance criteria agreed and unambiguous
- [ ] Docker Compose stack (Stories 1.1/1.2) verified healthy on the test machine
- [ ] CI pipeline wired (GitHub Actions `.github/` directory present with a basic workflow)
- [ ] Nginx config file (`nginx.conf` or equivalent) available for inspection
- [ ] `keycloak/realm-export.json` present in repo for lint and inspection
- [ ] `design-tokens/deep-sea.css` present for WCAG audit
- [ ] Pre-commit hook framework (husky/lefthook/pre-commit) available or installable

---

## Exit Criteria

- [ ] All P0 tests pass (100%)
- [ ] All P1 tests pass or failures triaged with documented waivers
- [ ] No open high-priority (score ≥6) risks without mitigation complete or formal waiver
- [ ] All SEC-category tests pass 100%
- [ ] CI gate runs end-to-end on the push that completes Story 1.5
- [ ] NFR evidence collected: header assertions, gitleaks, realm-lint, compose health check
- [ ] Stories 1.3–1.5 accepted against their ACs
- [ ] Progress file updated to `workflowStatus: completed`

---

## Test Coverage Plan

> P0/P1/P2/P3 = priority/risk level, NOT execution timing. See Execution Strategy for when each tier runs.

### P0 (Critical)

**Criteria:** Blocks core functionality + High risk (≥6) + No workaround

| Test ID | Requirement / AC | Test Level | Risk Link | Test Count | Notes |
| --- | --- | --- | --- | --- | --- |
| T-P0-01 | Stack brings up and Keycloak is healthy (`/health/ready` → 200) | API / Shell | R-004 | 2 | `docker compose up` → health endpoint; also assert admin console reachable on expected port |
| T-P0-02 | TLS served with HSTS header present on Nginx edge | API / Shell | R-001 | 2 | `curl -I https://localhost` → assert `Strict-Transport-Security` present with `max-age` |
| T-P0-03 | CSP `frame-ancestors 'none'` present on auth surface paths | API / Shell | R-001 | 2 | `curl -I https://localhost/auth/...` → assert `Content-Security-Policy: frame-ancestors 'none'` |
| T-P0-04 | No secrets in `realm-export.json` (gitleaks-clean) | Static / Shell | R-002 | 1 | Run `gitleaks detect` or equivalent on repo; assert 0 findings |
| T-P0-05 | Realm imports automatically and baseline settings (realm name, login settings) are applied | API / Shell | R-003 | 2 | Post-import: Keycloak Admin REST API or `kcadm.sh` asserts realm exists with correct name and `sslRequired=EXTERNAL` |

**Total P0:** 9 tests

---

### P1 (High)

**Criteria:** Important correctness and security checks + Medium/High risk (3–6)

| Test ID | Requirement / AC | Test Level | Risk Link | Test Count | Notes |
| --- | --- | --- | --- | --- | --- |
| T-P1-01 | Two distinct databases (`keycloak`, `admin`) exist with separate least-privilege roles | API / Shell | R-009 | 3 | `psql` assertions: databases exist; role for `keycloak` cannot access `admin` DB and vice versa |
| T-P1-02 | All images pinned by exact version/digest — no `:latest` in compose file | Static / Shell | R-005 | 2 | `grep -E ':latest'` in `compose.yaml` → 0 matches; digest pin format validated |
| T-P1-03 | `realm-export.json` contains no client secrets, passwords, or signing-key material | Static / Shell | R-002, R-003 | 2 | JSON inspection script: no `secret`, `privateKey`, `password` fields with non-placeholder values |
| T-P1-04 | Edge rate-limiting returns HTTP 429 after threshold on unauthenticated endpoints | API / Shell | R-006 | 3 | Rapid-fire requests in test loop → assert 429 on threshold breach; assert legitimate traffic recovers |
| T-P1-05 | JWKS and discovery endpoints return cacheable responses through the edge | API / Shell | R-007 | 2 | `curl -I .well-known/openid-configuration` and `/certs` → assert `Cache-Control` or `Expires` present and non-zero |
| T-P1-06 | Realm change is re-importable on a clean stack (diff is reviewable) | Shell | R-003 | 2 | Spin up clean stack; import realm-export; assert realm state matches exported config |

**Total P1:** 14 tests

---

### P2 (Medium)

**Criteria:** Secondary acceptance criteria + Low/Medium risk (1–4) + Edge cases

| Test ID | Requirement / AC | Test Level | Risk Link | Test Count | Notes |
| --- | --- | --- | --- | --- | --- |
| T-P2-01 | `.env.example` committed; real `.env` is git-ignored | Static / Shell | R-011 | 2 | `git ls-files .env.example` → found; `cat .gitignore` → `.env` present |
| T-P2-02 | All required env vars from compose file are present in `.env.example` | Static / Shell | R-011 | 1 | Script: extract `${VAR}` references from `compose.yaml` → assert all appear in `.env.example` |
| T-P2-03 | Deep Sea CSS variables expose all DESIGN.md tokens (colors, type, spacing, radius) | Static | R-008 | 2 | Parse `design-tokens/deep-sea.css`; assert required CSS custom properties (`--color-*`, `--font-*`, `--spacing-*`, `--radius-*`) are present |
| T-P2-04 | Every documented text/background pairing meets WCAG AA (≥4.5:1) | Static / Manual | R-008 | 3 | Contrast check for documented pairings in DESIGN.md — automated (`axe-core` or `postcss-contrast`) or manual calculation |
| T-P2-05 | Pre-commit hook runs gitleaks, Semgrep, realm-config lint and blocks on failure | Shell | R-002, R-003 | 2 | Introduce intentional violation (dummy secret string) → assert pre-commit exits non-zero and blocks commit |

**Total P2:** 10 tests

---

### P3 (Low)

**Criteria:** Nice-to-have, exploratory, or future-proofing

| Test ID | Requirement / AC | Test Level | Test Count | Notes |
| --- | --- | --- | --- | --- |
| T-P3-01 | Standard security response headers (X-Frame-Options, X-Content-Type-Options, Referrer-Policy) present on edge | API / Shell | 2 | Belt-and-suspenders check in addition to CSP |
| T-P3-02 | CI gate language checks (ESLint, tsc, svelte-check, bun audit) no-op gracefully when admin app absent | Shell | 1 | Run CI gate on clean repo without admin app; assert exit code 0 and no false failures |
| T-P3-03 | `docker compose down` cleanly removes containers and networks (no orphaned volumes) | Shell | 1 | `docker compose down -v`; assert no leftover containers or named volumes |

**Total P3:** 4 tests

---

## Execution Strategy

**Philosophy:** Run all functional and security tests on every PR — the full suite for Epic 1 is infrastructure assertions, shell scripts, and header checks. Total runtime is well under 5 minutes. No nightly tier needed at this stage.

### Every PR

All test tiers (P0 → P1 → P2) run in sequence:

1. Compose lint (version pins, no `:latest`) — ~30 seconds
2. Static analysis: gitleaks, realm-export secret check, `.env.example` completeness — ~60 seconds
3. Stack smoke: `docker compose up -d` → health endpoint assertion → `docker compose down` — ~2–3 minutes
4. Nginx header assertions (TLS, HSTS, CSP, rate-limiting, JWKS caching) — ~60 seconds
5. Database isolation check (role/DB separation) — ~30 seconds
6. Deep Sea CSS token completeness check — ~15 seconds

**Total estimated PR run time:** ~5–7 minutes

### Nightly (when applicable)

- WCAG AA contrast check (if automated tooling is set up — can be manual until tooling exists)
- Full realm re-import test on clean stack (more thorough than PR smoke check)

### On-Demand / Manual

- P3 exploratory checks
- Pre-commit hook adversarial test (introduce dummy secret → assert block)

---

## Resource Estimates

### Test Development Effort

| Priority | Test Count | Est. Hours/Test | Total Estimate | Notes |
| --- | --- | --- | --- | --- |
| P0 | 9 | 2–3 hrs | ~18–27 hrs | Docker/Nginx setup complexity; CI wiring |
| P1 | 14 | 1.5–2.5 hrs | ~21–35 hrs | DB isolation, rate-limit, static checks |
| P2 | 10 | 1–2 hrs | ~10–20 hrs | CSS checks, pre-commit hook tests |
| P3 | 4 | 0.5–1.5 hrs | ~2–6 hrs | Exploratory, low complexity |
| **Total** | **37** | — | **~51–88 hrs** | **~1.5–2.5 weeks solo** |

### Prerequisites

**Test Infrastructure:**

- Docker Compose + Docker available in CI environment (GitHub Actions `ubuntu-latest` satisfies this)
- `curl` available in CI (standard)
- `psql` client available for database role assertions
- `jq` for JSON inspection of realm-export

**Tooling:**

- `gitleaks` — secret detection in pre-commit and CI
- `Semgrep` — SAST in CI gate
- `axe-core` CLI or `postcss-contrast` — WCAG AA contrast check (P2, can defer to manual)
- Shell scripting (bash) — primary test runner for infrastructure assertions

**Environment:**

- CI can build and run `docker compose up` (GitHub Actions standard runner supports Docker)
- Test Nginx config must be mounted and accessible in the CI container
- Ports 8080 (Keycloak) and 443/80 (Nginx) available in test environment

---

## Quality Gate Criteria

### Pass/Fail Thresholds

- **P0 pass rate:** 100% (no exceptions — stack health and security header assertions are release-blocking)
- **P1 pass rate:** ≥95% (failures require documented triage)
- **P2/P3 pass rate:** ≥90% (informational; CSS/token checks are advisory until Story 1.4 is complete)
- **SEC-category tests:** 100% — R-001, R-002, R-003 mitigations must be verified before Story 1.3/1.5 acceptance

### Coverage Targets

- All 5 stories' acceptance criteria: ≥90% mapped to tests
- Security scenarios (R-001 through R-003): 100%
- NFR evidence collected for: TLS/headers, secret hygiene, realm config, image pinning, stack health

### Non-Negotiable Requirements

- [ ] T-P0-01 (stack health) passes before any Story 1.3+ work begins
- [ ] T-P0-04 (gitleaks clean) passes on every commit from Story 1.2 onward
- [ ] T-P0-02 and T-P0-03 (TLS/CSP) pass before Story 1.3 is accepted as done
- [ ] T-P1-02 (no `:latest`) passes before Story 1.5 CI gate is wired
- [ ] CI gate (Story 1.5) runs automatically on push before Epic 1 retrospective

---

## Risk Mitigation Plans

### R-001: Nginx TLS/Header Misconfiguration (Score: 6)

**Mitigation Strategy:**
1. Write a `ci/test-nginx-headers.sh` script that starts the Docker Compose stack in CI, runs `curl -I` against the Nginx endpoint, and asserts required headers.
2. Wire this script into the CI gate (Story 1.5) under the `nginx-security` job.
3. Assert: `Strict-Transport-Security`, `Content-Security-Policy: frame-ancestors 'none'`, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`.
4. Fail CI if any assertion fails.

**Owner:** Rawinan
**Timeline:** Complete before Story 1.3 acceptance
**Status:** Planned
**Verification:** CI pipeline passes with header assertions logged

---

### R-002: Secrets Committed to Git (Score: 6)

**Mitigation Strategy:**
1. Install `gitleaks` pre-commit hook (Story 1.5 AC).
2. Wire `gitleaks detect` as a CI step scanning every pushed branch.
3. Add a realm-export validation script (`scripts/check-realm-secrets.sh`) that greps for `secret`, `privateKey`, `password` fields in `keycloak/realm-export.json` and fails if non-placeholder values are found.
4. Add `.gitignore` entry for `.env` and assert `.env.example` is committed.

**Owner:** Rawinan
**Timeline:** Complete before Story 1.5 acceptance
**Status:** Partially mitigated (Story 1.2 done — realm export is secret-stripped; gitleaks pre-commit pending Story 1.5)
**Verification:** gitleaks CI report shows 0 findings; realm-export check passes

---

### R-003: Insecure Realm Defaults Post-Import (Score: 6)

**Mitigation Strategy:**
1. Write a realm-config lint script (`scripts/lint-realm-config.sh`) that validates `realm-export.json` for required security settings: `sslRequired`, `bruteForceProtected`, `accessTokenLifespan` ≤900, no Implicit/ROPC grant clients.
2. Wire lint script into pre-commit and CI gate.
3. Manual verification: post-import Keycloak admin console spot-check for key realm settings.

**Owner:** Rawinan
**Timeline:** Complete before Story 1.2 regression run (already done per sprint-status) — lint script should exist by Story 1.5
**Status:** Story 1.2 accepted (realm-export exists, secret-stripped) — lint script implementation pending Story 1.5
**Verification:** Lint script passes on every CI run; post-import realm settings confirmed

---

### R-004: Stack Brings Up Unhealthy Silently (Score: 6)

**Mitigation Strategy:**
1. Add a CI smoke job (`smoke-stack`) that runs `docker compose up -d`, polls `http://localhost:8080/health/ready` until 200 or timeout (30s), asserts admin console reachable, and then tears down.
2. Make this job a prerequisite for all other CI jobs.

**Owner:** Rawinan
**Timeline:** Complete before Story 1.1 regression / CI gate wired (Story 1.5)
**Status:** Planned
**Verification:** CI smoke job passes and is a required step in the workflow

---

### R-005: Version Pin Drift (Score: 6)

**Mitigation Strategy:**
1. Add a compose-lint step to CI: `grep -E ':latest'` on `compose.yaml` → fail if found.
2. Add a digest validation step: assert image references contain `@sha256:`.
3. Document the pin-update process in a `docs/pin-update.md` note (or inline in `compose.yaml` comments).

**Owner:** Rawinan
**Timeline:** Complete before Story 1.5 acceptance
**Status:** Planned
**Verification:** CI lint step passes; `compose.yaml` diff shows digest pins on all images

---

## Assumptions and Dependencies

### Assumptions

1. CI platform is GitHub Actions (`.github/` directory present; `ubuntu-latest` runners with Docker support).
2. No dedicated QA environment separate from the developer machine — all tests run on the Docker Compose stack locally and in CI.
3. The `keycloak/realm-export.json` file is the single source of truth for realm config; no manual Keycloak admin console changes are made outside of config-as-code.
4. `design-tokens/deep-sea.css` is the canonical file path for the Deep Sea token stylesheet (Story 1.4 AC).
5. Stories 1.1 and 1.2 acceptance criteria are already met (sprint-status: `done`); their tests are regression checks, not new acceptance tests.
6. No `playwright.config.*` or Node/Bun app code exists yet — all Epic 1 tests are shell/curl/psql scripts, not Playwright tests. Playwright becomes relevant from Epic 2/4 onward.

### Dependencies

1. **Docker and Docker Compose** available in CI — GitHub Actions `ubuntu-latest` satisfies this; no action required.
2. **Nginx config file committed** to repo — required before T-P0-02/T-P0-03 can run (Story 1.3 dependency).
3. **`design-tokens/deep-sea.css` committed** — required before T-P2-03/T-P2-04 (Story 1.4 dependency).
4. **CI workflow file (`.github/workflows/*.yml`)** — required before T-P3-02 (CI no-op check); must exist by Story 1.5.
5. **gitleaks binary** — must be installable in CI and pre-commit; verify availability in `ubuntu-latest`.

### Risks to Plan

- **Risk:** GitHub Actions runner does not have a routable hostname for Nginx TLS cert — localhost self-signed certs will cause `curl` to fail with SSL errors.
  - **Impact:** T-P0-02 and T-P0-03 may need `curl -k` (insecure) in CI or a self-signed cert in the test compose profile.
  - **Contingency:** Use `curl -k` for header assertions in CI; accept that cert validity is not tested in CI (separate manual check for production cert); document assumption.

- **Risk:** Keycloak 26.6.x Docker image startup time in CI exceeds 30-second poll timeout.
  - **Impact:** T-P0-01 may flake on slower CI runners.
  - **Contingency:** Increase health-check timeout to 60s and add retry logic in the smoke script.

---

## Interworking & Regression

| Service/Component | Impact | Regression Scope |
| --- | --- | --- |
| **Keycloak 26.6.x container** | Foundation for all subsequent epics | T-P0-01 smoke test must pass on every PR to `main` |
| **PostgreSQL (keycloak DB)** | Keycloak credential store; `admin` DB used by admin app (Epic 4) | T-P1-01 DB isolation check; breaks Epic 4 if roles misconfigured |
| **Nginx security edge** | All public traffic transits this; misconfiguration affects every downstream epic | T-P0-02/T-P0-03 header assertions; T-P1-04 rate-limiting |
| **`keycloak/realm-export.json`** | Realm config-as-code; imported at startup; affects all auth epics (Epic 2+) | T-P0-05 realm import assertion; realm-config lint |
| **`design-tokens/deep-sea.css`** | Shared by Keycloak theme (Epic 2) and admin app (Epic 4) | T-P2-03/T-P2-04 token completeness and WCAG check |
| **CI gate / pre-commit** | Enforces all subsequent story quality gates | T-P3-02 no-op check; verifies gate does not block other epics |

---

## Appendix

### Knowledge Base References

- `risk-governance.md` — Risk classification framework and gate decision rules
- `probability-impact.md` — Probability × Impact scoring (1–3 scale)
- `test-levels-framework.md` — Unit / Integration / E2E selection guidelines
- `test-priorities-matrix.md` — P0–P3 prioritization criteria

### Related Documents

- Epic: `_bmad-output/planning-artifacts/epics.md` (Epic 1, Stories 1.1–1.5)
- Architecture: `_bmad-output/planning-artifacts/architecture.md`
- PRD: `_bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-21/prd.md`
- Sprint Status: `_bmad-output/implementation-artifacts/sprint-status.yaml`
- UX/Design: `_bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/DESIGN.md`

### Follow-on Workflows

- Run `/bmad-testarch-atdd` to generate failing P0 tests from this plan (separate workflow; not auto-run).
- Run `/bmad-testarch-automate` for broader coverage once implementation exists.
- Run `/bmad-testarch-nfr` (nfr-assess) after implementation to evaluate NFR evidence against the planned thresholds above.

---

**Generated by:** BMad TEA Agent — Test Architect Module
**Workflow:** `bmad-testarch-test-design`
**Version:** 4.0 (BMad v6)
