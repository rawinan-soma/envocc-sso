---
workflowStatus: 'completed'
totalSteps: 5
stepsCompleted: ['step-01-detect-mode', 'step-02-load-context', 'step-03-risk-and-testability', 'step-04-coverage-plan', 'step-05-generate-output']
lastStep: 'step-05-generate-output'
nextStep: ''
lastSaved: '2026-06-25'
epic: 'Epic 1: Secure Platform Foundation'
inputDocuments:
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/implementation-artifacts/sprint-status.yaml
  - .github/workflows/ci.yml
---

# Test Design: Epic 1 — Secure Platform Foundation

**Date:** 2026-06-25
**Author:** Rawinan
**Status:** Draft

---

## Executive Summary

**Scope:** Epic-level test design for Epic 1 — Secure Platform Foundation. Covers 5 stories: Docker Compose stack, Realm config-as-code, Nginx security edge, Deep Sea design tokens, and Agentic-build / CI security gate.

**Mode:** Epic-Level (stories with acceptance criteria present; architecture doc available; all stories currently in `backlog` — test design precedes implementation)

**Risk Summary:**

- Total risks identified: 11
- High-priority risks (score ≥6): 4
- Critical categories: SEC, OPS, TECH

**Coverage Summary:**

- P0 scenarios: 8 (~15–25 hours)
- P1 scenarios: 10 (~12–20 hours)
- P2 scenarios: 8 (~5–10 hours)
- P3 scenarios: 4 (~2–4 hours)
- **Total effort:** ~34–59 hours (~1–2 weeks)

---

## Not in Scope

| Item | Reasoning | Mitigation |
| ---- | --------- | ---------- |
| **Full OIDC auth flow (Epic 2)** | Keycloak realm config for authentication is Epic 2+ | Epic 1 only validates bring-up, realm import, and base config |
| **Admin app (SvelteKit)** | Admin app scaffolding is Epic 4 | CI gate wired but no-ops gracefully per AC Story 1.5 |
| **WORM/off-host audit sink** | Deferred per AR7 | Covered in Epic 5 |
| **Thai translation** | NFR19 states English-first; Thai deferred | Covered in later epics once UI stabilizes |
| **HA / multi-node deployment** | Single instance to start; HA deferred per NFR17 | Not needed for pilot |
| **Performance/load testing** | ~150 users; no high-scale concern at foundation layer | P3 benchmark only; formal load test Epic 6+ |

---

## Risk Assessment

> Priority classifications: CRITICAL (score 9) → BLOCK; HIGH (score 6–8) → MITIGATE; MEDIUM (score 3–5) → MONITOR; LOW (score 1–2) → DOCUMENT.

### High-Priority Risks (Score ≥6)

