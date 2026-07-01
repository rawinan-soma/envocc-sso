#!/usr/bin/env bats
# tests/integration/account-disable.bats
# ATDD integration tests — Story 2.8: Disable blocks authentication & revokes sessions
#
# AC1 (FR25): Given an account set to disabled (enabled: false), when it attempts to
#             authenticate at any integrated app (any registered OIDC client in the
#             realm), then all new authentication is blocked immediately — the token
#             endpoint rejects password/ROPC grant with an error, and no new
#             authorization code can be exchanged for tokens on behalf of that user,
#             across every client, not just one.
#
# AC2 (FR46): Given an account is disabled, when the transition completes
#             (PUT /admin/realms/envocc/users/{id} with {"enabled": false}), then all
#             outstanding refresh-token families for that subject are revoked and all
#             server-side SSO sessions for that subject are invalidated (the Admin
#             REST API reports zero active sessions for the user immediately after
#             disable + POST /users/{id}/logout).
#
# Test scenarios covered:
#   TS-280a [P0] Active user can authenticate (control/baseline)
#   TS-280b [P0] Disabled account cannot obtain a new token via ROPC/password grant (AC1)
#   TS-280c [P1] enabled:false is a user-level field with no per-client scoping (AC1)
#   TS-280d [P1] Re-enabling restores authentication
#   TS-280e [P0] A previously-issued refresh token stops working after disable+logout (AC2)
#   TS-280f [P0] Admin REST reports zero active sessions after disable+logout (AC2)
#   TS-280g [P1] enabled:false alone (without /logout) does NOT retroactively kill a session
#   TS-280h [P1] POST /users/{id}/logout is idempotent on a user with zero sessions
#
# IMPORTANT: All tests in this file require a live Keycloak stack.
# They are skipped unless the INTEGRATION environment variable is set.
# To run: INTEGRATION=1 bats tests/integration/account-disable.bats
#
# Pre-requisites:
#   1. docker compose up --build (stack healthy, realm imported)
#   2. test-ropc-client present in keycloak/realm-export.json (Story 2.8 Task 0 —
#      NOT present at this story's baseline; every ROPC-based test below (all
#      except TS-280h) will fail red until Task 0 re-adds it. This is the expected
#      RED PHASE for this story: the built-in Keycloak disable/revoke behavior this
#      file proves is real, but the test fixture it depends on is missing.)
#   3. KC_TEST_ROPC_CLIENT_SECRET in .env (see .env.example)
#   4. BATS_LIB_PATH=$(pwd)/tests/lib bats tests/integration/account-disable.bats

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Per-test cleanup state.
# Each test stores its created user UUID here immediately after creation.
# teardown() deletes any stored user to prevent state pollution between tests.
# Prefix variable names with the test ID to avoid collisions.
# ---------------------------------------------------------------------------
_TS280A_USER_ID=""
_TS280B_USER_ID=""
_TS280C_USER_ID=""
_TS280D_USER_ID=""
_TS280E_USER_ID=""
_TS280F_USER_ID=""
_TS280G_USER_ID=""
_TS280H_USER_ID=""

# ---------------------------------------------------------------------------
# Suite setup: handled by tests/integration/setup_suite.bash (BATS 1.5+ companion).
# Per-test: guard against non-INTEGRATION runs.
# ---------------------------------------------------------------------------

setup() {
  if [[ -z "${INTEGRATION}" ]]; then
    skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"
  fi
  # Reset per-test cleanup variables at the top of every test
  _TS280A_USER_ID=""
  _TS280B_USER_ID=""
  _TS280C_USER_ID=""
  _TS280D_USER_ID=""
  _TS280E_USER_ID=""
  _TS280F_USER_ID=""
  _TS280G_USER_ID=""
  _TS280H_USER_ID=""
}

