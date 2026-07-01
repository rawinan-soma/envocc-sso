#!/usr/bin/env bats
# tests/integration/thaid-broker.bats
# ATDD integration tests — Story 2.9: Login with ThaiD (Brokered Federation & Account Linking)
#
# AC1: "Login with ThaiD" button appears on the top-level login screen (UX-DR6 /
#      thaid-login-button spec).
# AC2: The `thaid` OIDC identity provider is configured against a mock IdP in
#      dev/CI (real DOPA/ThaiD endpoints are a future swap, see Dev Notes).
# AC3: A ThaiD login resolves ONLY to a pre-registered federated-identity link
#      (PID -> local account). No account is ever auto-created or auto-linked by
#      email on first broker login (Task 2's deny-only `thaid-first-broker-login`
#      flow).
# AC4: A disabled local account cannot authenticate via ThaiD, mirroring Story
#      2.8's password-path enforcement.
# AC5: The `thaid` IdP's authorizationUrl/tokenUrl/userInfoUrl/issuer/jwksUrl
#      point at the mock OIDC IdP in dev/CI (Task 1.2).
#
# Test scenarios covered (Task 5 subtasks 5.2-5.8):
#   TS-290a [P0] Mock OIDC IdP responds to discovery (precondition smoke) (AC2/AC5)
#   TS-290b [P0] First ThaiD login links to the pre-created account by PID; sub matches (AC3)
#   TS-290c [P1] Second ThaiD login by the same PID reuses the same identity, no re-link prompt (AC3)
#   TS-290d [P0] Unrecognized PID does not create a phantom account (AC3)
#   TS-290e [P0] Disabled account cannot authenticate via ThaiD (AC4)
#   TS-290f [P2] Account already linked to one ThaiD PID rejects a second, conflicting link attempt
#   TS-290h [P2] Mock IdP unreachable produces a clean broker error, not a raw 5xx (resilience)
#
# NOTE: TS-290g (bonus, reverse direction — same PID linked to a second, different
# account) is an OPTIONAL scenario per story Task 5.7 ("if time permits") and is
# NOT implemented here — only the mandatory TS-290a-f/h set is in scope for this
# red-phase scaffold.
#
# RED PHASE (expected failures at this story's baseline, before Tasks 0-2 land):
#   - TS-290a fails: no `mock-oidc-provider` service exists in compose.yaml yet
#     (Task 0) — the discovery curl cannot connect.
#   - TS-290b/c/d/e/f/h all fail: `keycloak/realm-export.json` has no
#     `identityProviders` entry yet (Task 1), so `kc_idp_hint=thaid` is rejected
#     by Keycloak with an unknown-IDP error before any broker flow can begin.
#   - Once Tasks 0-2 land, drive_thaid_broker_login()'s exact multi-hop shape
#     (the mock IdP's login/consent form field names and redirect chain) MUST be
#     re-verified empirically against the running `mock-oidc-provider` container
#     (story Task 5.3) — this helper is a best-effort scaffold written from the
#     `ghcr.io/navikt/mock-oauth2-server` documented behavior, not a confirmed
#     hands-on trace, and may need field-name/hop adjustments during dev-story.
#
# IMPORTANT: All tests in this file require a live Keycloak + mock-oidc-provider
# stack. They are skipped unless the INTEGRATION environment variable is set.
# To run: INTEGRATION=1 bats tests/integration/thaid-broker.bats
#
# INTEGRATION=1 tests including this file are run locally against a live stack,
# not in CI — this is a pre-existing, already-accepted repo-wide gap (see Dev
# Notes — CI Coverage in the story file), not something this story introduces.
#
# Pre-requisites:
#   1. docker compose down -v && docker compose up --build (Task 0-2 realm/compose config)
#   2. .env with KC_BOOTSTRAP_ADMIN_USERNAME / KC_BOOTSTRAP_ADMIN_PASSWORD set
#   3. BATS_LIB_PATH=$(pwd)/tests/lib or bats-support/bats-assert installed system-wide

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

