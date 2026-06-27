---
stepsCompleted:
  - step-01-load-context
  - step-02-discover-tests
  - step-03-quality-evaluation
  - step-03f-aggregate-scores
  - step-04-generate-report
lastStep: step-04-generate-report
lastSaved: '2026-06-27'
storyId: '2.1'
storyKey: 2-1-canonical-identity-model-lifecycle-states
inputDocuments:
  - _bmad-output/implementation-artifacts/2-1-canonical-identity-model-lifecycle-states.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-2.md
  - _bmad/tea/config.yaml
  - tests/helpers/common.bash
  - tests/integration/identity-model.bats
  - tests/integration/realm-import.bats
reviewedFiles:
  - tests/integration/identity-model.bats
appliedFixes:
  - TS-210a cleanup gap (MEDIUM/Isolation) — Location header UUID capture
  - PDPA helper extraction (MEDIUM/Maintainability) — shared check_no_pdpa_sensitive_attrs
  - Teardown token optimization (LOW/Performance) — lazy fetch once and reuse
---

# Test Quality Review: Story 2.1 — Canonical Identity Model & Lifecycle States

**Date:** 2026-06-27
**Reviewer:** TEA Master Test Architect
**Scope:** `tests/integration/identity-model.bats` (5 BATS integration tests)
**Framework:** BATS 1.5+, backend stack (Keycloak Admin REST API)
**Execution Mode:** Sequential (auto-resolved: no subagent capability probe)

---

## Score Summary

| Dimension        | Score | Grade | Weight |
| ---------------- | ----- | ----- | ------ |
| Determinism      | 100   | A     | 30%    |
| Isolation        | 88    | B     | 30%    |
| Maintainability  | 88    | B     | 25%    |
| Performance      | 95    | A     | 15%    |
| **Overall**      | **93** | **A** | —     |

> Coverage is excluded from `test-review` scoring. Route coverage analysis to `trace`.

---

## Tests Reviewed

| Test ID   | Priority | Description                                                  | AC   |
| --------- | -------- | ------------------------------------------------------------ | ---- |
| TS-210a   | P2       | Stable sub — same UUID across calls; UUID not recycled after deletion | AC1  |
| TS-210b   | P2       | Email uniqueness enforced — duplicate email POST returns HTTP 409 | AC1  |
| TS-210c   | P2       | Data minimization — no PDPA §26 sensitive fields in user attributes | AC2  |
| TS-210d   | P2       | Pending state blocks login — ROPC token endpoint returns HTTP 400 | AC3  |
| TS-210e   | P2       | No PDPA §26 attributes on freshly created user (clean-creation invariant) | AC2  |

---

## Findings & Fixes Applied

### MEDIUM — Isolation: TS-210a cleanup gap on re-created user

**File:** `tests/integration/identity-model.bats` (TS-210a)

**Problem:** After deleting the first user and clearing `_TS210A_USER_ID=""`, the test re-creates a user with the same email. The re-created user's UUID was only captured via a subsequent GET. If that GET failed (curl exits non-zero), `_TS210A_USER_ID` remained `""` and the re-created user would be permanently leaked with no teardown handle. On the next test run, the leaked user's email (`ts210a@envocc.local`) would cause the initial POST to return 409 instead of 201, breaking the test silently.

**Fix applied:** Replaced the re-create-then-GET pattern with a direct `Location` header capture from the 201 response. The UUID is now extracted immediately from `grep -i '^Location:' | sed 's/^[Ll]ocation: //'` and `${new_location##*/}`, and `_TS210A_USER_ID` is set before any subsequent assertion. The extra GET for the re-created user is eliminated entirely — the `id3` value comes directly from the Location header, which is the authoritative UUID assigned by Keycloak.

---

### MEDIUM — Maintainability: PDPA sensitive_fields list duplicated in TS-210c and TS-210e

**Files:** `tests/integration/identity-model.bats` (TS-210c, TS-210e), `tests/helpers/common.bash`

**Problem:** Both TS-210c and TS-210e contained an identical Python heredoc checking 14 PDPA §26 sensitive field names. Any addition to the forbidden field list (e.g., a new PDPA §26 category) would need to be updated in two places, with the risk of one test becoming stale.

**Fix applied:** Extracted the PDPA check to a new `check_no_pdpa_sensitive_attrs()` helper function in `tests/helpers/common.bash`. The function is the single source of truth for the forbidden field list (FR23/NFR12). Both TS-210c and TS-210e now call `run check_no_pdpa_sensitive_attrs "${user_tmpfile}"` followed by `assert_success`. The diagnostic-first cleanup order (`assert_success` before `rm -f`) is preserved — consistent with the established pattern in `realm-import.bats` (TS-201d) which intentionally keeps the tmpfile available for diagnosis on failure.

---

### LOW — Performance: Admin token re-fetched per-ID in teardown

**File:** `tests/integration/identity-model.bats` (teardown)

**Problem:** The teardown loop called `get_admin_token 2>/dev/null` inside the loop body for each non-empty user ID. TS-210a creates up to 2 users, meaning 2 token round-trips per teardown invocation. While functionally correct, this is wasteful — the admin token has a lifespan of several minutes and can be reused within a single teardown execution.