# ---------------------------------------------------------------------------
# teardown: delete any test user created in the active test.
# Runs after EVERY test (pass or fail) to ensure cleanup even on assertion failure.
# Deleting the user also removes any residual server-side sessions Keycloak
# still associates with them.
# ---------------------------------------------------------------------------
teardown() {
  local ids=(
    "${_TS280A_USER_ID}"
    "${_TS280B_USER_ID}"
    "${_TS280C_USER_ID}"
    "${_TS280D_USER_ID}"
    "${_TS280E_USER_ID}"
    "${_TS280F_USER_ID}"
    "${_TS280G_USER_ID}"
    "${_TS280H_USER_ID}"
  )
  # Fetch admin token lazily on first non-empty ID and reuse for all subsequent
  # deletes — avoids a redundant token round-trip per user in multi-user tests.
  local token="" id
  for id in "${ids[@]}"; do
    if [[ -n "${id}" ]]; then
      [[ -n "${token}" ]] || token=$(get_admin_token 2>/dev/null) || true
      if [[ -n "${token}" ]]; then
        curl -sf -X DELETE \
          -H "Authorization: Bearer ${token}" \
          "http://localhost:8080/admin/realms/envocc/users/${id}" \
          2>/dev/null || true
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# Shared per-test setup helpers.
#
# TS-280a/b/d/e/f/g each independently need "create an active user, set its
# password, and populate the live test-ropc-client secret from .env" — that
# ~45-line sequence was originally duplicated verbatim 6 times in this file.
# These three composable helpers replace that duplication. Per this story's
# Dev Notes ("Do not add a new shared helper function to common.bash unless a
# second story would also need it"), they are scoped locally to this file
# rather than added to tests/helpers/common.bash.
#
# IMPORTANT — subshell/`fail` interaction: each helper is invoked via command
# substitution (`x=$(_helper ...)`), which runs in a subshell. A `fail` call
# inside that subshell would only abort the subshell, NOT the enclosing
# @test — the test would silently continue with an empty/partial value. To
# avoid that class of bug, these helpers never call `fail` themselves; they
# write a diagnostic to stderr and `return 1`, and every call site follows
# the existing `x=$(...) || fail "..."` convention already used for
# `get_admin_token` elsewhere in this file/repo.
#
# `_create_active_test_user` prints the new user's UUID to stdout as soon as
# it is known (before returning), so `_TS28xx_USER_ID` can still be captured
# for teardown() cleanup even if a *later* step in a test fails.
# ---------------------------------------------------------------------------

# _create_active_test_user <token> <username> <lastname>
# Creates an enabled+emailVerified user (no password set — call
# _set_test_user_password separately if the test needs to authenticate).
# Prints the user's UUID to stdout on success.
_create_active_test_user() {
  local token="${1}" username="${2}" lastname="${3}"
  local http_status post_loc_file user_id loc

  post_loc_file=$(mktemp)
  http_status=$(curl -s -o /dev/null -w "%{http_code}" -D "${post_loc_file}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${username}\",\"email\":\"${username}\",\"enabled\":true,\"emailVerified\":true,\"firstName\":\"Test\",\"lastName\":\"${lastname}\"}" \
    "http://localhost:8080/admin/realms/envocc/users")
  if [[ "${http_status}" != "201" ]]; then
    rm -f "${post_loc_file}"
    echo "_create_active_test_user: could not create ${username} (got HTTP ${http_status})" >&2
    return 1
  fi
  loc=$(grep -i '^location:' "${post_loc_file}" | tail -n 1 | tr -d '\r' | sed -E 's/^[^:]+:[[:space:]]*//')
  rm -f "${post_loc_file}"
  user_id="${loc##*/}"
  if [[ -z "${user_id}" ]]; then
    local fallback_resp
    fallback_resp=$(curl -sf --max-time 10 \
      -H "Authorization: Bearer ${token}" \
      "http://localhost:8080/admin/realms/envocc/users?email=${username}&exact=true") || true
    user_id=$(echo "${fallback_resp}" | python3 -c "import json,sys; u=json.load(sys.stdin); print(u[0]['id'] if u else '')" 2>/dev/null || echo "")
  fi
  if [[ -z "${user_id}" ]]; then
    echo "_create_active_test_user: UUID not found for ${username} after creation" >&2
    return 1
  fi

  echo "${user_id}"
}

# _set_test_user_password <token> <user_id>
# Sets the fixed, non-temporary test password (Test!Disable123) shared by
# every ROPC-based test in this file.
_set_test_user_password() {
  local token="${1}" user_id="${2}"
  local reset_status
  reset_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"type":"password","value":"Test!Disable123","temporary":false}' \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}/reset-password")
  if [[ "${reset_status}" != "204" ]]; then
    echo "_set_test_user_password: could not set password for user ${user_id} (got HTTP ${reset_status})" >&2
    return 1
  fi
}

