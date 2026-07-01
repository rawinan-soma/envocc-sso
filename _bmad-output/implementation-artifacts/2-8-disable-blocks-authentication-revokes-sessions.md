---
baseline_commit: 67899fd
---

# Story 2.8: Disable blocks authentication & revokes sessions

Status: ready-for-dev

## Story

As the organization,
I want a disabled account locked out instantly,
so that a leaver cannot authenticate anywhere.

**Epic:** 2 — Staff Authentication & SSO Identity
**GH Issue:** #14

**Scope boundary:** This story proves and hardens the disable→lockout→revocation pipeline that Story 2.1 already declared (`enabled: false` = `disabled` state) and that Story 2.4 already built the revocation primitives for (refresh-token family revocation, server-side sessions). It does **NOT** build the HR Admin UI disable button (Epic 4, Story 4.5) — that is a future SvelteKit admin-app surface that will call the same Admin REST API this story tests. It does **NOT** build the "System Admin force-terminate sessions" UI (Epic 5) — only the underlying Admin REST API mechanism this story verifies is the one that UI will call. The deliverables are: an integration test suite proving FR25 (auth blocked) and FR46 (session/token revocation) hold via direct Keycloak Admin REST API calls, and documentation of the exact Admin REST sequence + residual-window caveat that any future caller (HR Admin UI, ops runbook) MUST follow.

## Acceptance Criteria

**AC1 — Disabled account cannot authenticate at any client (FR25)**
Given an account set to disabled (`enabled: false`),
When it attempts to authenticate at any integrated app (any registered OIDC client in the realm),
Then all new authentication is blocked immediately — the token endpoint rejects password/ROPC grant with an error, and no new authorization code can be exchanged for tokens on behalf of that user, across every client, not just one.

**AC2 — Disabling revokes all outstanding refresh-token families and invalidates all server-side sessions (FR46)**
Given an account is disabled,
When the transition completes (`PUT /admin/realms/envocc/users/{id}` with `{"enabled": false}`),
Then all outstanding refresh-token families for that subject are revoked (a previously-valid refresh token can no longer mint a new access token) and all server-side SSO sessions for that subject are invalidated (the Admin REST API reports zero active sessions for the user immediately after disable).

## Tasks / Subtasks

- [ ] **Task 0 — PREREQUISITE: re-add `test-ropc-client` to `keycloak/realm-export.json` (blocks Tasks 3 & 4)**
  - [ ] 0.1: **Verify before assuming it exists.** Story 2.1's file (`_bmad-output/implementation-artifacts/2-1-canonical-identity-model-lifecycle-states.md`, Task 1.5/1.7/File List) claims `test-ropc-client` was added to `keycloak/realm-export.json`, but it is **NOT present in the current `keycloak/realm-export.json` at this story's baseline** — confirmed by inspection (`python3 -c "import json; print([c['clientId'] for c in json.load(open('keycloak/realm-export.json'))['clients']])"` returns only `test-oidc-client`) and by `git log --all -p -- keycloak/realm-export.json | grep test-ropc-client` returning zero hits across the entire history. This is a pre-existing documentation/reality mismatch inherited from Story 2.1 (the existing `TS-210d` test in `tests/integration/identity-model.bats` that depends on this client will currently fail with "test-ropc-client not found in realm — re-import"). Tasks 3 and 4 below are entirely ROPC-based and cannot run without this client — **do this first**.
  - [ ] 0.2: Re-add `test-ropc-client` to the `clients` array in `keycloak/realm-export.json`, matching the Story 2.1 spec exactly: `clientId: "test-ropc-client"`, `enabled: true`, `protocol: "openid-connect"`, `publicClient: false` (confidential — direct grants require client auth), `standardFlowEnabled: false`, `directAccessGrantsEnabled: true`, `serviceAccountsEnabled: false`, `secret: ""` (zeroed — populated from `.env` `KC_TEST_ROPC_CLIENT_SECRET` at test runtime, never committed with a real value).
  - [ ] 0.3: **Read `keycloak/IDENTITY-MODEL.md` Section 7 ("Test-Only ROPC Client") before adding it** — it already documents this exact client's intended shape and states plainly: `Production use: FORBIDDEN — remove before production deployment`. Also read the open, unresolved item in `_bmad-output/implementation-artifacts/deferred-work.md` ("Deferred from: code review of story-2.1") which flags that nothing mechanically prevents this ROPC/confidential client from being imported into a non-dev environment — it is a credential-stuffing surface if it ever ships to production. Re-adding it here does NOT resolve that deferred item; it only restores the test fixture Story 2.1 already committed to building. Do not attempt to fix the production-hardening gap in this story — stay in scope (note this explicitly in the PR/commit description so a reviewer doesn't conflate "re-added a test client" with "closed the deferred production-hardening item").
  - [ ] 0.4: Run `python3 -m json.tool keycloak/realm-export.json > /dev/null` (valid JSON) and `gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml --redact` (must exit 0 — the secret field is zeroed) before proceeding to Task 1.
  - [ ] 0.5: Run the existing `tests/integration/identity-model.bats` `TS-210d` test locally with `INTEGRATION=1` against a freshly rebuilt stack (`docker compose down -v && docker compose up --build`) to confirm re-adding the client also fixes that pre-existing, previously-broken test as a side effect — this is a welcome regression-fix bonus, not new scope.

