#!/usr/bin/env bats
# tests/integration/realm-import.bats
# ATDD tests — Story 1.2 AC1, AC3: Realm config-as-code baseline & secret hygiene
#
# AC1: Given keycloak/realm-export.json in git,
#      when the stack starts (docker compose up),
#      then the realm is imported automatically and baseline settings
#      are applied without manual intervention.
#
# AC3: Given a realm change made through the Keycloak Admin UI,
#      when it is exported back to the repo (using the documented procedure),
#      then the resulting diff is reviewable (no sensitive material) and the
#      updated file is re-importable on a fresh stack (docker compose down -v
#      && docker compose up) with the change applied.
#
# Test scenarios covered:
#   TS-201a [P0] OIDC discovery endpoint returns HTTP 200 for 'envocc' realm
#   TS-201b [P0] OIDC discovery issuer matches expected realm URL
#   TS-201c [P0] Keycloak admin API confirms 'envocc' realm exists and is enabled
#   TS-201d [P1] Baseline realm settings match realm-export.json values
#   TS-201e [P1] Realm imports cleanly on fresh stack (down -v + up --build)
#   TS-201f [P1] Round-trip: realm re-imports after export+import cycle on fresh stack
#   TS-201g [P2] Realm import is idempotent on existing DB (IGNORE_EXISTING strategy)
#
# NOTE: These tests require a running stack (docker compose up --build).
# Run manually: docker compose up --build -d, then: bats tests/integration/realm-import.bats
# In CI (Story 1.5), these run as part of the integration test suite after health checks.

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# keycloak_api_token
# Obtain an admin access token from the master realm using bootstrap credentials.
keycloak_api_token() {
  local admin_user
  local admin_pass
  admin_user="$(env_value KC_BOOTSTRAP_ADMIN_USERNAME)"
  admin_pass="$(env_value KC_BOOTSTRAP_ADMIN_PASSWORD)"

  curl -s \
    -d "client_id=admin-cli" \
    -d "username=${admin_user}" \
    -d "password=${admin_pass}" \
    -d "grant_type=password" \
    "http://localhost:8080/realms/master/protocol/openid-connect/token" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))"
}

# realm_setting <realm> <token> <jq_filter>
# Query the Keycloak Admin REST API for a realm and extract a setting via jq filter.
realm_setting() {
  local realm="${1}"
  local token="${2}"
  local jq_filter="${3}"

  curl -s \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/${realm}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(${jq_filter})" 2>/dev/null
}

# env_value <KEY>
# Reads the literal value of KEY from .env without shell-evaluating the file.
env_value() {
  local key="${1}"
  sed -n "s/^${key}=//p" "${PROJECT_ROOT}/.env" | tail -n 1
}

# ---------------------------------------------------------------------------
# Suite setup: handled by tests/integration/setup_suite.bash (BATS 1.5+).
# ---------------------------------------------------------------------------

setup() {
  : # per-test setup (noop for infra tests)
}

teardown() {
  : # per-test teardown
}

# ---------------------------------------------------------------------------
# TS-201a [P0] — OIDC discovery endpoint returns HTTP 200 for 'envocc' realm
# ---------------------------------------------------------------------------
@test "[P0][TS-201a] OIDC discovery endpoint for 'envocc' realm returns HTTP 200" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  # Given the stack is healthy
  run wait_for_healthy "keycloak" 120
  assert_success

  # When we query the OIDC discovery endpoint for the envocc realm
  run bash -c "curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    'http://localhost:8080/realms/envocc/.well-known/openid-configuration'"

  # Then it returns HTTP 200 (not 404 — realm exists)
  assert_output "200"
}

# ---------------------------------------------------------------------------
# TS-201b [P0] — OIDC discovery issuer matches expected realm URL
# ---------------------------------------------------------------------------
@test "[P0][TS-201b] OIDC discovery issuer is 'http://localhost:8080/realms/envocc'" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  # Given the stack is healthy and the realm is imported
  run wait_for_healthy "keycloak" 120
  assert_success

  # When we fetch the OIDC discovery document
  run bash -c "curl -sf --max-time 10 \
    'http://localhost:8080/realms/envocc/.well-known/openid-configuration' \
    | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d['issuer'])\""

  # Then the issuer exactly matches the expected realm URL (confirms realm name = 'envocc')
  assert_success
  assert_output "http://localhost:8080/realms/envocc"
}

