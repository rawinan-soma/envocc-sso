---
baseline_commit: 1fb0e6c
---

# Story 2.4: SSO Session, Lifetimes & RP-Initiated Logout

Status: ready-for-dev

## Story

As a staff member,
I want one session that carries me across apps and ends cleanly,
so that I sign in once and sign out securely.

## Acceptance Criteria

**AC1 — SSO single sign-on session (FR7)**
Given an authenticated session,
When I open another integrated app,
Then I reach it without re-entering credentials.

**AC2 — Session lifetime and token ceiling enforcement (FR8, NFR2a)**
Given session policy,
When idle or absolute lifetime expires,
Then re-authentication is required; access/ID tokens never exceed a 15-minute lifetime (NFR2a).

**AC3 — Refresh token rotation and family revocation (FR9)**
Given refresh tokens are issued,
When a refresh token is used,
Then a new refresh token is issued and the old one is revoked; on replay detection the entire family is revoked.

**AC4 — Session identifier regenerated on every auth-state transition (FR45)**
Given an auth-state transition (login success, MFA success),
When it occurs,
Then the session identifier is regenerated and a server-side session record is maintained.

**AC5 — RP-initiated logout terminates session and honors validated redirect (FR10)**
Given RP-initiated logout,
When an app requests it,
Then the session terminates, any outstanding refresh tokens are revoked, and a validated post-logout redirect is honored (landing on the branded signed-out surface per UX-DR3).

**AC6 — Realm lint validates session/lifetime values (AR8)**
Given the realm-export.json lint script,
When it runs,
Then it validates `accessTokenLifespan ≤ 900`, `revokeRefreshToken == true`, and `refreshTokenMaxReuse == 0`, blocking the commit if any value is wrong.

## Tasks / Subtasks

- [ ] Task 1: Add refresh token rotation config to `keycloak/realm-export.json` (AC3)
  - [ ] 1.1: Add `"revokeRefreshToken": true` — enables server-side family revocation on replay detection
  - [ ] 1.2: Add `"refreshTokenMaxReuse": 0` — each refresh token is single-use; a new one is issued on every refresh
  - [ ] 1.3: Verify the three existing session/lifetime fields have expected values: `ssoSessionIdleTimeout: 1800`, `ssoSessionMaxLifespan: 36000`, `accessTokenLifespan: 300`; leave them unchanged (already compliant with FR8 and NFR2a)
  - [ ] 1.4: Add a `## Story 2.4 — Session, Lifetimes & Refresh Token Rotation` section to the existing `keycloak/REALM-EXPORT-NOTES.md` (JSON does not support comments; this file is the established companion for realm config documentation and is already in the gitleaks path allowlist); document the rationale and exact values for each lifetime field, citing the relevant FR/NFR

- [ ] Task 2: Extend `scripts/lint-realm-export.py` to validate session/lifetime values (AC6)
  - [ ] 2.1: Add `revokeRefreshToken` to `REQUIRED_FIELDS` so its presence is enforced
  - [ ] 2.2: Add `refreshTokenMaxReuse` to `REQUIRED_FIELDS`
  - [ ] 2.3: After the required-field check, add a value-validation block that:
    - Asserts `data.get("accessTokenLifespan", 9999) <= 900` — errors with "accessTokenLifespan {actual}s exceeds NFR2a 15-minute ceiling (900 s max)"
    - Asserts `data.get("revokeRefreshToken") is True` — errors with "revokeRefreshToken must be true (FR9 family revocation)"
    - Asserts `data.get("refreshTokenMaxReuse") == 0` — errors with "refreshTokenMaxReuse must be 0 (FR9 rotate-on-use)"
  - [ ] 2.4: Ensure `scripts/lint-realm-export.py` continues to exit 0 on the updated realm-export.json

- [ ] Task 3: Add unit tests for the lint value-validation logic (AC6)
  - [ ] 3.1: Create `tests/unit/realm-session-config.bats` with test scenarios:
    - `[P0][TS-240a]` Lint passes when `revokeRefreshToken: true`, `refreshTokenMaxReuse: 0`, `accessTokenLifespan: 300` (green path)
    - `[P0][TS-240b]` Lint exits 1 when `accessTokenLifespan: 1200` (exceeds 900 s ceiling)
    - `[P0][TS-240c]` Lint exits 1 when `revokeRefreshToken: false`
    - `[P0][TS-240d]` Lint exits 1 when `refreshTokenMaxReuse: 1`
    - `[P0][TS-240e]` Lint exits 1 when `revokeRefreshToken` is missing
    - `[P0][TS-240f]` Lint exits 1 when `refreshTokenMaxReuse` is missing
  - [ ] 3.2: Each test writes a minimal valid/invalid JSON fixture to a temp file and passes it as `sys.argv[1]` to the lint script; no file I/O side effects on `keycloak/realm-export.json`
  - [ ] 3.3: Follow BATS conventions in `tests/unit/` — load `bats-support`, `bats-assert`, `../helpers/common`

