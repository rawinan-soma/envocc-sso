---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-06-25'
storyId: '1.3'
storyKey: 1-3-nginx-security-edge
storyFile: _bmad-output/implementation-artifacts/1-3-nginx-security-edge.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-3-nginx-security-edge.md
generatedTestFiles:
  - tests/integration/nginx-edge.bats
  - tests/unit/nginx-config.bats
inputDocuments:
  - _bmad-output/implementation-artifacts/1-3-nginx-security-edge.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-1.md
  - _bmad/tea/config.yaml
---

# ATDD Checklist: Story 1.3 — Nginx Security Edge

**Date:** 2026-06-25
**TDD Phase:** RED (all tests skipped until implementation)
**Stack Type:** backend / infrastructure (Nginx config, Docker Compose, shell)
**Test Framework:** bats (Bash Automated Testing System)

---

## TDD Red Phase Status

All acceptance test scaffolds are generated and **marked `skip`** — this is the intentional TDD red phase.

- Integration Tests: 14 tests (all skipped — `skip` in each `@test`)
- Unit Tests: 19 tests (all skipped — `skip` in each `@test`)
- **Total: 33 red-phase scaffold tests**

---

## Stack Detection

| Indicator | Found | Notes |
| --------- | ----- | ----- |
| `package.json` | No | No frontend/Node app yet (arrives Story 4.1) |
| `playwright.config.*` | No | Playwright wired in Story 4.1 |
| `compose.yaml` | Yes | nginx service to be added by this story |
| Shell/bats tests | Yes | Existing tests in `tests/` |
| `nginx/nginx.conf` | Target | The artifact being created by this story |

**Resolved stack type:** `backend` (infrastructure/shell)
**Generation mode:** AI generation (no browser recording needed)
**Test framework:** `bats` — correct choice for shell/Docker Compose/nginx integration tests

---

## Acceptance Criteria Coverage

| AC | Description | Test File | Priority | Tests |
| -- | ----------- | --------- | -------- | ----- |
| AC1 | TLS termination, HSTS, standard security headers | `tests/integration/nginx-edge.bats` | P0 | 6 |
| AC2 | CSP `frame-ancestors 'none'` on auth surfaces | `tests/integration/nginx-edge.bats` | P0 | 2 |
| AC3 | Rate-limiting / abuse controls, 429 on burst | `tests/integration/nginx-edge.bats` | P1 | 2 |
| AC4 | JWKS and discovery endpoints cacheable (Cache-Control preserved) | `tests/integration/nginx-edge.bats` | P1 | 2 |
| AC5 | Stack boots with nginx included; all 3 services healthy | `tests/integration/nginx-edge.bats` | P0 | 5 |
| AC6 | Secret hygiene: nginx certs git-ignored, .gitkeep tracked | `tests/unit/nginx-config.bats` | P0 | 3 |
| Config | nginx image no `:latest`, @sha256: pinned | `tests/unit/nginx-config.bats` | P1 | 2 |
| Config | nginx.conf directives: TLS, headers, rate-limit, CSP | `tests/unit/nginx-config.bats` | P1 | 10 |
| Config | Keycloak port 8080 not published, KC_PROXY_HEADERS set | `tests/unit/nginx-config.bats` | P1 | 2 |
| Config | nginx service healthcheck, depends_on keycloak | `tests/unit/nginx-config.bats` | P1 | 2 |

---

## Generated Test Files

### `tests/integration/nginx-edge.bats` (AC1, AC2, AC3, AC4, AC5)

