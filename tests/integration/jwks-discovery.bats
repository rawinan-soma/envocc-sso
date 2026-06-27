#!/usr/bin/env bats
# tests/integration/jwks-discovery.bats
# ATDD RED-PHASE scaffolds — Story 2.3: Signed Tokens, JWKS & OIDC Discovery
#
# Acceptance Criteria covered:
#   AC2: JWKS endpoint publishes signing key with kid, kty:RSA, use:sig (FR5, NFR3)
#   AC4: OIDC discovery document lets clients self-configure (FR11)
#   AC6: alg:none tokens rejected at token/userinfo endpoint (NFR3, NFR8)
#   AC8: JWKS and discovery Cache-Control headers preserved through Nginx edge (FR50)
#
# Test scenarios:
#   TS-232a [P0] JWKS endpoint returns valid JSON with at least one RSA signing key with kid (AC2)
#   TS-232b [P0] JWKS signing key has kty=RSA and use=sig (AC2)
#   TS-234a [P1] OIDC discovery document present with required fields (AC4)
#   TS-236a [P0] alg:none JWT presented to token introspect/userinfo is rejected with HTTP 401 (AC6)
#   TS-238a [P1] JWKS endpoint Cache-Control header preserved through Nginx edge (AC8)
#   TS-238b [P1] Discovery endpoint Cache-Control header preserved through Nginx edge (AC8)
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
#
# NOTE on port access:
#   Keycloak's port 8080 is intentionally NOT published to the host (see compose.yaml
#   Story 1.3 note). These tests use KC_DIRECT_URL (default: http://localhost:8080).
#   JWKS and discovery endpoints are public/unauthenticated — no token needed.
#   Cache-Control assertions (TS-238*) use NGINX_BASE_URL (default: https://localhost)
#   because they validate the Nginx edge preservation behavior (AC8).
#
# Run: INTEGRATION=1 bats tests/integration/jwks-discovery.bats

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Configuration — all overridable via environment variables
# ---------------------------------------------------------------------------
KC_DIRECT_URL="${KC_DIRECT_URL:-http://localhost:8080}"
NGINX_BASE_URL="${NGINX_BASE_URL:-https://localhost}"

# ---------------------------------------------------------------------------
# Per-test setup: guard against runs without INTEGRATION flag
# ---------------------------------------------------------------------------
setup() {
  if [[ -z "${INTEGRATION}" ]]; then
    skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"
  fi
}

# ---------------------------------------------------------------------------
# Per-test teardown: always remove the response temp files, including on the
# failure paths where the inline `rm` after assert_success is never reached.
# ---------------------------------------------------------------------------
teardown() {
  rm -f "/tmp/jwks-response-$$.json" "/tmp/discovery-response-$$.json"
}

# ---------------------------------------------------------------------------
# TS-232a [P0] — JWKS endpoint returns valid JSON with at least one RSA signing key (AC2)
# Verifies that the JWKS endpoint responds with HTTP 200 and a JSON body
# containing at least one key entry with a `kid` field.
# The `kid` field is required so that token verifiers can locate the correct
# signing key when Keycloak rotates keys.
# ---------------------------------------------------------------------------
@test "[P0][TS-232a] JWKS endpoint returns HTTP 200 with JSON containing at least one key with kid" {

  local jwks_url="${KC_DIRECT_URL}/realms/envocc/protocol/openid-connect/certs"

  local http_status
  http_status=$(curl -k -s --max-time 15 \
    "${jwks_url}" \
    -o /tmp/jwks-response-$$.json \
    -w "%{http_code}" \
    2>/dev/null)

  if [[ "${http_status}" != "200" ]]; then
    fail "JWKS endpoint ${jwks_url} returned HTTP ${http_status} — expected 200. Is Keycloak running?"
  fi

  run python3 - /tmp/jwks-response-$$.json <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    try:
        jwks = json.load(f)
    except json.JSONDecodeError as e:
        print(f"FAIL: JWKS response is not valid JSON: {e}", file=sys.stderr)
        sys.exit(1)

keys = jwks.get('keys', [])
if not keys:
    print("FAIL: JWKS response contains no keys (empty 'keys' array)", file=sys.stderr)
    sys.exit(1)

# Assert at least one key has a 'kid' field
keys_with_kid = [k for k in keys if k.get('kid')]
if not keys_with_kid:
    print(
        f"FAIL: None of the {len(keys)} JWKS key(s) have a 'kid' field. "
        "Token verifiers require 'kid' to locate the correct signing key.",
        file=sys.stderr,
    )
    sys.exit(1)

kids = [k['kid'] for k in keys_with_kid]
print(f"PASS: JWKS contains {len(keys)} key(s); {len(keys_with_kid)} with kid: {kids}")
sys.exit(0)
PYEOF

  assert_success
}

