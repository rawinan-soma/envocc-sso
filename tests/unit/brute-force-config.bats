#!/usr/bin/env bats
# tests/unit/brute-force-config.bats
# ATDD tests — Story 2.7: Brute-force protection & enumeration-resistant responses
#
# Static-file assertions against keycloak/realm-export.json.
# All checks are against the committed source tree — no live stack required.
#
# AC1: Progressive delays, per-account (Keycloak native brute-force detection) —
#      failureFactor tuned from the story-1.2 placeholder (30) to 5, and the six
#      other pre-existing brute-force timing fields re-affirmed as deliberate.
#
# Test scenarios covered:
#   TS-271a [P0] realm-export.json sets bruteForceProtected: true
#   TS-271b [P1] realm-export.json sets failureFactor to 5 (not the story-1.2 placeholder of 30)
#   TS-271c [P1] realm-export.json sets permanentLockout: false
#   TS-271d [P2] realm-export.json sets waitIncrementSeconds, maxFailureWaitSeconds,
#                minimumQuickLoginWaitSeconds, quickLoginCheckMilliSeconds,
#                maxDeltaTimeSeconds (all present, all positive integers)
#
# TDD Phase: RED — TS-271b fails until keycloak/realm-export.json's failureFactor
# is changed from 30 to 5 (Task 1, Subtask 1.1). TS-271a/c/d are expected to
# already pass (pre-existing values from story 1.2) — included here as
# regression guards, not new red-phase assertions.
#
# Run (no stack required):
#   BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/unit/brute-force-config.bats

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

setup() {
  : # per-test setup (noop for static file checks)
}

teardown() {
  : # per-test teardown
}

# ---------------------------------------------------------------------------
# TS-271a [P0] — bruteForceProtected: true (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-271a] realm-export.json sets bruteForceProtected: true" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run python3 -c "
import json
d = json.load(open('${PROJECT_ROOT}/keycloak/realm-export.json'))
val = d.get('bruteForceProtected')
assert val is True, f'bruteForceProtected: expected=True actual={val!r}'
"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-271b [P1] — failureFactor tuned to 5 (AC1, Task 1.1)
# RED PHASE: Fails until realm-export.json's failureFactor is changed from 30 to 5.
# ---------------------------------------------------------------------------
@test "[P1][TS-271b] realm-export.json sets failureFactor to 5 (not the story-1.2 placeholder of 30)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run python3 -c "
import json
d = json.load(open('${PROJECT_ROOT}/keycloak/realm-export.json'))
val = d.get('failureFactor')
assert isinstance(val, int) and not isinstance(val, bool), f'failureFactor: expected int, actual={val!r}'
assert val == 5, f'failureFactor: expected=5 actual={val!r} (story-1.2 placeholder was 30 — must be tuned down)'
"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-271c [P1] — permanentLockout: false (AC1)
# ---------------------------------------------------------------------------
@test "[P1][TS-271c] realm-export.json sets permanentLockout: false" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run python3 -c "
import json
d = json.load(open('${PROJECT_ROOT}/keycloak/realm-export.json'))
val = d.get('permanentLockout')
assert val is False, f'permanentLockout: expected=False actual={val!r}'
"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-271d [P2] — progressive-delay curve fields present and positive (AC1)
# waitIncrementSeconds, maxFailureWaitSeconds, minimumQuickLoginWaitSeconds,
# quickLoginCheckMilliSeconds, maxDeltaTimeSeconds
# ---------------------------------------------------------------------------
@test "[P2][TS-271d] realm-export.json sets all five brute-force timing fields as positive integers" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run python3 -c "
import json
d = json.load(open('${PROJECT_ROOT}/keycloak/realm-export.json'))

fields = [
    'waitIncrementSeconds',
    'maxFailureWaitSeconds',
    'minimumQuickLoginWaitSeconds',
    'quickLoginCheckMilliSeconds',
    'maxDeltaTimeSeconds',
]

failures = []
for key in fields:
    val = d.get(key)
    if not isinstance(val, int) or isinstance(val, bool) or val <= 0:
        failures.append(f'{key}: expected positive int, actual={val!r}')

assert not failures, 'Brute-force timing field mismatches: ' + str(failures)
"
  assert_success
}

@test "[P2][TS-271d] realm-export.json waitIncrementSeconds is 60 and maxFailureWaitSeconds is 900 (documented progressive-delay curve)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run python3 -c "
import json
d = json.load(open('${PROJECT_ROOT}/keycloak/realm-export.json'))
assert d.get('waitIncrementSeconds') == 60, f'waitIncrementSeconds: expected=60 actual={d.get(\"waitIncrementSeconds\")!r}'
assert d.get('maxFailureWaitSeconds') == 900, f'maxFailureWaitSeconds: expected=900 actual={d.get(\"maxFailureWaitSeconds\")!r}'
"
  assert_success
}

@test "[P2][TS-271d] realm-export.json minimumQuickLoginWaitSeconds is 60 and quickLoginCheckMilliSeconds is 1000" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run python3 -c "
import json
d = json.load(open('${PROJECT_ROOT}/keycloak/realm-export.json'))
assert d.get('minimumQuickLoginWaitSeconds') == 60, f'minimumQuickLoginWaitSeconds: expected=60 actual={d.get(\"minimumQuickLoginWaitSeconds\")!r}'
assert d.get('quickLoginCheckMilliSeconds') == 1000, f'quickLoginCheckMilliSeconds: expected=1000 actual={d.get(\"quickLoginCheckMilliSeconds\")!r}'
"
  assert_success
}

@test "[P2][TS-271d] realm-export.json maxDeltaTimeSeconds is 43200 (12h failure-count reset window)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run python3 -c "
import json
d = json.load(open('${PROJECT_ROOT}/keycloak/realm-export.json'))
assert d.get('maxDeltaTimeSeconds') == 43200, f'maxDeltaTimeSeconds: expected=43200 actual={d.get(\"maxDeltaTimeSeconds\")!r}'
"
  assert_success
}
