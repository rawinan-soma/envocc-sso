#!/usr/bin/env bats
# tests/integration/realm-import.bats
# ATDD integration tests — Story 1.2: Realm config-as-code baseline & secret hygiene
#
# AC1: Given keycloak/realm-export.json in git, when the stack starts (docker compose up),
#      then the realm is imported automatically and baseline settings are applied
#      without manual intervention.
# AC3: Given a realm change made through the Admin UI, when it is exported back to the
#      repo, then the resulting diff is reviewable and the updated file is re-importable
#      on a fresh stack.
#
# Test scenarios covered:
#   TS-201a [P0] OIDC discovery returns HTTP 200 for 'envocc' realm
#   TS-201b [P0] OIDC issuer matches expected realm URL
#   TS-201c [P0] Admin REST API confirms realm exists and is enabled
#   TS-201d [P1] Baseline settings match realm-export.json (bruteForceProtected, accessTokenLifespan)
#   TS-201e [P1] Fresh stack imports realm automatically (destructive — down -v + up)
#   TS-201f [P1] Round-trip: export → strip → reimport on fresh stack (manual procedure)
#   TS-201g [P2] IGNORE_EXISTING: runtime change survives KC restart (import strategy)
#
# IMPORTANT: All tests in this file require a live Keycloak stack.
# They are skipped unless the INTEGRATION environment variable is set.
# To run: INTEGRATION=1 bats tests/integration/realm-import.bats
# Pre-requisites:
#   1. docker compose up --build (stack healthy)
#   2. BATS_LIB_PATH=$(pwd)/tests/lib bats tests/integration/realm-import.bats

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Suite setup: handled by tests/integration/setup_suite.bash (BATS 1.5+ companion).
# Per-test: guard against non-INTEGRATION runs.
# ---------------------------------------------------------------------------

setup() {
  if [[ -z "${INTEGRATION}" ]]; then
    skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"
  fi
}

# ---------------------------------------------------------------------------
# TS-201a [P0] — OIDC discovery endpoint returns HTTP 200 (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-201a] OIDC discovery endpoint returns HTTP 200 for envocc realm" {
  run curl -sf --max-time 10 \
    "http://localhost:8080/realms/envocc/.well-known/openid-configuration" \
    -o /dev/null \
    -w "%{http_code}"
  assert_success
  assert_output "200"
}

# ---------------------------------------------------------------------------
# TS-201b [P0] — OIDC issuer matches expected realm URL (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-201b] OIDC issuer URL matches http://localhost:8080/realms/envocc" {
  run curl -sf --max-time 10 \
    "http://localhost:8080/realms/envocc/.well-known/openid-configuration"
  assert_success

  # Extract issuer from JSON
  local issuer
  issuer=$(echo "${output}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('issuer',''))")
  assert_equal "${issuer}" "http://localhost:8080/realms/envocc"
}

# ---------------------------------------------------------------------------
# TS-201c [P0] — Admin REST API confirms realm exists and is enabled (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-201c] Admin REST API confirms envocc realm exists and is enabled" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token — check KC_BOOTSTRAP_ADMIN_* in .env"

  # Query the realm endpoint
  run curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc"
  assert_success

  # Confirm realm is enabled
  local enabled
  enabled=$(echo "${output}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('enabled',False)).lower())")
  assert_equal "${enabled}" "true"
}

# ---------------------------------------------------------------------------
# TS-201d [P1] — Baseline settings match realm-export.json (AC1)
# Checks: bruteForceProtected, accessTokenLifespan, ssoSessionIdleTimeout,
#         revokeRefreshToken (Story 2.4 Task 4.2), refreshTokenMaxReuse (Story 2.4 Task 4.2)
# ---------------------------------------------------------------------------
@test "[P1][TS-201d] Baseline realm settings match realm-export.json spec" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Fetch realm JSON to a temp file via shared helper (tests/helpers/common.bash).
  # The helper guards the curl call and cleans up the tmpfile on failure.
  local realm_tmpfile
  realm_tmpfile=$(fetch_realm_json_to_tmpfile "${token}") \
    || fail "Could not fetch realm JSON from Admin API"

  run python3 - "${realm_tmpfile}" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    d = json.load(f)

