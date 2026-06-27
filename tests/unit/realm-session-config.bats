#!/usr/bin/env bats
# tests/unit/realm-session-config.bats
# Story 2.4: Lint value-validation for session/lifetime/refresh-token config
#
# AC6: Given the realm-export.json lint script,
#      when it runs,
#      then it validates accessTokenLifespan <= 900, revokeRefreshToken == true,
#      and refreshTokenMaxReuse == 0, blocking the commit if any value is wrong.
#
# Test scenarios covered:
#   TS-240a [P0] Lint passes when revokeRefreshToken: true, refreshTokenMaxReuse: 0, accessTokenLifespan: 300 (green path)
#   TS-240b [P0] Lint exits 1 when accessTokenLifespan: 1200 (exceeds 900s NFR2a ceiling)
#   TS-240c [P0] Lint exits 1 when revokeRefreshToken: false
#   TS-240d [P0] Lint exits 1 when refreshTokenMaxReuse: 1
#   TS-240e [P0] Lint exits 1 when revokeRefreshToken is missing
#   TS-240f [P0] Lint exits 1 when refreshTokenMaxReuse is missing
#   TS-240g [P0] Lint exits 1 when accessTokenLifespan is a non-integer over the ceiling
#   TS-240h [P0] Lint exits 1 when refreshTokenMaxReuse is boolean false (False == 0 trap)
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
# ---------------------------------------------------------------------------
@test "[P0][TS-240a] Lint passes when revokeRefreshToken=true, refreshTokenMaxReuse=0, accessTokenLifespan=300" {
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
# ---------------------------------------------------------------------------
@test "[P0][TS-240b] Lint exits 1 when accessTokenLifespan exceeds 900s ceiling" {
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
# ---------------------------------------------------------------------------
@test "[P0][TS-240c] Lint exits 1 when revokeRefreshToken is false" {
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
  # Match the field-specific message, not just "FR9" (which both refresh-token
  # error strings contain) — confirms the revokeRefreshToken check is what fired.
  assert_output --partial "revokeRefreshToken must be true"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-240d [P0] — Lint exits 1 when refreshTokenMaxReuse is non-zero
# ---------------------------------------------------------------------------
@test "[P0][TS-240d] Lint exits 1 when refreshTokenMaxReuse is 1" {
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
  # Match the field-specific message, not just "FR9" — confirms the
  # refreshTokenMaxReuse check is what fired (both FR9 strings share "FR9").
  assert_output --partial "refreshTokenMaxReuse must be 0"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-240e [P0] — Lint exits 1 when revokeRefreshToken field is absent
# ---------------------------------------------------------------------------
@test "[P0][TS-240e] Lint exits 1 when revokeRefreshToken is missing" {
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
  assert_output --partial "revokeRefreshToken"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-240f [P0] — Lint exits 1 when refreshTokenMaxReuse field is absent
# ---------------------------------------------------------------------------
@test "[P0][TS-240f] Lint exits 1 when refreshTokenMaxReuse is missing" {
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
  assert_output --partial "refreshTokenMaxReuse"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-240g [P0] — Lint exits 1 when accessTokenLifespan is a non-integer that
# would otherwise bypass the NFR2a ceiling (string/float/bool fail open if the
# check only guards on `isinstance(int)`). Regression for the type-confusion gap.
# ---------------------------------------------------------------------------
@test "[P0][TS-240g] Lint exits 1 when accessTokenLifespan is a non-integer over the ceiling" {
  local fixture
  fixture=$(mktemp)
  # 1200.0 (float) and "1200" (string) are both over the 900s ceiling but are
  # not Python ints — the ceiling must still reject them, not fail open.
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['accessTokenLifespan'] = 1200.0
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "accessTokenLifespan"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-240h [P0] — Lint exits 1 when refreshTokenMaxReuse is boolean false.
# Python's `False == 0` would let a JSON `false` pass a naive `!= 0` check;
# the type-strict guard must reject it. Regression for the type-confusion gap.
# ---------------------------------------------------------------------------
@test "[P0][TS-240h] Lint exits 1 when refreshTokenMaxReuse is boolean false" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['refreshTokenMaxReuse'] = False
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "refreshTokenMaxReuse must be 0"
  rm -f "${fixture}"
}
