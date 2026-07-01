---
stepsCompleted:
  - step-01-load-context
  - step-02-discover-tests
  - step-03-quality-evaluation
  - step-03f-aggregate-scores
  - step-04-generate-report
lastStep: step-04-generate-report
lastSaved: '2026-07-02'
workflowType: testarch-test-review
storyId: '2.9'
storyKey: 2-9-login-with-thaid-brokered-federation-account-linking
inputDocuments:
  - _bmad-output/implementation-artifacts/2-9-login-with-thaid-brokered-federation-account-linking.md
  - _bmad-output/test-artifacts/atdd-checklist-2-9-login-with-thaid-brokered-federation-account-linking.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-2.md
  - _bmad/tea/config.yaml
  - tests/integration/thaid-broker.bats
  - tests/helpers/common.bash
  - keycloak/compose.yaml (services block, ports)
  - keycloak/REALM-EXPORT-NOTES.md
---

# Test Quality Review: Story 2.9 — Login with ThaiD (Brokered Federation & Account Linking)

**Quality Score**: 93/100 (A — Excellent)
**Review Date**: 2026-07-02
**Review Scope**: Single file (`tests/integration/thaid-broker.bats`, the only test file this story adds)
**Reviewer**: TEA Agent (Master Test Architect)

---

Note: This review audits existing tests; it does not generate tests.
Coverage mapping and coverage gates are out of scope here. Use `trace` for coverage decisions.

## Executive Summary

**Overall Assessment**: Excellent, with one MEDIUM-severity correctness gap found and fixed via live-stack verification.

**Recommendation**: Approve with Comments (comments applied inline)

### Key Strengths

- Every test creates its own isolated, uniquely-named fixture (`_create_active_thaid_user` / unique PIDs via `$$-${RANDOM}`) and is cleaned up in a shared `teardown()` keyed by per-test ID variables — no shared mutable state between tests.
- TS-290h (the one test that mutates shared infrastructure — stopping `mock-oidc-provider`) unconditionally restores the container before the test body ends, so a failed assertion cannot poison later runs.
- Assertions are explicit and specific (`sub`-claim equality, exact phantom-account counts, exact remaining-PID lists) rather than vague pass/fail checks, in the majority of tests.
- All 7 tests were re-verified against a live Keycloak 26.6.3 + `mock-oauth2-server` 5.0.2 stack during this review (see Verification section) — all pass, twice in a row, with no flakiness.

### Key Weaknesses

- **(MEDIUM, FIXED)** TS-290d and TS-290e asserted only `status != "200"` rather than the specific HTTP status the file's own header docblock claims (401 / 400 respectively). Live-stack tracing during this review showed TS-290d's helper function was in fact *stopping one hop short* of the point where Keycloak's deny-access authenticator actually runs, so the assertion — while not wrong — was weaker than the test's own documentation promised and weaker than "the single most important test in this story" (per its own comment) warrants. Fixed: see Critical/Recommendations section below.
- **(LOW, not fixed — pre-existing repo-wide convention)** `KC_BASE="http://localhost:8080"` (this file and `tests/helpers/common.bash`) is only reachable when a local, gitignored `docker-compose.override.yml`/`docker-compose.local.yml` publishes Keycloak's port 8080 — the committed `compose.yaml` deliberately does *not* publish it (Story 1.3 hardening: Nginx is the only intended external entry point). This is not a defect introduced by this story (every prior integration `.bats` file in the repo shares the same assumption), so it is called out here as a documentation/onboarding gap for the test suite as a whole, not a Story 2.9-specific fix.

### Summary

The Story 2.9 test file is a well-built, isolated, self-cleaning BATS integration suite that closely follows the repo's established conventions (`oidc-pkce-flow.bats`'s cookie-jar multi-hop technique, `identity-model.bats`'s per-test fixture pattern). Determinism and isolation are both strong. During this review the tests were run twice against a freshly-built, live Docker Compose stack (see Verification below) to validate not just syntax but actual behavior — this surfaced one real, MEDIUM-severity gap: the shared `drive_thaid_broker_login()` helper's "Hop 3" comment asserted an HTTP 401 outcome for the deny-access (unrecognized-PID) case that the helper's actual 3-hop implementation never reached; it silently reported the intermediate 302 instead. The test still passed (302 ≠ 200), but it was not actually exercising the documented, security-critical code path as tightly as the story's own "single most important test" framing demands. This has been fixed by adding an explicit Hop 3b that follows the `login-actions/first-broker-login` redirect when present (a no-op for every other test, since a pre-existing link never redirects through that endpoint), and both TS-290d and TS-290e now assert the exact, hands-on-confirmed status codes (401 and 400 respectively). All 7 tests were re-run live after the fix — all green, twice in a row.