# _configure_ropc_client_secret <token>
# Reads KC_TEST_ROPC_CLIENT_SECRET from .env and pushes it onto the live
# test-ropc-client via PUT /clients/{id} — the realm export ships the client
# with a zeroed secret (see identity-model.bats TS-210d for pattern origin).
# Prints the secret to stdout on success.
_configure_ropc_client_secret() {
  local token="${1}"
  local ropc_secret
  ropc_secret=$(_env_value "KC_TEST_ROPC_CLIENT_SECRET")
  if [[ -z "${ropc_secret}" ]]; then
    echo "_configure_ropc_client_secret: KC_TEST_ROPC_CLIENT_SECRET not set in .env" >&2
    return 1
  fi

  local clients_json client_uuid client_rep update_status
  clients_json=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/clients?clientId=test-ropc-client") || {
    echo "_configure_ropc_client_secret: could not look up test-ropc-client — is the realm import current? (Story 2.8 Task 0)" >&2
    return 1
  }
  client_uuid=$(echo "${clients_json}" | python3 -c "import json,sys; c=json.load(sys.stdin); print(c[0]['id'] if c else '')")
  if [[ -z "${client_uuid}" ]]; then
    echo "_configure_ropc_client_secret: test-ropc-client not found in realm — re-import realm-export.json (Story 2.8 Task 0)" >&2
    return 1
  fi
  client_rep=$(echo "${clients_json}" | ROPC_SECRET="${ropc_secret}" python3 -c "import json,sys,os; c=json.load(sys.stdin)[0]; c['secret']=os.environ['ROPC_SECRET']; print(json.dumps(c))")
  update_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "${client_rep}" \
    "http://localhost:8080/admin/realms/envocc/clients/${client_uuid}")
  if [[ "${update_status}" != "204" ]]; then
    echo "_configure_ropc_client_secret: could not set test-ropc-client secret (got HTTP ${update_status})" >&2
    return 1
  fi

  echo "${ropc_secret}"
}

# ---------------------------------------------------------------------------
# TS-280a [P0] — Active user can authenticate (control/baseline)
#
# Creates a user in `active` state (enabled:true, emailVerified:true, no
# requiredActions), sets a password, and confirms ROPC login succeeds. This is
# the control that proves the subsequent disable tests (TS-280b, TS-280d) are
# meaningful — if this test itself fails, the disable-rejection tests below
# cannot be trusted (they'd "pass" for the wrong reason, e.g. client-auth
# failure rather than the disabled-account rejection under test).
#
# Requires: test-ropc-client in realm (Story 2.8 Task 0) + KC_TEST_ROPC_CLIENT_SECRET
# in .env. RED until Task 0 re-adds test-ropc-client to keycloak/realm-export.json.
# ---------------------------------------------------------------------------
@test "[P0][TS-280a] Active user can authenticate via ROPC (control/baseline)" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create active test user, set its password, and populate the live
  # test-ropc-client secret from .env (see the shared helpers above the
  # first @test in this file — the realm export ships test-ropc-client
  # with a zeroed secret; see tests/integration/identity-model.bats
  # TS-210d for the origin of this runtime-secret-population pattern).
  local user_id
  user_id=$(_create_active_test_user "${token}" "ts280a@envocc.local" "DisableCtrl")
  _TS280A_USER_ID="${user_id}"
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-280a — see stderr above"
  _set_test_user_password "${token}" "${user_id}" || fail "Could not set password for TS-280a — see stderr above"

  local ropc_secret
  ropc_secret=$(_configure_ropc_client_secret "${token}") \
    || fail "Could not configure test-ropc-client secret for TS-280a — see stderr above"

  # Attempt ROPC login — expect HTTP 200 with a non-empty access_token.
  local response status body access_token
  response=$(curl -s --max-time 10 -w $'\n%{http_code}' \
    -d "grant_type=password" \
    -d "client_id=test-ropc-client" \
    -d "client_secret=${ropc_secret}" \
    -d "username=ts280a@envocc.local" \
    -d "password=Test!Disable123" \
    "http://localhost:8080/realms/envocc/protocol/openid-connect/token")
  status=$(echo "${response}" | tail -n 1)
  body=$(echo "${response}" | sed '$d')

  assert_equal "${status}" "200"
  access_token=$(echo "${body}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
  [[ -n "${access_token}" ]] || fail "Expected non-empty access_token for active user, got body: ${body}"
}

