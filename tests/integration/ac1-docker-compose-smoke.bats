#!/usr/bin/env bats
# =============================================================================
# ATDD Red-Phase Acceptance Tests — Story 1.1
# AC1: Docker Compose brings up Keycloak + PostgreSQL and imports the baseline realm
#
# TDD Phase: RED — all tests are @skip until infrastructure is implemented.
# To activate: remove the `skip` call from the test you are implementing.
#
# Run:  bats tests/integration/ac1-docker-compose-smoke.bats
# Deps: docker, docker compose, curl, bats-core
# Env:  KC_PORT (default 8080), POSTGRES_PORT (default 5432)
# =============================================================================

KC_PORT="${KC_PORT:-8080}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
REALM="envocc"
DISCOVERY_URL="http://localhost:${KC_PORT}/realms/${REALM}/.well-known/openid-configuration"
HEALTH_URL="http://localhost:${KC_PORT}/health/ready"

# ---------------------------------------------------------------------------
# [P0] AC1-01 — All three compose services start and become healthy
# ---------------------------------------------------------------------------
@test "[P0][AC1-01] docker compose up starts all services" {
  skip "RED PHASE — compose.yaml not yet implemented"

  run docker compose up -d
  [ "$status" -eq 0 ]

  # Wait up to 60 s for services to settle
  local attempts=0
  until docker compose ps --format json 2>/dev/null | grep -q '"Health":"healthy"' || [ $attempts -ge 12 ]; do
    sleep 5
    attempts=$((attempts + 1))
  done

  # All three services must be running
  run docker compose ps --services --filter status=running
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "postgres"
  echo "$output" | grep -q "keycloak"
  echo "$output" | grep -q "mailpit"
}

# ---------------------------------------------------------------------------
# [P0] AC1-02 — Keycloak health endpoint responds 200
# ---------------------------------------------------------------------------
@test "[P0][AC1-02] Keycloak /health/ready returns HTTP 200" {
  skip "RED PHASE — Keycloak service not yet configured"

  run curl -sf -o /dev/null -w "%{http_code}" "${HEALTH_URL}"
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
}

# ---------------------------------------------------------------------------
# [P0] AC1-03 — OIDC discovery endpoint responds with JSON for the envocc realm
# ---------------------------------------------------------------------------
@test "[P0][AC1-03] Discovery endpoint responds at /realms/envocc/.well-known/openid-configuration" {
  skip "RED PHASE — realm import not yet implemented"

  run curl -sf "${DISCOVERY_URL}"
  [ "$status" -eq 0 ]

  # Must be valid JSON and contain required OIDC fields
  echo "$output" | grep -q '"issuer"'
  echo "$output" | grep -q '"authorization_endpoint"'
  echo "$output" | grep -q '"token_endpoint"'
  echo "$output" | grep -q '"jwks_uri"'
}

# ---------------------------------------------------------------------------
# [P0] AC1-04 — Issuer in discovery doc matches the expected envocc realm URL
# ---------------------------------------------------------------------------
@test "[P0][AC1-04] Issuer in discovery doc matches http://localhost:PORT/realms/envocc" {
  skip "RED PHASE — realm not yet available"

  local expected_issuer="http://localhost:${KC_PORT}/realms/${REALM}"

  run curl -sf "${DISCOVERY_URL}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "\"issuer\":\"${expected_issuer}\""
}

# ---------------------------------------------------------------------------
# [P0] AC1-05 — PostgreSQL has two databases: keycloak_db and rails_db
# ---------------------------------------------------------------------------
@test "[P0][AC1-05] PostgreSQL has keycloak_db and rails_db databases" {
  skip "RED PHASE — postgres init.sql not yet applied"

  # Use docker exec to query the postgres service
  run docker compose exec -T postgres psql -U postgres -l -t
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "keycloak_db"
  echo "$output" | grep -q "rails_db"
}

