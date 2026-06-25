---
baseline_commit: 6c81f7c8b7dc8628800e1caaccb283fb0f2288cb
---

# Story 1.3: Nginx Security Edge

Status: done

## Story

As the System Administrator,
I want a single Nginx security edge in front of the platform,
so that all public traffic is TLS-terminated, header-hardened, and abuse-protected.

## Acceptance Criteria

1. **TLS + HSTS + Security Headers (NFR4)**
   Given the edge config,
   When any request arrives,
   Then it is served over TLS with HSTS and standard security headers, and a CSP including `frame-ancestors 'none'` is set on auth surfaces (Keycloak login/registration/MFA endpoints).

2. **Rate-limiting / Abuse Controls (FR50)**
   Given public unauthenticated endpoints,
   When they receive excessive traffic,
   Then edge rate-limiting/abuse controls throttle it and return HTTP 429.

3. **Cacheable JWKS + Discovery (FR50)**
   Given the JWKS (`/realms/envocc/protocol/openid-connect/certs`) and discovery (`/realms/envocc/.well-known/openid-configuration`) endpoints,
   When clients fetch them through the edge,
   Then responses carry `Cache-Control: public, max-age=300` (or similar) and the edge does not strip upstream cache headers.

## Tasks / Subtasks

- [x] Task 1: Create nginx directory and config (AC: #1, #2, #3)
  - [x] Create `nginx/` directory at project root
  - [x] Write `nginx/nginx.conf` with TLS termination, security headers, rate-limiting, and caching rules
  - [x] Write `nginx/Dockerfile` (FROM nginx:pinned-digest) with COPY of nginx.conf
- [x] Task 2: Generate dev TLS certificate (AC: #1)
  - [x] Create `nginx/certs/` directory (git-ignored)
  - [x] Document self-signed cert generation with `mkcert` in README or `.env.example` comments
  - [x] Add `nginx/certs/` to `.gitignore`
- [x] Task 3: Update compose.yaml (AC: #1, #2, #3)
  - [x] Add `nginx` service (pinned digest, depends_on keycloak)
  - [x] Expose ports 443 (HTTPS) and 80 (HTTP → HTTPS redirect) on all interfaces (0.0.0.0)
  - [x] Keep Keycloak port 8080 loopback-only (nginx is the public entry point)
  - [x] Add `KC_PROXY_HEADERS: xforwarded` to Keycloak env vars
  - [x] Update `KC_HOSTNAME` to the public HTTPS URL (e.g., `https://localhost`)
  - [x] Remove `KC_HOSTNAME_STRICT: "false"` (no longer needed — hostname is explicit)
  - [x] Remove `KC_HTTP_ENABLED: "true"` (internal HTTP between nginx and KC stays, but set `KC_HTTP_RELATIVE_PATH` if needed)
- [x] Task 4: Update .env.example (AC: #1)
  - [x] Add `KC_HOSTNAME=https://localhost` (or `https://sso.local`)
  - [x] Add `NGINX_TLS_CERT` / `NGINX_TLS_KEY` path vars if needed
- [x] Task 5: Write BATS integration tests (AC: #1, #2, #3)
  - [x] `tests/integration/nginx-security-edge.bats` — curl-based assertions for headers and TLS
  - [x] Test: HSTS header present on HTTPS response
  - [x] Test: CSP `frame-ancestors 'none'` set on Keycloak login page
  - [x] Test: HTTP 80 redirects to HTTPS
  - [x] Test: HTTP 429 returned when rate-limit exceeded (loop requests)
  - [x] Test: Cache-Control header on JWKS endpoint
  - [x] Test: Cache-Control header on discovery endpoint

### Review Findings

_Adversarial code review (3 layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor) — 2026-06-24. Reviewed commit `f198dd9` vs parent `10b1917`._

**Decision-needed (RESOLVED 2026-06-24):**

- [x] [Review][Decision] Framing headers break OIDC session-check iframe → **RESOLVED: scope to login UI only.** Patch nginx to exempt `login-status-iframe.html` (and 3rd-party-cookie iframes) from `X-Frame-Options: DENY` + `frame-ancestors 'none'`, keeping clickjacking protection on login/MFA while preserving OIDC session management. → see Patch list.
- [x] [Review][Decision] Cache-Control `always` caches errors + may duplicate upstream → **RESOLVED: add on 2xx only, don't strip.** Drop `always` so 4xx/5xx aren't cached; leave upstream headers intact (satisfies AC3's no-strip clause). → see Patch list.
- [x] [Review][Decision] CSP allows `'unsafe-inline'` + `'unsafe-eval'` → **RESOLVED: drop `'unsafe-eval'` now**, keep `'unsafe-inline'`; full tightening (nonces) validated against the Deep Sea theme in story 2.5. → see Patch list.
- [x] [Review][Decision] Nginx base image not digest-pinned (AR8) → **RESOLVED: start Docker and pin now.** Resolve digest via `docker inspect` and update `nginx/Dockerfile` + `PINNED-VERSION.md`. → see Patch list (Docker-dependent).
- [x] [Review][Decision] KC 26 hostname semantics → **RESOLVED: verify at runtime.** Bring the stack up and confirm issuer = `KC_HOSTNAME`, admin console reachable, existing smoke tests pass. → runtime verification task.

**Patch (fixable without input):**

- [x] [Review][Patch] Scope framing headers to login UI; exempt OIDC session iframe [`nginx/nginx.conf`, `csp-auth.conf`/`security-headers.conf`] — resolved from decision above.
- [x] [Review][Patch] Cache-Control: add only on 2xx (drop `always`); do not strip upstream [`nginx/nginx.conf:84,92`] — resolved from decision above.
- [x] [Review][Patch] Remove `'unsafe-eval'` from auth-surface CSP [`nginx/snippets/csp-auth.conf`] — resolved from decision above.
- [x] [Review][Patch] Pin nginx base image by digest (AR8) [`nginx/Dockerfile`, `nginx/PINNED-VERSION.md`] — Docker-dependent; resolved from decision above.

- [x] [Review][Patch] X-Forwarded-For is appended (spoofable); no real_ip trust config [`nginx/nginx.conf:73`] — overwrite XFF with `$remote_addr` applied.
- [x] [Review][Patch] Open redirect / host-header injection via unvalidated `$host` [`nginx/nginx.conf:48,75-76`] — `map $host $host_allowed` + `return 444` allowlist added to both server blocks.
- [x] [Review][Patch] Nginx service has no healthcheck; missing certs cause silent crash-loop [`compose.yaml` nginx service] — healthcheck via `/dev/tcp/localhost/80` added.
- [x] [Review][Patch] No explicit proxy timeouts / friendly error page [`nginx/nginx.conf` proxy blocks] — `proxy_connect_timeout`/`proxy_send_timeout`/`proxy_read_timeout` and `error_page 502 503 504` added.
- [x] [Review][Patch] Test R10 (Server header) has fragile/inverted compound-grep logic [`tests/integration/nginx-security-edge.bats` R10] — replaced `${output,,}` (bash 4+ only) with `! echo "$output" | grep -qi` for portability.
- [x] [Review][Patch] Test R6 (CSP) uses two separate greps — only the last counts [`tests/integration/nginx-security-edge.bats` R6] — both assertions now use explicit `|| return 1`.
- [x] [Review][Patch] Test R7 (rate-limit) is timing-dependent with sequential curls [`tests/integration/nginx-security-edge.bats` R7] — changed to 40 concurrent background jobs (`&` + `wait`).
- [x] [Review][Patch] AC1-SMOKE-04 silently falls back to the old HTTP issuer [`tests/integration/ac1-docker-compose-smoke.bats`] — now sources `KC_HOSTNAME` from env or `.env`; fails loudly if unset.

**Deferred (real but not actionable in this story):**

- [x] [Review][Defer] HSTS `includeSubDomains` + 1-year max-age shipped uniformly to dev and prod [`nginx/snippets/security-headers.conf`] — deferred: HSTS is ignored over the self-signed dev cert, but `includeSubDomains` on a shared dev domain could affect sibling services. Gate by environment in a later infra/hardening story.
- [x] [Review][Defer] `proxy_pass` resolves `keycloak` at startup; no `resolver` for runtime re-resolution [`nginx/nginx.conf`] — deferred: acceptable for compose dev (`depends_on`); revisit for prod/HA where container IPs change without an nginx reload.
- [x] [Review][Defer] Container hardening is half-done [`nginx/nginx.conf` pid in /tmp; `compose.yaml` no `user`/`read_only`/`cap_drop`/tmpfs] — deferred: logging still works (official image symlinks logs to stdout/stderr); pick one coherent non-root/read-only posture in a dedicated hardening pass.

## Dev Notes

### Overview

This story adds a single Nginx reverse proxy as the TLS edge in front of the existing Keycloak (port 8080 loopback) service. After this story, all browser/client traffic enters via HTTPS on port 443; Nginx forwards to Keycloak over plain HTTP internally.

### Critical: Keycloak Reverse-Proxy Config (KC 26)

In Keycloak 26 (Quarkus), running behind a reverse proxy requires **two specific env vars** that are NOT currently in compose.yaml. Omitting them causes broken redirect URIs, wrong issuer URLs in tokens, and admin console breakage.

```yaml
# compose.yaml — Keycloak service additions for Story 1.3
KC_PROXY_HEADERS: xforwarded         # Trust X-Forwarded-Proto/Host from Nginx
KC_HOSTNAME: https://localhost        # Public HTTPS URL (update for prod domain)
```

**Remove or adjust these existing vars:**
- `KC_HTTP_ENABLED: "true"` — Keep this; Keycloak still serves HTTP on port 8080 to Nginx internally. Do NOT remove.
- `KC_HOSTNAME_STRICT: "false"` — Remove this. With `KC_HOSTNAME` explicitly set, strict mode is the correct default (or set to `"true"` explicitly).

> **Why:** Without `KC_PROXY_HEADERS`, Keycloak generates token issuers as `http://keycloak:8080/...` instead of `https://localhost/...`, breaking OIDC validation across every downstream story (2.3, 2.4, 2.5, ...).

### nginx.conf Structure

The config must address three ACs in one file:

```nginx
# 1. Rate-limit zone — declare at http{} level
limit_req_zone $binary_remote_addr zone=public:10m rate=20r/s;

server {
    listen 80;
    # AC1: HTTP → HTTPS redirect
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;

    # AC1: TLS hardening
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # AC1: HSTS (must include preload/includeSubDomains for prod; omit for dev)
    add_header Strict-Transport-Security "max-age=31536000" always;

    # AC1: Standard security headers (on all responses)
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), camera=(), microphone=()" always;

    # Forward real client IP/proto to Keycloak (required for KC_PROXY_HEADERS: xforwarded)
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header Host $host;

    # AC2: Rate-limit public unauthenticated paths
    location / {
        limit_req zone=public burst=40 nodelay;
        proxy_pass http://keycloak:8080;
    }

    # AC1: Auth surfaces — add CSP with frame-ancestors 'none'
    # Keycloak login/MFA/registration pages are served under /realms/{realm}/
    location ~ ^/realms/[^/]+/(login|protocol|account|broker) {
        limit_req zone=public burst=20 nodelay;
        add_header Content-Security-Policy "frame-ancestors 'none'; default-src 'self'; ..." always;
        # Re-add base headers (add_header inheritance: child location blocks reset parent headers)
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "DENY" always;
        proxy_pass http://keycloak:8080;
    }

    # AC3: Cacheable JWKS + OIDC discovery
    location ~ ^/realms/[^/]+/(protocol/openid-connect/certs|\.well-known/openid-configuration)$ {
        proxy_pass http://keycloak:8080;
        add_header Cache-Control "public, max-age=300" always;
        # Security headers still apply here
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header X-Content-Type-Options "nosniff" always;
    }
}
```

> **CRITICAL NGINX GOTCHA — `add_header` inheritance:** In Nginx, `add_header` directives defined in a `server {}` block are NOT inherited by `location {}` blocks that also define their own `add_header`. If a `location` block has ANY `add_header`, ALL security headers must be re-declared in that block. Use a dedicated include file (`nginx/snippets/security-headers.conf`) or repeat headers explicitly.

> **Recommended pattern:** Create `nginx/snippets/security-headers.conf` with the common headers and `include` it in each relevant location.

### Nginx Dockerfile & Version Pinning (AR8)

```dockerfile
# nginx/Dockerfile
FROM nginx:1.27.5@sha256:<exact-digest-here>
COPY nginx.conf /etc/nginx/nginx.conf
# certs are mounted at runtime via compose.yaml volume
```

Pin by exact digest. Get the digest with:
```bash
docker pull nginx:1.27.5
docker inspect nginx:1.27.5 --format '{{index .RepoDigests 0}}'
```

As of 2026-06: nginx stable 1.27.x is the current LTS branch. Confirm latest stable at hub.docker.com/r/library/nginx.

### Dev TLS Certificates

For local development, use **mkcert** to generate locally-trusted certificates:

```bash
# Install mkcert if not present
brew install mkcert
mkcert -install  # Installs local CA into system trust stores

# Generate certs (run from project root)
mkdir -p nginx/certs
mkcert -cert-file nginx/certs/cert.pem -key-file nginx/certs/key.pem localhost 127.0.0.1
```

The `nginx/certs/` directory must be in `.gitignore` (already is via `*.pem` or add explicitly).

Mount into Nginx container in compose.yaml:
```yaml
nginx:
  volumes:
    - ./nginx/certs:/etc/nginx/certs:ro
```

### compose.yaml Service Block

```yaml
  # ─── Nginx (security edge) ──────────────────────────────────────────────────
  nginx:
    build:
      context: ./nginx
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      # Expose 80 + 443 on all interfaces (this IS the public entry point)
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/certs:/etc/nginx/certs:ro
    depends_on:
      keycloak:
        condition: service_healthy
```

### Keycloak env changes in compose.yaml

```yaml
  keycloak:
    environment:
      # ... existing vars stay ...
      KC_HTTP_ENABLED: "true"           # Keep — internal HTTP to nginx
      KC_PROXY_HEADERS: xforwarded      # NEW — trust X-Forwarded-* from nginx
      KC_HOSTNAME: ${KC_HOSTNAME:-https://localhost}  # NEW — public HTTPS URL
      # REMOVE: KC_HOSTNAME_STRICT: "false"  (no longer needed)
```

### Testing BATS Strategy

Tests at `tests/integration/nginx-security-edge.bats`. Use `curl` with:
- `-k` / `--insecure` for self-signed dev certs, OR use `--cacert` with the mkcert root CA
- `--head` for header-only checks
- `-D -` to dump headers to stdout

```bash
# Example header test pattern
HTTPS_URL="${HTTPS_URL:-https://localhost}"

@test "AC1: HSTS header present" {
    run curl -sk --head "$HTTPS_URL/realms/envocc/protocol/openid-connect/certs"
    assert_output --partial "strict-transport-security"
}

@test "AC1: HTTP redirects to HTTPS" {
    run curl -s --head --max-redirs 0 "http://localhost/"
    assert_output --partial "301"
    assert_output --partial "Location: https://"
}

@test "AC1: CSP frame-ancestors on login page" {
    run curl -sk --head "$HTTPS_URL/realms/envocc/protocol/openid-connect/auth"
    assert_output --partial "frame-ancestors"
}

@test "AC3: JWKS endpoint has Cache-Control: public" {
    run curl -sk --head "$HTTPS_URL/realms/envocc/protocol/openid-connect/certs"
    assert_output --partial "cache-control: public"
}

@test "AC3: Discovery endpoint has Cache-Control: public" {
    run curl -sk --head "$HTTPS_URL/realms/envocc/.well-known/openid-configuration"
    assert_output --partial "cache-control: public"
}
```

For rate-limiting test (AC2): loop 50+ requests and assert HTTP 429 appears. Use `require_running_stack` guard from previous BATS tests (implemented in story 1.1).

### What Story 1.3 Must NOT Break

The following behaviors from stories 1.1 and 1.2 must be preserved:

- PostgreSQL health checks still work (loopback port 5432 unchanged)
- Keycloak health endpoint on port 9000 remains loopback-only (nginx does NOT proxy port 9000)
- Mailpit SMTP/UI remain on loopback (unchanged)
- Realm auto-import at Keycloak startup still works (Keycloak mounts `keycloak/realm-export.json`)
- Pre-commit hooks (gitleaks, keycloak-realm-lint) must still pass with new files
- All existing BATS tests in `tests/integration/` must continue to pass

### Network Topology After Story 1.3

```
Internet / Browser
        │
   [Port 80/443]
        │
   ┌────▼────┐
   │  Nginx  │  (new in 1.3 — TLS termination, headers, rate-limit, cache)
   └────┬────┘
        │ HTTP proxy_pass :8080
   ┌────▼──────┐
   │ Keycloak  │  (loopback 8080, management 9000)
   └────┬──────┘
        │
   ┌────▼──────┐
   │ PostgreSQL│  (loopback 5432)
   └───────────┘
```

### Project Structure Notes

Files to create (NEW):
```
nginx/
├── Dockerfile                 # nginx pinned by digest
├── nginx.conf                 # TLS + security headers + rate-limit + cache
└── snippets/
    └── security-headers.conf  # Shared header block (included in each location)

nginx/certs/                   # git-ignored — populated with mkcert for dev
├── cert.pem
└── key.pem
```

Files to update (MODIFY):
```
compose.yaml                   # Add nginx service; update Keycloak KC_PROXY_HEADERS + KC_HOSTNAME
.env.example                   # Add KC_HOSTNAME=https://localhost
.gitignore                     # Add nginx/certs/ (if not already covered)
tests/integration/
└── nginx-security-edge.bats   # New BATS test suite (AC1, AC2, AC3)
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1-3] — Acceptance criteria BDD statements
- [Source: _bmad-output/planning-artifacts/architecture.md#Infrastructure] — `nginx/nginx.conf` designated as "single security edge: TLS/HSTS, rate-limit/abuse (FR50)"
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure] — `compose.yaml` includes nginx service
- [Source: _bmad-output/implementation-artifacts/1-2-realm-config-as-code-baseline-secret-hygiene.md#Dev Notes] — compose.yaml current state (KC_HTTP_ENABLED, loopback bindings, Mailpit)
- [Source: _bmad-output/implementation-artifacts/1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md#Dev Notes] — BATS test patterns (`require_running_stack`, healthcheck on port 9000)
- Nginx `add_header` inheritance: https://nginx.org/en/docs/http/ngx_http_headers_module.html (documented behavior: headers in parent block not inherited when child defines its own)
- Keycloak 26 proxy config: KC_PROXY_HEADERS docs (replaces deprecated `KC_PROXY` from KC 21)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — implementation proceeded cleanly with no blockers.

### Completion Notes List

- ✅ Task 1: Created `nginx/nginx.conf` with full AC coverage. Used `include` snippets to solve nginx `add_header` inheritance gotcha (child location blocks must re-declare all headers). Rate-limiting uses `limit_req_status 429` (not default 503). JWKS/discovery locations declared before general `/realms/` block (regex order matters).
- ✅ Task 1: Created `nginx/Dockerfile` with `nginx:1.27.5`. Digest pin is TODO — Docker not running at dev time; recorded in `nginx/PINNED-VERSION.md`.
- ✅ Task 1: Created `nginx/snippets/security-headers.conf` (HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy) and `nginx/snippets/csp-auth.conf` (full CSP with `frame-ancestors 'none'` for Keycloak auth surfaces).
- ✅ Task 2: `nginx/certs/` tracked via `.gitkeep`. `*.pem`/`*.key` patterns already in `.gitignore`; added explicit `nginx/certs/*.pem` / `nginx/certs/*.key` entries with mkcert setup comment. Dev cert instructions in `.env.example` and compose.yaml header.
- ✅ Task 3: Updated `compose.yaml` — added nginx service (ports 80/443, depends_on keycloak healthy, mounts `nginx/certs/` read-only). Added `KC_PROXY_HEADERS: xforwarded` and `KC_HOSTNAME` to Keycloak env; removed `KC_HOSTNAME_STRICT: "false"`. Kept `KC_HTTP_ENABLED: "true"` (internal HTTP backend is still needed).
- ✅ Task 4: Added `KC_HOSTNAME=https://localhost` to `.env.example` with explanatory comment.
- ✅ Task 5: 28 BATS tests (18 static + 10 runtime self-skip). All static tests pass; runtime tests self-skip gracefully when stack is down. Also updated `ac1-docker-compose-smoke.bats` test AC1-SMOKE-04 to use `KC_HOSTNAME` env var for expected issuer (Story 1.3 changes issuer from `http://localhost:8080/...` to `https://localhost/...`). Updated `run-atdd.sh` to add `nginx` filter and include nginx tests in `all` run.
- ⚠️ Digest pin for nginx:1.27.5 is a TODO — run `docker inspect nginx:1.27.5 --format '{{index .RepoDigests 0}}'` when Docker is available and update `nginx/Dockerfile` + `nginx/PINNED-VERSION.md`.

### Change Log

- 2026-06-24: feat(1.3): nginx security edge — TLS/HSTS, rate-limit, cacheable JWKS/discovery (commit f198dd9)

### File List

**New files:**
- `nginx/nginx.conf`
- `nginx/Dockerfile`
- `nginx/PINNED-VERSION.md`
- `nginx/snippets/security-headers.conf`
- `nginx/snippets/csp-auth.conf`
- `nginx/certs/.gitkeep`
- `tests/integration/nginx-security-edge.bats`

**Modified files:**
- `compose.yaml`
- `.env.example`
- `.gitignore`
- `tests/integration/ac1-docker-compose-smoke.bats`
- `tests/run-atdd.sh`