| Risk ID | Category | Description | Probability | Impact | Score | Mitigation | Owner | Timeline |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ---------- | ----- | -------- |
| R-001 | SEC | Secrets hard-coded or leaked into git (Keycloak admin password, DB passwords, `.env`) | 2 | 3 | 6 | `.env.example` committed; real `.env` git-ignored; gitleaks gate blocks commits; realm-export.json scanned separately | Rawinan | Before any commit |
| R-002 | OPS | Docker Compose stack fails to reach healthy state (Keycloak can't connect to PostgreSQL, misconfigured credentials, wrong port) | 2 | 3 | 6 | Pinned images by digest; healthchecks defined; documented bring-up procedure with `.env.example` | Rawinan | Story 1.1 |
| R-003 | SEC | Realm export includes client secrets, signing key material, or password hashes — committed to git undetected | 2 | 3 | 6 | gitleaks realm-export-check CI job (already wired in ci.yml); export procedure documented; manual review checklist | Rawinan | Story 1.2 |
| R-004 | SEC | Nginx security edge misconfigured — missing HSTS, CSP `frame-ancestors 'none'`, or rate-limit absent on auth surfaces | 2 | 3 | 6 | Automated header-assertion tests (curl/API); Nginx config linted in CI; NFR4/FR50 acceptance criteria verify headers | Rawinan | Story 1.3 |

### Medium-Priority Risks (Score 3–5)

| Risk ID | Category | Description | Probability | Impact | Score | Mitigation | Owner |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ---------- | ----- |
| R-005 | TECH | Keycloak and PostgreSQL image versions drift (`:latest` crept in, or digest pinning missed) | 1 | 3 | 3 | Compose file reviewed; test asserts exact version tag from `docker inspect` output | Rawinan |
| R-006 | OPS | Two-database separation violated — keycloak DB and admin DB share the same Postgres role or DB name | 2 | 2 | 4 | Bring-up test queries `pg_catalog.pg_database` for both `keycloak` and `admin`; roles compared | Rawinan |
| R-007 | TECH | Realm export not idempotent — re-import on clean stack produces different realm state than original | 2 | 2 | 4 | Test exports from a clean stack, re-imports, and diffs key fields (realm name, login settings) | Rawinan |
| R-008 | SEC | Deep Sea CSS variables fail WCAG AA — colour contrast below 4.5:1 for normal text or 3:1 for large text | 1 | 3 | 3 | axe-core or manual contrast audit against DESIGN.md token palette; tested during Story 1.4 | Rawinan |
| R-009 | TECH | CI gate runs language-specific checks (ESLint/tsc/bun audit) even though admin app doesn't exist yet — builds fail spuriously | 2 | 2 | 4 | Story 1.5 AC explicitly requires graceful no-op; CI job structure tested to confirm no spurious failures | Rawinan |

### Low-Priority Risks (Score 1–2)

| Risk ID | Category | Description | Probability | Impact | Score | Action |
| ------- | -------- | ----------- | ----------- | ------ | ----- | ------ |
| R-010 | OPS | `.env.example` missing required keys discovered only at bring-up time | 1 | 2 | 2 | Bring-up test uses `.env.example` as-is; documents any missing keys | Monitor |
| R-011 | BUS | Deep Sea token values diverge from DESIGN.md spec (wrong hex, wrong spacing unit) | 1 | 1 | 1 | Cross-reference test between CSS variable values and DESIGN.md token table | Monitor |

### Risk Category Legend

- **TECH**: Technical / architecture (integration, version drift, idempotency)
- **SEC**: Security (secrets in git, header hardening, WCAG)
- **PERF**: Performance (not primary risk at this epic level)
- **DATA**: Data integrity (not primary risk at foundation layer)
- **BUS**: Business / UX impact
- **OPS**: Operations (stack bring-up, DB separation, CI gate stability)

---

## NFR Planning

**Purpose:** Capture NFR thresholds, planned validation, and expected evidence for later `nfr-assess`. No final PASS/CONCERNS/FAIL decisions here.

| NFR Category | Requirement / Threshold | Risk Link | Planned Validation | Evidence Needed |
| ------------ | ----------------------- | --------- | ------------------ | --------------- |
| Security — Secrets | No secret in git; `.env` git-ignored; realm export clean (NFR1, NFR2, NFR3) | R-001, R-003 | gitleaks detect on push + realm-export-check CI job | CI job green logs; gitleaks report |
| Security — Transport | All traffic TLS+HSTS; login surfaces CSP `frame-ancestors 'none'`; SameSite cookies (NFR4) | R-004 | curl-based header assertions in integration test; Nginx config review | HTTP response header dump from test run |
| Security — Rate limiting | Public unauthenticated endpoints rate-limited (FR50) | R-004 | Burst-request test against Nginx edge (e.g., 100 req/s against `/auth`) | Test run showing 429 responses |
| Maintainability — Config-as-code | Realm diff reviewable and re-importable; secrets stripped (AR2) | R-003, R-007 | Export → clean-stack import → key-field diff test | Diff output; import success log |
| Maintainability — CI gate | Pre-commit hook + CI enforce gitleaks, Semgrep, realm-config lint on every change (AR8) | R-009 | CI pipeline run on PR; pre-commit hook smoke test | GitHub Actions run log |
| Reliability — Stack health | `docker compose up` reaches healthy state with `.env.example`; Keycloak admin console reachable (AR1) | R-002 | Integration test: `docker compose up -d && wait-for-it` + HTTP GET admin console | Container health status; HTTP 200 on admin console |
| Accessibility — WCAG AA | All documented text/background pairings in Deep Sea CSS meet WCAG AA contrast (UX-DR1) | R-008 | axe-core audit or manual contrast check of token palette | Contrast audit report |

**Unknown thresholds:**

- HSTS `max-age` value not specified in PRD/architecture — assume `max-age=31536000; includeSubDomains` (OWASP recommendation); confirm with team.
- Rate-limit burst threshold for Nginx (FR50 says "throttle excessive traffic" without a numeric threshold) — mark as UNKNOWN; define during Story 1.3 implementation.
- Semgrep ruleset not yet specified (AR8 mentions SAST but no ruleset named) — default to `p/default` or project-specific rules; confirm before Story 1.5.

---

## Entry Criteria

- [ ] Epic 1 stories reviewed by developer (Rawinan)
- [ ] `.env.example` template drafted with all required keys named
- [ ] Local Docker Desktop / Docker Engine available and functional
- [ ] GitHub Actions runner accessible (ubuntu-latest)
- [ ] DESIGN.md token table available for cross-reference (confirm `_bmad-output/planning-artifacts/ux-designs/` path)

## Exit Criteria

- [ ] All P0 tests passing
- [ ] All P1 tests passing (or failures triaged with waivers)
- [ ] No open R-001, R-002, R-003, R-004 items (all high-priority risks mitigated)
- [ ] CI pipeline green on `epic-1` branch for all 5 stories
- [ ] `docker compose up` reaches healthy state from clean checkout with `.env.example`
- [ ] Realm export passes gitleaks scan (realm-export-check CI job green)
- [ ] Nginx security headers verified

---

## Test Coverage Plan

> **Note:** P0/P1/P2/P3 = priority / risk level, NOT execution timing. Execution timing is defined in the Execution Strategy section.

### P0 — Critical

**Criteria:** Blocks core journey + High risk (≥6) + No workaround

| Req / AC | Test Level | Risk Link | Test Count | Owner | Notes |
| --------- | ---------- | --------- | ---------- | ----- | ----- |
| Story 1.1 AC-1: `docker compose up` → Keycloak healthy, admin console reachable | Integration (shell) | R-002 | 2 | Dev | `wait-for-it` + curl GET admin console; one for fresh bring-up, one for idempotent restart |
| Story 1.1 AC-2: Two separate DBs (`keycloak` + `admin`) with distinct roles | Integration (shell) | R-006 | 2 | Dev | `psql` query `pg_catalog.pg_database`; assert two distinct DB names and role separation |
| Story 1.1 AC-4: No secret hard-coded; real `.env` git-ignored | CI / gitleaks | R-001 | 1 | CI | Already wired in ci.yml (`gitleaks` job); assert clean exit |
| Story 1.2 AC-2: Realm export contains no client secrets, passwords, or signing-key material | CI / gitleaks | R-003 | 1 | CI | `realm-export-check` job already wired; assert clean exit |
| Story 1.3 AC-1: HSTS + standard security headers + CSP `frame-ancestors 'none'` on auth surfaces | Integration (curl) | R-004 | 2 | Dev | `curl -I` assertions on Nginx-proxied Keycloak endpoint; one for HSTS/CSP, one for other headers |

**Total P0:** 8 tests, ~15–25 hours

---

### P1 — High

**Criteria:** Important features + Medium risk (3–5) + Common workflows

| Req / AC | Test Level | Risk Link | Test Count | Owner | Notes |
| --------- | ---------- | --------- | ---------- | ----- | ----- |
| Story 1.1 AC-3: Keycloak and PostgreSQL pinned by exact version/digest | Unit (shell / jq) | R-005 | 2 | Dev | `docker inspect` image digest; assert no `:latest` tag in compose file |
| Story 1.2 AC-1: Realm imported automatically on stack start; baseline settings applied | Integration (shell) | R-007 | 2 | Dev | Query Keycloak Admin REST `/realms/{realm}` after bring-up; assert realm name and login settings |
| Story 1.2 AC-3: Realm change exportable, diff reviewable, re-importable on clean stack | Integration (shell) | R-007 | 2 | Dev | Mutate realm setting → export → tear down → bring up clean → import → assert setting persisted |
| Story 1.3 AC-2: Edge rate-limiting throttles excessive traffic on public endpoints | Integration (curl) | R-004 | 2 | Dev | Burst 100+ requests; assert HTTP 429 responses returned |
| Story 1.5 AC-1: Pre-commit hook runs gitleaks, Semgrep, realm-config lint and blocks on failure | Unit (shell) | R-009 | 1 | Dev | Inject a synthetic secret; assert hook exits non-zero |
| Story 1.5 AC-3: Language-specific checks (ESLint/tsc/bun audit) no-op gracefully when admin app absent | CI | R-009 | 1 | CI | Push branch without admin app code; assert CI completes without false failures |

**Total P1:** 10 tests, ~12–20 hours

---

### P2 — Medium

**Criteria:** Secondary features + Low risk (1–2) + Edge cases

| Req / AC | Test Level | Risk Link | Test Count | Owner | Notes |
| --------- | ---------- | --------- | ---------- | ----- | ----- |
| Story 1.3 AC-3: JWKS and discovery endpoints cacheable through edge | Unit (curl) | — | 2 | Dev | Assert `Cache-Control` / `Expires` headers on `/.well-known/openid-configuration` and `/protocol/openid-connect/certs` |
| Story 1.4 AC-1: `deep-sea.css` exposes all DESIGN.md tokens as CSS variables | Unit (JS/grep) | R-011 | 2 | Dev | Parse DESIGN.md token table; assert each token appears as `--` variable in `deep-sea.css` |
| Story 1.4 AC-2: All documented text/background pairings meet WCAG AA | Unit (axe-core / manual) | R-008 | 2 | Dev | Run contrast check against token palette; assert ratio ≥4.5:1 (normal) / ≥3:1 (large) |
| Story 1.5 AC-2: CI runs full suite (formatting, SAST, secret-scan, dependency audit, realm-config lint) and fails on violation | CI | — | 2 | CI | Inject known Semgrep-detectable pattern; assert CI exits non-zero on that specific job |

**Total P2:** 8 tests, ~5–10 hours

---

### P3 — Low

**Criteria:** Nice-to-have + Exploratory + Benchmarks

| Req / AC | Test Level | Test Count | Owner | Notes |
| --------- | ---------- | ---------- | ----- | ----- |
| Baseline bring-up latency benchmark (Keycloak ready time from `docker compose up`) | Benchmark (shell) | 1 | Dev | Record time-to-healthy; reference for regression detection in later stories |
| Exploratory: edge Nginx behaviour under simulated upstream Keycloak downtime | Exploratory | 1 | Dev | Verify Nginx returns a useful error (not a raw 502) when upstream is down |
| `.env.example` completeness cross-check (all keys actually consumed by compose/config present) | Unit (grep/lint) | 1 | Dev | Script compares keys in compose `environment:` blocks with keys in `.env.example` |
| Semgrep SAST report review (false-positive rate, relevant findings) | Exploratory | 1 | Dev | Manual scan of first Semgrep report; tune config if needed |

**Total P3:** 4 tests, ~2–4 hours

---

## Execution Strategy

**Philosophy:** Run everything on every PR unless it is genuinely expensive or long-running. With parallelization, 30 tests complete in under 10 minutes.

| Trigger | Suite | Expected Duration | Rationale |
| ------- | ----- | ----------------- | --------- |
| **Every PR / push** | All functional tests (P0 + P1 + P2): gitleaks, realm-export-check, header assertions, bring-up test, DB separation, version-pin, realm import/export/re-import, rate-limit, WCAG contrast, CSS token cross-check, pre-commit hook smoke, CI gate validation | ~8–12 min | Cheap enough to run on every change; catches regressions immediately |
| **Nightly** | P3 benchmarks (bring-up latency), Semgrep full ruleset scan | ~15–30 min | Deterministic benchmarks are noise-sensitive; run overnight for cleaner baseline |
| **On-demand** | Exploratory (Nginx error behaviour, Semgrep report review) | N/A | Manual; run when changing Nginx config or Semgrep rules |

---

## Resource Estimates

| Priority | Count | Hours (range) | Notes |
| -------- | ----- | ------------- | ----- |
| P0 | 8 | ~15–25 | Docker Compose integration setup, gitleaks validation |
| P1 | 10 | ~12–20 | Realm import/export tests, rate-limit burst test, CI hook tests |
| P2 | 8 | ~5–10 | WCAG contrast, CSS cross-check, cacheability assertions |
| P3 | 4 | ~2–4 | Benchmarks, exploratory |
| **Total** | **30** | **~34–59 hours** | **~1–2 weeks solo** |

**Test Data & Prerequisites:**

- `.env.example` with all required variables
- Local Docker Engine with internet access (to pull pinned images on first run)
- `wait-for-it.sh` or equivalent for Keycloak health polling
- `psql` CLI for DB separation assertions
- axe-core CLI or equivalent for WCAG contrast audit

**Tooling:**

- Shell scripts (`bash` / `bats`) for bring-up, DB, header, rate-limit tests
- `curl` for HTTP header assertions
- `docker inspect` + `jq` for image digest/version assertions
- `gitleaks` binary (already pinned in ci.yml)
- axe-core or manual contrast checker for WCAG AA (Story 1.4)
- GitHub Actions (`ubuntu-latest`) for CI gate tests

**Environment:**

- Local: Docker Compose stack (for integration tests)
- CI: GitHub Actions `ubuntu-latest` (for CI gate tests)
- No external services required at this epic level

---

## Quality Gate Criteria

### Pass/Fail Thresholds

- **P0 pass rate:** 100% (no exceptions — stack must bring up, secrets must not leak)
- **P1 pass rate:** ≥95% (waivers require documented rationale)
- **P2/P3 pass rate:** ≥90% (informational; failures tracked not blocked)
- **High-risk mitigations (R-001 through R-004):** 100% complete or approved waivers before merging epic branch

### Coverage Targets

- **Critical paths (bring-up, secret hygiene):** 100%
- **Security headers / NFR4:** 100%
- **Config-as-code round-trip:** 100%
- **WCAG AA token palette:** 100%
- **NFR evidence identified:** All 7 NFR categories in scope have planned evidence artifact

### Non-Negotiable Requirements

- [ ] All P0 tests pass
- [ ] `gitleaks` CI job: green (R-001)
- [ ] `realm-export-check` CI job: green (R-003)
- [ ] Nginx header assertion test: green (R-004)
- [ ] `docker compose up` smoke test: green (R-002)
- [ ] No R-001, R-002, R-003, R-004 items open at epic close

---

## Mitigation Plans

### R-001: Secrets Hard-Coded or Leaked into Git (Score: 6)

**Mitigation Strategy:**
1. Commit `.env.example` with all required key names but no real values (placeholder comments only)
2. Add `.env` and any `*.env` variants to `.gitignore`
3. gitleaks gate already wired in `ci.yml` — verify it covers `.env.example` and all source files
4. Add explicit test: commit a synthetic secret string to a scratch branch; assert gitleaks exits non-zero

**Owner:** Rawinan
**Timeline:** Story 1.1 implementation
**Status:** Planned
**Verification:** gitleaks CI job green; `.env` not tracked by `git status`

---

### R-002: Stack Fails to Reach Healthy State (Score: 6)

**Mitigation Strategy:**
1. Define `healthcheck` in docker-compose for both Keycloak and PostgreSQL containers
2. Integration test: `docker compose up -d` → poll until healthy (max 120 s) → assert Keycloak admin console returns HTTP 200
3. Document bring-up steps in README / `.env.example` comments
4. Pin images by digest (`@sha256:...`) not just tag — prevents silent drift

**Owner:** Rawinan
**Timeline:** Story 1.1 implementation
**Status:** Planned
**Verification:** Integration test green; `docker compose ps` shows all services healthy

---

### R-003: Realm Export Contains Secrets (Score: 6)

**Mitigation Strategy:**
1. Export procedure documented: always use Keycloak partial-export (exclude realm keys, client secrets)
2. `realm-export-check` CI job already wired in `ci.yml` — verify ruleset covers Keycloak client-secret patterns
3. Add pre-export checklist: remove `clients[].secret`, `components` (signing keys), `users[].credentials`
4. Test: inject a synthetic client secret into realm-export.json; assert `realm-export-check` exits non-zero

**Owner:** Rawinan
**Timeline:** Story 1.2 implementation
**Status:** Planned
**Verification:** `realm-export-check` CI job green on production export; negative test exits non-zero on synthetic secret

---

### R-004: Nginx Security Edge Misconfigured (Score: 6)

**Mitigation Strategy:**
1. Nginx config includes: `add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;`, `add_header Content-Security-Policy "frame-ancestors 'none'" always;`, standard headers (X-Content-Type-Options, X-Frame-Options, Referrer-Policy)
2. `limit_req_zone` configured for `/auth/` location; return 429 on burst
3. Curl-based integration test asserts all required headers on a real request through the edge
4. Test: burst 100+ requests and assert HTTP 429 returned

**Owner:** Rawinan
**Timeline:** Story 1.3 implementation
**Status:** Planned
**Verification:** Header assertion test green; rate-limit burst test green; curl -I output archived as evidence

---

## Assumptions and Dependencies

### Assumptions

1. Docker Engine is available on the developer machine and in GitHub Actions `ubuntu-latest` — no extra runner configuration needed.
2. Keycloak 26.6.x supports partial export (excluding keys/credentials) natively — no custom export script required.
3. The DESIGN.md token table is the canonical source of truth for Deep Sea token names and values.
4. The gitleaks ruleset already covers Keycloak client-secret patterns; if not, the ruleset must be extended before Story 1.2 merges.
5. No HSTS `max-age` value is mandated by PRD — OWASP recommendation (`31536000`) is used; team to confirm.
6. Rate-limit threshold (requests/second) for FR50 is not yet defined; Story 1.3 implementation will set the value; tests will assert its existence and correctness, not a specific number.

### Dependencies

1. `.env.example` template — required before Story 1.1 test can run; author: Rawinan, target: Story 1.1 start
2. DESIGN.md token table path confirmed — required for Story 1.4 CSS cross-check; verify path `_bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/DESIGN.md`
3. Semgrep ruleset selection — required before Story 1.5 CI gate test; default `p/default` assumed unless team specifies otherwise

### Risks to Plan

- **Risk:** Keycloak 26.6.x partial-export behaviour differs from expected (exports more or fewer fields)
  - **Impact:** R-003 mitigation weakened; secrets could survive in export
  - **Contingency:** Add explicit field-level assertions in the export test (check `jq '.clients[].secret'` is null/absent)

- **Risk:** GitHub Actions `ubuntu-latest` runner does not include `psql` CLI out of the box
  - **Impact:** P0 DB separation test blocked
  - **Contingency:** Add `apt-get install postgresql-client` step to the CI job; or use `docker exec` against the compose network

---

## Interworking & Regression

| Service / Component | Impact | Regression Scope |
| ------------------- | ------ | ---------------- |
| **GitHub Actions CI** | gate jobs added in Story 1.5 must not break existing `gitleaks` / `realm-export-check` jobs | All existing CI jobs must still pass after Story 1.5 adds Semgrep/pre-commit |
| **Keycloak (later epics)** | Epic 2+ realm config depends on the base realm import from Story 1.2 | Re-run Story 1.2 import test after any realm-export.json change in later epics |
| **Nginx edge (later epics)** | Subsequent epics add routes / CSP directives | Story 1.3 header assertion test must be re-run and updated when new surfaces are added |
| **Deep Sea CSS (later epics)** | Admin app (Epic 4) and Keycloak theme (Epic 2) import `deep-sea.css` | Story 1.4 token cross-check re-run if DESIGN.md is amended |

---

## Follow-on Workflows

- Run `*atdd` to generate failing P0 tests before implementation (separate workflow; not auto-run).
- Run `*automate` for broader test coverage once implementation exists.
- Run `*framework` to configure the test framework (bats / shell-based) for integration tests.
- Run `*ci` to formalize CI pipeline stages (nightly benchmarks, shard configuration).

---

## Appendix

### Knowledge Base References

- `risk-governance.md` — risk classification framework (TECH/SEC/PERF/DATA/BUS/OPS, P×I scoring)
- `probability-impact.md` — probability and impact scale definitions
- `test-levels-framework.md` — unit / integration / E2E selection criteria
- `test-priorities-matrix.md` — P0–P3 prioritization criteria

### Related Documents

- Epic: `_bmad-output/planning-artifacts/epics.md` — Epic 1 stories and acceptance criteria (lines 242–355)
- Architecture: `_bmad-output/planning-artifacts/architecture.md` — AR1–AR8, Decision 1
- Sprint Status: `_bmad-output/implementation-artifacts/sprint-status.yaml`
- Existing CI: `.github/workflows/ci.yml`

---

**Generated by:** BMad TEA Agent — Test Architect Module
**Workflow:** `bmad-testarch-test-design`
**Version:** 4.0 (BMad v6)
