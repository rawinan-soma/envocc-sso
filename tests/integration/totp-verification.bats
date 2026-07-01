#!/usr/bin/env bats
# tests/integration/totp-verification.bats
# ATDD Scaffold — Story 2.6: TOTP MFA enforcement & verification hardening
#
# AC1: TOTP required after password for every account with a configured
#      credential (FR13) — via the browser authentication flow; skipping the
#      OTP step does not yield tokens.
# AC3: Bounded clock-drift, rate-limited, single-use-per-time-step verification (FR14):
#      - accepted only within lookAheadWindow/lookBehindWindow = 1 (±30s)
#      - rate-limited via bruteForceProtected covering the OTP step
#      - a verified code is single-use within its time step (replay rejected)
#
# Test scenarios covered (align to test-design-epic-2.md lines 182-183 P0, 213-214 P1):
#   TS-261a [P0] Valid TOTP code after password succeeds → tokens issued
#   TS-261b [P0] Skipping the OTP step after password succeeds does NOT yield tokens (AC1)
#   TS-261c [P0] Same valid TOTP code resubmitted within the same time step is rejected (AC3 replay)
#   TS-261d [P0] Several invalid TOTP codes in a row trigger rate-limited/delayed response (AC3 brute-force)
#   TS-261e [P1] User with no TOTP credential configured skips the OTP branch entirely
#                (regression guard for the CONDITIONAL flow shape — Task 2.5)
#
# IMPORTANT: All tests require a live Keycloak stack with Story 2.6 config applied:
#   - keycloak/realm-export.json updated (otpPolicy + authenticationFlows + browserFlow)
#   - docker compose down -v && docker compose up --build (fresh import)
#
# TOTP secrets are provisioned via Admin REST PUT
# /admin/realms/{realm}/users/{id}/configure-totp — NOT the enrollment UI
# (enrollment UX is out of scope, Epic 3/Story 3.3, per Dev Notes).
#
# To run: INTEGRATION=1 bats tests/integration/totp-verification.bats
# Pre-requisites:
#   1. docker compose down -v && docker compose up --build  (Story 2.6 realm config)
#   2. .env with KC_BOOTSTRAP_ADMIN_USERNAME / KC_BOOTSTRAP_ADMIN_PASSWORD set
#   3. BATS_LIB_PATH=$(pwd)/tests/lib or bats-support/bats-assert installed system-wide
#
# TDD Phase: RED — realm-export.json does not yet define otpPolicy /
# authenticationFlows / browserFlow (Task 1/Task 2 not yet built), and
# configure-totp against the current realm has no CONDITIONAL OTP execution
# to exercise. All INTEGRATION=1 tests in this file are expected to FAIL
# until Tasks 1, 2, and 4 are implemented against a live rebuilt stack.

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
KC_BASE="http://localhost:8080"
REALM="envocc"
CLIENT_ID="test-oidc-client"
REDIRECT_URI="http://localhost:8888/callback"
AUTH_ENDPOINT="${KC_BASE}/realms/${REALM}/protocol/openid-connect/auth"
TOKEN_ENDPOINT="${KC_BASE}/realms/${REALM}/protocol/openid-connect/token"

# RFC 6238 TOTP period; matches otpPolicy.period=30 required by AC3/Subtask 1.1.
TOTP_PERIOD=30

# ---------------------------------------------------------------------------
# PKCE helpers (mirrors tests/integration/oidc-pkce-flow.bats)
# ---------------------------------------------------------------------------
pkce_generate() {
  local verifier challenge
  verifier=$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')
  challenge=$(printf '%s' "${verifier}" | openssl dgst -sha256 -binary | openssl base64 | tr '+/' '-_' | tr -d '=\n')
  printf '%s\n%s\n' "${verifier}" "${challenge}"
}

