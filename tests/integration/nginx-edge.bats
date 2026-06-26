#!/usr/bin/env bats
# tests/integration/nginx-edge.bats
# ATDD tests — Story 1.3: Nginx security edge
#
# AC1: TLS termination with HSTS and standard security headers
# AC2: CSP `frame-ancestors 'none'` on auth surfaces
# AC3: Edge rate-limiting / abuse controls on public unauthenticated endpoints
# AC4: JWKS and discovery endpoints cacheable through the edge
# AC5: Stack boots with Nginx included; all three services healthy
#
# Test scenarios covered:
#   TS-135a [P0] docker compose up — all three services reach healthy (postgres, keycloak, nginx)
#   TS-135b [P0] Keycloak is reachable through Nginx proxy (not on port 8080 directly)
#   TS-131a [P0] HTTPS response carries HSTS header with correct value
#   TS-131b [P0] HTTPS response carries all standard security headers (X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy)
#   TS-132a [P0] Auth surface responses carry CSP frame-ancestors 'none'
#   TS-133a [P1] Rate-limiting throttles excessive requests to login endpoints with HTTP 429
#   TS-133b [P1] limit_req_status 429 is set (throttled requests return 429 not 503)
#   TS-134a [P1] JWKS endpoint response preserves Cache-Control header from Keycloak
#   TS-134b [P1] Discovery endpoint response preserves Cache-Control header from Keycloak
#
# TDD Phase: RED — all tests marked `skip`.
# Remove `skip` for each test when the corresponding task is implemented.
#
# NOTE: Integration tests require a running stack with nginx service.
# Prerequisites: docker compose up --build -d (after nginx/nginx.conf and compose.yaml updated)
# Run manually: bats tests/integration/nginx-edge.bats

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Suite setup: handled by tests/integration/setup_suite.bash (BATS 1.5+ companion).
# Per-test setup/teardown: no-ops for infra tests.
# ---------------------------------------------------------------------------

setup() {
  : # per-test setup (noop for infra tests)
}

teardown() {
  : # per-test teardown
}

# ---------------------------------------------------------------------------
# TS-135a [P0] — Stack boots with nginx: all three services reach healthy
# ---------------------------------------------------------------------------
@test "[P0][TS-135a] docker compose up -- postgres reaches healthy within 60 s (nginx stack)" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  assert [ -f "${PROJECT_ROOT}/.env" ]

  run compose_up
  assert_success

  run wait_for_healthy "postgres" 60
  assert_success
}

@test "[P0][TS-135a] docker compose up -- keycloak reaches healthy within 120 s (nginx stack)" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run compose_up
  assert_success

  run wait_for_healthy "keycloak" 120
  assert_success
}

@test "[P0][TS-135a] docker compose up -- nginx reaches healthy within 30 s" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run compose_up
  assert_success

  # Nginx depends_on keycloak: service_healthy; once keycloak is healthy, nginx starts quickly
  run wait_for_healthy "nginx" 30
  assert_success
}

# ---------------------------------------------------------------------------
# TS-135b [P0] — Keycloak is reachable through Nginx proxy on HTTPS:443
# ---------------------------------------------------------------------------
@test "[P0][TS-135b] Keycloak is reachable through Nginx on HTTPS port 443" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  # When we request Keycloak's root through Nginx on port 443 (TLS-terminated)
  run bash -c "curl -k -s -o /dev/null -w '%{http_code}' --max-time 15 https://localhost/"
  # Then we get a redirect (3xx) or 200 — not a connection error (000) or 502 Bad Gateway
  assert_output --regexp "^[23][0-9][0-9]$"
}

@test "[P0][TS-135b] HTTP port 80 redirects to HTTPS (301 Moved Permanently)" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  # When we request over plain HTTP
  run bash -c "curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://localhost/"
  # Then we get a 301 redirect to HTTPS — not a 200 (would mean TLS not enforced)
  assert_output "301"
}

# ---------------------------------------------------------------------------
# TS-131a [P0] — HSTS header with correct value on HTTPS responses
# ---------------------------------------------------------------------------
@test "[P0][TS-131a] HTTPS response carries Strict-Transport-Security: max-age=31536000; includeSubDomains" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  # Given any HTTPS request through the edge
  run bash -c "curl -k -s -I --max-time 15 https://localhost/ 2>&1"
  assert_success

  # Then the Strict-Transport-Security header is present with the correct value
  assert_output --regexp "Strict-Transport-Security:.*max-age=31536000.*includeSubDomains"
}

# ---------------------------------------------------------------------------
# TS-131b [P0] — Standard security headers on all HTTPS responses
# ---------------------------------------------------------------------------
@test "[P0][TS-131b] HTTPS response carries X-Frame-Options: DENY" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  run bash -c "curl -k -s -I --max-time 15 https://localhost/ 2>&1"
  assert_success
  assert_output --regexp "X-Frame-Options: DENY"
}

@test "[P0][TS-131b] HTTPS response carries X-Content-Type-Options: nosniff" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  run bash -c "curl -k -s -I --max-time 15 https://localhost/ 2>&1"
  assert_success
  assert_output --regexp "X-Content-Type-Options: nosniff"
}

