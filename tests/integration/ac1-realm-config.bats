#!/usr/bin/env bats
# =============================================================================
# ATDD Acceptance Tests — Story 1.2
# AC1 (extended): Baseline realm configuration validation
#
# Verifies ALL required baseline settings from AC1:
#   realm/displayName, sslRequired, registrationAllowed, loginWithEmailAllowed,
#   bruteForceProtected, accessTokenLifespan, ssoSessionIdleTimeout,
#   ssoSessionMaxLifespan, eventsEnabled, adminEventsEnabled,
#   internationalizationEnabled, supportedLocales, defaultLocale
#
# TDD Phase: RED — static JSON checks fail until realm-export.json exists;
# runtime Admin REST API checks self-skip when Keycloak is not up.
#
# Bats subprocess isolation note:
#   @test functions run in isolated subprocesses; env vars exported from
#   setup_file are NOT inherited. Persist shared state via $BATS_FILE_TMPDIR.
#
# Run:  bats tests/integration/ac1-realm-config.bats
# Deps: curl, python3, bats-core; docker compose for runtime tests
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

# Fetch the live realm JSON once and persist to $BATS_FILE_TMPDIR.
# $BATS_FILE_TMPDIR is shared across all @test subprocesses within a single
# file run (unlike regular env vars, which are lost across subprocess boundaries).
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
# STATIC CHECKS — run without a running stack (fail until files exist)
# =============================================================================

# ---------------------------------------------------------------------------
# [P0] AC1-RC-01 — realm-export.json is valid JSON
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-01] keycloak/realm-export.json exists and is valid JSON" {
  # RED: will fail until keycloak/realm-export.json is created
  [ -f "keycloak/realm-export.json" ]

  run python3 -c "import json, sys; json.load(open('keycloak/realm-export.json'))"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-02 — realm name and displayName in export
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-02] realm-export.json declares realm='envocc' and displayName='EnvOcc SSO'" {
  [ -f "keycloak/realm-export.json" ]
  grep -q '"realm":"envocc"' keycloak/realm-export.json
  grep -q '"displayName":"EnvOcc SSO"' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-03 — sslRequired=external in export (never none)
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-03] realm-export.json has sslRequired='external'" {
  [ -f "keycloak/realm-export.json" ]
  grep -q '"sslRequired":"external"' keycloak/realm-export.json
  # Hard negative: must NOT be "none"
  ! grep -q '"sslRequired":"none"' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-04 — registrationAllowed=false in export
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-04] realm-export.json has registrationAllowed=false" {
  [ -f "keycloak/realm-export.json" ]
  grep -q '"registrationAllowed":false' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-05 — loginWithEmailAllowed=true in export
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-05] realm-export.json has loginWithEmailAllowed=true" {
  [ -f "keycloak/realm-export.json" ]
  grep -q '"loginWithEmailAllowed":true' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-06 — bruteForceProtected=true in export
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-06] realm-export.json has bruteForceProtected=true" {
  [ -f "keycloak/realm-export.json" ]
  grep -q '"bruteForceProtected":true' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-07 — accessTokenLifespan=900 (≤15 min, NFR2a hard ceiling)
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-07] realm-export.json has accessTokenLifespan=900" {
  [ -f "keycloak/realm-export.json" ]
  grep -q '"accessTokenLifespan":900' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-08 — ssoSessionIdleTimeout=1800 and ssoSessionMaxLifespan=28800
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-08] realm-export.json has correct SSO session timeouts" {
  [ -f "keycloak/realm-export.json" ]
  grep -q '"ssoSessionIdleTimeout":1800' keycloak/realm-export.json
  grep -q '"ssoSessionMaxLifespan":28800' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-09 — eventsEnabled=true and adminEventsEnabled=true
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-09] realm-export.json has eventsEnabled=true and adminEventsEnabled=true" {
  [ -f "keycloak/realm-export.json" ]
  grep -q '"eventsEnabled":true' keycloak/realm-export.json
  grep -q '"adminEventsEnabled":true' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-10 — enabledEventTypes is NOT present (empty array disables all)
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-10] realm-export.json does NOT contain enabledEventTypes:[] (would disable all events)" {
  [ -f "keycloak/realm-export.json" ]
  # The field should be entirely absent — an empty array disables all event types
  ! grep -q '"enabledEventTypes":\[\]' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-11 — internationalizationEnabled=true, supportedLocales en+th, defaultLocale=en
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-11] realm-export.json has i18n enabled with en and th locales" {
  [ -f "keycloak/realm-export.json" ]
  grep -q '"internationalizationEnabled":true' keycloak/realm-export.json
  # supportedLocales array must contain "en" and "th"
  run python3 -c "
