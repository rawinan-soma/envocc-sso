#!/usr/bin/env bats
# tests/unit/nginx-config.bats
# ATDD tests — Story 1.3: Nginx security edge (static config / compose.yaml assertions)
#
# AC5: Stack boots with Nginx included
# AC6: Secret hygiene maintained (nginx certs git-ignored)
#
# Additional config validation (non-runtime, testable without a live stack):
#   - nginx/nginx.conf exists and contains required directives
#   - compose.yaml includes nginx service with correct healthcheck
#   - compose.yaml nginx image is version-pinned with @sha256: digest (no :latest)
#   - Keycloak port 8080 is NOT published to host after Story 1.3
#   - KC_PROXY_HEADERS: xforwarded is set in Keycloak service env
#   - nginx/certs/*.key and *.crt are git-ignored
#   - nginx/certs/.gitkeep is tracked
#
# Test scenarios covered:
#   TS-136a [P0] nginx/certs/*.key is covered by .gitignore
#   TS-136b [P0] nginx/certs/*.crt is covered by .gitignore
#   TS-136c [P0] nginx/certs/.gitkeep exists and is tracked by git
#   TS-137a [P1] compose.yaml nginx service image has no ':latest' tag
#   TS-137b [P1] compose.yaml nginx service image has @sha256: digest
#   TS-137c [P1] nginx/nginx.conf exists and references TLS cert paths
#   TS-137d [P1] nginx/nginx.conf sets ssl_protocols TLSv1.2 TLSv1.3 (TLS 1.0/1.1 disabled)
#   TS-137e [P1] nginx/nginx.conf adds Strict-Transport-Security header with always
#   TS-137f [P1] nginx/nginx.conf adds X-Frame-Options: DENY header
#   TS-137g [P1] nginx/nginx.conf adds X-Content-Type-Options: nosniff header
#   TS-137h [P1] nginx/nginx.conf defines limit_req_zone for login rate-limiting
#   TS-137i [P1] nginx/nginx.conf sets limit_req_status 429
#   TS-137j [P1] nginx/nginx.conf adds Content-Security-Policy: frame-ancestors on auth locations
#   TS-138a [P1] compose.yaml Keycloak service does NOT publish port 8080 to host
#   TS-138b [P1] compose.yaml Keycloak service has KC_PROXY_HEADERS: xforwarded
#   TS-138c [P1] compose.yaml nginx service has a healthcheck defined
#   TS-138d [P1] compose.yaml nginx service depends_on keycloak with service_healthy
#
# TDD Phase: GREEN — skip directives removed after Story 1.3 implementation.

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# TS-136a/b [P0] — nginx/certs key material git-ignored
# ---------------------------------------------------------------------------
@test "[P0][TS-136a] .gitignore covers 'nginx/certs/*.key' (private key files git-ignored)" {
  assert [ -f "${PROJECT_ROOT}/.gitignore" ]

  # The .gitignore must contain a rule covering nginx private key files
  # Acceptable patterns: nginx/certs/*.key, nginx/certs/*.pem, etc.
  run grep -E "nginx/certs/.*\.key|nginx/certs/\*\.pem" "${PROJECT_ROOT}/.gitignore"
  assert_success
}

@test "[P0][TS-136b] .gitignore covers 'nginx/certs/*.crt' (certificate files git-ignored)" {
  assert [ -f "${PROJECT_ROOT}/.gitignore" ]

  # The .gitignore must contain a rule covering nginx cert files
  # Acceptable patterns: nginx/certs/*.crt, nginx/certs/*.pem, etc.
  run grep -E "nginx/certs/.*\.crt|nginx/certs/\*\.pem" "${PROJECT_ROOT}/.gitignore"
  assert_success
}

@test "[P0][TS-136a-runtime] git does not track any file under nginx/certs/ with .key or .crt extension" {
  # Real key material must never be tracked
  run git -C "${PROJECT_ROOT}" ls-files "nginx/certs/*.key" "nginx/certs/*.crt" "nginx/certs/*.pem"
  assert_output ""
}

# ---------------------------------------------------------------------------
# TS-136c [P0] — nginx/certs/.gitkeep tracks the empty directory
# ---------------------------------------------------------------------------
@test "[P0][TS-136c] nginx/certs/.gitkeep is tracked by git (directory placeholder)" {
  assert [ -f "${PROJECT_ROOT}/nginx/certs/.gitkeep" ]

  # The .gitkeep must be tracked (not ignored)
  run git -C "${PROJECT_ROOT}" ls-files "nginx/certs/.gitkeep"
  assert_output "nginx/certs/.gitkeep"
}