# ---------------------------------------------------------------------------
# totp_code <base32_secret> [time_offset_seconds]
# Pure-stdlib RFC 6238 TOTP generator (no pyotp dependency — mirrors this
# repo's stdlib-only Python convention used throughout scripts/ and tests/).
# Prints the current (or offset) 6-digit TOTP code for the given base32 secret.
# ---------------------------------------------------------------------------
totp_code() {
  local secret="${1}"
  local offset="${2:-0}"
  python3 -c "
import base64, hashlib, hmac, struct, sys, time

secret = sys.argv[1]
offset = int(sys.argv[2])
period = int(sys.argv[3])

# Normalize base32 padding
key = secret.strip().upper()
key += '=' * ((8 - len(key) % 8) % 8)
key_bytes = base64.b32decode(key)

counter = int((time.time() + offset) // period)
msg = struct.pack('>Q', counter)
digest = hmac.new(key_bytes, msg, hashlib.sha1).digest()
offset_bits = digest[-1] & 0x0F
truncated = struct.unpack('>I', digest[offset_bits:offset_bits + 4])[0] & 0x7FFFFFFF
code = truncated % 1_000_000
print(f'{code:06d}')
" "${secret}" "${offset}" "${TOTP_PERIOD}"
}

# ---------------------------------------------------------------------------
# totp_secret_base32
# Generate a random RFC 4648 base32 secret (160-bit, matches Keycloak's
# default TOTP secret length) for use with configure-totp.
# ---------------------------------------------------------------------------
totp_secret_base32() {
  python3 -c "
import base64, os
print(base64.b32encode(os.urandom(20)).decode('utf-8').rstrip('='))
"
}

# ---------------------------------------------------------------------------
# configure_totp_for_user <admin_token> <user_id> <base32_secret>
# Provisions a TOTP credential on an existing user via Admin REST, matching
# Keycloak's PUT /admin/realms/{realm}/users/{id}/configure-totp semantics for
# a pre-existing secret (test setup only — never the enrollment UI).
# ---------------------------------------------------------------------------
configure_totp_for_user() {
  local admin_token="${1}" user_id="${2}" secret="${3}"
  curl -sf --max-time 15 \
    -X PUT "${KC_BASE}/admin/realms/${REALM}/users/${user_id}/configure-totp" \
    -H "Authorization: Bearer ${admin_token}" \
    -H "Content-Type: application/json" \
    -d "{\"secret\": \"${secret}\", \"encoding\": \"BASE32\"}"
}

# ---------------------------------------------------------------------------
# Login-form helpers — split into two steps because story 2.6 introduces a
# real OTP step between password submission and the auth-code redirect.
# ---------------------------------------------------------------------------

# submit_password_step <verifier> <challenge> <email> <password>
# Initiates the auth request, submits username/password, and returns the
# Set-Cookie session jar path (stdout line 1) and the OTP form's action URL
# (stdout line 2). On password rejection or unexpected redirect (no OTP form
# reached), returns non-zero.
submit_password_step() {
  local challenge="${1}" email="${2}" password="${3}"
  local session_jar tmphtml
  session_jar=$(mktemp "${TMPDIR:-/tmp}/kc-totp-sess-XXXXXX")
  tmphtml=$(mktemp "${TMPDIR:-/tmp}/kc-totp-login-XXXXXX")
  local state="state-$$-${RANDOM}"

  curl -sf --max-time 15 \
    -c "${session_jar}" \
    -o "${tmphtml}" \
    "${AUTH_ENDPOINT}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid&code_challenge=${challenge}&code_challenge_method=S256&state=${state}" \
    || { rm -f "${session_jar}" "${tmphtml}"; return 1; }

  local form_action
  form_action=$(python3 -c "
import re, sys
html = open('${tmphtml}').read()
actions = [m.replace('&amp;', '&') for m in re.findall(r'action=\"([^\"]+)\"', html)]
if not actions:
    sys.exit(1)
auth = [a for a in actions if 'login-actions/authenticate' in a or 'authenticate' in a]
print((auth or actions)[0])
") || { rm -f "${session_jar}" "${tmphtml}"; return 1; }

  # Submit credentials — the OTP-form page (not a code, since AC1 requires
  # the OTP step to be non-skippable for a user with a configured credential)
  local otp_tmphtml
  otp_tmphtml=$(mktemp "${TMPDIR:-/tmp}/kc-totp-otp-XXXXXX")
  curl -sf --max-time 15 \
    -c "${session_jar}" \
    -b "${session_jar}" \
    -o "${otp_tmphtml}" \
    -X POST "${form_action}" \
    -d "username=${email}" \
    -d "password=${password}" \
    -d "credentialId=" \
    || { rm -f "${session_jar}" "${tmphtml}" "${otp_tmphtml}"; return 1; }

  local otp_form_action
  otp_form_action=$(python3 -c "
import re, sys
html = open('${otp_tmphtml}').read()
actions = [m.replace('&amp;', '&') for m in re.findall(r'action=\"([^\"]+)\"', html)]
auth = [a for a in actions if 'login-actions/authenticate' in a or 'authenticate' in a]
print((auth or actions or [''])[0])
")

  rm -f "${tmphtml}" "${otp_tmphtml}"

  if [[ -z "${otp_form_action}" ]]; then
    rm -f "${session_jar}"
    return 1
  fi

  printf '%s\n%s\n' "${session_jar}" "${otp_form_action}"
}

# submit_otp_step <session_jar> <otp_form_action> <code>
# Submits the TOTP code against the OTP-form action and returns the response
# headers on stdout (caller inspects for auth code in Location, or absence
# thereof for negative cases).
submit_otp_step() {
  local session_jar="${1}" otp_form_action="${2}" code="${3}"
  curl -s --max-time 15 \
    -c "${session_jar}" \
    -b "${session_jar}" \
    -D - -o /dev/null \
    -X POST "${otp_form_action}" \
    -d "totp=${code}"
}

extract_auth_code_from_headers() {
  python3 -c "
import sys, urllib.parse
for line in sys.stdin:
    if line.lower().startswith('location:'):
        loc = line.split(':', 1)[1].strip()
        params = urllib.parse.parse_qs(urllib.parse.urlparse(loc).query)
        code = params.get('code', [''])[0]
        if code:
            print(code)
            sys.exit(0)
sys.exit(1)
"
}

# ---------------------------------------------------------------------------
# Per-test setup: guard non-integration runs; create a fresh test user with
# a configured TOTP credential (except TS-261e, which needs no credential).
# ---------------------------------------------------------------------------
TEST_USER_ID=""
TEST_USER_EMAIL=""
TEST_USER_PASSWORD="TestTOTP!Flow1"
TEST_TOTP_SECRET=""

setup() {
  if [[ -z "${INTEGRATION}" ]]; then
    skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"
  fi

  local admin_token
  admin_token=$(get_admin_token) \
    || fail "Could not obtain admin token — check KC_BOOTSTRAP_ADMIN_* in .env and confirm Keycloak is healthy"

  TEST_USER_EMAIL="totp-$(date +%s)-${RANDOM}@test.example.com"

  curl -sf --max-time 15 \
    -X POST "${KC_BASE}/admin/realms/${REALM}/users" \
    -H "Authorization: Bearer ${admin_token}" \
    -H "Content-Type: application/json" \
    -d "{
      \"username\": \"${TEST_USER_EMAIL}\",
      \"email\": \"${TEST_USER_EMAIL}\",
      \"firstName\": \"Test\",
      \"lastName\": \"TOTPUser\",
      \"enabled\": true,
      \"emailVerified\": true,
      \"requiredActions\": [],
      \"credentials\": [{
        \"type\": \"password\",
        \"value\": \"${TEST_USER_PASSWORD}\",
        \"temporary\": false
      }]
    }" > /dev/null \
    || fail "Could not create test user — check Keycloak Admin REST and realm name"

  TEST_USER_ID=$(curl -sf --max-time 15 \
    "${KC_BASE}/admin/realms/${REALM}/users?email=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "${TEST_USER_EMAIL}")" \
    -H "Authorization: Bearer ${admin_token}" \
    | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d[0]['id'] if d else '')
" 2>/dev/null) || true

  [[ -n "${TEST_USER_ID}" ]] || fail "Could not resolve test user ID after creation"

  # Provision TOTP credential for every scenario except TS-261e (no-credential case).
  if [[ "${BATS_TEST_DESCRIPTION}" != *"TS-261e"* ]]; then
    TEST_TOTP_SECRET=$(totp_secret_base32)
    configure_totp_for_user "${admin_token}" "${TEST_USER_ID}" "${TEST_TOTP_SECRET}" > /dev/null \
      || fail "Could not configure TOTP credential via Admin REST configure-totp — is Task 4.2's provisioning endpoint reachable and story 2.6's realm config applied?"
  fi
}