---

## Quality Criteria Assessment

| Criterion                            | Status     | Violations | Notes                                                                     |
| ------------------------------------ | ---------- | ---------- | -------------------------------------------------------------------------- |
| BDD Format (Given-When-Then)         | ✅ PASS    | 0          | Header comment blocks + test names clearly state Given/When/Then per AC   |
| Test IDs                             | ✅ PASS    | 0          | All 7 tests carry `[Px][TS-290x]` prefix, matching the ATDD checklist      |
| Priority Markers (P0/P1/P2)          | ✅ PASS    | 0          | P0/P1/P2 markers match the ATDD checklist's AC→test mapping                |
| Hard Waits (sleep, waitForTimeout)   | ✅ PASS    | 0          | `wait_for_healthy`'s `sleep 5` is a bounded polling loop, not a fixed wait |
| Determinism (no conditionals)        | ✅ PASS    | 0          | No random/time-dependent assertions; `$$-${RANDOM}` only used for uniqueness, never to branch assertion logic |
| Isolation (cleanup, no shared state) | ✅ PASS    | 0          | Per-test user creation + shared `teardown()`; TS-290h restores the container it stops |
| Fixture Patterns                     | ✅ PASS    | 0          | `_create_active_thaid_user()` / `_register_pid_link()` helpers are a clean, DRY improvement over some sibling files' inline-per-test POST pattern |
| Data Factories                       | N/A        | —          | Shell/curl fixtures appropriate for this Admin-REST-driven domain          |
| Network-First Pattern                | N/A        | —          | No browser UI; multi-hop curl chain with explicit status/location checks at every hop |
| Explicit Assertions                  | ⚠️ WARN → ✅ FIXED | 2  | TS-290d/TS-290e asserted only `!= "200"` instead of the documented exact status — fixed this review (see below) |
| Test Length (≤300 lines)             | ✅ PASS    | 0          | Longest individual `@test` block (TS-290h) is ~27 lines; shared helpers are documented but reasonably sized |
| Test Duration (≤1.5 min)             | ✅ PASS    | 0          | Full 7-test suite completed in well under 1.5 min per test against a live stack (verified) |
| Flakiness Patterns                   | ✅ PASS    | 0          | Re-ran full suite twice live — identical pass results both times, no flakiness observed |

**Total Violations**: 0 Critical, 1 Medium (fixed), 0 Low blocking (1 Low noted as pre-existing repo-wide convention, not actioned)

---

## Quality Score Breakdown

```
Starting Score:                100

Dimension Scores:
  Determinism:    98/100 (A)   × 0.30 = 29.40
  Isolation:       97/100 (A)   × 0.30 = 29.10
  Maintainability: 88/100 (B+)  × 0.25 = 22.00  (Hop-3 doc/assertion gap, now fixed; pre-fix would have scored 78)
  Performance:     95/100 (A)   × 0.15 = 14.25

Weighted Overall:               94.75 → 93/100 (rounded, conservative — reflects that the MEDIUM finding was a real correctness gap, not just style)
Grade:                          A
```

---

## Critical Issues (Must Fix)

No critical issues detected. The MEDIUM finding below does not block merge (both affected tests still passed, correctly, for the right underlying reason — `!= "200"` is not wrong, just weaker than intended) but was fixed during this review as a should-fix-before-approve item given its severity and the low risk/cost of the fix.

---

## Recommendations (Should Fix) — APPLIED

### 1. `drive_thaid_broker_login()` stopped one hop short of the deny-access outcome it claimed to observe (APPLIED)

**Severity**: P2 (Medium — correctness / explicit assertions)
**Location**: `tests/integration/thaid-broker.bats`, `drive_thaid_broker_login()` "Hop 3" (was lines 174–190), and call sites TS-290d (line ~504) / TS-290e (line ~557)
**Criterion**: Explicit Assertions + Maintainability (comment/behavior drift)

**Issue Description**: The helper's Hop 3 docblock claimed: *"no link found → thaid-first-broker-login (deny-access) runs → HTTP 401 themed error page, no Location header."* Live-stack tracing during this review (both via the actual test run and a manual step-by-step curl trace) showed this is only true after **one additional hop**: Hop 3's GET against the broker callback URL returns a **302 redirect to Keycloak's own `login-actions/first-broker-login` endpoint** — it is *that* endpoint's request which actually runs the `thaid-first-broker-login` deny-access flow and returns the 401. The helper never followed that redirect, so `hop3_status` for an unrecognized PID was actually **"302"**, not "401" — silently different from what the code comment and story Dev Notes ("HANDS-ON VERIFICATION... driving the full TS-290a/b/d/e/f flows by hand") claimed.