# ---------------------------------------------------------------------------
# TS-232b [P0] — JWKS signing key has kty=RSA and use=sig (AC2)
# Verifies that at least one key in the JWKS has the correct type and usage:
#   kty = "RSA"  — key type (asymmetric RSA key pair)
#   use = "sig"  — key usage (signature verification, not encryption)
# These are required by the OIDC specification for ID token verification.
# ---------------------------------------------------------------------------
@test "[P0][TS-232b] JWKS endpoint contains at least one key with kty=RSA and use=sig" {

  local jwks_url="${KC_DIRECT_URL}/realms/envocc/protocol/openid-connect/certs"

  local http_status
  http_status=$(curl -k -s --max-time 15 \
    "${jwks_url}" \
    -o /tmp/jwks-response-$$.json \
    -w "%{http_code}" \
    2>/dev/null)

  if [[ "${http_status}" != "200" ]]; then
    fail "JWKS endpoint ${jwks_url} returned HTTP ${http_status} — expected 200. Is Keycloak running?"
  fi

  run python3 - /tmp/jwks-response-$$.json <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    try:
        jwks = json.load(f)
    except json.JSONDecodeError as e:
        print(f"FAIL: JWKS response is not valid JSON: {e}", file=sys.stderr)
        sys.exit(1)

keys = jwks.get('keys', [])
if not keys:
    print("FAIL: JWKS has no keys", file=sys.stderr)
    sys.exit(1)

# Find keys with kty=RSA and use=sig
rsa_sig_keys = [k for k in keys if k.get('kty') == 'RSA' and k.get('use') == 'sig']

failures = []

if not rsa_sig_keys:
    # Diagnose: list what we have
    for i, k in enumerate(keys):
        kty = k.get('kty', 'MISSING')
        use = k.get('use', 'MISSING')
        kid = k.get('kid', 'MISSING')
        failures.append(f"  key[{i}]: kty={kty!r}, use={use!r}, kid={kid!r}")
    print(
        "FAIL: No JWKS key with kty='RSA' and use='sig' found. Found keys:",
        file=sys.stderr,
    )
    for f in failures:
        print(f, file=sys.stderr)
    print(
        "Ensure realm-export.json has an RSA key provider component "
        "with active=true and enabled=true.",
        file=sys.stderr,
    )
    sys.exit(1)

# Assert kid is present on all RSA sig keys
for k in rsa_sig_keys:
    if not k.get('kid'):
        print(
            f"FAIL: RSA signing key (n={k.get('n','?')[:16]}...) is missing 'kid' field",
            file=sys.stderr,
        )
        sys.exit(1)

kids = [k['kid'] for k in rsa_sig_keys]
print(f"PASS: {len(rsa_sig_keys)} RSA signing key(s) found with kty=RSA, use=sig, kid(s): {kids}")
sys.exit(0)
PYEOF

  assert_success
}