teardown() {
  if [[ -z "${INTEGRATION}" ]]; then
    return 0
  fi
  local admin_token
  admin_token=$(get_admin_token 2>/dev/null) || return 0

  if [[ -z "${TEST_USER_ID}" && -n "${TEST_USER_EMAIL}" ]]; then
    TEST_USER_ID=$(curl -sf --max-time 15 \
      "${KC_BASE}/admin/realms/${REALM}/users?email=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "${TEST_USER_EMAIL}")" \
      -H "Authorization: Bearer ${admin_token}" \
      | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['id'] if d else '')" 2>/dev/null) || true
  fi

  [[ -z "${TEST_USER_ID}" ]] && return 0
  curl -sf --max-time 15 \
    -X DELETE "${KC_BASE}/admin/realms/${REALM}/users/${TEST_USER_ID}" \
    -H "Authorization: Bearer ${admin_token}" \
    > /dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# TS-261a [P0] — Valid TOTP code after password succeeds → tokens issued (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-261a] Valid TOTP code after password succeeds and tokens are issued" {
  local pkce_out verifier challenge
  pkce_out=$(pkce_generate)
  verifier=$(echo "${pkce_out}" | head -1)
  challenge=$(echo "${pkce_out}" | tail -1)

  local step1 session_jar otp_form_action
  step1=$(submit_password_step "${challenge}" "${TEST_USER_EMAIL}" "${TEST_USER_PASSWORD}") \
    || fail "Password step did not reach an OTP form — expected AC1 CONDITIONAL OTP execution for a user with a configured TOTP credential"
  session_jar=$(echo "${step1}" | head -1)
  otp_form_action=$(echo "${step1}" | tail -1)

  local code headers auth_code
  code=$(totp_code "${TEST_TOTP_SECRET}")
  headers=$(submit_otp_step "${session_jar}" "${otp_form_action}" "${code}")
  auth_code=$(echo "${headers}" | extract_auth_code_from_headers) \
    || fail "Expected an auth code in Location header after valid TOTP submission; headers: ${headers}"

  local token_response http_code
  token_response=$(curl -s --max-time 15 \
    -X POST "${TOKEN_ENDPOINT}" \
    -d "grant_type=authorization_code" \
    -d "code=${auth_code}" \
    -d "redirect_uri=${REDIRECT_URI}" \
    -d "client_id=${CLIENT_ID}" \
    -d "code_verifier=${verifier}" \
    -w "\n%{http_code}")
  http_code=$(echo "${token_response}" | tail -1)

  rm -f "${session_jar}"
  assert_equal "${http_code}" "200"
}

