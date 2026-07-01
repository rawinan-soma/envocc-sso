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
storyId: '2.9'
storyKey: 2-9-login-with-thaid-brokered-federation-account-linking
storyFile: _bmad-output/implementation-artifacts/2-9-login-with-thaid-brokered-federation-account-linking.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-2-9-login-with-thaid-brokered-federation-account-linking.md
generatedTestFiles:
  - tests/integration/thaid-broker.bats
inputDocuments:
  - _bmad-output/implementation-artifacts/2-9-login-with-thaid-brokered-federation-account-linking.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-2.md
  - _bmad/tea/config.yaml
  - keycloak/realm-export.json
  - keycloak/IDENTITY-MODEL.md
  - tests/helpers/common.bash
  - tests/integration/oidc-pkce-flow.bats
  - tests/integration/identity-model.bats
---

# ATDD Checklist: Story 2.9 — Login with ThaiD (Brokered Federation & Account Linking)

## TDD Red Phase (Current)

This repo does not use `test.skip()`-style scaffolding for the Keycloak
config-as-code + BATS integration stack (same convention as stories 1.1-2.8).
The established convention is a **guarded-execution red phase**:

- BATS integration tests (`tests/integration/thaid-broker.bats`) are gated by
  `INTEGRATION=1` and skip cleanly without a live stack (verified: 7 skipped,
  0 failed, no stack running). They will FAIL for real, meaningful reasons
  once run against a live stack at this story's baseline:
  - TS-290a fails: no `mock-oidc-provider` service exists in `compose.yaml`
    yet (Task 0) — the discovery curl cannot connect.
  - TS-290b/c/d/e/f/h all fail: `keycloak/realm-export.json` has no
    `identityProviders` entry yet (Task 1), so `kc_idp_hint=thaid` is
    rejected by Keycloak before any broker flow can begin.
- All tests assert EXPECTED post-implementation behavior (specific HTTP
  statuses, specific `sub`-claim equality, specific zero-phantom-account
  search results) — no placeholder assertions.

**Total new test assertions: 7** (all in `tests/integration/thaid-broker.bats`, `INTEGRATION=1`-gated)

### Test Files

**BATS integration tests (live Keycloak + mock-oidc-provider stack required):**

`tests/integration/thaid-broker.bats`

Run command:
```bash
docker compose down -v && docker compose up --build -d
INTEGRATION=1 BATS_LIB_PATH=$(pwd)/tests/lib bats tests/integration/thaid-broker.bats
```

---

## Stack Detection

- **Detected stack:** backend / infrastructure (Keycloak + Nginx + Docker Compose — identical footprint class to stories 1.1-2.8; no frontend package manifest)
- **Generation mode:** AI generation (acceptance criteria are clear; live-Keycloak Admin-REST + OIDC-broker-flow checks; no browser recording required)
- **Test framework:** BATS (`INTEGRATION=1`-gated live-stack integration)
- **Execution mode:** Sequential (TS-290h deliberately runs last — see Dev Notes below)

---

## Step 1: Preflight Summary

| Config Key | Value |
|---|---|
| story_key | `2-9-login-with-thaid-brokered-federation-account-linking` |
| story_id | `2.9` |
| story_file | `_bmad-output/implementation-artifacts/2-9-login-with-thaid-brokered-federation-account-linking.md` |
| test_artifacts | `_bmad-output/test-artifacts` |
| test_framework | auto → BATS (integration only — no unit/lint changes needed per story Task 4.3) |

---

## Step 2: Generation Mode

**Selected mode:** AI generation

The story is a Keycloak `identityProviders` broker config (Task 1) + a
deny-only `thaid-first-broker-login` custom flow (Task 2) fronted by a mock
OIDC IdP container (Task 0). All Task 5 acceptance criteria are verifiable via
live Admin-REST calls and a multi-hop OIDC authorization-code redirect chain
against a running Keycloak + mock-oidc-provider stack — no browser recording
needed (curl + cookie jar, same technique as `oidc-pkce-flow.bats`).

---

## Step 3: Test Strategy

### Acceptance Criteria → Test Mapping

| AC | Description | Test Count | Priority | Level |
|---|---|---|---|---|
| AC2/AC5 | `thaid` OIDC IdP configured against a mock IdP in dev/CI | 1 | P0 | Integration (curl discovery smoke) |
| AC3 | Broker login resolves ONLY to a pre-registered PID link; no auto-create/auto-link | 4 | P0/P1/P2 | Integration (curl broker-flow + Admin REST) |
| AC4 | Disabled account cannot authenticate via ThaiD | 1 | P0 | Integration (curl broker-flow) |
| (resilience) | Mock IdP unreachable produces a clean broker error | 1 | P2 | Integration (curl broker-flow + docker compose) |
| **Total** | | **7** | | |

### Test Level Rationale

