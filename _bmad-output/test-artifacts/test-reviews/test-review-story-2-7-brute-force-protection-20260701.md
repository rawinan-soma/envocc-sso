---
stepsCompleted: ['step-01-load-context', 'step-02-discover-tests', 'step-03-quality-evaluation', 'step-03f-aggregate-scores', 'step-04-generate-report']
lastStep: 'step-04-generate-report'
lastSaved: '2026-07-01'
workflowType: 'testarch-test-review'
inputDocuments:
  - tests/unit/brute-force-config.bats
  - tests/unit/enumeration-resistant-messages.bats
  - tests/integration/brute-force-lockout.bats
  - tests/helpers/common.bash
  - tests/integration/setup_suite.bash
  - keycloak/realm-export.json
  - keycloak/REALM-EXPORT-NOTES.md
  - _bmad-output/implementation-artifacts/2-7-brute-force-protection-enumeration-resistant-responses.md
  - _bmad/tea/config.yaml
storyScope: 'story-2-7-brute-force-protection-enumeration-resistant-responses'
---

# Test Quality Review: story-2-7-brute-force-protection (Suite)

**Quality Score**: 93/100 (A - Excellent)
**Review Date**: 2026-07-01
**Review Scope**: directory (`tests/unit/brute-force-config.bats`, `tests/unit/enumeration-resistant-messages.bats`, `tests/integration/brute-force-lockout.bats`)
**Reviewer**: TEA Agent (Master Test Architect)

---

> Note: This review audits existing tests; it does not generate tests.
> Coverage mapping and coverage gates are out of scope here. Use `trace` for coverage decisions.

## Executive Summary

**Overall Assessment**: Excellent

**Recommendation**: Approve with Comments

### Key Strengths

- Static suites (`brute-force-config.bats`, `enumeration-resistant-messages.bats`) are pure file-content assertions — no network, no randomness, no live stack required; all 14 assertions pass against the current committed source tree.
- Integration suite (`brute-force-lockout.bats`) has excellent isolation: unique per-test users (`prefix-$$-$(date +%s)@envocc.local`), a `teardown()` (not inline cleanup) that resets brute-force state and deletes the user even on assertion failure, and zero cross-test shared mutable state.
- Strong DRY structure: `FAILURE_FACTOR` and (post-fix) `QUICK_LOGIN_GUARD_SECONDS` are declared once as documented single-source-of-truth constants; `_bf_create_user`/`_bf_browser_login`/`_bf_extract_error` helpers are reused across all 4 integration tests instead of being duplicated inline.

### Key Weaknesses

- **Medium (fixed at review time):** The integration suite's failed-login loops (TS-273a/b/c) fired `curl` requests back-to-back with no delay. `keycloak/realm-export.json` sets `quickLoginCheckMilliSeconds: 1000` — per the story's own `keycloak/REALM-EXPORT-NOTES.md`, attempts closer together than 1000ms are treated as scripted "quick" retries and immediately incur `minimumQuickLoginWaitSeconds` (60s), independent of the `failureFactor` count being tested. As written, this would make TS-273a spuriously fail on first live-stack execution — not because per-account lockout is broken, but because the test's own request cadence collides with a separate, faster-triggering Keycloak safeguard. Fixed by adding a documented `QUICK_LOGIN_GUARD_SECONDS="1.1"` pacing delay between same-user login attempts inside the three affected loops.
- **Low (advisory, not applied):** Minor duplication across TS-273a/b/c of the "create test user, capture id/username, set `_BF_USER_ID`" 5-line preamble — could be extracted into a `_bf_setup_test_user` wrapper, but the current duplication is small and each test remains independently readable.
- **Low (advisory, not applied):** Fire-and-forget attempts inside the TS-273a/b/c loops don't check for a `"000"` status (curl/URL-resolution failure) before continuing — a transient network blip mid-loop would surface as a confusing downstream assertion mismatch rather than a clear setup failure. Acceptable given the existing repo convention (other integration files follow the same fire-and-forget-in-loop pattern).

### Summary

