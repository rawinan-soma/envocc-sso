#!/usr/bin/env bats
# tests/integration/oidc-pkce-flow.bats
# ATDD integration tests — Story 2.2: OIDC Authorization Code + PKCE Login (Hosted Credentials)
#
# AC1: Auth Code + PKCE only; Implicit and ROPC unavailable (FR1, FR3)
# AC2: Credentials submitted to IdP only; RP receives only auth code (FR2)
# AC3: Exact-match redirect URI enforcement (FR4)
# AC4: Auth code single-use, short-lived (≤60s), PKCE-bound, replay-detected (FR47)
#
# Test scenarios covered:
#   TS-220a [P0] Implicit grant (response_type=token) rejected (AC1)
#   TS-220b [P0] ROPC (grant_type=password) rejected with HTTP 400 (AC1)
#   TS-220b2 [P0] ROPC rejection body contains error=unauthorized_client (AC1)
#   TS-220c [P0] Auth request without code_challenge rejected with error=invalid_request (AC1)
#   TS-220d [P1] Redirect URI with extra path rejected — HTTP 400 (AC3)
#   TS-220e [P1] Wrong-host redirect URI rejected — HTTP 400 (AC3)
#   TS-220f [P0] Auth code replay: second exchange returns 400 invalid_grant (AC4)
#   TS-220g [P0] Wrong code_verifier rejected with 400 invalid_grant (AC4)
#
# IMPORTANT: All tests require a live Keycloak stack with Story 2.2 config applied:
#   - keycloak/realm-export.json updated (accessCodeLifespan: 60, test-oidc-client registered)
#   - docker compose down -v && docker compose up --build (fresh import)
#
# To run: INTEGRATION=1 bats tests/integration/oidc-pkce-flow.bats
# Pre-requisites:
#   1. docker compose down -v && docker compose up --build  (Story 2.2 realm config)
#   2. .env with KC_BOOTSTRAP_ADMIN_USERNAME / KC_BOOTSTRAP_ADMIN_PASSWORD set
#   3. BATS_LIB_PATH=$(pwd)/tests/lib or bats-support/bats-assert installed system-wide
#
# Red-phase scaffolds: each @test starts with skip "RED PHASE — ..."
# Activate by removing the skip line when the corresponding task is implemented.

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

# ---------------------------------------------------------------------------
# PKCE helpers
# Generate code_verifier (random, URL-safe base64) + code_challenge (S256)
# Outputs two lines: CODE_VERIFIER then CODE_CHALLENGE
# ---------------------------------------------------------------------------
pkce_generate() {
  local verifier challenge
  verifier=$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')
  challenge=$(printf '%s' "${verifier}" | openssl dgst -sha256 -binary | openssl base64 | tr '+/' '-_' | tr -d '=\n')
  printf '%s\n%s\n' "${verifier}" "${challenge}"
}

