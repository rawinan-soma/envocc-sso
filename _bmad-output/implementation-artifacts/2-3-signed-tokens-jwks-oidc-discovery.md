# Story 2.3: Signed Tokens, JWKS & OIDC Discovery

Status: ready-for-dev

## Story

As an integrating app,
I want verifiable tokens and a discovery document,
so that I can validate identities and self-configure.

## Acceptance Criteria

**AC1 — RS256-signed ID token with required claims**
Given a successful authentication,
When a token is issued,
Then the ID token is asymmetrically signed with RS256 and carries all required claims: `sub` (stable internal subject), `email` (work email as reconciliation key), `iss`, `aud`, `exp`, `iat`, `nonce` (FR5, NFR3).

**AC2 — JWKS endpoint publishes signing key with `kid`**
Given token validation,
When a client fetches the JWKS endpoint (`/realms/envocc/protocol/openid-connect/certs`),
Then the response contains at least one RSA key with a `kid` field, `kty: "RSA"`, and `use: "sig"` (FR5, NFR3).

**AC3 — `state` and `nonce` binding; nonce single-use**
Given an auth request,
When it is created,
Then it is bound to the session via `state` (CSRF) and `nonce` (replay protection); and `nonce` is verified exactly once by the relying party — the same nonce in a replayed ID token must fail client-side validation (FR6, FR47).

**AC4 — OIDC discovery document lets clients self-configure**
Given a client bootstrapping,
When it reads `.well-known/openid-configuration`,
Then the standard OIDC discovery document is returned containing at minimum: `issuer`, `authorization_endpoint`, `token_endpoint`, `jwks_uri`, `userinfo_endpoint`, `response_types_supported`, `subject_types_supported`, `id_token_signing_alg_values_supported` (FR11).

**AC5 — Token lifetime within NFR ceiling**
Given an issued access/ID token,
When the token payload is decoded,
Then `exp - iat ≤ 900` seconds (15-minute hard maximum, NFR2a). Current realm setting of 300 s (5 min) satisfies this; the constraint must not be relaxed.

**AC6 — `alg:none` rejected**
Given a token exchange attempt,
When a client attempts to present a token with `"alg": "none"`,
Then Keycloak rejects it (NFR3, NFR8). Validated via integration test.

**AC7 — Key rotation with active/passive overlap**
Given the RSA key provider configuration in `realm-export.json`,
When inspected,
Then there is at least one RSA key provider component configured with rotation support (active/passive) and a priority such that key overlap ≥ the maximum token lifetime (NFR3).

**AC8 — JWKS and discovery endpoints are cacheable**
Given the JWKS and discovery endpoints served through the Nginx edge,
When a client fetches them,
Then Keycloak's own `Cache-Control` headers are preserved and passed through (the Nginx edge does not strip or override these headers). This is already satisfied by Story 1.3's Nginx configuration; this AC is a regression guard (FR50).

**AC9 — realm-lint extended to cover key provider**
Given `scripts/lint-realm-export.py`,
When it runs against `keycloak/realm-export.json`,
Then it asserts the presence of an RSA key provider component in the `components` section and exits 1 if absent, so the CI gate catches a missing key configuration.

## Tasks / Subtasks

- [ ] Task 1: Add RSA key provider to `keycloak/realm-export.json` (AC2, AC7)
  - [ ] 1.1: Add `components` section with `org.keycloak.keys.KeyProvider` containing an `rsa-generated` provider: `keySize=2048`, `active=true`, `enabled=true`, `priority=100`
  - [ ] 1.2: Verify `defaultSignatureAlgorithm` is `RS256` (already set — regression guard only)
  - [ ] 1.3: Verify `accessTokenLifespan` is ≤ 900 (currently 300 s — regression guard only)
  - [ ] 1.4: Run `python3 scripts/lint-realm-export.py` — must pass after Task 4 updates it

- [ ] Task 2: Configure protocol mapper for work-email claim (AC1)
  - [ ] 2.1: Understand that protocol mappers in Keycloak are scoped to **clients**, not the realm level. For Story 2.3 there are no registered clients yet (`clients: []` in realm-export.json). Add a **client scope** named `email-claims` with a User Attribute mapper that maps `email` → claim `email` in the ID token (type: `String`, `Add to ID token: true`, `Add to access token: true`).
  - [ ] 2.2: Make the `email-claims` scope a **default client scope** at the realm level so any future registered client automatically emits the `email` claim.
  - [ ] 2.3: Add the `email-claims` client scope JSON to `realm-export.json` under `clientScopes` and `defaultDefaultClientScopes`.
  - [ ] 2.4: Verify that Keycloak's built-in `sub` claim is always present (it is — no mapper needed); document this in Dev Notes.