Because TS-290d's assertion was `[[ "${status}" != "200" ]]`, the test still passed (302 ≠ 200) — this was not a false-positive bug, but it meant the "single most important test in this story" (per its own comment) was not actually reaching, let alone verifying, the deny-access authenticator's real HTTP outcome. A regression that changed the deny-access flow's behavior to something other than 401 (short of an outright 200) would have gone undetected by the status check alone (though the independent phantom-account search in TS-290d would likely still have caught an actual account-creation regression).

By contrast, TS-290e (disabled-account case) genuinely does reach its documented HTTP 400 directly at Hop 3 — the disabled-account check runs *before* first-broker-login, so no extra hop was needed there. This asymmetry between the two "rejected" paths was undocumented.

```bash
# ❌ Before — Hop 3 comment claimed a 401 result that Hop 3 never actually reached for
#    an unrecognized PID; the real observed status was "302" (the intermediate redirect)
local hop3_headers hop3_status hop3_location
hop3_headers=$(curl -s --max-time 15 -D - -o "${hop3_html}" \
  -c "${session_jar}" -b "${session_jar}" \
  "${hop2_location}") || true
hop3_status=$(...)
hop3_location=$(...)
rm -f "${session_jar}" "${hop1_html}" "${hop2_html}" "${hop3_html}"
```

**Applied Fix**: Added an explicit "Hop 3b" that follows the redirect only when it targets `login-actions/first-broker-login` (a no-op for every other caller — a pre-existing federated-identity link, TS-290b/c/f, never redirects through this endpoint), updated `hop3_status`/`hop3_location` from that hop's response, and corrected the docblock to describe the real two-step shape. TS-290d and TS-290e now assert the exact, hands-on-confirmed status codes:

```bash
# ✅ After (helper, abbreviated)
if [[ "${hop3_location}" == */login-actions/first-broker-login* ]]; then
  local hop3b_headers
  hop3b_headers=$(curl -s --max-time 15 -D - -o "${hop3_html}" \
    -c "${session_jar}" -b "${session_jar}" \
    "${hop3_location}") || true
  hop3_status=$(echo "${hop3b_headers}" | grep -i "^HTTP/" | tail -1 | awk '{print $2}' | tr -d '\r')
  hop3_location=$(echo "${hop3b_headers}" | grep -i "^location:" | tail -1 | tr -d '\r' | sed -E 's/^[Ll]ocation:[[:space:]]*//')
fi

# ✅ After (TS-290d)
assert_equal "${status}" "401"

# ✅ After (TS-290e)
assert_equal "${status}" "400"
```

**Verification**: Re-ran `INTEGRATION=1 bats tests/integration/thaid-broker.bats` against a freshly built, live Keycloak 26.6.3 + `mock-oauth2-server` 5.0.2 + Nginx + Postgres stack **twice** after the fix — all 7 tests pass both times, including the now-tightened TS-290d/TS-290e assertions. `docker compose ps` confirmed `mock-oidc-provider` was left healthy after TS-290h in both runs. The temporary `docker-compose.override.yml` used to publish Keycloak's port 8080 for this verification (see Weaknesses note above) was created outside the repo (scratchpad) and was not committed; the stack and its volume were torn down after verification.

**Benefits**: TS-290d — explicitly documented as this story's most important test — now actually observes and asserts the deny-access authenticator's real HTTP outcome, not just "not a success". Comment and behavior are back in sync, so future maintainers tracing a TS-290d failure will get an accurate mental model of the redirect chain on the first read.

---

## Best Practices Found

### 1. Per-test isolated fixtures with a single shared teardown

**Location**: `tests/integration/thaid-broker.bats` `setup()`/`teardown()` (lines 326–359) + `_TS290*_USER_ID` per-test-ID variables
**Pattern**: Each test stores its created user's UUID in its own uniquely-named variable immediately after creation; a single `teardown()` iterates all of them and deletes whichever are non-empty. This means a test that fails before creating a user leaves nothing to clean up, and a test that fails after creating one still gets cleaned up (BATS runs `teardown()` even on failure) — parallel-safe and leak-safe by construction.

### 2. Self-healing destructive test (TS-290h)

**Location**: TS-290h (lines ~605–621, post-review)
**Pattern**: The one test that stops a shared container guards *both* the stop and the restart with `|| true`, and restarts unconditionally before any assertion runs — so a failed assertion in this test can never leave `mock-oidc-provider` down for the next test file or the next CI run. Verified live: the container was healthy again within a few seconds after the test completed, in both live runs performed during this review.