failures = []
checks = [
    ('bruteForceProtected', True),
    ('accessTokenLifespan', 300),
    ('ssoSessionIdleTimeout', 1800),
    ('ssoSessionMaxLifespan', 36000),
    ('registrationAllowed', False),
    ('resetPasswordAllowed', False),
    # Story 2.4 Task 4.2: exhaust baseline assertion with refresh token rotation fields
    ('revokeRefreshToken', True),
    ('refreshTokenMaxReuse', 0),
]

for key, expected in checks:
    actual = d.get(key)
    # Use type-strict comparison: Python's False==0 and True==1 would silently
    # pass a bool where an int is expected (or vice versa). type() comparison
    # ensures e.g. refreshTokenMaxReuse=false and revokeRefreshToken=1 are caught.
    if actual != expected or type(actual) is not type(expected):
        failures.append(f'{key}: expected={expected!r} actual={actual!r}')

if failures:
    print('Realm setting mismatches: ' + str(failures))
    sys.exit(1)
sys.exit(0)
PYEOF

  # Assert first, then clean up — so the temp file is available for diagnosis on failure.
  assert_success
  rm -f "${realm_tmpfile}"
}

# ---------------------------------------------------------------------------
# TS-201e [P1] — Fresh stack imports realm automatically (AC1, destructive)
# CAUTION: This test tears down the stack and all volumes.
# Only run when DESTRUCTIVE_INTEGRATION=1 is also set.
# ---------------------------------------------------------------------------
@test "[P1][TS-201e] Fresh stack (down -v + up --build) auto-imports envocc realm" {
  if [[ -z "${DESTRUCTIVE_INTEGRATION}" ]]; then
    skip "Destructive test — set DESTRUCTIVE_INTEGRATION=1 to run (tears down volumes)"
  fi

  # Tear down completely
  docker compose -f "${PROJECT_ROOT}/compose.yaml" down -v --remove-orphans

  # Bring up fresh
  docker compose -f "${PROJECT_ROOT}/compose.yaml" up -d --build

  # Wait for Keycloak to become healthy (Docker healthcheck passes once KC is ready).
  # KC 26 with --import-realm performs the import synchronously before the server
  # accepts traffic, so a healthy status means import is complete.
  # Add a brief retry loop on the realm endpoint as a belt-and-suspenders guard
  # for environments where the healthcheck probe races the realm registration.
  wait_for_healthy keycloak 180

  # Verify realm imported — retry up to 30 s to absorb any brief post-healthy lag.
  local oidc_status="" elapsed=0
  while [[ "${elapsed}" -lt 30 ]]; do
    oidc_status=$(curl -sf --max-time 5 \
      "http://localhost:8080/realms/envocc/.well-known/openid-configuration" \
      -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
    [[ "${oidc_status}" == "200" ]] && break
    sleep 2
    elapsed=$((elapsed + 2))
  done

  # assert_equal only takes 2 args in this bats-assert version; emit a helpful
  # message via fail so the diagnosis is clear on timeout.
  if [[ "${oidc_status}" != "200" ]]; then
    fail "OIDC discovery did not return 200 after 30 s post-healthy wait (got: ${oidc_status})"
  fi
}

# ---------------------------------------------------------------------------
# TS-201f [P1] — Round-trip: export → strip → reimport (AC3, manual procedure)
# This test is always skipped — it documents the manual AC3 verification procedure.
# ---------------------------------------------------------------------------
@test "[P1][TS-201f] Manual: round-trip export → strip → reimport applies changes" {
  skip "Manual procedure — see keycloak/REALM-EXPORT-NOTES.md for step-by-step instructions"

  # Manual steps (not automated — requires human review of diff):
  # 1. Make a trivial change via Admin UI (e.g. update displayName)
  # 2. Export via Admin UI → Realm Settings → Action → Export
  # 3. Save as keycloak/realm-export.json
  # 4. Strip secrets: inspect for privateKey, certificate, secret, clientSecret fields
  # 5. Run: gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml --redact
  # 6. Review diff (should show only the setting change, no secret material)
  # 7. docker compose down -v && docker compose up --build
  # 8. Verify the change was applied via Admin UI or REST API
  # 9. Revert test change before final commit
}

# ---------------------------------------------------------------------------
# TS-201g [P2] — IGNORE_EXISTING: runtime change survives KC restart (AC3)
# ---------------------------------------------------------------------------
@test "[P2][TS-201g] IGNORE_EXISTING strategy: realm survives KC restart (no overwrite)" {
  skip "P2: import strategy edge case — run manually after verifying IGNORE_EXISTING behaviour"

  # Steps to test manually:
  # 1. Stack is running with realm imported.
  # 2. Make a change via Admin UI (e.g. set ssoSessionIdleTimeout to 2000).
  # 3. Restart KC without down -v: docker compose restart keycloak
  # 4. Wait for healthy.
  # 5. Verify via Admin API that ssoSessionIdleTimeout is STILL 2000 (not reverted to 1800).
  # This confirms IGNORE_EXISTING: the import file is skipped on existing realm.
}

# ===========================================================================
# Story 2.4 — SSO Session, Lifetimes & RP-Initiated Logout
# Tests added by Story 2.4 ATDD scaffold (Task 4.1, 5.2)
# All tests require: INTEGRATION=1 and a running Keycloak stack
# ===========================================================================

# ---------------------------------------------------------------------------
# TS-241a [P0] — Admin REST API confirms revokeRefreshToken is true (AC3/FR9)
# RED PHASE: Fails until keycloak/realm-export.json is updated (Task 1.1)
# ---------------------------------------------------------------------------
@test "[P0][TS-241a] Admin REST API confirms revokeRefreshToken is true in live realm" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  local realm_tmpfile
  realm_tmpfile=$(fetch_realm_json_to_tmpfile "${token}") \
    || fail "Could not fetch realm JSON from Admin API"

  run python3 - "${realm_tmpfile}" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    d = json.load(f)

val = d.get('revokeRefreshToken')
if val is not True:
    print(f'revokeRefreshToken: expected=True actual={val!r}')
    sys.exit(1)
sys.exit(0)
PYEOF

  assert_success
  rm -f "${realm_tmpfile}"
}

