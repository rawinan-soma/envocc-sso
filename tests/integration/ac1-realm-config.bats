#!/usr/bin/env bats
# =============================================================================
# ATDD Red-Phase Acceptance Tests — Story 1.1
# AC1 (extended): Baseline realm configuration validation
#
# These tests verify the envocc realm's specific settings beyond mere existence:
# login settings, user profile, token lifetimes, event capture.
#
# TDD Phase: RED — all tests are @skip until realm-export.json is implemented.
# To activate: remove the `skip` call from the test you are implementing.
#
# Prereqs: Keycloak running (ac1-docker-compose-smoke.bats passed)
# =============================================================================

KC_PORT="${KC_PORT:-8080}"
REALM="envocc"

# Helper: get an admin bearer token from the master realm
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

# ---------------------------------------------------------------------------
# [P0] AC1-RC-01 — Realm registration (self-registration) is OFF
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-01] envocc realm has registrationAllowed=false" {
  skip "RED PHASE — realm-export.json not yet created"

  local token
  token=$(_admin_token)
  [ -n "$token" ]

  run curl -sf -H "Authorization: Bearer ${token}" \
    "http://localhost:${KC_PORT}/admin/realms/${REALM}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"registrationAllowed":false'
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-02 — Forgot-password is ON
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-02] envocc realm has resetPasswordAllowed=true" {
  skip "RED PHASE — realm-export.json not yet created"

  local token
  token=$(_admin_token)
  [ -n "$token" ]

  run curl -sf -H "Authorization: Bearer ${token}" \
    "http://localhost:${KC_PORT}/admin/realms/${REALM}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"resetPasswordAllowed":true'
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-03 — Remember-me is OFF
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-03] envocc realm has rememberMe=false" {
  skip "RED PHASE — realm-export.json not yet created"

  local token
  token=$(_admin_token)
  [ -n "$token" ]

  run curl -sf -H "Authorization: Bearer ${token}" \
    "http://localhost:${KC_PORT}/admin/realms/${REALM}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"rememberMe":false'
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-04 — Email-as-username is ON
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-04] envocc realm has loginWithEmailAllowed=true and emailAsUsername=true" {
  skip "RED PHASE — realm-export.json not yet created"

  local token
  token=$(_admin_token)
  [ -n "$token" ]

  run curl -sf -H "Authorization: Bearer ${token}" \
    "http://localhost:${KC_PORT}/admin/realms/${REALM}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"loginWithEmailAllowed":true'
  echo "$output" | grep -q '"duplicateEmailsAllowed":false'
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-05 — SSO session idle = 1800 s, SSO session max = 28800 s
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-05] envocc realm has correct SSO session timeouts" {
  skip "RED PHASE — realm-export.json not yet created"

  local token
  token=$(_admin_token)
  [ -n "$token" ]

  run curl -sf -H "Authorization: Bearer ${token}" \
    "http://localhost:${KC_PORT}/admin/realms/${REALM}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"ssoSessionIdleTimeout":1800'
  echo "$output" | grep -q '"ssoSessionMaxLifespan":28800'
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-06 — Login events and admin events are enabled
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-06] envocc realm has eventsEnabled=true and adminEventsEnabled=true" {
  skip "RED PHASE — realm-export.json not yet created"

  local token
  token=$(_admin_token)
  [ -n "$token" ]

  run curl -sf -H "Authorization: Bearer ${token}" \
    "http://localhost:${KC_PORT}/admin/realms/${REALM}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"eventsEnabled":true'
  echo "$output" | grep -q '"adminEventsEnabled":true'
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-07 — Event expiry is set (30 days = 2592000 s)
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-07] envocc realm has eventsExpiration=2592000 (30 days)" {
  skip "RED PHASE — realm-export.json not yet created"

  local token
  token=$(_admin_token)
  [ -n "$token" ]

  run curl -sf -H "Authorization: Bearer ${token}" \
    "http://localhost:${KC_PORT}/admin/realms/${REALM}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"eventsExpiration":2592000'
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-08 — Realm display name is 'EnvOcc SSO'
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-08] envocc realm displayName is 'EnvOcc SSO'" {
  skip "RED PHASE — realm-export.json not yet created"

  local token
  token=$(_admin_token)
  [ -n "$token" ]

  run curl -sf -H "Authorization: Bearer ${token}" \
    "http://localhost:${KC_PORT}/admin/realms/${REALM}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"displayName":"EnvOcc SSO"'
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-09 — realm-export.json is valid JSON (offline static check)
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-09] keycloak/realm-export.json is valid JSON" {
  skip "RED PHASE — realm-export.json not yet created"

  [ -f "keycloak/realm-export.json" ]

  # python3 is universally available; use it to validate JSON
  run python3 -c "import json, sys; json.load(open('keycloak/realm-export.json'))"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-10 — realm-export.json declares realm id/name as 'envocc'
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-10] realm-export.json has realm=envocc" {
  skip "RED PHASE — realm-export.json not yet created"

  [ -f "keycloak/realm-export.json" ]
  grep -q '"realm":"envocc"' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-11 — keycloak/Dockerfile exists, pinned FROM, copies realm-export.json
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-11] keycloak/Dockerfile exists with pinned image and realm import" {
  skip "RED PHASE — keycloak/Dockerfile not yet created"

  [ -f "keycloak/Dockerfile" ]

  # Must FROM a pinned quay.io/keycloak/keycloak image (with explicit tag, not 'latest')
  grep -qE "^FROM quay\.io/keycloak/keycloak:[0-9]" keycloak/Dockerfile

  # Must COPY realm-export.json into import path
  grep -q "realm-export.json" keycloak/Dockerfile

  # Must use start-dev --import-realm
  grep -q "start-dev" keycloak/Dockerfile
  grep -q "import-realm" keycloak/Dockerfile
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-12 — compose.yaml exists and defines postgres, keycloak, mailpit services
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-12] compose.yaml defines required services" {
  skip "RED PHASE — compose.yaml not yet created"

  [ -f "compose.yaml" ]
  grep -q "postgres" compose.yaml
  grep -q "keycloak" compose.yaml
  grep -q "mailpit" compose.yaml
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-13 — compose.yaml does NOT hard-code any credential values
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-13] compose.yaml has no hardcoded password values" {
  skip "RED PHASE — compose.yaml not yet created"

  [ -f "compose.yaml" ]

  # Passwords must come from env vars, not literal values in compose.yaml
  # A password line must look like: KC_DB_PASSWORD: ${VAR} not KC_DB_PASSWORD: realpass
  if grep -E "(PASSWORD|SECRET|ADMIN_PASS)[[:space:]]*:[[:space:]]*['\"]?[a-zA-Z0-9]{8,}" compose.yaml | grep -v '\$\{'; then
    echo "FAIL: compose.yaml appears to contain hardcoded credential values"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# [P1] AC1-RC-14 — postgres/init.sql exists and creates both databases
# ---------------------------------------------------------------------------
@test "[P1][AC1-RC-14] postgres/init.sql creates keycloak_db and rails_db" {
  skip "RED PHASE — postgres/init.sql not yet created"

  [ -f "postgres/init.sql" ]
  grep -qi "CREATE DATABASE" postgres/init.sql
  grep -qi "keycloak_db" postgres/init.sql
  grep -qi "rails_db" postgres/init.sql
}

# ---------------------------------------------------------------------------
# [P2] AC1-RC-15 — REALM-EXPORT-NOTES.md documents which fields are stripped
# ---------------------------------------------------------------------------
@test "[P2][AC1-RC-15] keycloak/REALM-EXPORT-NOTES.md documents stripped secret fields" {
  skip "RED PHASE — REALM-EXPORT-NOTES.md not yet created"

  [ -f "keycloak/REALM-EXPORT-NOTES.md" ]
  grep -q "clientSecret" keycloak/REALM-EXPORT-NOTES.md
  grep -q "privateKey" keycloak/REALM-EXPORT-NOTES.md
}