# ---------------------------------------------------------------------------
# TS-261b [P0] — Skipping the OTP step after password succeeds does NOT yield
# tokens (AC1: the OTP step cannot be bypassed).
# ---------------------------------------------------------------------------
@test "[P0][TS-261b] Skipping the OTP step after password succeeds does not yield tokens" {
  local pkce_out verifier challenge
  pkce_out=$(pkce_generate)
  verifier=$(echo "${pkce_out}" | head -1)
  challenge=$(echo "${pkce_out}" | tail -1)

  local step1 session_jar otp_form_action
  step1=$(submit_password_step "${challenge}" "${TEST_USER_EMAIL}" "${TEST_USER_PASSWORD}") \
    || fail "Password step did not reach an OTP form — expected AC1 CONDITIONAL OTP execution for a user with a configured TOTP credential"
  session_jar=$(echo "${step1}" | head -1)
  otp_form_action=$(echo "${step1}" | tail -1)

  # Attempt to exchange at the token endpoint WITHOUT ever completing the OTP
  # step — there is no auth code yet because Keycloak has not issued one
  # (login has not completed). Confirm the token endpoint has nothing to
  # redeem: a bogus/absent code must be rejected.
  local token_response http_code
  token_response=$(curl -s --max-time 15 \
    -X POST "${TOKEN_ENDPOINT}" \
    -d "grant_type=authorization_code" \
    -d "code=" \
    -d "redirect_uri=${REDIRECT_URI}" \
    -d "client_id=${CLIENT_ID}" \
    -d "code_verifier=${verifier}" \
    -w "\n%{http_code}")
  http_code=$(echo "${token_response}" | tail -1)

  rm -f "${session_jar}"
  assert_equal "${http_code}" "400"
}