- [ ] Task 3: Confirm nonce and state enforcement in realm config (AC3)
  - [ ] 3.1: Keycloak enforces `nonce` in the ID token when included in the auth request — no explicit realm setting to enable. Document this as verified behavior.
  - [ ] 3.2: `state` is an OAuth 2.0 CSRF parameter validated client-side by `openid-client`; Keycloak echoes it. Document that Story 2.3 scope is server-side config only; client-side validation is part of Story 4.2 (admin OIDC sign-in).
  - [ ] 3.3: Add integration test assertion: perform an OIDC auth request with a `nonce`; decode the returned ID token; assert the `nonce` claim matches exactly.

- [ ] Task 4: Extend `scripts/lint-realm-export.py` (AC9)
  - [ ] 4.1: Add check: assert `"components"` key exists in realm JSON and `"org.keycloak.keys.KeyProvider"` is present under it with at least one entry; exit 1 with descriptive message if absent.
  - [ ] 4.2: Add check: assert no `clientSecret` values longer than 8 characters appear inside `components` entries (defense-in-depth, mirrors existing gitleaks rules).
  - [ ] 4.3: Verify the script still exits 0 on the current realm-export.json after Task 1 completes (round-trip test).

- [ ] Task 5: Write integration tests (AC1–AC6, AC8)
  - [ ] 5.1: `tests/integration/token-signing.bats` — test `alg=RS256` in decoded token header (AC1, AC6)
  - [ ] 5.2: `tests/integration/token-signing.bats` — test required claims present in ID token: `sub`, `email`, `iss`, `aud`, `exp`, `iat`, `nonce` (AC1)
  - [ ] 5.3: `tests/integration/token-signing.bats` — test `exp - iat ≤ 900` (AC5)
  - [ ] 5.4: `tests/integration/jwks-discovery.bats` — GET `/realms/envocc/protocol/openid-connect/certs`; assert `keys[0].kid` present, `keys[0].kty = "RSA"`, `keys[0].use = "sig"` (AC2)
  - [ ] 5.5: `tests/integration/jwks-discovery.bats` — GET `/realms/envocc/.well-known/openid-configuration`; assert required fields: `issuer`, `authorization_endpoint`, `token_endpoint`, `jwks_uri`, `userinfo_endpoint` (AC4)
  - [ ] 5.6: `tests/integration/jwks-discovery.bats` — assert `Cache-Control` header is present and not empty on JWKS and discovery responses (AC8 regression guard)
  - [ ] 5.7: `tests/integration/jwks-discovery.bats` — assert `alg:none` token is rejected (AC6): construct a minimal JWT with `alg:none` header; attempt userinfo or introspect; assert 401
  - [ ] 5.8: `tests/integration/nonce-state.bats` — full auth request with `nonce`; decode ID token; assert `nonce` claim present and matches sent value (AC3)

- [ ] Task 6: Verify stack import and CI pass (AC1–AC9)
  - [ ] 6.1: Rebuild Keycloak image and reset database to re-import: `docker compose build keycloak && docker compose down -v && docker compose up -d` — verify clean import with no errors in `docker compose logs keycloak`; confirm `envocc` realm was imported (look for "Importing realm 'envocc' from..." in logs)
  - [ ] 6.2: Run `python3 scripts/lint-realm-export.py` — assert exit 0
  - [ ] 6.3: Run integration tests against running stack — all BATS suites green
  - [ ] 6.4: Push branch; confirm CI gate passes (gitleaks, sast, realm-lint, realm-export-check)
  - [ ] 6.5: Confirm no regressions: `realm-export-check` and `gitleaks` CI jobs from Story 1.1/1.2 still pass

## Dev Notes

### Overview

Story 2.3 is **almost entirely `keycloak/realm-export.json` configuration** with supporting integration tests and a lint-script extension. No custom application code is required.

The three deliverables are:
1. **`keycloak/realm-export.json`** — add RSA key provider component + email client scope + default client scope registration
2. **`scripts/lint-realm-export.py`** — add key-provider presence assertion
3. **`tests/integration/`** — two new BATS test files covering token/JWKS/discovery/nonce

### Current State of `keycloak/realm-export.json` (Story 1.2 baseline)

