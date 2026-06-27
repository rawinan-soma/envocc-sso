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
storyId: '2.4'
storyKey: 2-4-sso-session-lifetimes-rp-initiated-logout
storyFile: _bmad-output/implementation-artifacts/2-4-sso-session-lifetimes-rp-initiated-logout.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-2-4-sso-session-lifetimes-rp-initiated-logout.md
generatedTestFiles:
  - tests/unit/realm-session-config.bats
  - tests/integration/realm-import.bats
inputDocuments:
  - _bmad-output/implementation-artifacts/2-4-sso-session-lifetimes-rp-initiated-logout.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-2.md
  - _bmad/tea/config.yaml
  - tests/helpers/common.bash
  - tests/unit/secret-hygiene.bats
  - tests/integration/realm-import.bats
  - scripts/lint-realm-export.py
---

# ATDD Checklist: Story 2.4 — SSO Session, Lifetimes & RP-Initiated Logout

## TDD Red Phase (Current)

Red-phase test scaffolds generated.

- Unit Tests (`tests/unit/realm-session-config.bats`): 6 tests (all `skip "RED PHASE — ..."` annotated)
- Integration Tests (`tests/integration/realm-import.bats`): 6 new tests added (TS-241a–TS-241f); TS-201d extended with 2 new field checks
- **Total new tests:** 12 (6 unit + 6 integration)

## Stack & Generation Mode

- **Detected stack:** `backend` (infrastructure/Keycloak config — no browser UI, no API endpoints to implement)
- **Generation mode:** AI generation (no browser recording needed for config/lint/shell tests)
- **Test framework:** BATS (matches existing `tests/unit/*.bats` and `tests/integration/*.bats` patterns)
- **Execution mode:** Sequential

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | SSO single sign-on session (FR7) — authenticated user reaches second app without re-entering credentials | TS-241e (End Session endpoint reachability confirms SSO session infrastructure) | P1 |
| AC2 | Session lifetime and token ceiling enforcement (FR8, NFR2a) — accessTokenLifespan ≤ 900s | TS-241c | P1 |
| AC3 | Refresh token rotation and family revocation (FR9) — revokeRefreshToken=true, refreshTokenMaxReuse=0 | TS-241a, TS-241b; updated TS-201d | P0 |
| AC4 | Session identifier regenerated on every auth-state transition (FR45) | TS-241f (always-skip manual procedure) | P2 |
| AC5 | RP-initiated logout terminates session and honors validated redirect (FR10) | TS-241d (end_session_endpoint in .well-known), TS-241e (endpoint reachability) | P1 |
| AC6 | Realm lint validates session/lifetime values (AR8) | TS-240a through TS-240f | P0 |

## Test File Summary

### `tests/unit/realm-session-config.bats` (NEW)

Covers AC6 (realm lint value-validation for session/lifetime/rotation fields).

| Test ID | Priority | Description | Task |
|---------|----------|-------------|------|
| TS-240a | P0 | Lint passes when revokeRefreshToken=true, refreshTokenMaxReuse=0, accessTokenLifespan=300 (green path) | Task 2 (all subtasks) |
| TS-240b | P0 | Lint exits 1 when accessTokenLifespan exceeds 900s NFR2a ceiling | Task 2.3 |
| TS-240c | P0 | Lint exits 1 when revokeRefreshToken is false | Task 2.3 |
| TS-240d | P0 | Lint exits 1 when refreshTokenMaxReuse is 1 | Task 2.3 |
| TS-240e | P0 | Lint exits 1 when revokeRefreshToken is missing | Task 2.1 |
| TS-240f | P0 | Lint exits 1 when refreshTokenMaxReuse is missing | Task 2.2 |

### `tests/integration/realm-import.bats` (MODIFIED — additions only)

New tests added for Story 2.4 (Tasks 4.1 and 5.2). Existing tests TS-201a–TS-201g preserved unchanged except TS-201d (Task 4.2 extension).

**TS-201d update (Task 4.2):** Added `revokeRefreshToken=True` and `refreshTokenMaxReuse=0` to the baseline assertion checklist. These checks will fail until Task 1 updates `keycloak/realm-export.json`.

