#!/usr/bin/env bats
# =============================================================================
# ATDD Acceptance Tests — Story 1.2
# AC1 (smoke): Docker Compose brings up Keycloak + PostgreSQL and imports realm
#
# TDD Phase: RED — static checks fail until files exist; runtime tests
# self-skip when the Docker stack is not running.
#
# Run:  bats tests/integration/ac1-docker-compose-smoke.bats
# Deps: docker, docker compose, curl, bats-core
# Env:  KC_PORT (default 8080), POSTGRES_PORT (default 5432)
# =============================================================================

# Load shared helpers: kc_running(), _admin_token(), KC_PORT, REALM
load "../test_helper"

DISCOVERY_URL="http://localhost:${KC_PORT}/realms/${REALM}/.well-known/openid-configuration"

# ---------------------------------------------------------------------------
# [P0] AC1-SMOKE-01 — compose.yaml exists and defines required services
# ---------------------------------------------------------------------------
@test "[P0][AC1-SMOKE-01] compose.yaml exists and defines postgres and keycloak services" {
  # RED: will fail until compose.yaml is created
  [ -f "compose.yaml" ]
  grep -q "postgres" compose.yaml
  grep -q "keycloak" compose.yaml
}

# ---------------------------------------------------------------------------
# [P0] AC1-SMOKE-02 — Keycloak responds on the main HTTP port (realm reachable)
# ---------------------------------------------------------------------------
@test "[P0][AC1-SMOKE-02] Keycloak responds on port ${KC_PORT} after 'docker compose up'" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"

  run curl -sf -o /dev/null -w "%{http_code}" \
    "http://localhost:${KC_PORT}/realms/${REALM}"
  [ "$status" -eq 0 ]
  [ "$output" = "200" ]
}

# ---------------------------------------------------------------------------
# [P0] AC1-SMOKE-03 — OIDC discovery endpoint returns required fields
# ---------------------------------------------------------------------------
@test "[P0][AC1-SMOKE-03] OIDC discovery endpoint responds for the envocc realm" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"

  run curl -sf "${DISCOVERY_URL}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"issuer"'
  echo "$output" | grep -q '"authorization_endpoint"'
  echo "$output" | grep -q '"token_endpoint"'
  echo "$output" | grep -q '"jwks_uri"'
}

# ---------------------------------------------------------------------------
# [P0] AC1-SMOKE-04 — Issuer matches expected envocc realm URL
# ---------------------------------------------------------------------------
@test "[P0][AC1-SMOKE-04] Issuer in discovery doc matches http://localhost:${KC_PORT}/realms/envocc" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"

  local expected_issuer="http://localhost:${KC_PORT}/realms/${REALM}"

  run curl -sf "${DISCOVERY_URL}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "\"issuer\":\"${expected_issuer}\""
}

# ---------------------------------------------------------------------------
# [P0] AC1-SMOKE-05 — envocc realm is importable via Admin REST API
# ---------------------------------------------------------------------------
@test "[P0][AC1-SMOKE-05] envocc realm is present in Keycloak after auto-import" {
  kc_running || skip "Keycloak not running — start with: docker compose up -d"

  local token
  token=$(_admin_token)
  [ -n "$token" ] || { echo "Failed to obtain admin token — is KEYCLOAK_ADMIN_PASSWORD exported?"; return 1; }

  run curl -sf -H "Authorization: Bearer ${token}" \
    "http://localhost:${KC_PORT}/admin/realms/${REALM}"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"realm":"envocc"'
}

# ---------------------------------------------------------------------------
# [P0] AC1-SMOKE-06 — PostgreSQL has keycloak_db and admin databases
# ---------------------------------------------------------------------------
@test "[P0][AC1-SMOKE-06] PostgreSQL has keycloak_db and admin databases after compose up" {
  command -v docker >/dev/null 2>&1 || skip "docker not installed"
  docker compose ps --services --status running 2>/dev/null | grep -q "^postgres$" \
    || skip "postgres service not running — start with: docker compose up -d"

  run docker compose exec -T postgres \
    psql -U "${POSTGRES_USER:-postgres}" -l -t
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "keycloak_db"
  echo "$output" | grep -q "admin"
}