- [ ] Task 4: Add integration tests for session/lifetime/logout config (AC1, AC2, AC3, AC4, AC5)
  - [ ] 4.1: Extend `tests/integration/realm-import.bats` — add the following test scenarios that share the existing `setup()` guard (`INTEGRATION=1`):
    - `[P0][TS-241a]` Admin REST API confirms `revokeRefreshToken` is `true` in the live realm (AC3)
    - `[P0][TS-241b]` Admin REST API confirms `refreshTokenMaxReuse` is `0` in the live realm (AC3)
    - `[P1][TS-241c]` Admin REST API confirms `accessTokenLifespan ≤ 900` in the live realm (AC2/NFR2a)
    - `[P1][TS-241d]` OIDC discovery `.well-known` includes `end_session_endpoint` (AC5 — RP-initiated logout infrastructure)
    - `[P1][TS-241e]` End Session endpoint (`/realms/envocc/protocol/openid-connect/logout`) returns 200 or 302 (not 4xx/5xx) on a GET without params (AC5 — endpoint reachability)
  - [ ] 4.2: Update the `TS-201d` baseline check in `realm-import.bats` to also assert `revokeRefreshToken == True` and `refreshTokenMaxReuse == 0` — this keeps the baseline assertion exhaustive

- [ ] Task 5: Verify Keycloak 26.x built-in FR45 behavior and document it (AC4)
  - [ ] 5.1: Verify via Keycloak 26.x documentation and OIDC discovery that session ID is regenerated on every auth-state transition (login success + MFA success) — this is Keycloak's default behavior; no realm config change is needed
  - [ ] 5.2: Add an integration test `[P2][TS-241f]` (always-skip, manual verification procedure) documenting the FR45 session-fixation check: authenticate, capture the `AUTH_SESSION_ID` cookie, complete MFA, confirm the cookie value changes
  - [ ] 5.3: Add a dev note to the `keycloak/REALM-EXPORT-NOTES.md` Story 2.4 section citing the Keycloak 26.x docs section confirming session-ID regeneration behavior

- [ ] Task 6: Document per-client RP-initiated logout requirements (AC5)
  - [ ] 6.1: Add a `## Per-Client Logout Configuration` section to `keycloak/REALM-EXPORT-NOTES.md` (Story 2.4 section) documenting the exact client-level fields required when registering any OIDC client in `realm-export.json`:
    - `"frontchannelLogout": false` — use back-channel logout (preferred for confidential clients)
    - `"attributes": { "post.logout.redirect.uris": "https://app.example.com/signed-out" }` — exact registered URIs; wildcard not accepted; Keycloak rejects a redirect not matching this list
    - `"attributes": { "backchannel.logout.session.required": "true" }` — ensures the Keycloak session is invalidated on back-channel logout notification
  - [ ] 6.2: Note in `keycloak/REALM-EXPORT-NOTES.md` that:
    - Story 2.2 (OIDC PKCE login) registers the admin-app client — that story MUST set `post.logout.redirect.uris` to the admin app's signed-out route
    - Story 5.3 (register OIDC clients UI) exposes per-client logout config to System Admins
    - The "branded signed-out surface" (UX-DR3 — the Keycloak "Signed out" theme page) is styled in Story 2.5; for now the Keycloak default "You are logged out" page is acceptable as a placeholder
  - [ ] 6.3: Do NOT add any `"_comment"` or pseudo-comment key to `realm-export.json` — Keycloak stores unknown top-level keys in its database and may emit them on export, causing diff noise; all documentation belongs in `keycloak/REALM-EXPORT-NOTES.md`

- [ ] Task 7: Verify agentic-build gate passes on the updated codebase (AR8)
  - [ ] 7.1: Run `python3 scripts/lint-realm-export.py` from repo root — must exit 0
  - [ ] 7.2: Run `gitleaks protect --staged --redact` on staged changes — must exit 0 (no secrets)
  - [ ] 7.3: Run `semgrep scan --config auto --error` — must exit 0
  - [ ] 7.4: Push branch; confirm all CI jobs pass (realm-lint, sast, gitleaks)

