#!/usr/bin/env bats
# tests/integration/identity-model.bats
# ATDD integration tests — Story 2.1: Canonical identity model & lifecycle states
#
# AC1: Given the realm user model, when an identity is created,
#      then it carries a stable internal subject (UUID `sub`, never reused) and
#      a unique work email as the reconciliation key; the realm rejects duplicate emails.
#
# AC2: Given data-minimization rules, when user attributes are inspected via the
#      Admin REST API, then only the allowed minimal set (username, email, firstName,
#      lastName) is stored; no national ID, date of birth, or other PDPA §26 sensitive
#      fields are present on the user record.
#
# AC3: Given the lifecycle, when an identity changes state,
#      then it moves only through `pending` → `active` → `disabled` via controlled
#      transitions, and a user in `pending` state cannot authenticate.
#
# Test scenarios covered:
#   TS-210a [P2] Stable sub — same user, same UUID across calls; UUID not recycled after deletion
#   TS-210b [P2] Email uniqueness enforced — duplicate email POST returns HTTP 409
#   TS-210c [P2] Data minimization — no PDPA §26 sensitive fields in user attributes
#   TS-210d [P2] Pending state blocks login — ROPC token endpoint returns HTTP 400
#   TS-210e [P2] No PDPA §26 attributes on freshly created user (clean-creation invariant)
#
# IMPORTANT: All tests in this file require a live Keycloak stack.
# They are skipped unless the INTEGRATION environment variable is set.
# To run: INTEGRATION=1 bats tests/integration/identity-model.bats
# Pre-requisites:
#   1. docker compose up --build (stack healthy, realm imported with test-ropc-client)
#   2. KC_TEST_ROPC_CLIENT_SECRET in .env (see .env.example)
#   3. BATS_LIB_PATH=$(pwd)/tests/lib bats tests/integration/identity-model.bats

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Per-test cleanup state.
# Each test stores its created user UUID here immediately after creation.
# teardown() deletes any stored user to prevent state pollution between tests.
# Prefix variable names with the test ID to avoid collisions.
# ---------------------------------------------------------------------------
_TS210A_USER_ID=""
_TS210B_USER_ID=""
_TS210C_USER_ID=""
_TS210D_USER_ID=""
_TS210E_USER_ID=""

# ---------------------------------------------------------------------------
# Suite setup: handled by tests/integration/setup_suite.bash (BATS 1.5+ companion).
# Per-test: guard against non-INTEGRATION runs.
# ---------------------------------------------------------------------------

setup() {
  if [[ -z "${INTEGRATION}" ]]; then
    skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"
  fi
  # Reset per-test cleanup variables at the top of every test
  _TS210A_USER_ID=""
  _TS210B_USER_ID=""
  _TS210C_USER_ID=""
  _TS210D_USER_ID=""
  _TS210E_USER_ID=""
}