**Fix applied:** Changed the teardown to fetch the admin token lazily on the first non-empty ID and reuse it for all subsequent deletes within the same teardown call. `local token=""` is initialized before the loop, and the lazy fetch `[[ -n "${token}" ]] || token=$(get_admin_token 2>/dev/null) || true` runs only once on first need.

---

## Findings NOT Applied (Advisory)

### LOW — INFO: POST UUID capture via Location header for TS-210b, TS-210c, TS-210d, TS-210e

**Problem:** All four remaining tests capture the user UUID via a GET-by-email after a successful POST. If the GET fails (very unlikely immediately after a successful POST to a running Keycloak), the user UUID is not recorded and the user would be leaked.

**Decision:** Not applied. The risk is very low (the GET should succeed immediately after the POST with no async processing). The existing GET pattern is idiomatic for the test suite and provides a natural confirmation of user creation. Applying Location-header capture to all four tests would increase code complexity without meaningful reliability benefit. Only TS-210a's gap was critical because it involves an intermediate delete, making the UUID capture window more fragile.

---

## Dimension Detail

### Determinism (100/100)

- No `Math.random()`, `Date.now()`, or arbitrary sleep calls found
- `--max-time 10` on all curl calls is a timeout guard, not an artificial delay
- No conditional flow control or try-catch for flow control
- Hardcoded test emails (e.g., `ts210a@envocc.local`) are intentional stable identifiers in BATS integration tests — parallel execution of the same file would require separate namespacing, but that is a CI configuration concern, not a test code concern
- Teardown cleanup via BATS `teardown()` (runs after each test, pass or fail)

### Isolation (88/100 → after fix: ~95/100)

- Tests do not depend on each other's state
- Each test creates its own data and cleans up via `teardown()`
- BATS runs each test in a separate bash subprocess — global variable mutations do not leak between tests
- **Fixed:** TS-210a cleanup gap (MEDIUM)

### Maintainability (88/100 → after fix: ~95/100)

- File is 395 lines (after fixes) for 5 tests — well within limits
- Test names follow `[PRIORITY][TEST-ID] Description` — aligned with test design doc
- Excellent inline comments explaining AC coverage, task activation timing, design decisions
- Established patterns from `realm-import.bats` are followed consistently
- **Fixed:** PDPA sensitive_fields list duplication (MEDIUM)

### Performance (95/100 → after fix: ~97/100)

- No hard waits — only `--max-time` timeout guards on curl
- Tests are sequential by design (Keycloak integration, stateful server)
- Admin token obtained once per test body (not re-fetched per API call)
- **Fixed:** Teardown token re-fetch optimization (LOW)

---

## Test Design Alignment

| Test ID | Test Design Req | Priority | Coverage |
| ------- | --------------- | -------- | -------- |
| TS-210a | Story 2.1 AC-1 (FR21): Stable `sub` across calls; UUID non-recycling | P2 | Full |
| TS-210b | Story 2.1 AC-1 (FR22): Email uniqueness — duplicate email POST 409 | P2 | Full |
| TS-210c | Story 2.1 AC-2 (FR23): Data minimization — no PDPA §26 fields | P2 | Full |
| TS-210d | Story 2.1 AC-3 (FR24): Lifecycle — pending state blocks login | P2 | Full |
| TS-210e | Story 2.1 AC-2 (FR23): Clean-creation invariant | P2 | Full |

All 5 P2 scenarios from the test design are covered. All acceptance criteria (AC1, AC2, AC3) have at least one test.

---

## Quality Gate: PASS

- No HIGH violations
- 2 MEDIUM violations applied and resolved
- 2 LOW violations: 1 applied, 1 advisory (no action required)
- Test design coverage: 5/5 P2 scenarios covered
- All tests guarded by `INTEGRATION=1` — safe for unit CI runs
- All tests have `teardown()` cleanup — no state pollution between tests
- Pre-commit gate (gitleaks, semgrep, realm-lint) unchanged

---

## Recommendations for Future Stories

1. **Location header capture pattern** (LOW): For integration tests that involve intermediate state changes (create → delete → recreate), always capture the UUID from the POST `Location` header rather than a subsequent GET. This eliminates the cleanup-handle gap.
2. **Shared helpers in common.bash**: As Epic 2 integration tests grow, consider a `tests/helpers/keycloak.bash` for Keycloak-specific helpers (user creation, ROPC auth attempts) to reduce duplication across test files.
3. **Test email namespace isolation**: If integration tests from multiple stories need to run concurrently in CI, prefix test emails with a run-ID (e.g., `${BATS_RUN_ID:-}ts210a@envocc.local`) to prevent email-collision failures on parallel shards.

---

## Files Changed

| File | Change Type | Description |
| ---- | ----------- | ----------- |
| `tests/helpers/common.bash` | UPDATE | Added `check_no_pdpa_sensitive_attrs()` helper — single source of truth for PDPA §26 forbidden attribute list |
| `tests/integration/identity-model.bats` | UPDATE | Fixed TS-210a cleanup gap (Location header UUID capture); replaced PDPA Python heredocs in TS-210c/TS-210e with helper calls; optimized teardown token fetch |

---

**Generated by:** BMad TEA Agent — Test Review Module
**Workflow:** `bmad-testarch-test-review`
**Story:** 2.1 — Canonical identity model & lifecycle states
