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
storyId: '2.1'
storyKey: 2-1-canonical-identity-model-lifecycle-states
storyFile: _bmad-output/implementation-artifacts/2-1-canonical-identity-model-lifecycle-states.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-2-1-canonical-identity-model-lifecycle-states.md
generatedTestFiles:
  - tests/integration/identity-model.bats
inputDocuments:
  - _bmad-output/implementation-artifacts/2-1-canonical-identity-model-lifecycle-states.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-2.md
  - _bmad/tea/config.yaml
  - tests/helpers/common.bash
  - tests/integration/realm-import.bats
---

# ATDD Checklist: Story 2.1 — Canonical Identity Model & Lifecycle States

## TDD Red Phase (Current)

Red-phase test scaffolds generated.

- Integration Tests (`tests/integration/identity-model.bats`): 5 tests (all skipped — RED PHASE)
- **Total:** 5 tests, all with `skip "RED PHASE — ..."` annotation

## Stack & Generation Mode

- **Detected stack:** `backend` (infrastructure/Keycloak config — no browser UI, no package.json)
- **Generation mode:** AI generation (no browser recording needed for Admin REST API tests)
- **Test framework:** BATS (matches existing `tests/integration/*.bats` patterns)
- **Execution mode:** Sequential

## Acceptance Criteria Coverage

| AC | Description | Test(s) | Priority |
|----|-------------|---------|----------|
| AC1 | Stable subject (UUID `sub`, never reused) | TS-210a | P2 |
| AC1 | Work-email as unique reconciliation key; realm rejects duplicate emails | TS-210b | P2 |
| AC2 | Minimal attribute set — no PDPA §26 sensitive fields present on user record | TS-210c, TS-210e | P2 |
| AC3 | Lifecycle: pending state blocks authentication | TS-210d | P2 |

## Test File Summary

### `tests/integration/identity-model.bats`

All 5 tests follow the existing BATS pattern from `tests/integration/realm-import.bats` exactly:
- `bats_load_library 'bats-support'` + `bats_load_library 'bats-assert'`
- `load '../helpers/common'` (provides `get_admin_token`, `_env_value`, `PROJECT_ROOT`)
- `setup()` with INTEGRATION guard and per-test variable reset
- `teardown()` that DELETEs any user UUIDs stored in `_TS210*_USER_ID` variables

| Test ID | Priority | Description | AC | Task |
|---------|----------|-------------|----|------|
| TS-210a | P2 | Stable sub — same UUID across GET calls; UUID not recycled after deletion | AC1 | Task 3.2 |
| TS-210b | P2 | Email uniqueness — duplicate email POST returns HTTP 409 | AC1 | Task 3.3 |
| TS-210c | P2 | Data minimization — no PDPA §26 sensitive fields in user attributes | AC2 | Task 3.4 |
| TS-210d | P2 | Pending state blocks login — ROPC token endpoint returns HTTP 400 | AC3 | Task 3.5 |
| TS-210e | P2 | Clean-creation invariant — freshly created user has no PDPA §26 attributes | AC2 | Task 3.6 |

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Identify which test(s) correspond to the task you are implementing (see "Task" column above).
2. Remove the `skip "RED PHASE — ..."` line from those tests.
3. Run the activated tests: `INTEGRATION=1 bats tests/integration/identity-model.bats`
4. Verify the activated test **fails** first (confirming the red phase, i.e., the feature is not yet implemented).
5. Implement the task until the test passes (green phase).
6. Commit the passing tests together with the implementation.

### Recommended Activation Order

- **Task 1 (User Profile Config + test-ropc-client):** No test activation needed — Task 1 sets up the realm config prerequisite that all tests depend on. Verify via Admin UI.
- **Task 2 (IDENTITY-MODEL.md):** No test activation — documentation task. Verify manually.
- **Task 3.2 (TS-210a):** Activate after realm user-profile config is applied (Task 1.3/1.4).
- **Task 3.3 (TS-210b):** Activate after `duplicateEmailsAllowed:false` verified in realm-lint update (Task 1.8).
- **Task 3.4 (TS-210c):** Activate after Declarative User Profile config applied (Task 1.3/1.4).
- **Task 3.5 (TS-210d):** Activate after `test-ropc-client` added to realm (Task 1.5) and `KC_TEST_ROPC_CLIENT_SECRET` in `.env` (Task 1.6).
- **Task 3.6 (TS-210e):** Activate after Declarative User Profile config applied (Task 1.3/1.4). May activate together with TS-210c.
- **Task 4 (agentic build gate):** Run `INTEGRATION=1 bats tests/integration/identity-model.bats` with all 5 tests activated. Confirm all pass.