- [ ] **Task 1 — Verify and document realm-wide auth blocking on `enabled: false` (AC1, FR25)**
  - [ ] 1.1: Confirm (do not reconfigure — this is Keycloak's built-in, non-configurable behavior) that `enabled: false` on a user blocks: (a) the Authorization Code + PKCE browser login flow, (b) the ROPC/password grant used by `test-ropc-client` (Story 2.1) and `test-oidc-client` where applicable, (c) token refresh via `grant_type=refresh_token`. This is a realm-wide, per-user property — it is NOT scoped to a single client, so "blocked at every integrated app" (FR25) requires no per-client configuration.
  - [ ] 1.2: Add a `## Story 2.8 — Disable Blocks Authentication & Revokes Sessions` section to `keycloak/REALM-EXPORT-NOTES.md` documenting: the `enabled: false` mechanism, that it is realm-wide (all clients), the exact Admin REST call, and cross-reference to `keycloak/IDENTITY-MODEL.md` Section 4/5 (already documents this transition from Story 2.1 — do not duplicate, link to it).
  - [ ] 1.3: Update `keycloak/IDENTITY-MODEL.md` Section 5 ("active → disabled") to note that this story (2.8) is the one that adds automated proof (integration tests) that the transition has the stated effect — the doc itself does not change substantively, add one cross-reference line. **Also fix a pre-existing self-contradiction while here:** `keycloak/IDENTITY-MODEL.md` line ~100 currently states `"The disabled state is irreversible via this API (re-enabling requires setting enabled: true, which is driven by a separate HR Admin action)."` — this is internally contradictory (it calls the transition "irreversible" in the same sentence that describes exactly how to reverse it). Reword to something unambiguous, e.g.: `"There is no dedicated 'un-disable' endpoint distinct from the disable endpoint — re-enabling uses the same PUT /users/{id} call with {\"enabled\": true}. This is a deliberate symmetry, not an irreversible state: a disabled account CAN be re-enabled by a future HR Admin action (Story 4.5 scope)."` This correction is a prerequisite for Task 3.5/TS-280d below, which tests exactly this re-enable path — the story's own claim that re-enabling is expected/valid behavior must not conflict with the doc it cites.

- [ ] **Task 2 — Add `POST /admin/realms/envocc/users/{id}/logout` to the documented disable procedure (AC2, FR46)**
  - [ ] 2.1: Document in `keycloak/REALM-EXPORT-NOTES.md` (Story 2.8 section) that the **complete disable procedure any caller (future HR Admin UI, System Admin force-terminate UI, or an ops runbook) MUST perform is TWO calls, not one**:
    1. `PUT /admin/realms/envocc/users/{id}` body `{"enabled": false}` — blocks all new authentication (AC1). Setting `enabled: false` alone does **NOT** retroactively revoke already-issued tokens or kill already-established sessions — Keycloak only checks `enabled` at authentication/token-issuance time.
    2. `POST /admin/realms/envocc/users/{id}/logout` (no body) — this is the Keycloak Admin REST endpoint that force-invalidates every server-side SSO session for that user AND revokes the associated refresh tokens by removing the session backing them. This is the mechanism that satisfies FR46 and is also the exact endpoint the future "System Admin force-terminate active sessions" capability (FR46 second clause, Epic 5) will reuse.
  - [ ] 2.2: Document response codes: `PUT /users/{id}` returns `204 No Content`; `POST /users/{id}/logout` returns `204 No Content` and is idempotent (safe to call even if the user has zero active sessions).
  - [ ] 2.3: Note explicitly that **call order matters for defense-in-depth but does not create a race window that matters in practice**: disabling first (step 1) ensures that even if a session-kill (step 2) is delayed, no *new* tokens can be minted in between; but a session/refresh token issued a moment before step 1 remains technically valid until step 2 completes. Both calls should be issued back-to-back by any caller (ideally in the same request handler / transaction-like sequence) — this is a documentation/procedure requirement in this story since no admin-app caller exists yet.
  - [ ] 2.4: Add a "Residual window — accepted (FR25)" note citing the PRD: an already-authenticated *relying-party's own local session* (e.g., a pilot app's cookie-based session established from a prior valid token) is bounded by that app's own session lifetime, not by this SSO revocation — integrating apps are contractually required (FG-7/FR41 integration guide, Epic 6) to bound their local session to the token lifetime. This is a **named, accepted residual**, not a defect of this story — do not attempt to "fix" it by inventing a push-based revocation/webhook mechanism; that is out of scope.

