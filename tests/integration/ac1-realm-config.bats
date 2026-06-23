#!/usr/bin/env bats
# =============================================================================
# ATDD Acceptance Tests — Story 1.2
# AC1 (static): Baseline realm configuration validation — offline JSON checks
#
# Verifies ALL required baseline settings from AC1 using only the committed
# realm-export.json file (no running stack required):
#   realm/displayName, sslRequired, registrationAllowed, loginWithEmailAllowed,
#   bruteForceProtected, accessTokenLifespan, ssoSessionIdleTimeout,
#   ssoSessionMaxLifespan, eventsEnabled, adminEventsEnabled,
#   internationalizationEnabled, supportedLocales, defaultLocale,
#   implicitFlowEnabled, directAccessGrantsEnabled, defaultSignatureAlgorithm,
#   browserSecurityHeaders.contentSecurityPolicy, adminEventsDetailsEnabled
#
# TDD Phase: RED — all tests fail until keycloak/realm-export.json exists.
#
# Run:  bats tests/integration/ac1-realm-config.bats
# Deps: python3, bats-core (no Docker required for these static checks)
# Note: Runtime/live checks are in ac1-realm-config-runtime.bats
# =============================================================================

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
  # Anchor the value with a trailing delimiter so 9000 (10x too long) cannot pass.
  grep -qE '"accessTokenLifespan":900([,}]|$)' keycloak/realm-export.json
}

# ---------------------------------------------------------------------------
# [P0] AC1-RC-08 — ssoSessionIdleTimeout=1800 and ssoSessionMaxLifespan=28800
# ---------------------------------------------------------------------------
@test "[P0][AC1-RC-08] realm-export.json has correct SSO session timeouts" {
  [ -f "keycloak/realm-export.json" ]
  # Anchor values so e.g. 18000 / 288000 cannot satisfy a prefix match.
  grep -qE '"ssoSessionIdleTimeout":1800([,}]|$)' keycloak/realm-export.json
  grep -qE '"ssoSessionMaxLifespan":28800([,}]|$)' keycloak/realm-export.json
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