# Task 0.1: mock-oidc-provider publishes a host port (e.g. 18080:8080) so the
# host-run BATS process can reach it directly, matching every other service's
# de-facto host-reachability in this test suite (see file header + story
# Dev Notes for why this does not contradict the Nginx-only-published-ports rule).
MOCK_IDP_BASE="http://localhost:18080"
# Task 0.4: the mock IdP is configured with exactly one named issuer, id "thaid".
MOCK_IDP_DISCOVERY="${MOCK_IDP_BASE}/thaid/.well-known/openid-configuration"

# ---------------------------------------------------------------------------
# drive_thaid_broker_login <pid> [password_form_value]
#
# Drives the full brokered-login redirect chain: Keycloak auth endpoint (with
# kc_idp_hint=thaid) -> mock IdP authorize/login -> mock IdP asserts `sub:
# <pid>` -> Keycloak broker callback -> RP redirect_uri with ?code=...
#
# Exchanges the resulting code for a token set and prints two lines to stdout:
#   1. the final HTTP status observed at the RP redirect hop ("200"-class
#      proxy for "did the flow complete", or the error status/marker)
#   2. the `sub` claim from the exchanged access_token's JWT payload (decoded,
#      NOT signature-verified — this test only needs the claim value), or
#      empty if no token was obtained
#
# Returns non-zero if the flow could not even be attempted (e.g. no HTTP
# response at all — connection refused because mock-oidc-provider isn't up).
#
# NOTE (see file header RED PHASE note): the mock IdP hop's exact form field
# name / redirect shape is written from `ghcr.io/navikt/mock-oauth2-server`'s
# documented behavior (a GET to the authorization endpoint returns an HTML
# login page; POSTing a `username` — used verbatim as the issued `sub` claim
# unless a `claims` override is configured — completes the flow). Re-verify
# hands-on per story Task 5.3 once Task 0 lands; adjust field names/hops here
# if the chosen image's actual behavior differs.
# ---------------------------------------------------------------------------
drive_thaid_broker_login() {
  local pid="${1}"
  local session_jar idp_jar state tmphtml idp_html
  state="state-thaid-$$-${RANDOM}"
  session_jar=$(mktemp "${TMPDIR:-/tmp}/kc-thaid-sess-XXXXXX")
  tmphtml=$(mktemp "${TMPDIR:-/tmp}/kc-thaid-hop1-XXXXXX")
  idp_html=$(mktemp "${TMPDIR:-/tmp}/kc-thaid-hop2-XXXXXX")

  # Hop 1: Keycloak auth endpoint with kc_idp_hint=thaid — jumps straight to
  # the named broker, skipping the local login form. Follow redirects with a
  # cookie jar; capture the final page (should be the mock IdP's login/consent
  # form) plus headers for diagnostics.
  local hop1_headers
  hop1_headers=$(curl -s --max-time 15 -L \
    -c "${session_jar}" -b "${session_jar}" \
    -D - -o "${tmphtml}" \
    "${AUTH_ENDPOINT}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid&state=${state}&kc_idp_hint=thaid") \
    || { rm -f "${session_jar}" "${tmphtml}" "${idp_html}"; echo "connect_error"; echo ""; return 1; }

  # If Keycloak itself rejected the hint (thaid IdP not configured — Task 1
  # not yet landed), the final page will be a Keycloak error page with no form
  # pointing at the mock IdP. Detect this explicitly so callers get a clear
  # red-phase failure message rather than an opaque parse error downstream.
  if ! grep -qi "mock-oidc-provider\|localhost:18080\|/thaid/" "${tmphtml}" 2>/dev/null; then
    local last_status
    last_status=$(echo "${hop1_headers}" | grep -i "^HTTP/" | tail -1 | awk '{print $2}' | tr -d '\r')
    rm -f "${session_jar}" "${tmphtml}" "${idp_html}"
    echo "${last_status:-no_thaid_redirect}"
    echo ""
    return 1
  fi

  # Hop 2: the mock IdP's login/consent form. Extract its form action and
  # submit the PID as the `username` field (mock-oauth2-server convention —
  # see helper header note).
  local idp_form_action
  idp_form_action=$(python3 -c "
import re, sys
html = open('${tmphtml}').read()
actions = [m.replace('&amp;', '&') for m in re.findall(r'action=\"([^\"]+)\"', html)]
print(actions[0] if actions else '')
")
  if [[ -z "${idp_form_action}" ]]; then
    rm -f "${session_jar}" "${tmphtml}" "${idp_html}"
    echo "no_idp_form"
    echo ""
    return 1
  fi

  local hop2_headers
  hop2_headers=$(curl -s --max-time 15 \
    -c "${session_jar}" -b "${session_jar}" \
    -D - -o "${idp_html}" \
    -X POST "${idp_form_action}" \
    -d "username=${pid}" \
    -d "subject=${pid}" \
    -d "claims={\"sub\":\"${pid}\"}") || true

  local idp_location
  idp_location=$(echo "${hop2_headers}" | grep -i "^location:" | tail -1 | tr -d '\r' | sed -E 's/^[Ll]ocation:[[:space:]]*//')
  if [[ -z "${idp_location}" ]]; then
    rm -f "${session_jar}" "${tmphtml}" "${idp_html}"
    echo "no_idp_redirect"
    echo ""
    return 1
  fi

  # Hop 3: follow the mock IdP's redirect back through Keycloak's broker
  # callback. Keycloak's core broker logic (not this file) decides whether a
  # matching federated-identity link exists; if so it completes the flow with
  # a redirect to the RP's redirect_uri carrying ?code=...; if not, it renders
  # an error page (Task 2's deny-only flow, or a generic broker error).
  local hop3_headers hop3_body
  hop3_headers=$(curl -s --max-time 15 -L \
    -c "${session_jar}" -b "${session_jar}" \
    -D - -o "${idp_html}" \
    "${idp_location}") || true
  hop3_body=$(cat "${idp_html}" 2>/dev/null || true)

  rm -f "${session_jar}" "${tmphtml}" "${idp_html}"

  # Extract the RP redirect's `code` param from the LAST Location header in
  # the redirect chain (curl -D - with -L prints headers for every hop).
  local code final_status
  code=$(echo "${hop3_headers}" | python3 -c "
import sys, urllib.parse
code = ''
for line in sys.stdin:
    if line.lower().startswith('location:'):
        loc = line.split(':', 1)[1].strip()
        params = urllib.parse.parse_qs(urllib.parse.urlparse(loc).query)
        c = params.get('code', [''])[0]
        if c:
            code = c
print(code)
")
  final_status=$(echo "${hop3_headers}" | grep -i "^HTTP/" | tail -1 | awk '{print $2}' | tr -d '\r')

  if [[ -z "${code}" ]]; then
    echo "${final_status:-no_code}"
    echo ""
    return 1
  fi

  # Exchange the code for tokens (test-oidc-client is a public client — no secret).
  local token_response token_status token_body access_token
  token_response=$(curl -s --max-time 15 -w $'\n%{http_code}' \
    -X POST "${TOKEN_ENDPOINT}" \
    -d "grant_type=authorization_code" \
    -d "code=${code}" \
    -d "client_id=${CLIENT_ID}" \
    -d "redirect_uri=${REDIRECT_URI}")
  token_status=$(echo "${token_response}" | tail -n 1)
  token_body=$(echo "${token_response}" | sed '$d')

  if [[ "${token_status}" != "200" ]]; then
    echo "${token_status}"
    echo ""
    return 1
  fi

  access_token=$(echo "${token_body}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
  if [[ -z "${access_token}" ]]; then
    echo "no_access_token"
    echo ""
    return 1
  fi

  # Decode the JWT payload (base64url, unverified — claim inspection only).
  local sub
  sub=$(python3 -c "
import base64, json, sys
token = sys.argv[1]
try:
    payload = token.split('.')[1]
    padded = payload + '=' * (-len(payload) % 4)
    claims = json.loads(base64.urlsafe_b64decode(padded))
    print(claims.get('sub', ''))
except Exception:
    print('')
" "${access_token}")

  echo "200"
  echo "${sub}"
  return 0
}

# ---------------------------------------------------------------------------
# _create_active_thaid_user <username_prefix>
# Creates an active (enabled:true, emailVerified:true) local account with no
# password credential (ThaiD-only account — password login is not exercised
# by this file). Prints the created user's Keycloak UUID to stdout.
# ---------------------------------------------------------------------------
_create_active_thaid_user() {
  local prefix="${1}" token
  token=$(get_admin_token) || { echo ""; return 1; }

  local email="${prefix}-$(date +%s)-${RANDOM}@envocc.local"
  local post_loc_file http_status loc user_id
  post_loc_file=$(mktemp)
  http_status=$(curl -s -o /dev/null -w "%{http_code}" -D "${post_loc_file}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${email}\",\"email\":\"${email}\",\"enabled\":true,\"emailVerified\":true,\"firstName\":\"Test\",\"lastName\":\"ThaidBroker\"}" \
    "${KC_BASE}/admin/realms/${REALM}/users")
  if [[ "${http_status}" != "201" ]]; then
    rm -f "${post_loc_file}"
    echo ""
    return 1
  fi
  loc=$(grep -i '^location:' "${post_loc_file}" | tail -n 1 | tr -d '\r' | sed -E 's/^[^:]+:[[:space:]]*//')
  rm -f "${post_loc_file}"
  user_id="${loc##*/}"
  if [[ -z "${user_id}" ]]; then
    local fallback_resp
    fallback_resp=$(curl -sf --max-time 10 \
      -H "Authorization: Bearer ${token}" \
      "${KC_BASE}/admin/realms/${REALM}/users?email=${email}&exact=true") || true
    user_id=$(echo "${fallback_resp}" | python3 -c "import json,sys; u=json.load(sys.stdin); print(u[0]['id'] if u else '')" 2>/dev/null || echo "")
  fi
  echo "${user_id}"
}

# ---------------------------------------------------------------------------
# _register_pid_link <user_id> <pid>
# POST /admin/realms/envocc/users/{id}/federated-identity/thaid. Prints the
# observed HTTP status to stdout.
# ---------------------------------------------------------------------------
_register_pid_link() {
  local user_id="${1}" pid="${2}" token
  token=$(get_admin_token) || { echo "000"; return 1; }
  curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "{\"identityProvider\":\"thaid\",\"userId\":\"${pid}\",\"userName\":\"${pid}\"}" \
    "${KC_BASE}/admin/realms/${REALM}/users/${user_id}/federated-identity/thaid"
}

# ---------------------------------------------------------------------------
# Per-test cleanup state. Each test stores its created user UUID here
# immediately after creation. teardown() deletes any stored user.
# ---------------------------------------------------------------------------
_TS290B_USER_ID=""
_TS290C_USER_ID=""
_TS290D_USER_ID=""
_TS290E_USER_ID=""
_TS290F_USER_ID=""
_TS290H_USER_ID=""

setup() {
  if [[ -z "${INTEGRATION}" ]]; then
    skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"
  fi
  _TS290B_USER_ID=""
  _TS290C_USER_ID=""
  _TS290D_USER_ID=""
  _TS290E_USER_ID=""
  _TS290F_USER_ID=""
  _TS290H_USER_ID=""
}

teardown() {
  local ids=(
    "${_TS290B_USER_ID}"
    "${_TS290C_USER_ID}"
    "${_TS290D_USER_ID}"
    "${_TS290E_USER_ID}"
    "${_TS290F_USER_ID}"
    "${_TS290H_USER_ID}"
  )
  local token="" id
  for id in "${ids[@]}"; do
    if [[ -n "${id}" ]]; then
      [[ -n "${token}" ]] || token=$(get_admin_token 2>/dev/null) || true
      if [[ -n "${token}" ]]; then
        curl -sf -X DELETE \
          -H "Authorization: Bearer ${token}" \
          "${KC_BASE}/admin/realms/${REALM}/users/${id}" \
          2>/dev/null || true
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# TS-290a [P0] — Mock OIDC IdP responds to discovery (precondition smoke) (AC2/AC5)
#
# Runs first so a misconfigured/absent mock IdP fails fast with a clear
# signal, rather than every subsequent broker test failing with an opaque
# connection or Keycloak-config error.
#
# RED until Task 0 adds the `mock-oidc-provider` service to compose.yaml.
# ---------------------------------------------------------------------------
@test "[P0][TS-290a] Mock OIDC IdP responds to discovery" {
  local body status
  body=$(curl -s --max-time 10 -w $'\n%{http_code}' "${MOCK_IDP_DISCOVERY}") \
    || fail "Could not reach mock IdP discovery endpoint at ${MOCK_IDP_DISCOVERY} — is mock-oidc-provider up? (Task 0)"
  status=$(echo "${body}" | tail -n 1)
  body=$(echo "${body}" | sed '$d')

  assert_equal "${status}" "200"

  run python3 -c "
import json, sys
d = json.loads('''${body}''')
for key in ('issuer', 'authorization_endpoint', 'token_endpoint'):
    assert key in d and d[key], f'missing or empty {key}'
print('OK')
"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-290b [P0] — First ThaiD login links to the pre-created account by PID;
# sub matches (AC3)
#
# Pre-registers the federated-identity link (HR/admin pre-registration, not
# auto-created by the broker flow itself — see Task 2's deny-only first-broker
# -login flow), then drives the broker flow and asserts the resulting token's
# `sub` claim equals the pre-created user's Keycloak id — proving the brokered
# identity resolved to the SAME canonical account, not a new one.
#
# RED until Tasks 0-2 land (mock IdP + thaid IdP config + deny-only flow).
# ---------------------------------------------------------------------------
@test "[P0][TS-290b] First ThaiD login links to the pre-created account by PID" {
  local user_id pid link_status status sub
  user_id=$(_create_active_thaid_user "ts290b")
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-290b"
  _TS290B_USER_ID="${user_id}"

  pid="pid-ts290b-$$-${RANDOM}"
  link_status=$(_register_pid_link "${user_id}" "${pid}")
  [[ "${link_status}" == "204" ]] || fail "Could not pre-register federated-identity link for TS-290b (got HTTP ${link_status})"

  local result
  result=$(drive_thaid_broker_login "${pid}")
  status=$(echo "${result}" | sed -n '1p')
  sub=$(echo "${result}" | sed -n '2p')

  assert_equal "${status}" "200"
  assert_equal "${sub}" "${user_id}"
}

# ---------------------------------------------------------------------------
# TS-290c [P1] — Second ThaiD login by the same PID reuses the same identity,
# no re-link prompt (AC3)
#
# Repeats the broker flow for the same (user, PID) pair. Because a
# federated-identity link already exists, Keycloak's broker logic treats this
# as a non-first-broker-login and completes directly — no intermediate
# "confirm link"/profile-review HTML form (Task 2's flow only ever executes on
# a true first-broker-login, i.e. no existing link).
#
# RED until Tasks 0-2 land.
# ---------------------------------------------------------------------------
@test "[P1][TS-290c] Second ThaiD login by the same PID reuses the same identity" {
  local user_id pid first_status first_sub second_status second_sub
  user_id=$(_create_active_thaid_user "ts290c")
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-290c"
  _TS290C_USER_ID="${user_id}"

  pid="pid-ts290c-$$-${RANDOM}"
  local link_status
  link_status=$(_register_pid_link "${user_id}" "${pid}")
  [[ "${link_status}" == "204" ]] || fail "Could not pre-register federated-identity link for TS-290c (got HTTP ${link_status})"

  local first_result
  first_result=$(drive_thaid_broker_login "${pid}")
  first_status=$(echo "${first_result}" | sed -n '1p')
  first_sub=$(echo "${first_result}" | sed -n '2p')
  assert_equal "${first_status}" "200"
  assert_equal "${first_sub}" "${user_id}"

  local second_result
  second_result=$(drive_thaid_broker_login "${pid}")
  second_status=$(echo "${second_result}" | sed -n '1p')
  second_sub=$(echo "${second_result}" | sed -n '2p')

  assert_equal "${second_status}" "200"
  assert_equal "${second_sub}" "${first_sub}"
}

# ---------------------------------------------------------------------------
# TS-290d [P0] — Unrecognized PID does not create a phantom account (AC3)
#
# The single most important test in this story: proves Task 2's deny-only
# `thaid-first-broker-login` flow works. Drives the broker flow with a PID
# that has NO pre-registered federated-identity link. Asserts (a) the flow
# does not complete with a valid token, and (b) no new user was created as a
# side effect of the failed first-broker-login.
#
# RED until Tasks 0-2 land.
# ---------------------------------------------------------------------------
@test "[P0][TS-290d] Unrecognized PID does not create a phantom account" {
  local pid status token
  pid="pid-ts290d-unregistered-$$-${RANDOM}"

  local result
  result=$(drive_thaid_broker_login "${pid}")
  status=$(echo "${result}" | sed -n '1p')

  [[ "${status}" != "200" ]] || fail "Expected the broker flow to be rejected for an unrecognized PID, but it completed with HTTP 200"

  token=$(get_admin_token) || fail "Could not obtain admin token"
  local search_json count
  search_json=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "${KC_BASE}/admin/realms/${REALM}/users?username=${pid}") \
    || fail "Could not search for phantom user by username=${pid}"
  count=$(echo "${search_json}" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
  assert_equal "${count}" "0"
}

# ---------------------------------------------------------------------------
# TS-290e [P0] — Disabled account cannot authenticate via ThaiD (AC4)
#
# Reuses a pre-linked, freshly-created test user (not TS-290b's — isolated
# fixture per test, matching the repo-wide convention), disables it
# (Story 2.8's Admin REST call), then attempts the ThaiD broker flow with
# that user's linked PID. Asserts the flow is rejected (no token issued).
#
# RED until Tasks 0-2 land.
# ---------------------------------------------------------------------------
@test "[P0][TS-290e] Disabled account cannot authenticate via ThaiD" {
  local user_id pid link_status token disable_status
  user_id=$(_create_active_thaid_user "ts290e")
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-290e"
  _TS290E_USER_ID="${user_id}"

  pid="pid-ts290e-$$-${RANDOM}"
  link_status=$(_register_pid_link "${user_id}" "${pid}")
  [[ "${link_status}" == "204" ]] || fail "Could not pre-register federated-identity link for TS-290e (got HTTP ${link_status})"

  token=$(get_admin_token) || fail "Could not obtain admin token"
  disable_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"enabled":false}' \
    "${KC_BASE}/admin/realms/${REALM}/users/${user_id}")
  [[ "${disable_status}" == "204" ]] || fail "Could not disable TS-290e user (got HTTP ${disable_status})"

  local result status
  result=$(drive_thaid_broker_login "${pid}")
  status=$(echo "${result}" | sed -n '1p')

  [[ "${status}" != "200" ]] || fail "Expected the broker flow to be rejected for a disabled account, but it completed with HTTP 200"
}

# ---------------------------------------------------------------------------
# TS-290f [P2] — Account already linked to one ThaiD PID rejects a second,
# conflicting link attempt
#
# Pre-registers pid_A to a test user, then attempts to register a second,
# different pid_B to the SAME user. Asserts the second call is rejected
# (non-2xx) and that only pid_A remains linked afterward.
#
# This test exercises the Admin REST API directly (no broker flow) — it can
# in principle pass or fail independent of Tasks 0/2, but is grouped here
# because it depends on the `thaid` identity provider alias existing at all
# (Task 1), which is RED at this story's baseline (identityProviders is
# absent from keycloak/realm-export.json).
# ---------------------------------------------------------------------------
@test "[P2][TS-290f] Account already linked to one ThaiD PID rejects a second link attempt" {
  local user_id pid_a pid_b first_link_status second_link_status token
  user_id=$(_create_active_thaid_user "ts290f")
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-290f"
  _TS290F_USER_ID="${user_id}"

  pid_a="pid-ts290f-a-$$-${RANDOM}"
  pid_b="pid-ts290f-b-$$-${RANDOM}"

  first_link_status=$(_register_pid_link "${user_id}" "${pid_a}")
  [[ "${first_link_status}" == "204" ]] || fail "Could not pre-register pid_A for TS-290f (got HTTP ${first_link_status})"

  second_link_status=$(_register_pid_link "${user_id}" "${pid_b}")
  if [[ "${second_link_status}" =~ ^2 ]]; then
    fail "Expected the second, conflicting federated-identity link attempt to be rejected (non-2xx), got HTTP ${second_link_status}"
  fi

  token=$(get_admin_token) || fail "Could not obtain admin token"
  local links_json remaining_pids
  links_json=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "${KC_BASE}/admin/realms/${REALM}/users/${user_id}/federated-identity") \
    || fail "Could not fetch federated-identity links for TS-290f user"
  remaining_pids=$(echo "${links_json}" | python3 -c "
import json, sys
links = json.load(sys.stdin)
print(','.join(sorted(l.get('userId', '') for l in links if l.get('identityProvider') == 'thaid')))
")
  assert_equal "${remaining_pids}" "${pid_a}"
}

# ---------------------------------------------------------------------------
# TS-290h [P2] — Mock IdP unreachable produces a clean broker error, not a
# raw 5xx passed through to the browser
#
# Runs LAST in this file deliberately: stops the mock-oidc-provider container,
# attempts the broker flow against a linked PID, asserts Keycloak returns a
# themed/generic error state (not an unhandled 502/stack trace), then restarts
# the container and waits for it to become healthy again BEFORE the test ends
# — mandatory, so a failure here does not poison any test that runs after this
# file (including on the next local/CI run, since the stack persists between
# bats invocations if not torn down).
#
# RED until Tasks 0-2 land (and, structurally, this test cannot even exercise
# its "stop the container" step meaningfully until Task 0 creates the
# container to stop — `docker compose stop` on a non-existent service is a
# no-op, so this test's failure mode at baseline is identical to TS-290e's:
# the broker flow never completes because `thaid` isn't configured).
# ---------------------------------------------------------------------------
@test "[P2][TS-290h] Mock IdP unreachable produces a clean broker error" {
  local user_id pid link_status
  user_id=$(_create_active_thaid_user "ts290h")
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-290h"
  _TS290H_USER_ID="${user_id}"

  pid="pid-ts290h-$$-${RANDOM}"
  link_status=$(_register_pid_link "${user_id}" "${pid}")
  [[ "${link_status}" == "204" ]] || fail "Could not pre-register federated-identity link for TS-290h (got HTTP ${link_status})"

  docker compose -f "${PROJECT_ROOT}/compose.yaml" stop mock-oidc-provider >/dev/null 2>&1 || true

  local result status
  result=$(drive_thaid_broker_login "${pid}")
  status=$(echo "${result}" | sed -n '1p')

  # Always attempt to bring the mock IdP back up before asserting, so a failed
  # assertion below does not leave the stack in a poisoned state for later runs.
  docker compose -f "${PROJECT_ROOT}/compose.yaml" start mock-oidc-provider >/dev/null 2>&1 || true
  wait_for_healthy mock-oidc-provider 60 || true

  [[ "${status}" != "502" ]] || fail "Expected a clean broker error (themed error page / non-502 status) when the mock IdP is unreachable, got a raw HTTP 502"
  [[ "${status}" != "200" ]] || fail "Expected the broker flow to fail when the mock IdP is unreachable, but it completed with HTTP 200"
}