- [ ] **Task 3 — Integration tests: AC1 disabled account cannot obtain new tokens (any grant, any client)**
  - [ ] 3.1: Create `tests/integration/account-disable.bats` following the exact conventions of `tests/integration/identity-model.bats` (Story 2.1) and `tests/integration/realm-import.bats`: `bats_load_library 'bats-support'`, `bats_load_library 'bats-assert'`, `load '../helpers/common'`, `setup()` guard `if [[ -z "${INTEGRATION}" ]]; then skip "..."; fi`, and a `teardown()` that deletes any test user created via a test-scoped `_TEST_USER_ID` variable (mirror the Story 2.1 cleanup pattern exactly).
  - [ ] 3.2: **`[P0][TS-280a]` Active user can authenticate (control/baseline)** — Using `get_admin_token`, create a test user in `active` state (`enabled: true`, `emailVerified: true`, no `requiredActions`), set a temporary password via `PUT /users/{id}/reset-password` with `{"type": "password", "value": "Test!Disable123", "temporary": false}`. Attempt ROPC login via `POST /realms/envocc/protocol/openid-connect/token` using `test-ropc-client` (Story 2.1) with the correct client secret from `.env` (`KC_TEST_ROPC_CLIENT_SECRET`, populate the client secret at runtime via `PUT /clients/{id}` exactly as the Story 2.1 review-fix pattern does — see Dev Notes). Assert HTTP 200 with a non-empty `access_token`. This is the control that proves the subsequent disable test is meaningful.
  - [ ] 3.3: **`[P0][TS-280b]` Disabled account cannot obtain a new token via ROPC/password grant (AC1)** — Reusing the TS-280a user, disable it: `PUT /users/{id}` with `{"enabled": false}`. Re-attempt the identical ROPC login as 3.2. Assert the token endpoint returns HTTP 400/401 (Keycloak returns `invalid_grant` / `Account is disabled`), NOT 200. Assert the response body does NOT contain an `access_token`.
  - [ ] 3.4: **`[P1][TS-280c]` Disabled account is rejected across multiple registered clients, not just one** — `test-oidc-client` has `directAccessGrantsEnabled: false` (confirmed in `keycloak/realm-export.json`), so it cannot be used for a second ROPC-based behavioral proof, and adding a second ROPC-capable client purely for this P1 test is explicit scope creep beyond Task 0's fixture restoration (do NOT add one). The **required minimum for this test** is the structural proof: assert via Admin REST `GET /users/{id}` that `enabled: false` is a **user-level** field with no per-client scoping field anywhere in the user or client objects (inspect the JSON shape directly), and cite `keycloak/IDENTITY-MODEL.md` Section 4 for the architectural claim that this is realm-wide by construction, not per-client config. Document this reasoning inline in the test's comment header. This is sufficient for a P1 test — do not attempt a second behavioral client-based proof in this story.
  - [ ] 3.5: **`[P1][TS-280d]` Re-enabling restores authentication** — Reusing the TS-280b user, re-enable it (`PUT /users/{id}` with `{"enabled": true}`), re-attempt ROPC login, assert HTTP 200 with a valid `access_token`. This confirms disable is reversible via the same `PUT /users/{id}` call (see the corrected wording in `keycloak/IDENTITY-MODEL.md` from Task 1.3 — re-enabling is a valid, expected HR Admin action, Story 4.5 scope) and that the test's disable assertion in TS-280b was really testing `enabled`, not some other failure mode.

- [ ] **Task 4 — Integration tests: AC2 refresh-token family revocation and server-side session invalidation on disable**
  - [ ] 4.1: **`[P0][TS-280e]` A previously-issued refresh token stops working after disable** — Create and activate a test user (as in 3.2), authenticate via ROPC against `test-ropc-client` and capture BOTH `access_token` and `refresh_token` from the 200 response (Story 2.4 config guarantees a `refresh_token` is issued and rotates on use — `revokeRefreshToken: true`, `refreshTokenMaxReuse: 0`). Disable the user (`PUT /users/{id}` `{"enabled": false}`) then immediately call `POST /users/{id}/logout` (Task 2 procedure). Attempt `POST /realms/envocc/protocol/openid-connect/token` with `grant_type=refresh_token` and the captured `refresh_token`. Assert HTTP 400/401 `invalid_grant` — the refresh token no longer mints a new access token. This is the direct proof of FR46's "revokes all outstanding refresh-token families."
  - [ ] 4.2: **`[P0][TS-280f]` Admin REST reports zero active sessions for the user immediately after disable+logout** — Reusing the TS-280e user (post-disable, post-`/logout`), call `GET /admin/realms/envocc/users/{id}/sessions`. Assert the response is an empty JSON array `[]`. This is the direct proof of FR46's "invalidates all server-side sessions for that subject."
  - [ ] 4.3: **`[P1][TS-280g]` `enabled: false` alone (without the `/logout` call) does NOT retroactively kill an already-issued session** — Create/activate/authenticate a test user, capture the refresh token, disable the user via `PUT /users/{id}` `{"enabled": false}` ONLY (deliberately skip `/logout`), then immediately call `GET /admin/realms/envocc/users/{id}/sessions` and assert the session list is **still non-empty** (i.e., `enabled: false` alone does not auto-terminate sessions). This is a **documentation-proving** test: it demonstrates why Task 2's two-call procedure is mandatory, not optional, and guards against a future regression where someone "simplifies" the disable procedure to a single `PUT` call. Follow with a cleanup call to `POST /users/{id}/logout` before `teardown()` deletes the user (avoid leaking a live session past the test).
  - [ ] 4.4: **`[P1][TS-280h]` `/logout` endpoint is idempotent and safe on a user with zero sessions** — Call `POST /users/{id}/logout` twice in a row on a freshly created (never-authenticated) test user. Assert both calls return `204 No Content` with no error — this is required because a future HR Admin "disable" action must be safe to call even on a `pending` account that never logged in.