## Dev Notes

### Overview

This story is **pure Keycloak realm configuration**. No SvelteKit/admin app code is written or modified. The story has three workstreams:

1. **Realm config** — add two fields to `keycloak/realm-export.json` (refresh token rotation) and document all session/lifetime values.
2. **Lint hardening** — upgrade `scripts/lint-realm-export.py` from presence-only to value-validated checks for the three security-critical lifetime fields.
3. **Tests** — unit tests for the lint logic, integration tests confirming the live Keycloak honours the config.

Session fixation protection (FR45) and the SSO session mechanism (FR7) are **Keycloak 26.x built-in behaviors** — no configuration is required, only verification and documentation.

### Learnings from Previous Stories (1.x)

Directly actionable patterns from Epic 1 implementation:

1. **Commit prefix:** `feat(story-2-4): ...` (matches the `feat(story-N-N): ...` convention established in 1.1–1.5).
2. **BATS test conventions:**
   - All unit tests in `tests/unit/` load `bats-support`, `bats-assert`, `../helpers/common`.
   - BATS_LIB_PATH must point to `tests/lib/` (gitignored vendored libraries). Tests confirm this is always needed.
   - Fixture files for unit tests: use `mktemp` to create, pass path as `sys.argv[1]`, and `rm -f` after assertion.
   - Label format: `[P0][TS-NNNx]` — `P0` = must-pass-before-merge, `P1` = should-pass, `P2` = optional/manual.
3. **Realm lint script (`scripts/lint-realm-export.py`):** already enforces `REQUIRED_FIELDS` presence-only (Story 1.5). This story upgrades it to value-validated. See deferred-work note below.
4. **gitleaks allowlist:** `keycloak/REALM-EXPORT-NOTES.md` is already in `.gitleaks.toml` `paths = [...]`. Do NOT create a new `REALM-SESSION-NOTES.md` — all documentation for realm config goes in the existing `REALM-EXPORT-NOTES.md`.
5. **Integration test pattern for realm API calls:** use `get_admin_token` from `tests/helpers/common.bash`, then `curl -sf -H "Authorization: Bearer ${token}" http://localhost:8080/admin/realms/envocc`, pipe to `python3 -c "..."` for field extraction. Use `mktemp` if the JSON payload is large (see TS-201d pattern in `tests/integration/realm-import.bats`).
6. **No forward dependencies on admin app:** `admin/` does not exist. Do NOT reference or attempt to run admin app commands.

**Deferred-work item resolved by this story:** Story 1.5 code review recorded a deferred item in `_bmad-output/implementation-artifacts/deferred-work.md`: "Realm-lint required-field check is presence-only — `accessTokenLifespan` are asserted present but not validated for sane values." This story's Task 2 resolves that deferred item by adding value validation for `accessTokenLifespan`, `revokeRefreshToken`, and `refreshTokenMaxReuse`.

### Current State of `keycloak/realm-export.json`

The file currently has three session/lifetime fields (from Story 1.2 baseline):

```json
{
  "ssoSessionIdleTimeout": 1800,
  "ssoSessionMaxLifespan": 36000,
  "accessTokenLifespan": 300,
  ...
}
```

| Field | Current value | Required by | Status |
|---|---|---|---|
| `ssoSessionIdleTimeout` | 1800 s (30 min) | FR8 idle timeout | ✅ Reasonable — leave unchanged |
| `ssoSessionMaxLifespan` | 36000 s (10 h) | FR8 absolute timeout | ✅ One working day — leave unchanged |
| `accessTokenLifespan` | 300 s (5 min) | NFR2a ≤ 15 min | ✅ Already compliant — leave unchanged |
| `revokeRefreshToken` | **MISSING** | FR9 family revocation | ❌ **Must add: `true`** |
| `refreshTokenMaxReuse` | **MISSING** | FR9 rotate-on-use | ❌ **Must add: `0`** |

After Task 1, the **exact diff to `keycloak/realm-export.json`** is:

```diff
   "accessTokenLifespan": 300,
+  "revokeRefreshToken": true,
+  "refreshTokenMaxReuse": 0,
   "defaultSignatureAlgorithm": "RS256",
```

The two new fields go immediately after `accessTokenLifespan` (keeping all token/session fields grouped). The full session block becomes:

```json
{
  "ssoSessionIdleTimeout": 1800,
  "ssoSessionMaxLifespan": 36000,
  "accessTokenLifespan": 300,
  "revokeRefreshToken": true,
  "refreshTokenMaxReuse": 0
}
```

### Why `revokeRefreshToken` + `refreshTokenMaxReuse: 0`

These two fields together implement FR9 ("rotate on use with family revocation on replay"):

- `revokeRefreshToken: true` — Keycloak 26.x enables **refresh token family tracking**. When a refresh token is used, the old one is invalidated. If a previously-invalidated token is presented again (replay attack), Keycloak **revokes the entire token family** and forces re-authentication.
- `refreshTokenMaxReuse: 0` — Each refresh token is single-use only (0 = no reuse allowed). Combined with `revokeRefreshToken: true`, this gives the rotate-on-every-use + family-revoke-on-replay behavior required by FR9.

Both fields default to `false`/`0` in Keycloak if absent; omitting them silently leaves refresh tokens non-rotating. Adding them explicitly is required and must be enforced by lint.

### Keycloak 26.x RP-Initiated Logout (FR10)

The **End Session endpoint** is published by Keycloak at:
```
/realms/envocc/protocol/openid-connect/logout
```
and listed in `.well-known/openid-configuration` as `end_session_endpoint`. This endpoint is available by default in Keycloak 26.x — no realm config is required to enable it.

**How a client uses it:**
1. The client (RP) constructs a logout request to the End Session endpoint with:
   - `id_token_hint` — the ID token from the session (strongly recommended)
   - `post_logout_redirect_uri` — must exactly match a URI registered in the client's `postLogoutRedirectUris`
   - `state` — optional, passed through to the redirect
2. Keycloak terminates the SSO session, revokes refresh token families, and redirects to the `post_logout_redirect_uri`.
3. If no `post_logout_redirect_uri` is provided (or `id_token_hint` is absent), Keycloak shows its own "You are logged out" page.

**Per-client config required (not done in this story):**
```json
{
  "clientId": "<client-id>",
  "frontchannelLogout": false,
  "attributes": {
    "post.logout.redirect.uris": "https://app.example.com/signed-out",
    "backchannel.logout.session.required": "true"
  }
}
```
This config must be added when each client is registered:
- Story 2.2 (admin-app OIDC client) — add `postLogoutRedirectUris` for the admin app
- Story 5.3 (OIDC client management UI) — exposes this config to System Admins

**For this story (2.4):** the End Session endpoint reachability is verified via an integration test. No client is registered in this story. The default "You are logged out" Keycloak page satisfies the post-logout UX until Story 2.5 implements the branded "Signed out" theme surface.

### Keycloak 26.x Session Fixation Protection (FR45)

Keycloak 26.x **regenerates the session ID on every authentication-state transition** as a built-in security property:
- After successful password authentication → new session ID
- After successful MFA (TOTP) verification → new session ID

This behavior is non-configurable (it cannot be disabled) and is the default in all Keycloak 26.x versions. No `realm-export.json` field controls it.

The **server-side session record** is maintained in Keycloak's PostgreSQL database (the `keycloak` DB, not the admin DB). This is also the default behavior; Keycloak's session store is always DB-backed in the production configuration.

Verification: the `AUTH_SESSION_ID` and `KEYCLOAK_SESSION` cookies change value between the password step and the MFA step, and again after MFA success. This can be manually verified via browser developer tools or an automated test using a cookie-jar aware HTTP client (documented as a `[P2]` always-skip manual procedure in Task 5.2).

### SSO Single Sign-On Mechanism (FR7)

Keycloak establishes a **realm-level SSO session** upon successful authentication. This session is tracked via the `KEYCLOAK_SESSION` cookie. When a second client (app) initiates an OIDC authorization request for the same user:
1. Keycloak detects the existing SSO session cookie
2. Skips the login/MFA prompts and issues tokens directly
3. The user reaches the second app without re-entering credentials

This mechanism is automatic for all clients registered in the same realm. No realm config is needed — it is the default OIDC session behavior in Keycloak 26.x.

**Test approach for AC1:** A full multi-client SSO test requires two registered OIDC clients, which are added in later stories (2.2, 5.3). The AC1 behavior is inherent to Keycloak's OIDC session model. For this story, the integration test `TS-241e` confirms the End Session endpoint is reachable (the logout side of the SSO session), and `TS-241a`/`TS-241b` confirm rotation config is correct.