Per Dev Notes and `test-design-epic-2.md#R-007`, this story is exclusively
integration-level: there is no new `scripts/lint-realm-export.py` check
(Task 4.3 explicitly rules this out — the pre-existing generic secret scan
already covers `identityProviders[].config.clientSecret`), and no new theme
test (Task 3 only activates an already-tested `socialProviders` block from
Story 2.5). All new coverage lands in one file, `tests/integration/thaid-broker.bats`,
mirroring `tests/integration/account-disable.bats`'s (Story 2.8) per-test
isolated-fixture convention and `tests/integration/oidc-pkce-flow.bats`'s
(Story 2.2) cookie-jar multi-hop redirect-chain technique, extended by one
additional hop through the mock IdP.

Deliberately **not** duplicated here (already covered elsewhere or explicitly
out of scope per Dev Notes):
- The zeroed `identityProviders[].config.clientSecret` secret-hygiene check —
  already proven generically by `tests/unit/ci-security-gate.bats` (TS-151o)
  and `tests/unit/secret-hygiene.bats` (TS-104-realm-d), both path-agnostic
  (story Task 4.2).
- TS-290g (bonus reverse-direction case: one PID linked to two accounts) —
  explicitly optional ("if time permits") per story Task 5.7; not implemented
  in this red-phase pass.

### Red Phase Requirements

- The single BATS integration file is `INTEGRATION=1`-gated (this repo's
  established red-phase convention — see `oidc-pkce-flow.bats`/`account-disable.bats`
  precedent); it skips cleanly without a stack and is expected to FAIL once
  run against a live, unmodified realm (no `thaid` IdP configured yet).
- All tests assert EXPECTED behavior (specific HTTP status codes, `sub`-claim
  equality, zero-result phantom-account searches, single-remaining-PID
  federated-identity-link state) — no placeholder assertions.

---

## Step 4: Generated Test Infrastructure

### Integration Tests (BATS, live Keycloak + mock-oidc-provider)

**File:** `tests/integration/thaid-broker.bats`

Test scenarios (TS-290 series, Task 5 subtasks 5.2-5.8):
1. `[P0][TS-290a]` Mock OIDC IdP responds to discovery (precondition smoke) (AC2/AC5)
2. `[P0][TS-290b]` First ThaiD login links to the pre-created account by PID; `sub` matches (AC3)
3. `[P1][TS-290c]` Second ThaiD login by the same PID reuses the same identity, no re-link prompt (AC3)
4. `[P0][TS-290d]` Unrecognized PID does not create a phantom account (AC3) — the single most important test in this story
5. `[P0][TS-290e]` Disabled account cannot authenticate via ThaiD (AC4)
6. `[P2][TS-290f]` Account already linked to one ThaiD PID rejects a second, conflicting link attempt
7. `[P2][TS-290h]` Mock IdP unreachable produces a clean broker error, not a raw 5xx (resilience; runs LAST and restores the container before the test ends)

Includes a shared `drive_thaid_broker_login()` helper (multi-hop cookie-jar
curl chain: Keycloak `kc_idp_hint=thaid` → mock IdP login/consent form →
Keycloak broker callback → RP redirect with `?code=` → token exchange → JWT
`sub` claim decode) plus `_create_active_thaid_user()` / `_register_pid_link()`
fixture helpers, following the exact per-test-ID teardown pattern established
by `tests/integration/account-disable.bats` (Story 2.8).

**Total: 7 tests — confirmed 0 passed / 0 failed / 7 skipped without `INTEGRATION=1`**
(verified: `BATS_LIB_PATH=<scratch>/bats-lib bats tests/integration/thaid-broker.bats`
→ `1..7`, all `ok ... # skip`, no stack required).

**IMPORTANT (see file header RED PHASE note):** `drive_thaid_broker_login()`'s
mock-IdP-hop field names (`username`/`subject`/`claims`) are a best-effort
scaffold written from `ghcr.io/navikt/mock-oauth2-server`'s documented
behavior, NOT a confirmed hands-on trace against a running container (Task 0
does not exist yet in this environment). Story Task 5.3 explicitly calls this
out: **re-verify each hop's real request/response shape empirically once
Task 0 lands, and adjust the helper if the chosen image's actual behavior
differs.** This is expected and acceptable for a red-phase scaffold — the
test *structure*, fixture/teardown pattern, and assertions are the durable
contract; the exact mock-IdP hop mechanics are provisional by design.

---

## Step 5: Validation

- [x] Prerequisites satisfied (story has clear, unambiguous acceptance criteria; PID-linking design intent documented in Dev Notes)
- [x] Test file created: `tests/integration/thaid-broker.bats`
- [x] All tests assert expected behavior (specific HTTP status codes / `sub`-claim equality / zero-result searches, not placeholders)
- [x] AC2, AC3, AC4, AC5 all have test coverage
- [x] `tests/integration/thaid-broker.bats` run verified: `bats --count` → 7; run without `INTEGRATION=1` → 7 skipped, 0 failed (correct — matches repo convention; no Docker stack brought up in this ATDD pass, see Risks below)
- [x] No orphaned temp artifacts (scratch `bats-support`/`bats-assert` clone used only for local `--count`/skip-mode verification, outside the repo tree)

