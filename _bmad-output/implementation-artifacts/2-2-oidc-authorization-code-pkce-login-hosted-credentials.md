---
baseline_commit: 1fb0e6ccbcc15a27c8583cbd4133bf54567c684d
---

# Story 2.2: OIDC Authorization Code + PKCE Login (Hosted Credentials)

Status: ready-for-dev

## Story

As a staff member,
I want to authenticate through the identity service's own login,
so that my credentials never touch the apps.

## Acceptance Criteria

**AC1 — Auth Code + PKCE only; Implicit and ROPC unavailable (FR1, FR3)**
Given a registered client,
When it initiates login,
Then only Authorization Code flow with PKCE is accepted; Implicit (`response_type=token`) and ROPC (`grant_type=password`) are unavailable and return HTTP 400/error.

**AC2 — Credentials submitted to IdP only (FR2)**
Given a login request,
When credentials are entered,
Then they are submitted to the Keycloak identity service only and never transit the relying party; the RP receives only an authorization code.

**AC3 — Exact-match redirect URI enforcement (FR4)**
Given a client's registered redirect URIs,
When a redirect is requested with an unregistered URI,
Then it is rejected; no wildcard or substring matching is honored.

**AC4 — Auth code is single-use, short-lived, PKCE-bound, replay-detected (FR47)**
Given an issued authorization code,
When it is exchanged,
Then it is single-use, short-lived (≤ 60 seconds), replay-detected (second use returns `invalid_grant`), and the PKCE `code_verifier` binding is enforced server-side (wrong verifier = 400).

## Tasks / Subtasks

- [ ] Task 1: Configure realm-level OIDC security settings in `keycloak/realm-export.json` (AC1, AC4)
  - [ ] 1.1: Set `"accessCodeLifespan": 60` (explicit 60-second auth code lifetime — default is 60 but make it explicit and lint-enforceable)
  - [ ] 1.2: Set `"accessCodeLifespanUserAction": 300` (user has 5 min to complete login form before the code-session expires)
  - [ ] 1.3: Set `"accessCodeLifespanLogin": 1800` (user has 30 min before needing to re-initiate; Keycloak default)
  - [ ] 1.4: Confirm `"defaultSignatureAlgorithm": "RS256"` is present (already in baseline — do not remove)
  - [ ] 1.5: Confirm `"bruteForceProtected": true` is present (already in baseline — do not remove)

- [ ] Task 2: Register the test/dev OIDC client in `keycloak/realm-export.json` (AC1, AC2, AC3, AC4)
  - [ ] 2.1: Add a client entry under `"clients"` with `"clientId": "test-oidc-client"` (used ONLY for integration tests; production clients arrive in Epic 4/5)
  - [ ] 2.2: Set `"standardFlowEnabled": true` (Authorization Code flow — must be enabled)
  - [ ] 2.3: Set `"implicitFlowEnabled": false` (disable Implicit grant — explicit, not just defaulted)
  - [ ] 2.4: Set `"directAccessGrantsEnabled": false` (disable ROPC — Keycloak default is `true`, this MUST be explicitly set to `false`)
  - [ ] 2.5: Set `"publicClient": true` (PKCE clients are public; no client secret in the flow)
  - [ ] 2.6: Set `"attributes": {"pkce.code.challenge.method": "S256"}` (enforces PKCE S256 for this client; auth requests without `code_challenge` are rejected)
  - [ ] 2.7: Set `"redirectUris": ["http://localhost:8888/callback"]` (exact-match, localhost only, for test integration)
  - [ ] 2.8: Set `"webOrigins": ["http://localhost:8888"]` (CORS: test only)
  - [ ] 2.9: Set `"protocol": "openid-connect"` and `"enabled": true`
  - [ ] 2.10: Set `"serviceAccountsEnabled": false`, `"authorizationServicesEnabled": false`, `"consentRequired": false`, `"fullScopeAllowed": false` (minimal surface; no consent prompt)
  - [ ] 2.11: Run gitleaks detect on realm-export.json after edit — must exit 0 (no secrets committed)
  - [ ] 2.12: Run `python3 -m json.tool keycloak/realm-export.json > /dev/null` — valid JSON check