# ---------------------------------------------------------------------------
# TS-280b [P0] — Disabled account cannot obtain a new token via ROPC/password grant (AC1)
#
# Creates and activates a user, disables it (PUT /users/{id} {"enabled": false}),
# then attempts the identical ROPC login. Asserts the token endpoint rejects the
# grant (HTTP 400/401) AND that the error content specifically indicates the
# account is disabled — not merely a non-200 status, to avoid the class of bug
# where the assertion accidentally passes for the wrong reason (e.g. a
# client-auth failure).
#
# Requires: test-ropc-client in realm (Story 2.8 Task 0). RED until Task 0.
# ---------------------------------------------------------------------------
@test "[P0][TS-280b] Disabled account cannot obtain a new token via ROPC/password grant" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create active test user, set its password, and populate the live
  # test-ropc-client secret (see the shared helpers above the first @test
  # in this file for the runtime-secret-population pattern origin).
  local user_id
  user_id=$(_create_active_test_user "${token}" "ts280b@envocc.local" "DisableBlock")
  _TS280B_USER_ID="${user_id}"
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-280b — see stderr above"
  _set_test_user_password "${token}" "${user_id}" || fail "Could not set password for TS-280b — see stderr above"

  local ropc_secret
  ropc_secret=$(_configure_ropc_client_secret "${token}") \
    || fail "Could not configure test-ropc-client secret for TS-280b — see stderr above"

  # Disable the account
  local disable_status
  disable_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"enabled":false}' \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}")
  [[ "${disable_status}" == "204" ]] || fail "Could not disable TS-280b user (got HTTP ${disable_status})"

  # Re-attempt the identical ROPC login — must be rejected.
  local response status body access_token error_description
  response=$(curl -s --max-time 10 -w $'\n%{http_code}' \
    -d "grant_type=password" \
    -d "client_id=test-ropc-client" \
    -d "client_secret=${ropc_secret}" \
    -d "username=ts280b@envocc.local" \
    -d "password=Test!Disable123" \
    "http://localhost:8080/realms/envocc/protocol/openid-connect/token")
  status=$(echo "${response}" | tail -n 1)
  body=$(echo "${response}" | sed '$d')

  # Assert: HTTP 400 or 401 (Keycloak returns invalid_grant for a disabled account)
  if [[ "${status}" != "400" && "${status}" != "401" ]]; then
    fail "Expected HTTP 400/401 for disabled-account ROPC attempt, got HTTP ${status} — body: ${body}"
  fi

  # Assert: no access_token in the response body
  access_token=$(echo "${body}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
  [[ -z "${access_token}" ]] || fail "Expected no access_token for disabled account, but got one: ${access_token}"

  # Assert: the error content specifically indicates the account is disabled — not
  # merely a non-200 status (guards against the class of bug where this assertion
  # passes for the wrong reason, e.g. a client-auth failure).
  error_description=$(echo "${body}" | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('error_description') or d.get('error') or '').lower())" 2>/dev/null || echo "")
  case "${error_description}" in
    *disabled*) : ;; # expected
    *) fail "Expected error content to mention 'disabled', got: ${body}" ;;
  esac
}

# ---------------------------------------------------------------------------
# TS-280c [P1] — enabled:false is a user-level field with no per-client scoping (AC1)
#
# test-oidc-client has directAccessGrantsEnabled:false, so it cannot be used for a
# second ROPC-based behavioral proof, and adding a second ROPC-capable client
# purely for this test is explicit scope creep beyond Story 2.8 Task 0's fixture
# restoration (do NOT add one — see story Dev Notes). The required minimum for
# this test is the structural proof: `enabled` is a top-level field on the USER
# object with no per-client scoping anywhere in the user or client JSON shapes —
# i.e. disabling a user is realm-wide by construction, not per-client config
# (see keycloak/IDENTITY-MODEL.md Section 4).
# ---------------------------------------------------------------------------
@test "[P1][TS-280c] enabled:false is a user-level field with no per-client scoping" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create a plain active test user (state does not matter for this structural
  # check; no password/ROPC needed, so only the creation helper is used).
  local user_id
  user_id=$(_create_active_test_user "${token}" "ts280c@envocc.local" "Structural")
  _TS280C_USER_ID="${user_id}"
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-280c — see stderr above"

  # Fetch the full user object
  local user_tmpfile curl_exit
  user_tmpfile=$(mktemp)
  curl_exit=0
  curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}" > "${user_tmpfile}" \
    || curl_exit=$?
  if [[ "${curl_exit}" -ne 0 ]]; then
    rm -f "${user_tmpfile}"
    fail "Could not fetch user details (curl exited ${curl_exit})"
  fi

  # Fetch the full client list
  local clients_tmpfile
  clients_tmpfile=$(mktemp)
  curl_exit=0
  curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/clients" > "${clients_tmpfile}" \
    || curl_exit=$?
  if [[ "${curl_exit}" -ne 0 ]]; then
    rm -f "${user_tmpfile}" "${clients_tmpfile}"
    fail "Could not fetch client list (curl exited ${curl_exit})"
  fi

  # Structural assertion:
  #  1. The user object has a top-level boolean `enabled` field (realm-wide account state).
  #  2. The user object has no per-client override map keyed by client id/name.
  #  3. No client object anywhere in the realm carries a per-user enablement field
  #     (a client's own `enabled` flag is a distinct concept — the client's own
  #     registration toggle — not a scoping mechanism over individual users).
  run python3 - "${user_tmpfile}" "${clients_tmpfile}" <<'PYEOF'
