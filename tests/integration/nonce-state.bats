#!/usr/bin/env bats
# tests/integration/nonce-state.bats
# ATDD RED-PHASE scaffolds — Story 2.3: Signed Tokens, JWKS & OIDC Discovery
#
# Acceptance Criteria covered:
#   AC3: state and nonce binding; nonce single-use; same nonce in a replayed
#        ID token must fail client-side validation (FR6, FR47)
#
# Test scenarios:
#   TS-233a [P1] Auth request with nonce — ID token contains matching nonce claim (AC3)
#   TS-233b [P1] Nonce in ID token is verified once — second validation of same nonce fails (AC3)
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
#
# Scope of this test file — server-side only:
#   Story 2.3 validates that Keycloak embeds the nonce in the ID token (server-side).
#   Client-side nonce validation (single-use enforcement by the OIDC library `openid-client`)
#   is out of scope for Story 2.3 and is tested in Story 4.2 (admin OIDC sign-in).
#   TS-233b simulates a simple client-side replay check to document the expected
#   behavior and guard against nonce omission in the token.
#
# NOTE on port access:
#   Keycloak's port 8080 is intentionally NOT published to the host (see compose.yaml
#   Story 1.3 note). These tests use KC_DIRECT_URL (default: http://localhost:8080).
#
# Run: INTEGRATION=1 bats tests/integration/nonce-state.bats

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Configuration — all overridable via environment variables
# ---------------------------------------------------------------------------
KC_DIRECT_URL="${KC_DIRECT_URL:-http://localhost:8080}"
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
# Keycloak embeds it in the returned ID token — this is the server-side
# behavior under test.
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
# TS-233a [P1] — Auth request with nonce — ID token contains matching nonce claim (AC3)
# Verifies that when an OIDC auth request includes a `nonce` parameter,
# Keycloak embeds the exact nonce value in the returned ID token as the `nonce`
# claim. This server-side binding is the foundation of nonce-based replay protection.
#
# Scope clarification:
#   This test validates SERVER-SIDE behavior only — that Keycloak echoes the nonce
#   into the token. The client-side single-use enforcement (exactly-once check by
#   `openid-client`) is validated in Story 4.2.
# ---------------------------------------------------------------------------
@test "[P1][TS-233a] ID token contains nonce claim matching the value sent in the auth request" {
  skip "RED PHASE — Task 5.8: add email-claims client scope + RSA key provider; verify nonce claim present in ID token"

  # Generate a unique nonce for this test run — must survive in the token
  local sent_nonce="ts-233a-$(date +%s%N)"

  local id_token_file
  id_token_file=$(mktemp)

  get_envocc_test_token "${sent_nonce}" > "${id_token_file}" \
    || { rm -f "${id_token_file}"; fail "Could not obtain ID token — check test client and user setup"; }

  run python3 - "${id_token_file}" "${sent_nonce}" <<'PYEOF'
import sys, base64, json

with open(sys.argv[1]) as f:
    token = f.read().strip()
expected_nonce = sys.argv[2]

parts = token.split('.')
if len(parts) != 3:
    print(f"ERROR: Not a valid JWT (expected 3 parts, got {len(parts)})", file=sys.stderr)
    sys.exit(1)

# Decode payload (part 1)
payload_segment = parts[1]
payload_segment += '=' * (4 - len(payload_segment) % 4)
try:
    payload = json.loads(base64.urlsafe_b64decode(payload_segment))
except Exception as e:
    print(f"ERROR: Cannot decode JWT payload: {e}", file=sys.stderr)
    sys.exit(1)

# Assert nonce claim is present in the token
if 'nonce' not in payload:
    print(
        "FAIL: ID token payload does not contain a 'nonce' claim. "
        "Keycloak must include the nonce from the auth request in the ID token (FR6, FR47).",
        file=sys.stderr,
    )
    print(f"Token payload claims: {sorted(payload.keys())}", file=sys.stderr)
    sys.exit(1)

actual_nonce = payload['nonce']

# Assert the nonce matches what was sent in the auth request
if actual_nonce != expected_nonce:
    print(
        f"FAIL: Nonce mismatch. "
        f"Sent nonce: {expected_nonce!r}; "
        f"Token nonce: {actual_nonce!r}",
        file=sys.stderr,
    )
    sys.exit(1)

print(
    f"PASS: ID token nonce claim matches sent nonce "
    f"(nonce={actual_nonce!r})"
)
sys.exit(0)
PYEOF

  assert_success
  rm -f "${id_token_file}"
}