- [ ] Task 3: Update `scripts/lint-realm-export.py` to validate Story 2.2 security constraints (AC1, AC4)
  - [ ] 3.1: Assert `accessCodeLifespan` is present AND its value is ≤ 60 (not just present — enforce the short-lived requirement)
  - [ ] 3.2: For each entry in `clients` array: assert `implicitFlowEnabled` is `false` or absent (absent defaults to false in Keycloak)
  - [ ] 3.3: For each entry in `clients` array: assert `directAccessGrantsEnabled` is `false` (must be explicit because KC default is `true`)
  - [ ] 3.4: For each public client (`publicClient: true`) in `clients` array: assert `attributes.pkce.code.challenge.method` is `"S256"` (not empty, not plain)
  - [ ] 3.5: Print per-client lint findings with the `clientId` to aid debugging; exit 1 if any violation found
  - [ ] 3.6: Run the updated lint script against the updated realm-export.json — must exit 0

- [ ] Task 4: Write integration tests for the OIDC grant-type and PKCE enforcement (AC1, AC3, AC4)
  - [ ] 4.1: Create `tests/integration/oidc-pkce-flow.bats` using BATS framework (consistent with Epic 1 test pattern)
  - [ ] 4.2: Test — Implicit flow rejected: `GET /realms/envocc/protocol/openid-connect/auth?response_type=token&client_id=test-oidc-client&redirect_uri=http://localhost:8888/callback&...` → assert Location header contains `error=` (Keycloak 302 redirect with error), NOT a valid code; use `-D -` to capture redirect headers
  - [ ] 4.3: Test — ROPC rejected: `POST /realms/envocc/protocol/openid-connect/token` with body `grant_type=password&username=test@example.com&password=anything&client_id=test-oidc-client` → assert HTTP 400, body contains `"error":"unauthorized_client"` (note: this must use the `envocc` realm token endpoint, not master)
  - [ ] 4.4: Test — PKCE required: Auth Code request with valid registered `redirect_uri` but WITHOUT `code_challenge` → assert error in redirect (Location header has `error=invalid_request`); IMPORTANT: include `redirect_uri=http://localhost:8888/callback` so rejection is for missing PKCE, not bad redirect_uri
  - [ ] 4.5: Test — Exact-match redirect URI rejected (extra path): Auth request with valid PKCE params but `redirect_uri=http://localhost:8888/callback/extra` → assert HTTP 400 (Keycloak rejects before redirect since URI doesn't match)
  - [ ] 4.6: Test — Exact-match redirect URI rejected (wrong host): Auth request with `redirect_uri=http://evil.example.com/callback` → assert HTTP 400
  - [ ] 4.7: Test — Auth code replay: Complete a full PKCE auth code exchange (requires active test user from Task 4.9) → exchange code once (success) → exchange same code again → assert HTTP 400 with `"error":"invalid_grant"`
  - [ ] 4.8: Test — Wrong PKCE verifier: Complete auth flow to get code → exchange with mismatched `code_verifier` → assert HTTP 400 with `"error":"invalid_grant"`
  - [ ] 4.9: Add BATS `setup` that: loads `tests/helpers/common.bash`; calls `get_admin_token` (reads `KC_BOOTSTRAP_ADMIN_USERNAME`/`KC_BOOTSTRAP_ADMIN_PASSWORD` from `.env`); creates an `active` test user via Admin REST (`POST /admin/realms/envocc/users`, `"enabled": true`, `"emailVerified": true`); sets user password to a known value. Add `teardown` that deletes the test user (`DELETE /admin/realms/envocc/users/{id}`).
  - [ ] 4.10: Add a `setup` guard (consistent with existing integration tests): if `INTEGRATION` env var is empty, `skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"`
  - [ ] 4.11: Use `bats_load_library 'bats-support'` and `bats_load_library 'bats-assert'` at the top of the file; use `load '../helpers/common'` to get `get_admin_token` and other helpers

- [ ] Task 5: CI integration — lint in CI, integration tests run locally (AC1–AC4)
  - [ ] 5.1: Verify the existing `realm-lint` CI job in `.github/workflows/ci.yml` will pick up the updated `scripts/lint-realm-export.py` automatically — no CI YAML change needed for linting
  - [ ] 5.2: IMPORTANT — the existing BATS integration tests (`tests/integration/`) are NOT yet wired into CI (`.github/workflows/ci.yml` has no `bats` step). Integration tests require a running Docker Compose stack and run locally with `INTEGRATION=1 bats tests/integration/oidc-pkce-flow.bats`. Adding a CI Docker Compose integration job is DEFERRED to a future story (requires secret provisioning, `KC_BOOTSTRAP_ADMIN_USERNAME`/`KC_BOOTSTRAP_ADMIN_PASSWORD` as GitHub Secrets, docker-compose-up wait logic). For this story: integration tests run locally only.
  - [ ] 5.3: Run `INTEGRATION=1 bats tests/integration/oidc-pkce-flow.bats` locally against the running stack as the final verification step (after Task 6 round-trip)

- [ ] Task 6: Round-trip verification (AC1–AC4)
  - [ ] 6.1: `docker compose down -v && docker compose up --build` — confirm Keycloak starts healthy
  - [ ] 6.2: Confirm `envocc` realm is imported: `curl -sf http://localhost:8080/realms/envocc/.well-known/openid-configuration | jq '.issuer'` → `"http://localhost:8080/realms/envocc"`
  - [ ] 6.3: Confirm `test-oidc-client` is registered: Keycloak Admin REST `GET /admin/realms/envocc/clients?clientId=test-oidc-client` → returns the client with correct settings
  - [ ] 6.4: Run `python3 scripts/lint-realm-export.py` → exits 0
  - [ ] 6.5: Run `gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml` → exits 0

## Dev Notes

### Overview

This story is **pure Keycloak realm configuration** (no custom application code), per NFR8 ("no hand-rolled crypto, token, or session logic anywhere"). The entire deliverable lives in `keycloak/realm-export.json` (config-as-code, secrets stripped) plus the lint-script extension and integration tests.

Epic 2 is largely realm config — see REALM-EXPORT-NOTES.md for the full export/import procedure. Story 2.2 specifically locks down the grant types and enforces PKCE at the client level.

**This story does NOT yet implement:**
- Token signing / JWKS (Story 2.3)
- SSO session lifetimes / logout (Story 2.4)
- The Deep Sea login theme (Story 2.5)
- TOTP MFA enforcement (Story 2.6)
- Brute-force protection settings (Story 2.7 — already set at realm level in Story 1.2 baseline)
- Identity lifecycle / user attributes (Story 2.1 — canonical identity model)
- ThaiD broker (Story 2.9)

### Critical Keycloak 26 Configuration Details

#### Disabling ROPC (Grant Type: password)
**CRITICAL**: In Keycloak, `directAccessGrantsEnabled` defaults to `true`. This means ROPC is ENABLED by default on all new clients. You MUST explicitly set it to `false` in the client JSON — otherwise any registered client can be used to issue tokens with just a username/password, bypassing the OIDC hosted-credential requirement.

```json
"directAccessGrantsEnabled": false
```

#### Enforcing PKCE S256
In Keycloak 26, PKCE enforcement is set per-client via the `attributes` object:

```json
"attributes": {
  "pkce.code.challenge.method": "S256"
}
```

When this is set, auth requests without `code_challenge` (or with `code_challenge_method=plain`) will be rejected. The `plain` method is deliberately excluded — only `S256` is acceptable per RFC 7636 best practices and NFR5 (OAuth 2.0 Security BCP conformance).

#### Authorization Code Lifetime
In Keycloak, `accessCodeLifespan` is the time (in seconds) a code is valid for exchange after issuance. The default is 60 seconds. Make it explicit in the realm JSON:

```json
"accessCodeLifespan": 60
```

Note: there is no Keycloak realm-level setting to enforce PKCE on ALL clients — it is per-client. The lint script (Task 3) compensates for this by asserting per-client PKCE configuration in CI.

#### Implicit Flow
`implicitFlowEnabled` defaults to `false` in Keycloak 26 (the Implicit grant was deprecated in OAuth 2.1). Make it explicit anyway so the lint script can verify it:

```json
"implicitFlowEnabled": false
```

#### Client JSON Structure in realm-export.json
Keycloak realm exports store clients as a JSON array under the `"clients"` key. The minimal correct client object for Story 2.2:

```json
{
  "clientId": "test-oidc-client",
  "name": "Test OIDC Client (integration tests only)",
  "description": "Used only for Story 2.2 grant-type and PKCE integration tests. Not a production client.",
  "enabled": true,
  "protocol": "openid-connect",
  "publicClient": true,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": false,
  "authorizationServicesEnabled": false,
  "consentRequired": false,
  "fullScopeAllowed": false,
  "redirectUris": ["http://localhost:8888/callback"],
  "webOrigins": ["http://localhost:8888"],
  "attributes": {
    "pkce.code.challenge.method": "S256"
  }
}
```

**Secret hygiene note:** This is a `publicClient: true` client — there is no `secret` field. If Keycloak exports a `secret` field anyway (it sometimes adds a placeholder), strip it before committing.

**UUID note:** Keycloak assigns a UUID `id` field to each client on import. You do NOT need to include `id` in the realm-export.json — Keycloak generates it. After import, the UUID appears in Admin REST responses. If you export the realm after import, the UUID will appear in the export — that is fine to commit (it is not secret material).

### Lint Script Extension (Task 3)

`scripts/lint-realm-export.py` currently checks:
1. JSON parseable
2. Required top-level fields: `realm`, `enabled`, `bruteForceProtected`, `accessTokenLifespan`
3. No key material (privateKey, certificate, secret, clientSecret)

After Story 2.2, add:
4. `accessCodeLifespan` present AND value ≤ 60
5. Per-client: `implicitFlowEnabled` not `true`
6. Per-client: `directAccessGrantsEnabled` not `true`
7. Per-client public clients: `attributes.pkce.code.challenge.method == "S256"`

The script must handle:
- `clients` key absent or empty list → no-op (no client to check)
- `attributes` key absent on a client → fail the PKCE check for that public client
- Non-dict client entries → skip with a warning
- Findings reported with `clientId` for debuggability

### Integration Test Strategy (Task 4)

**Test environment prerequisite:** Docker Compose stack from Epic 1 must be running with the updated realm-export.json imported (do `docker compose down -v && docker compose up --build` to force re-import). The BATS tests use `curl` for most assertions.

**BATS library pattern** (consistent with all existing integration tests):
```bash
#!/usr/bin/env bats
# tests/integration/oidc-pkce-flow.bats
bats_load_library 'bats-support'
bats_load_library 'bats-assert'
load '../helpers/common'

setup() {
  if [[ -z "${INTEGRATION}" ]]; then
    skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"
  fi
}
```

Run: `INTEGRATION=1 bats tests/integration/oidc-pkce-flow.bats`

**Admin REST API auth for test setup:**
Use the existing `get_admin_token` helper in `tests/helpers/common.bash` — it reads `KC_BOOTSTRAP_ADMIN_USERNAME` and `KC_BOOTSTRAP_ADMIN_PASSWORD` from `.env` and exchanges them via ROPC on the master realm's `admin-cli` client:
```bash
# In BATS tests — already available via `load '../helpers/common'`
local token
token=$(get_admin_token) || fail "Could not obtain admin token — check KC_BOOTSTRAP_ADMIN_* in .env"
```
Note: The master realm's `admin-cli` client uses ROPC — this is intentional (Keycloak's bootstrap admin client). This is completely separate from the `envocc` realm's `test-oidc-client` ROPC constraints. The ROPC test (Task 4.3) targets the `envocc` realm's `test-oidc-client` token endpoint.

