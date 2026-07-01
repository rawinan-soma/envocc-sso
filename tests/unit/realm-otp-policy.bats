#!/usr/bin/env bats
# tests/unit/realm-otp-policy.bats
# ATDD Scaffold — Story 2.6: TOTP MFA enforcement & verification hardening
#
# AC3: Given code verification, when a code is checked, then it is accepted only
#      within a bounded clock-drift window — otpPolicyLookAheadWindow is
#      explicitly set to 1 in realm-export.json (config-as-code, lint-enforced
#      — Subtask 1.1/2.4).
#
# This file also lint-enforces the browser-flow shape required by AC1 (Task 2.1/2.2/2.4):
#   - a `browserFlow` is set at the realm root
#   - its referenced flow contains an OTP execution set to CONDITIONAL with a
#     condition-user-configured sub-flow (not DISABLED, and not bare REQUIRED
#     with no condition) — the "Locked Decision" in the story's Dev Notes.
#
# NOTE (deliberate, reviewed correction of the ATDD scaffold — not a silent
# workaround): the original scaffold assumed a nested `"otpPolicy": {...}`
# object with `type`/`digits`/`lookAheadWindow`/`lookBehindWindow` sub-keys.
# Keycloak's RealmRepresentation has no such nested field — importing one
# fails with "Unrecognized field \"otpPolicy\"" (verified against a live
# Keycloak 26.6.3 import). The real schema is flat top-level fields:
# otpPolicyType, otpPolicyAlgorithm, otpPolicyDigits, otpPolicyPeriod,
# otpPolicyLookAheadWindow, otpPolicyCodeReusable, otpPolicyInitialCounter
# (HOTP-only). There is also no "lookBehindWindow" field at all — PUTting one
# via Admin REST returns HTTP 400 "Unrecognized field". Keycloak's
# TimeBasedOTP validator applies otpPolicyLookAheadWindow symmetrically,
# which is what actually delivers AC3's "bounded clock-drift window". All
# fixtures/mutations below were corrected to the flat, real schema; the
# TS-260c scenario (previously "lookBehindWindow != 1", a field that does not
# exist) was repurposed to cover otpPolicyPeriod, another explicit field
# Subtask 1.1 requires; TS-260k/TS-260l were added to cover the two other new
# checks (otpPolicyCodeReusable, and rejecting a regression back to the
# nonexistent nested otpPolicy object).
#
# Test scenarios covered (TS-260 series, next unused prefix after TS-256 from story 2.5):
#   TS-260a [P0] Lint passes when the OTP policy is fully valid + browserFlow references a
#                CONDITIONAL OTP execution gated by condition-user-configured (green path)
#   TS-260b [P0] Lint exits 1 when otpPolicyLookAheadWindow != 1
#   TS-260c [P0] Lint exits 1 when otpPolicyPeriod != 30
#   TS-260d [P0] Lint exits 1 when otpPolicyDigits != 6
#   TS-260e [P0] Lint exits 1 when otpPolicyType != "totp"
#   TS-260f [P0] Lint exits 1 when otpPolicyType is missing entirely
#   TS-260g [P0] Lint exits 1 when browserFlow is missing
#   TS-260h [P0] Lint exits 1 when the referenced browser flow's OTP execution
#                requirement is DISABLED
#   TS-260i [P0] Lint exits 1 when the referenced browser flow's OTP execution
#                is bare REQUIRED with no condition-user-configured sub-flow
#                (the "hard-REQUIRED-without-escape-hatch" regression this story
#                explicitly forbids — see Dev Notes "Flow Requirement Level")
#   TS-260j [P1] Lint exits 1 when otpPolicyLookAheadWindow is a non-integer
#                (type-confusion guard, mirrors TS-240g/h pattern from story 2.4)
#   TS-260k [P1] Lint exits 1 when otpPolicyCodeReusable is not boolean false
#                (AC3 single-use-within-time-step / replay protection)
#   TS-260l [P1] Lint exits 1 when a legacy nested "otpPolicy" object is present
#                (regression guard against the nonexistent-field mistake above)
#
# Run: BATS_LIB_PATH=$(pwd)/tests/lib bats tests/unit/realm-otp-policy.bats
#
# TDD Phase: GREEN — scripts/lint-realm-export.py implements otpPolicy*/
# authenticationFlows checks (Task 1/Task 2/Task 2.4).

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Minimal VALID fixture — baseline required fields (mirrors realm-session-config.bats)
# plus a fully-compliant flat OTP policy and a browserFlow referencing an
# authenticationFlows entry whose OTP Form execution is CONDITIONAL, gated by
# a condition-user-configured sub-flow — the exact shape Task 2.1/2.2 requires.
#
# NOTE (deliberate, reviewed correction of the ATDD scaffold — not a silent
# workaround): the original scaffold fixture only carried the session/rotation
# fields realm-session-config.bats (TS-240) checks, but lint-realm-export.py
# also enforces baseline fields added by stories 2.1/2.2/2.3
# (duplicateEmailsAllowed, registrationAllowed, loginWithEmailAllowed,
# accessCodeLifespan, components.KeyProvider) regardless of which story added
# which check — a fixture missing them fails lint for reasons unrelated to
# otpPolicy/browserFlow. Added those fields below so TS-260a exercises ONLY
# the Story 2.6 checks it documents itself as covering.
# ---------------------------------------------------------------------------
VALID_FIXTURE='{
  "realm": "envocc",
  "enabled": true,
  "bruteForceProtected": true,
  "accessTokenLifespan": 300,
  "revokeRefreshToken": true,
  "refreshTokenMaxReuse": 0,
  "duplicateEmailsAllowed": false,
  "registrationAllowed": false,
  "loginWithEmailAllowed": true,
  "accessCodeLifespan": 60,
  "components": {
    "org.keycloak.keys.KeyProvider": [
      {
        "providerId": "rsa-generated",
        "config": {
          "active": ["true"],
          "enabled": ["true"]
        }
      }
    ]
  },
  "browserFlow": "envocc browser",
  "otpPolicyType": "totp",
  "otpPolicyAlgorithm": "HmacSHA1",
  "otpPolicyDigits": 6,
  "otpPolicyPeriod": 30,
  "otpPolicyLookAheadWindow": 1,
  "otpPolicyCodeReusable": false,
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
# TS-260a [P0] — Lint passes with a fully-compliant OTP policy + CONDITIONAL
# browser-flow OTP execution gated by condition-user-configured (green path)
# ---------------------------------------------------------------------------
@test "[P0][TS-260a] Lint passes when the OTP policy is valid and browserFlow has CONDITIONAL OTP gated by condition-user-configured" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_success
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260b [P0] — Lint exits 1 when otpPolicyLookAheadWindow != 1
# ---------------------------------------------------------------------------
@test "[P0][TS-260b] Lint exits 1 when otpPolicyLookAheadWindow is not 1" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicyLookAheadWindow'] = 3
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "otpPolicyLookAheadWindow"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260c [P0] — Lint exits 1 when otpPolicyPeriod != 30
# (repurposed from the original "lookBehindWindow != 1" scenario — that field
# does not exist in Keycloak's real schema; see file header note)
# ---------------------------------------------------------------------------
@test "[P0][TS-260c] Lint exits 1 when otpPolicyPeriod is not 30" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicyPeriod'] = 60
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "otpPolicyPeriod"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260d [P0] — Lint exits 1 when otpPolicyDigits != 6
# ---------------------------------------------------------------------------
@test "[P0][TS-260d] Lint exits 1 when otpPolicyDigits is not 6" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicyDigits'] = 8
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "otpPolicyDigits"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260e [P0] — Lint exits 1 when otpPolicyType != "totp"
# ---------------------------------------------------------------------------
@test "[P0][TS-260e] Lint exits 1 when otpPolicyType is not totp" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicyType'] = 'hotp'
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "otpPolicyType"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260f [P0] — Lint exits 1 when otpPolicyType is missing entirely
# ---------------------------------------------------------------------------
@test "[P0][TS-260f] Lint exits 1 when otpPolicyType is missing" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
del d['otpPolicyType']
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "otpPolicyType"
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
# TS-260j [P1] — Lint exits 1 when otpPolicyLookAheadWindow is a non-integer
# that would otherwise slip past a loose equality check (type-confusion guard,
# mirrors the TS-240g/h pattern established in story 2.4's session-config lint).
# ---------------------------------------------------------------------------
@test "[P1][TS-260j] Lint exits 1 when otpPolicyLookAheadWindow is boolean true (type-confusion trap)" {
  local fixture
  fixture=$(mktemp)
  # Python: True == 1, so a naive `!= 1` check would incorrectly accept this.
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicyLookAheadWindow'] = True
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "otpPolicyLookAheadWindow"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260k [P1] — Lint exits 1 when otpPolicyCodeReusable is not boolean false
# (AC3: a verified code must be single-use within its time step — Keycloak's
# replay-protection cache is only active when this is explicitly false).
# ---------------------------------------------------------------------------
@test "[P1][TS-260k] Lint exits 1 when otpPolicyCodeReusable is not false" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicyCodeReusable'] = True
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "otpPolicyCodeReusable"
  rm -f "${fixture}"
}

# ---------------------------------------------------------------------------
# TS-260l [P1] — Lint exits 1 when a legacy nested "otpPolicy" object is
# present (regression guard: Keycloak's RealmRepresentation has no such
# field — see file header note — so its presence signals someone reverted to
# the incorrect nested shape).
# ---------------------------------------------------------------------------
@test "[P1][TS-260l] Lint exits 1 when a nested otpPolicy object is present" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['otpPolicy'] = {'type': 'totp', 'digits': 6}
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "otpPolicy"
  rm -f "${fixture}"
}