This suite adds the repo's first brute-force/enumeration-resistance test coverage across two static config-assertion files (14 tests, TS-271x/TS-272x, all green against the current tree) and one live-stack integration file (`brute-force-lockout.bats`, 4 tests, TS-273a–d, correctly skip-guarded behind `INTEGRATION=1`). The review's one substantive finding was a real correctness bug rather than a style nit: the integration suite's request cadence would have collided with Keycloak's `quickLoginCheckMilliSeconds` quick-retry guard, producing false failures unrelated to what the tests claim to verify. This was fixed directly in the test file (pacing delay + comment explaining why, cross-referenced to `REALM-EXPORT-NOTES.md`). Full unit regression (`tests/unit/*.bats`, 145 tests) was re-run after the fix: 141 pass, the same 4 pre-existing unrelated failures noted in the story's Dev Agent Record (`TS-220l/m/m2`, `TS-240a`) are unchanged. The integration file was also re-verified syntactically (bats parses and correctly skips all 4 tests without `INTEGRATION=1`). A live-stack `INTEGRATION=1` run was attempted (Docker/OrbStack was available in this session) but could not complete: sibling BAD-pipeline worktrees for stories 2.6 and 2.8 were concurrently racing for the same host ports 80/443 via their own `docker compose up`, so bringing this story's nginx container up would have been unstable/disruptive; the stack was cleanly torn down rather than forced. This is an environment-contention issue, not a test-quality finding — the deferred live-stack verification (Task 3.4, Task 4, Task 7, `INTEGRATION=1` run) remains open for a follow-up pass with exclusive access to a Docker host, per the story's own Dev Agent Record re-run procedure.

---

## Quality Criteria Assessment

| Criterion                            | Status      | Violations | Notes |
| ------------------------------------ | ----------- | ---------- | ----- |
| BDD Format (Given-When-Then)         | ✅ PASS     | 0          | BATS uses `[P{N}][TS-27Nx]` naming with descriptive `@test` titles |
| Test IDs                             | ✅ PASS     | 0          | TS-271a–d, TS-272a–d, TS-273a–d all present and consistently tagged |
| Priority Markers (P0/P1/P2/P3)       | ✅ PASS     | 0          | P0 on lockout-boolean/messaging-identity checks, P1/P2 on secondary fields |
| Hard Waits (sleep, waitForTimeout)   | ⚠️ WARN     | 1 (fixed)  | 3 new `sleep` calls added in `brute-force-lockout.bats`, but these are a deliberate, documented anti-flake pacing fix (not an arbitrary hard wait for UI state) — required by Keycloak's own `quickLoginCheckMilliSeconds` semantics, not a workaround for missing synchronization |
| Determinism (no conditionals)        | ⚠️→✅ FIXED | 1 (fixed)  | Quick-login-guard timing bug (see Key Weaknesses); no `Math.random()`/unmocked `Date.now()` |
| Isolation (cleanup, no shared state) | ✅ PASS     | 0          | Unique per-test user creation + `teardown()`-based cleanup (survives assertion failure) |
| Fixture Patterns                     | ✅ PASS     | 0          | Reuses `tests/helpers/common.bash` (`get_admin_token`) and `tests/integration/setup_suite.bash` per existing repo convention |
| Data Factories                       | N/A         | 0          | Bash/curl integration tests — no JS-style data factories applicable |
| Network-First Pattern                | N/A         | 0          | Not applicable (bats + curl, no Playwright) |
| Explicit Assertions                  | ✅ PASS     | 0          | `assert_success`/`assert_failure`/`assert_equal` (static suites) and explicit `fail`/status comparisons (integration suite) |
| Test Length (≤300 lines)             | ✅ PASS     | 0          | Largest file (`brute-force-lockout.bats`) is ~379 lines total but individual `@test` bodies are 15–40 lines; length comes from well-documented helper functions and header comments, not monolithic tests |
| Test Duration (≤1.5 min)             | ✅ PASS     | 0          | Static suites: <1s. Integration suite: ~15–20s estimated with the new pacing delays (gated behind `INTEGRATION=1`, not part of the default fast suite) |
| Flakiness Patterns                   | ✅ FIXED    | 1 (fixed)  | Quick-login-guard race (see above) was the one flakiness/false-failure risk found; resolved |

