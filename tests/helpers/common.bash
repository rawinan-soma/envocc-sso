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
# Linux) combined with the shell PID. This is sufficiently distinct per run;
# it is not a strict uniqueness guarantee (1-second resolution + constant PID),
# but each test only compares its own sent nonce against the echoed token claim.
# ---------------------------------------------------------------------------
get_envocc_test_token() {
  local nonce="${1:-test-nonce-$(date +%s)-$$}"

  # NOTE: intentionally NOT using curl -f here. With -f, curl discards the
  # response body on HTTP 4xx/5xx, so the Keycloak `error_description` below
  # would never surface and every auth rejection would be misreported as a
  # connection failure. Without -f, curl exits non-zero only on a genuine
  # network/timeout error; HTTP error responses flow through to the parser.
  local response
  response=$(curl -s --max-time 15 \
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
try:
    d = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f'get_envocc_test_token: Keycloak response is not valid JSON (HTML error page or proxy error?): {e}', file=sys.stderr)
    sys.exit(1)
t = d.get('id_token', '')
if not t:
    err = d.get('error_description', d.get('error', 'unknown error'))
    print(f'get_envocc_test_token: no id_token in response — {err}', file=sys.stderr)
    sys.exit(1)
print(t, end='')
"
}

# ---------------------------------------------------------------------------
# fetch_realm_json_to_tmpfile <admin_token>
# Fetch the live Keycloak 'envocc' realm JSON to a fresh temp file.
# Prints the temp-file path to stdout; exits non-zero on curl failure
# (with an error message on stderr so the caller's `fail` is self-contained).
#
# Companion to get_admin_token — call after obtaining a token.
#
# Usage:
#   local token realm_tmpfile
#   token=$(get_admin_token)              || fail "Could not obtain admin token"
#   realm_tmpfile=$(fetch_realm_json_to_tmpfile "${token}") \
#                                         || fail "Could not fetch realm JSON"
#   run python3 - "${realm_tmpfile}" <<'PYEOF'
#   ...
#   PYEOF
#   assert_success
#   rm -f "${realm_tmpfile}"
# ---------------------------------------------------------------------------
fetch_realm_json_to_tmpfile() {
  local token="${1}"
  local tmpfile
  tmpfile=$(mktemp) || {
    echo "fetch_realm_json_to_tmpfile: mktemp failed — TMPDIR unwritable or out of space?" >&2
    return 1
  }

  local curl_exit=0
  curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc" > "${tmpfile}" \
    || curl_exit=$?

  if [[ "${curl_exit}" -ne 0 ]]; then
    rm -f "${tmpfile}"
    echo "fetch_realm_json_to_tmpfile: curl failed (exit ${curl_exit}) — is Keycloak running?" >&2
    return 1
  fi

  # Guard against a 200 response with an empty/truncated body (e.g. a connection
  # dropped after headers) — otherwise the caller's json.load raises an opaque
  # JSONDecodeError. Confirm the payload is non-empty, parseable JSON.
  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "${tmpfile}" 2>/dev/null; then
    rm -f "${tmpfile}"
    echo "fetch_realm_json_to_tmpfile: realm JSON empty or unparseable — incomplete response body" >&2
    return 1
  fi

  echo "${tmpfile}"
}

# ---------------------------------------------------------------------------
# configure_test_ropc_client_secret <admin_token>
# Reads KC_TEST_ROPC_CLIENT_SECRET from .env and pushes it onto the live
# test-ropc-client via PUT /clients/{id} — the realm export ships the client
# with a zeroed secret (secret hygiene). Prints the secret to stdout on
# success; exits non-zero with a stderr diagnostic on any failure.
#
# Shared by tests/integration/identity-model.bats (TS-210d, pattern origin)
# and tests/integration/account-disable.bats (TS-280a/b/d/e/f/g) — promoted
# here so a second consumer doesn't have to carry its own copy.
#
# Usage:
#   local token ropc_secret
#   token=$(get_admin_token) || fail "Could not obtain admin token"
#   ropc_secret=$(configure_test_ropc_client_secret "${token}") \
#     || fail "Could not configure test-ropc-client secret"
# ---------------------------------------------------------------------------
configure_test_ropc_client_secret() {
  local token="${1}"
  local ropc_secret
  ropc_secret=$(_env_value "KC_TEST_ROPC_CLIENT_SECRET")
  if [[ -z "${ropc_secret}" ]]; then
    echo "configure_test_ropc_client_secret: KC_TEST_ROPC_CLIENT_SECRET not set in .env" >&2
    return 1
  fi

  local clients_json client_uuid client_rep update_status
  clients_json=$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    "http://localhost:8080/admin/realms/envocc/clients?clientId=test-ropc-client") || {
    echo "configure_test_ropc_client_secret: could not look up test-ropc-client — is the realm import current?" >&2
    return 1
  }
  client_uuid=$(echo "${clients_json}" | python3 -c "import json,sys; c=json.load(sys.stdin); print(c[0]['id'] if c else '')")
  if [[ -z "${client_uuid}" ]]; then
    echo "configure_test_ropc_client_secret: test-ropc-client not found in realm — re-import realm-export.json" >&2
    return 1
  fi
  client_rep=$(echo "${clients_json}" | ROPC_SECRET="${ropc_secret}" python3 -c "import json,sys,os; c=json.load(sys.stdin)[0]; c['secret']=os.environ['ROPC_SECRET']; print(json.dumps(c))")
  update_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "${client_rep}" \
    "http://localhost:8080/admin/realms/envocc/clients/${client_uuid}")
  if [[ "${update_status}" != "204" ]]; then
    echo "configure_test_ropc_client_secret: could not set test-ropc-client secret (got HTTP ${update_status})" >&2
    return 1
  fi

  echo "${ropc_secret}"
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
