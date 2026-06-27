#!/usr/bin/env bats
# tests/unit/realm-session-config.bats
# ATDD RED-PHASE scaffolds — Story 2.4: SSO Session, Lifetimes & RP-Initiated Logout
#
# AC6: Given the realm-export.json lint script,
#      when it runs,
#      then it validates accessTokenLifespan <= 900, revokeRefreshToken == true,
#      and refreshTokenMaxReuse == 0, blocking the commit if any value is wrong.
#
# NOTE: All tests are in RED PHASE (skip).
#       Remove the `skip` annotation from a test when you start implementing
#       the corresponding task, then verify it FAILS first (red phase), then
#       implement until the test passes (green phase).
#
# Test scenarios covered:
#   TS-240a [P0] Lint passes when revokeRefreshToken: true, refreshTokenMaxReuse: 0, accessTokenLifespan: 300 (green path)
#   TS-240b [P0] Lint exits 1 when accessTokenLifespan: 1200 (exceeds 900s NFR2a ceiling)
#   TS-240c [P0] Lint exits 1 when revokeRefreshToken: false
#   TS-240d [P0] Lint exits 1 when refreshTokenMaxReuse: 1
#   TS-240e [P0] Lint exits 1 when revokeRefreshToken is missing
#   TS-240f [P0] Lint exits 1 when refreshTokenMaxReuse is missing
#
# Recommended activation order:
#   Task 2.1 complete -> activate TS-240e
#   Task 2.2 complete -> activate TS-240f
#   Task 2.3 complete -> activate TS-240a, TS-240b, TS-240c, TS-240d
#
# Run: BATS_LIB_PATH=$(pwd)/tests/lib bats tests/unit/realm-session-config.bats

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Minimal VALID fixture — all baseline required fields (realm, enabled,
# bruteForceProtected, accessTokenLifespan) plus the two new session/rotation
# fields at compliant values. Used as the base for all mutation-pattern tests.
# ---------------------------------------------------------------------------
VALID_FIXTURE='{
  "realm": "envocc",
  "enabled": true,
  "bruteForceProtected": true,
  "accessTokenLifespan": 300,
  "revokeRefreshToken": true,
  "refreshTokenMaxReuse": 0
}'

# ---------------------------------------------------------------------------
# TS-240a [P0] — Lint passes with valid session/lifetime/rotation values (green path)
# Activates when: Task 2 complete (value-validation block + REQUIRED_FIELDS extended)
# ---------------------------------------------------------------------------
@test "[P0][TS-240a] Lint passes when revokeRefreshToken=true, refreshTokenMaxReuse=0, accessTokenLifespan=300" {
  skip "RED PHASE — activate after Task 2 (lint value-validation) is fully implemented"

  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  # Assert first so temp file is available for diagnosis on failure; clean up after
  assert_success
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-240b [P0] — Lint exits 1 when accessTokenLifespan exceeds 900s NFR2a ceiling
# Activates when: Task 2.3 complete (value-validation block added to lint script)
# ---------------------------------------------------------------------------
@test "[P0][TS-240b] Lint exits 1 when accessTokenLifespan exceeds 900s ceiling" {
  skip "RED PHASE — Task 2.3: add value-validation block to scripts/lint-realm-export.py"

  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['accessTokenLifespan'] = 1200
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "NFR2a"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-240c [P0] — Lint exits 1 when revokeRefreshToken is false
# Activates when: Task 2.3 complete (value-validation block added to lint script)
# ---------------------------------------------------------------------------
@test "[P0][TS-240c] Lint exits 1 when revokeRefreshToken is false" {
  skip "RED PHASE — Task 2.3: add value-validation block to scripts/lint-realm-export.py"

  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['revokeRefreshToken'] = False
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "FR9"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-240d [P0] — Lint exits 1 when refreshTokenMaxReuse is non-zero
# Activates when: Task 2.3 complete (value-validation block added to lint script)
# ---------------------------------------------------------------------------
@test "[P0][TS-240d] Lint exits 1 when refreshTokenMaxReuse is 1" {
  skip "RED PHASE — Task 2.3: add value-validation block to scripts/lint-realm-export.py"

  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['refreshTokenMaxReuse'] = 1
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "FR9"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-240e [P0] — Lint exits 1 when revokeRefreshToken field is absent
# Activates when: Task 2.1 complete (revokeRefreshToken added to REQUIRED_FIELDS)
# ---------------------------------------------------------------------------
@test "[P0][TS-240e] Lint exits 1 when revokeRefreshToken is missing" {
  skip "RED PHASE — Task 2.1: add 'revokeRefreshToken' to REQUIRED_FIELDS in lint script"

  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
del d['revokeRefreshToken']
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-240f [P0] — Lint exits 1 when refreshTokenMaxReuse field is absent
# Activates when: Task 2.2 complete (refreshTokenMaxReuse added to REQUIRED_FIELDS)
# ---------------------------------------------------------------------------
@test "[P0][TS-240f] Lint exits 1 when refreshTokenMaxReuse is missing" {
  skip "RED PHASE — Task 2.2: add 'refreshTokenMaxReuse' to REQUIRED_FIELDS in lint script"

  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
del d['refreshTokenMaxReuse']
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  rm -f "${fixture}"
}