@test "[P0][TS-131b] HTTPS response carries Referrer-Policy: strict-origin-when-cross-origin" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  run bash -c "curl -k -s -I --max-time 15 https://localhost/ 2>&1"
  assert_success
  assert_output --regexp "Referrer-Policy: strict-origin-when-cross-origin"
}

@test "[P0][TS-131b] HTTPS response carries Permissions-Policy header" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  run bash -c "curl -k -s -I --max-time 15 https://localhost/ 2>&1"
  assert_success
  # Permissions-Policy disables geolocation, camera, microphone
  assert_output --regexp "Permissions-Policy:.*geolocation"
}

# ---------------------------------------------------------------------------
# TS-132a [P0] — CSP frame-ancestors 'none' on auth surfaces
# ---------------------------------------------------------------------------
@test "[P0][TS-132a] /realms/ path returns Content-Security-Policy: frame-ancestors 'none'" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  # Given an auth surface request (Keycloak realms path)
  run bash -c "curl -k -s -I --max-time 15 https://localhost/realms/ 2>&1"
  assert_success

  # Then CSP with frame-ancestors 'none' is present (anti-phishing control NFR4/FR12)
  assert_output --regexp "Content-Security-Policy:.*frame-ancestors 'none'"
}

@test "[P0][TS-132a] /auth/ path returns Content-Security-Policy: frame-ancestors 'none'" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  run bash -c "curl -k -s -I --max-time 15 https://localhost/auth/ 2>&1"
  # Note: 404 from Keycloak is acceptable — we only care about the response headers from nginx
  # The CSP header must be present regardless of upstream response code
  assert_output --regexp "Content-Security-Policy:.*frame-ancestors 'none'"
}

# ---------------------------------------------------------------------------
# TS-133a [P1] — Rate-limiting returns 429 after burst threshold
# ---------------------------------------------------------------------------
@test "[P1][TS-133a] Burst requests to login endpoint trigger HTTP 429 Too Many Requests" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  # Given the token endpoint receives more requests than the rate limit allows
  # When we fire 30 rapid requests (exceeds 10r/m limit with burst=20)
  run bash -c "
    status_codes=()
    for i in \$(seq 1 30); do
      code=\$(curl -k -s -o /dev/null -w '%{http_code}' --max-time 5 \
        -X POST https://localhost/realms/master/protocol/openid-connect/token 2>/dev/null || echo '000')
      status_codes+=(\"\${code}\")
    done
    # Then at least one 429 response is seen (rate limit triggered)
    printf '%s\n' \"\${status_codes[@]}\" | grep -q '429' && echo 'RATE_LIMITED' || echo 'NOT_RATE_LIMITED'
  "
  assert_output "RATE_LIMITED"
}

@test "[P1][TS-133b] Rate-limited requests return 429 not 503 (limit_req_status 429 set)" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  # Flood the rate-limited endpoint and assert 503 is NOT the throttle response
  run bash -c "
    saw_429=0
    saw_503=0
    for i in \$(seq 1 30); do
      code=\$(curl -k -s -o /dev/null -w '%{http_code}' --max-time 5 \
        -X POST https://localhost/realms/master/protocol/openid-connect/token 2>/dev/null || echo '000')
      [[ \"\${code}\" == '429' ]] && saw_429=1
      [[ \"\${code}\" == '503' ]] && saw_503=1
    done
    echo \"saw_429=\${saw_429} saw_503=\${saw_503}\"
  "
  # 429 should appear; 503 should NOT appear from rate-limiting (503 = upstream down, not throttle)
  assert_output --regexp "saw_429=1"
  refute_output --regexp "saw_503=1"
}

# ---------------------------------------------------------------------------
# TS-134a [P1] — JWKS endpoint Cache-Control header preserved by Nginx
# ---------------------------------------------------------------------------
@test "[P1][TS-134a] JWKS endpoint response carries Cache-Control header (not stripped by Nginx)" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  # When we request the JWKS endpoint through the Nginx edge
  run bash -c "curl -k -s -I --max-time 15 \
    https://localhost/realms/master/protocol/openid-connect/certs 2>&1"
  assert_success

  # Then Cache-Control header is present and not absent (Nginx did not strip it)
  # The actual value comes from Keycloak — we verify it exists, not its specific value
  assert_output --regexp "Cache-Control:"
}

@test "[P1][TS-134b] OIDC discovery endpoint response carries Cache-Control header (not stripped by Nginx)" {
  skip "Integration: requires running stack with nginx service — run manually after docker compose up --build"

  run wait_for_healthy "nginx" 30
  assert_success

  # When we request the OIDC well-known endpoint through Nginx
  run bash -c "curl -k -s -I --max-time 15 \
    https://localhost/realms/master/.well-known/openid-configuration 2>&1"
  assert_success

  # Then Cache-Control header is present (Nginx did not strip Keycloak's cache directives)
  assert_output --regexp "Cache-Control:"
}