# ---------------------------------------------------------------------------
# teardown: delete any test user created in the active test.
# Runs after EVERY test (pass or fail) to ensure cleanup even on assertion failure.
# ---------------------------------------------------------------------------
teardown() {
  local ids=(
    "${_TS210A_USER_ID}"
    "${_TS210B_USER_ID}"
    "${_TS210C_USER_ID}"
    "${_TS210D_USER_ID}"
    "${_TS210E_USER_ID}"
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
# TS-210a [P2] — Stable sub: same UUID across calls; UUID not recycled after deletion (AC1)
#
# Validates FR21: Keycloak user `id` is a UUID permanently bound to an identity.
# After deletion, re-creating a user with the same email yields a NEW UUID.
#
# Activate when: Task 3.2 — after realm user-profile config is applied (Task 1).
# ---------------------------------------------------------------------------
@test "[P2][TS-210a] Stable sub — same user returns same UUID across calls; UUID not recycled after deletion" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token — check KC_BOOTSTRAP_ADMIN_* in .env"

  # Create test user with allowed fields only
  local http_status
  http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"username":"ts210a@envocc.local","email":"ts210a@envocc.local","enabled":true,"emailVerified":true,"firstName":"Test","lastName":"StableSub"}' \
    "http://localhost:8080/admin/realms/envocc/users")
  [[ "${http_status}" == "201" ]] || fail "Could not create test user TS-210a (got HTTP ${http_status})"

  # GET user by email — first call
  local get1_response id1
  get1_response=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users?email=ts210a@envocc.local&exact=true") \
    || fail "Could not GET user by email (first call)"
  id1=$(echo "${get1_response}" | python3 -c "import json,sys; users=json.load(sys.stdin); print(users[0]['id'] if users else '')")
  [[ -n "${id1}" ]] || fail "User TS-210a not found after creation"
  _TS210A_USER_ID="${id1}"

  # GET user by email — second call (must return the same UUID; stable sub invariant)
  local get2_response id2
  get2_response=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users?email=ts210a@envocc.local&exact=true") \
    || fail "Could not GET user by email (second call)"
  id2=$(echo "${get2_response}" | python3 -c "import json,sys; users=json.load(sys.stdin); print(users[0]['id'] if users else '')")

  # Assert: UUID is identical on repeated GETs (stable sub)
  assert_equal "${id1}" "${id2}"

  # Delete the user
  curl -sf -X DELETE \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/users/${id1}" || fail "Could not DELETE test user TS-210a"
  _TS210A_USER_ID=""  # already deleted — skip teardown for this variable

  # Re-create a new user with the same email (different username to avoid username collision).
  # Capture the Keycloak-assigned UUID from the Location response header immediately —
  # this guarantees a teardown cleanup handle even if a subsequent assertion fails.
  local recreate_status recreate_loc_file
  recreate_loc_file=$(mktemp)
  recreate_status=$(curl -s -o /dev/null -w "%{http_code}" -D "${recreate_loc_file}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"username":"ts210a-v2@envocc.local","email":"ts210a@envocc.local","enabled":true,"emailVerified":true,"firstName":"Test","lastName":"StableSubV2"}' \
    "http://localhost:8080/admin/realms/envocc/users")
  # Extract UUID from the Location header (last path segment of the URL).
  # Strip the header name case-agnostically (everything up to and including the
  # first colon + whitespace), so a differently-cased "Location" still parses.
  local new_location id3
  new_location=$(grep -i '^location:' "${recreate_loc_file}" | tail -n 1 | tr -d '\r' | sed -E 's/^[^:]+:[[:space:]]*//')
  rm -f "${recreate_loc_file}"
  id3="${new_location##*/}"
  # Fallback: if the header was absent/unparseable, recover the UUID via GET-by-email
  # so teardown always has a cleanup handle and the next run isn't poisoned by a leak.
  if [[ "${recreate_status}" == "201" && -z "${id3}" ]]; then
    local recovery
    recovery=$(curl -sf --max-time 10 \
      -H "Authorization: Bearer ${token}" \
      "http://localhost:8080/admin/realms/envocc/users?email=ts210a@envocc.local&exact=true") || true
    id3=$(echo "${recovery}" | python3 -c "import json,sys; u=json.load(sys.stdin); print(u[0]['id'] if u else '')" 2>/dev/null || echo "")
  fi
  _TS210A_USER_ID="${id3}"  # register for teardown cleanup BEFORE asserting
  [[ "${recreate_status}" == "201" ]] && [[ -n "${id3}" ]] \
    || fail "Could not re-create user with same email TS-210a-v2 (got HTTP ${recreate_status})"

  # Assert: new user has a DIFFERENT UUID — UUIDs are not recycled after deletion (FR21)
  if [[ "${id1}" == "${id3}" ]]; then
    fail "UUID was recycled after deletion — FR21 violated! Expected new UUID but got same: ${id3}"
  fi
}

# ---------------------------------------------------------------------------
# TS-210b [P2] — Email uniqueness enforced: duplicate email POST returns HTTP 409 (AC1)
#
# Validates FR22: duplicateEmailsAllowed=false enforced at the realm level.
# Admin REST returns HTTP 409 Conflict when a second user with the same email
# is created, even with a different username.
#
# Activate when: Task 3.3 — after duplicateEmailsAllowed:false verified in realm (Task 1.8).
# ---------------------------------------------------------------------------
@test "[P2][TS-210b] Email uniqueness enforced — duplicate email POST returns HTTP 409 Conflict" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create first user with a unique test email
  # Capture UUID from the POST Location header immediately — guarantees a teardown
  # cleanup handle even if a subsequent GET-by-email fails (confirmed leak path: if
  # GET fails, _TS210B_USER_ID stays "", teardown skips, test-dupe@envocc.local leaks
  # and poisons the next run with a 409 on the first POST).
  local http_status post_loc_file b_loc
  post_loc_file=$(mktemp)
  http_status=$(curl -s -o /dev/null -w "%{http_code}" -D "${post_loc_file}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"username":"ts210b-first@envocc.local","email":"test-dupe@envocc.local","enabled":true,"emailVerified":true,"firstName":"First","lastName":"Dupe"}' \
    "http://localhost:8080/admin/realms/envocc/users")
  [[ "${http_status}" == "201" ]] || { rm -f "${post_loc_file}"; fail "Could not create first test user TS-210b (got HTTP ${http_status})"; }
  b_loc=$(grep -i '^location:' "${post_loc_file}" | tail -n 1 | tr -d '\r' | sed -E 's/^[^:]+:[[:space:]]*//')
  rm -f "${post_loc_file}"
  _TS210B_USER_ID="${b_loc##*/}"
  # Fallback: if Location header was absent or unparseable, recover UUID via GET-by-email
  if [[ -z "${_TS210B_USER_ID}" ]]; then
    local fallback_resp
    fallback_resp=$(curl -sf --max-time 10 \
      -H "Authorization: Bearer ${token}" \
      "http://localhost:8080/admin/realms/envocc/users?email=test-dupe@envocc.local&exact=true") || true
    _TS210B_USER_ID=$(echo "${fallback_resp}" | python3 -c "import json,sys; u=json.load(sys.stdin); print(u[0]['id'] if u else '')" 2>/dev/null || echo "")
  fi

  # Attempt to create a second user with the same email — must return HTTP 409 Conflict
  local dupe_status
  dupe_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"username":"ts210b-second@envocc.local","email":"test-dupe@envocc.local","enabled":true,"emailVerified":true,"firstName":"Second","lastName":"Dupe"}' \
    "http://localhost:8080/admin/realms/envocc/users")

  # Assert: Keycloak enforces email uniqueness with HTTP 409
  assert_equal "${dupe_status}" "409"
}