# ---------------------------------------------------------------------------
# TS-234a [P1] — OIDC discovery document present with required fields (AC4)
# Verifies that the standard OIDC Provider Metadata document is served at the
# well-known endpoint and contains all required fields per OpenID Connect
# Discovery 1.0. These fields allow relying parties to self-configure without
# hard-coded endpoint URLs.
#
# Required fields (per story AC4 and FR11):
#   issuer, authorization_endpoint, token_endpoint, jwks_uri,
#   userinfo_endpoint, response_types_supported,
#   subject_types_supported, id_token_signing_alg_values_supported
# ---------------------------------------------------------------------------
@test "[P1][TS-234a] OIDC discovery document contains all required provider metadata fields" {

  local discovery_url="${KC_DIRECT_URL}/realms/envocc/.well-known/openid-configuration"

  local http_status
  http_status=$(curl -k -s --max-time 15 \
    "${discovery_url}" \
    -o /tmp/discovery-response-$$.json \
    -w "%{http_code}" \
    2>/dev/null)

  if [[ "${http_status}" != "200" ]]; then
    fail "Discovery endpoint ${discovery_url} returned HTTP ${http_status} — expected 200"
  fi

  run python3 - /tmp/discovery-response-$$.json <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    try:
        doc = json.load(f)
    except json.JSONDecodeError as e:
        print(f"FAIL: Discovery document is not valid JSON: {e}", file=sys.stderr)
        sys.exit(1)

# Required fields per OIDC Discovery 1.0 / AC4 / FR11
required_fields = [
    'issuer',
    'authorization_endpoint',
    'token_endpoint',
    'jwks_uri',
    'userinfo_endpoint',
    'response_types_supported',
    'subject_types_supported',
    'id_token_signing_alg_values_supported',
]

missing = [f for f in required_fields if f not in doc]

if missing:
    print(
        f"FAIL: OIDC discovery document is missing required fields: {missing}",
        file=sys.stderr,
    )
    print("Present fields:", sorted(doc.keys()), file=sys.stderr)
    sys.exit(1)

# Assert issuer references the envocc realm
issuer = doc.get('issuer', '')
if 'envocc' not in issuer:
    print(f"FAIL: Discovery issuer must reference envocc realm, got: {issuer!r}", file=sys.stderr)
    sys.exit(1)

# Assert RS256 in supported signing algorithms
alg_values = doc.get('id_token_signing_alg_values_supported', [])
if 'RS256' not in alg_values:
    print(
        f"FAIL: RS256 not in id_token_signing_alg_values_supported: {alg_values}",
        file=sys.stderr,
    )
    sys.exit(1)

print(
    f"PASS: Discovery document valid. "
    f"issuer={issuer}, "
    f"alg_values={alg_values}, "
    f"all {len(required_fields)} required fields present"
)
sys.exit(0)
PYEOF

  assert_success
  rm -f /tmp/discovery-response-$$.json
}

