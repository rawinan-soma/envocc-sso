#!/usr/bin/env bats
# tests/unit/oidc-pkce-lint.bats
# ATDD unit tests — Story 2.2: OIDC Authorization Code + PKCE Login (Hosted Credentials)
#
# AC1: Auth Code + PKCE only; Implicit and ROPC unavailable (FR1, FR3)
# AC4: Auth code single-use, short-lived (≤60s), PKCE-bound, replay-detected (FR47)
#
# Test scenarios covered:
#   TS-220h [P0] lint-realm-export.py exits 1 when accessCodeLifespan is absent
#   TS-220n [P1] lint-realm-export.py exits 1 when accessCodeLifespan > 60
#   TS-220i [P0] lint-realm-export.py exits 1 when a client has implicitFlowEnabled: true
#   TS-220j [P0] lint-realm-export.py exits 1 when a client has directAccessGrantsEnabled: true
#   TS-220k [P0] lint-realm-export.py exits 1 when a public client lacks PKCE S256 attribute
#   TS-220l [P1] lint-realm-export.py exits 0 for valid Story 2.2 configuration
#   TS-220m [P1] lint-realm-export.py exits 0 when clients key is absent (no-op)
#
# Run: bats tests/unit/oidc-pkce-lint.bats
# No live Keycloak stack required. Tests use ephemeral temp JSON files.
#
# Red-phase scaffolds: each @test starts with skip "RED PHASE — ..."
# Activate by removing the skip line when implementing the corresponding Task.

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Write a JSON string to a temp file; echo the path
write_realm_json() {
  local tmpfile
  tmpfile=$(mktemp /tmp/realm-export-test-XXXXXX.json)
  printf '%s' "${1}" > "${tmpfile}"
  echo "${tmpfile}"
}

# Run the lint script against a given file path
run_lint() {
  local json_file="${1}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${json_file}"
}

# ---------------------------------------------------------------------------
# TS-220h [P0] — lint detects absent accessCodeLifespan (AC4)
# ---------------------------------------------------------------------------
@test "[P0][TS-220h] lint-realm-export.py exits 1 when accessCodeLifespan is absent" {
  local tmpfile
  tmpfile=$(write_realm_json \
    '{"realm":"envocc","enabled":true,"bruteForceProtected":true,"accessTokenLifespan":900}')
  run_lint "${tmpfile}"
  rm -f "${tmpfile}"
  assert_failure
  assert_output --partial "accessCodeLifespan"
}

# ---------------------------------------------------------------------------
# TS-220n [P1] — lint detects accessCodeLifespan value > 60 (AC4)
# ---------------------------------------------------------------------------
@test "[P1][TS-220n] lint-realm-export.py exits 1 when accessCodeLifespan is 120 (> 60)" {
  local tmpfile
  tmpfile=$(write_realm_json \
    '{"realm":"envocc","enabled":true,"bruteForceProtected":true,"accessTokenLifespan":900,"accessCodeLifespan":120}')
  run_lint "${tmpfile}"
  rm -f "${tmpfile}"
  assert_failure
  assert_output --partial "accessCodeLifespan"
}

# ---------------------------------------------------------------------------
# TS-220i [P0] — lint detects implicitFlowEnabled: true on client (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-220i] lint-realm-export.py exits 1 when a client has implicitFlowEnabled: true" {
  local tmpfile
  tmpfile=$(write_realm_json '{
    "realm":"envocc","enabled":true,"bruteForceProtected":true,
    "accessTokenLifespan":900,"accessCodeLifespan":60,
    "clients":[{
      "clientId":"bad-implicit-client",
      "implicitFlowEnabled":true,
      "directAccessGrantsEnabled":false,
      "publicClient":true,
      "attributes":{"pkce.code.challenge.method":"S256"}
    }]
  }')
  run_lint "${tmpfile}"
  rm -f "${tmpfile}"
  assert_failure
  assert_output --partial "implicitFlowEnabled"
}

# ---------------------------------------------------------------------------
# TS-220j [P0] — lint detects directAccessGrantsEnabled: true on client (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-220j] lint-realm-export.py exits 1 when a client has directAccessGrantsEnabled: true" {
  local tmpfile
  tmpfile=$(write_realm_json '{
    "realm":"envocc","enabled":true,"bruteForceProtected":true,
    "accessTokenLifespan":900,"accessCodeLifespan":60,
    "clients":[{
      "clientId":"bad-ropc-client",
      "implicitFlowEnabled":false,
      "directAccessGrantsEnabled":true,
      "publicClient":true,
      "attributes":{"pkce.code.challenge.method":"S256"}
    }]
  }')
  run_lint "${tmpfile}"
  rm -f "${tmpfile}"
  assert_failure
  assert_output --partial "directAccessGrantsEnabled"
}

