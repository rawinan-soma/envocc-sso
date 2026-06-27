---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-06-27'
storyId: '2.3'
storyKey: '2-3-signed-tokens-jwks-oidc-discovery'
storyFile: '_bmad-output/implementation-artifacts/2-3-signed-tokens-jwks-oidc-discovery.md'
atddChecklistPath: '_bmad-output/test-artifacts/atdd-checklist-2-3-signed-tokens-jwks-oidc-discovery.md'
generatedTestFiles:
  - tests/integration/token-signing.bats
  - tests/integration/jwks-discovery.bats
  - tests/integration/nonce-state.bats
inputDocuments:
  - _bmad-output/implementation-artifacts/2-3-signed-tokens-jwks-oidc-discovery.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-2.md
  - _bmad/tea/config.yaml
  - tests/helpers/common.bash
  - tests/integration/setup_suite.bash
  - tests/integration/ci-gate-jobs.bats
  - tests/integration/realm-import.bats
---

# ATDD Checklist: Story 2.3 — Signed Tokens, JWKS & OIDC Discovery

**Date:** 2026-06-27
**Story:** 2.3
**Story Key:** 2-3-signed-tokens-jwks-oidc-discovery
**TDD Phase:** RED (all tests scaffolded with `skip`)

---

## Step 1: Preflight & Context

### Stack Detection

- `test_stack_type`: `auto` → detected as **backend** (BATS integration tests, Docker Compose stack, no frontend manifests at repo root with SPA framework dependencies)
- No `playwright.config.ts` or `cypress.config.ts` at repo root; test framework is **BATS** (Bash Automated Testing System)
- `tea_use_playwright_utils`: `true` (config default) — overridden to **API-only profile** since `{detected_stack}` is `backend` and no `page.goto` / `page.locator` patterns found in `tests/`

### Prerequisites

- [x] Story 2.3 has clear acceptance criteria (AC1–AC9) in `_bmad-output/implementation-artifacts/2-3-signed-tokens-jwks-oidc-discovery.md`
- [x] BATS test framework in use (existing tests in `tests/integration/`, `tests/unit/`)
- [x] Docker Compose stack available for integration tests (Epic 1 complete)
- [x] `tests/helpers/common.bash` provides shared helpers (`get_admin_token`, `wait_for_healthy`, etc.)

### Story Key and ID

- **story_key:** `2-3-signed-tokens-jwks-oidc-discovery`
- **story_id:** `2.3`
- **story_file:** `_bmad-output/implementation-artifacts/2-3-signed-tokens-jwks-oidc-discovery.md`

---

## Step 2: Generation Mode

**Mode selected:** AI Generation (backend stack, BATS framework, no browser recording needed)

---

## Step 3: Test Strategy

### Acceptance Criteria to Test Scenario Mapping

| AC | Description | Test Scenarios | Level | Priority | File |
|----|-------------|----------------|-------|----------|------|
| AC1 | RS256-signed ID token with required claims | TS-231a, TS-231b | Integration | P0 | `token-signing.bats` |
| AC2 | JWKS endpoint publishes RSA signing key with kid | TS-232a, TS-232b | Integration | P0 | `jwks-discovery.bats` |
| AC3 | state/nonce binding; nonce single-use | TS-233a, TS-233b | Integration | P1 | `nonce-state.bats` |
| AC4 | OIDC discovery document complete | TS-234a | Integration | P1 | `jwks-discovery.bats` |
| AC5 | Token lifetime exp - iat ≤ 900 s | TS-231c | Integration | P0 | `token-signing.bats` |
| AC6 | alg:none rejected | TS-231d, TS-236a | Integration | P0 | `token-signing.bats`, `jwks-discovery.bats` |
| AC7 | Key rotation active/passive overlap in config | TS-237a | Unit (config inspection) | P1 | *(covered by realm-lint AC9 + CI gate)* |
| AC8 | JWKS/discovery Cache-Control headers preserved | TS-238a, TS-238b | Integration | P1 | `jwks-discovery.bats` |
| AC9 | realm-lint extended to assert RSA key provider | TS-239a | Unit | P1 | *(covered by lint script extension + CI gate)* |

### Test Level Decision (Backend Stack)

All tests are **integration-level** BATS tests running against a live Docker Compose stack.
No E2E / browser-based tests needed — story deliverables are JSON config + BATS integration tests.

### Red Phase Requirements