# ---------------------------------------------------------------------------
# TS-201c [P0] — Keycloak admin API confirms 'envocc' realm exists and is enabled
# ---------------------------------------------------------------------------
@test "[P0][TS-201c] Admin REST API confirms 'envocc' realm exists and is enabled" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  run wait_for_healthy "keycloak" 120
  assert_success

  # Obtain admin token
  local token
  token="$(keycloak_api_token)"
  [ -n "${token}" ] || fail "Failed to obtain admin API token from master realm"

  # Query the envocc realm via Admin REST API
  run bash -c "curl -sf --max-time 10 \
    -H 'Authorization: Bearer ${token}' \
    'http://localhost:8080/admin/realms/envocc' \
    | python3 -c \"import sys,json; d=json.load(sys.stdin); print(str(d.get('enabled',False)).lower())\""

  # Then the realm exists (200 response) and is enabled
  assert_success
  assert_output "true"
}

# ---------------------------------------------------------------------------
# TS-201d [P1] — Baseline realm settings match realm-export.json values
# Verifies that imported settings match what was committed (config-as-code fidelity).
# ---------------------------------------------------------------------------
@test "[P1][TS-201d] Imported realm 'displayName' is 'EnvOcc SSO'" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  run wait_for_healthy "keycloak" 120
  assert_success

  local token
  token="$(keycloak_api_token)"
  [ -n "${token}" ] || fail "Failed to obtain admin API token"

  run realm_setting "envocc" "${token}" "d.get('displayName','')"
  assert_success
  assert_output "EnvOcc SSO"
}

@test "[P1][TS-201d] Imported realm 'loginWithEmailAllowed' is true" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  run wait_for_healthy "keycloak" 120
  assert_success

  local token
  token="$(keycloak_api_token)"
  [ -n "${token}" ] || fail "Failed to obtain admin API token"

  run realm_setting "envocc" "${token}" "str(d.get('loginWithEmailAllowed',False)).lower()"
  assert_success
  assert_output "true"
}

@test "[P1][TS-201d] Imported realm 'registrationAllowed' is false (no self-registration)" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  run wait_for_healthy "keycloak" 120
  assert_success

  local token
  token="$(keycloak_api_token)"
  [ -n "${token}" ] || fail "Failed to obtain admin API token"

  run realm_setting "envocc" "${token}" "str(d.get('registrationAllowed',True)).lower()"
  assert_success
  assert_output "false"
}

@test "[P1][TS-201d] Imported realm 'bruteForceProtected' is true" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  run wait_for_healthy "keycloak" 120
  assert_success

  local token
  token="$(keycloak_api_token)"
  [ -n "${token}" ] || fail "Failed to obtain admin API token"

  run realm_setting "envocc" "${token}" "str(d.get('bruteForceProtected',False)).lower()"
  assert_success
  assert_output "true"
}

@test "[P1][TS-201d] Imported realm 'accessTokenLifespan' is 300 seconds (5 min)" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  run wait_for_healthy "keycloak" 120
  assert_success

  local token
  token="$(keycloak_api_token)"
  [ -n "${token}" ] || fail "Failed to obtain admin API token"

  run realm_setting "envocc" "${token}" "str(d.get('accessTokenLifespan',0))"
  assert_success
  assert_output "300"
}

@test "[P1][TS-201d] Imported realm 'defaultSignatureAlgorithm' is RS256" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  run wait_for_healthy "keycloak" 120
  assert_success

  local token
  token="$(keycloak_api_token)"
  [ -n "${token}" ] || fail "Failed to obtain admin API token"

  run realm_setting "envocc" "${token}" "d.get('defaultSignatureAlgorithm','')"
  assert_success
  assert_output "RS256"
}