```json
{
  "realm": "envocc",
  "enabled": true,
  "displayName": "EnvOcc SSO",
  "defaultSignatureAlgorithm": "RS256",   ← already RS256 ✓
  "accessTokenLifespan": 300,             ← 5 min, well within 15-min ceiling ✓
  "ssoSessionIdleTimeout": 1800,
  "ssoSessionMaxLifespan": 36000,
  "bruteForceProtected": true,
  "clients": [],                          ← no clients yet
  "roles": {},
  "groups": []
  // NO "components" key — RSA key provider MISSING
  // NO "clientScopes" — email claim mapper MISSING
}
```

**Critical gaps this story fills:**
- `components` section with RSA key provider is absent → Keycloak will auto-generate one at startup, but it won't be in config-as-code → add it explicitly.
- No `clientScopes` or `defaultDefaultClientScopes` → `email` claim won't appear in ID tokens for any registered client → add `email-claims` scope.

### Keycloak 26.6.x: RSA Key Provider in `realm-export.json`

Add the following to `realm-export.json` at the top level (alongside `realm`, `enabled`, etc.):

```json
"components": {
  "org.keycloak.keys.KeyProvider": [
    {
      "id": "rsa-generated-signing",
      "name": "rsa-generated",
      "providerId": "rsa-generated",
      "subComponents": {},
      "config": {
        "keySize": ["2048"],
        "enabled": ["true"],
        "active": ["true"],
        "priority": ["100"]
      }
    }
  ]
}
```

**Why `priority: 100`?** Keycloak uses the highest-priority active key for signing. Future key rotation adds a new entry at a higher priority (e.g. 200) while leaving the old key at 100 as passive — this provides the active/passive overlap required by NFR3. No separate `passive` field is needed; Keycloak manages this through priority ordering when multiple keys are present.

**Note on IDs:** The `id` field for a component in a Keycloak export can be any stable UUID-like string. Using a descriptive string `"rsa-generated-signing"` is valid during import; Keycloak will accept it or assign its own UUID. Use a proper UUID format (e.g., `"a1b2c3d4-e5f6-7890-abcd-ef1234567890"`) if you want strict compatibility.

### Keycloak 26.6.x: Email Claim via Client Scope

Add to `realm-export.json`:

```json
"clientScopes": [
  {
    "id": "email-claims-scope",
    "name": "email-claims",
    "description": "Includes email as the work-email reconciliation claim in ID and access tokens",
    "protocol": "openid-connect",
    "attributes": {
      "include.in.token.scope": "true",
      "display.on.consent.screen": "false"
    },
    "protocolMappers": [
      {
        "id": "email-mapper",
        "name": "email",
        "protocol": "openid-connect",
        "protocolMapper": "oidc-usermodel-property-mapper",
        "consentRequired": false,
        "config": {
          "userinfo.token.claim": "true",
          "user.attribute": "email",
          "id.token.claim": "true",
          "access.token.claim": "true",
          "claim.name": "email",
          "jsonType.label": "String"
        }
      }
    ]
  }
],
"defaultDefaultClientScopes": ["email-claims"],
"defaultOptionalClientScopes": []
```

**Why a client scope, not a client-level mapper?** There are no registered OIDC clients in `realm-export.json` yet (Story 2.2 registered `envocc-admin` with PKCE — confirm with Story 2.2 implementation before finalizing). A default client scope applies automatically to every registered client, avoiding per-client duplication.

**`sub` claim:** Always present in Keycloak ID tokens by default (built-in mapper in the `openid` scope). No additional mapper needed.

### Keycloak 26.6.x: `nonce` and `state` Behavior

- **`nonce`**: Keycloak includes the `nonce` in the ID token whenever it appears in the authorization request. No explicit realm setting to enable. Server-side: Keycloak binds it to the auth session and includes it in the token. Client-side validation (exactly-once check) is the responsibility of the OIDC client library (`openid-client` in Story 4.2).
- **`state`**: OAuth 2.0 CSRF parameter. Keycloak echoes it in the redirect back to the RP. Validation is client-side (the RP checks that the returned `state` matches what it sent). This story validates the server emits `nonce` in the token — client-side `state`/`nonce` validation is tested in Story 4.2.

### JWKS and Discovery Endpoints

Keycloak 26.6.x provides these automatically for any realm:

| Endpoint | Path |
|----------|------|
| OIDC Discovery | `GET /realms/envocc/.well-known/openid-configuration` |
| JWKS | `GET /realms/envocc/protocol/openid-connect/certs` |

**No Nginx changes needed.** Story 1.3 already preserves Keycloak's `Cache-Control` headers on `/realms/` paths (verified in `nginx/nginx.conf`: "NOTE: No Cache-Control add_header here — Keycloak's Cache-Control is preserved (AC4)"). Story 2.3 adds a regression test to assert this remains true.