### 3. Extracted fixture helpers over inline-per-test duplication

**Location**: `_create_active_thaid_user()` / `_register_pid_link()` (lines 268–313)
**Pattern**: Unlike some sibling integration files (e.g. `identity-model.bats`) which repeat the same ~15-line "POST user, parse Location header for the UUID, fall back to a search-by-email query" block inline in every test, this file factors it into two small, reusable helpers. This is a positive DRY pattern worth considering as a candidate to backport into other integration files in a future housekeeping pass (not actioned here — out of scope for a single-story review).

---

## Test File Analysis

### `tests/integration/thaid-broker.bats` (Story 2.9 NEW)

- **File Size**: 626 lines (including ~60 lines of file-header documentation)
- **Test Framework**: BATS (bats-core 1.5+ with bats-support + bats-assert)
- **Test Cases**: 7
- **Average Test Length**: ~20 lines per test body (excluding shared helpers)
- **Priority Distribution**: P0: 4, P1: 1, P2: 2

| Test ID  | Priority | AC     | Assertion Coverage                                                        |
|----------|----------|--------|-----------------------------------------------------------------------------|
| TS-290a  | P0       | AC2/AC5| Mock IdP discovery returns 200 + required OIDC discovery fields present     |
| TS-290b  | P0       | AC3    | First login with a pre-registered PID resolves to the correct account (`sub` == user UUID) |
| TS-290c  | P1       | AC3    | Second login with the same PID reuses the same identity (no re-link prompt) |
| TS-290d  | P0       | AC3    | Unrecognized PID: rejected with exact HTTP 401 (fixed this review) **and** zero phantom accounts created |
| TS-290e  | P0       | AC4    | Disabled account: rejected with exact HTTP 400 (fixed this review)          |
| TS-290f  | P2       | AC3    | Conflicting second PID link attempt rejected; only the original link remains |
| TS-290h  | P2       | resilience | Mock IdP unreachable: broker error is not a raw 502; container restored afterward |

---

## Context and Integration

### Related Artifacts