# ---------------------------------------------------------------------------
# TS-201e [P1] — Realm imports cleanly on fresh stack (down -v + up --build)
# This is the canonical AC1 proof: fresh state must produce an imported realm.
# ---------------------------------------------------------------------------
@test "[P1][TS-201e] Fresh stack (down -v + up --build) imports 'envocc' realm automatically" {
  skip "Integration: DESTRUCTIVE — requires docker compose down -v. Run manually only."

  # DESTRUCTIVE STEP: wipe volumes and rebuild
  run compose_down_volumes
  assert_success

  run bash -c "docker compose -f '${PROJECT_ROOT}/compose.yaml' up -d --build"
  assert_success

  # Wait for Keycloak to become healthy (realm import happens during startup)
  run wait_for_healthy "keycloak" 180
  assert_success

  # Then the OIDC discovery endpoint must return 200 — not 404
  run bash -c "curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
    'http://localhost:8080/realms/envocc/.well-known/openid-configuration'"
  assert_output "200"
}

# ---------------------------------------------------------------------------
# TS-201f [P1] — Round-trip: export → strip → reimport on fresh stack (AC3)
# Verifies the export procedure documented in keycloak/REALM-EXPORT-NOTES.md works.
# ---------------------------------------------------------------------------
@test "[P1][TS-201f] Round-trip: realm re-imports after export-strip-commit cycle on fresh stack" {
  skip "Integration: MANUAL — requires Admin UI export + gitleaks strip + fresh stack. Run manually per REALM-EXPORT-NOTES.md."

  # MANUAL PROCEDURE (see keycloak/REALM-EXPORT-NOTES.md):
  # 1. Make a trivial change via Admin UI (e.g., set ssoSessionIdleTimeout to 2000)
  # 2. Export: Realm Settings → Action → Export → Save as keycloak/realm-export.json
  # 3. Run gitleaks: gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml --redact
  # 4. docker compose down -v && docker compose up --build -d
  # 5. Verify the change was imported via the Admin API or OIDC endpoint

  # The test below verifies step 5 — after the manual round-trip, the realm still imports correctly.
  run wait_for_healthy "keycloak" 180
  assert_success

  run bash -c "curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
    'http://localhost:8080/realms/envocc/.well-known/openid-configuration'"
  assert_output "200"

  # Verify the round-tripped setting (ssoSessionIdleTimeout = 2000 from the manual test change).
  # Revert this test change before the final commit.
  local token
  token="$(keycloak_api_token)"
  [ -n "${token}" ] || fail "Failed to obtain admin API token"

  run realm_setting "envocc" "${token}" "str(d.get('ssoSessionIdleTimeout',0))"
  assert_success
  # The baseline value from realm-export.json is 1800; a test change of 2000 would appear here.
  # This assertion documents the round-trip intent — adjust as needed for the actual test change.
  assert_output "1800"
}

# ---------------------------------------------------------------------------
# TS-201g [P2] — IGNORE_EXISTING: realm import is skipped on existing DB
# Verifies KC 26 default import strategy (IGNORE_EXISTING) — existing realm is
# NOT overwritten on container restart without volume wipe.
# ---------------------------------------------------------------------------
@test "[P2][TS-201g] Realm import is skipped (IGNORE_EXISTING) on existing DB restart" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  # Given the stack is up with the envocc realm imported
  run wait_for_healthy "keycloak" 120
  assert_success

  # Make a change via Admin API (to verify it survives a restart)
  local token
  token="$(keycloak_api_token)"
  [ -n "${token}" ] || fail "Failed to obtain admin API token"

  # Change ssoSessionIdleTimeout to 9999 via the Admin API — simulates a UI change
  run bash -c "curl -sf --max-time 10 \
    -X PUT \
    -H 'Authorization: Bearer ${token}' \
    -H 'Content-Type: application/json' \
    -d '{\"ssoSessionIdleTimeout\": 9999}' \
    'http://localhost:8080/admin/realms/envocc'"
  assert_success

  # When we restart the Keycloak container WITHOUT wiping volumes (IGNORE_EXISTING behavior)
  run docker compose -f "${PROJECT_ROOT}/compose.yaml" restart keycloak
  assert_success

  run wait_for_healthy "keycloak" 120
  assert_success

  # Re-obtain token after restart
  token="$(keycloak_api_token)"
  [ -n "${token}" ] || fail "Failed to obtain admin API token after restart"

  # Then the runtime change (9999) is preserved — import file was NOT re-applied
  # (This confirms IGNORE_EXISTING strategy: DB wins over import file on restart)
  run realm_setting "envocc" "${token}" "str(d.get('ssoSessionIdleTimeout',0))"
  assert_success
  assert_output "9999"
}
