#!/usr/bin/env bats
# tests/unit/version-pinning.bats
# ATDD tests — Story 1.1 AC3: Exact version pinning
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
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  run grep -n ":latest" "${PROJECT_ROOT}/compose.yaml"
  # grep returns exit 1 when no match — that is what we want
  assert_failure
}

@test "[P1][TS-103a] keycloak/Dockerfile contains no ':latest' image tag" {
  assert [ -f "${PROJECT_ROOT}/keycloak/Dockerfile" ]

  run grep -n ":latest" "${PROJECT_ROOT}/keycloak/Dockerfile"
  assert_failure
}

# ---------------------------------------------------------------------------
# TS-103b [P1] — postgres image pinned by @sha256: digest in compose.yaml
# ---------------------------------------------------------------------------
@test "[P1][TS-103b] compose.yaml postgres image includes @sha256: digest" {
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  # The postgres image line must contain @sha256: followed by a hex string
  run grep -E "postgres.*@sha256:[a-f0-9]{64}" "${PROJECT_ROOT}/compose.yaml"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-103c [P1] — Keycloak Dockerfile FROM pinned by @sha256: digest
# ---------------------------------------------------------------------------
@test "[P1][TS-103c] keycloak/Dockerfile FROM line includes @sha256: digest" {
  assert [ -f "${PROJECT_ROOT}/keycloak/Dockerfile" ]

  # FROM quay.io/keycloak/keycloak:26.6.3@sha256:<64-hex>
  run grep -E "FROM.*keycloak.*@sha256:[a-f0-9]{64}" "${PROJECT_ROOT}/keycloak/Dockerfile"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-103d [P1] — Keycloak version tag is exactly 26.6.x
# ---------------------------------------------------------------------------
@test "[P1][TS-103d] keycloak/Dockerfile FROM tag matches 26.6.x version pattern" {
  assert [ -f "${PROJECT_ROOT}/keycloak/Dockerfile" ]

  # Must be 26.6.N — not 25.x, 27.x, or a floating '26' tag
  run grep -E "FROM.*keycloak:26\.6\.[0-9]+" "${PROJECT_ROOT}/keycloak/Dockerfile"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-103d2 [P1] — postgres image version tag is exact (not a floating tag)
# ---------------------------------------------------------------------------
@test "[P1][TS-103d2] compose.yaml postgres image tag is an exact version (not floating)" {
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  # Must contain an explicit version tag like postgres:17.5 (not just postgres: or postgres:latest)
  # Pattern: postgres:<MAJOR>.<MINOR> (optionally .<PATCH>) followed by @sha256
  run grep -E "postgres:[0-9]+\.[0-9]+(\.[0-9]+)?@sha256:" "${PROJECT_ROOT}/compose.yaml"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-103d3 [P1] — nginx image version tag includes a version number (not floating)
#
# Added in Story 1.3 review: TS-137a only rejects ':latest'; a floating tag like
# 'nginx:alpine' (no version) or 'nginx:1.28-alpine' (minor only, no patch) would
# pass TS-137a but still drift across patch updates if the digest is not pinned.
# This test ensures the nginx image tag contains at least a major.minor version
# number — combined with TS-137b (@sha256: digest), this gives full pinning coverage.
# ---------------------------------------------------------------------------
@test "[P1][TS-103d3] compose.yaml nginx image tag includes a version number (not bare :alpine or :latest)" {
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  # Must match: nginx:<MAJOR>.<MINOR>(optional: -<VARIANT>)@sha256:
  # e.g. nginx:1.28-alpine@sha256:... — passes
  #      nginx:alpine@sha256:...       — fails (no version number)
  #      nginx:latest@sha256:...       — fails (caught by TS-103a too)
  run grep -E "nginx:[0-9]+\.[0-9]+[^@]*@sha256:" "${PROJECT_ROOT}/compose.yaml"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-103e [P2] — Runtime: pulled image digest matches compose pin
#   (Requires stack to be running; skipped in offline/unit-only runs)
# ---------------------------------------------------------------------------
@test "[P2][TS-103e] Runtime postgres image digest matches @sha256: pin in compose.yaml" {
  skip "P2 runtime test: requires running stack — run manually via Task 5"

  # Extract expected digest from compose.yaml (first sha256 line, which is postgres)
  local expected_digest
  expected_digest=$(grep -oE "sha256:[a-f0-9]{64}" "${PROJECT_ROOT}/compose.yaml" \
    | head -1)

  [ -n "${expected_digest}" ] || fail "No sha256 digest found in compose.yaml for postgres"

  # Get the running container's image ID via docker compose ps --format json
  # then inspect the image to retrieve its repo digest
  local container_name
  container_name=$(docker compose -f "${PROJECT_ROOT}/compose.yaml" ps --format json 2>/dev/null \
    | python3 -c "import sys,json; data=[json.loads(l) for l in sys.stdin if l.strip()]; \
      pg=[d for d in data if 'postgres' in d.get('Service','')]; \
      print(pg[0]['Image'] if pg else '')" 2>/dev/null || true)

  [ -n "${container_name}" ] || fail "Could not determine postgres image name from running containers"

  # docker inspect returns RepoDigests as an array; assert the pinned digest is present
  run bash -c "docker inspect --format '{{range .RepoDigests}}{{.}}{{\"\\n\"}}{{end}}' '${container_name}' \
    | grep -q '${expected_digest}' && echo MATCH || echo MISMATCH"
  assert_output "MATCH"
}

# ---------------------------------------------------------------------------
# TS-103f [P2] — postgres/init script has no floating version refs
# ---------------------------------------------------------------------------
@test "[P2][TS-103f] postgres/init/01-init-databases.sh contains no floating version strings" {
  assert [ -f "${PROJECT_ROOT}/postgres/init/01-init-databases.sh" ]

  # The init script should reference no external image tags or version pins
  # (it is a pure SQL/shell script; version concerns live in Dockerfile/compose.yaml)
  run grep -E ":[0-9]+\.[0-9]+" "${PROJECT_ROOT}/postgres/init/01-init-databases.sh"
  assert_failure
}
