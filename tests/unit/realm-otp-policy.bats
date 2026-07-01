#!/usr/bin/env bats
# tests/unit/realm-otp-policy.bats
# ATDD Scaffold — Story 2.6: TOTP MFA enforcement & verification hardening
#
# AC3: Given code verification, when a code is checked, then it is accepted only
#      within a bounded clock-drift window — otpPolicy.lookAheadWindow and
#      otpPolicy.lookBehindWindow are both explicitly set to 1 in realm-export.json
#      (config-as-code, lint-enforced — Subtask 1.1/2.4).
#
# This file also lint-enforces the browser-flow shape required by AC1 (Task 2.1/2.2/2.4):
#   - a `browserFlow` is set at the realm root
#   - its referenced flow contains an OTP execution set to CONDITIONAL with a
#     condition-user-configured sub-flow (not DISABLED, and not bare REQUIRED
#     with no condition) — the "Locked Decision" in the story's Dev Notes.
#
# Test scenarios covered (TS-260 series, next unused prefix after TS-256 from story 2.5):
#   TS-260a [P0] Lint passes when otpPolicy is fully valid + browserFlow references a
#                CONDITIONAL OTP execution gated by condition-user-configured (green path)
#   TS-260b [P0] Lint exits 1 when otpPolicy.lookAheadWindow != 1
#   TS-260c [P0] Lint exits 1 when otpPolicy.lookBehindWindow != 1
#   TS-260d [P0] Lint exits 1 when otpPolicy.digits != 6
#   TS-260e [P0] Lint exits 1 when otpPolicy.type != "totp"
#   TS-260f [P0] Lint exits 1 when otpPolicy is missing entirely
#   TS-260g [P0] Lint exits 1 when browserFlow is missing
#   TS-260h [P0] Lint exits 1 when the referenced browser flow's OTP execution
#                requirement is DISABLED
#   TS-260i [P0] Lint exits 1 when the referenced browser flow's OTP execution
#                is bare REQUIRED with no condition-user-configured sub-flow
#                (the "hard-REQUIRED-without-escape-hatch" regression this story
#                explicitly forbids — see Dev Notes "Flow Requirement Level")
#   TS-260j [P1] Lint exits 1 when otpPolicy.lookAheadWindow is a non-integer
#                (type-confusion guard, mirrors TS-240g/h pattern from story 2.4)
#
# Run: BATS_LIB_PATH=$(pwd)/tests/lib bats tests/unit/realm-otp-policy.bats
#
# TDD Phase: RED — scripts/lint-realm-export.py does not yet implement any of
# these otpPolicy/authenticationFlows checks (Task 1/Task 2 not yet built).
# All tests in this file are expected to FAIL until Task 2.4 is implemented.

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Minimal VALID fixture — baseline required fields (mirrors realm-session-config.bats)
# plus a fully-compliant otpPolicy and a browserFlow referencing an
# authenticationFlows entry whose OTP Form execution is CONDITIONAL, gated by
# a condition-user-configured sub-flow — the exact shape Task 2.1/2.2 requires.
# ---------------------------------------------------------------------------
VALID_FIXTURE='{
  "realm": "envocc",
  "enabled": true,
  "bruteForceProtected": true,
  "accessTokenLifespan": 300,
  "revokeRefreshToken": true,
  "refreshTokenMaxReuse": 0,
  "browserFlow": "envocc browser",
  "otpPolicy": {
    "type": "totp",
    "algorithm": "HmacSHA1",
    "digits": 6,
    "period": 30,
    "lookAheadWindow": 1,
    "lookBehindWindow": 1
  },
  "authenticationFlows": [
    {
      "alias": "envocc browser",
      "description": "Custom browser flow with conditional OTP",
      "providerId": "basic-flow",
      "topLevel": true,
      "builtIn": false,
      "authenticationExecutions": [
        {
          "authenticator": "auth-cookie",
          "requirement": "ALTERNATIVE",
          "priority": 10,
          "userSetupAllowed": false,
          "autheticatorFlow": false
        },
        {
          "authenticator": "identity-provider-redirector",
          "requirement": "ALTERNATIVE",
          "priority": 25,
          "userSetupAllowed": false,
          "autheticatorFlow": false
        },
        {
          "flowAlias": "envocc browser forms",
          "requirement": "ALTERNATIVE",
          "priority": 30,
          "userSetupAllowed": false,
          "autheticatorFlow": true
        }
      ]
    },
    {
      "alias": "envocc browser forms",
      "description": "Username/password + conditional OTP",
      "providerId": "basic-flow",
      "topLevel": false,
      "builtIn": false,
      "authenticationExecutions": [
        {
          "authenticator": "auth-username-password-form",
          "requirement": "REQUIRED",
          "priority": 10,
          "userSetupAllowed": false,
          "autheticatorFlow": false
        },
        {
          "flowAlias": "envocc browser forms conditional otp",
          "requirement": "CONDITIONAL",
          "priority": 20,
          "userSetupAllowed": false,
          "autheticatorFlow": true
        }
      ]
    },
    {
      "alias": "envocc browser forms conditional otp",
      "description": "Conditional OTP — only asked if the user has a TOTP credential",
      "providerId": "basic-flow",
      "topLevel": false,
      "builtIn": false,
      "authenticationExecutions": [
        {
          "authenticator": "conditional-user-configured",
          "requirement": "REQUIRED",
          "priority": 10,
          "userSetupAllowed": false,
          "autheticatorFlow": false
        },
        {
          "authenticator": "auth-otp-form",
          "requirement": "REQUIRED",
          "priority": 20,
          "userSetupAllowed": false,
          "autheticatorFlow": false
        }
      ]
    }
  ]
}'

