#!/usr/bin/env bats
# tests/integration/brute-force-lockout.bats
# ATDD integration tests — Story 2.7: Brute-force protection & enumeration-resistant
# responses
#
# AC1: Per-account progressive delays (Keycloak native brute-force detection) —
#      an account is NOT locked before failureFactor failed attempts, and IS
#      locked once failureFactor is reached.
# AC2: Identical, generic response for any login failure — enumeration-resistant
#      (FR20, UX-DR9) — a locked account and a nonexistent-user attempt must be
#      indistinguishable from a plain wrong-password attempt.
#
# Login path used: the browser-flow POST to
#   /realms/envocc/login-actions/authenticate
# rather than ROPC. Per story Task 6 / Subtask 6.0: `test-ropc-client` does not
# yet exist in keycloak/realm-export.json (only `test-oidc-client`, which has
# directAccessGrantsEnabled: false). Using the browser-flow POST avoids taking
# a dependency on that unresolved prerequisite and exercises the same
# credential-check + brute-force pipeline any real login goes through.
#
# The browser flow requires first GETting the login form (to obtain the
# execution-scoped form action URL + AUTH_SESSION_ID cookie), then POSTing
# username/password to that action URL.
#
# Test scenarios covered:
#   TS-273a [P0] account is NOT locked before failureFactor failed attempts
#   TS-273b [P0] account IS locked after failureFactor failed attempts
#   TS-273c [P1] locked-account response is identical to wrong-password response
#   TS-273d [P1] nonexistent-user response is identical to wrong-password response
#
# IMPORTANT: All tests in this file require a live Keycloak stack.
# They are skipped unless the INTEGRATION environment variable is set.
# To run: INTEGRATION=1 bats tests/integration/brute-force-lockout.bats
# Pre-requisites:
#   1. docker compose up --build (stack healthy)
#      NOTE: realm-export.json is imported with IGNORE_EXISTING — if a realm
#      already exists in the Postgres volume from a prior run, an updated
#      failureFactor will NOT be picked up. Use `docker compose down -v` then
#      `up --build -d` for a clean re-import before running these tests.
#   2. BATS_LIB_PATH=$(pwd)/tests/lib bats tests/integration/brute-force-lockout.bats
#
# TDD Phase: RED — TS-273a/b/c fail until keycloak/realm-export.json's
# failureFactor is tuned to 5 (Task 1) and a clean realm re-import has picked
# up the new value (Task 7 manual step). TS-273d exercises already-shipped
# story 2.5 enumeration-safe messaging and is expected to pass once the stack
# is reachable.

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Per-test cleanup state — each test stores its created user UUID here
# immediately after creation. teardown() resets brute-force state and
# deletes the user so runs don't pollute each other (bats teardown runs even
# on assertion failure, per Task 6, Subtask 6.3).
# ---------------------------------------------------------------------------
_BF_USER_ID=""
_BF_USERNAME=""

# realm-export.json failureFactor under test (Task 1.1 target value — kept as
# a single source of truth in this file so the test doesn't silently pass
# against a stale/placeholder value without anyone noticing the constant).
FAILURE_FACTOR=5

# Minimum delay (seconds) between consecutive failed-login attempts against
# the SAME user, used only in loops that are counting failures toward
# FAILURE_FACTOR. keycloak/realm-export.json sets quickLoginCheckMilliSeconds:
# 1000 — per keycloak/REALM-EXPORT-NOTES.md (Story 2.7), attempts less than
# 1000ms apart are treated as scripted "quick" retries and immediately incur
# minimumQuickLoginWaitSeconds (60s), independent of the failureFactor count.
# Firing curl requests back-to-back with no delay would trip that separate
# quick-retry guard well before failureFactor attempts are reached, making
# TS-273a/b/c fail for a reason unrelated to what they're testing. Must be
# strictly greater than quickLoginCheckMilliSeconds/1000.
QUICK_LOGIN_GUARD_SECONDS="1.1"

