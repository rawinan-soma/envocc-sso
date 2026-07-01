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
# NOT implemented here — only the mandatory TS-290a-f/h set is in scope.
#
# HANDS-ON VERIFICATION (story Task 5.3, dev-story implementation pass): the
# drive_thaid_broker_login() helper's exact multi-hop shape, the `deny-access`
# authenticator's real provider id, and the `thaid` identity provider's split
# browser-facing/backend-facing URL scheme (see keycloak/REALM-EXPORT-NOTES.md,
# Story 2.9 section) were all confirmed by importing this story's actual
# realm-export.json into a live Keycloak 26.6.3 container alongside a real
# ghcr.io/navikt/mock-oauth2-server 5.0.2 container and driving the full
# TS-290a/b/d/e/f flows by hand — not written from documentation alone.
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
# drive_thaid_broker_login <pid>
#
# Drives the full brokered-login redirect chain: Keycloak auth endpoint (with
# kc_idp_hint=thaid) -> mock IdP authorize/login -> mock IdP asserts `sub:
# <pid>` -> Keycloak broker callback -> RP redirect_uri with ?code=...
#
# Exchanges the resulting code for a token set and prints two lines to stdout:
#   1. the final HTTP status observed ("200" if the flow completed and a
#      token was issued, or the error status/marker otherwise)
#   2. the `sub` claim from the exchanged ID token's JWT payload (decoded,
#      NOT signature-verified — this test only needs the claim value), or
#      empty if no token was obtained
#
# Returns non-zero if the flow did not complete with a usable token.
#
# HANDS-ON VERIFIED (story Task 5.3) against a live Keycloak 26.6.3 import of
# this story's own realm-export.json + a real ghcr.io/navikt/mock-oauth2-server
# 5.0.2 container, replacing the original best-effort red-phase scaffold. Key
# findings that shaped this helper (documented in keycloak/REALM-EXPORT-NOTES.md,
# Story 2.9 section, in more detail):
#   - The mock IdP's login page is a SINGLE hop, not three: `GET .../authorize`
#     returns an HTML form with NO `action` attribute (a browser posts back to
#     the *same* URL), and `POST username=<pid>` to that same URL returns the
#     302 redirect straight to Keycloak's broker callback — there is no
#     separate "mock IdP redirect" hop to follow before reaching Keycloak.
#   - `test-oidc-client` is a public client with PKCE S256 enforced
#     (realm-export.json `pkce.code.challenge.method: "S256"`) — the initial
#     `/auth` request MUST include `code_challenge`/`code_challenge_method`,
#     and the final token exchange MUST include the matching `code_verifier`,
#     or Keycloak rejects the request before any broker redirect happens.
#   - This realm's access_token does NOT carry a `sub` claim for this client
#     (confirmed against a live token exchange) — only the ID token does, per
#     the OIDC spec's ID Token requirement. Decode `id_token`, matching
#     tests/helpers/common.bash's get_envocc_test_token() convention, which
#     also reads id_token rather than access_token for the same reason.
# ---------------------------------------------------------------------------
drive_thaid_broker_login() {
  local pid="${1}"
  local session_jar hop1_html hop2_html hop3_html
  local state verifier challenge
  state="state-thaid-$$-${RANDOM}"
  session_jar=$(mktemp "${TMPDIR:-/tmp}/kc-thaid-sess-XXXXXX")
  hop1_html=$(mktemp "${TMPDIR:-/tmp}/kc-thaid-hop1-XXXXXX")
  hop2_html=$(mktemp "${TMPDIR:-/tmp}/kc-thaid-hop2-XXXXXX")
  hop3_html=$(mktemp "${TMPDIR:-/tmp}/kc-thaid-hop3-XXXXXX")

  # PKCE S256 verifier/challenge — required by test-oidc-client (see header note).
  verifier="verifier-${RANDOM}-$$-$(date +%s)-thaidbrokertestpadding"
  challenge=$(python3 -c "
import hashlib, base64, sys
v = sys.argv[1]
h = hashlib.sha256(v.encode()).digest()
print(base64.urlsafe_b64encode(h).decode().rstrip('='))
" "${verifier}")

  # Hop 1: Keycloak auth endpoint with kc_idp_hint=thaid — jumps straight to
  # the named broker, skipping the local login form. Follow redirects with a
  # cookie jar; %{url_effective} captures the FINAL URL reached (the mock
  # IdP's login form). That form has no action attribute of its own, so the
  # next hop posts back to this same URL, exactly as a browser would.
  local hop1_url
  hop1_url=$(curl -s --max-time 15 -L \
    -c "${session_jar}" -b "${session_jar}" \
    -o "${hop1_html}" \
    -w '%{url_effective}' \
    "${AUTH_ENDPOINT}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=openid&state=${state}&kc_idp_hint=thaid&code_challenge=${challenge}&code_challenge_method=S256") \
    || { rm -f "${session_jar}" "${hop1_html}" "${hop2_html}" "${hop3_html}"; echo "connect_error"; echo ""; return 1; }

  # If Keycloak itself rejected the hint (thaid IdP not configured) or the
  # mock IdP is unreachable (connection failure mid-redirect — TS-290h), the
  # final URL will not be under the mock IdP's published host port.
  if [[ "${hop1_url}" != http://localhost:18080/* ]]; then
    rm -f "${session_jar}" "${hop1_html}" "${hop2_html}" "${hop3_html}"
    echo "no_thaid_redirect"
    echo ""
    return 1
  fi

  # Hop 2: POST the PID as `username` to the mock IdP's login form (its own
  # current URL — see header note). Capture the Location header WITHOUT
  # following it automatically: the target (Keycloak's broker callback)
  # requires a GET, and re-issuing that GET explicitly keeps this helper's
  # behavior deterministic regardless of how a given curl build handles
  # POST-to-GET conversion on a 302.
  local hop2_headers hop2_location
  hop2_headers=$(curl -s --max-time 15 -D - -o "${hop2_html}" \
    -c "${session_jar}" -b "${session_jar}" \
    -X POST "${hop1_url}" \
    -d "username=${pid}") || true
  hop2_location=$(echo "${hop2_headers}" | grep -i "^location:" | tail -1 | tr -d '\r' | sed -E 's/^[Ll]ocation:[[:space:]]*//')
  if [[ -z "${hop2_location}" ]]; then
    rm -f "${session_jar}" "${hop1_html}" "${hop2_html}" "${hop3_html}"
    echo "no_idp_redirect"
    echo ""
    return 1
  fi

  # Hop 3: GET Keycloak's broker callback. Keycloak's backend exchanges the
  # code with the mock IdP's tokenUrl/jwksUrl server-to-server (container-
  # network URLs, realm-export.json Task 1.2), then either:
  #   - an existing federated-identity link was found -> redirects to the RP
  #     redirect_uri with Keycloak's own ?code=... (this hop's Location header)
  #   - no link found -> redirects (302) to Keycloak's own
  #     login-actions/first-broker-login endpoint, which is where the
  #     thaid-first-broker-login (deny-access) flow actually executes (see
  #     Hop 3b below) -> that request is the one that produces the themed
  #     401 error page
  #   - the linked account is disabled -> HTTP 400 themed error page directly
  #     from this hop, no Location header (the disabled-account check runs
  #     before first-broker-login, so no Hop 3b is needed here)
  local hop3_headers hop3_status hop3_location
  hop3_headers=$(curl -s --max-time 15 -D - -o "${hop3_html}" \
    -c "${session_jar}" -b "${session_jar}" \
    "${hop2_location}") || true
  hop3_status=$(echo "${hop3_headers}" | grep -i "^HTTP/" | tail -1 | awk '{print $2}' | tr -d '\r')
  hop3_location=$(echo "${hop3_headers}" | grep -i "^location:" | tail -1 | tr -d '\r' | sed -E 's/^[Ll]ocation:[[:space:]]*//')

  # Hop 3b: HANDS-ON VERIFIED (re-confirmed against the live TS-290d/e stack
  # during test review) — an unrecognized-PID (no existing link) login does
  # NOT land on the 401 error page at Hop 3 itself; Hop 3 only redirects
  # (302) to Keycloak's login-actions/first-broker-login endpoint, and it is
  # THAT request which runs the thaid-first-broker-login (deny-access) flow
  # and returns the themed 401. Without following this hop, hop3_status would
  # only ever observe the intermediate 302 — never the actual deny-access
  # outcome. A pre-existing federated-identity link (TS-290b/c) never
  # redirects through this endpoint, so this is a no-op for every other
  # caller.
  local via_first_broker_login="false"
  if [[ "${hop3_location}" == */login-actions/first-broker-login* ]]; then
    via_first_broker_login="true"
    local hop3b_headers
    hop3b_headers=$(curl -s --max-time 15 -D - -o "${hop3_html}" \
      -c "${session_jar}" -b "${session_jar}" \
      "${hop3_location}") || true
    hop3_status=$(echo "${hop3b_headers}" | grep -i "^HTTP/" | tail -1 | awk '{print $2}' | tr -d '\r')
    hop3_location=$(echo "${hop3b_headers}" | grep -i "^location:" | tail -1 | tr -d '\r' | sed -E 's/^[Ll]ocation:[[:space:]]*//')
  fi

  rm -f "${session_jar}" "${hop1_html}" "${hop2_html}" "${hop3_html}"

  if [[ -z "${hop3_location}" ]]; then
    # No further redirect — broker flow was rejected (deny-access / disabled
    # account / other error). Report Keycloak's own HTTP status so callers
    # can assert on it (never "200" in this branch).
    echo "${hop3_status:-no_redirect}"
    echo ""
    return 1
  fi

  # Extract the RP redirect's `code` param.
  local code
  code=$(python3 -c "
import sys, urllib.parse
loc = sys.argv[1]
params = urllib.parse.parse_qs(urllib.parse.urlparse(loc).query)
print(params.get('code', [''])[0])
" "${hop3_location}")

  if [[ -z "${code}" ]]; then
    echo "${hop3_status:-no_code}"
    echo ""
    return 1
  fi

  # Exchange the code for tokens (test-oidc-client is a public PKCE client —
  # no client_secret, but the code_verifier matching hop 1's code_challenge
  # IS required).
  local token_response token_status token_body id_token
  token_response=$(curl -s --max-time 15 -w $'\n%{http_code}' \
    -X POST "${TOKEN_ENDPOINT}" \
    -d "grant_type=authorization_code" \
    -d "code=${code}" \
    -d "client_id=${CLIENT_ID}" \
    -d "redirect_uri=${REDIRECT_URI}" \
    -d "code_verifier=${verifier}")
  token_status=$(echo "${token_response}" | tail -n 1)
  token_body=$(echo "${token_response}" | sed '$d')

  if [[ "${token_status}" != "200" ]]; then
    echo "${token_status}"
    echo ""
    return 1
  fi

  id_token=$(echo "${token_body}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id_token',''))" 2>/dev/null || echo "")
  if [[ -z "${id_token}" ]]; then
    echo "no_id_token"
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
" "${id_token}")

  echo "200"
  echo "${sub}"
  # 3rd line: whether the flow was routed through Keycloak's
  # login-actions/first-broker-login endpoint (i.e. an interstitial
  # confirm-link/profile-review step) before completing. Callers with a
  # pre-registered federated-identity link (TS-290b/c) must observe "false"
  # here — Keycloak's core broker logic should match the existing link
  # directly, never routing through first-broker-login at all (code review
  # finding: makes Task 5.4's "no confirm-link form" requirement an explicit,
  # positive assertion instead of an inference from a 200 status alone).
  echo "${via_first_broker_login}"
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

  # Pass the body via stdin rather than splicing it into a Python source
  # literal — a discovery response containing `'''` or backslash sequences
  # would otherwise corrupt the triple-quoted string (code review finding).
  run python3 -c "
import json, sys
d = json.load(sys.stdin)
for key in ('issuer', 'authorization_endpoint', 'token_endpoint'):
    assert key in d and d[key], f'missing or empty {key}'
print('OK')
" <<< "${body}"
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
  local user_id pid first_status first_sub first_via_fbl second_status second_sub second_via_fbl
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
  first_via_fbl=$(echo "${first_result}" | sed -n '3p')
  assert_equal "${first_status}" "200"
  assert_equal "${first_sub}" "${user_id}"

  local second_result
  second_result=$(drive_thaid_broker_login "${pid}")
  second_status=$(echo "${second_result}" | sed -n '1p')
  second_sub=$(echo "${second_result}" | sed -n '2p')
  second_via_fbl=$(echo "${second_result}" | sed -n '3p')

  assert_equal "${second_status}" "200"
  assert_equal "${second_sub}" "${first_sub}"

  # Task 5.4: explicitly prove there was no intermediate confirm-link/
  # profile-review HTML form on EITHER call — because the federated-identity
  # link is pre-registered before the first call too, Keycloak's core broker
  # logic should match it directly and never route through
  # login-actions/first-broker-login at all (code review finding: this was
  # previously only inferred from a bare 200 status, not asserted directly).
  assert_equal "${first_via_fbl}" "false"
  assert_equal "${second_via_fbl}" "false"
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

  token=$(get_admin_token) || fail "Could not obtain admin token"
  local count_before
  count_before=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "${KC_BASE}/admin/realms/${REALM}/users/count") \
    || fail "Could not read realm user count before the broker attempt"

  local result
  # drive_thaid_broker_login intentionally returns non-zero when the flow is
  # rejected (the expected outcome here) — `|| true` prevents bats' implicit
  # errexit from aborting the test before the assertions below run.
  result=$(drive_thaid_broker_login "${pid}") || true
  status=$(echo "${result}" | sed -n '1p')

  # Hands-on verified (see drive_thaid_broker_login's Hop 3b): the deny-access
  # authenticator's rejection surfaces as an exact HTTP 401 themed error page,
  # not merely "anything other than 200" — assert the specific status so a
  # regression that changes the rejection's shape (e.g. a 5xx, or the flow
  # silently completing) is caught precisely, not just "not 200".
  assert_equal "${status}" "401"

  token=$(get_admin_token) || fail "Could not obtain admin token"
  local search_json count_by_username
  search_json=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "${KC_BASE}/admin/realms/${REALM}/users?username=${pid}") \
    || fail "Could not search for phantom user by username=${pid}"
  count_by_username=$(echo "${search_json}" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
  assert_equal "${count_by_username}" "0"

  # Code review finding: a username-only search would miss a phantom account
  # auto-created under a different key (e.g. a claim-derived username/email
  # rather than the raw PID, per Task 5.5's "search by any other identifying
  # value" ask). A realm-wide user-count delta is a stronger, key-agnostic
  # proof that the deny-only flow created NO account at all, regardless of
  # what field it might have been keyed on — this is "the single most
  # important test in this story" (Task 5.5).
  local count_after
  count_after=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "${KC_BASE}/admin/realms/${REALM}/users/count") \
    || fail "Could not read realm user count after the broker attempt"
  assert_equal "${count_after}" "${count_before}"
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
  # See TS-290d's comment: drive_thaid_broker_login intentionally returns
  # non-zero here (expected outcome) — `|| true` prevents bats' implicit
  # errexit from aborting the test before the assertion below runs.
  result=$(drive_thaid_broker_login "${pid}") || true
  status=$(echo "${result}" | sed -n '1p')

  # Hands-on verified: a disabled account's rejection surfaces as an exact
  # HTTP 400 themed error page directly at Hop 3 (see drive_thaid_broker_login
  # header) — assert the specific status for the same reason as TS-290d.
  assert_equal "${status}" "400"
}

# ---------------------------------------------------------------------------
# TS-290f [P2] — Account already linked to one ThaiD PID rejects a second,
# conflicting link attempt
#
# Pre-registers pid_A to a test user, then attempts to register a second,
# different pid_B to the SAME user. Asserts the second call is rejected with
# the specific, hands-on-confirmed HTTP 409 Conflict (not merely "non-2xx",
# which would also match a curl transport failure) and that only pid_A
# remains linked afterward.
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
  # Code review finding (Step 7): a bare "not 2xx" check treats a curl transport
  # failure (e.g. "000"/empty from a connection error, see _register_pid_link)
  # identically to a real Keycloak rejection — silently passing without ever
  # exercising the conflicting-link business logic. Assert the specific,
  # hands-on-confirmed rejection status (HTTP 409 Conflict, per
  # keycloak/REALM-EXPORT-NOTES.md) so only an actual server-side rejection
  # satisfies this test.
  [[ "${second_link_status}" == "409" ]] || fail "Expected the second, conflicting federated-identity link attempt to be rejected with HTTP 409, got HTTP ${second_link_status}"

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
# TS-290h [P2] — Mock IdP unreachable produces a clean connection failure at
# the browser-facing hop, not a raw 5xx/opaque status passed through
#
# Runs LAST in this file deliberately: stops the mock-oidc-provider container,
# attempts the broker flow against a linked PID, then restarts the container
# and waits for it to become healthy again BEFORE asserting — mandatory, so a
# failed assertion does not poison any test that runs after this file
# (including on the next local/CI run, since the stack persists between bats
# invocations if not torn down). Restart failure is itself a fatal assertion,
# not silently swallowed.
#
# SCOPE NOTE (code review finding): stopping mock-oidc-provider kills BOTH its
# browser-facing port (18080, the `thaid` IdP's authorizationUrl) and its
# container-network hostname (Keycloak's backend-facing tokenUrl/jwksUrl)
# simultaneously, since both are served by the same container. The flow
# therefore always fails at Hop 1 (the browser-facing redirect), deterministically
# and safely, well before Keycloak's own backend would ever attempt (and could
# fail) a server-to-server token exchange. This test proves the browser-facing
# leg fails cleanly (a connection error, not a raw proxied 502/stack trace) —
# it does not, and with a single mock container cannot, isolate a pure
# backend-token-exchange failure. See the in-test comment for the accepted
# residual gap and what a fuller test would require.
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
  # See TS-290d's comment: drive_thaid_broker_login intentionally returns
  # non-zero here (expected outcome) — `|| true` prevents bats' implicit
  # errexit from aborting the test before the mock IdP is restarted below.
  result=$(drive_thaid_broker_login "${pid}") || true
  status=$(echo "${result}" | sed -n '1p')

  # Restart the mock IdP and wait for it to become healthy BEFORE asserting —
  # mandatory (see header note) so a failed assertion below never leaves the
  # stack poisoned for later tests/runs. Restart failure is FATAL (code
  # review finding: previously both `docker compose start` and
  # `wait_for_healthy` were `|| true` with no downstream check at all, so a
  # broken restore could go unnoticed and silently poison every subsequent
  # test/run — the exact hazard this test's own header comment warns about).
  local restart_ok=1 healthy_ok=1
  docker compose -f "${PROJECT_ROOT}/compose.yaml" start mock-oidc-provider >/dev/null 2>&1 || restart_ok=0
  wait_for_healthy mock-oidc-provider 60 || healthy_ok=0

  # Code review finding: `mock-oidc-provider` serves BOTH the browser-facing
  # authorizationUrl (localhost:18080) and Keycloak's own backend-facing
  # tokenUrl/jwksUrl (container-network hostname) from the SAME container.
  # Stopping it fails the flow at Hop 1 — the browser-facing redirect target
  # becomes unreachable to curl — before Keycloak's own backend ever attempts
  # (and could fail) a token exchange. `drive_thaid_broker_login` reports
  # this deterministically via its Hop 1 failure branch ("connect_error", or
  # "no_thaid_redirect" if a redirect partially resolves before failing).
  # This test therefore proves the browser-facing leg degrades to a clean
  # connection failure rather than any raw Keycloak-proxied 5xx/stack trace —
  # it does NOT (and, with a single mock container serving both roles,
  # cannot) isolate a pure backend-token-exchange failure independent of the
  # browser-facing outage. Doing so would require either splitting the mock
  # into two independently-stoppable endpoints or container-level network
  # fault injection — out of scope for this story; documented here as a
  # known, accepted residual gap rather than left as an implicit assumption
  # the previous "anything but 200/502" assertion silently relied on.
  if [[ "${status}" != "connect_error" && "${status}" != "no_thaid_redirect" ]]; then
    fail "Expected a deterministic Hop-1 connection-failure marker (connect_error/no_thaid_redirect) when the mock IdP is unreachable, got '${status}'"
  fi

  [[ "${restart_ok}" == "1" ]] || fail "Could not restart mock-oidc-provider after TS-290h — stack may be left in a poisoned state for subsequent tests/runs"
  [[ "${healthy_ok}" == "1" ]] || fail "mock-oidc-provider did not become healthy within 60s after TS-290h restart — stack may be left in a poisoned state for subsequent tests/runs"
}
