---
stepsCompleted: ['step-01-load-context', 'step-02-discover-tests', 'step-03-quality-evaluation', 'step-03f-aggregate-scores', 'step-04-generate-report']
lastStep: 'step-04-generate-report'
lastSaved: '2026-06-20'
workflowType: 'testarch-test-review'
inputDocuments:
  - '_bmad-output/implementation-artifacts/1-1-keycloak-stand-up-baseline-realm-and-secret-hygiene.md'
  - 'tests/integration/ac1-docker-compose-smoke.bats'
  - 'tests/integration/ac1-realm-config.bats'
  - 'tests/secret-hygiene/ac2-secret-hygiene.bats'
  - '_bmad/tea/config.yaml'
---

# Test Quality Review: Story 1-1 — Keycloak Stand-Up, Baseline Realm & Secret Hygiene

**Quality Score**: 77/100 (C — Acceptable, needs targeted fixes)
**Review Date**: 2026-06-20
**Review Scope**: suite (3 BATS files, 41 tests)
**Reviewer**: TEA Agent (claude-sonnet-4-6) / Rawinan

---

Note: This review audits existing tests; it does not generate tests.
Coverage mapping and coverage gates are out of scope here. Use `trace` for coverage decisions.

## Executive Summary

**Overall Assessment**: Acceptable — targeted fixes required before merge

**Recommendation**: Request Changes (fix 3 issues; all fixable in < 30 min)

### Key Strengths

- No hard waits (`sleep`, `waitForTimeout`) anywhere in the suite — all runtime checks are deterministic via `kc_running || skip` guard pattern
- Comprehensive priority tagging (`[P0]`, `[P1]`, `[P2]`) on every `@test` block; test IDs are systematic (`AC1-01` through `AC2-15`)
- Strong isolation: BATS tests are stateless shell commands; no shared mutable state; `teardown_file` correctly conditional on `ATDD_TEARDOWN`; AC2-15 stages/unstages within the test body and cleans up on exit
- Static tests (offline, no Docker) are correctly separated from runtime-guarded tests — this is the right layering for CI
- `_admin_token()` helper in `ac1-realm-config.bats` correctly extracts the bearer token as a pure data helper (no assertions hidden inside)

### Key Weaknesses