# ---------------------------------------------------------------------------
# Auth code acquisition helper
# Performs the full PKCE login flow to obtain a real auth code.
# Usage: acquire_auth_code <verifier> <challenge> <user_email> <user_password>
# Outputs the auth code to stdout; exits non-zero on failure.
# ---------------------------------------------------------------------------
acquire_auth_code() {
  local verifier="${1}" challenge="${2}" email="${3}" password="${4}"
  local session_jar state tmphtml
  state="state-$$-${RANDOM}"
  session_jar=$(mktemp /tmp/kc-sess-XXXXXX.jar)
  tmphtml=$(mktemp /tmp/kc-login-XXXXXX.html)

  # Step 1: Initiate auth flow → receive login form
  curl -sf --max-time 15 \
    -c "${session_jar}" \
    -o "${tmphtml}" \
    "${AUTH_ENDPOINT}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid&code_challenge=${challenge}&code_challenge_method=S256&state=${state}" \
    || { rm -f "${session_jar}" "${tmphtml}"; return 1; }

  # Extract form action URL from login page
  local form_action
  form_action=$(python3 -c "
import re, sys
html = open('${tmphtml}').read()
m = re.search(r'action=\"([^\"]+)\"', html)
if m:
    print(m.group(1).replace('&amp;', '&'))
else:
    sys.exit(1)
") || { rm -f "${session_jar}" "${tmphtml}"; return 1; }

  # Step 2: Submit credentials; follow redirect to get auth code in Location
  local code_headers
  code_headers=$(curl -sf --max-time 15 \
    -c "${session_jar}" \
    -b "${session_jar}" \
    -D - -o /dev/null \
    -X POST "${form_action}" \
    -d "username=${email}" \
    -d "password=${password}" \
    -d "credentialId=") || true

  rm -f "${session_jar}" "${tmphtml}"

  # Extract code from Location header
  echo "${code_headers}" | python3 -c "
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
# Suite-level setup
# ---------------------------------------------------------------------------
setup_suite() {
  env_setup
}

# ---------------------------------------------------------------------------
# Per-test setup: guard non-integration runs; create a fresh test user
# ---------------------------------------------------------------------------
TEST_USER_ID=""
TEST_USER_EMAIL=""
TEST_USER_PASSWORD="TestPKCE!Flow1"

setup() {
  if [[ -z "${INTEGRATION}" ]]; then
    skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"
  fi

  # Obtain admin token
  local admin_token
  admin_token=$(get_admin_token) \
    || fail "Could not obtain admin token — check KC_BOOTSTRAP_ADMIN_* in .env and confirm Keycloak is healthy"

  # Create a unique test user for this test
  TEST_USER_EMAIL="pkce-$(date +%s)-${RANDOM}@test.example.com"

  curl -sf --max-time 15 \
    -X POST "${KC_BASE}/admin/realms/${REALM}/users" \
    -H "Authorization: Bearer ${admin_token}" \
    -H "Content-Type: application/json" \
    -d "{
      \"username\": \"${TEST_USER_EMAIL}\",
      \"email\": \"${TEST_USER_EMAIL}\",
      \"enabled\": true,
      \"emailVerified\": true,
      \"credentials\": [{
        \"type\": \"password\",
        \"value\": \"${TEST_USER_PASSWORD}\",
        \"temporary\": false
      }]
    }" > /dev/null \
    || fail "Could not create test user — check Keycloak Admin REST and realm name"

  # Retrieve the user ID for teardown
  TEST_USER_ID=$(curl -sf --max-time 15 \
    "${KC_BASE}/admin/realms/${REALM}/users?email=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${TEST_USER_EMAIL}'))")" \
    -H "Authorization: Bearer ${admin_token}" \
    | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d[0]['id'] if d else '')
" 2>/dev/null) || true
}

# ---------------------------------------------------------------------------
# Per-test teardown: delete test user
# ---------------------------------------------------------------------------
teardown() {
  if [[ -z "${INTEGRATION}" || -z "${TEST_USER_ID}" ]]; then
    return 0
  fi
  local admin_token
  admin_token=$(get_admin_token 2>/dev/null) || return 0
  curl -sf --max-time 15 \
    -X DELETE "${KC_BASE}/admin/realms/${REALM}/users/${TEST_USER_ID}" \
    -H "Authorization: Bearer ${admin_token}" \
    > /dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# TS-220a [P0] — Implicit grant (response_type=token) rejected (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-220a] Implicit grant (response_type=token) is rejected by envocc realm" {
  skip "RED PHASE — activate when Task 1 (realm settings) and Task 2 (test-oidc-client: implicitFlowEnabled: false) are implemented"
  # Keycloak with implicitFlowEnabled: false either returns HTTP 400 directly
  # or 302-redirects with error= in the Location header.
  local response_headers
  response_headers=$(curl --max-time 15 \
    -D - -o /dev/null \
    "${AUTH_ENDPOINT}?response_type=token&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid" \
    2>/dev/null) || true

  local http_code location_header
  http_code=$(echo "${response_headers}" | grep -i "^HTTP/" | tail -1 | awk '{print $2}' | tr -d '\r')
  location_header=$(echo "${response_headers}" | grep -i "^location:" | head -1)

  # Accept either: direct HTTP 400, or 302 redirect with error= in Location
  if [[ "${http_code}" == "400" ]]; then
    : # pass — Keycloak rejected implicit grant directly
  elif echo "${location_header}" | grep -qi "error="; then
    : # pass — Keycloak redirected with error
  else
    fail "Expected HTTP 400 or redirect with error= for Implicit grant, got HTTP ${http_code}; Location: ${location_header}"
  fi
}

