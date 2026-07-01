---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-07-01'
storyId: '2.8'
storyKey: 2-8-disable-blocks-authentication-revokes-sessions
storyFile: _bmad-output/implementation-artifacts/2-8-disable-blocks-authentication-revokes-sessions.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-2-8-disable-blocks-authentication-revokes-sessions.md
generatedTestFiles:
  - tests/integration/account-disable.bats
inputDocuments:
  - _bmad-output/implementation-artifacts/2-8-disable-blocks-authentication-revokes-sessions.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-2.md
  - _bmad/tea/config.yaml
  - tests/helpers/common.bash
  - tests/integration/identity-model.bats
  - tests/integration/realm-import.bats
  - keycloak/realm-export.json
  - keycloak/IDENTITY-MODEL.md
  - .env.example
---

# ATDD Checklist: Story 2.8 — Disable Blocks Authentication & Revokes Sessions

## TDD Red Phase (Current)

Red-phase integration test scaffold generated as a new file.

- Integration Tests (`tests/integration/account-disable.bats`): 8 tests (TS-280a–TS-280h)
- **Total new tests:** 8

All 8 tests are written as real assertions (no `skip "RED PHASE — ..."` annotations) because
AC1/AC2 exercise built-in Keycloak behavior — the same "verify + document" story shape as
Story 2.4. The RED state comes from a missing test fixture, not missing production config:
`test-ropc-client` is not yet present in `keycloak/realm-export.json` (Story 2.8 Task 0 —
confirmed absent at this story's baseline despite Story 2.1 claiming to have added it). Every
test that performs an ROPC login (TS-280a, TS-280b, TS-280d, TS-280e, TS-280f, TS-280g) will
fail red with "test-ropc-client not found in realm" until Task 0 re-adds the client. TS-280c
(structural proof) and TS-280h (`/logout` idempotency on a never-authenticated user) do not
require ROPC and can pass independently of Task 0.

## Stack & Generation Mode

- **Detected stack:** `backend` (Keycloak Admin REST API verification — no browser UI, no new API endpoints implemented)
- **Generation mode:** AI generation (shell/BATS tests against Admin REST API; no browser recording needed)
- **Test framework:** BATS (matches existing `tests/integration/*.bats` patterns)
- **Execution mode:** Sequential

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | Disabled account cannot authenticate at any client (FR25) | TS-280a (control), TS-280b, TS-280c, TS-280d | P0/P1 |
| AC2 | Disabling revokes all outstanding refresh-token families and invalidates all server-side sessions (FR46) | TS-280e, TS-280f, TS-280g, TS-280h | P0/P1 |

## Test File Summary

### `tests/integration/account-disable.bats` (NEW)

| Test ID | Priority | Description | Task |
|---------|----------|--------------|------|
| TS-280a | P0 | Active user can authenticate via ROPC (control/baseline) | Task 3.2 |
| TS-280b | P0 | Disabled account cannot obtain a new token via ROPC/password grant; asserts specific `invalid_grant` error content, not just non-200 | Task 3.3 |
| TS-280c | P1 | Structural proof: `enabled:false` is a user-level field with no per-client scoping (no second ROPC client added — see story Dev Notes) | Task 3.4 |
| TS-280d | P1 | Re-enabling (`PUT {"enabled":true}`) restores authentication | Task 3.5 |
| TS-280e | P0 | A previously-issued refresh token stops working after disable + `/logout` | Task 4.1 |
| TS-280f | P0 | `GET /users/{id}/sessions` reports zero active sessions after disable + `/logout` | Task 4.2 |
| TS-280g | P1 | `enabled:false` alone (without `/logout`) does NOT retroactively kill an existing session — proves the two-call procedure is mandatory | Task 4.3 |
| TS-280h | P1 | `POST /users/{id}/logout` is idempotent and safe on a user with zero sessions | Task 4.4 |

## Blocking Prerequisite (Story 2.8 Task 0 — NOT part of this ATDD scaffold)

`test-ropc-client` is missing from `keycloak/realm-export.json` at this story's baseline
(confirmed by direct inspection: `clients` array contains only `test-oidc-client`). Per the
story's explicit scope split, Task 0 (re-adding the client fixture), Task 1 (auth-blocking
documentation), and Task 2 (two-call disable procedure documentation) are **dev-story
implementation work**, not ATDD scaffold work — this checklist and the generated test file
cover Tasks 3 and 4 only (the test suite itself). The dev-story agent must complete Task 0
before any ROPC-dependent test in this file can go green.

## Local Verification Status

Docker/OrbStack was not running in this environment, so the live-stack integration run
(story Task 5.4: `INTEGRATION=1 bats tests/integration/account-disable.bats` against
`docker compose up --build`) was **not** executed here. Verified instead, in this environment:

- `bats --version` → 1.13.0; `BATS_LIB_PATH=/private/tmp bats tests/integration/account-disable.bats`
  (bats-support/bats-assert available locally at `/private/tmp/bats-support`,
  `/private/tmp/bats-assert`) → all 8 tests parse and correctly `skip` without `INTEGRATION=1`
  (confirms BATS syntax validity and the `setup()` skip-guard).
- `shellcheck -x tests/integration/account-disable.bats` → no findings.
- `gitleaks detect --source tests/integration/account-disable.bats --no-git --config .gitleaks.toml --redact` → no leaks found.

The dev-story agent (or a human) MUST run Task 5.4 against a live stack after completing
Task 0, to confirm the red→green transition for the 6 ROPC-dependent tests.

## Next Steps (Task-by-Task Activation)

1. Implement Story 2.8 Task 0 (re-add `test-ropc-client` to `keycloak/realm-export.json`) — this unblocks TS-280a, TS-280b, TS-280d, TS-280e, TS-280f, TS-280g.
2. Run `INTEGRATION=1 BATS_LIB_PATH=$(pwd)/tests/lib bats tests/integration/account-disable.bats` against a freshly rebuilt stack (`docker compose down -v && docker compose up --build`) — confirm TS-280c and TS-280h pass immediately (no Task 0 dependency), and the remaining 6 tests transition red → green once Task 0 lands.
3. Implement Story 2.8 Task 1 (auth-blocking documentation in `keycloak/REALM-EXPORT-NOTES.md` / `keycloak/IDENTITY-MODEL.md`) and Task 2 (two-call disable procedure documentation) — these are documentation-only tasks with no direct test dependency, but complete them alongside Task 0 per the story's task ordering.
4. Re-run the full suite; all 8 tests must pass (green phase) before Task 5 (agentic-build gate: `lint-realm-export.py`, `gitleaks protect --staged`, `semgrep scan`).
5. Commit passing tests with the implementation, following the story's commit convention (`feat(story-2-8): ...`).
