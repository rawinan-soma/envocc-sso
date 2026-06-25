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
# Checks: bruteForceProtected, accessTokenLifespan, ssoSessionIdleTimeout
# ---------------------------------------------------------------------------
@test "[P1][TS-201d] Baseline realm settings match realm-export.json spec" {
  local token
  token=$(get_admin_token) || fail "Could not obtain admin token"

  # Fetch realm JSON and write to a temp file to avoid shell-interpolation risks
  # when passing large JSON strings into python3 -c "..." inline scripts.
  local realm_tmpfile
  realm_tmpfile=$(mktemp)

  # Guard the curl explicitly so a network/auth failure surfaces a clear message
  # rather than an opaque JSONDecodeError from python3 on the next step.
  # Capture curl's exit code before rm -f can overwrite $?.
  local curl_exit=0
  curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc" > "${realm_tmpfile}" \
    || curl_exit=$?
  if [[ "${curl_exit}" -ne 0 ]]; then
    rm -f "${realm_tmpfile}"
    fail "Could not fetch realm JSON from Admin API (curl exited ${curl_exit})"
  fi

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
]

for key, expected in checks:
    actual = d.get(key)
    if actual != expected:
        failures.append(f'{key}: expected={expected} actual={actual}')

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

  assert_equal "${oidc_status}" "200" "OIDC discovery did not return 200 after 30 s post-healthy wait (got: ${oidc_status})"
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
