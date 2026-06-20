#!/usr/bin/env bats
# =============================================================================
# ATDD Acceptance Tests — Story 1.1
# AC1: Docker Compose brings up Keycloak + PostgreSQL and imports the baseline realm
#
# TDD Phase: GREEN — infrastructure implemented; skip guards removed.
# Tests that require a running Docker stack are guard-skipped if stack isn't up.
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

# Helper: skip if docker compose stack isn't up
kc_running() {
  curl -sf -o /dev/null -w "%{http_code}" "${HEALTH_URL}" 2>/dev/null | grep -q "200"
}

# ---------------------------------------------------------------------------
# [P0] AC1-01 — compose.yaml file exists with required services
# ---------------------------------------------------------------------------
@test "[P0][AC1-01] compose.yaml exists and defines postgres, keycloak, mailpit services" {
  [ -f "compose.yaml" ]
  grep -q "postgres" compose.yaml
  grep -q "keycloak" compose.yaml
  grep -q "mailpit" compose.yaml
}

# ---------------------------------------------------------------------------
# [P0] AC1-02 — Keycloak health endpoint responds 200 (requires running stack)
# ---------------------------------------------------------------------------
@test "[P0][AC1-02] Keycloak /health/ready returns HTTP 200" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"

  run curl -sf -o /dev/null -w "%{http_code}" "${HEALTH_URL}"
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
}

# ---------------------------------------------------------------------------
# [P0] AC1-03 — OIDC discovery endpoint responds with JSON for the envocc realm
# ---------------------------------------------------------------------------
@test "[P0][AC1-03] Discovery endpoint responds at /realms/envocc/.well-known/openid-configuration" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"

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
  kc_running || skip "Keycloak not running — start with: docker compose up -d"

  local expected_issuer="http://localhost:${KC_PORT}/realms/${REALM}"

  run curl -sf "${DISCOVERY_URL}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "\"issuer\":\"${expected_issuer}\""
}

# ---------------------------------------------------------------------------
# [P0] AC1-05 — PostgreSQL has two databases: keycloak_db and rails_db
# ---------------------------------------------------------------------------
@test "[P0][AC1-05] PostgreSQL has keycloak_db and rails_db databases" {
  command -v docker >/dev/null 2>&1 || skip "docker not installed"
  docker compose ps --services 2>/dev/null | grep -q "postgres" || skip "postgres service not running"

  # Use docker exec to query the postgres service
  run docker compose exec -T postgres psql -U "${POSTGRES_USER:-postgres}" -l -t
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "keycloak_db"
  echo "$output" | grep -q "rails_db"
}

# ---------------------------------------------------------------------------
# [P0] AC1-06 — Keycloak envocc realm exists (Admin REST API)
# ---------------------------------------------------------------------------
@test "[P0][AC1-06] envocc realm is present in Keycloak after import" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"

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
  kc_running || skip "Keycloak not running — start with: docker compose up -d"

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
  kc_running || skip "Keycloak not running — start with: docker compose up -d"

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
  curl -sf -o /dev/null "http://localhost:8025" 2>/dev/null || skip "Mailpit not running — start with: docker compose up -d"

  run curl -sf -o /dev/null -w "%{http_code}" "http://localhost:8025"
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
}

# ---------------------------------------------------------------------------
# [P1] AC1-10 — .env.example exists and contains expected placeholder keys
# ---------------------------------------------------------------------------
@test "[P1][AC1-10] .env.example has required placeholder keys" {
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
@test "[P1][AC1-11] .env.example secret variables contain only placeholder values" {
  [ -f ".env.example" ]
  # Only check variables whose underscore-delimited name segments indicate secrets:
  # PASSWORD, SECRET, KEY, TOKEN, or MASTER as a whole segment (not as a substring).
  # Pattern (^|_)KEYWORD(_|=) anchors on _ boundaries so KEYCLOAK_ADMIN is skipped
  # but KEYCLOAK_ADMIN_PASSWORD, KC_DB_PASSWORD, SECRET_KEY, MASTER_KEY are caught.
  # Non-secret vars like KC_DB_URL (a JDBC connection string) are intentionally excluded.
  # Review fix: previous regex '^[A-Z_]+=.{20,}$' falsely flagged KC_DB_URL (43 chars).
  while IFS= read -r line; do
    # Skip blank lines and comments
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue
    # Extract var name (part before first '=')
    local varname
    varname="${line%%=*}"
    # Check if any underscore-delimited segment is a secret keyword
    if echo "_${varname}=" | grep -qE '_(PASSWORD|SECRET|KEY|TOKEN|MASTER)(_|=)'; then
      local val
      val="${line#*=}"
      # Value must be a known placeholder (case-insensitive) or empty
      if ! echo "$val" | grep -qiE '^(change-me|change_me|placeholder|test-only|changeit|your[-_]password|)$'; then
        echo "Non-placeholder secret value detected in .env.example: $line"
        return 1
      fi
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
