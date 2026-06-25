#!/usr/bin/env bats
# tests/integration/stack-boot.bats
# ATDD tests — Story 1.1 AC1: Stack boots healthy
#
# AC1: Given a clean checkout with a populated .env,
#      when I run `docker compose up`,
#      then Keycloak starts healthy against PostgreSQL
#      and its admin console is reachable.
#
# Test scenarios covered:
#   TS-101a [P0] Fresh bring-up reaches healthy (both containers)
#   TS-101b [P0] Keycloak admin console returns an HTTP response
#   TS-101c [P1] Stack restarts without error (idempotent restart)
#   TS-101d [P1] Postgres is healthy before Keycloak starts (depends_on)
#
# NOTE: These tests require a running stack.
# Run manually: docker compose up --build -d, then: bats tests/integration/stack-boot.bats
# In CI (Story 1.5), these run as part of the integration test suite.

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Suite setup / teardown
# ---------------------------------------------------------------------------

setup_suite() {
  env_setup
}

teardown_suite() {
  # Leave the stack running for subsequent tests in the suite;
  # a dedicated cleanup job or manual `docker compose down -v` handles teardown.
  :
}

setup() {
  : # per-test setup (noop for most infra tests)
}

teardown() {
  : # per-test teardown
}

# ---------------------------------------------------------------------------
# TS-101a [P0] — Fresh bring-up: both services reach healthy
# ---------------------------------------------------------------------------
@test "[P0][TS-101a] docker compose up -- postgres reaches healthy within 60 s" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  # Given a populated .env
  assert [ -f "${PROJECT_ROOT}/.env" ]

  # When the stack is brought up
  run compose_up
  assert_success

  # Then postgres service reaches healthy
  run wait_for_healthy "postgres" 60
  assert_success
}

@test "[P0][TS-101a] docker compose up -- keycloak reaches healthy within 120 s" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  # Given postgres already healthy (from previous test or setup)
  # When the stack is up
  run compose_up
  assert_success

  # Then keycloak service reaches healthy
  run wait_for_healthy "keycloak" 120
  assert_success
}

# ---------------------------------------------------------------------------
# TS-101b [P0] — Keycloak admin console reachable
# ---------------------------------------------------------------------------
@test "[P0][TS-101b] Keycloak HTTP port 8080 returns an HTTP response" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  # Given the stack is healthy
  run wait_for_healthy "keycloak" 120
  assert_success

  # When we request the root URL
  run bash -c "curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://localhost:8080/"
  # Then we get a redirect (302) to the login or welcome page — not a connection refused
  assert_output --regexp "^[23][0-9][0-9]$"
}

@test "[P0][TS-101b] Keycloak admin console page returns HTTP response" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  run wait_for_healthy "keycloak" 120
  assert_success

  run bash -c "curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://localhost:8080/admin/"
  # Admin console returns 200 or 302 redirect to login
  assert_output --regexp "^[23][0-9][0-9]$"
}

# ---------------------------------------------------------------------------
# TS-101c [P1] — Idempotent restart (stack down + up without volume wipe)
# ---------------------------------------------------------------------------
@test "[P1][TS-101c] Stack restarts without error after docker compose stop + start" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  # Given the stack is already up and healthy
  run wait_for_healthy "keycloak" 120
  assert_success

  # When we stop and restart without wiping volumes
  run docker compose -f "${PROJECT_ROOT}/compose.yaml" stop
  assert_success

  run docker compose -f "${PROJECT_ROOT}/compose.yaml" start
  assert_success

  # Then keycloak recovers to healthy
  run wait_for_healthy "keycloak" 120
  assert_success
}

# ---------------------------------------------------------------------------
# TS-101d [P1] — depends_on: service_healthy ensures ordering
# ---------------------------------------------------------------------------
@test "[P1][TS-101d] Keycloak container waits for postgres healthy before starting" {
  skip "Integration: requires running stack — run manually after docker compose up --build"

  # When we inspect the compose config for depends_on
  run docker compose -f "${PROJECT_ROOT}/compose.yaml" config
  assert_success

  # Then the keycloak service config shows depends_on postgres with condition service_healthy
  assert_output --partial "condition: service_healthy"
}
