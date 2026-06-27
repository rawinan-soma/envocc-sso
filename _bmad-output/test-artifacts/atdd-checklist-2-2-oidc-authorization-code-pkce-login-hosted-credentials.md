---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-06-27'
storyId: '2.2'
storyKey: 2-2-oidc-authorization-code-pkce-login-hosted-credentials
storyFile: _bmad-output/implementation-artifacts/2-2-oidc-authorization-code-pkce-login-hosted-credentials.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-2-2-oidc-authorization-code-pkce-login-hosted-credentials.md
generatedTestFiles:
  - tests/unit/oidc-pkce-lint.bats
  - tests/integration/oidc-pkce-flow.bats
inputDocuments:
  - _bmad-output/implementation-artifacts/2-2-oidc-authorization-code-pkce-login-hosted-credentials.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-2.md
  - _bmad/tea/config.yaml
  - tests/helpers/common.bash
  - tests/integration/realm-import.bats
  - tests/unit/secret-hygiene.bats
  - scripts/lint-realm-export.py
---

# ATDD Checklist: Story 2.2 — OIDC Authorization Code + PKCE Login (Hosted Credentials)

## TDD Red Phase (Current)

Red-phase test scaffolds generated.

- Unit Tests (`tests/unit/oidc-pkce-lint.bats`): 10 tests (all skipped — RED PHASE)
- Integration Tests (`tests/integration/oidc-pkce-flow.bats`): 9 tests (all skipped — RED PHASE)
- **Total:** 19 tests, all with `skip "RED PHASE — ..."` annotation

## Stack & Generation Mode

- **Detected stack:** `backend` (pure Keycloak realm configuration — no browser UI, no application API endpoints)
- **Generation mode:** AI generation (no browser recording needed; tests are BATS + curl)
- **Test framework:** BATS (matches existing `tests/unit/*.bats` and `tests/integration/*.bats` patterns)
- **Execution mode:** Sequential

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | Auth Code + PKCE only; Implicit and ROPC unavailable (FR1, FR3) | TS-220a, TS-220b, TS-220b2, TS-220c (integration) + TS-220h, TS-220n, TS-220i, TS-220j, TS-220k, TS-220k2, TS-220l, TS-220m, TS-220m2, TS-220p, TS-220q (unit lint) | P0–P1 |
| AC2 | Credentials submitted to IdP only; RP receives only auth code (FR2) | Structural — covered by AC1/AC3/AC4 integration tests; Playwright E2E deferred to Story 2.5 | — |
| AC3 | Exact-match redirect URI enforcement (FR4) | TS-220d, TS-220e (integration) | P1 |
| AC4 | Auth code: single-use, short-lived ≤60s, PKCE-bound, replay-detected (FR47) | TS-220f, TS-220g (integration) + TS-220h, TS-220n (unit lint for accessCodeLifespan) | P0 |

## Test File Summary

### `tests/unit/oidc-pkce-lint.bats`

Covers Tasks 3.1–3.5 (lint script extension). Validates `scripts/lint-realm-export.py` against synthetic JSON fixtures — no live Keycloak required.

| Test ID | Priority | Description | Task |
|---------|----------|-------------|------|
| TS-220h | P0 | lint exits 1 when accessCodeLifespan is absent | Task 3.1 |
| TS-220n | P1 | lint exits 1 when accessCodeLifespan > 60 (e.g. 120) | Task 3.1 |
| TS-220i | P0 | lint exits 1 when a client has implicitFlowEnabled: true | Task 3.2 |
| TS-220j | P0 | lint exits 1 when a client has directAccessGrantsEnabled: true | Task 3.3 |
| TS-220k | P0 | lint exits 1 when a public client lacks pkce.code.challenge.method: S256 (empty attrs) | Task 3.4 |
| TS-220k2 | P0 | lint exits 1 when a public client has no attributes key at all | Task 3.4 |
| TS-220l | P1 | lint exits 0 for valid Story 2.2 realm configuration | Tasks 3.1–3.5 |
| TS-220m | P1 | lint exits 0 when clients key is absent (no-op) | Task 3 |
| TS-220m2 | P1 | lint exits 0 when clients array is empty (no-op) | Task 3 |
| TS-220p | P1 | lint includes clientId in per-client violation output | Task 3.5 |
| TS-220q | P1 | lint exits 0 against the real keycloak/realm-export.json after Story 2.2 changes | Tasks 2+3 done |

### `tests/integration/oidc-pkce-flow.bats`

Covers Tasks 4.2–4.8 (BATS integration tests against live Keycloak). Requires `INTEGRATION=1` + running Docker Compose stack with Story 2.2 realm config imported.

