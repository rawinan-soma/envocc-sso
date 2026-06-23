#!/usr/bin/env bash
# =============================================================================
# lint-realm.sh — Realm config security lint script
#
# Reads keycloak/realm-export.json and asserts required security settings.
# Exits non-zero on any violation.
#
# Usage:
#   bash keycloak/lint-realm.sh                          # uses default path
#   bash keycloak/lint-realm.sh keycloak/realm-export.json
#
# Prerequisites: jq (brew install jq)
#
# Checks performed:
#   1. bruteForceProtected == true
#   2. accessTokenLifespan <= 900  (NFR2a: 15 min ceiling)
#   3. sslRequired != "none"
#   4. registrationAllowed == false
#   5. No KeyProvider component group present (must be omitted, not blanked)
#   6. No client has implicitFlowEnabled == true  (FR3)
#   7. No client (except admin-cli) has directAccessGrantsEnabled == true (FR3)
#   8. eventsEnabled == true
# =============================================================================

set -euo pipefail

REALM_FILE="${1:-keycloak/realm-export.json}"
ERRORS=0

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed. Install via: brew install jq"
  exit 1
fi

if [ ! -f "$REALM_FILE" ]; then
  echo "ERROR: Realm file not found: $REALM_FILE"
  exit 1
fi

echo "Linting realm config: $REALM_FILE"
echo "--------------------------------------------"

# check <description> <jq_result_is_true>
check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "true" ]; then
    echo "  OK: $desc"
  else
    echo "FAIL: $desc"
    ERRORS=$((ERRORS + 1))
  fi
}

# 1. Brute-force protection must be enabled
check "bruteForceProtected=true (FR19)" \
  "$(jq -r '.bruteForceProtected == true' "$REALM_FILE")"

# 2. Access token lifespan must be at most 900 seconds (NFR2a: ≤15 min)
check "accessTokenLifespan<=900 (NFR2a — 15 min ceiling)" \
  "$(jq -r '.accessTokenLifespan <= 900' "$REALM_FILE")"

# 3. SSL must not be none (never disable TLS requirement)
check "sslRequired!=\"none\" (must be external or all)" \
  "$(jq -r '.sslRequired != "none"' "$REALM_FILE")"

# 4. Self-registration must be disabled
check "registrationAllowed=false" \
  "$(jq -r '.registrationAllowed == false' "$REALM_FILE")"

# 5. KeyProvider components must be entirely absent (not blanked)
#    Omitting the group lets Keycloak auto-generate fresh keys.
#    Blanking privateKey:[""] causes InvalidKeySpecException on import.
check "KeyProvider components absent (org.keycloak.keys.KeyProvider omitted)" \
  "$(jq -r '
    if .components == null then true
    elif (.components | type) == "object" then
      (.components | to_entries |
       map(.value | if type == "array" then .[] else . end) |
       map(select(.providerId != null)) |
       map(.providerId) |
       contains(["rsa-generated"]) | not)
    else true
    end
  ' "$REALM_FILE")"

# 6. No client may have implicitFlowEnabled=true (FR3)
check "No client has implicitFlowEnabled=true (FR3 — no Implicit grant)" \
  "$(jq -r '[.clients[]? | select(.implicitFlowEnabled == true)] | length == 0' "$REALM_FILE")"

# 7. No client (except admin-cli) may have directAccessGrantsEnabled=true (FR3)
check "No non-admin-cli client has directAccessGrantsEnabled=true (FR3 — no ROPC)" \
  "$(jq -r '
    [.clients[]?
     | select(.directAccessGrantsEnabled == true)
     | select(.clientId != "admin-cli")]
    | length == 0
  ' "$REALM_FILE")"

# 8. Login event capture must be enabled
check "eventsEnabled=true (audit foundation)" \
  "$(jq -r '.eventsEnabled == true' "$REALM_FILE")"

echo "--------------------------------------------"
if [ "$ERRORS" -eq 0 ]; then
  echo "Realm lint: PASS"
  exit 0
else
  echo "Realm lint: FAIL ($ERRORS error(s))"
  exit 1
fi
