#!/usr/bin/env bats
# tests/unit/version-pinning.bats
# ATDD RED-PHASE scaffolds — Story 1.1 AC3: Exact version pinning
#
# TDD RED PHASE: All tests are marked `skip` until compose.yaml and
# keycloak/Dockerfile exist with pinned-by-digest images.
# Remove `skip` for the current task to activate.
#
# AC3: Given the compose file, when images are resolved,
#      then Keycloak (26.6.x) and PostgreSQL are pinned by exact version
#      AND digest (@sha256:…) — never :latest, never a floating tag.
#
# Test scenarios covered:
#   TS-103a [P1] compose.yaml contains no ':latest' references
#   TS-103b [P1] compose.yaml contains @sha256: digest for postgres image
#   TS-103c [P1] keycloak/Dockerfile contains @sha256: digest for base image
#   TS-103d [P1] Keycloak image tag is exactly 26.6.x (not a different major/minor)
#   TS-103e [P2] Runtime docker inspect confirms pulled image digest matches compose pin
#   TS-103f [P2] postgres/init/01-init-databases.sh contains no hard-coded version strings
#                that could drift independently

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# TS-103a [P1] — No ':latest' in compose.yaml or Dockerfile
# ---------------------------------------------------------------------------
@test "[P1][TS-103a] compose.yaml contains no ':latest' image tag" {
  skip "RED PHASE: compose.yaml not yet created (Story 1.1 Task 4)"

  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  run grep -n ":latest" "${PROJECT_ROOT}/compose.yaml"
  # grep returns exit 1 when no match — that is what we want
  assert_failure
}

@test "[P1][TS-103a] keycloak/Dockerfile contains no ':latest' image tag" {
  skip "RED PHASE: keycloak/Dockerfile not yet created (Story 1.1 Task 3)"

  assert [ -f "${PROJECT_ROOT}/keycloak/Dockerfile" ]

  run grep -n ":latest" "${PROJECT_ROOT}/keycloak/Dockerfile"
  assert_failure
}

# ---------------------------------------------------------------------------
# TS-103b [P1] — postgres image pinned by @sha256: digest in compose.yaml
# ---------------------------------------------------------------------------
@test "[P1][TS-103b] compose.yaml postgres image includes @sha256: digest" {
  skip "RED PHASE: compose.yaml not yet created (Story 1.1 Task 4)"

  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  # The postgres image line must contain @sha256: followed by a hex string
  run grep -E "postgres.*@sha256:[a-f0-9]{64}" "${PROJECT_ROOT}/compose.yaml"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-103c [P1] — Keycloak Dockerfile FROM pinned by @sha256: digest
# ---------------------------------------------------------------------------
@test "[P1][TS-103c] keycloak/Dockerfile FROM line includes @sha256: digest" {
  skip "RED PHASE: keycloak/Dockerfile not yet created (Story 1.1 Task 3)"

  assert [ -f "${PROJECT_ROOT}/keycloak/Dockerfile" ]

  # FROM quay.io/keycloak/keycloak:26.6.3@sha256:<64-hex>
  run grep -E "FROM.*keycloak.*@sha256:[a-f0-9]{64}" "${PROJECT_ROOT}/keycloak/Dockerfile"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-103d [P1] — Keycloak version tag is exactly 26.6.x
# ---------------------------------------------------------------------------
@test "[P1][TS-103d] keycloak/Dockerfile FROM tag matches 26.6.x version pattern" {
  skip "RED PHASE: keycloak/Dockerfile not yet created (Story 1.1 Task 3)"

  assert [ -f "${PROJECT_ROOT}/keycloak/Dockerfile" ]

  # Must be 26.6.N — not 25.x, 27.x, or a floating '26' tag
  run grep -E "FROM.*keycloak:26\.6\.[0-9]+" "${PROJECT_ROOT}/keycloak/Dockerfile"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-103e [P2] — Runtime: pulled image digest matches compose pin
#   (Requires stack to be running; skipped in offline/unit-only runs)
# ---------------------------------------------------------------------------
@test "[P2][TS-103e] Runtime postgres image digest matches @sha256: pin in compose.yaml" {
  skip "RED PHASE: compose.yaml not yet created AND stack not yet running (Story 1.1 Task 5)"

  # Extract expected digest from compose.yaml
  local expected_digest
  expected_digest=$(grep -oE "sha256:[a-f0-9]{64}" "${PROJECT_ROOT}/compose.yaml" \
    | head -1)

  [ -n "${expected_digest}" ] || fail "No sha256 digest found in compose.yaml for postgres"

  # Get actual image digest from running container
  local actual_digest
  actual_digest=$(docker compose -f "${PROJECT_ROOT}/compose.yaml" \
    exec -T postgres \
    bash -c "cat /etc/os-release" 2>/dev/null || true)

  # Compare via docker inspect on the image ID
  local image_id
  image_id=$(docker compose -f "${PROJECT_ROOT}/compose.yaml" images --format json postgres 2>/dev/null \
    | grep -o '"ID":"[^"]*"' | head -1 | sed 's/"ID":"//;s/"//')

  run docker inspect --format '{{index .RepoDigests 0}}' "${image_id}"
  assert_output --partial "${expected_digest}"
}

# ---------------------------------------------------------------------------
# TS-103f [P2] — postgres/init script has no floating version refs
# ---------------------------------------------------------------------------
@test "[P2][TS-103f] postgres/init/01-init-databases.sh contains no floating version strings" {
  skip "RED PHASE: postgres/init/01-init-databases.sh not yet created (Story 1.1 Task 2)"

  assert [ -f "${PROJECT_ROOT}/postgres/init/01-init-databases.sh" ]

  # The init script should reference no external image tags or version pins
  # (it is a pure SQL/shell script; version concerns live in Dockerfile/compose.yaml)
  run grep -E ":[0-9]+\.[0-9]+" "${PROJECT_ROOT}/postgres/init/01-init-databases.sh"
  assert_failure
}