# ---------------------------------------------------------------------------
# TS-220b [P0] — ROPC (grant_type=password) rejected with HTTP 400 (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-220b] ROPC (grant_type=password) is rejected with HTTP 400" {
  skip "RED PHASE — activate when Task 2.4 (directAccessGrantsEnabled: false on test-oidc-client) is implemented"
  run curl --max-time 15 \
    -X POST "${TOKEN_ENDPOINT}" \
    -d "grant_type=password" \
    -d "username=${TEST_USER_EMAIL}" \
    -d "password=${TEST_USER_PASSWORD}" \
    -d "client_id=${CLIENT_ID}" \
    -d "scope=openid" \
    -o /dev/null \
    -w "%{http_code}" \
    -s
  assert_output "400"
}

# ---------------------------------------------------------------------------
# TS-220b2 [P0] — ROPC rejection body contains error=unauthorized_client (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-220b2] ROPC rejection body contains error=unauthorized_client" {
  skip "RED PHASE — activate when Task 2.4 (directAccessGrantsEnabled: false on test-oidc-client) is implemented"
  local body
  body=$(curl -s --max-time 15 \
    -X POST "${TOKEN_ENDPOINT}" \
    -d "grant_type=password" \
    -d "username=${TEST_USER_EMAIL}" \
    -d "password=${TEST_USER_PASSWORD}" \
    -d "client_id=${CLIENT_ID}" \
    -d "scope=openid")

  local error
  error=$(echo "${body}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error',''))" 2>/dev/null || echo "parse_error")
  [[ "${error}" == "unauthorized_client" ]] \
    || fail "Expected error=unauthorized_client in ROPC rejection, got: ${body}"
}

# ---------------------------------------------------------------------------
# TS-220c [P0] — Auth request without code_challenge rejected (AC1 / PKCE)
# ---------------------------------------------------------------------------
@test "[P0][TS-220c] Auth request without code_challenge is rejected (error=invalid_request)" {
  skip "RED PHASE — activate when Task 2.6 (pkce.code.challenge.method: S256 on test-oidc-client) is implemented"
  # Include a valid redirect_uri so Keycloak rejects for missing PKCE, not bad redirect
  local response_headers
  response_headers=$(curl --max-time 15 \
    -D - -o /dev/null \
    "${AUTH_ENDPOINT}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid" \
    -s) || true

  local location_header
  location_header=$(echo "${response_headers}" | grep -i "^location:" | head -1)

  echo "${location_header}" | grep -qi "error=invalid_request" \
    || fail "Expected redirect with error=invalid_request for missing code_challenge; Location: ${location_header}"
}

# ---------------------------------------------------------------------------
# TS-220d [P1] — Redirect URI with extra path rejected (AC3)
# ---------------------------------------------------------------------------
@test "[P1][TS-220d] Auth request with extra-path redirect URI is rejected with HTTP 400" {
  skip "RED PHASE — activate when Task 2.7 (redirectUris exact-match: http://localhost:8888/callback) is implemented"
  local pkce_out verifier challenge
  pkce_out=$(pkce_generate)
  verifier=$(echo "${pkce_out}" | head -1)
  challenge=$(echo "${pkce_out}" | tail -1)

  # extra path appended to the registered redirect_uri
  run curl --max-time 15 \
    "${AUTH_ENDPOINT}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}/extra&scope=openid&code_challenge=${challenge}&code_challenge_method=S256" \
    -o /dev/null \
    -w "%{http_code}" \
    -s
  # Keycloak returns HTTP 400 for unregistered redirect_uri (does not redirect)
  assert_output "400"
}

# ---------------------------------------------------------------------------
# TS-220e [P1] — Wrong-host redirect URI rejected (AC3)
# ---------------------------------------------------------------------------
@test "[P1][TS-220e] Auth request with wrong-host redirect URI is rejected with HTTP 400" {
  skip "RED PHASE — activate when Task 2.7 (redirectUris exact-match: http://localhost:8888/callback) is implemented"
  local pkce_out verifier challenge
  pkce_out=$(pkce_generate)
  verifier=$(echo "${pkce_out}" | head -1)
  challenge=$(echo "${pkce_out}" | tail -1)

  run curl --max-time 15 \
    "${AUTH_ENDPOINT}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=http://evil.example.com/callback&scope=openid&code_challenge=${challenge}&code_challenge_method=S256" \
    -o /dev/null \
    -w "%{http_code}" \
    -s
  assert_output "400"
}

