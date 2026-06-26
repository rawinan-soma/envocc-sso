#!/usr/bin/env bash
# tests/helpers/common.bash
# Shared helpers for all bats integration and unit tests.
# Story 1.1: Docker Compose stack — pinned Keycloak + PostgreSQL (two databases)

# Project root — resolve two levels up from tests/helpers/
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ---------------------------------------------------------------------------
# wait_for_healthy <service> <timeout_seconds>
# Poll "docker compose ps <service>" until the output contains "(healthy)".
# Uses the plain-text compose ps output which reliably shows "(healthy)" once
# the container's healthcheck has passed.
# ---------------------------------------------------------------------------
wait_for_healthy() {
  local service="${1}"
  local timeout="${2:-120}"
  local elapsed=0

  while [[ "${elapsed}" -lt "${timeout}" ]]; do
    if docker compose -f "${PROJECT_ROOT}/compose.yaml" ps "${service}" 2>/dev/null \
        | grep -q "(healthy)"; then
      return 0
    fi

    sleep 5
    elapsed=$((elapsed + 5))
  done

  echo "TIMEOUT: ${service} did not reach healthy within ${timeout}s" >&2
  docker compose -f "${PROJECT_ROOT}/compose.yaml" ps 2>/dev/null >&2 || true
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
# compose_service_field <service> <python_expr>
#
# Parse `docker compose config` output with python3 and evaluate <python_expr>
# against the parsed YAML, printing the result to stdout.
#
# <python_expr> receives:
#   svc  — the service dict for <service> (e.g. svc.get('environment', {}))
#
# Example:
#   compose_service_field "nginx" "svc.get('healthcheck', {}).get('test', [])"
#
# Added in Story 1.3 review: the four TS-138x tests in nginx-config.bats each
# ran a full `docker compose config | python3` pipeline independently (~300ms
# each). Centralising here lets tests share the pattern and keeps the
# extraction logic in one place.
# ---------------------------------------------------------------------------
compose_service_field() {
  local service="${1}"
  local py_expr="${2}"
  docker compose -f "${PROJECT_ROOT}/compose.yaml" config 2>/dev/null \
    | python3 -c "
import sys, yaml
cfg = yaml.safe_load(sys.stdin)
# Guard: yaml.safe_load returns None on empty input (docker compose config failed
# or produced no output). Fail with a clear message rather than an AttributeError
# on None.get() which is hard to diagnose from a BATS test failure.
if cfg is None:
    import sys as _sys
    print('ERROR: docker compose config produced no output (docker down? missing .env?)', file=_sys.stderr)
    raise SystemExit(1)
svc = cfg.get('services', {}).get('${service}', {})
print(${py_expr})
"
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