## Implementation Prerequisites

The following must be in place before any test can run green:

1. **Live stack:** `docker compose up --build` with Keycloak healthy
2. **Realm config (Task 1):**
   - Declarative User Profile: allowed attributes = `username`, `email`, `firstName`, `lastName` only
   - `duplicateEmailsAllowed: false` (already set; lint check added by Task 1.8)
   - `registrationAllowed: false` (already set; lint check added by Task 1.8)
   - `test-ropc-client` added with `directAccessGrantsEnabled: true` (Task 1.5)
3. **Environment variables:**
   - `KC_BOOTSTRAP_ADMIN_USERNAME` and `KC_BOOTSTRAP_ADMIN_PASSWORD` in `.env` (used by `get_admin_token`)
   - `KC_TEST_ROPC_CLIENT_SECRET=change-me-test-secret` in `.env` (Task 1.6)
4. **BATS libraries:** `BATS_LIB_PATH=$(pwd)/tests/lib` pointing to bats-support and bats-assert

## Key Design Decisions

### TS-210a: UUID not-recycled assertion
- After deletion, re-create with the SAME EMAIL but different `username` to avoid username uniqueness collision.
- The new user must have a different `id` UUID — confirms Keycloak's non-recycling invariant (FR21).

### TS-210d: ROPC requires test-ropc-client
- ROPC (`grant_type=password`) is disabled on standard clients (PKCE-only story 2.2).
- A dedicated `test-ropc-client` with `directAccessGrantsEnabled: true` is the only way to programmatically verify the pending-state block without a full browser session.
- This client must NOT be deployed in production (see `keycloak/REALM-EXPORT-NOTES.md`).

### TS-210c vs TS-210e: complementary data minimization tests
- **TS-210c** verifies the user's `attributes` map after clean creation with allowed fields.
- **TS-210e** is identical in behavior but named separately to make it explicit that "clean creation invariant" is a distinct FR23 requirement: the default profile config must not inject sensitive fields.
- Both can be activated together (same prerequisite: Task 1.3/1.4).

### Admin REST bypass caveat (IDENTITY-MODEL.md note)
- In KC 26, the Admin REST API CAN set arbitrary attributes even when the user-profile config blocks them for self-service users. The tests validate the clean-creation invariant (standard creation flow) — not a technical enforcement block. This distinction is documented per story Dev Notes.

## Key Risks and Assumptions

- **test-ropc-client secret in `.env`:** TS-210d reads `KC_TEST_ROPC_CLIENT_SECRET` via `_env_value`. The `.env.example` value `change-me-test-secret` must match the zeroed-then-manually-set secret in the realm export. Document in `keycloak/REALM-EXPORT-NOTES.md`.
- **Email re-use after deletion (TS-210a):** Keycloak allows the same email on a new user after the original is deleted (email uniqueness is enforced at DB level per user, not globally reserved). The test relies on this behavior being consistent in KC 26.
- **`VERIFY_EMAIL` required action behavior (TS-210d):** Keycloak returns HTTP 400 with `{"error":"invalid_grant","error_description":"Account is not fully set up"}` for ROPC attempts on a user with pending VERIFY_EMAIL. This behavior is stable across KC 25–26.x. If behavior changes, update the expected HTTP status code.
- **teardown robustness:** Each test stores its created user UUID in a test-prefixed global variable immediately after creation. `teardown()` iterates all five variables and deletes any non-empty UUIDs. This ensures cleanup even when assertions fail mid-test.

## ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-2-1-canonical-identity-model-lifecycle-states.md`
- Integration tests: `tests/integration/identity-model.bats`
- Story file: `_bmad-output/implementation-artifacts/2-1-canonical-identity-model-lifecycle-states.md`
- Test design: `_bmad-output/test-artifacts/test-design/test-design-epic-2.md` (P2 story 2.1 scenarios)