# ---------------------------------------------------------------------------
# TS-236a [P0] — alg:none JWT rejected at userinfo endpoint with HTTP 401 (AC6)
# Constructs a minimal forged JWT with "alg":"none" and a fabricated envocc
# payload. Presents it to the Keycloak userinfo endpoint. Keycloak must reject
# this with HTTP 401 — it should never accept unsigned tokens.
#
# This is a defense-in-depth regression guard. Keycloak rejects alg:none by
# default, but the test confirms this remains true after any realm reconfiguration.
# ---------------------------------------------------------------------------
@test "[P0][TS-236a] alg:none JWT presented to userinfo endpoint is rejected with HTTP 401" {

  # Build forged JWT: header {"alg":"none","typ":"JWT"}
  local forged_header
  forged_header=$(python3 -c "
import base64, json
header = {'alg': 'none', 'typ': 'JWT'}
encoded = base64.urlsafe_b64encode(json.dumps(header, separators=(',',':')).encode()).decode().rstrip('=')
print(encoded, end='')
")

  # Build forged payload with envocc issuer and far-future expiry
  local forged_payload
  forged_payload=$(python3 -c "
import base64, json, time
payload = {
    'sub': 'attacker-fabricated-sub',
    'iss': '${KC_DIRECT_URL}/realms/envocc',
    'aud': 'envocc-test-client',
    'exp': int(time.time()) + 3600,
    'iat': int(time.time()),
    'email': 'attacker@evil.example.com',
}
encoded = base64.urlsafe_b64encode(json.dumps(payload, separators=(',',':')).encode()).decode().rstrip('=')
print(encoded, end='')
")

  # alg:none JWT has an empty signature part
  local alg_none_token="${forged_header}.${forged_payload}."

  # Present the forged token to the userinfo endpoint — must be rejected with 401
  local http_status
  http_status=$(curl -k -s --max-time 10 \
    -H "Authorization: Bearer ${alg_none_token}" \
    "${KC_DIRECT_URL}/realms/envocc/protocol/openid-connect/userinfo" \
    -o /dev/null \
    -w "%{http_code}" \
    2>/dev/null)

  if [[ "${http_status}" != "401" ]]; then
    fail "Expected HTTP 401 for alg:none token at userinfo endpoint, got: ${http_status}. Keycloak must reject unsigned JWTs."
  fi
}

# ---------------------------------------------------------------------------
# TS-238a [P1] — JWKS endpoint Cache-Control header preserved through Nginx edge (AC8)
# Verifies that the Nginx edge does not strip or override Keycloak's
# Cache-Control header on the JWKS endpoint. Clients must receive Keycloak's
# caching directive so they can cache public keys and reduce JWKS refetch load.
#
# Story 1.3 nginx.conf already preserves Cache-Control on /realms/ paths —
# this test is a regression guard to ensure that behavior is not accidentally
# removed by future Nginx configuration changes.
#
# Uses NGINX_BASE_URL (https://localhost) because it tests the full edge path.
# ---------------------------------------------------------------------------
@test "[P1][TS-238a] JWKS endpoint Cache-Control header is present and non-empty through Nginx edge" {

  local jwks_url="${NGINX_BASE_URL}/realms/envocc/protocol/openid-connect/certs"

  # Fetch headers only (-I) through the Nginx edge
  local cache_control_header
  cache_control_header=$(curl -k -sI --max-time 15 \
    "${jwks_url}" \
    2>/dev/null \
    | grep -i "^cache-control:" \
    | head -1 \
    | tr -d '\r')

  if [[ -z "${cache_control_header}" ]]; then
    fail "No Cache-Control header on JWKS endpoint ${jwks_url} — Nginx may be stripping Keycloak's Cache-Control header. Check nginx.conf: no cache-control add_header on /realms/ location."
  fi

  # The header must not be empty or 'no-store' only — Keycloak typically sends
  # 'no-cache' or a max-age directive to allow key caching per RFC 7517.
  local cache_value
  cache_value="${cache_control_header#*: }"
  echo "Cache-Control: ${cache_value}"
}

# ---------------------------------------------------------------------------
# TS-238b [P1] — Discovery endpoint Cache-Control header preserved through Nginx edge (AC8)
# Same regression guard as TS-238a, but for the OIDC discovery endpoint.
# Clients that bootstrap from `.well-known/openid-configuration` should be able
# to cache the discovery document per Keycloak's directives.
# ---------------------------------------------------------------------------
@test "[P1][TS-238b] Discovery endpoint Cache-Control header is present and non-empty through Nginx edge" {

  local discovery_url="${NGINX_BASE_URL}/realms/envocc/.well-known/openid-configuration"

  local cache_control_header
  cache_control_header=$(curl -k -sI --max-time 15 \
    "${discovery_url}" \
    2>/dev/null \
    | grep -i "^cache-control:" \
    | head -1 \
    | tr -d '\r')

  if [[ -z "${cache_control_header}" ]]; then
    fail "No Cache-Control header on discovery endpoint ${discovery_url} — Nginx may be stripping Keycloak's Cache-Control header. Check nginx.conf /realms/ location block."
  fi

  local cache_value
  cache_value="${cache_control_header#*: }"
  echo "Cache-Control: ${cache_value}"
}