import json, sys

user_file, clients_file = sys.argv[1], sys.argv[2]

with open(user_file) as f:
    user = json.load(f)
with open(clients_file) as f:
    clients = json.load(f)

if "enabled" not in user or not isinstance(user["enabled"], bool):
    print("FAIL: user object has no top-level boolean 'enabled' field")
    sys.exit(1)

# No per-client override map on the user object (e.g. a hypothetical
# "clientEnabled": {"clientId": true} shape would indicate per-client scoping).
suspect_user_keys = [k for k in user.keys() if "client" in k.lower() and "enable" in k.lower()]
if suspect_user_keys:
    print(f"FAIL: user object has suspicious per-client enablement keys: {suspect_user_keys}")
    sys.exit(1)

# No client object carries a per-user enablement field.
for client in clients:
    suspect_client_keys = [
        k for k in client.keys()
        if "user" in k.lower() and "enable" in k.lower()
    ]
    if suspect_client_keys:
        print(f"FAIL: client '{client.get('clientId')}' has suspicious per-user enablement keys: {suspect_client_keys}")
        sys.exit(1)

print("OK: enabled is a user-level field; no per-client scoping found on user or client objects")
sys.exit(0)
PYEOF
  assert_success
  rm -f "${user_tmpfile}" "${clients_tmpfile}"
}

# ---------------------------------------------------------------------------
# TS-280d [P1] — Re-enabling restores authentication
#
# Confirms disable is reversible via the same PUT /users/{id} call
# ({"enabled": true}) — a disabled account CAN be re-enabled by a future HR
# Admin action (Story 4.5 scope) — and that the disable assertion pattern used
# by TS-280b is really testing `enabled`, not some other failure mode.
#
# Requires: test-ropc-client in realm (Story 2.8 Task 0). RED until Task 0.
# ---------------------------------------------------------------------------
@test "[P1][TS-280d] Re-enabling restores authentication" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create active test user, set its password, and populate the live
  # test-ropc-client secret (see the shared helpers above the first @test
  # in this file for the runtime-secret-population pattern origin).
  local user_id
  user_id=$(_create_active_test_user "${token}" "ts280d@envocc.local" "ReEnable")
  _TS280D_USER_ID="${user_id}"
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-280d — see stderr above"
  _set_test_user_password "${token}" "${user_id}" || fail "Could not set password for TS-280d — see stderr above"

  local ropc_secret
  ropc_secret=$(_configure_ropc_client_secret "${token}") \
    || fail "Could not configure test-ropc-client secret for TS-280d — see stderr above"

  # Disable, confirm rejection
  local disable_status
  disable_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"enabled":false}' \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}")
  [[ "${disable_status}" == "204" ]] || fail "Could not disable TS-280d user (got HTTP ${disable_status})"

  local disabled_status
  disabled_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -d "grant_type=password" \
    -d "client_id=test-ropc-client" \
    -d "client_secret=${ropc_secret}" \
    -d "username=ts280d@envocc.local" \
    -d "password=Test!Disable123" \
    "http://localhost:8080/realms/envocc/protocol/openid-connect/token")
  if [[ "${disabled_status}" != "400" && "${disabled_status}" != "401" ]]; then
    fail "Expected disabled-account ROPC attempt to be rejected (400/401), got HTTP ${disabled_status}"
  fi

  # Re-enable the account
  local reenable_status
  reenable_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"enabled":true}' \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}")
  [[ "${reenable_status}" == "204" ]] || fail "Could not re-enable TS-280d user (got HTTP ${reenable_status})"

  # Re-attempt ROPC login — must now succeed with a valid access_token
  local response status body access_token
  response=$(curl -s --max-time 10 -w $'\n%{http_code}' \
    -d "grant_type=password" \
    -d "client_id=test-ropc-client" \
    -d "client_secret=${ropc_secret}" \
    -d "username=ts280d@envocc.local" \
    -d "password=Test!Disable123" \
    "http://localhost:8080/realms/envocc/protocol/openid-connect/token")
  status=$(echo "${response}" | tail -n 1)
  body=$(echo "${response}" | sed '$d')

  assert_equal "${status}" "200"
  access_token=$(echo "${body}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
  [[ -n "${access_token}" ]] || fail "Expected non-empty access_token after re-enabling, got body: ${body}"
}