- [ ] **Task 5 — Verify agentic-build gate passes (AR8)**
  - [ ] 5.1: Run `python3 scripts/lint-realm-export.py` from repo root — must exit 0 (Task 0's `test-ropc-client` re-addition must not break existing lint checks; no new lint rules are added by this story — see Dev Notes).
  - [ ] 5.2: Run `gitleaks protect --staged --redact` on staged changes — must exit 0 (no secrets; the re-added `test-ropc-client` secret must be zeroed exactly as Story 2.1 specified, and `REALM-EXPORT-NOTES.md`/`IDENTITY-MODEL.md` documentation-only changes are already gitleaks-allowlisted).
  - [ ] 5.3: Run `semgrep scan --config auto --error` — must exit 0.
  - [ ] 5.4: Run `bats tests/integration/account-disable.bats` locally with `INTEGRATION=1` against a live stack (`docker compose up --build`) — all 8 tests (TS-280a–TS-280h) must pass.
  - [ ] 5.5: Push branch; confirm CI jobs pass (`realm-lint`, `sast`, `gitleaks`; integration tests are NOT run in CI per the existing pattern — see Dev Notes CI Coverage).

## Dev Notes

### Overview — what this story is and is not

This story is **pure verification + documentation, plus one test-fixture restoration**, structurally similar in kind to Story 2.4 (which also added zero new realm-config *behavior* for its FR45/FR7 clauses and instead verified+documented built-in Keycloak behavior, only adding real config for FR9's rotation fields). Story 2.8's situation is even more concentrated on the "verify and document" side, with one caveat:

- **AC1 (FR25 — auth blocked)** requires **zero NEW realm-export.json config**. `enabled: false` blocking all authentication realm-wide is native, non-configurable Keycloak behavior, already declared as the `disabled` state's definition in `keycloak/IDENTITY-MODEL.md` (Story 2.1, Section 4): `"disabled" | enabled: false | any | No — Keycloak immediately rejects all authentication attempts and revokes active sessions/tokens.` This story's Task 3 is the **automated proof** that claim is true, across the grant types this realm actually exposes — but that proof depends on the `test-ropc-client` test fixture, which Story 2.1 specified but never actually committed (Task 0 fixes this first — see below).
- **AC2 (FR46 — revocation)** requires **zero NEW realm-export.json config** either, but it DOES require documenting (Task 2) and testing (Task 4) a **second Admin REST call** — `POST /users/{id}/logout` — that `keycloak/IDENTITY-MODEL.md`'s existing "active → disabled" transition example (`PUT /users/{id}` with `{"enabled": false}` alone) does **not** mention. This is the single most important correction/addition this story makes: **the one-call disable procedure documented in Story 2.1 is necessary but not sufficient for FR46.** TS-280g (Task 4.3) is written specifically to prove this gap exists and guard against it recurring.

**No SvelteKit/admin-app code is written in this story.** `admin/` does not exist yet (created in Story 4.1, per `_bmad-output/planning-artifacts/architecture.md`'s Complete Project Tree and Decision Impact Analysis implementation sequence — HR features are sequence-step 7, after the admin scaffold in step 4). The future HR Admin "disable" button (Story 4.5) and the System Admin "force-terminate sessions" action (Epic 5, FR46 second clause) will both call the exact two-call Admin REST sequence this story documents and tests — this story is their contract.

### Current state of `keycloak/realm-export.json` — `test-ropc-client` is MISSING, not present (fix in Task 0)

Story 2.1's own story file claims `test-ropc-client` was added to `keycloak/realm-export.json` (Task 1.5/1.7) and that it backs the existing `TS-210d` test in `tests/integration/identity-model.bats`. **This is not true of the actual file at this story's baseline** — inspect `keycloak/realm-export.json`'s `clients` array directly before writing any test in Task 3/4; at the time this story was authored it contains only `test-oidc-client`. Task 0 above re-adds `test-ropc-client`; do that first, or every ROPC-based test in Tasks 3 and 4 will fail with a "client not found" error that has nothing to do with the disable/revocation logic actually under test.

### Current state of the two files this story documents (READ before editing — do not replace, extend)

**`keycloak/IDENTITY-MODEL.md`** (created Story 2.1) already contains, verbatim, in its Section 4 (Lifecycle State Machine) and Section 5 (Admin REST API Transitions):

```
| `disabled` | `false` | any | **No** | User disabled by HR Admin (Story 2.8). Keycloak immediately
rejects all authentication attempts and revokes active sessions/tokens. |
```
and
```
### active → disabled
Driven by the Story 2.8 HR Admin disable action:
PUT /users/{id}
{ "enabled": false }
Response: 204 No Content. All active sessions and tokens are immediately invalidated.
```

**This second code block is the exact claim Task 4.3 (TS-280g) proves is INCOMPLETE** — `PUT /users/{id}` with `{"enabled": false}` alone does NOT immediately invalidate sessions/tokens; it only blocks *new* authentication. The session/token invalidation requires the additional `POST /users/{id}/logout` call. Task 1.3 requires adding a corrective cross-reference in `IDENTITY-MODEL.md` pointing to the Story 2.8 section in `REALM-EXPORT-NOTES.md` — do not silently leave the original (slightly imprecise) claim unqualified.

**`keycloak/REALM-EXPORT-NOTES.md`** (created Story 1.2, extended Stories 2.1, 2.4) is the established, gitleaks-allowlisted location for ALL realm-config rationale documentation (JSON has no comments — see the file's own header note reiterated in Story 2.4's Dev Notes). This story adds a new `## Story 2.8 — Disable Blocks Authentication & Revokes Sessions` section, following the exact heading/table style of the existing `## Story 2.4 — Session, Lifetimes & Refresh Token Rotation` section. Do NOT create a new `.md` file for this — `REALM-EXPORT-NOTES.md` is the single source of truth for realm-behavior documentation and is already in `.gitleaks.toml`'s path allowlist.

### The Admin REST API sequence — exact reference

Base path: `http://localhost:8080/admin/realms/envocc` (same base used by every existing integration test, via `get_admin_token` in `tests/helpers/common.bash`).

**Step 1 — Block new authentication (FR25):**
```http
PUT /admin/realms/envocc/users/{id}
Authorization: Bearer <admin_token>
Content-Type: application/json

{ "enabled": false }
```
Response: `204 No Content`.

**Step 2 — Revoke sessions + refresh-token families (FR46):**
```http
POST /admin/realms/envocc/users/{id}/logout
Authorization: Bearer <admin_token>
```
Response: `204 No Content`. No request body. Idempotent — safe to call on a user with zero active sessions (Task 4.4 / TS-280h proves this).

**Verification call (used by tests, and usable operationally to confirm revocation took effect):**
```http
GET /admin/realms/envocc/users/{id}/sessions
Authorization: Bearer <admin_token>
```
Returns a JSON array of session objects; `[]` after successful disable+logout.

This `GET .../sessions` endpoint is also the mechanism the future System Admin "force-terminate active sessions" UI (Epic 5, FR46 second clause) will use to list sessions before/after a force-terminate action — this story's Task 4.2 test is effectively also a smoke test of that future capability's underlying API.

**Note on a discrepancy with the test-design doc:** `_bmad-output/test-artifacts/test-design/test-design-epic-2.md`'s R-006 mitigation strategy (line ~426) describes the mechanism as `PUT /admin/realms/{realm}/users/{id}/logout` + `DELETE /admin/realms/{realm}/users/{id}/sessions`. Those exact verb/path combinations are **not** correct against Keycloak's actual Admin REST API (there is no `DELETE .../sessions` endpoint for this purpose, and the logout call is `POST`, not `PUT`) — the test-design doc used imprecise verbs when it was authored. This story's Task 2 documents the **verified-correct** contract (`POST /users/{id}/logout`, `GET /users/{id}/sessions`), confirmed against Keycloak's Admin REST API during story creation. Do not follow the test-design doc's literal HTTP verbs; follow this story's Task 2 / Admin REST API sequence instead.

### Why ROPC-only proof is sufficient for AC1 despite TOTP/MFA existing (Story 2.6, separate concern)

The Epic 2 test-design doc's P1 entry for AC1 (line 217) says "Disabled account blocked from new password+TOTP login," which could read as requiring a full browser-flow, TOTP-inclusive test. That is out of scope here: `enabled: false` is checked by Keycloak's authentication pipeline **before** the credential/MFA chain runs at all — it is a gate in front of the entire login flow, not a step within it. TOTP enforcement is Story 2.6's orthogonal concern (does an *active* account require a second factor); it has no bearing on whether a *disabled* account can start authenticating in the first place. ROPC via `test-ropc-client` is sufficient proof of the `enabled` gate itself. Full password+TOTP browser-flow proof would require Playwright infrastructure that does not exist yet in this repo (planned for the admin app, Epic 4+) — do not attempt to add browser automation in this story.

### Test infrastructure — reuse exactly, do not invent new patterns

This repo has an established, consistent BATS integration-test pattern used identically across `tests/integration/realm-import.bats` (Story 1.2/2.4), `tests/integration/identity-model.bats` (Story 2.1), `tests/integration/oidc-pkce-flow.bats`, `tests/integration/nonce-state.bats`, `tests/integration/token-signing.bats`, and `tests/integration/jwks-discovery.bats`. Follow it exactly for `tests/integration/account-disable.bats`:

- `bats_load_library 'bats-support'` / `bats_load_library 'bats-assert'`
- `load '../helpers/common'` — provides `get_admin_token`, `wait_for_healthy`, `fetch_realm_json_to_tmpfile`, `PROJECT_ROOT`
- `setup()` guard: `if [[ -z "${INTEGRATION}" ]]; then skip "Integration tests skipped — set INTEGRATION=1 and ensure stack is running"; fi`
- Test ID format: `[P0|P1|P2][TS-280x]` — **280-series** for Story 2.8 (Story 2.1 used 210-series, Story 2.4 used 240/241-series; the pattern is `TS-{epic}{story}{letter}` i.e. story 2.8 → `28` → `280a`, `280b`, ...).
- Mandatory `teardown()` per Story 2.1's pattern: a test-scoped `_TEST_USER_ID` variable, initialized empty, set immediately after user creation, and in `teardown()` if non-empty, `DELETE /admin/realms/envocc/users/${_TEST_USER_ID}`. This guarantees cleanup even on assertion failure mid-test.
- Admin token pattern: `token=$(get_admin_token) || fail "Could not obtain admin token"`.

**Critical gotcha from Story 2.1's own code-review history — the `test-ropc-client` secret is zeroed in `realm-export.json` on disk.** The Story 2.1 review fix pattern (already applied and working in `tests/integration/identity-model.bats`) is: at test runtime, `PUT /admin/realms/envocc/clients/{client-uuid}` to set the client's `secret` field to the value read from `.env`'s `KC_TEST_ROPC_CLIENT_SECRET`, THEN perform the ROPC grant with that same secret. Do not assume the zeroed on-disk secret works — it will produce a 401 (client auth failure) that looks like — but is NOT — the disabled-account rejection this story is trying to prove. Copy this exact runtime-secret-population pattern from `tests/integration/identity-model.bats` (search for its `PUT /clients/` call before writing TS-280a).

**`test-ropc-client` config (from `keycloak/realm-export.json`, Story 2.1):** `directAccessGrantsEnabled: true`, `standardFlowEnabled: false`, secret populated from `.env` `KC_TEST_ROPC_CLIENT_SECRET` at test runtime. This is the ONLY ROPC-capable client in the realm — use it for all ROPC-based assertions in this story.

**`test-oidc-client` config (from `keycloak/realm-export.json`, Story 2.2):** `publicClient: true`, `standardFlowEnabled: true`, `directAccessGrantsEnabled: false`, PKCE `S256` enforced. This client does NOT support ROPC — it is used for browser-flow PKCE tests elsewhere (`tests/integration/oidc-pkce-flow.bats`). Task 3.4 (TS-280c) uses the structural-proof approach for this reason — do not attempt an ROPC grant against `test-oidc-client`, and do not add a second ROPC-capable client or browser-flow automation to work around this (see Task 3.4's exact required-minimum wording).

**Refresh-token capture pattern for TS-280e:** the ROPC token response already includes `refresh_token` because Story 2.4 set `revokeRefreshToken: true` (family tracking) — extract it the same way `access_token` is extracted in `get_envocc_test_token`/`get_admin_token` (pipe the curl response through `python3 -c "import json,sys; print(json.load(sys.stdin)['refresh_token'])"`). Do not add a new shared helper function to `common.bash` unless a second story would also need it — inline the extraction in the test file, matching the existing convention where `common.bash` only holds helpers used by 3+ call sites.

### Why no NEW realm-export.json config values are needed (contrast with Story 2.4) — Task 0's edit is a test-fixture restoration, not new config

Story 2.4 needed real config changes (`revokeRefreshToken: true`, `refreshTokenMaxReuse: 0`) because *rotation-on-use with family-revoke-on-replay* is an opt-in Keycloak feature (defaults to `false`/non-rotating). Story 2.8's AC1/AC2 behaviors are different in kind:

- `enabled: false` blocking authentication is **not** a feature flag — it is core to how Keycloak's authentication pipeline checks the user object before issuing any token, unconditionally, for every realm.
- `POST /users/{id}/logout` (session/refresh-token revocation) is a **standing Admin REST API endpoint**, always available, not something a realm setting turns on or off.

Task 0's `test-ropc-client` re-addition to `keycloak/realm-export.json` is orthogonal to this — it is restoring a missing **test fixture** (already specified by Story 2.1, never actually committed), not adding new production-relevant config. There is therefore no `lint-realm-export.py` change in this story (unlike Story 2.1's and 2.4's `REQUIRED_FIELDS`/`REQUIRED_VALUES` additions) — nothing new needs to be asserted about the realm-export.json content beyond what Story 2.1 already specified for this client. Do not add a lint check for something that isn't a security-relevant config value.

### CI Coverage — integration tests are not run in CI (existing, pre-existing gap, out of scope)

Per the CI job list in `.github/workflows/ci.yml` (`gitleaks`, `realm-export-check`, `realm-lint`, `sast`, `admin-app-check`, `format-check`, `dependency-audit`, `language-checks`), **no CI job currently runs `tests/integration/*.bats` against a live Keycloak stack** — the existing integration suites (`realm-import.bats`, `identity-model.bats`, `oidc-pkce-flow.bats`, etc.) are all run manually/locally with `INTEGRATION=1` per their own file headers, same as this story's new file. This is a pre-existing gap from prior stories, not something to fix here — Task 5.5 confirms only the static gates (`realm-lint`, `sast`, `gitleaks`) run in CI for this story; the new BATS integration file is verified locally per Task 5.4.

### File Structure

Files to **CREATE** (new):
- `tests/integration/account-disable.bats` — 8 integration tests (TS-280a–TS-280h), Task 3 + Task 4.

Files to **MODIFY**:
- `keycloak/realm-export.json` — **Task 0 only:** re-add the `test-ropc-client` entry to the `clients` array (it is missing at this story's baseline despite Story 2.1 claiming to have added it — see "Current state of `keycloak/realm-export.json`" above). This is a test-fixture restoration, not new production config; no other realm-export.json fields change (session/lifetime/revocation fields added in Story 2.4 remain untouched).
- `keycloak/REALM-EXPORT-NOTES.md` — append `## Story 2.8 — Disable Blocks Authentication & Revokes Sessions` section (Task 1.2, Task 2). Existing sections (`## Story 2.4 — ...`) are untouched.
- `keycloak/IDENTITY-MODEL.md` — (a) add one corrective cross-reference line in the existing "active → disabled" transition example (Task 1.3), pointing to the two-call procedure now fully documented in `REALM-EXPORT-NOTES.md`; (b) fix the self-contradictory "irreversible" wording near Section 4 (Task 1.3 — see exact replacement text in that task). Do not otherwise rewrite the existing lifecycle table or Section 4/5 structure.

Files that are **NOT touched** in this story:
- `scripts/lint-realm-export.py` — no changes (see "Why no NEW realm-export.json config values are needed" above — Task 0's realm-export.json edit is a test-fixture restoration, not a new lint-worthy security config value).
- `compose.yaml`, `keycloak/Dockerfile`, `nginx/`, `postgres/` — no changes.
- `admin/` — does not exist yet (Story 4.1); do not create or reference it.
- `keycloak/themes/` — no theme changes.
- `.github/workflows/ci.yml`, `lefthook.yml` — no changes; existing gates already cover this story's file types (BATS files are not currently gated in CI per the CI Coverage note above; gitleaks/semgrep/realm-lint already apply generically).
- `tests/integration/identity-model.bats`, `tests/integration/realm-import.bats` — read for pattern reuse, but not modified (this story's tests are additive in a new file, not appended to existing ones, because the subject matter — disable/revoke — is a distinct concern from realm-import baseline (1.2/2.4) or identity-model shape (2.1)).

### Previous Story Intelligence

**From Story 2.1 (Canonical identity model & lifecycle states) — most directly relevant:**
- Defined the exact `enabled`/`emailVerified` truth table this story's tests exercise (`pending`/`active`/`disabled`), and explicitly named Story 2.8 as the owner of the `active → disabled` transition and its "immediately invalidated" claim — this story now fulfills and corrects that forward-reference.
- Established the `test-ropc-client` and the runtime-secret-population pattern (`PUT /clients/{id}` to inject the secret from `.env` before an ROPC grant) — a hard requirement to reuse, discovered via a code-review fix (a naive approach without it fails with 401 client-auth error, easily misread as the intended disabled-account rejection).
- Established the mandatory `teardown()` cleanup pattern with a test-scoped `_TEST_USER_ID` variable, prefixed per-test-function to avoid collisions.
- Test ID series convention: `TS-{story-number-no-dot}{letter}`, e.g. `TS-210a` for story 2.1. This story uses `TS-280a` onward.
- Commit prefix convention: `feat(story-2-N): ...`.

**From Story 2.4 (SSO session, lifetimes & RP-initiated logout) — second most relevant, same shape of story (verify+document built-in behavior, minimal/no new config):**
- Demonstrated the "pure documentation + test" story shape this story follows: Story 2.4 needed real config only for FR9 (rotation), while FR7/FR45 were pure verification of Keycloak defaults, documented in `REALM-EXPORT-NOTES.md` under a per-story `##` section — this story's Task 1/Task 2 follow that exact documentation pattern (new `##` section, not a new file).
- The `revokeRefreshToken: true` / `refreshTokenMaxReuse: 0` config this story's tests depend on (TS-280e captures a rotating refresh token) was added in Story 2.4 and is already live in `keycloak/realm-export.json` — confirmed present via direct inspection (`revokeRefreshToken: true`, `refreshTokenMaxReuse: 0`, `accessTokenLifespan: 300`).
- The `fetch_realm_json_to_tmpfile` helper and JSON-validity/mktemp-failure guards added to `common.bash` in Story 2.4's code review are available for reuse if this story needs to fetch/inspect realm JSON (not currently required by any task above, but available).
- Code-review pattern observed twice now (2.1 and 2.4): reviewers specifically hunt for (a) type-loose boolean/value checks that silently pass on wrong types, and (b) assertions that test the wrong failure mode (e.g., 401 client-auth vs. 400 account-disabled) — write TS-280b/TS-280e assertions to check the **specific** error content (`error_description` containing "disabled" or similar), not just a bare non-200 status, to avoid this exact class of review finding. Keycloak's `invalid_grant` error for a disabled account includes a distinguishing `error_description`; assert on it, not merely on status code.

**From Story 2.5 (Branded Deep Sea login theme) — tangential, no direct dependency, one useful pattern:**
- Confirmed `messages_en.properties` already has an `accountDisabledMessage=This account is not available. Contact HR if you need help.` override wired into the login theme — this is the **browser-flow** user-facing copy for a disabled account attempting interactive login (separate from the ROPC/token-endpoint JSON error this story's tests assert on). No action needed in this story; noted for completeness since AC1 mentions "any integrated app" and a future manual/exploratory check could visually confirm this message renders, but that is out of this story's automated-test scope (no browser automation exists in this repo yet — Playwright is planned for the admin app, Epic 4+).
- Confirms the review pattern: 3-layer adversarial review (Blind Hunter, Edge Case Hunter, Acceptance Auditor) is standard for every story in this epic — expect similar scrutiny.

### Git Intelligence Summary

Inspected `git log --oneline -20` and `git show --stat` for the last 5 merged story commits (2-1 through 2-5, PRs #48–#52):

- **Commit message format:** PR-squash commits use `story-{epic}-{story}-{kebab-title} - fixes #{issue} (#{pr})`, with an inner conventional-commit trailer `feat(story-{epic}-{story}): {short description}` for each logical change within the PR (often 2 commits per story: one ATDD red-phase scaffold commit, one implementation commit). Follow this: `feat(story-2-8): add account-disable integration tests and revocation procedure docs`.
- **Every recent story PR includes a "Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>" trailer** — this is a standing convention for agent-authored commits in this repo, not story-specific; the Dev Agent Record's "Agent Model Used" field should be filled with whatever model actually implements the story.
- **Branch naming:** `story-{epic}-{story}-{kebab-case-title}` (this worktree is already correctly named `story-2.8-disable-blocks-authentication`, consistent with the pattern seen in merged branches `story-2-4-sso-session-lifetimes-rp-initiated-logout`, `story-2-5-branded-deep-sea-login-theme-top-level-anti-phishing`).
- **All 5 recent stories (2.1–2.5) followed a "docs-first" review discipline**: every story's Dev Notes accumulate a "Review Findings" section post-merge documenting Patch/Defer/Dismiss outcomes from a 3-agent adversarial review (Blind Hunter, Edge Case Hunter, Acceptance Auditor) — this story should expect the same review gate before merge; nothing to pre-empt in the story file itself, just confirming the pipeline this story enters.
- **`chore(sprint): mark stories 2-1..2-5 done after batch-1 PRs #48-#52 merged`** confirms 2.1–2.5 are done at the time this story file is authored; 2.6 (TOTP MFA) and 2.7 (brute-force) have worktrees present (`story-2.6-totp-mfa-enforcement`, `story-2.7-brute-force-protection`) but are not yet reflected as merged in this branch's log — this story (2.8) has no hard dependency on 2.6/2.7 completing first (confirmed: AC1/AC2 only depend on Story 2.1's lifecycle model and Story 2.4's session/token infrastructure, both already merged).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.8] — story text, GH issue #14, both ACs verbatim (lines ~526–543)
- [Source: _bmad-output/planning-artifacts/epics.md#FG-3 — Identity & User Store] — FR25 definition (lines ~62–63)
- [Source: _bmad-output/planning-artifacts/epics.md#FG-8 — Operational Security & Account-Protection Controls] — FR46 definition (lines ~94)
- [Source: _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-21/prd.md#FG-3] — FR25 full text including the accepted residual-window clause (line 110)
- [Source: _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-21/prd.md#FG-8] — FR46 full text including the System Admin force-terminate clause (line 160)
- [Source: _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-21/prd.md#UJ-5] — HR offboarding user journey narrative citing FR28/FR25/FR46 together (line 178)
- [Source: _bmad-output/planning-artifacts/architecture.md#Decision 3 — Authentication & Security] — "server-side invalidation on disable/force-logout (FR46)" (line 144)
- [Source: _bmad-output/planning-artifacts/architecture.md#Complete Project Tree] — confirms `admin/` does not exist yet; HR features are implementation-sequence step 7 (lines 260–312)
- [Source: keycloak/IDENTITY-MODEL.md#4. Lifecycle State Machine] — `disabled` state definition, names this story as the disable-action owner
- [Source: keycloak/IDENTITY-MODEL.md#5. Admin REST API Transitions] — the (incomplete, single-call) `active → disabled` example this story's Task 1.3/TS-280g corrects
- [Source: keycloak/REALM-EXPORT-NOTES.md#Story 2.4 — Session, Lifetimes & Refresh Token Rotation] — established per-story documentation-section pattern to follow; refresh-token rotation config this story's tests depend on
- [Source: _bmad-output/implementation-artifacts/2-1-canonical-identity-model-lifecycle-states.md] — test-ropc-client setup, runtime-secret-population pattern, teardown() cleanup pattern
- [Source: _bmad-output/implementation-artifacts/2-4-sso-session-lifetimes-rp-initiated-logout.md] — sibling "verify+document built-in behavior" story shape; revokeRefreshToken/refreshTokenMaxReuse config already live
- [Source: _bmad-output/implementation-artifacts/2-5-branded-deep-sea-login-theme-top-level-anti-phishing.md] — `accountDisabledMessage` login-theme copy (tangential, no action required)
- [Source: keycloak/realm-export.json] — confirmed live values: `revokeRefreshToken: true`, `refreshTokenMaxReuse: 0`, `accessTokenLifespan: 300`; confirmed `test-oidc-client` (directAccessGrantsEnabled: false) present; confirmed `test-ropc-client` is **absent** despite Story 2.1 claiming to have added it (see Task 0 and "Current state of `keycloak/realm-export.json`" above) — re-add it with `directAccessGrantsEnabled: true` per the Story 2.1 spec
- [Source: tests/helpers/common.bash] — `get_admin_token`, `wait_for_healthy`, `fetch_realm_json_to_tmpfile`, `env_setup`, `check_no_pdpa_sensitive_attrs` — reusable helpers
- [Source: tests/integration/identity-model.bats] — exact BATS pattern, teardown convention, runtime client-secret-population fix to copy
- [Source: tests/integration/realm-import.bats] — exact BATS pattern for realm-level Admin REST assertions
- Keycloak Admin REST API reference (user logout / force session invalidation): `POST /admin/realms/{realm}/users/{id}/logout` and `GET /admin/realms/{realm}/users/{id}/sessions` — standard Keycloak 26.x Admin REST endpoints, no version-specific caveats found during research beyond what is already pinned (Keycloak 26.6.x per AR1/Decision 1)

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-2-8-disable-blocks-authentication-revokes-sessions.md`
- Integration tests: `tests/integration/account-disable.bats` (new — TS-280a through TS-280h, Tasks 3 & 4)
- **Red-phase note:** these tests are real assertions (not `skip`-annotated); they are RED because `test-ropc-client` is missing from `keycloak/realm-export.json` (Task 0), not because of missing/placeholder assertions. TS-280c and TS-280h do not depend on Task 0 and can go green independently.

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