# ---------------------------------------------------------------------------
# TS-241b [P0] — Admin REST API confirms refreshTokenMaxReuse is 0 (AC3/FR9)
# RED PHASE: Fails until keycloak/realm-export.json is updated (Task 1.2)
# ---------------------------------------------------------------------------
@test "[P0][TS-241b] Admin REST API confirms refreshTokenMaxReuse is 0 in live realm" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  local realm_tmpfile
  realm_tmpfile=$(fetch_realm_json_to_tmpfile "${token}") \
    || fail "Could not fetch realm JSON from Admin API"

  run python3 - "${realm_tmpfile}" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    d = json.load(f)

val = d.get('refreshTokenMaxReuse')
# Type-strict: Python False==0, so a naive != 0 would accept refreshTokenMaxReuse=false.
# Require integer type explicitly (mirrors the lint-realm-export.py guard).
if not isinstance(val, int) or isinstance(val, bool) or val != 0:
    print(f'refreshTokenMaxReuse: expected=0 (int) actual={val!r}')
    sys.exit(1)
sys.exit(0)
PYEOF

  assert_success
  rm -f "${realm_tmpfile}"
}

# ---------------------------------------------------------------------------
# TS-241c [P1] — Admin REST API confirms accessTokenLifespan <= 900 (AC2/NFR2a)
# Expected to pass once stack is running (current value: 300s < 900s ceiling)
# ---------------------------------------------------------------------------
@test "[P1][TS-241c] Admin REST API confirms accessTokenLifespan <= 900s in live realm" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  local realm_tmpfile
  realm_tmpfile=$(fetch_realm_json_to_tmpfile "${token}") \
    || fail "Could not fetch realm JSON from Admin API"

  run python3 - "${realm_tmpfile}" <<'PYEOF'
import json, sys

