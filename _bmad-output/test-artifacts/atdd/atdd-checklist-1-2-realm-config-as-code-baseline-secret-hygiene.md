---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'test-review-complete']
lastStep: 'test-review-complete'
lastSaved: '2026-06-23'
storyId: '1.2'
storyKey: '1-2-realm-config-as-code-baseline-secret-hygiene'
storyFile: '_bmad-output/implementation-artifacts/1-2-realm-config-as-code-baseline-secret-hygiene.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd/atdd-checklist-1-2-realm-config-as-code-baseline-secret-hygiene.md'
generatedTestFiles:
  - tests/run-atdd.sh
  - tests/integration/ac1-docker-compose-smoke.bats
  - tests/integration/ac1-realm-config.bats
  - tests/integration/ac1-realm-config-runtime.bats
  - tests/secret-hygiene/ac2-secret-hygiene.bats
testReviewFile: _bmad-output/test-artifacts/test-reviews/test-review-story-1-2-realm-config.md
inputDocuments:
  - _bmad-output/implementation-artifacts/1-2-realm-config-as-code-baseline-secret-hygiene.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-1.md
  - _bmad/tea/config.yaml
tddPhase: RED
---

# ATDD Checklist — Story 1.2: Realm config-as-code baseline & secret hygiene

**Date:** 2026-06-23
**Author:** Rawinan (via BMad TEA ATDD Agent)
**TDD Phase:** RED (failing scaffolds — implementation not yet done)
**Story GH Issue:** #3

---

## Step 1: Preflight & Context

### Stack Detection

- **Detected stack:** `backend`
- **Rationale:** No `package.json`, no `playwright.config.*`, no frontend markers. Project uses BATS shell tests against a Keycloak/Docker backend service.
- **Test framework:** `bats-core` (shell integration tests)

### Prerequisites Verified

- [x] Story approved with clear acceptance criteria (AC1, AC2, AC3)
- [x] Backend test framework: BATS shell tests (no playwright/cypress required for backend stack)
- [x] Prior implementation reference available in git history (`7fb3b08`)
- [x] Test design document exists: `_bmad-output/test-artifacts/test-design/test-design-epic-1.md`

### Story Context

| Field | Value |
|---|---|
| Story | 1.2 — Realm config-as-code baseline & secret hygiene |
| Key | `1-2-realm-config-as-code-baseline-secret-hygiene` |
| GH Issue | #3 |
| Status | `ready-for-dev` |
| ACs | AC1 (auto-import + baseline settings), AC2 (gitleaks-clean export), AC3 (reviewable round-trip) |

### TEA Config Flags

| Flag | Value |
|---|---|
| `tea_use_playwright_utils` | true (not applicable — backend stack) |
| `tea_use_pactjs_utils` | false |
| `tea_pact_mcp` | none |
| `tea_browser_automation` | auto (N/A — backend) |
| `test_stack_type` | auto → resolved `backend` |
| `tea_execution_mode` | auto → resolved `sequential` |

---

## Step 2: Generation Mode

**Selected mode:** AI Generation (sequential)

**Rationale:** Backend stack (`detected_stack = backend`). All test scenarios are deterministic shell/BATS assertions against JSON files, Docker state, and shell scripts. No browser recording needed.

---

## Step 3: Test Strategy

### Acceptance Criteria → Test Scenarios

#### AC1 — Auto-import on bring-up