### Lint Script Enhancement Pattern

The existing lint script (`scripts/lint-realm-export.py`) has two validation passes:
1. **Presence check**: `REQUIRED_FIELDS = [...]` — asserts fields exist.
2. **Key-material scan**: recursive scan for private keys/secrets.

Task 2 adds a third pass: **value validation**. The pattern follows the existing error-accumulation style:

```python
# Value-validation block (add after the required-field check)
MAX_ACCESS_TOKEN_LIFESPAN = 900  # 15 minutes — NFR2a hard ceiling

atl = data.get("accessTokenLifespan")
if isinstance(atl, int) and atl > MAX_ACCESS_TOKEN_LIFESPAN:
    errors.append(
        f"accessTokenLifespan {atl}s exceeds NFR2a 15-minute ceiling "
        f"({MAX_ACCESS_TOKEN_LIFESPAN}s max)."
    )

if data.get("revokeRefreshToken") is not True:
    errors.append(
        "revokeRefreshToken must be true (FR9: family revocation on replay)."
    )

if data.get("refreshTokenMaxReuse") != 0:
    errors.append(
        "refreshTokenMaxReuse must be 0 (FR9: rotate on every use)."
    )
```

Note: only validate if the field is present (presence failure is already caught by `REQUIRED_FIELDS`). The `isinstance(atl, int)` guard prevents a crash if the field contains a non-integer value — the presence check will already have flagged that case. For `revokeRefreshToken`, use `is not True` (not `!= True`) to correctly reject `null`, `0`, and absent values.

### BATS Unit Test Fixture Pattern

Unit tests in `tests/unit/realm-session-config.bats` use the established temp-file fixture pattern from `tests/unit/secret-hygiene.bats`. Each negative test writes a minimal fixture to `mktemp`:

```bash
#!/usr/bin/env bats
# tests/unit/realm-session-config.bats
# Story 2.4: Lint value-validation for session/lifetime/refresh-token config

bats_load_library 'bats-support'
bats_load_library 'bats-assert'
load '../helpers/common'

# Minimal VALID fixture — all required fields, compliant values
VALID_FIXTURE='{
  "realm": "envocc",
  "enabled": true,
  "bruteForceProtected": true,
  "accessTokenLifespan": 300,
  "revokeRefreshToken": true,
  "refreshTokenMaxReuse": 0
}'

@test "[P0][TS-240a] Lint passes with valid session/lifetime values" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_success
  rm -f "${fixture}"
}

@test "[P0][TS-240b] Lint exits 1 when accessTokenLifespan exceeds 900s ceiling" {
  local fixture
  fixture=$(mktemp)
  echo "${VALID_FIXTURE}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['accessTokenLifespan'] = 1200
print(json.dumps(d))
" > "${fixture}"
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${fixture}"
  assert_failure
  assert_output --partial "NFR2a"
  rm -f "${fixture}"
}

# ... follow same pattern for TS-240c (revokeRefreshToken: false),
#     TS-240d (refreshTokenMaxReuse: 1), TS-240e (missing revokeRefreshToken),
#     TS-240f (missing refreshTokenMaxReuse)
```

Key pattern: `assert_output --partial "NFR2a"` (or "FR9") confirms the error message is informative. Always `rm -f "${fixture}"` **after** the assertion so the file is available for diagnosis on failure (same pattern as TS-201d in `realm-import.bats`).

### File Structure

Files to **MODIFY** (existing):
- `keycloak/realm-export.json` — add two fields: `revokeRefreshToken` and `refreshTokenMaxReuse`
- `scripts/lint-realm-export.py` — extend with value-validation block (Task 2)
- `tests/integration/realm-import.bats` — add TS-241a through TS-241f (Task 4)

Files to **CREATE** (new):
- `tests/unit/realm-session-config.bats` — unit tests for lint value-validation (Task 3)

Files to **MODIFY** with documentation additions:
- `keycloak/REALM-EXPORT-NOTES.md` — **extend** (not replace) with a new `## Story 2.4` section covering session rationale, per-client logout config, and FR45 docs (Tasks 1.4, 5.3, 6.1–6.2); this file already exists and is in the gitleaks path allowlist (`.gitleaks.toml` `paths = [...]`)