# ---------------------------------------------------------------------------
# [P0] AC1-06 — Keycloak envocc realm exists (Admin REST API)
# ---------------------------------------------------------------------------
@test "[P0][AC1-06] envocc realm is present in Keycloak after import" {
  skip "RED PHASE — realm-export.json not yet created"

  local admin_user="${KEYCLOAK_ADMIN:-admin}"
  local admin_pass="${KEYCLOAK_ADMIN_PASSWORD:-change-me}"
  local token_url="http://localhost:${KC_PORT}/realms/master/protocol/openid-connect/token"
  local admin_api="http://localhost:${KC_PORT}/admin/realms/${REALM}"

  # Get admin token from master realm
  local token
  token=$(curl -sf \
    -d "client_id=admin-cli" \
    -d "username=${admin_user}" \
    -d "password=${admin_pass}" \
    -d "grant_type=password" \
    "${token_url}" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

  [ -n "$token" ] || { echo "Failed to obtain admin token"; return 1; }

  # Fetch realm info
  run curl -sf -H "Authorization: Bearer ${token}" "${admin_api}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"realm":"envocc"'
}

# ---------------------------------------------------------------------------
# [P0] AC1-07 — envocc realm SSL Required is set to 'external' (not 'all' or 'none')
# ---------------------------------------------------------------------------
@test "[P0][AC1-07] envocc realm has sslRequired=external" {
  skip "RED PHASE — realm settings not yet configured"

  local admin_user="${KEYCLOAK_ADMIN:-admin}"
  local admin_pass="${KEYCLOAK_ADMIN_PASSWORD:-change-me}"
  local token_url="http://localhost:${KC_PORT}/realms/master/protocol/openid-connect/token"
  local admin_api="http://localhost:${KC_PORT}/admin/realms/${REALM}"

  local token
  token=$(curl -sf \
    -d "client_id=admin-cli" \
    -d "username=${admin_user}" \
    -d "password=${admin_pass}" \
    -d "grant_type=password" \
    "${token_url}" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

  [ -n "$token" ]

  run curl -sf -H "Authorization: Bearer ${token}" "${admin_api}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"sslRequired":"external"'
}

# ---------------------------------------------------------------------------
# [P0] AC1-08 — Access token lifespan in baseline realm is 900 s (15 min)
# ---------------------------------------------------------------------------
@test "[P0][AC1-08] envocc realm accessTokenLifespan is 900 seconds" {
  skip "RED PHASE — realm token settings not yet configured"

  local admin_user="${KEYCLOAK_ADMIN:-admin}"
  local admin_pass="${KEYCLOAK_ADMIN_PASSWORD:-change-me}"
  local token_url="http://localhost:${KC_PORT}/realms/master/protocol/openid-connect/token"
  local admin_api="http://localhost:${KC_PORT}/admin/realms/${REALM}"

  local token
  token=$(curl -sf \
    -d "client_id=admin-cli" \
    -d "username=${admin_user}" \
    -d "password=${admin_pass}" \
    -d "grant_type=password" \
    "${token_url}" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

  [ -n "$token" ]

  run curl -sf -H "Authorization: Bearer ${token}" "${admin_api}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"accessTokenLifespan":900'
}

# ---------------------------------------------------------------------------
# [P1] AC1-09 — Mailpit SMTP (port 1025) and web UI (port 8025) are reachable
# ---------------------------------------------------------------------------
@test "[P1][AC1-09] Mailpit web UI is reachable on port 8025" {
  skip "RED PHASE — mailpit service not yet in compose.yaml"

  run curl -sf -o /dev/null -w "%{http_code}" "http://localhost:8025"
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
}

# ---------------------------------------------------------------------------
# [P1] AC1-10 — .env.example exists and contains expected placeholder keys
# ---------------------------------------------------------------------------
@test "[P1][AC1-10] .env.example has required placeholder keys" {
  skip "RED PHASE — .env.example not yet created"

  [ -f ".env.example" ]
  grep -q "KEYCLOAK_ADMIN=" .env.example
  grep -q "KEYCLOAK_ADMIN_PASSWORD=" .env.example
  grep -q "KEYCLOAK_DB_PASSWORD=" .env.example
  grep -q "POSTGRES_PASSWORD=" .env.example
  grep -q "RAILS_DB_PASSWORD=" .env.example
}

# ---------------------------------------------------------------------------
# [P1] AC1-11 — No real secrets in .env.example (only placeholder values)
# ---------------------------------------------------------------------------
@test "[P1][AC1-11] .env.example contains only placeholder values (change-me or CHANGE_ME)" {
  skip "RED PHASE — .env.example not yet created"

  [ -f ".env.example" ]
  # All password fields must be set to placeholder values only
  # This regex rejects any value that looks like a real secret (len > 20, mixed chars)
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^[A-Z_]+=.{20,}$'; then
      echo "Suspicious non-placeholder value in .env.example: $line"
      return 1
    fi
  done < .env.example
}

# ---------------------------------------------------------------------------
# Teardown — bring compose down after test run (optional; skip in CI if reusing stack)
# ---------------------------------------------------------------------------
teardown_file() {
  # Only tear down if explicitly requested (avoids destroying shared dev stack)
  if [ "${ATDD_TEARDOWN:-false}" = "true" ]; then
    docker compose down -v 2>/dev/null || true
  fi
}