**Rate-limiting on JWKS/discovery:** The `login_zone` (10 req/min, burst=20) in Nginx applies to all `/realms/` paths including JWKS and discovery. For clients that aggressively fetch JWKS, this could be an issue — but for this project's scale (~150 users, low client count) it is acceptable. Clients should cache JWKS per the `Cache-Control` header and only refetch on unknown `kid`. Document this in the integration guide (Story 6.2).

### `scripts/lint-realm-export.py` Current State

From Story 1.5, the script currently checks:
1. JSON parseable
2. Required fields present: `realm`, `enabled`, `bruteForceProtected`, `accessTokenLifespan`
3. No key material: `privateKey` values > 64 chars, `clientSecret` > 8 chars

**Story 2.3 extends it with:**
- Assert `components` key exists
- Assert `org.keycloak.keys.KeyProvider` present under `components` with ≥ 1 entry
- Assert no `clientSecret` values inside `components` entries

Do NOT modify the existing checks — they must still pass (regression guard).

### Integration Test Framework

Existing tests in `tests/` use **BATS** (Bash Automated Testing System). See Story 1.5 (`tests/unit/ci-security-gate.bats`, `tests/integration/ci-gate-jobs.bats`) for the established pattern.

**New test files for Story 2.3:**

`tests/integration/token-signing.bats`:
- Requires a running Keycloak stack (`docker compose up -d`)
- Requires a test user in the realm (create via Admin REST API before tests run)
- Requires an OIDC client registered in the realm for test purposes
- Pattern: obtain token via client credentials or Authorization Code (headless), decode with `jq`, assert claims

`tests/integration/jwks-discovery.bats`:
- Only requires Keycloak to be running
- Uses `curl` to fetch endpoints, `jq` to parse JSON
- No auth required (endpoints are public/unauthenticated)

`tests/integration/nonce-state.bats`:
- Requires full Authorization Code + PKCE flow (headless)
- Use `curl` cookie jar + redirect following to simulate the flow
- Or use a minimal test OIDC client script

**Helper pattern** (from existing stories): tests should be runnable in CI against the Docker Compose stack. Use `KC_BASE_URL` env var defaulting to `https://localhost:443` for flexibility.

### Files to CREATE (New)

- `tests/integration/token-signing.bats` — token header/payload/lifetime assertions
- `tests/integration/jwks-discovery.bats` — JWKS keys and discovery document assertions
- `tests/integration/nonce-state.bats` — nonce binding assertion

### Files to MODIFY (Existing)

- `keycloak/realm-export.json` — add `components` (RSA key provider) + `clientScopes` + `defaultDefaultClientScopes`
- `scripts/lint-realm-export.py` — add key provider presence check

### Files NOT touched in this story

- `nginx/nginx.conf` — no changes; caching behavior already correct from Story 1.3
- `keycloak/Dockerfile` — no changes; uses same pinned image
- `compose.yaml` — no changes
- `admin/` — does not exist yet
- `keycloak/themes/` — not yet created (Story 2.5)
- `keycloak/providers/` — not yet created (Story 5.1 audit SPI)

### Dependency Context

- **Depends on Epic 1 (all done):** Stack runs, realm-export is gitleaks-clean, Nginx edge in place, CI gate wired.
- **Story 2.2 note:** Story 2.2 (OIDC Authorization Code + PKCE) may register an `envocc-admin` client. Check the Story 2.2 output file before finalizing `clientScopes` — if 2.2 already registered a client, the `email-claims` default scope will automatically apply to it. Stories 2.1–2.5 have no intra-epic dependencies per the dependency graph and may be worked in parallel.
- **`alg:none` rejection:** Keycloak rejects `alg:none` by default. No realm configuration needed. Integration test validates the behavior.

### Keycloak Import / Restart Mechanics — CRITICAL

**`realm-export.json` is baked into the Docker image at BUILD TIME** (see `keycloak/Dockerfile`, line 27: `COPY realm-export.json /opt/keycloak/data/import/realm-export.json`). After modifying `realm-export.json`, you MUST rebuild the image for changes to take effect:

```bash
docker compose build keycloak
docker compose down -v   # -v wipes the postgres_data volume so KC re-imports on next boot
docker compose up -d
```

**Why `-v`?** The Dockerfile uses `--import-realm` with the default `IGNORE_EXISTING` strategy — if the `envocc` realm already exists in the Postgres database, the import file is silently skipped. `-v` resets the database so the realm is always re-imported from the updated image.