# ---------------------------------------------------------------------------
# TS-280e [P0] — A previously-issued refresh token stops working after disable+logout (AC2)
#
# Captures both access_token and refresh_token from a successful ROPC login
# (Story 2.4 config guarantees a refresh_token is issued and rotates on use —
# revokeRefreshToken:true, refreshTokenMaxReuse:0). Disables the user, then
# immediately calls POST /users/{id}/logout (the Story 2.8 Task 2 two-call
# procedure), then attempts to use the captured refresh_token. Asserts the
# token endpoint rejects it — direct proof of FR46's "revokes all outstanding
# refresh-token families."
#
# KNOWN LIMITATION (code review): this test alone cannot structurally isolate
# "rejected because the /logout revocation kicked in" (FR46) from "rejected
# because the user is disabled" (FR25) — Keycloak's `enabled` gate on the
# refresh grant is checked ahead of any session/family lookup, so the refresh
# attempt would also be rejected here even if /logout were a no-op. This
# combined disable+logout sequence matches AC2's own given/when ("Given an
# account is disabled, when the transition completes") and is the procedure
# Task 2 documents as mandatory, so it remains the correct test for that
# combined claim. The isolated "disable alone does not revoke" half of the
# claim (i.e. that /logout — not `enabled: false` — is what does the actual
# session/family revocation) is proven independently on the *session* side by
# TS-280g below; there is no equivalent independent proof for the *refresh
# token* side because the token endpoint itself cannot be used to observe
# that distinction (the enabled-check pre-empts it either way).
#
# Requires: test-ropc-client in realm (Story 2.8 Task 0). RED until Task 0.
# ---------------------------------------------------------------------------
@test "[P0][TS-280e] Refresh token stops working after disable+logout" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create active test user, set its password, and populate the live
  # test-ropc-client secret (see the shared helpers above the first @test
  # in this file for the runtime-secret-population pattern origin).
  local user_id
  user_id=$(_create_active_test_user "${token}" "ts280e@envocc.local" "RefreshRevoke")
  _TS280E_USER_ID="${user_id}"
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-280e — see stderr above"
  _set_test_user_password "${token}" "${user_id}" || fail "Could not set password for TS-280e — see stderr above"

  local ropc_secret
  ropc_secret=$(_configure_ropc_client_secret "${token}") \
    || fail "Could not configure test-ropc-client secret for TS-280e — see stderr above"

  # Authenticate and capture both access_token and refresh_token
  local login_response login_status login_body refresh_token
  login_response=$(curl -s --max-time 10 -w $'\n%{http_code}' \
    -d "grant_type=password" \
    -d "client_id=test-ropc-client" \
    -d "client_secret=${ropc_secret}" \
    -d "username=ts280e@envocc.local" \
    -d "password=Test!Disable123" \
    "http://localhost:8080/realms/envocc/protocol/openid-connect/token")
  login_status=$(echo "${login_response}" | tail -n 1)
  login_body=$(echo "${login_response}" | sed '$d')
  [[ "${login_status}" == "200" ]] || fail "Could not authenticate TS-280e user before disable (got HTTP ${login_status})"
  refresh_token=$(echo "${login_body}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('refresh_token',''))" 2>/dev/null || echo "")
  [[ -n "${refresh_token}" ]] || fail "No refresh_token in ROPC login response — Story 2.4 revokeRefreshToken config not active?"

  # Disable the account (Story 2.8 Task 2 procedure, step 1)
  local disable_status
  disable_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"enabled":false}' \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}")
  [[ "${disable_status}" == "204" ]] || fail "Could not disable TS-280e user (got HTTP ${disable_status})"

  # Force-invalidate sessions and revoke refresh tokens (Story 2.8 Task 2 procedure, step 2)
  local logout_status
  logout_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}/logout")
  [[ "${logout_status}" == "204" ]] || fail "Could not force-logout TS-280e user (got HTTP ${logout_status})"

  # Attempt to use the captured refresh token — must be rejected
  local refresh_response refresh_status refresh_body
  refresh_response=$(curl -s --max-time 10 -w $'\n%{http_code}' \
    -d "grant_type=refresh_token" \
    -d "client_id=test-ropc-client" \
    -d "client_secret=${ropc_secret}" \
    -d "refresh_token=${refresh_token}" \
    "http://localhost:8080/realms/envocc/protocol/openid-connect/token")
  refresh_status=$(echo "${refresh_response}" | tail -n 1)
  refresh_body=$(echo "${refresh_response}" | sed '$d')

  if [[ "${refresh_status}" != "400" && "${refresh_status}" != "401" ]]; then
    fail "Expected HTTP 400/401 for revoked refresh token, got HTTP ${refresh_status} — body: ${refresh_body}"
  fi
  echo "${refresh_body}" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('error') == 'invalid_grant', f'unexpected error: {d}'" \
    || fail "Expected error=invalid_grant for revoked refresh token, got: ${refresh_body}"
}