MAX_ACCESS_TOKEN_LIFESPAN = 900  # NFR2a: 15-minute hard ceiling

with open(sys.argv[1]) as f:
    d = json.load(f)

val = d.get('accessTokenLifespan')
# Type-strict: bool subclasses int in Python, so isinstance(True, int) is True.
# Exclude bool explicitly to mirror the lint-realm-export.py guard (line ~148).
if not isinstance(val, int) or isinstance(val, bool) or val > MAX_ACCESS_TOKEN_LIFESPAN:
    print(f'accessTokenLifespan: expected<={MAX_ACCESS_TOKEN_LIFESPAN}s actual={val!r}')
    sys.exit(1)
sys.exit(0)
PYEOF

  assert_success
  rm -f "${realm_tmpfile}"
}

# ---------------------------------------------------------------------------
# TS-241d [P1] — OIDC discovery .well-known includes end_session_endpoint (AC5/FR10)
# Expected to pass on Keycloak 26.x (end_session_endpoint is built-in)
# ---------------------------------------------------------------------------
@test "[P1][TS-241d] OIDC discovery .well-known/openid-configuration includes end_session_endpoint" {
  run curl -sf --max-time 10 \
    "http://localhost:8080/realms/envocc/.well-known/openid-configuration"
  assert_success

  local endpoint
  endpoint=$(echo "${output}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('end_session_endpoint', ''))
")

  # end_session_endpoint must be present and non-empty
  [[ -n "${endpoint}" ]] || fail "end_session_endpoint missing from OIDC discovery document"

  # Must point to the envocc realm logout endpoint
  [[ "${endpoint}" == *"/realms/envocc/protocol/openid-connect/logout"* ]] || \
    fail "end_session_endpoint does not reference expected logout path: ${endpoint}"
}

# ---------------------------------------------------------------------------
# TS-241e [P1] — End Session endpoint returns 200 or 302 on bare GET (AC5/FR10)
# Tests reachability only — no id_token_hint, so Keycloak shows its default page
# Expected to pass on Keycloak 26.x (endpoint is always available)
# ---------------------------------------------------------------------------
@test "[P1][TS-241e] End Session endpoint returns 200 or 302 on bare GET (no params)" {
  local http_code
  http_code=$(curl -s --max-time 10 \
    -o /dev/null \
    -w "%{http_code}" \
    "http://localhost:8080/realms/envocc/protocol/openid-connect/logout")

  # 200 = Keycloak renders its "You are logged out" page
  # 302 = redirect to post_logout_redirect_uri (none set here, so likely 200)
  # Must NOT be 4xx or 5xx
  case "${http_code}" in
    200|302) ;;
    *) fail "End Session endpoint returned unexpected HTTP ${http_code} (expected 200 or 302)" ;;
  esac
}

# ---------------------------------------------------------------------------
# TS-241f [P2] — Session ID regenerated on every auth-state transition (AC4/FR45)
# Always-skip — manual verification procedure (Keycloak 26.x built-in behavior)
# See keycloak/REALM-EXPORT-NOTES.md Story 2.4 section for step-by-step instructions
# ---------------------------------------------------------------------------
@test "[P2][TS-241f] Manual: AUTH_SESSION_ID cookie changes value after each auth-state transition" {
  skip "Manual procedure — see keycloak/REALM-EXPORT-NOTES.md Story 2.4 section for FR45 session-fixation verification steps"

  # Manual verification steps (requires browser developer tools or cookie-jar HTTP client):
  # 1. Open the Keycloak login page for the envocc realm
  # 2. Capture the AUTH_SESSION_ID cookie value before authentication
  # 3. Enter valid username and password — observe the login form
  # 4. Confirm AUTH_SESSION_ID changes value after successful password submission
  # 5. If MFA (TOTP) is required: capture AUTH_SESSION_ID after password step
  # 6. Enter TOTP code
  # 7. Confirm AUTH_SESSION_ID changes value again after successful TOTP verification
  # 8. This confirms Keycloak 26.x default session-fixation protection (FR45)
  # Note: No realm-export.json change is needed — this is Keycloak's non-configurable default
}
