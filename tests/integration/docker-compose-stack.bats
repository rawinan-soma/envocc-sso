#!/usr/bin/env bats
# ATDD Red-Phase Test Scaffolds — Story 1.1: Docker Compose Stack
# TDD Phase: RED — all tests use skip() semantics via bats_skip
# These tests assert EXPECTED behavior and will FAIL until the feature is implemented.
#
# Framework: bats-core (https://github.com/bats-core/bats-core)
# Run: bats tests/integration/docker-compose-stack.bats
#
# ACTIVATION INSTRUCTIONS (per-task TDD activation):
#   Remove the `skip "..."` line from a test when you start working on its task.
#   Verify it FAILS first (red), then implement until it PASSES (green).

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
  # Full stack teardown is done in the LAST test (AC1 validation).
  true
}

# ---------------------------------------------------------------------------
# [AC3] Image pinning — compose.yaml must not use :latest or floating tags
# ---------------------------------------------------------------------------

@test "[P0][AC3] compose.yaml exists at repo root" {
  skip "RED: compose.yaml not yet created (Task 1)"
  [ -f "compose.yaml" ]
}

@test "[P0][AC3] Keycloak image is pinned to exact version 26.6.3 with digest — no :latest" {
  skip "RED: compose.yaml not yet created (Task 1)"
  [ -f "compose.yaml" ]
  # Must contain a quay.io/keycloak/keycloak:26.6.3 reference with SHA256 digest
  grep -q "quay.io/keycloak/keycloak:26.6.3@sha256:" compose.yaml
}

@test "[P0][AC3] PostgreSQL image is pinned to postgres:16.x with digest — no :latest" {
  skip "RED: compose.yaml not yet created (Task 1)"
  [ -f "compose.yaml" ]
  # Must NOT reference ':latest'
  run grep "postgres:latest" compose.yaml
  [ "$status" -ne 0 ]
  # Must contain a digest-pinned postgres:16 reference
  grep -q "postgres:16" compose.yaml
  grep -E "postgres:16.*@sha256:" compose.yaml
}

