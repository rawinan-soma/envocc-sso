#!/usr/bin/env bats
# tests/unit/enumeration-resistant-messages.bats
# ATDD tests — Story 2.7: Brute-force protection & enumeration-resistant responses
#
# Static-file assertions against
# keycloak/themes/envocc/login/messages/messages_en.properties.
# All checks are against the committed source tree — no live stack required.
#
# AC2: Identical, generic response for any login failure — enumeration-resistant
#      (FR20, UX-DR9). invalidUserMessage/invalidPasswordMessage must stay
#      byte-identical (already true from story 2.5), and the envocc theme must
#      NOT override the account-lockout message keys — those must inherit
#      Keycloak's base-theme generic "Invalid username or password."-family
#      copy so a brute-force-locked account is indistinguishable from a
#      wrong-password attempt.
#
# Test scenarios covered:
#   TS-272a [P0] invalidUserMessage equals invalidPasswordMessage (byte-identical)
#   TS-272b [P0] messages_en.properties does NOT define accountTemporarilyDisabledMessage
#                (must inherit base theme, not diverge)
#   TS-272c [P0] messages_en.properties does NOT define accountPermanentlyDisabledMessage
#                (must inherit base theme, not diverge)
#   TS-272d [P2] messages_en.properties does NOT define accountTemporarilyDisabledMessageTotp
#                or accountPermanentlyDisabledMessageTotp
#
# TDD Phase: RED-by-regression-guard — these assertions are expected to already
# pass given the current committed messages_en.properties (story 2.5 baseline).
# They exist as a permanent regression gate: any future PR that accidentally
# adds an override for the account-lockout keys must fail this suite (AC2).
#
# Run (no stack required):
#   BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/unit/enumeration-resistant-messages.bats

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

MESSAGES_FILE="${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties"

setup() {
  : # per-test setup (noop for static file checks)
}

teardown() {
  : # per-test teardown
}

# ---------------------------------------------------------------------------
# TS-272a [P0] — invalidUserMessage == invalidPasswordMessage (AC2)
# ---------------------------------------------------------------------------
@test "[P0][TS-272a] messages_en.properties exists" {
  assert [ -f "${MESSAGES_FILE}" ]
}

@test "[P0][TS-272a] invalidUserMessage equals invalidPasswordMessage (byte-identical)" {
  assert [ -f "${MESSAGES_FILE}" ]

  local user_msg pass_msg
  user_msg=$(grep -E "^invalidUserMessage=" "${MESSAGES_FILE}" | head -n 1 | sed -E 's/^invalidUserMessage=//')
  pass_msg=$(grep -E "^invalidPasswordMessage=" "${MESSAGES_FILE}" | head -n 1 | sed -E 's/^invalidPasswordMessage=//')

  [[ -n "${user_msg}" ]] || fail "invalidUserMessage key not found in messages_en.properties"
  [[ -n "${pass_msg}" ]] || fail "invalidPasswordMessage key not found in messages_en.properties"

  assert_equal "${user_msg}" "${pass_msg}"
}

# ---------------------------------------------------------------------------
# TS-272b [P0] — no override of accountTemporarilyDisabledMessage (AC2)
# ---------------------------------------------------------------------------
@test "[P0][TS-272b] messages_en.properties does NOT define accountTemporarilyDisabledMessage" {
  assert [ -f "${MESSAGES_FILE}" ]

  # grep exit 1 (no match) is the success condition — the key must be absent
  # so Keycloak's base theme (enumeration-safe) is inherited unmodified.
  run grep -E "^accountTemporarilyDisabledMessage=" "${MESSAGES_FILE}"
  assert_failure
}

# ---------------------------------------------------------------------------
# TS-272c [P0] — no override of accountPermanentlyDisabledMessage (AC2)
# ---------------------------------------------------------------------------
@test "[P0][TS-272c] messages_en.properties does NOT define accountPermanentlyDisabledMessage" {
  assert [ -f "${MESSAGES_FILE}" ]

  run grep -E "^accountPermanentlyDisabledMessage=" "${MESSAGES_FILE}"
  assert_failure
}

# ---------------------------------------------------------------------------
# TS-272d [P2] — no override of the TOTP-variant lockout messages (AC2)
# ---------------------------------------------------------------------------
@test "[P2][TS-272d] messages_en.properties does NOT define accountTemporarilyDisabledMessageTotp" {
  assert [ -f "${MESSAGES_FILE}" ]

  run grep -E "^accountTemporarilyDisabledMessageTotp=" "${MESSAGES_FILE}"
  assert_failure
}

@test "[P2][TS-272d] messages_en.properties does NOT define accountPermanentlyDisabledMessageTotp" {
  assert [ -f "${MESSAGES_FILE}" ]

  run grep -E "^accountPermanentlyDisabledMessageTotp=" "${MESSAGES_FILE}"
  assert_failure
}

# ---------------------------------------------------------------------------
# TS-272 [P2] — accountDisabledMessage stays distinct (scope note, AC2)
# Accepted UX exception (HR-disabled account, story 2.8 scope) — this key IS
# expected to be overridden and must remain distinct from the generic
# invalid-credentials copy. Regression guard: confirm it still exists and
# still differs from invalidUserMessage (not accidentally merged/reverted).
# ---------------------------------------------------------------------------
@test "[P2][TS-272] accountDisabledMessage override exists and differs from invalidUserMessage (HR-disable scope exception)" {
  assert [ -f "${MESSAGES_FILE}" ]

  local disabled_msg user_msg
  disabled_msg=$(grep -E "^accountDisabledMessage=" "${MESSAGES_FILE}" | head -n 1 | sed -E 's/^accountDisabledMessage=//')
  user_msg=$(grep -E "^invalidUserMessage=" "${MESSAGES_FILE}" | head -n 1 | sed -E 's/^invalidUserMessage=//')

  [[ -n "${disabled_msg}" ]] || fail "accountDisabledMessage key not found (expected override per story 2.5/2.8 scope)"

  # Must be a distinct, non-empty string different from the generic invalid-credentials message
  [[ "${disabled_msg}" != "${user_msg}" ]] || fail "accountDisabledMessage must NOT be conflated with invalidUserMessage (see AC2 scope note)"
}