All tests are scaffolded with `skip "RED PHASE — ..."`. Each skip message references the specific task from the story's task list so developers know which task activates each test.

---

## Step 4: Generated Tests (TDD RED PHASE)

### Test Files Generated / Present

| File | Tests | Coverage | Status |
|------|-------|----------|--------|
| `tests/integration/token-signing.bats` | 4 | AC1 (TS-231a, TS-231b), AC5 (TS-231c), AC6 (TS-231d) | RED (all skipped) |
| `tests/integration/jwks-discovery.bats` | 6 | AC2 (TS-232a, TS-232b), AC4 (TS-234a), AC6 (TS-236a), AC8 (TS-238a, TS-238b) | RED (all skipped) |
| `tests/integration/nonce-state.bats` | 2 | AC3 (TS-233a, TS-233b) | RED (all skipped) |

**Total test scaffolds:** 12 (all skipped — TDD red phase)

### Test Scenario Inventory

#### `tests/integration/token-signing.bats` (4 tests)

| ID | Priority | Description | AC | Task |
|----|----------|-------------|-----|------|
| TS-231a | P0 | ID token header `alg` field is RS256 | AC1, AC6 | Task 5.1 |
| TS-231b | P0 | ID token payload contains all required claims: sub email iss aud exp iat nonce | AC1 | Task 5.2 |
| TS-231c | P0 | ID token lifetime exp minus iat does not exceed 900 seconds | AC5 | Task 5.3 |
| TS-231d | P0 | Keycloak rejects alg:none JWT at userinfo endpoint with HTTP 401 | AC6 | Task 5.1/5.7 |

#### `tests/integration/jwks-discovery.bats` (6 tests)

| ID | Priority | Description | AC | Task |
|----|----------|-------------|-----|------|
| TS-232a | P0 | JWKS endpoint returns HTTP 200 with JSON containing at least one key with kid | AC2 | Task 5.4 |
| TS-232b | P0 | JWKS endpoint contains at least one key with kty=RSA and use=sig | AC2 | Task 5.4 |
| TS-234a | P1 | OIDC discovery document contains all required provider metadata fields | AC4 | Task 5.5 |
| TS-236a | P0 | alg:none JWT presented to userinfo endpoint is rejected with HTTP 401 | AC6 | Task 5.7 |
| TS-238a | P1 | JWKS endpoint Cache-Control header is present and non-empty through Nginx edge | AC8 | Task 5.6 |
| TS-238b | P1 | Discovery endpoint Cache-Control header is present and non-empty through Nginx edge | AC8 | Task 5.6 |

#### `tests/integration/nonce-state.bats` (2 tests)

| ID | Priority | Description | AC | Task |
|----|----------|-------------|-----|------|
| TS-233a | P1 | ID token contains nonce claim matching the value sent in the auth request | AC3 | Task 5.8 |
| TS-233b | P1 | Replaying an ID token with the same nonce is detected by client-side nonce validation | AC3 | Task 5.8 |

### TDD Red Phase Compliance

- [x] All 12 tests use `skip "RED PHASE — ..."` markers
- [x] All tests assert EXPECTED behavior (no placeholder assertions like `assert true`)
- [x] Skip messages reference specific story task numbers for developer activation guidance
- [x] Tests follow existing BATS project conventions (`bats_load_library`, `load '../helpers/common'`, `setup()` INTEGRATION guard)
- [x] No active tests that might accidentally pass before implementation

---

## Step 5: Validation & Completion

### Checklist Validation

- [x] Prerequisites satisfied (story AC present, BATS framework in use)
- [x] Test files created with correct BATS shebang and project conventions
- [x] Each AC covered by at least one test scenario
- [x] All tests in red-phase (`skip`) — none will pass before implementation
- [x] Story metadata and handoff paths captured in frontmatter
- [x] No orphaned temporary files

### AC Coverage Summary

