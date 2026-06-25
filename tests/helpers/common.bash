#!/usr/bin/env bash
# tests/helpers/common.bash
# Shared helpers for all bats integration and unit tests.
# Story 1.1: Docker Compose stack — pinned Keycloak + PostgreSQL (two databases)
# Story 1.2: Realm config-as-code baseline & secret hygiene

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
# get_admin_token
# Obtain a Keycloak admin-cli token using KC_BOOTSTRAP_ADMIN_* from .env.
# Reads credentials via literal sed-parse (not source) to preserve special chars.
# Prints the access_token to stdout; exits non-zero if the token could not be obtained.
#
# Usage:
#   local token
#   token=$(get_admin_token) || fail "Could not obtain admin token"
# ---------------------------------------------------------------------------
# Read one KEY=value from .env, normalising the way Docker Compose does:
#   - last assignment wins (tail -n 1)
#   - a trailing CR (CRLF checkouts) is removed
#   - a single pair of surrounding quotes (" or ') is stripped
_env_value() {
  local key="${1}"
  sed -n "s/^${key}=//p" "${PROJECT_ROOT}/.env" \
    | tail -n 1 \
    | tr -d '\r' \
    | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

get_admin_token() {
  local admin_user admin_pass
  admin_user=$(_env_value "KC_BOOTSTRAP_ADMIN_USERNAME")
  admin_pass=$(_env_value "KC_BOOTSTRAP_ADMIN_PASSWORD")

  curl -sf --max-time 15 \
    -d "client_id=admin-cli" \
    -d "username=${admin_user}" \
    -d "password=${admin_pass}" \
    -d "grant_type=password" \
    "http://localhost:8080/realms/master/protocol/openid-connect/token" \
    | python3 -c "
import json, sys
d = json.load(sys.stdin)
t = d.get('access_token', '')
if not t:
    sys.exit(1)
print(t)
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
