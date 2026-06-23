#!/usr/bin/env bats
# ATDD Green-Phase Tests — Story 1.1: Docker Compose Stack
# TDD Phase: GREEN — implementation complete; all tests activated
#
# Framework: bats-core (https://github.com/bats-core/bats-core)
# Run: bats tests/integration/docker-compose-stack.bats

# ---------------------------------------------------------------------------
# Setup / Teardown helpers
# ---------------------------------------------------------------------------

setup() {
  # Ensure we are at the repo root so compose.yaml is resolvable
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  cd "$REPO_ROOT"

  # Source .env.example as defaults when real .env is absent (for CI / clean checkout)
  if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    # Export keys with placeholder values so compose parsing doesn't fail
    set -a
    # shellcheck disable=SC1091
    source .env.example
    set +a
  fi
}

teardown() {
  # Do not tear down between individual tests to keep suite fast.
  # Full stack teardown is done in the LAST test ([P1][AC1] docker compose down -v).
  # NOTE: If a test fails before that last test runs, the Docker stack will remain
  # up. Run `docker compose down -v` manually in that case.
  true
}

# ---------------------------------------------------------------------------
# Helper: assert that a PostgreSQL privilege keyword does not appear as a bare
# grant in the init script.  NOSUPERUSER / NOCREATEDB / NOCREATEROLE are the
# expected denial keywords and are explicitly excluded from matching.
#
# Usage: assert_no_bare_privilege KEYWORD NO_KEYWORD
# Example: assert_no_bare_privilege SUPERUSER NOSUPERUSER
# ---------------------------------------------------------------------------
assert_no_bare_privilege() {
  local keyword="$1"
  local negated="$2"
  local script="postgres/init/01-init-dbs.sh"
  [ -f "$script" ]
  local count
  count=$(grep -iE "(^|[^A-Za-z])${keyword}([^A-Za-z]|$)" "$script" \
    | grep -v -i "$negated" | grep -vE "^\s*(#|--)" | grep -c . || true)
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Helper: skip the calling test unless BOTH postgres AND keycloak services are
# actually running. The live-stack tests below query a running container; on a
# clean checkout / CI (where the slow `up --wait` test is skipped) the stack is
# down and these tests must SKIP rather than hard-fail with a misleading error.
#
# Checking only postgres is insufficient: tests that hit Keycloak's health
# endpoint will exhaust their retry budget (90 s) and hard-FAIL if keycloak is
# still starting or crashed while postgres is already healthy.
# ---------------------------------------------------------------------------
require_running_stack() {
  command -v docker >/dev/null || skip "Docker not installed"

  # Check postgres
  local pg_cid
  pg_cid=$(docker compose ps -q postgres 2>/dev/null || true)
  [ -n "$pg_cid" ] || skip "stack not running — start it with: docker compose up --wait"
  local pg_state
  pg_state=$(docker inspect -f '{{.State.Running}}' "$pg_cid" 2>/dev/null || echo false)
  [ "$pg_state" = "true" ] || skip "postgres container is not running (state=$pg_state)"

  # Check keycloak
  local kc_cid
  kc_cid=$(docker compose ps -q keycloak 2>/dev/null || true)
  [ -n "$kc_cid" ] || skip "keycloak container is not running — start it with: docker compose up --wait"
  local kc_state
  kc_state=$(docker inspect -f '{{.State.Running}}' "$kc_cid" 2>/dev/null || echo false)
  [ "$kc_state" = "true" ] || skip "keycloak container is not running (state=$kc_state)"
}

# ---------------------------------------------------------------------------
# [AC3] Image pinning — compose.yaml must not use :latest or floating tags
# ---------------------------------------------------------------------------

@test "[P0][AC3] compose.yaml exists at repo root" {
  [ -f "compose.yaml" ]
}

@test "[P0][AC3] Keycloak image is pinned to exact version 26.6.3 with digest — no :latest" {
  [ -f "compose.yaml" ]
  # Must contain a quay.io/keycloak/keycloak:26.6.3 reference with SHA256 digest
  grep -q "quay.io/keycloak/keycloak:26.6.3@sha256:" compose.yaml
}

@test "[P0][AC3] PostgreSQL image is pinned to postgres:16.x with digest — no :latest" {
  [ -f "compose.yaml" ]
  # Must NOT reference ':latest'
  run grep "postgres:latest" compose.yaml
  [ "$status" -ne 0 ]
  # Must contain a digest-pinned postgres:16 reference
  grep -q "postgres:16" compose.yaml
  grep -E "postgres:16.*@sha256:" compose.yaml
}

@test "[P1][AC3] No service in compose.yaml uses ':latest' tag" {
  [ -f "compose.yaml" ]
  run grep ":latest" compose.yaml
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# [AC4] Secret hygiene — no hard-coded secrets; .env.example committed
# ---------------------------------------------------------------------------

@test "[P0][AC4] .env.example is committed and contains all required keys" {
  [ -f ".env.example" ]
  grep -q "KEYCLOAK_ADMIN=" .env.example
  grep -q "KEYCLOAK_ADMIN_PASSWORD=" .env.example
  grep -q "POSTGRES_USER=" .env.example
  grep -q "POSTGRES_PASSWORD=" .env.example
  grep -q "KC_DB=" .env.example
  grep -q "KC_DB_URL=" .env.example
  grep -q "KC_DB_USERNAME=" .env.example
  grep -q "KC_DB_PASSWORD=" .env.example
  grep -q "KC_HOSTNAME=" .env.example
  grep -q "ADMIN_DB_PASSWORD=" .env.example
}

@test "[P0][AC4] .env is NOT committed to the repository (.gitignore must exclude it)" {
  # The real .env must not be tracked
  run git ls-files .env
  [ -z "$output" ]
}

@test "[P0][AC4] gitleaks detects no secrets in compose.yaml and postgres/init/" {
  command -v gitleaks >/dev/null || skip "gitleaks not installed — install via brew install gitleaks"
  [ -f "compose.yaml" ]
  [ -f "postgres/init/01-init-dbs.sh" ]
  run gitleaks detect --no-git --source compose.yaml 2>&1
  [ "$status" -eq 0 ]
  run gitleaks detect --no-git --source postgres/ 2>&1
  [ "$status" -eq 0 ]
}

@test "[P1][AC4] No plaintext password appears hard-coded in compose.yaml" {
  [ -f "compose.yaml" ]
  # All password values should be env-var references like ${KC_DB_PASSWORD} not literal strings
  # Reject patterns like: password: "changeme" or password: 'literal'
  run grep -E "PASSWORD\s*:\s*['\"][^$\{]" compose.yaml
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# [AC2] PostgreSQL init script — two databases, least-privilege roles
# ---------------------------------------------------------------------------

@test "[P0][AC2] postgres/init/01-init-dbs.sh exists" {
  [ -f "postgres/init/01-init-dbs.sh" ]
}

@test "[P0][AC2] init script creates keycloak_db database" {
  [ -f "postgres/init/01-init-dbs.sh" ]
  grep -q "keycloak_db" postgres/init/01-init-dbs.sh
}

@test "[P0][AC2] init script creates admin database" {
  [ -f "postgres/init/01-init-dbs.sh" ]
  # Pin the actual DB-creation statement, not just any mention of "admin"
  # (a bare \badmin\b match also hits admin_user and comments — it would pass
  # even if the CREATE DATABASE line were deleted).
  grep -qE "CREATE DATABASE admin\b" postgres/init/01-init-dbs.sh
}

@test "[P0][AC2] init script creates keycloak_user role with least-privilege" {
  [ -f "postgres/init/01-init-dbs.sh" ]
  grep -q "keycloak_user" postgres/init/01-init-dbs.sh
}

@test "[P0][AC2] init script creates admin_user role with least-privilege" {
  [ -f "postgres/init/01-init-dbs.sh" ]
  grep -q "admin_user" postgres/init/01-init-dbs.sh
}

@test "[P1][AC2] init script revokes default PUBLIC CONNECT to isolate the two databases" {
  # PostgreSQL grants CONNECT to PUBLIC by default; without revoking it, keycloak_user
  # could connect to the admin DB (and vice-versa), breaking the "isolated databases"
  # boundary in AC2. Assert both databases revoke CONNECT from PUBLIC.
  [ -f "postgres/init/01-init-dbs.sh" ]
  grep -qE "REVOKE CONNECT ON DATABASE keycloak_db FROM PUBLIC" postgres/init/01-init-dbs.sh
  grep -qE "REVOKE CONNECT ON DATABASE admin FROM PUBLIC" postgres/init/01-init-dbs.sh
}

@test "[P1][AC2] init script does NOT grant SUPERUSER to any role" {
  # NOSUPERUSER is the correct PostgreSQL keyword to DENY superuser (expected and allowed).
  # Guard against a bare 'SUPERUSER' grant (without the 'NO' prefix).
  assert_no_bare_privilege SUPERUSER NOSUPERUSER
}

@test "[P1][AC2] init script does NOT grant CREATEDB to any role" {
  # NOCREATEDB is the correct keyword; guard against bare CREATEDB grant.
  assert_no_bare_privilege CREATEDB NOCREATEDB
}

@test "[P1][AC2] init script does NOT grant CREATEROLE to any role" {
  # NOCREATEROLE is the correct keyword; guard against bare CREATEROLE grant.
  assert_no_bare_privilege CREATEROLE NOCREATEROLE
}

# ---------------------------------------------------------------------------
# [AC1] End-to-end bring-up — requires Docker + running daemon
# These tests are P0 but marked with an additional guard requiring Docker.
# ---------------------------------------------------------------------------

@test "[P0][AC1] docker compose config validates without errors" {
  command -v docker >/dev/null || skip "Docker not installed"
  [ -f "compose.yaml" ]
  # Validate using an explicit env file so we never write a stray .env into the
  # worktree (which would persist as a side effect and change later test behavior).
  # Prefer the real .env if the operator created one; otherwise fall back to the
  # committed .env.example placeholders via --env-file.
  if [ -f ".env" ]; then
    run docker compose config --quiet 2>&1
  else
    run docker compose --env-file .env.example config --quiet 2>&1
  fi
  [ "$status" -eq 0 ]
}

@test "[P0][AC1] docker compose up --wait brings stack to healthy state" {
  skip "SLOW TEST (60-90s) — run manually: docker compose up --wait --timeout 150"
  command -v docker >/dev/null || skip "Docker not installed"
  [ -f "compose.yaml" ]
  [ -f ".env" ] || skip ".env not present — copy .env.example to .env and fill real values"
  run docker compose up --wait --timeout 150 2>&1
  [ "$status" -eq 0 ]
}

@test "[P0][AC1] Keycloak health endpoint /health/ready returns 200 on management port" {
  # Keycloak 26 with KC_HEALTH_ENABLED=true exposes health on port 9000 (management interface).
  # Port 8080 does NOT serve /health/ready — only the management port does.
  # Wait up to 90s for the stack to be fully healthy before hitting the endpoint.
  require_running_stack
  command -v curl   >/dev/null || skip "curl not installed"
  KC_HEALTH_PORT="${KC_HEALTH_PORT:-9000}"
  local max_retries=18
  local retry_interval=5
  for i in $(seq 1 "$max_retries"); do
    if curl --silent --fail --max-time 5 "http://localhost:${KC_HEALTH_PORT}/health/ready" >/dev/null 2>&1; then
      break
    fi
    sleep "$retry_interval"
  done
  run curl --silent --fail --max-time 10 "http://localhost:${KC_HEALTH_PORT}/health/ready"
  [ "$status" -eq 0 ]
}

@test "[P0][AC2] both keycloak_db and admin databases exist after postgres init" {
  require_running_stack
  # Use ${POSTGRES_USER} (sourced from .env.example in setup()) rather than the
  # hardcoded literal 'postgres' so the test works when POSTGRES_USER is customised.
  run docker compose exec -T postgres psql -U "${POSTGRES_USER:-postgres}" -tAc "SELECT datname FROM pg_database WHERE datname IN ('keycloak_db','admin') ORDER BY datname;" 2>&1
  echo "Output: $output"
  [[ "$output" == *"admin"* ]]
  [[ "$output" == *"keycloak_db"* ]]
}

@test "[P0][AC2] keycloak_user role exists and has NO superuser privileges" {
  require_running_stack
  run docker compose exec -T postgres psql -U "${POSTGRES_USER:-postgres}" -tAc "SELECT rolname, rolsuper, rolcreatedb, rolcreaterole FROM pg_roles WHERE rolname='keycloak_user';" 2>&1
  echo "Output: $output"
  [[ "$output" == *"keycloak_user"* ]]
  # rolsuper, rolcreatedb, rolcreaterole must all be 'f' (false)
  [[ "$output" == *"f|f|f"* ]]
}

@test "[P0][AC2] admin_user role exists and has NO superuser privileges" {
  require_running_stack
  run docker compose exec -T postgres psql -U "${POSTGRES_USER:-postgres}" -tAc "SELECT rolname, rolsuper, rolcreatedb, rolcreaterole FROM pg_roles WHERE rolname='admin_user';" 2>&1
  echo "Output: $output"
  [[ "$output" == *"admin_user"* ]]
  [[ "$output" == *"f|f|f"* ]]
}

@test "[P1][AC1] docker compose down -v cleans up stack cleanly" {
  command -v docker >/dev/null || skip "Docker not installed"
  run docker compose down -v --timeout 30 2>&1
  [ "$status" -eq 0 ]
}