---

## Activation / Verification Guide (Task-by-Task)

During implementation of each task, re-run the corresponding tests and confirm red → green:

**Task 0 (mock-oidc-provider service + healthcheck):**
```
Re-run: INTEGRATION=1 bats tests/integration/thaid-broker.bats -f TS-290a
        TS-290a should flip from a connection-refused FAIL to PASS.
```

**Task 1 (`thaid` identityProviders config):**
```
Re-run: INTEGRATION=1 bats tests/integration/thaid-broker.bats
        TS-290b/c/d/e/f/h should stop failing on "no thaid IdP configured" and
        start exercising real broker-flow behavior (may still fail on Task 2
        until the deny-only flow lands — see below).
Also confirm (Task 4 regression gate): tests/unit/ci-security-gate.bats and
        tests/unit/secret-hygiene.bats still pass against the zeroed
        identityProviders[].config.clientSecret.
```

**Task 2 (deny-only `thaid-first-broker-login` flow):**
```
Re-run: INTEGRATION=1 bats tests/integration/thaid-broker.bats -f TS-290d
        This is the flow's direct proof — must pass before this story is
        considered functionally complete, per Dev Notes.
Re-run: -f TS-290b and -f TS-290c to confirm pre-registered links still
        resolve correctly once the deny-only flow is in place (it must only
        reject TRUE first-broker-logins with no existing link, not every login).
```

**Task 3 (login theme — activate the ThaiD button):**
```
No new automated test — Task 3 is a manual/visual verification step per the
story (AC1, activating an already-tested Story 2.5 socialProviders block).
```

**Task 5 (full integration suite + AC4/resilience):**
```
Re-run full file: INTEGRATION=1 BATS_LIB_PATH=$(pwd)/tests/lib bats tests/integration/thaid-broker.bats
All 7 tests green before marking review-ready. Confirm TS-290h leaves
mock-oidc-provider healthy afterward (wait_for_healthy check inside the test).
```

**Task 7 (agentic-build gate):**
```
Run: python3 scripts/lint-realm-export.py
Run: gitleaks protect --staged --redact
Run: semgrep scan --config auto --error
Run: bats tests/integration/thaid-broker.bats with INTEGRATION=1 against a rebuilt stack
```

---

## Risks & Assumptions

| Risk | Mitigation |
|---|---|
| No live Docker/Keycloak stack was brought up in this ATDD pass (host ports 8080/443 were already bound by a concurrent sibling story's stack in this shared-host BAD pipeline run) | `tests/integration/thaid-broker.bats` verified to gather (7 tests) and skip cleanly (7/7 skipped, 0 failed) via `bats --count` / a plain `bats` run with `INTEGRATION` unset; full red/green verification against a live stack is deferred to dev-story implementation, consistent with this repo's `INTEGRATION=1` convention used by every prior integration suite |
| `bats-support`/`bats-assert` not preinstalled locally | Verified locally via a scratch clone outside the repo tree; CI/dev environment is expected to provide `tests/lib` per existing suite conventions (same as every other `tests/integration/*.bats` file) |
| `mock-oidc-provider`'s exact login-form field names / redirect shape are unknown until Task 0 exists | `drive_thaid_broker_login()` is written as a best-effort scaffold from `ghcr.io/navikt/mock-oauth2-server`'s documented behavior and explicitly flagged (in both the test file header and this checklist) as needing hands-on re-verification per story Task 5.3 — this is a named, accepted limitation of a red-phase scaffold for a not-yet-existing dependency, not a defect |
| TS-290h stops/restarts a live Docker container as part of its test body | The test unconditionally attempts to restart `mock-oidc-provider` and wait for healthy in a cleanup step that runs regardless of the assertion outcome (`||` guards around both the stop and restart `docker compose` calls), so a failed assertion cannot leave the container down for later tests |

---

## Next Steps

1. **dev-story** — implement story 2.9 following the task list in the story file (Tasks 0-7)
2. Re-run `INTEGRATION=1 bats tests/integration/thaid-broker.bats -f TS-290a` after Task 0 — verify red → green
3. Re-run the full file after Task 1 — confirm TS-290b/c/d/e/f/h move past the "no thaid IdP" failure mode
4. Re-run `-f TS-290d` after Task 2 — this is the story's most important assertion; must be green
5. Re-verify `drive_thaid_broker_login()`'s mock-IdP hop against the real running container (Task 5.3) and adjust field names/parsing if needed
6. Run the full suite green before marking review-ready
7. Run `lefthook run pre-commit` (or equivalent) before marking review-ready

---

## Handoff Path

- Story file: `_bmad-output/implementation-artifacts/2-9-login-with-thaid-brokered-federation-account-linking.md`
- Test files:
  - `tests/integration/thaid-broker.bats` (BATS, `INTEGRATION=1`-gated — 7 tests, confirmed skip-clean)
- Checklist: `_bmad-output/test-artifacts/atdd-checklist-2-9-login-with-thaid-brokered-federation-account-linking.md`