# ---------------------------------------------------------------------------
# TS-233b [P1] — Nonce replay simulation — second use of same nonce fails client-side (AC3)
# Documents the expected single-use behavior of the nonce by simulating a
# basic client-side nonce validation pattern:
#   1. Obtain an ID token with a specific nonce.
#   2. Validate the token's nonce — first validation succeeds.
#   3. Attempt to re-validate the same token nonce — must fail (nonce already used).
#
# Scope clarification:
#   Keycloak is not directly involved in nonce single-use enforcement — it embeds
#   the nonce in the token but does not track nonce usage. The OIDC client library
#   (`openid-client`) is responsible for exactly-once enforcement by storing used
#   nonces in the session. This test simulates that pattern to guard against nonce
#   omission or mismatched nonce values in the token.
#
#   Full client-side enforcement (using `openid-client`) is tested in Story 4.2.
#   This test validates: if the nonce is present in the token and tracked in a
#   simple nonce store, replaying the same token is detected.
# ---------------------------------------------------------------------------
@test "[P1][TS-233b] Replaying an ID token with the same nonce is detected by client-side nonce validation" {
  skip "RED PHASE — Task 5.8: verify nonce claim present; simulate replay detection pattern"

  local sent_nonce="ts-233b-$(date +%s%N)"

  local id_token_file
  id_token_file=$(mktemp)

  get_envocc_test_token "${sent_nonce}" > "${id_token_file}" \
    || { rm -f "${id_token_file}"; fail "Could not obtain ID token — check test client and user setup"; }

  run python3 - "${id_token_file}" "${sent_nonce}" <<'PYEOF'
import sys, base64, json

with open(sys.argv[1]) as f:
    token = f.read().strip()
expected_nonce = sys.argv[2]

parts = token.split('.')
if len(parts) != 3:
    print(f"ERROR: Not a valid JWT", file=sys.stderr)
    sys.exit(1)

payload_segment = parts[1]
payload_segment += '=' * (4 - len(payload_segment) % 4)
try:
    payload = json.loads(base64.urlsafe_b64decode(payload_segment))
except Exception as e:
    print(f"ERROR: Cannot decode JWT payload: {e}", file=sys.stderr)
    sys.exit(1)

token_nonce = payload.get('nonce', '')

if not token_nonce:
    print(
        "FAIL: ID token missing 'nonce' claim — cannot validate replay protection. "
        "Ensure Keycloak embeds the nonce from the auth request in the ID token.",
        file=sys.stderr,
    )
    sys.exit(1)

if token_nonce != expected_nonce:
    print(
        f"FAIL: Token nonce {token_nonce!r} does not match sent nonce {expected_nonce!r}",
        file=sys.stderr,
    )
    sys.exit(1)

# --- Simulate client-side nonce store (in-memory, single-request scope) ---
#
# A real OIDC client (e.g., openid-client) stores the nonce in the session
# at auth-request time and deletes it after the first successful token validation.
# Attempting to validate a second token with the same nonce raises an error
# because the nonce has already been consumed.
#
# This simulation uses a simple in-memory set to model that behavior.

class NonceStore:
    """Minimal simulation of an OIDC client nonce store."""

    def __init__(self):
        self._used_nonces = set()

    def validate_and_consume(self, nonce):
        """Return True if nonce is valid and not yet used; raise if already used."""
        if nonce in self._used_nonces:
            raise ValueError(f"Nonce replay detected: nonce {nonce!r} has already been used")
        self._used_nonces.add(nonce)
        return True


nonce_store = NonceStore()

# First validation: should succeed
try:
    nonce_store.validate_and_consume(token_nonce)
except ValueError as e:
    print(f"FAIL: First nonce validation unexpectedly failed: {e}", file=sys.stderr)
    sys.exit(1)

# Second validation with same nonce: must raise (replay detected)
try:
    nonce_store.validate_and_consume(token_nonce)
    # If we reach here, replay was not detected — FAIL
    print(
        f"FAIL: Second nonce validation succeeded — replay not detected. "
        f"A nonce must be usable exactly once.",
        file=sys.stderr,
    )
    sys.exit(1)
except ValueError:
    # Expected — replay correctly detected
    pass

print(
    f"PASS: Nonce {token_nonce!r} present in token; "
    "first validation succeeded; second validation (replay) correctly rejected"
)
sys.exit(0)
PYEOF

  assert_success
  rm -f "${id_token_file}"
}