# PKCE code_challenge sent on every browser-flow authorization GET.
# test-oidc-client (keycloak/realm-export.json) enforces PKCE S256
# ("pkce.code.challenge.method": "S256") — a request without a matching
# code_challenge is rejected by Keycloak before the login form renders (no
# action="..." to scrape). The corresponding code_verifier is never used:
# this suite only needs the login FORM to render, it never completes a code
# exchange. Computed once here (rather than per _bf_browser_login call,
# which is invoked ~20 times across this file) so the suite doesn't pay for
# a fresh python3 subprocess + SHA-256 computation dozens of times for a
# verifier that is immediately discarded — one valid S256 pair is reused for
# every login attempt in this file.
BF_CODE_CHALLENGE=$(python3 -c "
import base64, hashlib, secrets
verifier = base64.urlsafe_b64encode(secrets.token_bytes(48)).rstrip(b'=').decode()
print(base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b'=').decode())
")

setup() {
  if [[ -z "${INTEGRATION}" ]]; then
    skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"
  fi
  _BF_USER_ID=""
  _BF_USERNAME=""
}

# ---------------------------------------------------------------------------
# teardown: reset brute-force failure count and delete the test user.
# Uses a bats teardown() function (not inline end-of-test cleanup) so this
# still runs if an assertion fails mid-test (Task 6, Subtask 6.3).
# ---------------------------------------------------------------------------
teardown() {
  if [[ -n "${_BF_USER_ID}" ]]; then
    local token
    token=$(get_admin_token 2>/dev/null) || true
    if [[ -n "${token}" ]]; then
      # DELETE .../attack-detection/brute-force/users/{id} resets brute-force
      # state — POST .../reset-password does NOT reset it (per Dev Notes).
      curl -sf -X DELETE \
        -H "Authorization: Bearer ${token}" \
        "http://localhost:8080/admin/realms/envocc/attack-detection/brute-force/users/${_BF_USER_ID}" \
        2>/dev/null || true
      curl -sf -X DELETE \
        -H "Authorization: Bearer ${token}" \
        "http://localhost:8080/admin/realms/envocc/users/${_BF_USER_ID}" \
        2>/dev/null || true
    fi
  fi
}

# ---------------------------------------------------------------------------
# _bf_create_user <username_prefix> <password>
# Creates an enabled, email-verified test user with the given password via
# the Admin REST API. Prints "<user_id> <username>" to stdout.
# Stores the user id in _BF_USER_ID for teardown cleanup.
# ---------------------------------------------------------------------------
_bf_create_user() {
  local prefix="${1}"
  local password="${2}"
  local username
  username="${prefix}-$$-$(date +%s)@envocc.local"

  local token
  token=$(get_admin_token) || { echo "could not obtain admin token" >&2; return 1; }

  local post_loc_file http_status
  post_loc_file=$(mktemp)
  http_status=$(curl -s -o /dev/null -w "%{http_code}" -D "${post_loc_file}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${username}\",\"email\":\"${username}\",\"enabled\":true,\"emailVerified\":true,\"firstName\":\"Test\",\"lastName\":\"BruteForce\"}" \
    "http://localhost:8080/admin/realms/envocc/users")
  if [[ "${http_status}" != "201" ]]; then
    rm -f "${post_loc_file}"
    echo "could not create test user (got HTTP ${http_status})" >&2
    return 1
  fi

  local location user_id
  location=$(grep -i '^location:' "${post_loc_file}" | tail -n 1 | tr -d '\r' | sed -E 's/^[^:]+:[[:space:]]*//')
  rm -f "${post_loc_file}"
  user_id="${location##*/}"
  if [[ -z "${user_id}" ]]; then
    local fallback_resp
    fallback_resp=$(curl -sf --max-time 10 \
      -H "Authorization: Bearer ${token}" \
      "http://localhost:8080/admin/realms/envocc/users?email=${username}&exact=true") || true
    user_id=$(echo "${fallback_resp}" | python3 -c "import json,sys; u=json.load(sys.stdin); print(u[0]['id'] if u else '')" 2>/dev/null || echo "")
  fi
  [[ -n "${user_id}" ]] || { echo "user UUID not found after creation" >&2; return 1; }
  _BF_USER_ID="${user_id}"
  _BF_USERNAME="${username}"

  # Print the id/username as soon as the user exists in Keycloak — BEFORE
  # attempting the password reset below. This function always runs inside a
  # command-substitution subshell (`create_out=$(_bf_create_user ...)`), so
  # the _BF_USER_ID assignment above never reaches the caller's shell; the
  # caller re-derives it by parsing this stdout line instead. If we only
  # echoed at the very end (success-only), a failure in the password-reset
  # step below — after the user already exists server-side — would return 1
  # with no id on stdout, leaving the caller unable to register the user for
  # teardown cleanup and orphaning it in Keycloak.
  echo "${user_id} ${username}"

  local reset_status
  reset_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"password\",\"value\":\"${password}\",\"temporary\":false}" \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}/reset-password")
  [[ "${reset_status}" == "204" ]] || { echo "could not set password (got HTTP ${reset_status})" >&2; return 1; }
}