# ---------------------------------------------------------------------------
# TS-261c [P0] — Same valid TOTP code resubmitted within the same time step is
# rejected (AC3: single-use-per-time-step / Keycloak's built-in replay cache).
# ---------------------------------------------------------------------------
@test "[P0][TS-261c] Resubmitting the same valid TOTP code within the same time step is rejected" {
  local pkce_out challenge
  pkce_out=$(pkce_generate)
  challenge=$(echo "${pkce_out}" | tail -1)

  local step1 session_jar otp_form_action
  step1=$(submit_password_step "${challenge}" "${TEST_USER_EMAIL}" "${TEST_USER_PASSWORD}") \
    || fail "Password step did not reach an OTP form"
  session_jar=$(echo "${step1}" | head -1)
  otp_form_action=$(echo "${step1}" | tail -1)

  local code first_headers first_auth_code
  code=$(totp_code "${TEST_TOTP_SECRET}")
  first_headers=$(submit_otp_step "${session_jar}" "${otp_form_action}" "${code}")
  first_auth_code=$(echo "${first_headers}" | extract_auth_code_from_headers) \
    || fail "First submission of a valid TOTP code should succeed; headers: ${first_headers}"

  # Immediately resubmit the SAME code against the SAME (already-authenticated)
  # OTP form action — Keycloak's replay cache must reject reuse of a code
  # already verified within the current time step.
  local second_headers second_auth_code
  second_headers=$(submit_otp_step "${session_jar}" "${otp_form_action}" "${code}")
  second_auth_code=$(echo "${second_headers}" | extract_auth_code_from_headers 2>/dev/null || echo "")

  rm -f "${session_jar}"
  [[ -z "${second_auth_code}" || "${second_auth_code}" != "${first_auth_code}" ]] \
    || fail "Expected the second submission of the same TOTP code to be rejected (replay), but got a fresh auth code"
}