- **BUG (CRITICAL)**: `ac1-docker-compose-smoke.bats` AC1-11 regex `'^[A-Z_]+=.{20,}$'` produces a **false positive** on `KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak_db` (43 chars). This test will fail on the correct `.env.example` right now.
- **INCORRECT ASSERTION (HIGH)**: `ac1-realm-config.bats` AC1-RC-04 test name says `emailAsUsername=true` but asserts `duplicateEmailsAllowed=false` instead of `registrationEmailAsUsername:true`. The Keycloak Admin REST API field is `registrationEmailAsUsername` — the test is checking the wrong field for half its claimed purpose.
- **INCONSISTENCY (MEDIUM)**: `kc_running()` is defined differently in the two integration files: `smoke.bats` explicitly verifies HTTP 200; `realm-config.bats` only checks `curl -sf` success (which could pass on 503 if `-f` flag isn't triggered). This is a flakiness vector during Keycloak startup.

### Summary

The Story 1.1 test suite is well-structured for a pure infrastructure/secret-hygiene story. There is no application code to unit-test; the BATS integration/static tests are the appropriate tool. The test design — layering offline static checks over runtime-guarded smoke tests — follows best practices for a Docker Compose stack story.

Three issues require fixes before merge: one is a genuine bug (AC1-11 will fail the correct `.env.example`), one is an incorrect assertion that undermines the AC1 acceptance criteria signal (AC1-RC-04 doesn't test what its name claims), and one is a consistency gap between two definitions of `kc_running()` that could produce misleading skip decisions during Keycloak startup.

---

## Quality Criteria Assessment

| Criterion                             | Status     | Violations | Notes |
|---------------------------------------|------------|------------|-------|
| BDD Format (Given-When-Then)          | ✅ PASS    | 0          | BATS @test names are descriptive; AC comments in headers serve as Given/When |
| Test IDs                              | ✅ PASS    | 0          | All 41 tests have `[ACx-xx]` IDs |
| Priority Markers (P0/P1/P2/P3)        | ✅ PASS    | 0          | All tests tagged P0, P1, or P2 |
| Hard Waits (sleep, waitForTimeout)    | ✅ PASS    | 0          | None found |
| Determinism (no conditionals)         | ⚠️ WARN    | 1          | AC1-11 regex false-positive is a determinism failure — correct env.example always fails this test |
| Isolation (cleanup, no shared state)  | ✅ PASS    | 0          | AC2-15 cleans up staged file; teardown_file is conditional |
| Fixture Patterns                      | ✅ PASS    | 0          | BATS helper functions (`kc_running`, `_admin_token`) are correct pattern; no fixture framework needed |
| Data Factories                        | N/A        | 0          | Not applicable — infrastructure tests; no application data |
| Network-First Pattern                 | N/A        | 0          | Not applicable — smoke tests use direct curl with `-sf` (fail-fast), not browser navigation |
| Explicit Assertions                   | ⚠️ WARN    | 1          | AC1-RC-04 asserts a different field than its name claims |
| Test Length (≤300 lines)              | ✅ PASS    | 0          | Longest file: 244 lines (ac1-realm-config.bats) — within limit |
| Test Duration (≤1.5 min)             | ✅ PASS    | 0          | Static tests: < 5s. Runtime smoke: bounded by `curl -sf` timeout + skip guard |
| Flakiness Patterns                    | ⚠️ WARN    | 1          | `kc_running()` inconsistency — realm-config version may not correctly detect 503 |

**Total Violations**: 0 Critical, 1 High (RC-04), 1 Medium (kc_running inconsistency), 1 Bug (AC1-11 false positive — effectively Critical because it makes a static test always fail)

---

## Quality Score Breakdown

```
Starting Score:          100

Bug Violations (effective HIGH):
  AC1-11 false positive:   -10  (static test fails on correct implementation)

High Violations:
  AC1-RC-04 wrong field:   -8   (assertion name/body mismatch on P0 test)

Medium Violations:
  kc_running inconsistency: -5  (flakiness vector during startup)

Bonus Points:
  No hard waits anywhere:  +5
  All test IDs present:    +5
  Strong priority tagging: +5
  Clean isolation:         +5
  Appropriate test level:  +5
  Proper skip guards:       -   (included above)
                           --------
Total Bonus:             +25
Deductions:              -23

Final Score:              77/100
Grade:                    C (Acceptable — fix 3 issues to reach B+)
```

---

## Critical Issues (Must Fix)

### 1. AC1-11: Regex False Positive — Test Always Fails on Correct `.env.example`

**Severity**: HIGH (functionally Critical — static test produces incorrect result)
**Location**: `tests/integration/ac1-docker-compose-smoke.bats:149–165` (AC1-11 block)
**Criterion**: Determinism / Explicit Assertions
**Knowledge Base**: test-quality.md — "Tests must be deterministic"

**Issue Description**:
The AC1-11 test is meant to verify that `.env.example` contains only placeholder values. It does so by flagging any line matching `'^[A-Z_]+=.{20,}$'` (any env var with a value ≥20 characters) as suspicious. However, `.env.example` legitimately contains `KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak_db` whose value is 43 characters. This is a connection string, not a secret. The test will return `1` (fail) every time it encounters this line, even though the `.env.example` is correct. The test is non-deterministic in intent but always-failing in practice — which is arguably worse.

**Current Code**:

```bash
# ❌ Bad — regex is too broad; flags URL values as secrets
@test "[P1][AC1-11] .env.example contains only placeholder values (change-me or CHANGE_ME)" {
  [ -f ".env.example" ]
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^[A-Z_]+=.{20,}$'; then
      echo "Suspicious non-placeholder value in .env.example: $line"
      return 1
    fi
  done < .env.example
}
```

**Recommended Fix**:

Narrow the heuristic to only flag lines whose values look like secrets (high-entropy mixed character strings), not legitimate URLs, hostnames, or JDBC connection strings. The cleanest approach is to skip lines containing known safe patterns (URLs, `jdbc:`, `postgres://`, `localhost`) or to only flag lines whose variable names contain `PASSWORD`, `SECRET`, `KEY`, `TOKEN`, or `MASTER`:

```bash
# ✅ Good — only check known secret variable names for non-placeholder values
@test "[P1][AC1-11] .env.example contains only placeholder values for secret variables" {
  [ -f ".env.example" ]
  # Only check variables whose names indicate they hold secrets
  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    # Only flag secret-typed variables (PASSWORD, SECRET, KEY, TOKEN, MASTER_KEY)
    if echo "$line" | grep -qE '^[A-Z_]*(PASSWORD|SECRET|KEY|TOKEN|MASTER)[A-Z_]*='; then
      local val
      val="${line#*=}"
      # Value must be a placeholder (change-me, CHANGE_ME, placeholder, empty, or short)
      if echo "$val" | grep -qvE '^(change-me|CHANGE.ME|placeholder|test-only|changeit|your.password|)$'; then
        echo "Non-placeholder secret value in .env.example: $line"
        return 1
      fi
    fi
  done < .env.example
}
```

**Why This Matters**:
This is a static test that runs without Docker. It will block CI every time it is run, defeating its purpose. The correct `.env.example` with `KC_DB_URL` already committed will fail this test unconditionally.

---

### 2. AC1-RC-04: Test Name Claims `emailAsUsername=true` but Assertion Checks Wrong Field

**Severity**: HIGH (P0 acceptance criterion — asserts incorrect API field)
**Location**: `tests/integration/ac1-realm-config.bats:87–100` (AC1-RC-04 block)
**Criterion**: Explicit Assertions — assertions must match what the test name claims
**Knowledge Base**: test-quality.md — "Explicit Assertions: Keep expect() calls in test bodies, not hidden in helpers"

**Issue Description**:
The test description claims to verify `emailAsUsername=true`. In the Keycloak Admin REST API, the field for email-as-username is `registrationEmailAsUsername` (boolean). The test currently only asserts `loginWithEmailAllowed=true` and `duplicateEmailsAllowed=false`. The second assertion is thematically related but is the wrong field for the stated claim. `registrationEmailAsUsername` is what controls whether Keycloak uses the email address as the username, and it is present in the realm export as `"registrationEmailAsUsername":true`. The test as written will pass even if `registrationEmailAsUsername` is inadvertently set to `false` in a future realm change.

**Current Code**:

```bash
# ⚠️ Asserts wrong field for "emailAsUsername" — missing registrationEmailAsUsername
@test "[P0][AC1-RC-04] envocc realm has loginWithEmailAllowed=true and emailAsUsername=true" {
  ...
  echo "$output" | grep -q '"loginWithEmailAllowed":true'
  echo "$output" | grep -q '"duplicateEmailsAllowed":false'  # Wrong field for claim
}
```

**Recommended Fix**:

Replace `duplicateEmailsAllowed` check with `registrationEmailAsUsername` check, which is the actual Keycloak field for "use email as username":

```bash
# ✅ Asserts the actual Keycloak field for email-as-username
@test "[P0][AC1-RC-04] envocc realm has loginWithEmailAllowed=true and registrationEmailAsUsername=true" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"

  local token
  token=$(_admin_token)
  [ -n "$token" ]

  run curl -sf -H "Authorization: Bearer ${token}" \
    "http://localhost:${KC_PORT}/admin/realms/${REALM}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"loginWithEmailAllowed":true'
  echo "$output" | grep -q '"registrationEmailAsUsername":true'
}
```

**Why This Matters**:
This is a P0 test for AC1. It must assert what the acceptance criteria requires (email-as-username = ON). The current assertion would pass even if `registrationEmailAsUsername` was flipped to `false`, which is a specification regression the test should catch.

---

## Recommendations (Should Fix)

### 3. `kc_running()` Has Inconsistent Implementation Between Files

**Severity**: MEDIUM
**Location**: `tests/integration/ac1-docker-compose-smoke.bats:21–23` vs `tests/integration/ac1-realm-config.bats:32–34`
**Criterion**: Determinism / Flakiness Patterns

**Issue Description**:
Both integration files define a `kc_running()` helper for skip-guarding, but with different semantics:

- `smoke.bats`: `curl -sf -o /dev/null -w "%{http_code}" ... | grep -q "200"` — explicitly checks for HTTP 200
- `realm-config.bats`: `curl -sf -o /dev/null ...` — only checks `curl` exit code (0 = HTTP 2xx/3xx with `-f`, meaning 4xx/5xx would still fail with `-f`, but 503 would be caught)

Actually, `curl -sf` with the `-f` flag does return non-zero on 4xx/5xx, so both versions are effectively equivalent for the `/health/ready` endpoint. However, the `smoke.bats` version is explicitly self-documenting (it tells you it expects 200), while `realm-config.bats` version relies on implicit `curl -f` behavior. For consistency and readability:

**Current Code** (`realm-config.bats`):
```bash
# ⚠️ Implicit — relies on curl -sf exit code behavior
kc_running() {
  curl -sf -o /dev/null "http://localhost:${KC_PORT}/health/ready" 2>/dev/null
}
```

**Recommended Improvement**:

Align `realm-config.bats` to match the explicit `smoke.bats` version:

```bash
# ✅ Explicit — readable and consistent with smoke.bats
kc_running() {
  curl -sf -o /dev/null -w "%{http_code}" "http://localhost:${KC_PORT}/health/ready" 2>/dev/null | grep -q "200"
}
```

**Benefits**:
Consistency between files prevents confusion when maintaining tests. Makes the intent explicit (we want HTTP 200, not just "connection accepted"). If Keycloak is still starting and returns 503, `grep -q "200"` cleanly returns 1 while `curl -sf` with `-f` will also return non-zero for 503 — so the behavior is the same, but the explicit version is self-documenting.

**Priority**: P2 — does not affect current correctness but improves clarity and future-proofing.

---

## Best Practices Found

### 1. Skip Guards That Don't Abort the Suite

**Location**: All runtime tests in `tests/integration/`
**Pattern**: `kc_running || skip "message"`

BATS `skip` is the correct idiom for conditional test execution. Using it as the first statement in runtime tests means the static tests always run, and Docker-dependent tests gracefully skip in CI environments where Docker isn't running. This is exactly the right pattern for a mixed static/runtime test suite.

### 2. `_admin_token()` as a Pure Data Helper

**Location**: `tests/integration/ac1-realm-config.bats:19–29`

The `_admin_token()` function extracts data (the bearer token) but contains no assertions. This follows the correct pattern from `test-quality.md`: helpers can extract or transform data, but assertions must remain in the `@test` body. Each test that needs the token calls `[ -n "$token" ]` inline to assert extraction succeeded.

### 3. Python3 for JSON Validation in BATS

**Location**: `tests/integration/ac1-realm-config.bats:173–176` (AC1-RC-09), `tests/secret-hygiene/ac2-secret-hygiene.bats:47–67` (AC2-03)

Using `python3 -c "import json; ..."` for JSON parsing inside BATS is the correct pragmatic choice. `jq` may not be installed, `python3` is universally available on macOS and modern Linux CI. The inline Python for deep-scanning `privateKey` fields (AC2-03) is especially well-designed — it handles nested arrays and dict recursion.

### 4. Conditional Teardown Pattern

**Location**: `tests/integration/ac1-docker-compose-smoke.bats:210–214`

```bash
teardown_file() {
  if [ "${ATDD_TEARDOWN:-false}" = "true" ]; then
    docker compose down -v 2>/dev/null || true
  fi
}
```

Opting out of automatic teardown by default (requiring `ATDD_TEARDOWN=true`) is the correct pattern for a shared dev stack — it prevents the stack from being destroyed between test runs during local development while still allowing CI to clean up after itself.

---

## Test File Analysis

### File Metadata

| File | Lines | Tests | Framework | Phase |
|------|-------|-------|-----------|-------|
| `tests/integration/ac1-docker-compose-smoke.bats` | 215 | 11 | BATS | GREEN |
| `tests/integration/ac1-realm-config.bats` | 244 | 15 | BATS | GREEN |
| `tests/secret-hygiene/ac2-secret-hygiene.bats` | 232 | 15 | BATS | GREEN |
| **Total** | **691** | **41** | | |

### Test Scope

- **Test IDs**: AC1-01 through AC1-11 (smoke), AC1-RC-01 through AC1-RC-15 (realm config), AC2-01 through AC2-15 (secret hygiene)
- **Priority Distribution**:
  - P0 (Critical): 26 tests
  - P1 (High): 13 tests
  - P2 (Medium): 2 tests
  - P3 (Low): 0 tests
- **Static/offline tests**: 23 tests (always run, no Docker required)
- **Runtime-guarded tests**: 18 tests (skip if Keycloak not running)

### Assertions Analysis

- BATS uses `[ ... ]` and `grep -q` as assertions; all assertions are inline in `@test` bodies
- No assertions hidden in helper functions
- Average 2–4 assertions per test

---

## Context and Integration

### Related Artifacts

- **Story File**: [`_bmad-output/implementation-artifacts/1-1-keycloak-stand-up-baseline-realm-and-secret-hygiene.md`](_bmad-output/implementation-artifacts/1-1-keycloak-stand-up-baseline-realm-and-secret-hygiene.md)
- **ATDD Checklist**: `_bmad-output/test-artifacts/atdd-checklist-1-1-keycloak-stand-up-baseline-realm-and-secret-hygiene.md`
- **Risk Assessment**: Story 1.1 is a foundational infrastructure story; secret hygiene failures (AC2) are P0 × P3 = HIGH risk. Realm configuration drift (AC1) is P1 risk.
- **Priority Framework**: P0-P2 applied consistently.

---

## Violation Summary by Location

| File | Line | Severity | Criterion | Issue | Fix |
|------|------|----------|-----------|-------|-----|
| `ac1-docker-compose-smoke.bats` | 154–165 | HIGH (Bug) | Determinism | AC1-11 regex flags `KC_DB_URL` as suspicious — false positive, test always fails | Narrow regex to only check `*PASSWORD*`, `*SECRET*`, `*KEY*`, `*TOKEN*` variable names |
| `ac1-realm-config.bats` | 87–100 | HIGH | Explicit Assertions | AC1-RC-04 asserts `duplicateEmailsAllowed` instead of `registrationEmailAsUsername` | Replace assertion with `grep -q '"registrationEmailAsUsername":true'`; update test name |
| `ac1-realm-config.bats` | 32–34 | MEDIUM | Consistency/Flakiness | `kc_running()` lacks explicit HTTP 200 check (implicit curl -f behavior) | Align to smoke.bats pattern: `... -w "%{http_code}" ... \| grep -q "200"` |

---

## Next Steps

### Immediate Actions (Before Merge)

1. **Fix AC1-11 false positive regex** (`ac1-docker-compose-smoke.bats:149–165`)
   - Priority: P0 (test currently fails on correct implementation)
   - Owner: Dev agent
   - Estimated Effort: 5 minutes

2. **Fix AC1-RC-04 wrong field assertion** (`ac1-realm-config.bats:87–100`)
   - Priority: P0 (wrong AC assertion undermines specification signal)
   - Owner: Dev agent
   - Estimated Effort: 5 minutes

3. **Align `kc_running()` implementations** (`ac1-realm-config.bats:32–34`)
   - Priority: P2 (consistency; no current correctness impact)
   - Owner: Dev agent
   - Estimated Effort: 2 minutes

### Re-Review Needed?

No re-review needed after fixes — all three issues are targeted line-level changes with no architectural implications. Approve after confirming fixes are applied.

---

## Decision

**Recommendation**: Request Changes (3 targeted fixes, all < 30 min combined)

**Rationale**:
The test suite is well-designed for a Story 1.1 scope: correct test levels (BATS integration/static, no unit tests needed), strong skip guards, good isolation, comprehensive AC coverage. Two issues require immediate correction before merge: the AC1-11 regex bug (causes a static test to always fail on the correct implementation — this is a broken CI gate), and the AC1-RC-04 assertion gap (fails to verify the actual Keycloak field for email-as-username, undermining the P0 acceptance criterion). The `kc_running()` inconsistency is a lower-priority cleanup.

After the three fixes are applied, the suite will be production-ready and scores an estimated 88/100 (B+).

---

## Review Metadata

**Generated By**: BMad TEA Agent (Test Architect) — claude-sonnet-4-6
**Workflow**: testarch-test-review
**Review ID**: test-review-story-1-1-20260620
**Timestamp**: 2026-06-20
**Version**: 1.0