# ---------------------------------------------------------------------------
# _bf_browser_login <username> <password>
# Performs a browser-flow login attempt: GET the login form to obtain the
# execution-scoped form action + AUTH_SESSION_ID cookie, then POST
# username/password to that action URL. Prints the final HTTP status code
# and response body, separated by a newline, to stdout.
#
# This exercises the same generic-message/timing path a real user's browser
# goes through — required because test-oidc-client / test-ropc-client either
# disable ROPC or do not yet exist (see file header).
# ---------------------------------------------------------------------------
_bf_browser_login() {
  local username="${1}"
  local password="${2}"
  local cookie_jar
  cookie_jar=$(mktemp)

  # Step 1: GET the realm's auth endpoint via test-oidc-client to start a
  # fresh login flow and capture the session cookie + form action URL.
  # redirect_uri MUST exactly match one of test-oidc-client's registered
  # redirectUris (keycloak/realm-export.json — currently only
  # "http://localhost:8888/callback") or Keycloak rejects the request with
  # an error page instead of the login form. The callback target is never
  # actually navigated to (curl does not follow redirects here), so it does
  # not need to resolve to a live listener.
  local login_page
  login_page=$(curl -s --max-time 10 -c "${cookie_jar}" \
    -G "http://localhost:8080/realms/envocc/protocol/openid-connect/auth" \
    --data-urlencode "client_id=test-oidc-client" \
    --data-urlencode "response_type=code" \
    --data-urlencode "scope=openid" \
    --data-urlencode "redirect_uri=http://localhost:8888/callback" \
    --data-urlencode "code_challenge=${BF_CODE_CHALLENGE}" \
    --data-urlencode "code_challenge_method=S256")

  # Extract the login form action URL. Prefer the form that POSTs to
  # Keycloak's login-actions/authenticate endpoint (same approach as
  # tests/integration/oidc-pkce-flow.bats:acquire_auth_code) rather than
  # blindly taking the first action="..." on the page — an earlier
  # unrelated element (locale selector, IdP button) with its own action=
  # attribute would otherwise be silently picked up instead.
  local action_url
  action_url=$(echo "${login_page}" | python3 -c "
import re, sys
html = sys.stdin.read()
actions = [m.replace('&amp;', '&') for m in re.findall(r'action=\"([^\"]+)\"', html)]
auth = [a for a in actions if 'login-actions/authenticate' in a]
print((auth or actions or [''])[0])
")

  if [[ -z "${action_url}" ]]; then
    rm -f "${cookie_jar}"
    echo "000"
    echo "could not resolve login form action URL"
    return 0
  fi

  # Step 2: POST credentials to the resolved action URL, reusing the session cookie.
  local http_status response_body_file response_body
  response_body_file=$(mktemp)
  http_status=$(curl -s -o "${response_body_file}" -w "%{http_code}" --max-time 10 \
    -b "${cookie_jar}" -c "${cookie_jar}" \
    --data-urlencode "username=${username}" \
    --data-urlencode "password=${password}" \
    "${action_url}")
  response_body=$(cat "${response_body_file}")
  rm -f "${cookie_jar}" "${response_body_file}"

  echo "${http_status}"
  echo "${response_body}"
}

# ---------------------------------------------------------------------------
# _bf_extract_error <html_body>
# Extracts Keycloak's rendered generic-error text (span/div with
# kc-feedback-text or alert-error class) from a login-page HTML response.
# Prints the extracted text (best-effort; empty if not found).
# ---------------------------------------------------------------------------
_bf_extract_error() {
  local body="${1}"
  echo "${body}" | python3 -c "
import re, sys
html = sys.stdin.read()
m = re.search(r'kc-feedback-text[^>]*>([^<]*)<', html)
if not m:
    m = re.search(r'alert-error[^>]*>\s*<span[^>]*>([^<]*)<', html, re.S)
print(m.group(1).strip() if m else '')
"
}

# ---------------------------------------------------------------------------
# TS-273a [P0] — account NOT locked before failureFactor failed attempts (AC1)
# RED PHASE: depends on failureFactor=5 having been picked up by a clean
# realm import (Task 1.1 + Task 7 manual re-import step).
# ---------------------------------------------------------------------------
@test "[P0][TS-273a] account is NOT locked before failureFactor failed attempts" {
  local password="Correct!Passw0rd1"
  local create_out create_rc user_id username create_err_file create_err
  create_err_file=$(mktemp)
  create_out=$(_bf_create_user "ts273a" "${password}" 2>"${create_err_file}")
  create_rc=$?
  create_err=$(cat "${create_err_file}")
  rm -f "${create_err_file}"
  user_id=$(echo "${create_out}" | awk '{print $1}')
  username=$(echo "${create_out}" | awk '{print $2}')
  # Register for teardown cleanup as soon as an id is parseable, even if
  # _bf_create_user returned non-zero (e.g. password-reset failed after the
  # user already exists in Keycloak) — see _bf_create_user comment.
  [[ -n "${user_id}" ]] && _BF_USER_ID="${user_id}"
  # create_err surfaces _bf_create_user's stderr diagnostic (e.g. the actual
  # HTTP status of a failed step) — without it, a setup failure only shows
  # the (often empty) stdout capture and loses the real reason.
  [[ "${create_rc}" -eq 0 ]] || fail "setup: ${create_out} ${create_err}"

  # Submit (failureFactor - 1) wrong passwords — must NOT trigger lockout.
  # Paced by QUICK_LOGIN_GUARD_SECONDS (see declaration above) so consecutive
  # failures aren't misclassified as scripted "quick" retries.
  local attempts=$((FAILURE_FACTOR - 1))
  local i status body
  for ((i = 1; i <= attempts; i++)); do
    local result
    result=$(_bf_browser_login "${username}" "WrongPassword${i}!")
    status=$(echo "${result}" | sed -n '1p')
    [[ "${status}" == "200" ]] || fail "attempt ${i}: expected HTTP 200 (re-rendered login form), got ${status}"
    sleep "${QUICK_LOGIN_GUARD_SECONDS}"
  done

  # The next attempt with the CORRECT password must still succeed (not locked).
  local final_result final_status
  final_result=$(_bf_browser_login "${username}" "${password}")
  final_status=$(echo "${final_result}" | sed -n '1p')
  body=$(echo "${final_result}" | tail -n +2)

  # A successful browser-flow login redirects (302) toward redirect_uri with a
  # code, or Keycloak returns 200 on a page that is no longer the login form
  # (no kc-feedback-text error). Assert no lockout-style error is present.
  local error_text
  error_text=$(_bf_extract_error "${body}")
  [[ -z "${error_text}" || "${final_status}" == "302" ]] || fail "expected no error / redirect after correct password within failureFactor-1 wrong attempts, got status=${final_status} error='${error_text}'"
}

# ---------------------------------------------------------------------------
# TS-273b [P0] — account IS locked after failureFactor failed attempts (AC1)
# RED PHASE: depends on failureFactor=5 having been picked up by a clean
# realm import (Task 1.1 + Task 7 manual re-import step).
# ---------------------------------------------------------------------------
@test "[P0][TS-273b] account IS locked after failureFactor failed attempts" {
  local password="Correct!Passw0rd2"
  local create_out create_rc user_id username create_err_file create_err
  create_err_file=$(mktemp)
  create_out=$(_bf_create_user "ts273b" "${password}" 2>"${create_err_file}")
  create_rc=$?
  create_err=$(cat "${create_err_file}")
  rm -f "${create_err_file}"
  user_id=$(echo "${create_out}" | awk '{print $1}')
  username=$(echo "${create_out}" | awk '{print $2}')
  # Register for teardown cleanup as soon as an id is parseable, even if
  # _bf_create_user returned non-zero (e.g. password-reset failed after the
  # user already exists in Keycloak) — see _bf_create_user comment.
  [[ -n "${user_id}" ]] && _BF_USER_ID="${user_id}"
  [[ "${create_rc}" -eq 0 ]] || fail "setup: ${create_out} ${create_err}"

  # Submit exactly failureFactor wrong passwords to trip the lockout threshold.
  # Paced by QUICK_LOGIN_GUARD_SECONDS so failures accrue toward failureFactor
  # instead of tripping the separate quick-retry guard (see declaration above).
  # Each attempt's status is checked (not discarded) so a login-form-resolution
  # failure (_bf_browser_login returns "000") fails loudly here instead of
  # silently not counting toward failureFactor and producing a confusing
  # failure later at the lockout assertion.
  local i result status
  for ((i = 1; i <= FAILURE_FACTOR; i++)); do
    result=$(_bf_browser_login "${username}" "WrongPassword${i}!")
    status=$(echo "${result}" | sed -n '1p')
    [[ "${status}" == "200" ]] || fail "attempt ${i}: expected HTTP 200 (re-rendered login form), got ${status}"
    sleep "${QUICK_LOGIN_GUARD_SECONDS}"
  done

  # Confirm lockout via Admin REST API attack-detection endpoint.
  local token bf_status disabled
  token=$(get_admin_token) || fail "could not obtain admin token"
  bf_status=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/attack-detection/brute-force/users/${user_id}") \
    || fail "could not query attack-detection status"
  disabled=$(echo "${bf_status}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('disabled', False)).lower())")
  assert_equal "${disabled}" "true"

  # Belt-and-suspenders: a subsequent CORRECT password must also fail while locked.
  local correct_result correct_status
  correct_result=$(_bf_browser_login "${username}" "${password}")
  correct_status=$(echo "${correct_result}" | sed -n '1p')
  [[ "${correct_status}" != "302" ]] || fail "correct password succeeded (302 redirect) while account should be locked"
}

# ---------------------------------------------------------------------------
# TS-273c [P1] — locked-account response identical to wrong-password response (AC2)
# ---------------------------------------------------------------------------
@test "[P1][TS-273c] locked-account response is identical to wrong-password response" {
  local password="Correct!Passw0rd3"
  local create_out create_rc user_id username create_err_file create_err
  create_err_file=$(mktemp)
  create_out=$(_bf_create_user "ts273c" "${password}" 2>"${create_err_file}")
  create_rc=$?
  create_err=$(cat "${create_err_file}")
  rm -f "${create_err_file}"
  user_id=$(echo "${create_out}" | awk '{print $1}')
  username=$(echo "${create_out}" | awk '{print $2}')
  # Register for teardown cleanup as soon as an id is parseable, even if
  # _bf_create_user returned non-zero (e.g. password-reset failed after the
  # user already exists in Keycloak) — see _bf_create_user comment.
  [[ -n "${user_id}" ]] && _BF_USER_ID="${user_id}"
  [[ "${create_rc}" -eq 0 ]] || fail "setup: ${create_out} ${create_err}"

  # First wrong-password attempt (pre-lockout) — capture status + generic error text.
  local pre_result pre_status pre_body pre_error
  pre_result=$(_bf_browser_login "${username}" "WrongBefore!")
  pre_status=$(echo "${pre_result}" | sed -n '1p')
  pre_body=$(echo "${pre_result}" | tail -n +2)
  pre_error=$(_bf_extract_error "${pre_body}")
  [[ "${pre_status}" == "200" ]] || fail "pre-lockout attempt: expected HTTP 200 (re-rendered login form), got ${pre_status}"
  sleep "${QUICK_LOGIN_GUARD_SECONDS}"

  # Trip the lockout with the remaining attempts. Paced by
  # QUICK_LOGIN_GUARD_SECONDS so failures accrue toward failureFactor instead
  # of tripping the separate quick-retry guard (see declaration above).
  # Each attempt's status is checked so a login-form-resolution failure
  # (_bf_browser_login returns "000") fails loudly here instead of silently
  # not counting toward failureFactor.
  local i during_result during_status
  for ((i = 2; i <= FAILURE_FACTOR; i++)); do
    during_result=$(_bf_browser_login "${username}" "WrongDuring${i}!")
    during_status=$(echo "${during_result}" | sed -n '1p')
    [[ "${during_status}" == "200" ]] || fail "attempt ${i}: expected HTTP 200 (re-rendered login form), got ${during_status}"
    sleep "${QUICK_LOGIN_GUARD_SECONDS}"
  done

  # Post-lockout attempt (any password) — capture status + generic error text.
  local post_result post_status post_body post_error
  post_result=$(_bf_browser_login "${username}" "AnyPasswordAfterLockout!")
  post_status=$(echo "${post_result}" | sed -n '1p')
  post_body=$(echo "${post_result}" | tail -n +2)
  post_error=$(_bf_extract_error "${post_body}")

  # Both attempts must produce the same HTTP status and the same generic error text.
  assert_equal "${post_status}" "${pre_status}"
  [[ -n "${pre_error}" ]] || fail "could not extract error text from pre-lockout response — check _bf_extract_error selectors"
  assert_equal "${post_error}" "${pre_error}"
}

# ---------------------------------------------------------------------------
# TS-273d [P1] — nonexistent-user response identical to wrong-password response (AC2)
# Exercises already-shipped story 2.5 enumeration-safe messaging
# (invalidUserMessage == invalidPasswordMessage) against a live stack.
# ---------------------------------------------------------------------------
@test "[P1][TS-273d] nonexistent-user response is identical to wrong-password response" {
  local password="Correct!Passw0rd4"
  local create_out create_rc user_id username create_err_file create_err
  create_err_file=$(mktemp)
  create_out=$(_bf_create_user "ts273d" "${password}" 2>"${create_err_file}")
  create_rc=$?
  create_err=$(cat "${create_err_file}")
  rm -f "${create_err_file}"
  user_id=$(echo "${create_out}" | awk '{print $1}')
  username=$(echo "${create_out}" | awk '{print $2}')
  # Register for teardown cleanup as soon as an id is parseable, even if
  # _bf_create_user returned non-zero (e.g. password-reset failed after the
  # user already exists in Keycloak) — see _bf_create_user comment.
  [[ -n "${user_id}" ]] && _BF_USER_ID="${user_id}"
  [[ "${create_rc}" -eq 0 ]] || fail "setup: ${create_out} ${create_err}"

  # Real user, wrong password.
  local real_result real_status real_body real_error
  real_result=$(_bf_browser_login "${username}" "WrongPasswordForRealUser!")
  real_status=$(echo "${real_result}" | sed -n '1p')
  real_body=$(echo "${real_result}" | tail -n +2)
  real_error=$(_bf_extract_error "${real_body}")

  # Nonexistent user, any password.
  local ghost_username
  ghost_username="nonexistent-$$-$(date +%s)@envocc.local"
  local ghost_result ghost_status ghost_body ghost_error
  ghost_result=$(_bf_browser_login "${ghost_username}" "AnyPassword!")
  ghost_status=$(echo "${ghost_result}" | sed -n '1p')
  ghost_body=$(echo "${ghost_result}" | tail -n +2)
  ghost_error=$(_bf_extract_error "${ghost_body}")

  assert_equal "${ghost_status}" "${real_status}"
  [[ -n "${real_error}" ]] || fail "could not extract error text from real-user response — check _bf_extract_error selectors"
  assert_equal "${ghost_error}" "${real_error}"
}