**PKCE code generation for BATS:**
PKCE requires generating a `code_verifier` and computing `code_challenge = BASE64URL(SHA256(code_verifier))`. In BATS/bash:
```bash
CODE_VERIFIER=$(head -c 48 /dev/urandom | base64url | tr -d '=\n')
CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | sha256sum | xxd -r -p | base64 | tr '+/' '-_' | tr -d '=\n')
```
Or use `openssl`:
```bash
CODE_VERIFIER=$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')
CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | openssl dgst -sha256 -binary | openssl base64 | tr '+/' '-_' | tr -d '=\n')
```

**Auth code acquisition for replay test (Task 4.7):**
To test code replay, you need a real auth code. This requires:
1. Creating a test user via Admin REST
2. Initiating the OIDC auth flow (GET /realms/envocc/protocol/openid-connect/auth with PKCE)
3. Submitting credentials (POST to Keycloak's login form — the action URL from the auth redirect)
4. Extracting the `code` from the redirect Location header
5. Exchanging the code once (success)
6. Exchanging the same code again (expect `invalid_grant`)

This is a multi-step curl flow. See Keycloak's test documentation or existing BATS patterns in `tests/integration/` for the form-submit approach.

**Alternative for replay test:** If the multi-step curl flow is complex, use Playwright (`tests/e2e/`) for the replay test (AC4) since it can drive the browser flow. The P0 test design (`test-design-epic-2.md`) already calls for this test type.

### Keycloak Realm-Export Round-Trip

After editing `keycloak/realm-export.json`:
1. Run `python3 -m json.tool keycloak/realm-export.json > /dev/null` (valid JSON)
2. Run `gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml` (no secrets)
3. Run `python3 scripts/lint-realm-export.py` (lint passes)
4. `docker compose down -v && docker compose up --build` (fresh import)
5. Verify `test-oidc-client` is present via Admin REST

If the stack is already running (volumes retained), Keycloak uses `IGNORE_EXISTING` and won't re-import. Use `docker compose down -v` + `up --build` for the final round-trip test.

### Project Structure Notes

**Files to MODIFY (existing):**
- `keycloak/realm-export.json` — add `accessCodeLifespan: 60`, `clients: [test-oidc-client]`
- `scripts/lint-realm-export.py` — extend with AC1/AC4 checks (Tasks 3.1–3.5)

**Files to CREATE (new):**
- `tests/integration/oidc-pkce-flow.bats` — BATS integration tests (Task 4)

**Files NOT touched in this story:**
- `compose.yaml` — no changes needed; Epic 1 stack is sufficient
- `keycloak/Dockerfile` — no changes
- `nginx/nginx.conf` — no changes
- `design-tokens/deep-sea.css` — no changes
- `admin/` — does not exist yet (Epic 4)
- `.github/workflows/ci.yml` — NO CHANGES NEEDED: `realm-lint` job already picks up the updated lint script; integration tests remain local-only for this story
- `keycloak/themes/` — no changes (Epic 2, Story 2.5)

**Scope boundary (what NOT to add to realm-export.json in this story):**
- Do NOT add MFA required actions / OTP policies (Story 2.6)
- Do NOT add password policy (Story 3.1)
- Do NOT add ThaiD identity provider (Story 2.9)
- Do NOT add realm roles `hr-admin` / `system-admin` (Story 4.2 / 5.4)
- Do NOT change `ssoSessionIdleTimeout` / `ssoSessionMaxLifespan` / token lifetimes (Story 2.4, except `accessCodeLifespan` which is THIS story)
- Do NOT add the admin app client (Story 4.2)

### Dependency Context

- **Depends on Epic 1 complete** (all 5 stories merged to `main`):
  - `keycloak/realm-export.json` baseline exists (Story 1.2)
  - Docker Compose stack + Postgres healthy (Story 1.1)
  - Nginx security edge running (Story 1.3)
  - Agentic-build gate active — gitleaks + Semgrep + realm-lint run pre-commit and in CI (Story 1.5)
- **Does NOT depend on Story 2.1** (canonical identity model): 2.2 configures the OIDC grant flow; 2.1 configures user attributes/lifecycle. Both depend only on Epic 1, and can be implemented in any order.

Stories that depend on Story 2.2 (must not merge without 2.2):
- **2.6** TOTP MFA enforcement — sits on top of the auth flow
- **2.7** Brute-force protection — sits on top of the auth flow
- **2.8** Disable blocks auth + revokes sessions — requires active sessions to exist
- **2.9** Login with ThaiD — requires auth flow + identity model (2.1)

### Security Compliance Notes

- **NFR5** (OAuth 2.0 Security BCP / RFC 9700): Only Authorization Code + PKCE is offered (no Implicit, no ROPC). PKCE S256 method required — `plain` must not be accepted.
- **NFR8** (no hand-rolled auth): All grant type restrictions are Keycloak engine configuration — no custom auth code.
- **FR1**: Authorization Code + PKCE for all client applications — enforced via client `pkce.code.challenge.method: S256`.
- **FR2**: Hosted login — enforced structurally; RP receives only auth code.
- **FR3**: No Implicit / ROPC — enforced via `implicitFlowEnabled: false` and `directAccessGrantsEnabled: false`.
- **FR4**: Exact-match redirect URIs — enforced by Keycloak per-client; no wildcard (`*`) in `redirectUris`.
- **FR47**: Single-use, short-lived, PKCE-bound codes — Keycloak's built-in code lifecycle handles single-use and replay detection. `accessCodeLifespan: 60` ensures short-lived. PKCE verifier binding is enforced by `pkce.code.challenge.method: S256`.

### Known Keycloak 26 PKCE Behavior

In Keycloak 26 with `pkce.code.challenge.method: S256` on a client:
- Auth requests WITHOUT `code_challenge`: Keycloak returns `error=invalid_request` in the redirect (or directly in the response if the redirect_uri itself is invalid).
- Auth requests WITH `code_challenge_method=plain`: Keycloak rejects — only `S256` is honored when the attribute is set to `S256`.
- Token exchange WITH wrong `code_verifier`: Keycloak returns HTTP 400 `{"error": "invalid_grant"}`.
- Auth code second use: Keycloak returns HTTP 400 `{"error": "invalid_grant"}` (codes are single-use).

### CI Integration Notes

The existing `realm-lint` job in `.github/workflows/ci.yml` (Story 1.5) runs:
```yaml
- run: python3 scripts/lint-realm-export.py
```
This automatically picks up the extended lint checks in Task 3 — **no CI YAML change needed for linting**.

**Integration tests are NOT yet in CI.** Checking `.github/workflows/ci.yml` confirms zero `bats` or `INTEGRATION` references. The existing BATS tests (`tests/integration/`) are designed to run locally with `INTEGRATION=1`. Adding a CI Docker Compose integration job requires:
- Provisioning `KC_BOOTSTRAP_ADMIN_USERNAME` and `KC_BOOTSTRAP_ADMIN_PASSWORD` as GitHub Secrets
- A docker-compose-up + health-wait step before BATS runs
- BATS + bats-support + bats-assert installed on the runner

This is **out of scope for Story 2.2** — the integration test CI job is a cross-story infrastructure concern for a future story. Story 2.2 integration tests run **locally only** via `INTEGRATION=1 bats tests/integration/oidc-pkce-flow.bats`.

### Test Design Alignment

From `_bmad-output/test-artifacts/test-design/test-design-epic-2.md`, the P0 tests for Story 2.2 are:

| AC | Test | Level | Risk |
|----|------|-------|------|
| AC1 | Implicit grant (`response_type=token`) rejected | Integration (curl) | R-001 |
| AC1 | ROPC (`grant_type=password`) rejected | Integration (curl) | R-001 |
| AC1 | No `code_challenge` rejected | Integration (curl) | R-001 |
| AC4 | Auth code replay: second use fails with `invalid_grant` | Integration (curl) | R-001 |
| AC4 | Wrong `code_verifier` rejected | Integration (curl) | R-001 |

P1 tests for Story 2.2:
| AC | Test | Level |
|----|------|-------|
| AC2 | Credentials never transit RP (RP receives only code) | E2E (Playwright) |
| AC3 | Redirect URI with extra params rejected | Integration (curl) |
| AC3 | Subdomain variant redirect URI rejected | Integration (curl) |

The P0 tests (Tasks 4.2–4.8) MUST be implemented and green before this story is marked `done`. The P1 Playwright test (AC2) is best addressed in Story 2.5 when Playwright is set up for the login theme E2E tests.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.2] — story ACs and FR references
- [Source: _bmad-output/planning-artifacts/architecture.md#Decision 1] — Keycloak as the IdP engine, NFR8
- [Source: _bmad-output/planning-artifacts/architecture.md#Decision 3 — Supporting stack] — no hand-rolled auth, Keycloak handles grant types
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure] — `keycloak/realm-export.json` location
- [Source: _bmad-output/planning-artifacts/architecture.md#Implementation Patterns — Enforcement] — 5 mandatory rules for all agents
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements FR1, FR2, FR3, FR4, FR47] — detailed FR specs
- [Source: _bmad-output/planning-artifacts/epics.md#NonFunctional Requirements NFR5, NFR8] — OAuth BCP + no hand-rolled
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements AR8] — agentic-build gate on every story
- [Source: _bmad-output/implementation-artifacts/dependency-graph.md] — story 2.2 dependencies and what depends on 2.2
- [Source: _bmad-output/test-artifacts/test-design/test-design-epic-2.md#P0 — Critical] — test plan for Story 2.2 (R-001 mitigations)
- [Source: keycloak/REALM-EXPORT-NOTES.md] — realm export/import procedure, secret stripping, round-trip test
- [Source: keycloak/realm-export.json] — current baseline state (no clients, RS256 signature, bruteForceProtected: true)
- [Source: scripts/lint-realm-export.py] — current lint script to extend
- [Source: _bmad-output/implementation-artifacts/1-5-agentic-build-ci-security-gate.md] — BATS test patterns, CI job structure

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-2-2-oidc-authorization-code-pkce-login-hosted-credentials.md`
- Unit tests: `tests/unit/oidc-pkce-lint.bats`
- Integration tests: `tests/integration/oidc-pkce-flow.bats`

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (Claude Code — bmad-create-story workflow, 2026-06-27)

### Debug Log References

None.

### Completion Notes List

(To be filled in by dev agent)

### File List

(To be filled in by dev agent)
