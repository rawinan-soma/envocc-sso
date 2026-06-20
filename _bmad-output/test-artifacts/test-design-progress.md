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

# Test Design Progress — envocc-sso Epic 1

## Step 1: Mode Detection

**Mode selected:** Epic-Level (Phase 4)

**Reason:** Arguments explicitly specify "Epic 1: Keycloak IdP Foundation & SSO Core"; `sprint-status.yaml` exists and confirms `epic-1: backlog`. Epic-level mode is appropriate — single test plan output targeting the 8 stories of Epic 1.

**Prerequisites confirmed:**
- Epic and story requirements: present in `epics.md` (Stories 1.1–1.8 with full ACs)
- Architecture context: present in `architecture.md`

---

## Step 2: Context Loaded

**Configuration (from `_bmad/tea/config.yaml`):**
- `test_artifacts`: `{project-root}/_bmad-output/test-artifacts`
- `tea_use_playwright_utils`: true
- `tea_use_pactjs_utils`: false
- `tea_pact_mcp`: none
- `tea_browser_automation`: auto
- `test_stack_type`: auto → detected **backend** (Keycloak + Rails; no frontend test files yet)
- Loading profile: **API-only** (no `page.goto`/`page.locator` found; stack is backend/fullstack)

**Stack detected:** backend/fullstack — Keycloak (Docker) + Ruby on Rails 8 + PostgreSQL + Nginx; no frontend test files exist yet.

**Artifacts loaded:**
- `epics.md`: Epic 1 definition with Stories 1.1–1.8, FRs covered (FR1–FR11, FR14, FR18, FR19, FR20, FR21–FR24, FR35, FR37, FR45, FR47), ARs (AR1–AR4, AR8), NFRs (NFR1–NFR5, NFR7, NFR8)
- `architecture.md`: Full architecture ADR including Keycloak hardening decisions, data model, integration patterns, secret-hygiene rules, CI/CD pipeline shape
- `sprint-status.yaml`: All Epic 1 stories in `backlog`
- Knowledge fragments loaded: `risk-governance.md`, `probability-impact.md`, `test-levels-framework.md`, `test-priorities-matrix.md`, `nfr-criteria.md`

**Existing test coverage scan:** No test files found in the repository (all stories are backlog; no implementation yet). Starting from zero coverage.

---

## Step 3: Risk Assessment

**14 risks identified:**
- 7 high-priority (score ≥ 6): R-001 through R-008, R-014 (SEC and OPS dominated)
- 4 medium-priority (score 3–5): R-009, R-011, R-012, R-004, R-010, R-013
- 2 low-priority (score 1–2): R-015, R-016

**Top risk areas:**
- SEC: Implicit/ROPC enabled (R-001), PKCE not enforced (R-002), wildcard redirect URI (R-003), refresh-token reuse (R-005), secret committed (R-006), TOTP replay (R-007)
- OPS: Keycloak startup failure (R-008), key-loss scenario untested (R-014)

**NFR thresholds extracted:**
- NFR1: Argon2id ≥ 19 MiB / ≥ 2 iter / p=1
- NFR2a: access/ID token ≤ 15 min
- NFR3: RS256 + active/passive key overlap ≥ token TTL; `alg:none` rejected
- NFR4: Secure/HttpOnly/SameSite cookies; CSP `frame-ancestors 'none'`
- NFR5: PKCE S256; Implicit/ROPC disabled
- NFR7: ≥ 12 char passwords; no composition; breached-password check
- Unknown: Keycloak startup SLA (no formal threshold defined); p95 load-test (deferred to Epic 6)

---

## Step 4: Coverage Plan

**Test counts:**
- P0: 27 test cases
- P1: 22 test cases
- P2: 14 test cases
- P3: 5 test cases

**Execution strategy:**
- Smoke (every commit, < 5 min): 4 checks
- P0 (every commit, < 15 min): 27 tests against running Keycloak
- P1 (every PR to main, < 30 min): 22 tests
- P2/P3 (nightly/on-demand): 19 tests

**Estimates:** 76–108 hours total (~10–14 days)

---

## Step 5: Output Generated

**Output file:** `_bmad-output/test-artifacts/test-design/test-design-epic-1.md`

**Mode:** Sequential (single epic-level output)

**Key gates:**
- P0: 100% pass required
- P1: ≥ 95% pass
- All 7 high-risk items (R-001–R-008, R-014) must have passing tests at merge
- `gitleaks` CI clean (non-negotiable)
- Reference client E2E SSO (Story 1.7) must pass before epic is complete

**Open assumptions:**
- Keycloak version pinned before test harness written
- TOTP test fixture uses injected clock to avoid drift-window flakiness
- Admin API CI credentials supplied via CI secrets (not committed)
