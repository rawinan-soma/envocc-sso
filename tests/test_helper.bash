#!/usr/bin/env bash
# =============================================================================
# test_helper.bash — Shared BATS helpers for envocc-sso integration tests
#
# Source this from any BATS file that needs the common helpers:
#   load "../test_helper"   (from tests/integration/)
#   load "../../test_helper" (from tests/secret-hygiene/)
# =============================================================================

KC_PORT="${KC_PORT:-8080}"
REALM="envocc"

# kc_running — returns 0 if the Keycloak envocc realm is reachable, 1 otherwise.
# Uses the realm endpoint as the readiness probe because Keycloak 26 serves
# /health/ready on the management port (9000) which is NOT published to the host.
kc_running() {
  curl -sf -o /dev/null -w "%{http_code}" \
    "http://localhost:${KC_PORT}/realms/${REALM}" 2>/dev/null | grep -q "200"
}

# _admin_token — fetches an admin bearer token from the master realm.
# Returns empty string on auth failure; caller must check.
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