# ---------------------------------------------------------------------------
# TS-210c [P2] — Data minimization: no PDPA §26 sensitive fields in user attributes (AC2)
#
# Validates FR23: creating a user with only allowed fields (username, email, firstName,
# lastName) must not populate sensitive attributes. Checks for PDPA §26 forbidden fields.
#
# Activate when: Task 3.4 — after Declarative User Profile config applied (Task 1.3/1.4).
# ---------------------------------------------------------------------------
@test "[P2][TS-210c] Data minimization — no PDPA §26 sensitive fields in user attributes after creation" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create user with only the four allowed fields (minimal attribute set)
  # Capture UUID from Location header immediately for teardown cleanup.
  local http_status post_loc_file user_id c_loc
  post_loc_file=$(mktemp)
  http_status=$(curl -s -o /dev/null -w "%{http_code}" -D "${post_loc_file}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"username":"ts210c@envocc.local","email":"ts210c@envocc.local","enabled":true,"emailVerified":true,"firstName":"Test","lastName":"DataMin"}' \
    "http://localhost:8080/admin/realms/envocc/users")
  [[ "${http_status}" == "201" ]] || { rm -f "${post_loc_file}"; fail "Could not create test user TS-210c (got HTTP ${http_status})"; }
  c_loc=$(grep -i '^location:' "${post_loc_file}" | tail -n 1 | tr -d '\r' | sed -E 's/^[^:]+:[[:space:]]*//')
  rm -f "${post_loc_file}"
  user_id="${c_loc##*/}"
  # Fallback: if Location header was absent or unparseable, recover UUID via GET-by-email
  if [[ -z "${user_id}" ]]; then
    local fallback_resp
    fallback_resp=$(curl -sf --max-time 10 \
      -H "Authorization: Bearer ${token}" \
      "http://localhost:8080/admin/realms/envocc/users?email=ts210c@envocc.local&exact=true") || true
    user_id=$(echo "${fallback_resp}" | python3 -c "import json,sys; u=json.load(sys.stdin); print(u[0]['id'] if u else '')" 2>/dev/null || echo "")
  fi
  [[ -n "${user_id}" ]] || fail "User TS-210c UUID not found after creation"
  _TS210C_USER_ID="${user_id}"

  # Fetch full user object via GET /users/{id}
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

  # Assert: no PDPA §26 sensitive fields in the attributes map.
  # Uses shared helper from tests/helpers/common.bash — single source of truth
  # for the forbidden field list (FR23/NFR12).
  run check_no_pdpa_sensitive_attrs "${user_tmpfile}"
  # Assert first so test output shows failure context; then clean up temp file
  assert_success
  rm -f "${user_tmpfile}"
}