# ---------------------------------------------------------------------------
# TS-137a [P1] — compose.yaml nginx image has no ':latest'
# ---------------------------------------------------------------------------
@test "[P1][TS-137a] compose.yaml nginx service image does not use ':latest' tag" {
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  # compose.yaml must not contain ':latest' at all (for any service)
  # This complements TS-103a from version-pinning.bats (which covers postgres/keycloak)
  run grep -n ":latest" "${PROJECT_ROOT}/compose.yaml"
  assert_failure
}

# ---------------------------------------------------------------------------
# TS-137b [P1] — compose.yaml nginx image pinned by @sha256: digest
# ---------------------------------------------------------------------------
@test "[P1][TS-137b] compose.yaml nginx service image includes @sha256: digest" {
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  # The nginx image line must contain @sha256: followed by a 64-char hex digest
  run grep -E "nginx.*@sha256:[a-f0-9]{64}" "${PROJECT_ROOT}/compose.yaml"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-137c [P1] — nginx/nginx.conf exists and references TLS cert paths
# ---------------------------------------------------------------------------
@test "[P1][TS-137c] nginx/nginx.conf exists at repo root" {
  assert [ -f "${PROJECT_ROOT}/nginx/nginx.conf" ]
}

@test "[P1][TS-137c] nginx/nginx.conf references self-signed cert paths /etc/nginx/certs/dev.crt and dev.key" {
  assert [ -f "${PROJECT_ROOT}/nginx/nginx.conf" ]

  run grep -E "ssl_certificate[^_]" "${PROJECT_ROOT}/nginx/nginx.conf"
  assert_success

  run grep "dev.crt" "${PROJECT_ROOT}/nginx/nginx.conf"
  assert_success

  run grep "dev.key" "${PROJECT_ROOT}/nginx/nginx.conf"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-137d [P1] — nginx/nginx.conf sets ssl_protocols (TLS 1.0/1.1 disabled)
# ---------------------------------------------------------------------------
@test "[P1][TS-137d] nginx/nginx.conf sets ssl_protocols TLSv1.2 TLSv1.3 (TLS 1.0/1.1 absent)" {
  assert [ -f "${PROJECT_ROOT}/nginx/nginx.conf" ]

  # ssl_protocols must only allow TLSv1.2 and TLSv1.3
  run grep "ssl_protocols" "${PROJECT_ROOT}/nginx/nginx.conf"
  assert_success
  assert_output --regexp "TLSv1\.2"
  assert_output --regexp "TLSv1\.3"

  # TLSv1.0 and TLSv1.1 must NOT appear in ssl_protocols line
  run bash -c "grep 'ssl_protocols' '${PROJECT_ROOT}/nginx/nginx.conf' | grep -E 'TLSv1\.0|TLSv1\.1'"
  assert_failure
}

# ---------------------------------------------------------------------------
# TS-137e [P1] — nginx/nginx.conf includes HSTS header directive
# ---------------------------------------------------------------------------
@test "[P1][TS-137e] nginx/nginx.conf adds Strict-Transport-Security header with 'always'" {
  assert [ -f "${PROJECT_ROOT}/nginx/nginx.conf" ]

  # HSTS must be in nginx.conf with the correct value and 'always' parameter
  run grep -E "add_header.*Strict-Transport-Security.*max-age=31536000.*always" "${PROJECT_ROOT}/nginx/nginx.conf"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-137f [P1] — nginx/nginx.conf includes X-Frame-Options: DENY
# ---------------------------------------------------------------------------
@test "[P1][TS-137f] nginx/nginx.conf adds X-Frame-Options: DENY header" {
  assert [ -f "${PROJECT_ROOT}/nginx/nginx.conf" ]

  run grep -E "add_header.*X-Frame-Options.*DENY" "${PROJECT_ROOT}/nginx/nginx.conf"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-137g [P1] — nginx/nginx.conf includes X-Content-Type-Options: nosniff
# ---------------------------------------------------------------------------
@test "[P1][TS-137g] nginx/nginx.conf adds X-Content-Type-Options: nosniff header" {
  assert [ -f "${PROJECT_ROOT}/nginx/nginx.conf" ]

  run grep -E "add_header.*X-Content-Type-Options.*nosniff" "${PROJECT_ROOT}/nginx/nginx.conf"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-137h [P1] — nginx/nginx.conf defines limit_req_zone for rate-limiting
# ---------------------------------------------------------------------------
@test "[P1][TS-137h] nginx/nginx.conf defines limit_req_zone for login rate-limiting" {
  assert [ -f "${PROJECT_ROOT}/nginx/nginx.conf" ]

  # limit_req_zone declaration must be present
  run grep "limit_req_zone" "${PROJECT_ROOT}/nginx/nginx.conf"
  assert_success
}

@test "[P1][TS-137h] nginx/nginx.conf applies limit_req directive to auth locations" {
  assert [ -f "${PROJECT_ROOT}/nginx/nginx.conf" ]

  # limit_req usage (not just declaration) must be present in a location block.
  # grep exits 0 when it finds a match, 1 when not — assert_success directly validates this.
  run grep "limit_req zone=" "${PROJECT_ROOT}/nginx/nginx.conf"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-137i [P1] — nginx/nginx.conf sets limit_req_status 429
# ---------------------------------------------------------------------------
@test "[P1][TS-137i] nginx/nginx.conf sets limit_req_status 429 (not default 503)" {
  assert [ -f "${PROJECT_ROOT}/nginx/nginx.conf" ]

  run grep "limit_req_status 429" "${PROJECT_ROOT}/nginx/nginx.conf"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-137j [P1] — nginx/nginx.conf sets CSP frame-ancestors on auth locations
# ---------------------------------------------------------------------------
@test "[P1][TS-137j] nginx/nginx.conf sets Content-Security-Policy frame-ancestors 'none' on auth location" {
  assert [ -f "${PROJECT_ROOT}/nginx/nginx.conf" ]

  # CSP with frame-ancestors 'none' must appear in nginx.conf (in a location block)
  run grep -E "Content-Security-Policy.*frame-ancestors" "${PROJECT_ROOT}/nginx/nginx.conf"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-138a [P1] — compose.yaml Keycloak does NOT publish port 8080 to host
# ---------------------------------------------------------------------------
@test "[P1][TS-138a] compose.yaml Keycloak service does NOT publish port 8080 to host" {
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  # After Story 1.3, Keycloak's port 8080 must NOT be published to the host.
  # External traffic routes through Nginx:443 only.
  # A published port appears as "8080:8080" or "- 8080:8080" in the keycloak service's ports block.
  #
  # Parse compose config to check keycloak published ports:
  run bash -c "docker compose -f '${PROJECT_ROOT}/compose.yaml' config 2>/dev/null \
    | python3 -c \"
import sys, yaml
cfg = yaml.safe_load(sys.stdin)
svc = cfg.get('services', {}).get('keycloak', {})
ports = svc.get('ports', [])
published = [str(p) for p in ports if '8080' in str(p)]
print(len(published))
\""
  # Keycloak must have zero published ports containing '8080'
  assert_output "0"
}

# ---------------------------------------------------------------------------
# TS-138b [P1] — compose.yaml Keycloak has KC_PROXY_HEADERS: xforwarded
# ---------------------------------------------------------------------------
@test "[P1][TS-138b] compose.yaml Keycloak service has KC_PROXY_HEADERS set to xforwarded" {
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  # KC_PROXY_HEADERS must be set so Keycloak trusts X-Forwarded-* headers from Nginx
  run bash -c "docker compose -f '${PROJECT_ROOT}/compose.yaml' config 2>/dev/null \
    | python3 -c \"
import sys, yaml
cfg = yaml.safe_load(sys.stdin)
svc = cfg.get('services', {}).get('keycloak', {})
env = svc.get('environment', {})
val = env.get('KC_PROXY_HEADERS', '')
print(val)
\""
  assert_output "xforwarded"
}

# ---------------------------------------------------------------------------
# TS-138c [P1] — compose.yaml nginx service has a healthcheck
# ---------------------------------------------------------------------------
@test "[P1][TS-138c] compose.yaml nginx service defines a healthcheck" {
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  # Nginx service must have a healthcheck block (for depends_on: service_healthy in future services)
  run bash -c "docker compose -f '${PROJECT_ROOT}/compose.yaml' config 2>/dev/null \
    | python3 -c \"
import sys, yaml
cfg = yaml.safe_load(sys.stdin)
svc = cfg.get('services', {}).get('nginx', {})
hc = svc.get('healthcheck', {})
test_cmd = hc.get('test', [])
print('defined' if test_cmd else 'missing')
\""
  assert_output "defined"
}

# ---------------------------------------------------------------------------
# TS-138d [P1] — compose.yaml nginx depends_on keycloak with service_healthy
# ---------------------------------------------------------------------------
@test "[P1][TS-138d] compose.yaml nginx service depends_on keycloak with condition: service_healthy" {
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  # Nginx must wait for Keycloak to be fully healthy before starting
  run bash -c "docker compose -f '${PROJECT_ROOT}/compose.yaml' config 2>/dev/null \
    | python3 -c \"
import sys, yaml
cfg = yaml.safe_load(sys.stdin)
svc = cfg.get('services', {}).get('nginx', {})
deps = svc.get('depends_on', {})
kc = deps.get('keycloak', {}) if isinstance(deps, dict) else {}
cond = kc.get('condition', '')
print(cond)
\""
  assert_output "service_healthy"
}