| Test ID | Priority | Description | Task |
|---------|----------|-------------|------|
| TS-241a | P0 | Admin REST API confirms revokeRefreshToken=true in live realm (AC3) | Task 1.1 |
| TS-241b | P0 | Admin REST API confirms refreshTokenMaxReuse=0 in live realm (AC3) | Task 1.2 |
| TS-241c | P1 | Admin REST API confirms accessTokenLifespan ≤ 900s in live realm (AC2/NFR2a) | Task 1.3 (verify) |
| TS-241d | P1 | OIDC discovery .well-known includes end_session_endpoint (AC5/FR10) | Task 5.1 (verify) |
| TS-241e | P1 | End Session endpoint returns 200 or 302 on bare GET (AC5/FR10) | Task 5.1 (verify) |
| TS-241f | P2 | Manual: AUTH_SESSION_ID cookie changes after each auth-state transition (AC4/FR45) | Task 5.2 (always skip) |

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Identify which test(s) correspond to the task you are implementing (see "Task" column above).
2. Remove the `skip "RED PHASE — ..."` annotation from those tests.
3. Run the activated tests:
   - Unit: `BATS_LIB_PATH=$(pwd)/tests/lib bats tests/unit/realm-session-config.bats`
   - Integration: `INTEGRATION=1 BATS_LIB_PATH=$(pwd)/tests/lib bats tests/integration/realm-import.bats`
4. Verify the activated test **FAILS** first (confirming the red phase).
5. Implement the task until the test passes (green phase).
6. Commit passing tests with the implementation.

### Recommended Activation Order

- **Task 1.1** (`revokeRefreshToken: true` in realm-export.json): Activate TS-241a; update TS-201d (already modified — no skip needed)
- **Task 1.2** (`refreshTokenMaxReuse: 0` in realm-export.json): Activate TS-241b
- **Task 1.3** (verify accessTokenLifespan ≤ 900): Activate TS-241c
- **Task 2.1** (add `revokeRefreshToken` to REQUIRED_FIELDS): Activate TS-240e
- **Task 2.2** (add `refreshTokenMaxReuse` to REQUIRED_FIELDS): Activate TS-240f
- **Task 2.3** (add value-validation block): Activate TS-240a, TS-240b, TS-240c, TS-240d
- **Task 4.1** (integration test additions): Already active via INTEGRATION=1 guard — TS-241a through TS-241f run when stack is live
- **Task 5.1** (verify Keycloak 26.x RP-logout infrastructure): Activate TS-241d, TS-241e
- **Task 5.2** (FR45 manual verification): TS-241f always-skips — read its comment for manual steps

## Implementation Guidance

### Files to create:
- `tests/unit/realm-session-config.bats` — already created by this ATDD scaffold

### Files to modify:
- `keycloak/realm-export.json` — add `"revokeRefreshToken": true, "refreshTokenMaxReuse": 0` (Task 1)
- `scripts/lint-realm-export.py` — add `revokeRefreshToken` and `refreshTokenMaxReuse` to `REQUIRED_FIELDS`; add value-validation block (Task 2)
- `tests/integration/realm-import.bats` — already extended by this ATDD scaffold (TS-241a–TS-241f added; TS-201d extended)
- `keycloak/REALM-EXPORT-NOTES.md` — add Story 2.4 section (Tasks 1.4, 5.3, 6.1–6.2)

### Files NOT touched in this story:
- `compose.yaml`, `keycloak/Dockerfile`, `nginx/`, `postgres/` — no changes
- `.github/workflows/ci.yml` — realm-lint CI job from Story 1.5 already covers `scripts/lint-realm-export.py`
- `lefthook.yml` — pre-commit hook from Story 1.5 already runs realm-lint

### Key constraints:
- `revokeRefreshToken` and `refreshTokenMaxReuse` fields go immediately after `accessTokenLifespan` in realm-export.json
- Lint value validation: use `is not True` (not `!= True`) for `revokeRefreshToken` to correctly reject null, 0, and absent values
- `accessTokenLifespan` validation: use `isinstance(atl, int)` guard before comparison to avoid crash on non-integer values
- Fixture cleanup pattern: always `rm -f "${fixture}"` AFTER `assert_success`/`assert_failure` so the file is available for diagnosis on failure

## Key Risks and Assumptions

- **R-001 (INFRA):** AC1 (SSO single sign-on across apps) cannot be fully tested until a second OIDC client is registered (Stories 2.2 and 5.3). TS-241e partially covers the SSO infrastructure by confirming the End Session endpoint (the logout side) is reachable.
- **R-002 (BATS):** Unit tests TS-240b through TS-240d will produce misleading output if run before Task 2.3 — the lint exits 0 so `assert_failure` fails without a helpful message. The `skip "RED PHASE"` annotation prevents this during normal `bats` runs.
- **R-003 (INTEGRATION):** TS-241a and TS-241b will fail when `INTEGRATION=1` is set but Task 1 has not been implemented. This is the expected red-phase behavior.
- **R-004 (KEYCLOAK):** TS-241d and TS-241e test Keycloak 26.x built-in behavior. If the stack runs a different Keycloak version, these may fail for reasons unrelated to realm config.

## ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-2-4-sso-session-lifetimes-rp-initiated-logout.md`
- Unit tests: `tests/unit/realm-session-config.bats`
- Integration tests: `tests/integration/realm-import.bats` (extended)
- Story file: `_bmad-output/implementation-artifacts/2-4-sso-session-lifetimes-rp-initiated-logout.md`