# ---------------------------------------------------------------------------
# TS-210d [P2] — Pending state blocks login: ROPC returns HTTP 400 (AC3)
#
# Validates FR24: a user in `pending` state (enabled:true, emailVerified:false,
# requiredActions:[VERIFY_EMAIL]) cannot authenticate via ROPC.
# Keycloak returns HTTP 400 (not 200) because VERIFY_EMAIL required action is pending.
#
# Requires: test-ropc-client in realm (Task 1.5) + KC_TEST_ROPC_CLIENT_SECRET in .env.
#
# Activate when: Task 3.5 — after test-ropc-client added to realm (Task 1.5) and
# KC_TEST_ROPC_CLIENT_SECRET set in .env.example (Task 1.6).
# ---------------------------------------------------------------------------
@test "[P2][TS-210d] Pending state blocks login — ROPC token endpoint returns HTTP 400 for emailVerified:false user" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create user in pending state:
  #   enabled: true  — user exists
  #   emailVerified: false — activation not completed
  #   requiredActions: [VERIFY_EMAIL] — Keycloak enforces email verification before login
  # Capture UUID from Location header immediately for password reset and teardown.
  local http_status post_loc_file user_id d_loc
  post_loc_file=$(mktemp)
  http_status=$(curl -s -o /dev/null -w "%{http_code}" -D "${post_loc_file}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"username":"ts210d@envocc.local","email":"ts210d@envocc.local","enabled":true,"emailVerified":false,"requiredActions":["VERIFY_EMAIL"],"firstName":"Test","lastName":"Pending"}' \
    "http://localhost:8080/admin/realms/envocc/users")
  [[ "${http_status}" == "201" ]] || { rm -f "${post_loc_file}"; fail "Could not create pending test user TS-210d (got HTTP ${http_status})"; }
  d_loc=$(grep -i '^location:' "${post_loc_file}" | tail -n 1 | tr -d '\r' | sed -E 's/^[^:]+:[[:space:]]*//')
  rm -f "${post_loc_file}"
  user_id="${d_loc##*/}"
  # Fallback: if Location header was absent or unparseable, recover UUID via GET-by-email
  if [[ -z "${user_id}" ]]; then
    local fallback_resp
    fallback_resp=$(curl -sf --max-time 10 \
      -H "Authorization: Bearer ${token}" \
      "http://localhost:8080/admin/realms/envocc/users?email=ts210d@envocc.local&exact=true") || true
    user_id=$(echo "${fallback_resp}" | python3 -c "import json,sys; u=json.load(sys.stdin); print(u[0]['id'] if u else '')" 2>/dev/null || echo "")
  fi
  [[ -n "${user_id}" ]] || fail "Pending user TS-210d UUID not found after creation"
  _TS210D_USER_ID="${user_id}"

  # Set a non-temporary password on the pending user.
  # ROPC requires a password to attempt authentication; this lets us verify the
  # pending-state block independently of "no credentials" rejection.
  local reset_status
  reset_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"type":"password","value":"Test!Pending123","temporary":false}' \
    "http://localhost:8080/admin/realms/envocc/users/${user_id}/reset-password")
  [[ "${reset_status}" == "204" ]] || fail "Could not set password for pending user TS-210d (got HTTP ${reset_status})"

  # Read ROPC client secret from .env (never hardcoded)
  local ropc_secret
  ropc_secret=$(_env_value "KC_TEST_ROPC_CLIENT_SECRET")
  [[ -n "${ropc_secret}" ]] || fail "KC_TEST_ROPC_CLIENT_SECRET not set in .env — add it per Task 1.6 (.env.example: KC_TEST_ROPC_CLIENT_SECRET=change-me-test-secret)"

  # The realm export ships test-ropc-client with a zeroed secret (secret-hygiene),
  # so the imported client's secret will NOT match the .env value. Set it at runtime
  # via the Admin REST API so that client authentication succeeds — this guarantees the
  # asserted HTTP 400 reflects the pending-state block (VERIFY_EMAIL), not a client-auth
  # failure (HTTP 401 invalid_client), which would silently pass for the wrong reason.
  local clients_json client_uuid client_rep update_status
  clients_json=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/clients?clientId=test-ropc-client") \
    || fail "Could not look up test-ropc-client — is the realm import current?"
  client_uuid=$(echo "${clients_json}" | python3 -c "import json,sys; c=json.load(sys.stdin); print(c[0]['id'] if c else '')")
  [[ -n "${client_uuid}" ]] || fail "test-ropc-client not found in realm — re-import realm-export.json (Task 1.5)"
  # Inject the secret into the full client representation and PUT it back (preserves all flags).
  client_rep=$(echo "${clients_json}" | ROPC_SECRET="${ropc_secret}" python3 -c "import json,sys,os; c=json.load(sys.stdin)[0]; c['secret']=os.environ['ROPC_SECRET']; print(json.dumps(c))")
  update_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "${client_rep}" \
    "http://localhost:8080/admin/realms/envocc/clients/${client_uuid}")
  [[ "${update_status}" == "204" ]] || fail "Could not set test-ropc-client secret (got HTTP ${update_status})"

  # Attempt ROPC login with valid credentials.
  # Expected: HTTP 400 — Keycloak rejects because VERIFY_EMAIL required action is pending.
  # (Keycloak returns {"error":"invalid_grant","error_description":"Account is not fully set up"})
  local token_status
  token_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -d "grant_type=password" \
    -d "client_id=test-ropc-client" \
    -d "client_secret=${ropc_secret}" \
    -d "username=ts210d@envocc.local" \
    -d "password=Test!Pending123" \
    "http://localhost:8080/realms/envocc/protocol/openid-connect/token")

  # Assert: HTTP 400 (not 200) — pending state blocks authentication
  assert_equal "${token_status}" "400"
}