# ---------------------------------------------------------------------------
# [P1] AC1-SMOKE-07 — keycloak/Dockerfile exists with pinned image (not :latest)
# ---------------------------------------------------------------------------
@test "[P1][AC1-SMOKE-07] keycloak/Dockerfile exists with pinned image and --import-realm CMD" {
  # RED: will fail until Dockerfile is created
  [ -f "keycloak/Dockerfile" ]

  # Must FROM a pinned quay.io/keycloak/keycloak image (exact tag, not 'latest')
  grep -qE "^FROM quay\.io/keycloak/keycloak:[0-9]" keycloak/Dockerfile

  # Must pin the immutable digest, not just the mutable tag (supply-chain integrity).
  grep -qE "^FROM quay\.io/keycloak/keycloak:[0-9.]+@sha256:[0-9a-f]{64}" keycloak/Dockerfile

  # Must COPY realm-export.json into the import path
  grep -q "realm-export.json" keycloak/Dockerfile

  # Must use start-dev --import-realm
  grep -q "start-dev" keycloak/Dockerfile
  grep -q "import-realm" keycloak/Dockerfile
}

# ---------------------------------------------------------------------------
# [P1] AC1-SMOKE-08 — compose.yaml uses ${VAR} for secrets, no hardcoded values
# ---------------------------------------------------------------------------
@test "[P1][AC1-SMOKE-08] compose.yaml uses env-var references, not hardcoded credentials" {
  # RED: will fail until compose.yaml is created
  [ -f "compose.yaml" ]

  # Every credential key's VALUE must be a ${VAR} reference (optionally with a
  # :-default), never a literal. We match credential keys and inspect only the
  # value to the right of the colon, so a same-line comment containing ${...}
  # cannot mask a hardcoded literal (the old `grep -v '${'` over-filtered).
  if grep -nE "^[[:space:]]*[A-Z_]*(PASSWORD|SECRET|ADMIN_PASS)[A-Z_]*[[:space:]]*:[[:space:]]*[^[:space:]#]" \
      compose.yaml \
      | grep -vE ":[[:space:]]*[\"']?\\\$\{" ; then
    echo "FAIL: compose.yaml contains a credential value that is not a \${VAR} reference"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# [P1] AC1-SMOKE-09 — postgres/init.sh creates keycloak_db and admin databases
# ---------------------------------------------------------------------------
@test "[P1][AC1-SMOKE-09] postgres/init.sh creates keycloak_db and admin databases" {
  # RED: will fail until postgres/init.sh is created
  [ -f "postgres/init.sh" ]
  grep -qi "CREATE DATABASE" postgres/init.sh
  grep -qi "keycloak_db" postgres/init.sh
  grep -qi "admin" postgres/init.sh
}

# ---------------------------------------------------------------------------
# [P1] AC1-SMOKE-10 — .env.example has all required placeholder keys
# ---------------------------------------------------------------------------
@test "[P1][AC1-SMOKE-10] .env.example contains all required env-var placeholders" {
  [ -f ".env.example" ]
  grep -q "KEYCLOAK_ADMIN=" .env.example
  grep -q "KEYCLOAK_ADMIN_PASSWORD=" .env.example
  grep -q "KC_DB_PASSWORD=" .env.example
  grep -q "POSTGRES_PASSWORD=" .env.example
}

# ---------------------------------------------------------------------------
# Teardown — only tear down if ATDD_TEARDOWN=true (avoids destroying dev stack)
# ---------------------------------------------------------------------------
teardown_file() {
  if [ "${ATDD_TEARDOWN:-false}" = "true" ]; then
    docker compose down -v 2>/dev/null || true
  fi
}