# ---------------------------------------------------------------------------
# TS-280f [P0] — Admin REST reports zero active sessions after disable+logout (AC2)
#
# Confirms GET /admin/realms/envocc/users/{id}/sessions returns an empty array
# immediately after disable + POST /users/{id}/logout — direct proof of FR46's
# "invalidates all server-side sessions for that subject."
#
# Asserts a non-empty session list right after login, BEFORE disable+logout —
# without this, a zero-session assertion afterward would pass vacuously (for
# the wrong reason) if ROPC direct-grant ever stopped creating a visible
# session at all, the exact "passes for the wrong reason" failure mode TS-280b
# guards against for the token-endpoint error content (code review finding).
#
# Requires: test-ropc-client in realm (Story 2.8 Task 0). RED until Task 0.
# ---------------------------------------------------------------------------
@test "[P0][TS-280f] Admin REST reports zero active sessions after disable+logout" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create active test user, set its password, and populate the live
  # test-ropc-client secret (see the shared helpers above the first @test
  # in this file for the runtime-secret-population pattern origin).
  local user_id
  user_id=$(_create_active_test_user "${token}" "ts280f@envocc.local" "SessionsZero")
  _TS280F_USER_ID="${user_id}"
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-280f — see stderr above"
  _set_test_user_password "${token}" "${user_id}" || fail "Could not set password for TS-280f — see stderr above"

  local ropc_secret
  ropc_secret=$(_configure_ropc_client_secret "${token}") \
    || fail "Could not configure test-ropc-client secret for TS-280f — see stderr above"

  # Authenticate to establish a server-side session
  local login_status
  login_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -d "grant_type=password" \
    -d "client_id=test-ropc-client" \
    -d "client_secret=${ropc_secret}" \
    -d "username=ts280f@envocc.local" \
    -d "password=Test!Disable123" \
    "http://localhost:8080/realms/envocc/protocol/openid-connect/token")
  [[ "${login_status}" == "200" ]] || fail "Could not authenticate TS-280f user before disable (got HTTP ${login_status})"

  # Baseline: confirm a server-side session actually exists post-login, BEFORE
  # disable+logout — see test header note on why this guards against a vacuous
  # zero-session pass below.
  local baseline_sessions_json baseline_session_count
  baseline_sessions_json=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}/sessions") \
    || fail "Could not GET baseline sessions for TS-280f user"
  baseline_session_count=$(echo "${baseline_sessions_json}" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "")
  [[ "${baseline_session_count}" =~ ^[0-9]+$ ]] || fail "Could not parse baseline session count — got: ${baseline_sessions_json}"
  [[ "${baseline_session_count}" -gt 0 ]] || fail "Expected a non-empty session list immediately after login (baseline), got zero — the zero-session assertion after disable+logout below would be meaningless without this baseline"

  # Disable + force-logout (Story 2.8 Task 2 two-call procedure)
  local disable_status logout_status
  disable_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"enabled":false}' \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}")
  [[ "${disable_status}" == "204" ]] || fail "Could not disable TS-280f user (got HTTP ${disable_status})"

  logout_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}/logout")
  [[ "${logout_status}" == "204" ]] || fail "Could not force-logout TS-280f user (got HTTP ${logout_status})"

  # Assert zero active sessions
  local sessions_json session_count
  sessions_json=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}/sessions") \
    || fail "Could not GET sessions for TS-280f user"
  session_count=$(echo "${sessions_json}" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "")
  [[ "${session_count}" =~ ^[0-9]+$ ]] || fail "Could not parse session count after disable+logout — got: ${sessions_json}"
  assert_equal "${session_count}" "0"
}