# ---------------------------------------------------------------------------
# TS-220f [P0] — Auth code replay: second exchange returns 400 invalid_grant (AC4)
# ---------------------------------------------------------------------------
@test "[P0][TS-220f] Auth code replay: second use of same code returns 400 invalid_grant" {
  skip "RED PHASE — activate when Tasks 1+2 (realm config + test-oidc-client registered + PKCE S256) are fully implemented"
  # Generate PKCE pair
  local pkce_out verifier challenge
  pkce_out=$(pkce_generate)
  verifier=$(echo "${pkce_out}" | head -1)
  challenge=$(echo "${pkce_out}" | tail -1)

  # Acquire a real auth code via the full login flow
  local auth_code
  auth_code=$(acquire_auth_code "${verifier}" "${challenge}" "${TEST_USER_EMAIL}" "${TEST_USER_PASSWORD}") \
    || fail "Could not acquire auth code — confirm test-oidc-client is registered and stack is healthy"

  [[ -n "${auth_code}" ]] || fail "Auth code was empty after login flow"

  # First exchange — must succeed (HTTP 200)
  local first_status
  first_status=$(curl -s --max-time 15 \
    -X POST "${TOKEN_ENDPOINT}" \
    -d "grant_type=authorization_code" \
    -d "code=${auth_code}" \
    -d "client_id=${CLIENT_ID}" \
    -d "redirect_uri=${REDIRECT_URI}" \
    -d "code_verifier=${verifier}" \
    -o /dev/null \
    -w "%{http_code}")
  [[ "${first_status}" == "200" ]] \
    || fail "First code exchange failed (expected 200, got ${first_status})"

  # Replay — must fail with 400 invalid_grant
  local replay_body replay_error
  replay_body=$(curl -s --max-time 15 \
    -X POST "${TOKEN_ENDPOINT}" \
    -d "grant_type=authorization_code" \
    -d "code=${auth_code}" \
    -d "client_id=${CLIENT_ID}" \
    -d "redirect_uri=${REDIRECT_URI}" \
    -d "code_verifier=${verifier}")

  replay_error=$(echo "${replay_body}" | python3 -c \
    "import json,sys; print(json.load(sys.stdin).get('error',''))" 2>/dev/null \
    || echo "parse_error")

  [[ "${replay_error}" == "invalid_grant" ]] \
    || fail "Expected error=invalid_grant on code replay, got: ${replay_body}"
}

# ---------------------------------------------------------------------------
# TS-220g [P0] — Wrong code_verifier rejected with 400 invalid_grant (AC4)
# ---------------------------------------------------------------------------
@test "[P0][TS-220g] Wrong code_verifier is rejected with 400 invalid_grant" {
  skip "RED PHASE — activate when Tasks 1+2 (realm config + test-oidc-client registered + PKCE S256) are fully implemented"
  # Generate PKCE pair for login
  local pkce_out verifier challenge
  pkce_out=$(pkce_generate)
  verifier=$(echo "${pkce_out}" | head -1)
  challenge=$(echo "${pkce_out}" | tail -1)

  # Acquire a real auth code
  local auth_code
  auth_code=$(acquire_auth_code "${verifier}" "${challenge}" "${TEST_USER_EMAIL}" "${TEST_USER_PASSWORD}") \
    || fail "Could not acquire auth code — confirm test-oidc-client is registered and stack is healthy"

  [[ -n "${auth_code}" ]] || fail "Auth code was empty after login flow"

  # Generate a DIFFERENT verifier (does not match the challenge used in auth)
  local wrong_verifier
  wrong_verifier=$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')

  # Exchange with wrong verifier — must fail with invalid_grant
  local body error
  body=$(curl -s --max-time 15 \
    -X POST "${TOKEN_ENDPOINT}" \
    -d "grant_type=authorization_code" \
    -d "code=${auth_code}" \
    -d "client_id=${CLIENT_ID}" \
    -d "redirect_uri=${REDIRECT_URI}" \
    -d "code_verifier=${wrong_verifier}")

  error=$(echo "${body}" | python3 -c \
    "import json,sys; print(json.load(sys.stdin).get('error',''))" 2>/dev/null \
    || echo "parse_error")

  [[ "${error}" == "invalid_grant" ]] \
    || fail "Expected error=invalid_grant for wrong code_verifier, got: ${body}"
}