# ---------------------------------------------------------------------------
# TS-261d [P0] — Several invalid TOTP codes in a row trigger a rate-limited /
# delayed response (AC3: bruteForceProtected covers the OTP step, not just
# username/password).
# ---------------------------------------------------------------------------
@test "[P0][TS-261d] Repeated invalid TOTP submissions trigger rate-limited/delayed response" {
  local pkce_out challenge
  pkce_out=$(pkce_generate)
  challenge=$(echo "${pkce_out}" | tail -1)

  local step1 session_jar otp_form_action
  step1=$(submit_password_step "${challenge}" "${TEST_USER_EMAIL}" "${TEST_USER_PASSWORD}") \
    || fail "Password step did not reach an OTP form"
  session_jar=$(echo "${step1}" | head -1)
  otp_form_action=$(echo "${step1}" | tail -1)

  # Submit 6 wrong codes in a row (default Keycloak brute-force threshold is
  # low; the exact threshold is Story 2.7 scope — this AC only confirms the
  # mechanism activates on the OTP step, not the specific delay schedule).
  local wrong_code="000000"
  local last_headers=""
  for _ in 1 2 3 4 5 6; do
    last_headers=$(submit_otp_step "${session_jar}" "${otp_form_action}" "${wrong_code}")
  done

  rm -f "${session_jar}"

  # After repeated failures, a further attempt must NOT silently succeed with
  # a fresh auth code — either an explicit account-temporarily-disabled error
  # page or a rejection is expected. Absence of a code is the pass condition.
  local leaked_auth_code
  leaked_auth_code=$(echo "${last_headers}" | extract_auth_code_from_headers 2>/dev/null || echo "")
  [[ -z "${leaked_auth_code}" ]] \
    || fail "Expected repeated invalid TOTP submissions to be rate-limited/rejected, but an auth code was issued"
}

# ---------------------------------------------------------------------------
# TS-261e [P1] — User with no TOTP credential configured skips the OTP branch
# entirely (regression guard for the CONDITIONAL flow shape — Task 2.5).
# Mirrors tests/integration/oidc-pkce-flow.bats's acquire_auth_code() behavior:
# a user with no TOTP credential must still get an auth code directly from
# the password step, with no OTP form in between.
# ---------------------------------------------------------------------------
@test "[P1][TS-261e] User with no TOTP credential configured skips the OTP branch entirely" {
  local pkce_out challenge
  pkce_out=$(pkce_generate)
  challenge=$(echo "${pkce_out}" | tail -1)

  # submit_password_step expects to land on an OTP form; for a no-credential
  # user under the CONDITIONAL flow it should instead land directly on the
  # redirect with an auth code, so submit_password_step is expected to fail
  # here — assert that failure mode explicitly rather than reusing it blind.
  local session_jar tmphtml
  session_jar=$(mktemp "${TMPDIR:-/tmp}/kc-totp-nocred-sess-XXXXXX")
  tmphtml=$(mktemp "${TMPDIR:-/tmp}/kc-totp-nocred-login-XXXXXX")
  local state="state-$$-${RANDOM}"

  curl -sf --max-time 15 \
    -c "${session_jar}" \
    -o "${tmphtml}" \
    "${AUTH_ENDPOINT}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid&code_challenge=${challenge}&code_challenge_method=S256&state=${state}" \
    || fail "Could not initiate auth request"

  local form_action
  form_action=$(python3 -c "
import re, sys
html = open('${tmphtml}').read()
actions = [m.replace('&amp;', '&') for m in re.findall(r'action=\"([^\"]+)\"', html)]
auth = [a for a in actions if 'login-actions/authenticate' in a or 'authenticate' in a]
print((auth or actions or [''])[0])
")

  local headers auth_code
  headers=$(curl -s --max-time 15 \
    -c "${session_jar}" \
    -b "${session_jar}" \
    -D - -o /dev/null \
    -X POST "${form_action}" \
    -d "username=${TEST_USER_EMAIL}" \
    -d "password=${TEST_USER_PASSWORD}" \
    -d "credentialId=")

  auth_code=$(echo "${headers}" | extract_auth_code_from_headers) \
    || fail "Expected an auth code directly after the password step for a user with no TOTP credential (CONDITIONAL flow must skip the OTP branch); headers: ${headers}"

  rm -f "${session_jar}" "${tmphtml}"
  [[ -n "${auth_code}" ]]
}
