#!/usr/bin/env bash
# tests/helpers/common.bash
# Shared helpers for all bats integration and unit tests.
# Story 1.1: Docker Compose stack — pinned Keycloak + PostgreSQL (two databases)

# Project root — resolve two levels up from tests/helpers/
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ---------------------------------------------------------------------------
# wait_for_healthy <service> <timeout_seconds>
# Poll "docker compose ps" until <service> status contains "healthy".
# ---------------------------------------------------------------------------
wait_for_healthy() {
  local service="${1}"
  local timeout="${2:-120}"
  local elapsed=0

  while [[ "${elapsed}" -lt "${timeout}" ]]; do
    local status
    status=$(docker compose -f "${PROJECT_ROOT}/compose.yaml" ps --format json 2>/dev/null \
      | grep -o '"Health":"[^"]*"' \
      | head -1 \
      | sed 's/"Health":"//;s/"//')

    # Fallback: use plain text output
    if docker compose -f "${PROJECT_ROOT}/compose.yaml" ps "${service}" 2>/dev/null \
        | grep -q "healthy"; then
      return 0
    fi

    sleep 5
    elapsed=$((elapsed + 5))
  done

  echo "TIMEOUT: ${service} did not reach healthy within ${timeout}s" >&2
  return 1
}

# ---------------------------------------------------------------------------
# compose_up / compose_down
# ---------------------------------------------------------------------------
compose_up() {
  docker compose -f "${PROJECT_ROOT}/compose.yaml" up -d --build
}

compose_down_volumes() {
  docker compose -f "${PROJECT_ROOT}/compose.yaml" down -v --remove-orphans
}

# ---------------------------------------------------------------------------
# env_setup
# Copy .env.example -> .env if no real .env exists (CI / clean checkout).
# ---------------------------------------------------------------------------
env_setup() {
  if [[ ! -f "${PROJECT_ROOT}/.env" ]]; then
    cp "${PROJECT_ROOT}/.env.example" "${PROJECT_ROOT}/.env"
    # Replace placeholders with deterministic test values
    # (safe for local CI — never used in production)
    sed -i.bak \
      -e "s|change-me-kc-admin-user|testadmin|g" \
      -e "s|change-me-kc-admin-password|TestAdmin!Pass1|g" \
      -e "s|change-me-postgres-user|postgres|g" \
      -e "s|change-me-postgres-password|TestPG!Root1|g" \
      -e "s|change-me-kc-db-user|keycloak|g" \
      -e "s|change-me-kc-db-password|TestKC!DB1|g" \
      -e "s|change-me-admin-db-user|adminapp|g" \
      -e "s|change-me-admin-db-password|TestAdmin!DB1|g" \
      "${PROJECT_ROOT}/.env"
    rm -f "${PROJECT_ROOT}/.env.bak"
  fi
}