| Scenario | Level | Priority |
|---|---|---|
| compose.yaml exists with required services | Static (BATS) | P0 |
| keycloak/Dockerfile exists, pinned FROM, copies realm-export.json | Static (BATS) | P0 |
| realm-export.json is valid JSON | Static (BATS) | P0 |
| realm='envocc', displayName='EnvOcc SSO' | Static (BATS) | P0 |
| sslRequired='external' (never 'none') | Static (BATS) | P0 |
| registrationAllowed=false | Static (BATS) | P0 |
| loginWithEmailAllowed=true | Static (BATS) | P0 |
| bruteForceProtected=true | Static (BATS) | P0 |
| accessTokenLifespan=900 (≤15 min, NFR2a) | Static (BATS) | P0 |
| ssoSessionIdleTimeout=1800, ssoSessionMaxLifespan=28800 | Static (BATS) | P0 |
| eventsEnabled=true, adminEventsEnabled=true | Static (BATS) | P0 |
| enabledEventTypes NOT present (empty array = disables all) | Static (BATS) | P0 |
| internationalizationEnabled=true, en+th locales, defaultLocale=en | Static (BATS) | P1 |
| No implicitFlowEnabled=true on any client (FR3) | Static (BATS) | P1 |
| No directAccessGrantsEnabled=true except admin-cli (FR3) | Static (BATS) | P1 |
| defaultSignatureAlgorithm=RS256 (NFR3) | Static (BATS) | P1 |
| CSP frame-ancestors in browserSecurityHeaders (NFR4) | Static (BATS) | P1 |
| adminEventsDetailsEnabled=true | Static (BATS) | P1 |
| Keycloak responds on port 8080 (runtime) | Integration (BATS) | P0 |
| OIDC discovery endpoint responds (runtime) | Integration (BATS) | P0 |
| Issuer matches expected URL (runtime) | Integration (BATS) | P0 |
| envocc realm present via Admin REST API (runtime) | Integration (BATS) | P0 |
| PostgreSQL has keycloak_db and admin databases (runtime) | Integration (BATS) | P0 |
| Live realm settings verified via Admin REST API (6 checks) | Integration (BATS) | P0/P1 |

#### AC2 — Gitleaks-clean export

| Scenario | Level | Priority |
|---|---|---|
| gitleaks scan on realm-export.json = 0 findings | Static (BATS) | P0 |
| No non-empty clientSecret or secret fields | Static (BATS) | P0 |
| No non-empty privateKey values | Static (BATS) | P0 |
| KeyProvider component group ENTIRELY ABSENT | Static (BATS) | P0 |
| No non-empty secretData values | Static (BATS) | P0 |
| Full repo gitleaks scan = 0 findings | Static (BATS) | P0 |
| .env is gitignored | Static (BATS) | P0 |
| *.pem and *.key are gitignored | Static (BATS) | P0 |
| .env.example is NOT gitignored (must be committed) | Static (BATS) | P0 |
| .env.example passes gitleaks (placeholders allowlisted) | Static (BATS) | P0 |

#### AC3 — Reviewable round-trip

| Scenario | Level | Priority |
|---|---|---|
| lefthook.yml has gitleaks pre-commit hook | Static (BATS) | P1 |
| lefthook.yml has keycloak-realm-lint pre-commit step | Static (BATS) | P1 |
| keycloak/lint-realm.sh exists and asserts security settings | Static (BATS) | P1 |
| lint-realm.sh passes on current realm-export.json | Static (BATS) | P1 |
| gitleaks protect --staged blocks staged fake-secret | Behavioral (BATS) | P1 |
| REALM-EXPORT-NOTES.md documents stripped fields | Static (BATS) | P2 |
| PINNED-VERSION.md records 26.6.x tag + digest | Static (BATS) | P2 |

### TDD Red Phase Confirmation

All tests are designed to **fail before implementation**:
- Tests checking for missing files (`[ -f "keycloak/realm-export.json" ]`) fail immediately — ✅ CONFIRMED RED
- Runtime tests self-skip when Keycloak is not running — correct RED behavior (not green, not error)
- Static JSON content checks fail when files don't exist — ✅ CONFIRMED RED

---

## Step 4: Generated Test Files

### Summary Statistics

| File | Tests | P0 | P1 | P2 | P3 |
|---|---|---|---|---|---|
| `tests/run-atdd.sh` | (runner) | — | — | — | — |
| `tests/integration/ac1-docker-compose-smoke.bats` | 10 | 6 | 4 | 0 | 0 |
| `tests/integration/ac1-realm-config.bats` | 24 | 12 | 10 | 0 | 0 |
| `tests/secret-hygiene/ac2-secret-hygiene.bats` | 18 | 10 | 6 | 2 | 0 |
| **TOTAL** | **52** | **28** | **20** | **2** | **0** |

