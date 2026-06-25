---
baseline_commit: 4da01ef
---

# Story 1.3: Nginx security edge

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the System Administrator,
I want a single Nginx security edge in front of the platform,
so that all public traffic is TLS-terminated, header-hardened, and abuse-protected.

**Epic:** 1 — Secure Platform Foundation
**GH Issue:** #4
**Scope boundary:** This story delivers ONLY the Nginx security edge — `nginx/nginx.conf`, self-signed TLS certs for local dev, integration of the `nginx` service into `compose.yaml`, and verification that all ACs pass. It does NOT include realm config-as-code (Story 1.2), the Deep Sea design tokens (Story 1.4), or the CI/pre-commit gate (Story 1.5). Keycloak's `KC_HTTP_ENABLED=true` / `KC_HOSTNAME_STRICT=false` in `compose.yaml` may be revisited once Nginx is the TLS front — see Dev Notes.

## Acceptance Criteria

1. **AC1 — TLS termination with HSTS and standard security headers.** Given the edge config, when any request arrives at the Nginx listener, then:
   - It is served over HTTPS (TLS 1.2+ only; TLS 1.0/1.1 disabled).
   - The response carries `Strict-Transport-Security: max-age=31536000; includeSubDomains` (HSTS).
   - Standard security headers are present on all responses: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: geolocation=(), camera=(), microphone=()`.
   - [Source: PRD NFR4; epics.md Story 1.3 AC1]

2. **AC2 — CSP `frame-ancestors 'none'` on auth surfaces.** Given authentication-related paths (Keycloak's login, account, admin, `realms/*`, `auth/*` endpoints), when a response is returned, then a `Content-Security-Policy` header is set on those surfaces that includes `frame-ancestors 'none'` (anti-phishing, NFR4, FR12). Non-auth paths may carry a permissive or absent CSP — the `frame-ancestors 'none'` mandate applies specifically to auth surfaces.

3. **AC3 — Edge rate-limiting / abuse controls on public unauthenticated endpoints.** Given public unauthenticated endpoints (login page, token endpoint, registration flows), when they receive excessive traffic from a single source, then Nginx rate-limiting throttles it — e.g., via `limit_req_zone` with a burst allowance appropriate for a small (~150-user) staff portal (FR50).

4. **AC4 — JWKS and discovery endpoints are cacheable through the edge.** Given the OIDC well-known discovery endpoint (`/.well-known/openid-configuration`) and JWKS endpoint (`/realms/{realm}/protocol/openid-connect/certs`), when Nginx proxies responses from Keycloak, then it preserves (or adds) appropriate `Cache-Control` response headers so clients and CDNs may cache them (FR50). These endpoints change rarely; Keycloak already sets cache headers — Nginx must not strip or negate them.

5. **AC5 — Stack boots with Nginx included.** Given `compose.yaml` includes the `nginx` service, when I run `docker compose up`, then all three services (`postgres`, `keycloak`, `nginx`) reach `healthy` / `running` status. The Nginx service has a healthcheck. Keycloak remains reachable through the Nginx proxy (not just on port 8080 directly).

6. **AC6 — Secret hygiene maintained.** Given TLS certificate material is required for local dev, when I inspect the repo, then private key files are git-ignored (`.gitignore` covers `nginx/certs/*.key`, `nginx/certs/*.pem`, or equivalent paths). A `nginx/certs/.gitkeep` or generation script may exist; actual key material never commits. [Source: architecture.md#Project Tree, epics.md Story 1.1 AC4 patterns]

## Tasks / Subtasks

- [x] **Task 1 — Create `nginx/` directory and generate local dev TLS certs (AC5, AC6)**
  - [x] Create `nginx/` directory at repo root (same level as `compose.yaml`, `keycloak/`, `postgres/`).
  - [x] Generate self-signed certificate for local dev: `openssl req -x509 -newkey rsa:4096 -keyout nginx/certs/dev.key -out nginx/certs/dev.crt -days 365 -nodes -subj "/CN=localhost"`. The `nginx/certs/` directory must be created manually or by the `openssl` command.
  - [x] Add `nginx/certs/*.key` and `nginx/certs/*.crt` (or `*.pem`) to `.gitignore` so key material never commits. Add `nginx/certs/.gitkeep` so the empty directory is tracked.
  - [x] Document the cert generation command in `README.md` under a "TLS (local dev)" section so the next developer knows how to regenerate certs.

- [x] **Task 2 — Write `nginx/nginx.conf` (all ACs)**
  - [x] Use the `official nginx` Docker image (pinned by exact version + digest — see Dev Notes for current version). Do NOT use `:latest` or a floating tag.
  - [x] Configure TLS on port 443: `ssl_protocols TLSv1.2 TLSv1.3;`, `ssl_prefer_server_ciphers on;`, reference the self-signed certs at `/etc/nginx/certs/dev.crt` and `/etc/nginx/certs/dev.key` (mounted from `nginx/certs/`).
  - [x] Add HTTP→HTTPS redirect on port 80: `return 301 https://$host$request_uri;`.
  - [x] Add HSTS header: `add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;` (AC1).
  - [x] Add standard security headers on all locations (AC1): `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: geolocation=(), camera=(), microphone=()`.
  - [x] Add `Content-Security-Policy: frame-ancestors 'none'` specifically on auth-surface locations (AC2): use a Nginx `location` block matching Keycloak auth paths (`/realms/`, `/auth/`, etc.). This is the anti-phishing control from NFR4/FR12.
  - [x] Add rate-limiting for public login endpoints (AC3): declare a `limit_req_zone` (e.g., `$binary_remote_addr zone=login_zone:10m rate=10r/m`) and apply it with a small `burst` to the auth/token paths. Size the rate to be generous enough for legitimate use (TOTP entry, password reset) but protective against brute-force supplementing Keycloak's own brute-force protection. A good starting rate is **10 req/min with burst=20** for login endpoints. Set `limit_req_status 429;` in the `http {}` block so throttled clients receive `429 Too Many Requests` (not the default `503 Service Unavailable`).
  - [x] Configure the reverse proxy to Keycloak: `proxy_pass http://keycloak:8080;` with standard proxy headers (`proxy_set_header Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto https`). Keycloak listens on port 8080 (HTTP-only internal, TLS is terminated at Nginx). Do NOT proxy port 9000 (Keycloak management/health — internal only).
  - [x] Ensure JWKS and discovery endpoint responses from Keycloak pass through with their `Cache-Control` headers intact (AC4). Nginx's default `proxy_pass` preserves upstream headers. Do NOT use `proxy_hide_header Cache-Control` or add any `add_header Cache-Control` directive on the JWKS/discovery `location` blocks. **CRITICAL gotcha:** if the JWKS/discovery location uses its own `add_header` directives (e.g. to add security headers), it will NOT inherit security headers from the parent `server {}` block — repeat all required headers in that location block explicitly. Do NOT accidentally include a `Cache-Control` header when repeating them.
  - [x] Set `proxy_buffer_size`, `proxy_buffers`, and appropriate timeouts for the Keycloak proxy (Keycloak can be slow on first login/TOTP).

- [x] **Task 3 — Add `nginx` service to `compose.yaml` (AC5, AC6)**
  - [x] Add the `nginx` service to `compose.yaml` using the pinned official image (exact version + `@sha256:` digest).
  - [x] Mount `./nginx/nginx.conf:/etc/nginx/nginx.conf:ro` and `./nginx/certs:/etc/nginx/certs:ro`.
  - [x] Publish HTTPS port: `443:443`. Also publish `80:80` for the HTTP→HTTPS redirect. **REQUIRED: remove `ports: "8080:8080"` from the `keycloak` service** in `compose.yaml` — after this story, Nginx is the only external entry point. Leaving 8080 published bypasses all security headers, CSP, rate-limiting, and HSTS — defeating the purpose of this story.
  - [x] Set `depends_on` so Nginx waits for Keycloak to be `service_healthy` before starting (Nginx will otherwise get upstream errors on startup).
  - [x] Add a healthcheck for the Nginx service: `curl -k https://localhost/health` or a simple TCP check on port 443. Since the `nginx` Docker image includes `curl`, use `curl -k -sf https://localhost/ -o /dev/null` (the `-k` flag bypasses the self-signed cert; `-s` silent; `-f` fail on HTTP error).
  - [x] Verify: `KC_HTTP_ENABLED: "true"` and `KC_HOSTNAME_STRICT: "false"` MUST remain in the Keycloak service environment in `compose.yaml`. Keycloak communicates with Nginx via HTTP internally; TLS is at the edge. These flags are NOT removed by this story.
  - [x] Add comment in `compose.yaml` explaining that KC port 8080 is intentionally NOT published to host after Story 1.3 — Nginx is the only external entry point.

- [x] **Task 4 — Update `.env.example` (AC6)**
  - [x] No new secrets are needed — TLS certs are local-generated files, not env vars. Verify that `.env.example` needs no changes. If any Nginx-specific env var is added (e.g., for a domain name), add a `NGINX_SERVER_NAME` placeholder with a `change-me-*` value and document it.

- [x] **Task 5 — Verify end-to-end (all ACs)**
  - [x] From clean state, run `docker compose up --build`. Confirm all three services reach healthy/running.
  - [x] AC1: `curl -kI https://localhost/` → verify response includes `Strict-Transport-Security`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`.
  - [x] AC2: `curl -kI https://localhost/realms/` → verify `Content-Security-Policy` header includes `frame-ancestors 'none'`.
  - [x] AC3: Run a quick burst test (e.g., `for i in $(seq 1 30); do curl -sk -o /dev/null -w "%{http_code}\n" https://localhost/realms/master/protocol/openid-connect/token; done`) — confirm `429` responses appear after the burst limit.
  - [x] AC4: `curl -kI https://localhost/realms/master/protocol/openid-connect/certs` → verify `Cache-Control` header is present and not negated.
  - [x] AC5: `docker compose ps` → all three services show `healthy` or `running`.
  - [x] AC6: `git status` → `nginx/certs/*.key` and `nginx/certs/*.crt` are NOT tracked. `git check-ignore -v nginx/certs/dev.key` → shows a matching `.gitignore` rule.
  - [x] `gitleaks detect --source=.` → clean (no secrets detected in committed files).

### Review Findings

Code review (2026-06-25) — three adversarial layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor). 4 patches applied, 2 deferred, rest dismissed as noise/out-of-scope.

- [x] [Review][Patch] Admin console (`/admin/`) missing CSP `frame-ancestors 'none'` [nginx/nginx.conf] — AC2 names "admin" as an auth surface and the README directs admins to `https://localhost/admin/`, but `/admin/` matched neither `^/realms/` nor `^/auth/`, so it fell through to `location /` with no CSP. Added a `location ~ ^/admin/` block with the full security-header set + CSP + rate-limit. (AC2 violation — fixed.)
- [x] [Review][Patch] Security headers absent on the port-80 HTTP→HTTPS redirect [nginx/nginx.conf] — AC1 requires headers on "any request arriving at the Nginx listener"; the port-80 server had no `add_header`. Added X-Frame-Options / X-Content-Type-Options / Referrer-Policy / Permissions-Policy to the redirect server block. (AC1 deviation — fixed.)
- [x] [Review][Patch] nginx healthcheck coupled to Keycloak upstream status [compose.yaml + nginx/nginx.conf] — `curl -sf https://localhost/` proxied to Keycloak, so a Keycloak 4xx/5xx marked nginx unhealthy. Added a local `location = /healthz { return 200; }` and repointed the compose healthcheck at it, decoupling nginx liveness from the upstream. (AC5 hardening — fixed.)
- [x] [Review][Patch] Dead `token_zone` declaration removed [nginx/nginx.conf] — `limit_req_zone ... zone=token_zone` was declared but never applied (the token endpoint sits under `^/realms/` and is throttled by `login_zone`). Removed the unused zone (saved its 10MB shared-memory allocation); the stricter 10r/m budget on the token endpoint is intentional. (AC3 cleanup — fixed.)
- [x] [Review][Defer] No `resolver` for `proxy_pass http://keycloak:8080` [nginx/nginx.conf] — deferred, infra hardening. nginx resolves the upstream name once at start; a Keycloak-only restart that changes its container IP leaves nginx proxying a stale IP (502) until reload. Live boot is verified; fixing properly (resolver + variable upstream) changes proxy URI handling and warrants its own pass.
- [x] [Review][Defer] Host-header reflection in port-80 `return 301 https://$host` [nginx/nginx.conf] — deferred, out of scope. `server_name _` reflects an arbitrary Host into the redirect and into Keycloak (`KC_HOSTNAME_STRICT=false`). Production hostname/TLS handling is explicitly out of scope for this local-dev story; a `server_name` allowlist belongs to the production-hardening pass.

## Dev Notes

### Source of truth & key decisions

- **Nginx role (binding):** single security edge for TLS termination, HSTS, security headers, CSP, rate-limiting, and caching control. All external traffic routes through Nginx on port 443; Keycloak listens only on 8080 internally. Management port 9000 stays internal-only. [Source: architecture.md#Decision 3 → Infrastructure & Deployment; architecture.md#Complete Project Tree `nginx/nginx.conf`]
- **Config-as-code location (binding):** `nginx/nginx.conf` at repo root. No sub-directory; the architecture tree is explicit. [Source: architecture.md#Complete Project Tree]
- **TLS in local dev:** self-signed cert (openssl); production TLS (Let's Encrypt / organizational CA) is outside the scope of this story and this repo. The architecture does not prescribe a CA for local dev.
- **Keycloak HTTP stays enabled (binding):** `KC_HTTP_ENABLED=true` and `KC_HOSTNAME_STRICT=false` remain in `compose.yaml` even after this story. Keycloak is behind Nginx — it receives HTTP from Nginx on the internal Docker network. Removing these would break internal routing. [Source: compose.yaml existing env block comment: "Required for HTTP-only local stack (TLS termination via Nginx is Story 1.3)"]
- **FR50 is split across stories (context):** Edge rate-limiting (AC3) and cacheable JWKS/discovery (AC4) are the FR50 contributions of this story. Admin CSRF protection and step-up re-auth (the other FR50 items) belong to Story 4.x. [Source: epics.md FR50 mapping]

### Nginx version pinning (CRITICAL — never use `:latest`)

Architecture mandates exact version + digest pinning for all images. At story-write time (2026-06-25), verify the latest stable Nginx version from `hub.docker.com/_/nginx`. Use the **stable** (not mainline) variant with the `alpine` base for a smaller image:

```
# Example — RE-VERIFY digest at implementation time:
nginx:1.28-alpine@sha256:<verify-from-hub.docker.com>
```

To get the current digest: `docker pull nginx:1.28-alpine && docker inspect nginx:1.28-alpine --format='{{index .RepoDigests 0}}'`.

The architecture precedent (from Story 1.1) is `image:tag@sha256:digest` format. Do not skip the digest.

### Security headers — exact values (binding)

These values are taken directly from NFR4 and standard OWASP security header guidance:

```nginx
# Add to all responses (in server {} block or in a location block that covers all paths)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), camera=(), microphone=()" always;

# On Keycloak auth surfaces only (use a separate location block)
add_header Content-Security-Policy "frame-ancestors 'none'" always;
```

The `always` parameter ensures headers are added even on error responses (4xx, 5xx). Without `always`, Nginx only adds headers on 2xx responses.

### Rate-limiting — design rationale

Nginx `limit_req_zone` rate-limits are in addition to Keycloak's own brute-force protection (FR19, configured in realm config-as-code, Story 1.2). Both layers defend independently:
- **Keycloak brute-force** (Story 1.2): per-account lockout after N failed attempts.
- **Nginx rate-limit** (this story): per-IP throttle on the HTTP layer before the request even reaches Keycloak.

Recommended zones:

```nginx
# In http {} block (top-level)
limit_req_zone $binary_remote_addr zone=login_zone:10m rate=10r/m;
limit_req_zone $binary_remote_addr zone=token_zone:10m rate=20r/m;

# In server {} → location for login/token endpoints
limit_req zone=login_zone burst=20 nodelay;
```

Set `limit_req_status 429;` so clients receive a proper `429 Too Many Requests` (not 503).

### JWKS / discovery caching (AC4) — what to do and not do

Keycloak sets `Cache-Control: no-transform` and sometimes `Cache-Control: public, max-age=...` on its JWKS endpoint. Nginx's default proxy behavior preserves these headers. **Do not** add an overriding `add_header Cache-Control` directive on the JWKS/discovery locations, as this would add a *second* `Cache-Control` header (some clients use the first, some the last — ambiguous). Simply ensure Nginx does not strip them via `proxy_hide_header Cache-Control`.

### Proxy headers to Keycloak (binding)

Keycloak must see the real client IP and know it is behind a TLS-terminating proxy:

```nginx
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto https;
```

Without `X-Forwarded-Proto https`, Keycloak may generate `http://` URLs in its redirect URIs and discovery document — breaking OIDC flows.

### Keycloak proxy mode setting (IMPORTANT)

When Keycloak is behind a reverse proxy and receives `X-Forwarded-*` headers, Keycloak must be configured to trust them. In Keycloak 26, set `KC_PROXY_HEADERS=xforwarded` (or `KC_PROXY=edge` in older versions) in the KC environment block in `compose.yaml`. Without this, Keycloak ignores the forwarded headers and uses the internal HTTP address for its own URLs — causing redirect URI mismatches in OIDC flows.

Add to Keycloak environment in `compose.yaml`:
```yaml
KC_PROXY_HEADERS: xforwarded
```

### Compose service ordering and healthcheck

- **`depends_on` order:** `nginx` depends on `keycloak: condition: service_healthy`. This ensures KC is fully up before Nginx starts accepting connections and avoids 502 Bad Gateway on startup.
- **Nginx healthcheck:** The `nginx` Docker image includes `curl`. Use:
  ```yaml
  healthcheck:
    test: ["CMD", "curl", "-k", "-sf", "https://localhost/", "-o", "/dev/null"]
    interval: 10s
    timeout: 5s
    retries: 3
    start_period: 5s
  ```

### Files to create / modify (complete list)

**New files:**
- `nginx/nginx.conf` — the Nginx configuration (TLS, headers, rate-limiting, proxy)
- `nginx/certs/.gitkeep` — tracks the `certs/` directory without committing key material
- `nginx/certs/dev.crt` — self-signed cert (generated locally, git-ignored)
- `nginx/certs/dev.key` — private key (generated locally, git-ignored)

**Modified files:**
- `compose.yaml` — add `nginx` service; add `KC_PROXY_HEADERS: xforwarded` to Keycloak env; **remove `ports: "8080:8080"` from Keycloak** (REQUIRED — external traffic must route through Nginx only; leaving 8080 published bypasses all security controls)
- `.gitignore` — add `nginx/certs/*.key`, `nginx/certs/*.crt` (and `*.pem` if used)
- `README.md` — add TLS cert generation instructions under a new section

**Do NOT create:**
- `keycloak/realm-export.json` — Story 1.2
- `lefthook.yml` / `.github/workflows/ci.yml` expansion — Story 1.5
- `admin/` directory — Story 4.1

### Testing for this story

No app test framework exists yet (SvelteKit arrives in Story 4.1). Verification is **operational** per Task 5. The existing bats test structure (`tests/unit/`, `tests/integration/`) may be extended with nginx-specific checks but is NOT required to pass ACs. The CI gate (Story 1.5) will run them.

Pattern from Story 1.1: the integration test files exist as bats scaffolds with `skip`. You may add a `tests/integration/nginx-edge.bats` scaffold that skips runtime tests — this is optional. If added, follow the `tests/helpers/common.bash` helper pattern established in Story 1.1.

### Learnings from Story 1.1 (apply here)

- **Version + digest pinning is mandatory** for all images in `compose.yaml`. Pattern: `image:tag@sha256:digest`. Re-verify the Nginx digest at implementation time — the story file may have an outdated digest.
- **`add_header` in Nginx clobbers inherited headers** from parent blocks: if `add_header` is used in a `location {}` block, Nginx will NOT inherit `add_header` directives from the enclosing `server {}` block. Workaround: repeat all required headers in every `location {}` block, OR use `include` for a shared headers file, OR use `proxy_hide_header` + `always` in the most specific block.
- **Docker Compose `$$` escaping:** environment variable references in `compose.yaml` `command`/`healthcheck` strings must use `$$VAR` (double dollar) to prevent compose variable interpolation — already the pattern in `compose.yaml` Keycloak healthcheck.
- **Port publishing decision:** After Story 1.3, Keycloak's port 8080 should NOT be published to the host. External traffic routes through Nginx:443 only. Update the `keycloak` service in `compose.yaml` by removing or commenting `ports: "8080:8080"`. The Postgres service has no published ports at all — follow the same minimal-exposure principle.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 1 → Story 1.3 (AC1–AC3); FR50; NFR4; AR1]
- [Source: _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-21/prd.md#NFR4, FR50, FR12, NFR17]
- [Source: _bmad-output/planning-artifacts/architecture.md#Decision 3 → Infrastructure & Deployment; #Complete Project Tree; #Enforcement]
- [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-06-23.md — FR50 coverage, top-level-only auth → Nginx CSP `frame-ancestors 'none'`]
- [Source: _bmad-output/implementation-artifacts/1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md — compose.yaml patterns, version-pinning conventions, healthcheck approach, `KC_HTTP_ENABLED` note]
- [Source: compose.yaml — existing service definitions, KC env block with `KC_HTTP_ENABLED` and `KC_HOSTNAME_STRICT`]

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-1-3-nginx-security-edge.md`
- Integration tests: `tests/integration/nginx-edge.bats`
- Unit tests: `tests/unit/nginx-config.bats`

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (Claude Code — bmad-dev-story workflow, 2026-06-25)

### Debug Log References

- Fixed test assertions in `tests/unit/nginx-config.bats` (TS-138a/b/c/d): `docker compose config` outputs Docker warnings to stderr but `run bash -c "..."` in bats captures both stdout and stderr. Fixed by adding `2>/dev/null` to all `docker compose config` calls in test assertions.

### Completion Notes List

- Task 1: Created `nginx/certs/` directory, generated self-signed RSA 4096 cert (`dev.crt`/`dev.key`) via openssl. Added nginx-specific `.gitignore` rules (`nginx/certs/*.key`, `nginx/certs/*.crt`, `nginx/certs/*.pem` + `!nginx/certs/.gitkeep`). Updated `README.md` with "TLS (local dev)" section including the full openssl command. `nginx/certs/.gitkeep` staged and tracked by git.
- Task 2: Wrote `nginx/nginx.conf` with: TLS (TLSv1.2 + TLSv1.3 only), HTTP→HTTPS redirect on port 80, HSTS, standard security headers (X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy), CSP `frame-ancestors 'none'` on `/realms/` and `/auth/` location blocks, rate-limiting (`limit_req_zone` 10r/m + 20r/m, burst=20, `limit_req_status 429`), reverse proxy to `http://keycloak:8080` with X-Forwarded-Proto https, proxy buffer/timeout settings. Critical: all `add_header` directives repeated in each location block to avoid nginx inheritance issue.
- Task 3: Added `nginx` service to `compose.yaml` using `nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236` (pinned). Published ports 80 and 443. Removed Keycloak `ports: "8080:8080"`. Added `KC_PROXY_HEADERS: xforwarded` to Keycloak env. Nginx `depends_on keycloak: service_healthy`. Healthcheck: `curl -k -sf https://localhost/ -o /dev/null`.
- Task 4: Verified `.env.example` needs no changes — no new Nginx-specific env vars required.
- Task 5: Ran full stack (`docker compose up --build -d --project-name story13`). All 3 services (postgres, keycloak, nginx) reached `healthy`. Verified AC1 (HSTS + security headers), AC2 (CSP frame-ancestors on /realms/), AC3 (429 rate-limit triggered on burst test), AC4 (Cache-Control: no-cache preserved from Keycloak on JWKS), AC5 (all healthy), AC6 (dev.key git-ignored, gitleaks clean). HTTP→HTTPS redirect returns 301.
- Unit tests: All 20/20 tests in `tests/unit/nginx-config.bats` pass (GREEN). All 37/37 total unit tests pass (2 are skipped P2 runtime tests).
- `gitleaks detect` (git-tracked files only): 0 leaks found.

### File List

- `nginx/nginx.conf` (new)
- `nginx/certs/.gitkeep` (new)
- `compose.yaml` (modified — added nginx service, removed KC port 8080, added KC_PROXY_HEADERS)
- `.gitignore` (modified — added nginx/certs/*.key, nginx/certs/*.crt, nginx/certs/*.pem rules)
- `README.md` (modified — added TLS local dev section, updated prerequisites and access URLs)
- `tests/unit/nginx-config.bats` (modified — removed skip directives for GREEN phase; fixed docker compose config stderr suppression in test assertions)

### Change Log

- 2026-06-25: Implemented Story 1.3 — Nginx security edge. Added nginx/nginx.conf (TLS, headers, rate-limiting, CSP, reverse proxy), nginx service to compose.yaml with pinned image + healthcheck, removed KC port 8080, added KC_PROXY_HEADERS, updated .gitignore and README. All ACs verified live. Status → review.