| Test | ID | Priority | Skip Reason |
| ---- | -- | -------- | ----------- |
| postgres reaches healthy (nginx stack) | TS-135a | P0 | nginx service not yet in compose.yaml |
| keycloak reaches healthy (nginx stack) | TS-135a | P0 | nginx service not yet in compose.yaml |
| nginx reaches healthy within 30 s | TS-135a | P0 | nginx service not yet in compose.yaml |
| Keycloak reachable through Nginx HTTPS:443 | TS-135b | P0 | nginx.conf not yet created |
| HTTP port 80 redirects to HTTPS (301) | TS-135b | P0 | nginx.conf not yet created |
| HSTS header with max-age=31536000; includeSubDomains | TS-131a | P0 | nginx.conf not yet created |
| X-Frame-Options: DENY | TS-131b | P0 | nginx.conf not yet created |
| X-Content-Type-Options: nosniff | TS-131b | P0 | nginx.conf not yet created |
| Referrer-Policy: strict-origin-when-cross-origin | TS-131b | P0 | nginx.conf not yet created |
| Permissions-Policy header present | TS-131b | P0 | nginx.conf not yet created |
| /realms/ returns CSP frame-ancestors 'none' | TS-132a | P0 | nginx.conf not yet created |
| /auth/ returns CSP frame-ancestors 'none' | TS-132a | P0 | nginx.conf not yet created |
| Burst requests trigger HTTP 429 | TS-133a | P1 | nginx.conf rate-limiting not yet configured |
| Rate-limited requests return 429 not 503 | TS-133b | P1 | nginx.conf limit_req_status not yet set |
| JWKS endpoint Cache-Control header preserved | TS-134a | P1 | nginx proxy not yet configured |
| OIDC discovery endpoint Cache-Control header preserved | TS-134b | P1 | nginx proxy not yet configured |

### `tests/unit/nginx-config.bats` (AC5, AC6, Config)

