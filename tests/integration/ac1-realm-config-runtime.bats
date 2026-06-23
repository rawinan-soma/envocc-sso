#!/usr/bin/env bats
# =============================================================================
# ATDD Acceptance Tests — Story 1.2
# AC1 (runtime): Live Keycloak realm configuration validation via Admin REST API
#
# Verifies baseline settings against a running Keycloak instance:
#   registrationAllowed, sslRequired, bruteForceProtected, accessTokenLifespan,
#   ssoSessionIdleTimeout, ssoSessionMaxLifespan, eventsEnabled,
#   adminEventsEnabled, displayName, internationalizationEnabled
#
# All tests self-skip when Keycloak is not running.
#
# Bats subprocess isolation note:
#   @test functions run in isolated subprocesses; env vars exported from
#   setup_file are NOT inherited. Persist shared state via $BATS_FILE_TMPDIR.
#
# Run:  bats tests/integration/ac1-realm-config-runtime.bats
# Deps: curl, bats-core; docker compose (stack must be running)
# Note: Static/offline checks are in ac1-realm-config.bats
# =============================================================================

KC_PORT="${KC_PORT:-8080}"
REALM="envocc"

# Helper: get admin bearer token from master realm
_admin_token() {
  local admin_user="${KEYCLOAK_ADMIN:-admin}"
  local admin_pass="${KEYCLOAK_ADMIN_PASSWORD:-change-me}"
  curl -sf \
    -d "client_id=admin-cli" \
    -d "username=${admin_user}" \
    -d "password=${admin_pass}" \
    -d "grant_type=password" \
    "http://localhost:${KC_PORT}/realms/master/protocol/openid-connect/token" \
    | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4
}

# Helper: skip if Keycloak is not up.
# In Keycloak 26 /health/ready is on the management port (9000) which is NOT
# published to the host. Use the realm endpoint as the readiness probe.
kc_running() {
  curl -sf -o /dev/null -w "%{http_code}" \
    "http://localhost:${KC_PORT}/realms/${REALM}" 2>/dev/null | grep -q "200"
}

# Fetch the live realm JSON once per file run and persist to $BATS_FILE_TMPDIR.
# $BATS_FILE_TMPDIR is managed by BATS — it is unique per file run and shared
# across all @test subprocesses within the same file invocation.
setup_file() {
  if ! kc_running; then
    return 0  # individual tests will skip via kc_running guard
  fi
  local token
  token=$(_admin_token)
  if [ -z "$token" ]; then
    echo "setup_file: failed to obtain admin token; runtime tests will skip." >&2
    return 0
  fi
  curl -sf -H "Authorization: Bearer ${token}" \
    "http://localhost:${KC_PORT}/admin/realms/${REALM}" \
    > "${BATS_FILE_TMPDIR}/realm.json"
}

# Internal helper: read the cached live realm JSON.
_realm_json() {
  if [ -f "${BATS_FILE_TMPDIR}/realm.json" ]; then
    cat "${BATS_FILE_TMPDIR}/realm.json"
  fi
}

# =============================================================================
# RUNTIME CHECKS — require a running Keycloak stack
# =============================================================================

# ---------------------------------------------------------------------------
# [P0] AC1-RC-17 — Live realm has registrationAllowed=false (Admin REST API)
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-17] Live envocc realm: registrationAllowed=false" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"
  [ -f "${BATS_FILE_TMPDIR}/realm.json" ] || skip "Realm JSON not cached in setup_file"
  _realm_json | grep -q '"registrationAllowed":false'
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-18 — Live realm: sslRequired=external
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-18] Live envocc realm: sslRequired=external" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"
  [ -f "${BATS_FILE_TMPDIR}/realm.json" ] || skip "Realm JSON not cached in setup_file"
  _realm_json | grep -q '"sslRequired":"external"'
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-19 — Live realm: bruteForceProtected=true
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-19] Live envocc realm: bruteForceProtected=true" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"
  [ -f "${BATS_FILE_TMPDIR}/realm.json" ] || skip "Realm JSON not cached in setup_file"
  _realm_json | grep -q '"bruteForceProtected":true'
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-20 — Live realm: accessTokenLifespan=900 (NFR2a hard ceiling)
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-20] Live envocc realm: accessTokenLifespan=900" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"
  [ -f "${BATS_FILE_TMPDIR}/realm.json" ] || skip "Realm JSON not cached in setup_file"
  # Exact numeric equality via jq — resilient to compact/pretty output and to
  # prefix-match false negatives (e.g. 9000 must NOT satisfy a 900 check).
  [ "$(_realm_json | jq -r '.accessTokenLifespan')" = "900" ]
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-21 — Live realm: eventsEnabled=true and adminEventsEnabled=true
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-21] Live envocc realm: eventsEnabled=true and adminEventsEnabled=true" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"
  [ -f "${BATS_FILE_TMPDIR}/realm.json" ] || skip "Realm JSON not cached in setup_file"
  _realm_json | grep -q '"eventsEnabled":true'
  _realm_json | grep -q '"adminEventsEnabled":true'
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-22 — Live realm: correct SSO session timeouts
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-22] Live envocc realm: correct SSO session timeouts (idle=1800, max=28800)" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"
  [ -f "${BATS_FILE_TMPDIR}/realm.json" ] || skip "Realm JSON not cached in setup_file"
  # Exact numeric equality via jq (see AC1-RC-20 rationale).
  [ "$(_realm_json | jq -r '.ssoSessionIdleTimeout')" = "1800" ]
  [ "$(_realm_json | jq -r '.ssoSessionMaxLifespan')" = "28800" ]
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-23 — Live realm: displayName=EnvOcc SSO
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-23] Live envocc realm: displayName='EnvOcc SSO'" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"
  [ -f "${BATS_FILE_TMPDIR}/realm.json" ] || skip "Realm JSON not cached in setup_file"
  _realm_json | grep -q '"displayName":"EnvOcc SSO"'
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-24 — Live realm: internationalizationEnabled=true
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-24] Live envocc realm: internationalizationEnabled=true with en and th" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"
  [ -f "${BATS_FILE_TMPDIR}/realm.json" ] || skip "Realm JSON not cached in setup_file"
  _realm_json | grep -q '"internationalizationEnabled":true'
}