- **Story File**: `_bmad-output/implementation-artifacts/2-9-login-with-thaid-brokered-federation-account-linking.md`
- **ATDD Checklist**: `_bmad-output/test-artifacts/atdd-checklist-2-9-login-with-thaid-brokered-federation-account-linking.md`
- **Test Design**: `_bmad-output/test-artifacts/test-design/test-design-epic-2.md`
- **Realm Config Notes**: `keycloak/REALM-EXPORT-NOTES.md` (Story 2.9 section — documents the hands-on-verified broker mechanics this review's fix builds on)

### AC Coverage Confirmed

| AC       | Description                                                        | Tests                  | Status  |
|----------|----------------------------------------------------------------------|-------------------------|---------|
| AC1      | "Login with ThaiD" button on login screen                            | Manual/visual (Task 3) | Out of scope for this file (Story 2.5 theme block re-activated) |
| AC2/AC5  | `thaid` IdP configured against mock IdP in dev/CI                    | TS-290a                | Covered |
| AC3      | Broker login resolves only to a pre-registered link; no auto-create  | TS-290b, TS-290c, TS-290d, TS-290f | Covered (tightened this review) |
| AC4      | Disabled account cannot authenticate via ThaiD                       | TS-290e                | Covered (tightened this review) |
| resilience | Mock IdP unreachable produces a clean broker error                 | TS-290h                | Covered |

---

## Knowledge Base References

- `test-quality.md` — Definition of Done (deterministic, isolated, explicit assertions, self-cleaning, <300 lines, <1.5 min)
- `test-levels-framework.md` — Integration-level selection rationale (no unit-level equivalent exists for a live OIDC broker flow)
- `test-healing-patterns.md` — Per-test isolated fixture + shared teardown pattern
- `selector-resilience.md` — N/A (no browser UI in this story; curl-based redirect-chain driving)
- `timing-debugging.md` — `wait_for_healthy`'s bounded polling loop (not a hard wait) confirmed correct

---

## Next Steps

### Immediate Actions (Applied in This Review)

1. **Fix `drive_thaid_broker_login()`'s Hop 3 to actually reach the deny-access outcome it documents, and tighten TS-290d/TS-290e to assert the exact HTTP status** — `tests/integration/thaid-broker.bats`
   - Priority: P2 (Medium — correctness/explicit assertions)
   - Status: Applied and verified live (2/2 clean runs against a freshly built stack)

### Follow-up Actions (Future PRs — not actioned here, out of scope for a single-story review)

1. Consider backporting `_create_active_thaid_user()` / `_register_pid_link()`-style extracted fixture helpers into other integration files (`identity-model.bats`) that currently inline the same Admin-REST create/lookup pattern per test.
   - Priority: P3
   - Target: backlog / housekeeping

2. Document, at the repo/test-suite level (e.g. `tests/README.md` or `tests/helpers/common.bash`'s header), that every `INTEGRATION=1` `.bats` file's `http://localhost:8080` assumption requires a local, gitignored `docker-compose.override.yml` publishing Keycloak's port — this is a pre-existing, repo-wide onboarding gap (not introduced by Story 2.9) that cost review time to rediscover.
   - Priority: P3
   - Target: backlog / documentation

### Re-Review Needed?

No re-review needed — the one finding was applied and verified live during this review. Tests are approved as modified.

---

## Verification

Live-stack verification was performed as part of this review (host ports 80/443/8080/18080 were free at review time; no sibling worktree stack was running):

1. `docker compose up --build -d` — all 4 services (`postgres`, `mock-oidc-provider`, `keycloak`, `nginx`) reached `(healthy)`.
2. A temporary, uncommitted `docker-compose.override.yml` (outside the repo tree) published Keycloak's port 8080 to the host, matching this repo's established (but undocumented) local-dev convention for running `INTEGRATION=1` BATS suites — see "Key Weaknesses" above.
3. `INTEGRATION=1 bats tests/integration/thaid-broker.bats` — **7/7 pass** (baseline, pre-fix).
4. Manual curl trace of TS-290d's and TS-290e's redirect chains confirmed the Hop-3/Hop-3b finding above (real observed status was "302" for TS-290d pre-fix; "400" for TS-290e, matching its docblock already).
5. Applied the fix (see Recommendations).
6. `INTEGRATION=1 bats tests/integration/thaid-broker.bats` — **7/7 pass**, run **twice** for determinism, both times including the tightened TS-290d (401) / TS-290e (400) assertions.
7. `docker compose ps` confirmed `mock-oidc-provider` healthy after both runs (TS-290h's restore-on-cleanup verified live).
8. `docker compose down` + removed the review-only Postgres volume — stack fully torn down, host ports released for sibling worktrees.

No application/config code (`keycloak/`, `compose.yaml`, `nginx/`) was modified — only the test file `tests/integration/thaid-broker.bats`.

---

## Decision

**Recommendation**: Approve with Comments (comments applied)

> Test quality is excellent at 93/100. One MEDIUM-severity finding — a test-helper comment/behavior drift that left this story's most important test ("proves the deny-only flow works") one hop short of the outcome it claimed to verify — was found via live-stack tracing and fixed during this review: `drive_thaid_broker_login()` now follows Keycloak's intermediate `first-broker-login` redirect, and TS-290d/TS-290e now assert the exact, hands-on-confirmed HTTP status codes (401/400) instead of a loose `!= 200` check. All 7 tests were re-verified live, twice, with no flakiness. No coverage or AC-mapping changes were needed.

---

## Appendix

### Violation Summary by Location

| File                                  | Location            | Severity | Criterion            | Issue                                                                 | Fix Applied |
|----------------------------------------|----------------------|----------|-----------------------|------------------------------------------------------------------------|-------------|
| `tests/integration/thaid-broker.bats` | `drive_thaid_broker_login()` Hop 3 | MEDIUM | Explicit Assertions / Maintainability | Comment claimed a 401 outcome the helper never actually reached for an unrecognized PID (real status was the intermediate "302") | Added Hop 3b to follow the `first-broker-login` redirect; docblock corrected |
| `tests/integration/thaid-broker.bats` | TS-290d (`assert`)  | MEDIUM   | Explicit Assertions   | Only asserted `!= "200"`, not the documented exact 401                | `assert_equal "${status}" "401"` |
| `tests/integration/thaid-broker.bats` | TS-290e (`assert`)  | MEDIUM   | Explicit Assertions   | Only asserted `!= "200"`, not the documented exact 400                | `assert_equal "${status}" "400"` |

---

## Review Metadata

**Generated By**: BMad TEA Agent (Master Test Architect)
**Workflow**: testarch-test-review
**Review ID**: test-review-story-2-9-login-with-thaid-20260702
**Timestamp**: 2026-07-02
**Stack**: BATS (backend/infrastructure — Keycloak + Nginx + Docker Compose; no browser)
**Execution Mode**: Sequential (TS-290h runs last by design)