# ---------------------------------------------------------------------------
# TS-220k [P0] — lint detects missing PKCE S256 on public client (AC1/AC4)
# ---------------------------------------------------------------------------
@test "[P0][TS-220k] lint-realm-export.py exits 1 when a public client has no pkce.code.challenge.method: S256" {
  local tmpfile
  tmpfile=$(write_realm_json '{
    "realm":"envocc","enabled":true,"bruteForceProtected":true,
    "accessTokenLifespan":900,"accessCodeLifespan":60,
    "clients":[{
      "clientId":"no-pkce-client",
      "implicitFlowEnabled":false,
      "directAccessGrantsEnabled":false,
      "publicClient":true,
      "attributes":{}
    }]
  }')
  run_lint "${tmpfile}"
  rm -f "${tmpfile}"
  assert_failure
  assert_output --partial "pkce.code.challenge.method"
}

# ---------------------------------------------------------------------------
# TS-220k2 [P0] — lint detects absent attributes key on public client (AC1/AC4)
# ---------------------------------------------------------------------------
@test "[P0][TS-220k2] lint-realm-export.py exits 1 when a public client has no attributes key at all" {
  local tmpfile
  tmpfile=$(write_realm_json '{
    "realm":"envocc","enabled":true,"bruteForceProtected":true,
    "accessTokenLifespan":900,"accessCodeLifespan":60,
    "clients":[{
      "clientId":"no-attributes-client",
      "implicitFlowEnabled":false,
      "directAccessGrantsEnabled":false,
      "publicClient":true
    }]
  }')
  run_lint "${tmpfile}"
  rm -f "${tmpfile}"
  assert_failure
  assert_output --partial "pkce.code.challenge.method"
}

# ---------------------------------------------------------------------------
# TS-220l [P1] — lint passes on fully compliant Story 2.2 configuration (AC1, AC4)
# ---------------------------------------------------------------------------
@test "[P1][TS-220l] lint-realm-export.py exits 0 for valid Story 2.2 realm configuration" {
  local tmpfile
  tmpfile=$(write_realm_json '{
    "realm":"envocc","enabled":true,"bruteForceProtected":true,
    "accessTokenLifespan":900,"accessCodeLifespan":60,
    "clients":[{
      "clientId":"test-oidc-client",
      "name":"Test OIDC Client (integration tests only)",
      "enabled":true,
      "protocol":"openid-connect",
      "standardFlowEnabled":true,
      "implicitFlowEnabled":false,
      "directAccessGrantsEnabled":false,
      "publicClient":true,
      "serviceAccountsEnabled":false,
      "authorizationServicesEnabled":false,
      "consentRequired":false,
      "fullScopeAllowed":false,
      "redirectUris":["http://localhost:8888/callback"],
      "webOrigins":["http://localhost:8888"],
      "attributes":{"pkce.code.challenge.method":"S256"}
    }]
  }')
  run_lint "${tmpfile}"
  rm -f "${tmpfile}"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-220m [P1] — lint handles absent clients key gracefully (AC1)
# ---------------------------------------------------------------------------
@test "[P1][TS-220m] lint-realm-export.py exits 0 when clients key is absent (no clients to check)" {
  local tmpfile
  tmpfile=$(write_realm_json \
    '{"realm":"envocc","enabled":true,"bruteForceProtected":true,"accessTokenLifespan":900,"accessCodeLifespan":60}')
  run_lint "${tmpfile}"
  rm -f "${tmpfile}"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-220m2 [P1] — lint handles empty clients array gracefully (AC1)
# ---------------------------------------------------------------------------
@test "[P1][TS-220m2] lint-realm-export.py exits 0 when clients array is empty" {
  local tmpfile
  tmpfile=$(write_realm_json \
    '{"realm":"envocc","enabled":true,"bruteForceProtected":true,"accessTokenLifespan":900,"accessCodeLifespan":60,"clients":[]}')
  run_lint "${tmpfile}"
  rm -f "${tmpfile}"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-220p [P1] — lint reports clientId in per-client violation message (Task 3.5)
# ---------------------------------------------------------------------------
@test "[P1][TS-220p] lint-realm-export.py includes clientId in per-client violation output" {
  local tmpfile
  tmpfile=$(write_realm_json '{
    "realm":"envocc","enabled":true,"bruteForceProtected":true,
    "accessTokenLifespan":900,"accessCodeLifespan":60,
    "clients":[{
      "clientId":"identifiable-bad-client",
      "implicitFlowEnabled":true,
      "directAccessGrantsEnabled":false,
      "publicClient":false
    }]
  }')
  run_lint "${tmpfile}"
  rm -f "${tmpfile}"
  assert_failure
  assert_output --partial "identifiable-bad-client"
}

# ---------------------------------------------------------------------------
# TS-220q [P1] — lint script passes against the real realm-export.json after Story 2.2 changes
# Smoke test: the updated lint script must pass against the updated file.
# ---------------------------------------------------------------------------
@test "[P1][TS-220q] lint-realm-export.py exits 0 against the real keycloak/realm-export.json after Story 2.2 changes" {
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py"
  assert_success
}