**In CI:** The stack always starts clean (no persistent volume), so a simple `docker compose build keycloak && docker compose up -d` is sufficient.

**For iterative local dev without wiping the database:** Use Keycloak's partial import via Admin REST API:
```bash
curl -k -s -X POST "https://localhost/admin/realms/envocc/partialImport" \
  -H "Authorization: Bearer <admin-access-token>" \
  -H "Content-Type: application/json" \
  -d '{"ifResourceExists": "OVERWRITE", "components": {...}, "clientScopes": [...]}'
```
Or use the Keycloak Admin UI → Realm Settings → Import to apply individual JSON sections.

**DO NOT** try to restart Keycloak without rebuilding the image — the old `realm-export.json` is still baked in from the previous build. The only way to apply realm-export changes is `docker compose build keycloak`.

### Project Structure Notes

All paths relative to the monorepo root:

```
keycloak/
  realm-export.json         ← MODIFY: add components + clientScopes
scripts/
  lint-realm-export.py      ← MODIFY: add key-provider check
tests/
  integration/
    token-signing.bats      ← CREATE
    jwks-discovery.bats     ← CREATE
    nonce-state.bats        ← CREATE
```

No files under `admin/`, `design-tokens/`, `postgres/`, or `nginx/` are touched.

### Architecture Compliance Checklist

- `defaultSignatureAlgorithm: RS256` preserved ✓
- No hand-rolled crypto — Keycloak's built-in RSA key provider used ✓ (NFR8)
- Identities stay in Keycloak; admin DB not touched ✓
- Validation via realm-lint + integration tests at the agentic-build gate ✓
- `alg:none` rejected by Keycloak default — confirmed via test ✓
- Token lifetime ≤ 15 min — `accessTokenLifespan: 300` ✓ (NFR2a)
- Key rotation: active/passive via priority ordering in components ✓ (NFR3)
- JWKS cacheable: Nginx preserves Keycloak Cache-Control headers ✓ (FR50)

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 2.3, AC1–AC4]
- [Source: `_bmad-output/planning-artifacts/epics.md` — FR5, FR6, FR11, FR37, FR47, FR50]
- [Source: `_bmad-output/planning-artifacts/epics.md` — NFR2a, NFR3, NFR5, NFR8]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Decision 1 (Keycloak 26.6.3), Decision 3 (Authentication & Security)]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Implementation Patterns: Naming, Structure, Enforcement]
- [Source: `_bmad-output/implementation-artifacts/1-2-realm-config-as-code-baseline-secret-hygiene.md` — realm-export.json structure + gitleaks hygiene rules]
- [Source: `_bmad-output/implementation-artifacts/1-3-nginx-security-edge.md` — AC4: Keycloak Cache-Control preserved on /realms/ paths]
- [Source: `_bmad-output/implementation-artifacts/1-5-agentic-build-ci-security-gate.md` — lint-realm-export.py spec, BATS test pattern]
- [Source: `_bmad-output/test-artifacts/test-design/test-design-epic-2.md` — Risk R-002, P0 tests for Story 2.3, P1 tests AC3/AC4]
- [Source: `keycloak/realm-export.json` — current baseline state]
- [Source: `nginx/nginx.conf` — Cache-Control preservation comment at /realms/ location block]

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-2-3-signed-tokens-jwks-oidc-discovery.md`
- Integration tests (RED phase): `tests/integration/token-signing.bats`
- Integration tests (RED phase): `tests/integration/jwks-discovery.bats`
- Integration tests (RED phase): `tests/integration/nonce-state.bats`

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (create-story workflow, 2026-06-27)

### Debug Log References

### Completion Notes List

- Ultimate context engine analysis completed — comprehensive developer guide created
- Epic 2 status updated to `in-progress` (this is the first story file created for Epic 2)
- Story status set to `ready-for-dev`
- Key insight: `components` section is absent from current realm-export.json baseline; must be added or Keycloak will auto-generate an RSA key that won't be reproducible from config-as-code.
- Key insight: Protocol mappers for `email` claim must be scoped as a default client scope (not client-level) since no OIDC clients are registered yet in the realm.
- Nginx JWKS caching already correct from Story 1.3 — no changes needed; AC8 is a regression guard only.
- `alg:none` rejection is Keycloak default behavior — no realm config change; validate via integration test.

### File List

**Modified:**
- `keycloak/realm-export.json`
- `scripts/lint-realm-export.py`

**Created:**
- `tests/integration/token-signing.bats`
- `tests/integration/jwks-discovery.bats`
- `tests/integration/nonce-state.bats`