# ---------------------------------------------------------------------------
# TS-280g [P1] — enabled:false alone (without /logout) does NOT retroactively kill a session
#
# This is a documentation-proving test: it demonstrates why the Story 2.8 Task 2
# two-call procedure is mandatory, not optional, and guards against a future
# regression where someone "simplifies" the disable procedure to a single PUT
# call. Deliberately skips POST /users/{id}/logout and asserts the session list
# is still non-empty, then cleans up by calling /logout before teardown deletes
# the user (avoids leaking a live session past the test).
#
# Requires: test-ropc-client in realm (Story 2.8 Task 0). RED until Task 0.
# ---------------------------------------------------------------------------
@test "[P1][TS-280g] enabled:false alone (without /logout) does NOT retroactively kill a session" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create active test user, set its password, and populate the live
  # test-ropc-client secret (see the shared helpers above the first @test
  # in this file for the runtime-secret-population pattern origin).
  local user_id
  user_id=$(_create_active_test_user "${token}" "ts280g@envocc.local" "NoRetroactive")
  _TS280G_USER_ID="${user_id}"
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-280g — see stderr above"
  _set_test_user_password "${token}" "${user_id}" || fail "Could not set password for TS-280g — see stderr above"

  local ropc_secret
  ropc_secret=$(_configure_ropc_client_secret "${token}") \
    || fail "Could not configure test-ropc-client secret for TS-280g — see stderr above"

  # Authenticate to establish a server-side session
  local login_status
  login_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -d "grant_type=password" \
    -d "client_id=test-ropc-client" \
    -d "client_secret=${ropc_secret}" \
    -d "username=ts280g@envocc.local" \
    -d "password=Test!Disable123" \
    "http://localhost:8080/realms/envocc/protocol/openid-connect/token")
  [[ "${login_status}" == "200" ]] || fail "Could not authenticate TS-280g user before disable (got HTTP ${login_status})"

  # Disable ONLY — deliberately skip the /logout call
  local disable_status
  disable_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"enabled":false}' \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}")
  [[ "${disable_status}" == "204" ]] || fail "Could not disable TS-280g user (got HTTP ${disable_status})"

  # Assert: session list is STILL non-empty — enabled:false alone does not
  # auto-terminate sessions. This proves the two-call procedure (Task 2) is
  # mandatory, not optional.
  local sessions_json session_count
  sessions_json=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}/sessions") \
    || fail "Could not GET sessions for TS-280g user"
  session_count=$(echo "${sessions_json}" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "")
  [[ "${session_count}" =~ ^[0-9]+$ ]] || fail "Could not parse session count after enabled:false-only — got: ${sessions_json}"
  if [[ "${session_count}" == "0" ]]; then
    fail "Expected a non-empty session list after enabled:false alone (without /logout), but got zero sessions — this would mean Keycloak auto-terminates sessions on disable, contradicting the documented two-call procedure (Story 2.8 Task 2)"
  fi

  # Cleanup: force-logout before teardown deletes the user, to avoid leaking a
  # live session past this test (per story Task 4.3 instruction).
  curl -s -o /dev/null --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}/logout" || true
}

# ---------------------------------------------------------------------------
# TS-280h [P1] — POST /users/{id}/logout is idempotent on a user with zero sessions
#
# A future HR Admin "disable" action must be safe to call even on a `pending`
# account that never logged in. Calls POST /users/{id}/logout twice in a row
# on a freshly created (never-authenticated) test user and asserts both calls
# return 204 with no error.
#
# Does NOT require test-ropc-client — no ROPC login is attempted in this test.
# This test can pass even before Story 2.8 Task 0 restores the ROPC fixture.
# ---------------------------------------------------------------------------
@test "[P1][TS-280h] POST /users/{id}/logout is idempotent on a user with zero sessions" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create a fresh, never-authenticated test user (no password/ROPC needed,
  # so only the creation helper is used).
  local user_id
  user_id=$(_create_active_test_user "${token}" "ts280h@envocc.local" "IdempotentLogout")
  _TS280H_USER_ID="${user_id}"
  [[ -n "${user_id}" ]] || fail "Could not create test user TS-280h — see stderr above"

  # First /logout call — user has never authenticated, zero sessions
  local first_status
  first_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}/logout")
  assert_equal "${first_status}" "204"

  # Second /logout call, back-to-back — must also return 204, no error
  local second_status
  second_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}/logout")
  assert_equal "${second_status}" "204"
}