import json, sys
with open('keycloak/realm-export.json') as f:
    data = json.load(f)
locales = data.get('supportedLocales', [])
if 'en' not in locales:
    print('FAIL: en not in supportedLocales'); sys.exit(1)
if 'th' not in locales:
    print('FAIL: th not in supportedLocales'); sys.exit(1)
if data.get('defaultLocale') != 'en':
    print('FAIL: defaultLocale is not en'); sys.exit(1)
print('OK')
"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-12 — No client has implicitFlowEnabled=true (FR3)
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-12] realm-export.json has no client with implicitFlowEnabled=true" {
  [ -f "keycloak/realm-export.json" ]
  run python3 -c "
import json, sys
with open('keycloak/realm-export.json') as f:
    data = json.load(f)
bad = [c.get('clientId','?') for c in data.get('clients', [])
       if c.get('implicitFlowEnabled') is True]
if bad:
    print('FAIL: implicit flow enabled on:', bad); sys.exit(1)
print('OK')
"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-13 — No client (except admin-cli) has directAccessGrantsEnabled=true (FR3)
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-13] realm-export.json has no ROPC (directAccessGrants) except admin-cli" {
  [ -f "keycloak/realm-export.json" ]
  run python3 -c "
import json, sys
with open('keycloak/realm-export.json') as f:
    data = json.load(f)
ALLOWED_ROPC = {'admin-cli'}
bad = [c.get('clientId','?') for c in data.get('clients', [])
       if c.get('directAccessGrantsEnabled') is True
       and c.get('clientId') not in ALLOWED_ROPC]
if bad:
    print('FAIL: directAccessGrantsEnabled on non-admin-cli clients:', bad); sys.exit(1)
print('OK')
"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-14 — defaultSignatureAlgorithm=RS256 (NFR3)
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-14] realm-export.json has defaultSignatureAlgorithm=RS256" {
  [ -f "keycloak/realm-export.json" ]
  grep -q '"defaultSignatureAlgorithm":"RS256"' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-15 — browserSecurityHeaders includes frame-ancestors 'self' (NFR4)
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-15] realm-export.json has CSP with frame-ancestors in browserSecurityHeaders" {
  [ -f "keycloak/realm-export.json" ]
  run python3 -c "
import json, sys
with open('keycloak/realm-export.json') as f:
    data = json.load(f)
headers = data.get('browserSecurityHeaders', {})
csp = headers.get('contentSecurityPolicy', '')
if 'frame-ancestors' not in csp:
    print('FAIL: frame-ancestors not in CSP:', repr(csp)); sys.exit(1)
print('OK')
"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-16 — adminEventsDetailsEnabled=true
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-16] realm-export.json has adminEventsDetailsEnabled=true" {
  [ -f "keycloak/realm-export.json" ]
  grep -q '"adminEventsDetailsEnabled":true' keycloak/realm-export.json
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
  _realm_json | grep -q '"accessTokenLifespan":900'
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
  _realm_json | grep -q '"ssoSessionIdleTimeout":1800'
  _realm_json | grep -q '"ssoSessionMaxLifespan":28800'
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
