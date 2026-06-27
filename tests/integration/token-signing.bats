#!/usr/bin/env bats
# tests/integration/token-signing.bats
# ATDD RED-PHASE scaffolds — Story 2.3: Signed Tokens, JWKS & OIDC Discovery
#
# Acceptance Criteria covered:
#   AC1: ID token is RS256-signed; required claims: sub, email, iss, aud, exp, iat, nonce (FR5, NFR3)
#   AC5: Token lifetime: exp - iat ≤ 900 seconds (NFR2a)
#   AC6: alg:none tokens are rejected (NFR3, NFR8)
#
# Test scenarios:
#   TS-231a [P0] ID token header `alg` is RS256 — not alg:none or HS256 (AC1, AC6)
#   TS-231b [P0] Required claims present in ID token payload: sub, email, iss, aud, exp, iat, nonce (AC1)
#   TS-231c [P0] Token lifetime exp - iat does not exceed 900 seconds (AC5, NFR2a)
#   TS-231d [P0] Keycloak rejects a JWT with alg:none at the userinfo endpoint — HTTP 401 (AC6, NFR3, NFR8)
#
# NOTE: All tests are RED PHASE.
#       `skip "RED PHASE — ..."` marks each test as not yet activated.
#       Workflow:
#         1. Pick a task to implement.
#         2. Remove the `skip` from the matching test.
#         3. Confirm the test FAILS (red phase verified).
#         4. Implement until the test turns GREEN.
#         5. Do not re-add `skip`.
#
# Prerequisites (requires INTEGRATION=1 and a running full stack):
#   1. docker compose up --build -d  (postgres → keycloak → nginx all healthy)
#   2. A test-only OIDC client in the envocc realm with direct access grants enabled:
#        Client ID:     $KC_TEST_CLIENT_ID   (default: envocc-test-client)
#        Client Secret: $KC_TEST_CLIENT_SECRET
#        Grant types:   password (direct grant — test-only, not for production)
#   3. A test user in the envocc realm:
#        Username: $KC_TEST_USER     (default: testuser@envocc.go.th)
#        Password: $KC_TEST_PASSWORD (default: TestUser!Pass1)
#        email attribute set to the username (for AC1 email claim assertion)
#
# NOTE on port access:
#   Keycloak's port 8080 is intentionally NOT published to the host (see compose.yaml
#   Story 1.3 note). These tests use KC_DIRECT_URL (default: http://localhost:8080).
#   To reach Keycloak in a sealed stack, either:
#   (a) Add a test-specific compose override that publishes port 8080, OR
#   (b) Set KC_DIRECT_URL=https://localhost and use the Nginx proxy path.
#   The NGINX_BASE_URL is used for tests that must go through the Nginx edge.
#
# Run: INTEGRATION=1 bats tests/integration/token-signing.bats

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Configuration — all overridable via environment variables
# ---------------------------------------------------------------------------
KC_DIRECT_URL="${KC_DIRECT_URL:-http://localhost:8080}"
NGINX_BASE_URL="${NGINX_BASE_URL:-https://localhost}"
KC_TEST_CLIENT_ID="${KC_TEST_CLIENT_ID:-envocc-test-client}"
KC_TEST_CLIENT_SECRET="${KC_TEST_CLIENT_SECRET:-test-secret-change-me}"
KC_TEST_USER="${KC_TEST_USER:-testuser@envocc.go.th}"
KC_TEST_PASSWORD="${KC_TEST_PASSWORD:-TestUser!Pass1}"

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
# ---------------------------------------------------------------------------
get_envocc_test_token() {
  local nonce="${1:-test-nonce-$(date +%s%N)}"

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
# Per-test setup: guard against runs without INTEGRATION flag
# ---------------------------------------------------------------------------
setup() {
  if [[ -z "${INTEGRATION}" ]]; then
    skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"
  fi
}

# ---------------------------------------------------------------------------
# TS-231a [P0] — ID token header `alg` is RS256 (AC1, AC6)
# Verifies that Keycloak signs ID tokens with RS256 (asymmetric signing).
# This is both a positive assertion (alg=RS256) and a negative assertion
# against alg:none / symmetric algorithms (NFR3, NFR8).
# ---------------------------------------------------------------------------
@test "[P0][TS-231a] ID token header alg field is RS256" {

  local nonce="ts-231a-$(date +%s)"
  local id_token_file
  id_token_file=$(mktemp)

  get_envocc_test_token "${nonce}" > "${id_token_file}" \
    || { rm -f "${id_token_file}"; fail "Could not obtain ID token — check test client and user setup"; }

  run python3 - "${id_token_file}" <<'PYEOF'
import sys, base64, json

with open(sys.argv[1]) as f:
    token = f.read().strip()

parts = token.split('.')
if len(parts) != 3:
    print(f"ERROR: JWT must have 3 parts, got {len(parts)}", file=sys.stderr)
    sys.exit(1)

# Decode header (part 0)
header_segment = parts[0]
header_segment += '=' * (4 - len(header_segment) % 4)
try:
    header = json.loads(base64.urlsafe_b64decode(header_segment))
except Exception as e:
    print(f"ERROR: Cannot decode JWT header: {e}", file=sys.stderr)
    sys.exit(1)

alg = header.get('alg', '')
if alg != 'RS256':
    print(f"FAIL: Expected alg=RS256 in ID token header, got alg={alg!r}", file=sys.stderr)
    sys.exit(1)

print(f"PASS: ID token header alg={alg}")
sys.exit(0)
PYEOF

  assert_success
  rm -f "${id_token_file}"
}

# ---------------------------------------------------------------------------
# TS-231b [P0] — Required claims present in ID token payload (AC1)
# Verifies that the issued ID token carries all required claims:
#   sub   — stable internal subject (Keycloak user ID)
#   email — work email as reconciliation key (via email-claims client scope)
#   iss   — issuer (must reference envocc realm)
#   aud   — audience
#   exp   — expiration time
#   iat   — issued at time
#   nonce — replay-protection value matching the auth request nonce (FR5)
# ---------------------------------------------------------------------------
@test "[P0][TS-231b] ID token payload contains all required claims: sub email iss aud exp iat nonce" {

  local nonce="ts-231b-$(date +%s)"
  local id_token_file
  id_token_file=$(mktemp)

  get_envocc_test_token "${nonce}" > "${id_token_file}" \
    || { rm -f "${id_token_file}"; fail "Could not obtain ID token — check test client and user setup"; }

  run python3 - "${id_token_file}" "${nonce}" <<'PYEOF'
import sys, base64, json

with open(sys.argv[1]) as f:
    token = f.read().strip()
expected_nonce = sys.argv[2]

parts = token.split('.')
if len(parts) != 3:
    print(f"ERROR: Not a valid JWT (expected 3 parts)", file=sys.stderr)
    sys.exit(1)

# Decode payload (part 1)
payload_segment = parts[1]
payload_segment += '=' * (4 - len(payload_segment) % 4)
try:
    payload = json.loads(base64.urlsafe_b64decode(payload_segment))
except Exception as e:
    print(f"ERROR: Cannot decode JWT payload: {e}", file=sys.stderr)
    sys.exit(1)

failures = []

# Assert all required claims are present
required_claims = ['sub', 'email', 'iss', 'aud', 'exp', 'iat', 'nonce']
for claim in required_claims:
    if claim not in payload:
        failures.append(f"Missing required claim: '{claim}'")

# Assert issuer references the envocc realm
iss = payload.get('iss', '')
if 'envocc' not in iss:
    failures.append(f"Issuer must reference envocc realm, got: {iss!r}")

# Assert nonce matches what was sent in the auth request (AC1, FR5)
actual_nonce = payload.get('nonce', '')
if actual_nonce != expected_nonce:
    failures.append(f"Nonce mismatch — sent: {expected_nonce!r}, token: {actual_nonce!r}")

if failures:
    print("FAIL — ID token claim violations:", file=sys.stderr)
    for f in failures:
        print(f"  - {f}", file=sys.stderr)
    sys.exit(1)

sub = payload.get('sub', '')
email = payload.get('email', '')
print(f"PASS: All required claims present (sub={sub[:8]}..., email={email}, iss={iss})")
sys.exit(0)
PYEOF

  assert_success
  rm -f "${id_token_file}"
}

# ---------------------------------------------------------------------------
# TS-231c [P0] — Token lifetime exp - iat ≤ 900 seconds (AC5, NFR2a)
# Verifies that the issued token's lifetime does not exceed the 15-minute hard
# ceiling. The current realm setting is 300 s (5 min) — this test enforces the
# ceiling as a regression guard so the setting cannot be silently relaxed.
# ---------------------------------------------------------------------------
@test "[P0][TS-231c] ID token lifetime exp minus iat does not exceed 900 seconds" {

  local nonce="ts-231c-$(date +%s)"
  local id_token_file
  id_token_file=$(mktemp)

  get_envocc_test_token "${nonce}" > "${id_token_file}" \
    || { rm -f "${id_token_file}"; fail "Could not obtain ID token"; }

  run python3 - "${id_token_file}" <<'PYEOF'
import sys, base64, json

with open(sys.argv[1]) as f:
    token = f.read().strip()

parts = token.split('.')
payload_segment = parts[1]
payload_segment += '=' * (4 - len(payload_segment) % 4)
payload = json.loads(base64.urlsafe_b64decode(payload_segment))

exp = payload.get('exp')
iat = payload.get('iat')

if exp is None or iat is None:
    print("ERROR: ID token missing 'exp' or 'iat' claim", file=sys.stderr)
    sys.exit(1)

lifetime = exp - iat
NFR2A_CEILING = 900  # 15 minutes

if lifetime > NFR2A_CEILING:
    print(
        f"FAIL: Token lifetime {lifetime}s exceeds NFR2a ceiling of {NFR2A_CEILING}s (15 min). "
        f"Current realm accessTokenLifespan must not be raised above 900 s.",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"PASS: Token lifetime {lifetime}s ≤ {NFR2A_CEILING}s ceiling")
sys.exit(0)
PYEOF

  assert_success
  rm -f "${id_token_file}"
}

# ---------------------------------------------------------------------------
# TS-231d [P0] — alg:none token rejected at userinfo endpoint — HTTP 401 (AC6, NFR3, NFR8)
# Constructs a forged JWT with alg:none (unsigned) and a fabricated payload
# claiming to be a valid envocc user. Asserts that Keycloak rejects the token
# with HTTP 401 at the userinfo endpoint.
# Keycloak rejects alg:none by default — this test guards against regressions
# (e.g., a realm configuration change that might inadvertently allow it).
# ---------------------------------------------------------------------------
@test "[P0][TS-231d] Keycloak rejects alg:none JWT at userinfo endpoint with HTTP 401" {

  # Build forged JWT: header {"alg":"none","typ":"JWT"}
  local forged_header
  forged_header=$(python3 -c "
import base64, json
header = {'alg': 'none', 'typ': 'JWT'}
encoded = base64.urlsafe_b64encode(json.dumps(header, separators=(',', ':')).encode()).decode().rstrip('=')
print(encoded, end='')
")

  # Build forged payload with envocc issuer and far-future expiry
  local forged_payload
  forged_payload=$(python3 -c "
import base64, json, time
payload = {
    'sub': 'attacker-fabricated-sub',
    'iss': '${KC_DIRECT_URL}/realms/envocc',
    'aud': '${KC_TEST_CLIENT_ID}',
    'exp': int(time.time()) + 3600,
    'iat': int(time.time()),
    'email': 'attacker@evil.example.com',
}
encoded = base64.urlsafe_b64encode(json.dumps(payload, separators=(',', ':')).encode()).decode().rstrip('=')
print(encoded, end='')
")

  # alg:none JWT has an empty signature part
  local alg_none_token="${forged_header}.${forged_payload}."

  # Present the forged token to the userinfo endpoint — must be rejected
  local http_status
  http_status=$(curl -k -s --max-time 10 \
    -H "Authorization: Bearer ${alg_none_token}" \
    "${KC_DIRECT_URL}/realms/envocc/protocol/openid-connect/userinfo" \
    -o /dev/null \
    -w "%{http_code}" \
    2>/dev/null || echo "000")

  # Keycloak must return HTTP 401; any other status is a failure
  if [[ "${http_status}" != "401" ]]; then
    fail "Expected HTTP 401 for alg:none token, got: ${http_status} — Keycloak may be misconfigured"
  fi
}
