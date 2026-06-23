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
#   3. sslRequired in {external, all}  (never "none")
#   4. registrationAllowed == false
#   5. org.keycloak.keys.KeyProvider group entirely absent (not blanked)
#   6. No client has implicitFlowEnabled == true  (FR3)
#   7. No client (except admin-cli) has directAccessGrantsEnabled == true (FR3)
#   8. eventsEnabled == true
#   9. adminEventsEnabled == true  (AC1, task 2.7)
#  10. adminEventsDetailsEnabled == true  (AC1, task 2.7)
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

# 2. Access token lifespan must be present, numeric, and at most 900 seconds.
#    (jq treats `null <= 900` as true, so a MISSING key would silently pass —
#     require an explicit number to fail loudly on an omitted/typed key.)
check "accessTokenLifespan<=900 (NFR2a — 15 min ceiling)" \
  "$(jq -r '(.accessTokenLifespan | type) == "number" and .accessTokenLifespan <= 900' "$REALM_FILE")"

# 3. SSL must be required. Assert positive membership rather than just !=none,
#    so a missing/empty/typo'd value fails instead of slipping through.
check "sslRequired in {external, all} (TLS required)" \
  "$(jq -r '.sslRequired == "external" or .sslRequired == "all"' "$REALM_FILE")"

# 4. Self-registration must be disabled
check "registrationAllowed=false" \
  "$(jq -r '.registrationAllowed == false' "$REALM_FILE")"

# 5. org.keycloak.keys.KeyProvider group must be entirely absent (not blanked).
#    Omitting the group lets Keycloak auto-generate fresh keys.
#    Blanking privateKey:[""] causes InvalidKeySpecException on import.
#    We check group-key absence (matching AC2) rather than a denylist of
#    specific providerIds — Keycloak 26 ships ecdsa-generated and ed25519-generated
#    that a denylist approach would silently miss.
check "KeyProvider group entirely absent (org.keycloak.keys.KeyProvider must not be present)" \
  "$(jq -r '.components["org.keycloak.keys.KeyProvider"] == null' "$REALM_FILE")"

# 6. No client may have implicitFlowEnabled=true (FR3).
#    Guard: if the 'clients' key is missing entirely, flag it explicitly — a
#    clients-absent export means FR3 is completely unverified.
check "clients array present (required for FR3 checks)" \
  "$(jq -r '(.clients | type) == "array"' "$REALM_FILE")"

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

# 9. Admin event capture must be enabled (AC1, task 2.7)
check "adminEventsEnabled=true (AC1 — admin audit)" \
  "$(jq -r '.adminEventsEnabled == true' "$REALM_FILE")"

# 10. Admin event details must be captured (AC1, task 2.7)
check "adminEventsDetailsEnabled=true (AC1 — admin event details)" \
  "$(jq -r '.adminEventsDetailsEnabled == true' "$REALM_FILE")"

echo "--------------------------------------------"
if [ "$ERRORS" -eq 0 ]; then
  echo "Realm lint: PASS"
  exit 0
else
  echo "Realm lint: FAIL ($ERRORS error(s))"
  exit 1
fi