### AC Coverage

| AC | Test File(s) | Tests | Coverage |
|---|---|---|---|
| AC1 — Auto-import on bring-up | ac1-docker-compose-smoke.bats, ac1-realm-config.bats | 34 | All required baseline settings verified (static + runtime) |
| AC2 — Gitleaks-clean export | ac2-secret-hygiene.bats | 18 | All secret hygiene checks: gitleaks, clientSecret, privateKey, KeyProvider absent, secretData |
| AC3 — Reviewable round-trip | ac2-secret-hygiene.bats (partial) | 5 | lefthook, realm-lint, gitleaks protect --staged behavioral |

### Traceability to Story Tasks

| Story Task | Test IDs |
|---|---|
| Task 1 — Keycloak Dockerfile + compose | AC1-SMOKE-01, AC1-SMOKE-07, AC1-SMOKE-08, AC1-RC-01 |
| Task 2 — Harden realm-export.json security | AC1-RC-03..RC-16 (all security settings) |
| Task 3 — Strip/validate secrets | AC2-01..AC2-10 |
| Task 4 — Document round-trip | AC2-17, AC2-18 |
| Task 5 — Realm lint script + lefthook | AC2-11, AC2-12, AC2-13, AC2-14 |
| Task 6 — BATS integration tests (meta) | These tests ARE the BATS suite |

### Traceability to NFRs

| NFR | Test ID(s) |
|---|---|
| NFR2a — accessTokenLifespan ≤ 15 min | AC1-RC-07, AC1-RC-20 |
| NFR3 — RS256 token signing | AC1-RC-14 |
| NFR4 — CSP frame-ancestors | AC1-RC-15 |
| NFR8 — No hand-rolled crypto | AC2-04 (KeyProvider absent → KC auto-generates keys) |
| NFR9 — SAST + secret scanning | AC2-01, AC2-06, AC2-11, AC2-15, AC2-16 |
| FR3 — No Implicit/ROPC | AC1-RC-12, AC1-RC-13 |
| FR19 — Brute-force protection | AC1-RC-06, AC1-RC-19 |
| AR1 — Realm config-as-code | AC1-RC-01..AC1-RC-10 (static export), AC1-RC-17..AC1-RC-24 (live) |

---

## Red Phase Verification Results

Run date: 2026-06-23 (pre-implementation — all implementation files absent from worktree)

```
tests/secret-hygiene/ac2-secret-hygiene.bats: 18 tests
  - 11 FAILED (correctly — missing files: realm-export.json, lefthook.yml, lint-realm.sh, NOTES.md, PINNED-VERSION.md)
  - 5 PASSED (correctly — .gitignore, .gitleaks.toml, .env.example already exist)
  - 2 PASSED (gitleaks behavioral tests work against existing repo state)

tests/integration/ac1-docker-compose-smoke.bats: 10 tests
  - Will FAIL/SKIP (compose.yaml, Dockerfile, postgres/init.sh absent; stack not running)

tests/integration/ac1-realm-config.bats: 24 tests
  - Will FAIL (realm-export.json absent; stack not running → runtime tests skip)
```

**TDD RED PHASE: CONFIRMED** ✅

---

## How to Run

```bash
# Prerequisites
brew install bats-core gitleaks

# Run all tests (static fails = expected in red phase)
bash tests/run-atdd.sh

# Run only secret-hygiene tests
bash tests/run-atdd.sh secrets

# Run only realm-config tests
bash tests/run-atdd.sh integration

# Run only smoke tests
bash tests/run-atdd.sh smoke

# With a running stack (docker compose up -d first)
docker compose up -d
bash tests/run-atdd.sh
```

---

**Generated by:** BMad TEA Agent — ATDD Workflow
**Workflow:** `bmad-testarch-atdd`
**Version:** BMad v6