# ---------------------------------------------------------------------------
# TS-210e [P2] — No PDPA §26 attributes on freshly created user (AC2, clean-creation invariant)
#
# Validates FR23: the standard user creation flow (Admin REST with only allowed fields)
# does not populate any PDPA §26 sensitive attribute fields.
#
# NOTE: In KC 26, the Admin REST API can bypass user-profile restrictions when setting
# attributes explicitly (admin bypass is by design). This test validates the
# clean-creation invariant: a standard creation request with no sensitive fields
# produces a user record with no sensitive attributes. See keycloak/IDENTITY-MODEL.md.
#
# Activate when: Task 3.6 — after Declarative User Profile default config applied (Task 1.3/1.4).
# ---------------------------------------------------------------------------
@test "[P2][TS-210e] No PDPA §26 attributes on freshly created user — clean-creation invariant" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Create user using ONLY the four allowed fields: username, email, firstName, lastName
  # Capture UUID from Location header immediately for teardown cleanup.
  local http_status post_loc_file user_id e_loc
  post_loc_file=$(mktemp)
  http_status=$(curl -s -o /dev/null -w "%{http_code}" -D "${post_loc_file}" --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"username":"ts210e@envocc.local","email":"ts210e@envocc.local","enabled":true,"emailVerified":true,"firstName":"Test","lastName":"CleanCreate"}' \
    "http://localhost:8080/admin/realms/envocc/users")
  [[ "${http_status}" == "201" ]] || { rm -f "${post_loc_file}"; fail "Could not create test user TS-210e (got HTTP ${http_status})"; }
  e_loc=$(grep -i '^location:' "${post_loc_file}" | tail -n 1 | tr -d '\r' | sed -E 's/^[^:]+:[[:space:]]*//')
  rm -f "${post_loc_file}"
  user_id="${e_loc##*/}"
  # Fallback: if Location header was absent or unparseable, recover UUID via GET-by-email
  if [[ -z "${user_id}" ]]; then
    local fallback_resp
    fallback_resp=$(curl -sf --max-time 10 \
      -H "Authorization: Bearer ${token}" \
      "http://localhost:8080/admin/realms/envocc/users?email=ts210e@envocc.local&exact=true") || true
    user_id=$(echo "${fallback_resp}" | python3 -c "import json,sys; u=json.load(sys.stdin); print(u[0]['id'] if u else '')" 2>/dev/null || echo "")
  fi
  [[ -n "${user_id}" ]] || fail "User TS-210e UUID not found after creation"
  _TS210E_USER_ID="${user_id}"

  # Fetch full user object
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

  # Assert: no PDPA §26 sensitive fields appear in the attributes map after clean creation.
  # This validates that the Declarative User Profile default configuration does not inject
  # unexpected sensitive attributes into a freshly created user.
  # Uses shared helper from tests/helpers/common.bash — single source of truth
  # for the forbidden field list (FR23/NFR12).
  run check_no_pdpa_sensitive_attrs "${user_tmpfile}"
  assert_success
  rm -f "${user_tmpfile}"
}