| Test | ID | Priority | Skip Reason |
| ---- | -- | -------- | ----------- |
| .gitignore covers nginx/certs/*.key | TS-136a | P0 | .gitignore nginx rules not yet added |
| .gitignore covers nginx/certs/*.crt | TS-136b | P0 | .gitignore nginx rules not yet added |
| git does not track nginx/certs/*.key/*.crt | TS-136a-rt | P0 | nginx/certs/ not yet created |
| nginx/certs/.gitkeep is tracked | TS-136c | P0 | nginx/certs/.gitkeep not yet created |
| compose.yaml nginx image: no ':latest' | TS-137a | P1 | nginx service not yet in compose.yaml |
| compose.yaml nginx image: @sha256: digest | TS-137b | P1 | nginx service not yet in compose.yaml |
| nginx/nginx.conf exists | TS-137c | P1 | nginx.conf not yet created |
| nginx.conf references dev.crt and dev.key paths | TS-137c | P1 | nginx.conf not yet created |
| nginx.conf: ssl_protocols TLSv1.2 TLSv1.3 | TS-137d | P1 | nginx.conf not yet created |
| nginx.conf: Strict-Transport-Security header with always | TS-137e | P1 | nginx.conf not yet created |
| nginx.conf: X-Frame-Options: DENY header | TS-137f | P1 | nginx.conf not yet created |
| nginx.conf: X-Content-Type-Options: nosniff header | TS-137g | P1 | nginx.conf not yet created |
| nginx.conf: limit_req_zone defined | TS-137h | P1 | nginx.conf not yet created |
| nginx.conf: limit_req applied to auth locations | TS-137h | P1 | nginx.conf not yet created |
| nginx.conf: limit_req_status 429 | TS-137i | P1 | nginx.conf not yet created |
| nginx.conf: CSP frame-ancestors on auth location | TS-137j | P1 | nginx.conf not yet created |
| compose.yaml: Keycloak port 8080 NOT published | TS-138a | P1 | nginx service not yet in compose.yaml / KC port not yet removed |
| compose.yaml: KC_PROXY_HEADERS: xforwarded set | TS-138b | P1 | KC_PROXY_HEADERS not yet added |
| compose.yaml: nginx healthcheck defined | TS-138c | P1 | nginx service not yet in compose.yaml |
| compose.yaml: nginx depends_on keycloak: service_healthy | TS-138d | P1 | nginx service not yet in compose.yaml |

---

## Helper Infrastructure

### `tests/helpers/common.bash` (existing)

Provides shared utilities — no changes needed for Story 1.3:
- `wait_for_healthy <service> <timeout>` — polls `docker compose ps` until service is healthy (reused for nginx service)
- `compose_up` / `compose_down_volumes` — stack lifecycle helpers
- `env_setup` — copies `.env.example` → `.env` with CI-safe placeholder substitution

---

## Test Design Traceability

| Test Scenario (test-design-epic-1.md) | Covered By |
| ------------------------------------- | ---------- |
| TS-131 HSTS + standard security headers + CSP `frame-ancestors 'none'` (P0) | `nginx-edge.bats` TS-131a/b, TS-132a |
| TS-132 Edge rate-limiting throttles excessive traffic, HTTP 429 (P1) | `nginx-edge.bats` TS-133a/b |
| TS-133 JWKS and discovery endpoints cacheable (P2) | `nginx-edge.bats` TS-134a/b |
| Story 1.3 AC5: Stack boots with nginx (R-002 mitigation) | `nginx-edge.bats` TS-135a/b |
| Story 1.3 AC6: Secret hygiene for TLS cert material (R-001 mitigation) | `nginx-config.bats` TS-136a/b/c |

---

## Implementation Guidance for Dev Agent

### Task Activation Order

When implementing each story task, activate the corresponding tests by removing `skip`:

| Task | Activate These Tests |
| ---- | ------------------- |
| Task 1 — Create nginx/ dir, generate certs, .gitignore update | `nginx-config.bats` TS-136a, TS-136b, TS-136a-rt, TS-136c |
| Task 2 — Write nginx/nginx.conf | `nginx-config.bats` TS-137c through TS-137j (all nginx.conf directive tests) |
| Task 3 — Add nginx service to compose.yaml; remove KC port 8080; add KC_PROXY_HEADERS | `nginx-config.bats` TS-137a, TS-137b, TS-138a, TS-138b, TS-138c, TS-138d |
| Task 4 — Update .env.example (verify no changes needed) | No new tests (verify TS-104g from `secret-hygiene.bats` still passes) |
| Task 5 — End-to-end verify with live stack | `nginx-edge.bats` ALL tests (remove all `skip` and run against live stack) |

### Critical Gotcha: Nginx add_header Inheritance

When a `location {}` block in nginx has its own `add_header` directives, it will **NOT inherit** `add_header` directives from the enclosing `server {}` block. This means:

- If the `/realms/` location block adds `Content-Security-Policy`, it must **also repeat** all standard headers (HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy).
- Tests TS-131b check these headers on the root path. If auth locations fail these checks, the location blocks need to include the full header set.
- Workaround: Use a shared `include nginx/snippets/security-headers.conf` or repeat all headers in every location block.

### How to Run Tests

Prerequisites:
```bash
# Install bats and support libraries (once)
brew install bats-core
# bats-support and bats-assert are vendored in tests/lib/ — no system install needed
```

Run all unit tests (no stack required):
```bash
BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/unit/nginx-config.bats
```

Run integration tests (requires live stack):
```bash
# First bring up the stack
docker compose up --build -d
# Wait for nginx to be healthy, then:
BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/integration/nginx-edge.bats
```

Run all tests together:
```bash
BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/unit/ tests/integration/
```

Quick header verification (after Task 2+3):
```bash
# AC1 — HSTS and standard headers
curl -kI https://localhost/ 2>&1 | grep -E "Strict-Transport-Security|X-Frame-Options|X-Content-Type-Options|Referrer-Policy"

# AC2 — CSP on auth surface
curl -kI https://localhost/realms/ 2>&1 | grep "Content-Security-Policy"

# AC4 — Cache-Control preserved on JWKS
curl -kI https://localhost/realms/master/protocol/openid-connect/certs 2>&1 | grep "Cache-Control"
```

Rate-limit burst test (AC3):
```bash
for i in $(seq 1 30); do
  curl -sk -o /dev/null -w "%{http_code}\n" \
    -X POST https://localhost/realms/master/protocol/openid-connect/token
done
# Expect some 429 responses after the burst window is exceeded
```

---

## ATDD Artifacts

- **Checklist:** `_bmad-output/test-artifacts/atdd-checklist-1-3-nginx-security-edge.md`
- **Integration tests:** `tests/integration/nginx-edge.bats`
- **Unit tests:** `tests/unit/nginx-config.bats`

---

## Next Steps

1. **Dev agent implements Story 1.3** (Task 1 → Task 5 in order per story file)
2. **For each task:** remove `skip` from the relevant tests → run → verify RED (fail) → implement → run → verify GREEN (pass) → commit
3. After all tests pass: run `bmad-dev-story` to finalize the story
4. After implementation: run `bmad-testarch-automate` for broader automated coverage

---

**Generated by:** BMad TEA Agent — ATDD Test Architect Module
**Workflow:** `bmad-testarch-atdd` (Create mode, sequential execution)
**Version:** 4.0 (BMad v6)
