#!/usr/bin/env bats
# tests/integration/db-isolation.bats
# ATDD RED-PHASE scaffolds — Story 1.1 AC2: Two least-privilege databases
#
# TDD RED PHASE: All tests are marked `skip` until compose.yaml and
# postgres/init/01-init-databases.sh exist.
# Remove `skip` for the current task to activate.
#
# AC2: Given the Postgres container initialises,
#      when bring-up completes,
#      then two separate databases exist — `keycloak` and `admin` —
#      each owned by a distinct, least-privilege role.
#      The `admin` DB role MUST NOT have access to the `keycloak` DB
#      and vice-versa.
#
# Test scenarios covered:
#   TS-102a [P0] Both databases exist in pg_catalog.pg_database
#   TS-102b [P0] Two distinct roles exist — `keycloak` and `adminapp`
#   TS-102c [P0] keycloak role cannot connect to admin DB (access denied)
#   TS-102d [P0] adminapp role cannot connect to keycloak DB (access denied)
#   TS-102e [P0] keycloak role connects to keycloak DB successfully
#   TS-102f [P0] adminapp role connects to admin DB successfully
#   TS-102g [P1] Special chars in KC_DB_PASSWORD do not break connection
#            (validates SQL quoting fix — passwords with ', $, \)

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# psql_as <role> <dbname> <sql>
# Runs SQL inside the running postgres container as the given role.
psql_as() {
  local role="${1}"
  local dbname="${2}"
  local sql="${3}"

  # Source the .env to pick up credentials
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/.env"

  local password_var
  case "${role}" in
    keycloak)  password_var="${KC_DB_PASSWORD}" ;;
    adminapp)  password_var="${ADMINAPP_DB_PASSWORD}" ;;
    postgres)  password_var="${POSTGRES_PASSWORD}" ;;
    *)         password_var="" ;;
  esac

  docker compose -f "${PROJECT_ROOT}/compose.yaml" exec -T postgres \
    env PGPASSWORD="${password_var}" \
    psql -U "${role}" -d "${dbname}" -c "${sql}" -t -A 2>&1
}

setup_suite() {
  env_setup
}

# ---------------------------------------------------------------------------
# TS-102a [P0] — Both databases exist
# ---------------------------------------------------------------------------
@test "[P0][TS-102a] Database 'keycloak' exists in pg_catalog.pg_database" {
  skip "RED PHASE: postgres/init/01-init-databases.sh not yet created (Story 1.1 Task 2)"

  run wait_for_healthy "postgres" 60
  assert_success

  run psql_as "postgres" "postgres" \
    "SELECT datname FROM pg_catalog.pg_database WHERE datname = 'keycloak';"
  assert_success
  assert_output --partial "keycloak"
}

@test "[P0][TS-102a] Database 'admin' exists in pg_catalog.pg_database" {
  skip "RED PHASE: postgres/init/01-init-databases.sh not yet created (Story 1.1 Task 2)"

  run wait_for_healthy "postgres" 60
  assert_success

  run psql_as "postgres" "postgres" \
    "SELECT datname FROM pg_catalog.pg_database WHERE datname = 'admin';"
  assert_success
  assert_output --partial "admin"
}

# ---------------------------------------------------------------------------
# TS-102b [P0] — Two distinct roles exist
# ---------------------------------------------------------------------------
@test "[P0][TS-102b] Role 'keycloak' exists in pg_catalog.pg_roles" {
  skip "RED PHASE: postgres/init/01-init-databases.sh not yet created (Story 1.1 Task 2)"

  run psql_as "postgres" "postgres" \
    "SELECT rolname FROM pg_catalog.pg_roles WHERE rolname = 'keycloak';"
  assert_success
  assert_output --partial "keycloak"
}

@test "[P0][TS-102b] Role 'adminapp' exists in pg_catalog.pg_roles" {
  skip "RED PHASE: postgres/init/01-init-databases.sh not yet created (Story 1.1 Task 2)"

  run psql_as "postgres" "postgres" \
    "SELECT rolname FROM pg_catalog.pg_roles WHERE rolname = 'adminapp';"
  assert_success
  assert_output --partial "adminapp"
}

@test "[P0][TS-102b] Roles 'keycloak' and 'adminapp' are distinct (not the same role)" {
  skip "RED PHASE: postgres/init/01-init-databases.sh not yet created (Story 1.1 Task 2)"

  run psql_as "postgres" "postgres" \
    "SELECT COUNT(DISTINCT rolname) FROM pg_catalog.pg_roles WHERE rolname IN ('keycloak','adminapp');"
  assert_success
  assert_output --partial "2"
}

# ---------------------------------------------------------------------------
# TS-102c [P0] — keycloak role CANNOT connect to admin DB (isolation)
# ---------------------------------------------------------------------------
@test "[P0][TS-102c] keycloak role is denied connection to 'admin' database" {
  skip "RED PHASE: postgres/init/01-init-databases.sh not yet created (Story 1.1 Task 2)"

  run psql_as "keycloak" "admin" "SELECT 1;"
  # Should fail — FATAL: permission denied for database admin
  assert_failure
  assert_output --partial "permission denied"
}

# ---------------------------------------------------------------------------
# TS-102d [P0] — adminapp role CANNOT connect to keycloak DB (isolation)
# ---------------------------------------------------------------------------
@test "[P0][TS-102d] adminapp role is denied connection to 'keycloak' database" {
  skip "RED PHASE: postgres/init/01-init-databases.sh not yet created (Story 1.1 Task 2)"

  run psql_as "adminapp" "keycloak" "SELECT 1;"
  # Should fail — FATAL: permission denied for database keycloak
  assert_failure
  assert_output --partial "permission denied"
}

# ---------------------------------------------------------------------------
# TS-102e [P0] — keycloak role CAN connect to its own DB
# ---------------------------------------------------------------------------
@test "[P0][TS-102e] keycloak role connects successfully to 'keycloak' database" {
  skip "RED PHASE: postgres/init/01-init-databases.sh not yet created (Story 1.1 Task 2)"

  run psql_as "keycloak" "keycloak" "SELECT 1;"
  assert_success
  assert_output --partial "1"
}

# ---------------------------------------------------------------------------
# TS-102f [P0] — adminapp role CAN connect to its own DB
# ---------------------------------------------------------------------------
@test "[P0][TS-102f] adminapp role connects successfully to 'admin' database" {
  skip "RED PHASE: postgres/init/01-init-databases.sh not yet created (Story 1.1 Task 2)"

  run psql_as "adminapp" "admin" "SELECT 1;"
  assert_success
  assert_output --partial "1"
}

# ---------------------------------------------------------------------------
# TS-102g [P1] — Special characters in password do not break KC connection
# This validates the SQL quoting fix (format('%L', :'var') instead of
# raw shell interpolation) from Story 1.1 dev notes guardrail #2.
# ---------------------------------------------------------------------------
@test "[P1][TS-102g] KC_DB_PASSWORD with special chars (' \$ \\) still allows keycloak DB connection" {
  skip "RED PHASE: postgres/init/01-init-databases.sh not yet created (Story 1.1 Task 2); requires manual .env override with special-char password"

  # This test requires a .env where KC_DB_PASSWORD contains special chars.
  # In CI, set: KC_DB_PASSWORD="p@ss'word\$with\\special"
  # Then bring up a fresh stack from scratch (docker compose down -v first).

  # Verify the keycloak service is healthy even with special-char password
  run wait_for_healthy "keycloak" 120
  assert_success

  # And keycloak role can still connect to its DB
  run psql_as "keycloak" "keycloak" "SELECT 1;"
  assert_success
  assert_output --partial "1"
}