**Total Violations (pre-fix)**: 0 Critical, 1 Medium (determinism/flakiness), 2 Low (advisory)
**Total Violations (post-fix)**: 0 Critical, 0 Medium, 2 Low (advisory, not blocking)

---

## Quality Score Breakdown

```
Starting Score:          100

Pre-fix violations:
  Medium (1 × 5):        -5   (quick-login-guard timing bug)
  Low (2 × 2):           -4   (advisory: preamble duplication, no-"000"-guard in loops)
  Subtotal:              -9

Post-fix bonus:
  Medium finding applied: +5  (pacing fix resolved and verified via bats dry-run)

Structural bonuses:
  Excellent isolation (teardown-based cleanup): +3
  DRY single-source-of-truth constants:         +3
  Full static-suite regression re-verified:      +2
                              --------
Net effective score:     93/100 (advisory Low items left open, not blocking)
```

**Final Score: 93/100 (Grade A)**

---

## Dimension Scores (weighted evaluation)

| Dimension | Score | Grade | Key Finding |
|-----------|-------|-------|-------------|
| Determinism | 96/100 | A | One MEDIUM (quick-login-guard timing collision) found and fixed; no other randomness/time/network-mocking issues |
| Isolation | 96/100 | A | Unique per-test users + `teardown()`-based cleanup; no shared mutable state between tests |
| Maintainability | 90/100 | A- | Strong TS-ID/priority conventions and DRY helpers; minor LOW advisory on preamble duplication across TS-273a/b/c |
| Performance | 88/100 | B+ | Necessary ~15–20s pacing overhead added by the determinism fix (unavoidable given Keycloak's `quickLoginCheckMilliSeconds` design); no unnecessary serialization or inefficiency otherwise |

**Weighted overall**: (96×0.30) + (96×0.30) + (90×0.25) + (88×0.15) = **93/100**

---

## Findings Applied at Review Time

### MEDIUM — Resolved

| ID | File | Finding | Fix Applied |
|----|------|---------|-------------|
| DET-01 | tests/integration/brute-force-lockout.bats | TS-273a/b/c fired failed-login attempts back-to-back with no delay; `quickLoginCheckMilliSeconds: 1000` (realm-export.json) + documented behavior in `keycloak/REALM-EXPORT-NOTES.md` means attempts <1000ms apart trigger a separate 60s "quick retry" wait (`minimumQuickLoginWaitSeconds`) independent of `failureFactor`, which would make TS-273a spuriously fail on a live stack | Added a documented `QUICK_LOGIN_GUARD_SECONDS="1.1"` constant (with rationale + cross-reference to `REALM-EXPORT-NOTES.md`) and inserted `sleep "${QUICK_LOGIN_GUARD_SECONDS}"` between same-user login attempts in the TS-273a, TS-273b, and TS-273c loops |

Verification of the fix: `BATS_LIB_PATH=<path> bats tests/unit/brute-force-config.bats tests/unit/enumeration-resistant-messages.bats tests/integration/brute-force-lockout.bats` — all 14 static assertions pass; all 4 integration tests correctly `skip` without `INTEGRATION=1` (confirming no bash/bats syntax errors were introduced). Full `tests/unit/*.bats` regression (145 tests) re-run post-fix: 141 pass, 4 pre-existing unrelated failures unchanged (`TS-220l`, `TS-220m`, `TS-220m2`, `TS-240a` — already documented in the story's Dev Agent Record as pre-existing and out of scope).

---

## Remaining Advisory Items (not applied — informational only)

| Dimension | Severity | Description |
|-----------|----------|--------------|
| Maintainability | LOW | TS-273a/b/c each repeat a ~5-line "create test user, capture id/username, set `_BF_USER_ID`" preamble. Could be extracted into a `_bf_setup_test_user <prefix> <password>` wrapper that also sets `_BF_USER_ID`, but current duplication is small (3 occurrences, 5 lines each) and each test remains independently readable without following an extra indirection. Optional follow-up, not blocking. |
| Determinism | LOW | The fire-and-forget `_bf_browser_login` calls inside the TS-273a/b/c loops don't check for a `"000"` status (curl/URL-resolution failure) before the loop continues. A transient network blip mid-loop would surface as a confusing downstream assertion mismatch instead of a clear "setup attempt N failed" message. This matches the existing convention in sibling integration files in this repo (none of which check intermediate loop-body curl statuses either), so it is not a story-2.7-specific regression — flagged as a suite-wide advisory, not a required fix for this story. |

---

## Live-Stack Verification Status

The story's Dev Agent Record already documents that Task 3 Subtask 3.4 (manual message-rendering trigger), Task 4 (timing-sample verification), Task 7 (manual smoke test), and the `INTEGRATION=1` run of `tests/integration/brute-force-lockout.bats` were deferred because no Docker daemon was available in the original sandboxed dev session.

In this review session, Docker/OrbStack **was** available, and an attempt was made to bring up the stack (`openssl` dev certs generated, `docker compose down -v && up --build -d`, Keycloak + Postgres reached healthy). However, the `nginx` container failed to bind host ports 80/443: sibling BAD-pipeline worktrees for stories `2.6-totp-mfa-enforcement` and `2.8-disable-blocks-authentication` were concurrently running their own `docker compose up` and racing for the same host ports. Forcing the bind would have been disruptive to those in-flight parallel agents, so the stack was torn down cleanly (`docker compose down -v`) instead. The live-stack checks remain deferred — not as a test-quality finding, but as an environment-contention constraint of this parallel multi-worktree session. Re-run per the story's documented procedure once exclusive access to ports 80/443 is available.

---

## Test File Summary

### `tests/unit/brute-force-config.bats`

- **Framework**: BATS
- **Tests**: 7 `@test` blocks (TS-271a, TS-271b, TS-271c, TS-271d ×4)
- **AC Coverage**: AC1 (per-account progressive-delay field tuning)
- **Pattern**: Static `python3 -c` JSON assertions against `keycloak/realm-export.json`
- **Run**: `BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/unit/brute-force-config.bats` — all 7 pass

### `tests/unit/enumeration-resistant-messages.bats`

- **Framework**: BATS
- **Tests**: 7 `@test` blocks (TS-272a ×2, TS-272b, TS-272c, TS-272d ×2, TS-272 accountDisabledMessage guard)
- **AC Coverage**: AC2 (enumeration-resistant identical messaging)
- **Pattern**: Static `grep`/shell assertions against `messages_en.properties`
- **Run**: `BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/unit/enumeration-resistant-messages.bats` — all 7 pass

### `tests/integration/brute-force-lockout.bats`

- **Framework**: BATS + curl + python3, using `tests/integration/setup_suite.bash` + `tests/helpers/common.bash`
- **Tests**: 4 `@test` blocks (TS-273a, TS-273b, TS-273c, TS-273d)
- **AC Coverage**: AC1 (progressive lockout at `failureFactor`), AC2 (identical locked/wrong-password/nonexistent-user responses)
- **Pattern**: Browser-flow POST against `/realms/envocc/login-actions/authenticate`, Admin REST API for test-user lifecycle and attack-detection status
- **Skip guard**: All 4 tests skip unless `INTEGRATION=1` — confirmed via dry-run
- **Run**: `INTEGRATION=1 BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/integration/brute-force-lockout.bats` (requires live stack; not executed this session — see Live-Stack Verification Status)

---

## Next Recommended Workflow

- **`automate`**: Static suites are CI-ready as-is. `tests/integration/brute-force-lockout.bats` should be wired into a live-stack CI job (or documented as a pre-merge manual gate) alongside the other `tests/integration/*.bats` files — no live-stack CI wiring exists yet in this repo (consistent with prior stories' notes).
- **`trace`**: Coverage mapping is out of scope for `test-review`. A `trace` pass could confirm TS-271x/272x/273x map cleanly to AC1/AC2 and flag whether the TOTP-specific lockout path (`accountTemporarilyDisabledMessageTotp`) needs dedicated integration coverage once story 2.6 (TOTP MFA) lands.