@test "[P1][AC3] No service in compose.yaml uses ':latest' tag" {
  skip "RED: compose.yaml not yet created (Task 1)"
  [ -f "compose.yaml" ]
  run grep ":latest" compose.yaml
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# [AC4] Secret hygiene — no hard-coded secrets; .env.example committed
# ---------------------------------------------------------------------------

@test "[P0][AC4] .env.example is committed and contains all required keys" {
  skip "RED: .env.example not yet updated (Task 3)"
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
  skip "RED: .gitignore guard not yet verified (Task 3)"
  # The real .env must not be tracked
  run git ls-files .env
  [ -z "$output" ]
}

@test "[P0][AC4] gitleaks detects no secrets in compose.yaml and postgres/init/" {
  skip "RED: compose.yaml and init script not yet created (Tasks 1 & 2)"
  command -v gitleaks >/dev/null || skip "gitleaks not installed — install via brew install gitleaks"
  [ -f "compose.yaml" ]
  [ -f "postgres/init/01-init-dbs.sh" ]
  run gitleaks detect --no-git --source . --include-path compose.yaml 2>&1
  [ "$status" -eq 0 ]
  run gitleaks detect --no-git --source . --include-path postgres/init/01-init-dbs.sh 2>&1
  [ "$status" -eq 0 ]
}

@test "[P1][AC4] No plaintext password appears hard-coded in compose.yaml" {
  skip "RED: compose.yaml not yet created (Task 1)"
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
  skip "RED: init script not yet created (Task 2)"
  [ -f "postgres/init/01-init-dbs.sh" ]
}

@test "[P0][AC2] init script creates keycloak_db database" {
  skip "RED: init script not yet created (Task 2)"
  [ -f "postgres/init/01-init-dbs.sh" ]
  grep -q "keycloak_db" postgres/init/01-init-dbs.sh
}

@test "[P0][AC2] init script creates admin database" {
  skip "RED: init script not yet created (Task 2)"
  [ -f "postgres/init/01-init-dbs.sh" ]
  grep -qE "\badmin\b" postgres/init/01-init-dbs.sh
}

@test "[P0][AC2] init script creates keycloak_user role with least-privilege" {
  skip "RED: init script not yet created (Task 2)"
  [ -f "postgres/init/01-init-dbs.sh" ]
  grep -q "keycloak_user" postgres/init/01-init-dbs.sh
}

@test "[P0][AC2] init script creates admin_user role with least-privilege" {
  skip "RED: init script not yet created (Task 2)"
  [ -f "postgres/init/01-init-dbs.sh" ]
  grep -q "admin_user" postgres/init/01-init-dbs.sh
}

@test "[P1][AC2] init script does NOT grant SUPERUSER to any role" {
  skip "RED: init script not yet created (Task 2)"
  [ -f "postgres/init/01-init-dbs.sh" ]
  # SUPERUSER should never appear in any CREATE ROLE statement
  run grep -i "SUPERUSER" postgres/init/01-init-dbs.sh
  [ "$status" -ne 0 ]
}

@test "[P1][AC2] init script does NOT grant CREATEDB to any role" {
  skip "RED: init script not yet created (Task 2)"
  [ -f "postgres/init/01-init-dbs.sh" ]
  run grep -i "CREATEDB" postgres/init/01-init-dbs.sh
  [ "$status" -ne 0 ]
}

@test "[P1][AC2] init script does NOT grant CREATEROLE to any role" {
  skip "RED: init script not yet created (Task 2)"
  [ -f "postgres/init/01-init-dbs.sh" ]
  run grep -i "CREATEROLE" postgres/init/01-init-dbs.sh
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# [AC1] End-to-end bring-up — requires Docker + running daemon
# These tests are P0 but marked with an additional guard requiring Docker.
# ---------------------------------------------------------------------------

@test "[P0][AC1] docker compose config validates without errors" {
  skip "RED: compose.yaml not yet created (Task 1)"
  command -v docker >/dev/null || skip "Docker not installed"
  [ -f "compose.yaml" ]
  [ -f ".env" ] || cp .env.example .env  # use placeholder .env for config validation only
  run docker compose config --quiet 2>&1
  [ "$status" -eq 0 ]
}

@test "[P0][AC1] docker compose up --wait brings stack to healthy state" {
  skip "RED: compose.yaml not yet created (Tasks 1-3) — SLOW TEST (60-90s), run manually"
  command -v docker >/dev/null || skip "Docker not installed"
  [ -f "compose.yaml" ]
  [ -f ".env" ] || skip ".env not present — copy .env.example to .env and fill real values"
  run docker compose up --wait --timeout 120 2>&1
  [ "$status" -eq 0 ]
}

@test "[P0][AC1] Keycloak health endpoint /health/ready returns HTTP 200 after stack up" {
  skip "RED: Stack not yet implemented (Tasks 1-3) — requires running stack"
  KC_HOSTNAME="${KC_HOSTNAME:-localhost}"
  run curl --silent --fail --max-time 10 "http://${KC_HOSTNAME}:8080/health/ready"
  [ "$status" -eq 0 ]
}

@test "[P0][AC2] both keycloak_db and admin databases exist after postgres init" {
  skip "RED: Stack not yet implemented (Tasks 1-3) — requires running stack"
  command -v docker >/dev/null || skip "Docker not installed"
  run docker compose exec -T postgres psql -U postgres -tAc "SELECT datname FROM pg_database WHERE datname IN ('keycloak_db','admin') ORDER BY datname;" 2>&1
  echo "Output: $output"
  [[ "$output" == *"admin"* ]]
  [[ "$output" == *"keycloak_db"* ]]
}

@test "[P0][AC2] keycloak_user role exists and has NO superuser privileges" {
  skip "RED: Stack not yet implemented (Tasks 1-3) — requires running stack"
  command -v docker >/dev/null || skip "Docker not installed"
  run docker compose exec -T postgres psql -U postgres -tAc "SELECT rolname, rolsuper, rolcreatedb, rolcreaterole FROM pg_roles WHERE rolname='keycloak_user';" 2>&1
  echo "Output: $output"
  [[ "$output" == *"keycloak_user"* ]]
  # rolsuper, rolcreatedb, rolcreaterole must all be 'f' (false)
  [[ "$output" == *"f|f|f"* ]]
}

@test "[P0][AC2] admin_user role exists and has NO superuser privileges" {
  skip "RED: Stack not yet implemented (Tasks 1-3) — requires running stack"
  command -v docker >/dev/null || skip "Docker not installed"
  run docker compose exec -T postgres psql -U postgres -tAc "SELECT rolname, rolsuper, rolcreatedb, rolcreaterole FROM pg_roles WHERE rolname='admin_user';" 2>&1
  echo "Output: $output"
  [[ "$output" == *"admin_user"* ]]
  [[ "$output" == *"f|f|f"* ]]
}

@test "[P1][AC1] docker compose down -v cleans up stack cleanly" {
  skip "RED: Stack not yet implemented (Tasks 1-3) — run after AC1 stack-up test"
  command -v docker >/dev/null || skip "Docker not installed"
  run docker compose down -v --timeout 30 2>&1
  [ "$status" -eq 0 ]
}