| AC | Description | Covered | Tests | Notes |
|----|-------------|---------|-------|-------|
| AC1 | RS256-signed ID token with required claims | ✅ | TS-231a, TS-231b | P0 |
| AC2 | JWKS endpoint publishes RSA signing key with kid | ✅ | TS-232a, TS-232b | P0 |
| AC3 | state/nonce binding; nonce single-use | ✅ | TS-233a, TS-233b | P1; server-side only; client enforcement in Story 4.2 |
| AC4 | OIDC discovery document complete | ✅ | TS-234a | P1 |
| AC5 | Token lifetime exp - iat ≤ 900 s | ✅ | TS-231c | P0 |
| AC6 | alg:none rejected | ✅ | TS-231d, TS-236a | P0; tested at both token-signing and jwks-discovery level |
| AC7 | Key rotation config (active/passive overlap) | ✅ | Covered via realm-lint extension (AC9) + CI gate | Config inspection; realm-lint asserts key provider present |
| AC8 | JWKS/discovery Cache-Control preserved | ✅ | TS-238a, TS-238b | P1; regression guard from Story 1.3 |
| AC9 | realm-lint asserts RSA key provider | ✅ | Covered by lint script unit test (Story 1.5 pattern) | Script extension: exit 1 if components/KeyProvider absent |

### Key Risks & Assumptions

1. **ROPC test client required** (TS-231a–231d, TS-233a–233b): Tests in `token-signing.bats` and `nonce-state.bats` use Resource Owner Password Credentials grant. A test-only Keycloak client (`envocc-test-client`) with Direct Access Grants enabled must be registered in the realm. This client is NOT for production use.

2. **Test user required** (TS-231b, TS-233a–233b): A test user (`testuser@envocc.go.th`) with `email` attribute set must exist in the `envocc` realm before running integration tests. Create via Keycloak Admin REST API.

3. **Keycloak port 8080 not published** (by design from Story 1.3): Tests default to `KC_DIRECT_URL=http://localhost:8080`. In a sealed stack, use a compose override to publish port 8080 for testing, or set `KC_DIRECT_URL=https://localhost` to go through Nginx.

4. **Cache-Control headers (TS-238a, TS-238b)**: These tests use `NGINX_BASE_URL=https://localhost` (not direct Keycloak) because they validate Nginx edge behavior. The self-signed cert requires `curl -k`.

5. **AC3 scope boundary**: `nonce-state.bats` validates the server-side nonce embedding only. The exactly-once client-side enforcement (`openid-client` library) is Story 4.2 scope, not Story 2.3.

6. **alg:none coverage split**: `TS-231d` (in `token-signing.bats`) and `TS-236a` (in `jwks-discovery.bats`) both test alg:none rejection. This is intentional — `token-signing.bats` tests it alongside the token claims flow while `jwks-discovery.bats` treats it as a standalone security assertion.

### Next Recommended Workflow

After implementing story tasks:

1. **`dev-story`** — Implement the story (realm-export.json changes + lint script + integration tests activation)
2. **`automate`** — After all tests are green, run the automate workflow to promote scaffolds to production-ready tests

---

## How to Activate Tests (Task-by-Task TDD Activation)

For each task during implementation:

1. Identify which test(s) correspond to the task (see skip message in each test)
2. Remove the `skip "RED PHASE — ..."` line from the matching test
3. Run the test: `INTEGRATION=1 bats tests/integration/<file>.bats`
4. Verify the test **FAILS** (confirms red phase — task not yet implemented)
5. Implement the task until the test turns **GREEN**
6. Do NOT re-add `skip`
7. Commit with both the implementation change and the activated test

### Task-to-Test Activation Map

| Task | Test(s) to Activate | File |
|------|---------------------|------|
| Task 1: Add RSA key provider to realm-export.json | TS-231a, TS-232a, TS-232b, TS-236a | `token-signing.bats`, `jwks-discovery.bats` |
| Task 2: Add email-claims client scope | TS-231b, TS-233a, TS-233b | `token-signing.bats`, `nonce-state.bats` |
| Task 3: Confirm nonce/state enforcement | TS-233a, TS-233b | `nonce-state.bats` |
| Task 4: Extend lint-realm-export.py | Validate via `python3 scripts/lint-realm-export.py` CLI; no separate bats test needed |
| Task 5.1: Token alg + alg:none tests | TS-231a, TS-231d | `token-signing.bats` |
| Task 5.2: Required claims test | TS-231b | `token-signing.bats` |
| Task 5.3: Token lifetime test | TS-231c | `token-signing.bats` |
| Task 5.4: JWKS endpoint tests | TS-232a, TS-232b | `jwks-discovery.bats` |
| Task 5.5: Discovery document test | TS-234a | `jwks-discovery.bats` |
| Task 5.6: Cache-Control tests | TS-238a, TS-238b | `jwks-discovery.bats` |
| Task 5.7: alg:none at userinfo test | TS-236a | `jwks-discovery.bats` |
| Task 5.8: Nonce binding test | TS-233a, TS-233b | `nonce-state.bats` |