| Test ID | Priority | Description | Task |
|---------|----------|-------------|------|
| TS-220a | P0 | Implicit grant (response_type=token) rejected (HTTP 400 or redirect with error=) | Task 4.2 |
| TS-220b | P0 | ROPC (grant_type=password) rejected with HTTP 400 | Task 4.3 |
| TS-220b2 | P0 | ROPC rejection body contains error=unauthorized_client | Task 4.3 |
| TS-220c | P0 | Auth request without code_challenge rejected (error=invalid_request in redirect) | Task 4.4 |
| TS-220d | P1 | Extra-path redirect URI rejected with HTTP 400 | Task 4.5 |
| TS-220e | P1 | Wrong-host redirect URI rejected with HTTP 400 | Task 4.6 |
| TS-220f | P0 | Auth code replay: second exchange returns 400 invalid_grant | Task 4.7 |
| TS-220g | P0 | Wrong code_verifier rejected with 400 invalid_grant | Task 4.8 |

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Identify which test(s) correspond to the task you are implementing (see "Task" column above).
2. Remove the `skip "RED PHASE — ..."` annotation from those tests.
3. Run unit tests: `bats tests/unit/oidc-pkce-lint.bats`
4. Run integration tests: `INTEGRATION=1 bats tests/integration/oidc-pkce-flow.bats`
5. Verify the activated test **fails** first (confirming red phase).
6. Implement the task until the test passes (green phase).
7. Commit passing tests with the implementation.

### Recommended Activation Order

- **Task 1 (realm-export.json baseline settings — AC4):**
  Activate TS-220h (accessCodeLifespan absent), TS-220n (accessCodeLifespan > 60)
  → Implement: add `"accessCodeLifespan": 60` to realm JSON

- **Task 2 (test-oidc-client registration — AC1, AC3):**
  Activate TS-220i, TS-220j, TS-220k, TS-220k2 (per-client lint checks)
  → Implement: add test-oidc-client entry in realm JSON

- **Task 3.1–3.5 (lint script extension):**
  Activate TS-220l (passing config), TS-220m, TS-220m2 (empty clients), TS-220p (clientId in error), TS-220q (real file)
  → Implement: extend `scripts/lint-realm-export.py` with checks 4–7

- **Task 4.2–4.4 (grant-type + PKCE rejections):**
  Activate TS-220a, TS-220b, TS-220b2, TS-220c
  → Requires: running stack with Tasks 1+2 already implemented

- **Task 4.5–4.6 (redirect URI enforcement):**
  Activate TS-220d, TS-220e
  → Requires: running stack with Tasks 1+2 already implemented

- **Task 4.7–4.8 (replay + wrong verifier):**
  Activate TS-220f, TS-220g
  → Requires: running stack + test user creation working in setup()

## Implementation Guidance

### Files to modify (existing):
- `keycloak/realm-export.json` — add `"accessCodeLifespan": 60`; add `test-oidc-client` under `"clients"`
- `scripts/lint-realm-export.py` — extend with checks 4–7 per Task 3 spec

### Files created (new):
- `tests/unit/oidc-pkce-lint.bats` — unit tests for lint script extension (this file)
- `tests/integration/oidc-pkce-flow.bats` — BATS integration tests for grant-type + PKCE enforcement

### Files NOT modified in this story:
- `compose.yaml` — no changes needed
- `.github/workflows/ci.yml` — `realm-lint` job auto-picks up extended lint; integration tests are local-only

### Key constraints:
- `directAccessGrantsEnabled` defaults to `true` in Keycloak — MUST be explicitly set to `false`
- PKCE enforcement is per-client via `attributes.pkce.code.challenge.method: S256`
- Integration tests run locally only: `INTEGRATION=1 bats tests/integration/oidc-pkce-flow.bats`
- For Tasks 4.7/4.8 (replay + wrong verifier), the full multi-step PKCE login flow is required; the `acquire_auth_code` helper in the test file encapsulates this

## Key Risks and Assumptions

- **R-001 (SEC, Score 6):** Grant type restrictions misconfigured — implicit or ROPC inadvertently enabled. Mitigated by TS-220a, TS-220b, TS-220b2 (integration) and TS-220i, TS-220j (unit lint).
- **PKCE test flow assumption:** TS-220f and TS-220g use `acquire_auth_code()` which parses the Keycloak login form's action URL from HTML. If Keycloak 26 changes the form structure, this helper needs updating. The form `action` attribute is standard HTML — no custom parsing expected.
- **ROPC error code:** Story dev notes specify `error=unauthorized_client` for ROPC rejection. TS-220b2 asserts this. If Keycloak returns a different error code, update the test and document the actual behavior.
- **Implicit flow rejection behavior:** Keycloak may return HTTP 400 directly (no redirect) or redirect with `error=` in the Location header — TS-220a accepts both. Verify actual behavior after implementation.
- **AC2 (credentials never transit RP):** Structural guarantee via hosted-credentials architecture. A P1 Playwright E2E test for this is deferred to Story 2.5 when the Deep Sea login theme is implemented.

## ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-2-2-oidc-authorization-code-pkce-login-hosted-credentials.md`
- Unit tests: `tests/unit/oidc-pkce-lint.bats`
- Integration tests: `tests/integration/oidc-pkce-flow.bats`
- Story file: `_bmad-output/implementation-artifacts/2-2-oidc-authorization-code-pkce-login-hosted-credentials.md`
