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
  local admin_user admin_pass response
  admin_user=$(_env_value "KC_BOOTSTRAP_ADMIN_USERNAME")
  admin_pass=$(_env_value "KC_BOOTSTRAP_ADMIN_PASSWORD")

  # Capture curl output explicitly so we can check curl's exit code before
  # passing the body to python3. This avoids an opaque JSONDecodeError when
  # curl fails (timeout, HTTP 4xx/5xx) and the pipe delivers empty stdin.
  response=$(curl -sf --max-time 15 \
    -d "client_id=admin-cli" \
    -d "username=${admin_user}" \
    -d "password=${admin_pass}" \
    -d "grant_type=password" \
    "http://localhost:8080/realms/master/protocol/openid-connect/token") \
    || { echo "get_admin_token: curl failed (exit $?) — is Keycloak running?" >&2; return 1; }

  echo "${response}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
t = d.get('access_token', '')
if not t:
    print('get_admin_token: no access_token in response (bad credentials?)', file=sys.stderr)
    sys.exit(1)
print(t)
"
}

# ---------------------------------------------------------------------------
# get_envocc_test_token [nonce]
# Obtain an ID token from the envocc realm using the Resource Owner Password
# Credentials grant on the test-only client. Prints the raw ID token string.
#
# NOTE: ROPC grant is used here only for automated integration testing.
#       Production clients must use Authorization Code + PKCE (Story 2.2).
#       The test client must have "Direct Access Grants" enabled in Keycloak.
#
# The nonce parameter is passed as the OAuth2 `nonce` request parameter so
# Keycloak embeds it in the returned ID token — enabling AC1/AC3 nonce tests.
#
# Requires environment variables (set defaults in each calling test file):
#   KC_DIRECT_URL         — Keycloak base URL  (default: http://localhost:8080)
#   KC_TEST_CLIENT_ID     — test-only OIDC client ID
#   KC_TEST_CLIENT_SECRET — test-only OIDC client secret
#   KC_TEST_USER          — test user username
#   KC_TEST_PASSWORD      — test user password
#
# The default nonce uses `date +%s` (portable: works on macOS BSD date and
# Linux) combined with the shell PID to guarantee uniqueness within a run.
# ---------------------------------------------------------------------------
get_envocc_test_token() {
  local nonce="${1:-test-nonce-$(date +%s)-$$}"

  local response
  response=$(curl -sf --max-time 15 \
    -d "client_id=${KC_TEST_CLIENT_ID}" \
    -d "client_secret=${KC_TEST_CLIENT_SECRET}" \
    -d "username=${KC_TEST_USER}" \
    -d "password=${KC_TEST_PASSWORD}" \
    -d "grant_type=password" \
    -d "scope=openid email" \
    -d "nonce=${nonce}" \
    "${KC_DIRECT_URL}/realms/envocc/protocol/openid-connect/token") \
    || {
      echo "get_envocc_test_token: curl failed — is Keycloak reachable at ${KC_DIRECT_URL}?" >&2
      echo "  Ensure INTEGRATION=1, stack is running, and test client '${KC_TEST_CLIENT_ID}' is registered." >&2
      return 1
    }

  echo "${response}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
t = d.get('id_token', '')
if not t:
    err = d.get('error_description', d.get('error', 'unknown error'))
    print(f'get_envocc_test_token: no id_token in response — {err}', file=sys.stderr)
    sys.exit(1)
print(t, end='')
"
}

# ---------------------------------------------------------------------------
# compose_service_field <service_name> <python_expression>
# Parses compose.yaml and evaluates <python_expression> with `svc` bound to
# the named service's dict. Prints the evaluated result to stdout.
#
# Uses `docker compose config --format json` for env-var-substituted output;
# falls back to raw YAML parse via PyYAML if docker is unavailable.
#
# Usage examples:
#   compose_service_field nginx "'defined' if svc.get('healthcheck') else 'missing'"
#   compose_service_field keycloak "svc.get('environment', {}).get('KC_PROXY_HEADERS', '')"
# ---------------------------------------------------------------------------
compose_service_field() {
  local service="${1}"
  local expression="${2}"

  python3 - "${PROJECT_ROOT}/compose.yaml" "${service}" "${expression}" <<'PYEOF'
import sys, json, subprocess

compose_file = sys.argv[1]
service_name = sys.argv[2]
expression   = sys.argv[3]

# Prefer docker compose config (resolves env vars) over raw YAML parse.
cfg = None
try:
    result = subprocess.run(
        ["docker", "compose", "-f", compose_file, "config", "--format", "json"],
        capture_output=True, text=True, check=True
    )
    cfg = json.loads(result.stdout)
except Exception:
    pass

if cfg is None:
    try:
        import yaml
        with open(compose_file) as f:
            cfg = yaml.safe_load(f)
    except ImportError:
        print("ERROR: docker unavailable and PyYAML not installed", file=sys.stderr)
        sys.exit(2)

svc = cfg.get("services", {}).get(service_name, {})
print(eval(expression))
PYEOF
}

# ---------------------------------------------------------------------------
# check_no_pdpa_sensitive_attrs <user_json_file>
# Runs a Python check against the given user JSON file, exiting non-zero
# and printing a diagnostic message if any PDPA §26 sensitive field is found
# in the user's 'attributes' map.
#
# Single source of truth for the PDPA §26 forbidden attribute list — update
# here if the data-minimisation requirements (FR23/NFR12) change.
#
# Usage (in BATS tests):
#   run check_no_pdpa_sensitive_attrs "${user_tmpfile}"
#   assert_success
# ---------------------------------------------------------------------------
check_no_pdpa_sensitive_attrs() {
  local user_file="${1}"
  python3 - "${user_file}" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    user = json.load(f)

# PDPA §26 sensitive data categories forbidden from user attribute storage.
# National ID / PID for ThaiD is stored ONLY in the identity broker link — not here.
sensitive_fields = [
    'nationalId', 'pid', 'citizenId', 'dateOfBirth', 'gender',
    'ethnicity', 'religion', 'healthInfo', 'biometric', 'criminalRecord',
    'politicalOpinion', 'sexualOrientation', 'tradeUnion', 'geneticData',
]

attrs = user.get('attributes', {})
found = [f for f in sensitive_fields if f in attrs]

if found:
    print(f'PDPA §26 violation: sensitive fields found in user attributes: {found}')
    sys.exit(1)

sys.exit(0)
PYEOF
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