# ---------------------------------------------------------------------------
# TS-260a [P0] — Lint passes with a fully-compliant otpPolicy + CONDITIONAL
# browser-flow OTP execution gated by condition-user-configured (green path)
# ---------------------------------------------------------------------------
@test "[P0][TS-260a] Lint passes when otpPolicy is valid and browserFlow has CONDITIONAL OTP gated by condition-user-configured" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_success
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260b [P0] — Lint exits 1 when otpPolicy.lookAheadWindow != 1
# ---------------------------------------------------------------------------
@test "[P0][TS-260b] Lint exits 1 when otpPolicy.lookAheadWindow is not 1" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicy']['lookAheadWindow'] = 3
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "lookAheadWindow"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260c [P0] — Lint exits 1 when otpPolicy.lookBehindWindow != 1
# ---------------------------------------------------------------------------
@test "[P0][TS-260c] Lint exits 1 when otpPolicy.lookBehindWindow is not 1" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicy']['lookBehindWindow'] = 0
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "lookBehindWindow"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260d [P0] — Lint exits 1 when otpPolicy.digits != 6
# ---------------------------------------------------------------------------
@test "[P0][TS-260d] Lint exits 1 when otpPolicy.digits is not 6" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicy']['digits'] = 8
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "digits"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260e [P0] — Lint exits 1 when otpPolicy.type != "totp"
# ---------------------------------------------------------------------------
@test "[P0][TS-260e] Lint exits 1 when otpPolicy.type is not totp" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicy']['type'] = 'hotp'
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "otpPolicy.type"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260f [P0] — Lint exits 1 when otpPolicy is missing entirely
# ---------------------------------------------------------------------------
@test "[P0][TS-260f] Lint exits 1 when otpPolicy is missing" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
del d['otpPolicy']
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "otpPolicy"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260g [P0] — Lint exits 1 when browserFlow is missing
# ---------------------------------------------------------------------------
@test "[P0][TS-260g] Lint exits 1 when browserFlow is missing" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
del d['browserFlow']
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "browserFlow"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260h [P0] — Lint exits 1 when the referenced browser flow's OTP execution
# requirement is DISABLED (OTP effectively turned off — must be caught)
# ---------------------------------------------------------------------------
@test "[P0][TS-260h] Lint exits 1 when the OTP Form execution requirement is DISABLED" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for flow in d['authenticationFlows']:
    if flow['alias'] == 'envocc browser forms conditional otp':
        for ex in flow['authenticationExecutions']:
            if ex['authenticator'] == 'auth-otp-form':
                ex['requirement'] = 'DISABLED'
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "CONDITIONAL"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260i [P0] — Lint exits 1 when the OTP step is bare REQUIRED with no
# condition-user-configured sub-flow. This is the "Locked Decision" regression
# guard from Dev Notes: hard REQUIRED without an enrollment escape hatch would
# strand any account without a TOTP credential — the lint must reject it.
# ---------------------------------------------------------------------------
@test "[P0][TS-260i] Lint exits 1 when OTP execution is bare REQUIRED with no condition-user-configured sub-flow" {
  local fixture
  fixture=$(mktemp)
  # Collapse the flow to inline a REQUIRED auth-otp-form directly on the
  # "envocc browser forms" flow, with no conditional sub-flow at all —
  # simulates the forbidden hard-REQUIRED implementation.
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for flow in d['authenticationFlows']:
    if flow['alias'] == 'envocc browser forms':
        flow['authenticationExecutions'] = [
            {
                'authenticator': 'auth-username-password-form',
                'requirement': 'REQUIRED',
                'priority': 10,
                'userSetupAllowed': False,
                'autheticatorFlow': False
            },
            {
                'authenticator': 'auth-otp-form',
                'requirement': 'REQUIRED',
                'priority': 20,
                'userSetupAllowed': False,
                'autheticatorFlow': False
            }
        ]
d['authenticationFlows'] = [f for f in d['authenticationFlows'] if f['alias'] != 'envocc browser forms conditional otp']
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "condition-user-configured"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260j [P1] — Lint exits 1 when otpPolicy.lookAheadWindow is a non-integer
# that would otherwise slip past a loose equality check (type-confusion guard,
# mirrors the TS-240g/h pattern established in story 2.4's session-config lint).
# ---------------------------------------------------------------------------
@test "[P1][TS-260j] Lint exits 1 when otpPolicy.lookAheadWindow is boolean true (type-confusion trap)" {
  local fixture
  fixture=$(mktemp)
  # Python: True == 1, so a naive `!= 1` check would incorrectly accept this.
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicy']['lookAheadWindow'] = True
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "lookAheadWindow"
  rm -f "${fixture}"
}