Files that are **NOT touched** in this story:
- `compose.yaml`, `keycloak/Dockerfile`, `nginx/`, `postgres/` — no changes
- `admin/` — does not exist yet; no changes
- `keycloak/themes/` — the branded "Signed out" theme surface is Story 2.5
- `.github/workflows/ci.yml` — no changes; realm-lint CI job from Story 1.5 already covers `scripts/lint-realm-export.py`
- `lefthook.yml` — no changes; pre-commit hook from Story 1.5 already runs `realm-lint`

### CI Coverage Note

The realm-lint CI job (Story 1.5, job `realm-lint` in `.github/workflows/ci.yml`) already runs `python3 scripts/lint-realm-export.py` on every push. After Task 2, it will also enforce the new value-validation rules automatically without any CI config changes.

**Note on CI branch triggers (deferred from Story 1.2):** The CI trigger branch list (`main`, `develop`, `story-*`) does not match the actual branch model (`main`, `dev`, `epic-N`). This is pre-existing deferred work from Story 1.2 and is out of scope for this story. The CI gate still runs on PRs to `main` — the merge path always triggers it. Branch name reconciliation (`develop`→`dev`, add `epic-*`) should be addressed in a CI maintenance pass.

### Testing Approach

| Test | File | Type | Guard |
|---|---|---|---|
| Lint green path (Task 3.1 TS-240a) | `tests/unit/realm-session-config.bats` | Unit | None (always runs) |
| Lint rejects bad values (TS-240b–f) | `tests/unit/realm-session-config.bats` | Unit | None (always runs) |
| Live realm: revokeRefreshToken=true (TS-241a) | `tests/integration/realm-import.bats` | Integration | `INTEGRATION=1` |
| Live realm: refreshTokenMaxReuse=0 (TS-241b) | `tests/integration/realm-import.bats` | Integration | `INTEGRATION=1` |
| Live realm: accessTokenLifespan≤900 (TS-241c) | `tests/integration/realm-import.bats` | Integration | `INTEGRATION=1` |
| .well-known has end_session_endpoint (TS-241d) | `tests/integration/realm-import.bats` | Integration | `INTEGRATION=1` |
| End Session endpoint reachable (TS-241e) | `tests/integration/realm-import.bats` | Integration | `INTEGRATION=1` |
| FR45 session-ID change (TS-241f) | `tests/integration/realm-import.bats` | Integration | Always skip (manual) |

### Dependency Context

- **Depends on Epic 1 complete** (per dependency-graph.md): the Docker Compose stack, realm-export.json baseline, and CI gate are all in place.
- **Does NOT depend on 2.1, 2.2, 2.3** — can run in parallel; no clients need to be registered for this story's scope.
- **Story 2.2** (OIDC PKCE login) MUST add `post.logout.redirect.uris` to the admin-app client when it registers that client. The exact attribute names are documented in `keycloak/REALM-EXPORT-NOTES.md` (Story 2.4 section, Per-Client Logout Configuration).
- **Story 2.5** (Branded Deep Sea login theme) implements the branded "Signed out" Keycloak theme page — one of the nine UX-DR3 surfaces referenced in AC5.

### Commit Style

Follow the established pattern from Epic 1 stories:
```
feat(story-2-4): add refresh token rotation and session lifetime validation
```

### Key References

- Keycloak 26.x Session Management docs: `https://www.keycloak.org/docs/latest/server_admin/#_timeouts`
- Keycloak 26.x RP-Initiated Logout: `https://www.keycloak.org/docs/latest/server_admin/#_oidc_logout`
- FR7, FR8, FR9, FR10, FR45: `_bmad-output/planning-artifacts/epics.md` — Requirements Inventory section
- NFR2a: `_bmad-output/planning-artifacts/epics.md` — NonFunctional Requirements section A
- UX-DR3: `_bmad-output/planning-artifacts/epics.md` — UX Design Requirements
- Architecture session design: `_bmad-output/planning-artifacts/architecture.md` — Decision 3 → Authentication & Security
- Existing lint script: `scripts/lint-realm-export.py`
- Existing integration tests: `tests/integration/realm-import.bats`
- Existing test helpers: `tests/helpers/common.bash`
- Existing realm doc (extend, do not replace): `keycloak/REALM-EXPORT-NOTES.md`
- Deferred-work resolved by this story: `_bmad-output/implementation-artifacts/deferred-work.md` → "Realm-lint required-field check is presence-only"

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-2-4-sso-session-lifetimes-rp-initiated-logout.md`
- Unit tests: `tests/unit/realm-session-config.bats`
- Integration tests: `tests/integration/realm-import.bats` (extended — TS-241a through TS-241f added; TS-201d extended)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

### File List
