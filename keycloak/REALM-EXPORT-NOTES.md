# Keycloak Realm Export Procedure

This document describes how to export and maintain `keycloak/realm-export.json` as a
version-controlled, secret-free baseline configuration.

> **Scope (updated Story 2.1):** this file now includes the Declarative User Profile
> configuration (minimal attribute set: `username`, `email`, `firstName`, `lastName`)
> and the `test-ropc-client` (integration tests only — see warning below).
> Full realm roles, MFA required actions, ThaiD identity provider, and password policy
> are added in Epic 2 stories (2.2–2.9).
>
> **WARNING — test-ropc-client:** The `test-ropc-client` in `realm-export.json` is
> a **test-only** client used exclusively for integration tests (TS-210d pending-state
> verification). It MUST NOT be deployed to any non-development environment. Its `secret`
> field is intentionally zeroed (`""`) in the exported JSON — populate it from
> `KC_TEST_ROPC_CLIENT_SECRET` in `.env` (never hardcode). Remove this client entirely
> before any production deployment.

---

## How the import works

`keycloak/realm-export.json` is baked into the Keycloak Docker image at build time via
`COPY realm-export.json /opt/keycloak/data/import/realm-export.json` in `keycloak/Dockerfile`.

Keycloak 26 auto-imports all JSON files found in `/opt/keycloak/data/import/` when
started with `--import-realm` (currently in the Dockerfile CMD).

**Import strategy: `IGNORE_EXISTING` (default)**

| Scenario | Behaviour |
|---|---|
| Fresh stack (`docker compose down -v && docker compose up --build`) | Realm is created from `realm-export.json`. |
| Existing stack restart (volumes retained) | Import file is **silently skipped** — the existing realm in the DB is unchanged. |

For strict config-as-code where the file always wins, set the import strategy to
`OVERWRITE_EXISTING`. Keycloak 26 reads this from the `KC_IMPORT_STRATEGY` environment
variable (or `--override true` on the dedicated `kc.sh import` subcommand) — it is **not**
a bare flag you can append to the `start` command, so add it as an env var on the
keycloak service in `compose.yaml` rather than editing the `CMD`:

```yaml
environment:
  KC_IMPORT_STRATEGY: OVERWRITE_EXISTING
```

Note: this overwrites live realm state (including manual Admin UI changes not yet
exported) on every container restart. Verify the flag/env behaviour against your exact
Keycloak version before relying on it. The baseline story uses the default
`IGNORE_EXISTING` — safer for dev stacks.

---

## Updating the realm config

Follow this procedure whenever realm settings change.

### Step 1 — Make the change in the Admin UI

Navigate to the Keycloak Admin UI:
```
http://localhost:8080/admin/master/console/#/envocc
```
Apply the desired change via **Realm Settings** (or clients, roles, etc.).

### Step 2 — Export via Admin UI (recommended — works with a running stack)

1. In the Admin UI: select the `envocc` realm.
2. Go to **Realm Settings** → **Action** dropdown (top-right) → **Export**.
3. On the export dialog:
   - Check **Export clients** to include `test-ropc-client` (Story 2.1+).
   - Uncheck **Export groups and roles** if no groups/roles are defined.
   - Click **Export**.
   - After export: zero out the `secret` field under `test-ropc-client` in the JSON
     (the export will contain the live secret — strip it before committing per Step 4).
4. Save the downloaded file as `keycloak/realm-export.json` (overwrite existing).

### Step 3 — Alternative: CLI export (requires stopped Keycloak)

> **IMPORTANT:** `kc.sh export` cannot run while the Keycloak server process is already
> running. The Quarkus server mode conflicts with the export command in KC 26.
> Use the Admin UI export for a running stack. For CLI export:

```bash
# 1. Stop KC only (keep PostgreSQL running so realm data exists in the DB)
docker compose stop keycloak

# 2. Run export via a new container (same image, no server start)
docker compose run --rm --entrypoint "" keycloak \
  /opt/keycloak/bin/kc.sh export \
  --realm envocc \
  --dir /tmp/export \
  --users skip \
  --db-url-database keycloak \
  --db-username "${KC_DB_USERNAME}" \
  --db-password "${KC_DB_PASSWORD}" \
  --db-url-host postgres

# 3. Copy the exported file out of the container
# (or mount a host volume in step 2 to skip docker cp)

# 4. Restart KC
docker compose start keycloak
```

`--users skip` omits user records — we do not commit user data to the repo.

### Step 4 — Strip secrets from the exported file

Inspect the exported JSON and remove or empty any of the following fields:

| Field | Action |
|---|---|
| `"privateKey": "..."` | Remove the field or set to `""` |
| `"certificate": "..."` | Remove the field or set to `""` |
| `"secret": ["..."]` (array form, in KeyProvider components) | Remove the field or set to `[""]` |
| `"clientSecret": "..."` | Remove the field or set to `""` |
| `"components"` entries with `rsa-generated` or `hmac-generated` key material | Remove the populated value fields (KC regenerates keys on boot) |

> Empty string values (`""`) and absent fields are fine — they are not detected by gitleaks.
> Keycloak regenerates signing keys automatically on every fresh boot.

### Step 5 — Run gitleaks scan

```bash
gitleaks detect \
  --source keycloak/realm-export.json \
  --no-git \
  --config .gitleaks.toml \
  --redact \
  --verbose
```

The scan must exit 0 (no findings) before committing.

### Step 6 — Verify JSON syntax

```bash
python3 -m json.tool keycloak/realm-export.json > /dev/null && echo "Valid JSON"
# or: jq . keycloak/realm-export.json > /dev/null
```

### Step 7 — Commit

The diff should show only realm setting changes — no secret material. Review it before
pushing. The CI `realm-export-check` job in `.github/workflows/ci.yml` re-runs the
gitleaks scan on every PR.

---

## Round-trip test (AC3)

To verify a change survives a full down/up cycle:

```bash
# 1. Apply the change and export as above (Steps 1–6).
# 2. Rebuild and boot from scratch:
docker compose down -v && docker compose up --build

# 3. Confirm the change was imported:
curl -sf http://localhost:8080/realms/envocc/.well-known/openid-configuration | jq '.issuer'
# Expected: "http://localhost:8080/realms/envocc"

# Then verify your specific setting change via Admin UI or REST API.
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Realm not imported after `up --build` | Volumes not removed before `up` — `IGNORE_EXISTING` skips existing realm | Run `docker compose down -v` first, then `up --build` |
| Import silently skipped | Same as above | Same fix |
| `kc.sh export` fails with "server already running" | Keycloak server process is active | Use Admin UI export or run `docker compose stop keycloak` first |
| gitleaks finds a secret | Exported file contains key material | Follow Step 4 to strip the fields, then re-run Step 5 |

---

## Story 2.4 — Session, Lifetimes & Refresh Token Rotation

This section documents the session/lifetime and refresh token rotation configuration
added in Story 2.4, covering FR7, FR8, FR9, FR10, FR45, and NFR2a.

> **Note on documentation placement:** JSON does not support comments. All realm config
> rationale and documentation belongs here in `REALM-EXPORT-NOTES.md`, which is on the
> gitleaks path allowlist (`.gitleaks.toml`). Do NOT add `"_comment"` or any
> pseudo-comment key to `realm-export.json` — Keycloak stores unknown top-level keys in
> its database and may emit them on export, causing diff noise.

### Session and Lifetime Field Reference

The following fields in `keycloak/realm-export.json` govern session and token lifetimes:

| Field | Value | Required by | Rationale |
|---|---|---|---|
| `ssoSessionIdleTimeout` | `1800` (30 min) | FR8 — idle timeout | Session expires after 30 minutes of inactivity; balances security with usability for a staff portal. |
| `ssoSessionMaxLifespan` | `36000` (10 h) | FR8 — absolute timeout | One working day; forces re-authentication after a full shift even if the user remains active. |
| `accessTokenLifespan` | `300` (5 min) | NFR2a — token ceiling | Access and ID tokens expire in 5 minutes, well within the 15-minute hard ceiling (900 s) required by NFR2a. |
| `revokeRefreshToken` | `true` | FR9 — family revocation | Enables Keycloak's refresh token family tracking. When a refresh token is used, the old one is immediately invalidated. If a previously-invalidated token is replayed, Keycloak revokes the **entire token family** and forces re-authentication, defeating refresh token theft. |
| `refreshTokenMaxReuse` | `0` | FR9 — rotate on use | Each refresh token is single-use only (0 = no reuse allowed). Combined with `revokeRefreshToken: true`, every token exchange issues a fresh refresh token and invalidates the old one. |

**Together, `revokeRefreshToken: true` and `refreshTokenMaxReuse: 0` implement FR9:**
"Refresh tokens rotate on every use, and replay of any token in a family revokes the
entire family." Both fields default to `false`/`0` in Keycloak if absent — omitting them
silently leaves refresh tokens non-rotating and vulnerable to replay.

### FR45 — Session Fixation Protection (Keycloak 26.x Built-In)

Keycloak 26.x **regenerates the session ID on every authentication-state transition**
as a non-configurable, built-in security property (FR45):

- After successful password authentication → new `AUTH_SESSION_ID` and `KEYCLOAK_SESSION` cookie values
- After successful MFA (TOTP) verification → new cookie values again

This behavior cannot be disabled and requires no `realm-export.json` configuration.
The server-side session record is maintained in Keycloak's PostgreSQL database (the
`keycloak` DB) — also the default behavior.

**Reference:** Keycloak 26.x Server Administration Guide, section "Sessions":
`https://www.keycloak.org/docs/latest/server_admin/#_timeouts`

**Manual verification procedure (TS-241f):**
See the always-skip test `[P2][TS-241f]` in `tests/integration/realm-import.bats` for
step-by-step instructions to verify session-ID regeneration via browser developer tools
or a cookie-jar HTTP client.

### RP-Initiated Logout — End Session Endpoint (FR10)

Keycloak 26.x publishes the End Session endpoint at:

```
/realms/envocc/protocol/openid-connect/logout
```

This endpoint is listed in `.well-known/openid-configuration` as `end_session_endpoint`
and is available by default — no realm configuration is required to enable it.

**How an RP uses RP-initiated logout:**
1. Construct a request to the End Session endpoint with:
   - `id_token_hint` — the ID token from the current session (strongly recommended)
   - `post_logout_redirect_uri` — must exactly match a URI registered in the client's `postLogoutRedirectUris`
   - `state` — optional, passed through to the redirect
2. Keycloak terminates the SSO session, revokes refresh token families, and redirects.
3. If no `id_token_hint` is provided, Keycloak shows its default "You are logged out" page.

The default "You are logged out" page is acceptable as a placeholder until Story 2.5
implements the branded "Signed out" theme surface (UX-DR3).

### Per-Client Logout Configuration

When registering any OIDC client in `realm-export.json`, set the following client-level
fields to enable proper RP-initiated logout:

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

| Field | Value | Rationale |
|---|---|---|
| `frontchannelLogout` | `false` | Use back-channel logout (preferred for confidential clients — no browser redirect on logout). |
| `post.logout.redirect.uris` | Exact registered URIs | Keycloak validates the `post_logout_redirect_uri` in an RP-initiated logout request against this list. Wildcards are not accepted. A redirect to an unregistered URI will be rejected. |
| `backchannel.logout.session.required` | `"true"` | Ensures the Keycloak session is invalidated when a back-channel logout notification is received. |

**Per-story integration notes:**
- **Story 2.2** (OIDC PKCE login — admin-app client): when the admin-app client is
  registered, it MUST set `post.logout.redirect.uris` to the admin app's signed-out
  route (e.g. `http://localhost:5173/signed-out` for local dev,
  `https://admin.envocc.internal/signed-out` for production).
- **Story 5.3** (OIDC client management UI): exposes per-client logout config
  (`post.logout.redirect.uris`, `frontchannelLogout`) to System Admins via the admin UI.
- **UX-DR3 — Branded signed-out surface**: the Keycloak "Signed out" theme page is
  styled in Story 2.5. Until then, the default "You are logged out" page is acceptable
  as a placeholder.

---

## Story 2.9 — Login with ThaiD (Brokered Federation & Account Linking)

This section documents the `identityProviders`/`authenticationFlows` additions and the
mock OIDC IdP added in Story 2.9, covering FR13a, FR21, FR2/FR12 (top-level redirect,
no framing), and AR8/architecture.md Decision 2 (native Keycloak brokering, no
hand-rolled auth code).

### `identityProviders` — the `thaid` OIDC broker

`realm-export.json` adds one `identityProviders[]` entry, alias `thaid`. Key fields:

| Field | Value | Rationale |
|---|---|---|
| `providerId` | `"oidc"` | Generic OIDC broker — no custom auth code (NFR8, Decision 2). |
| `trustEmail` | `false` | This realm's reconciliation key for ThaiD is the pre-registered federated-identity link by PID, never an email claim asserted by the IdP. |
| `firstBrokerLoginFlowAlias` | `"thaid-first-broker-login"` | The deny-only flow below — only invoked when no existing link is found. |
| `config.clientSecret` | `""` (zeroed) | Mirrors the `test-ropc-client` zeroed-secret pattern (Story 2.1/2.8): committed value is never a real secret; populate at runtime via `PUT /admin/realms/envocc/identity-provider/instances/thaid` with a body containing `config.clientSecret` sourced from `.env`'s `KC_THAID_MOCK_CLIENT_SECRET`. **In practice, this mock IdP does not validate `clientSecret` at all** (confirmed hands-on against `ghcr.io/navikt/mock-oauth2-server` — it is a permissive mock server by design), so the flow works correctly even before this runtime-population step runs; the convention is followed anyway for consistency with the realm's secret-hygiene posture and to keep the swap to a real, secret-validating DOPA/ThaiD endpoint a config-only change later. |

### Why `authorizationUrl` differs from `tokenUrl`/`userInfoUrl`/`jwksUrl`/`issuer`

**This is the single most important, non-obvious design detail in this story's realm
config — read this before changing any of these five URLs.**

All five could naively be set to the same `http://mock-oidc-provider:8080/thaid/...`
container-network address. That is correct for four of them, but **not**
`authorizationUrl`:

- `tokenUrl`, `userInfoUrl`, `jwksUrl`, `issuer` are called **server-to-server by
  Keycloak's own backend**, which runs inside the Docker Compose network — so the
  Compose service DNS name `mock-oidc-provider` resolves correctly there.
- `authorizationUrl` is **never called by Keycloak itself** — Keycloak only ever emits
  an HTTP redirect pointing the *browser* (or, in this story's own BATS-driven tests,
  the host-run curl process acting as a browser surrogate) at this URL. In dev/CI, that
  browser/test-process runs on the **host**, which cannot resolve the Compose-internal
  hostname `mock-oidc-provider` (confirmed hands-on: `ping host.docker.internal` and a
  direct hostname-based identity-provider config both fail to resolve from the host in
  this environment). `authorizationUrl` is therefore set to
  `http://localhost:18080/thaid/authorize` — the mock IdP's published host port
  (Task 0.1) — while the other four use the container-network hostname.

This asymmetry is safe and does not create a validation mismatch: the `iss` claim
embedded in tokens the mock IdP issues is derived from whatever `Host` header reached
its **token** endpoint (confirmed hands-on: the same mock IdP instance, queried with
different `Host` headers, returns a different `issuer` in its discovery document each
time) — and since Keycloak's backend always calls `tokenUrl` via the
`mock-oidc-provider:8080` hostname, the issued token's `iss` always equals the
configured `issuer` field, regardless of which host/port the browser used to reach the
authorize step.

**Keycloak's own URL-scheme validation (why plain `http://` is even allowed here):**
Keycloak rejects non-HTTPS identity-provider endpoint URLs unless the target host
resolves to a loopback/private/link-local address (`SslRequired.EXTERNAL`'s
`isLocal()` check — `org.keycloak.common.enums.SslRequired`, confirmed by reading
Keycloak 26.6.3 source). `localhost` and the `mock-oidc-provider` Compose service name
(which resolves to a private container IP via Compose's embedded DNS) both satisfy
this; an arbitrary non-resolvable or public hostname would not. This is also why
`mock-oidc-provider` must already exist on the Compose network by the time Keycloak's
realm import runs — Keycloak validates every configured URL, including
`tokenUrl`/`issuer`, at **import time**, and import fails outright (crash-loop) if the
hostname does not yet resolve. This is why `keycloak`'s `depends_on` entry in
`compose.yaml` (Task 0.3) requires `mock-oidc-provider: condition: service_started`
(Compose's embedded DNS registers a container's service-name record at
container-creation time, well before the container reaches "started" — so hostname
resolution is already satisfied by then). Note this is DNS resolution only, not an
HTTP/TCP readiness probe of the mock IdP's listening port — `isLocal()` never actually
connects to `tokenUrl`/`issuer`, so Keycloak does not need the mock IdP to be *healthy*
(actively serving requests) to import successfully, only *resolvable*. That is also
why this dependency was intentionally loosened from `service_healthy` to
`service_started` (Step 7 code-review finding): a hard health gate made the unrelated
email+password/TOTP login path a hostage to this dev/CI-only mock container's health.

### Mock OIDC IdP — `ghcr.io/navikt/mock-oauth2-server`

- **Image:** `ghcr.io/navikt/mock-oauth2-server:5.0.2`, pinned by tag and
  `@sha256:f625692f5bf84939f3d0af4931f2c0f038dca84c4f1bac1171710d544181f97f` (verified
  current stable release at implementation time, 2026-07-01; re-verify before bumping).
- **Config mechanism chosen:** a mounted JSON config file (`keycloak/mock-oidc/config.json`,
  mounted read-only at `/config/config.json`, referenced via the `JSON_CONFIG_PATH` env
  var) containing only `{"interactiveLogin": true}`. No explicit issuer/tokenCallback
  registration is needed — the image supports multiple issuers with **zero**
  configuration: the first path segment of any request URL is taken as the issuer id
  (confirmed hands-on), so every URL in this realm's config consistently uses the
  single path segment `thaid` (e.g. `/thaid/.well-known/openid-configuration`) simply
  by always addressing the service under that path — there is no separate "register
  issuer thaid" step.
- **Per-PID claim assertion:** `interactiveLogin: true` serves an HTML login form at
  the `/thaid/authorize` endpoint with **no `action` attribute** (a browser posts back
  to the form's own current URL). Submitting `username=<pid>` completes the login and
  the mock IdP issues a token whose `sub` claim equals the submitted `username` value —
  this is how each integration test asserts an arbitrary PID as the ThaiD subject
  claim, with zero per-test mock-IdP configuration required.
- **Health check:** `GET /isalive` returns `200 "alive and well"`. The image is
  Wolfi-based and ships `wget` but no `curl` (confirmed hands-on) — the `compose.yaml`
  healthcheck uses `wget --quiet --spider`.
- **Client secret validation:** the mock server does **not** validate `client_secret`
  at all (confirmed hands-on — a token exchange with an empty `client_secret` succeeds
  identically to one with a real value). This is expected, documented behavior for a
  test-only mock IdP and is why the zeroed, never-runtime-populated
  `identityProviders[].config.clientSecret` still works end-to-end in this story's
  tests.

### PID pre-registration — the Admin REST mechanism this story's tests use

Story 4.4 (HR Admin "capture PID at account creation" UI, not yet built) will call this
same endpoint from its UI; this story's own integration tests call it directly to
pre-register a federated-identity link before driving a broker login:

```http
POST /admin/realms/envocc/users/{id}/federated-identity/thaid
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "identityProvider": "thaid",
  "userId": "<PID>",
  "userName": "<PID>"
}
```

Response: `204 No Content` on success. `GET /admin/realms/envocc/users/{id}/federated-identity`
returns the list of links for a user (used by TS-290f to assert only one PID remains
linked after a rejected conflicting-link attempt).

**Observed behavior (TS-290f, confirmed hands-on):** attempting to register a
**second, different** PID to a user that already has a `thaid` federated-identity link
returns **HTTP 409 Conflict** (Keycloak 26.6.3) — the first link is preserved and the
second call is rejected outright, with no need to first `DELETE` the existing link.

### `thaid-first-broker-login` — the deny-only flow (Task 2)

`realm-export.json` adds a top-level `authenticationFlows[]` entry, alias
`thaid-first-broker-login`, consisting of exactly one execution:

```json
{
  "authenticator": "deny-access-authenticator",
  "authenticatorFlow": false,
  "requirement": "REQUIRED",
  "priority": 10,
  "userSetupAllowed": false
}
```

**Provider id correction (confirmed hands-on):** the story's own drafting text names
this authenticator `"deny-access"`. The actual registered provider id in this repo's
pinned Keycloak 26.6.3 is **`deny-access-authenticator`** (confirmed via
`GET /admin/realms/{realm}/authentication/authenticator-providers` against a live
instance — `deny-access` alone is not a registered provider id and `POST .../executions/execution`
with that id returns `400 "No authentication provider found for id: deny-access"`).
This is a naming correction, not a missing-feature finding — the "Deny access"
authenticator itself is present and selectable exactly as the story's Task 2.2
anticipated, just under this slightly different id.

This flow only ever runs when Keycloak's **core broker logic** (not this flow) finds
no existing federated-identity link for the incoming `(thaid, <PID>)` pair — i.e. a
true first-broker-login. When it runs, the single `deny-access-authenticator` execution
unconditionally fails the flow: Keycloak renders a themed error page (`HTTP 401`,
confirmed hands-on) and creates **no** local account. See
`keycloak/IDENTITY-MODEL.md` Section 3 for why this realm cannot use Keycloak's default
attribute/email-based first-broker-login linking (PID is never a user `attributes`
field).

### `--import-realm` field-shape pitfalls found (fixed in `realm-export.json`)

Two issues surfaced only by actually importing this story's `realm-export.json` into a
live Keycloak 26.6.3 container (not caught by `python3 -m json.tool` alone):

1. **`authenticationFlows[].description` has a 255-character DB column limit.** An
   earlier, more verbose draft description caused realm import to crash the entire
   Keycloak boot with `Value too long for column "DESCRIPTION CHARACTER VARYING(255)"`.
   Keep any `authenticationFlows[].description` string at or under 255 characters.
2. **`identityProviders[].hideOnLoginPage` (inside `config`) is not a recognized
   field.** The actual Keycloak `IdentityProviderRepresentation` field controlling
   login-page visibility is a **top-level boolean** `hideOnLogin` (not nested in
   `config`, and not the string `"false"`/`"true"` convention `config` map entries
   use). `realm-export.json` sets `"hideOnLogin": false` at the top level of the
   `thaid` entry; AC1 requires the button to render, which is `hideOnLogin`'s default
   anyway, but the field is set explicitly for clarity.

### Pre-existing bug fixed: `login.ftl` 500'd on every render (not a Story 2.9 defect)

Verifying AC1 hands-on (loading the actual rendered Sign-in page through a live stack)
surfaced that `login.ftl` **failed to render at all** — every login attempt returned
HTTP 500 with `freemarker.core.ParseException: ... Using ?html (legacy escaping) is not
allowed when auto-escaping is on with a markup output format (HTML)`. `git blame` traces
this to Story 2.5 (`value="${(login.username!'')?html}"`, two occurrences) — Keycloak
26's default FreeMarker auto-escaping already HTML-escapes `${...}` interpolations, and
stacking the legacy `?html` builtin on top is a hard parse error in this Keycloak
version, not merely deprecated. This is unrelated to any Story 2.9 change (confirmed via
`git blame` and `git diff` — the affected lines are untouched by this story's edit to the
`socialProviders` block) and predates this story entirely; no prior story's tests caught
it because none of them render the login page's HTML via a live browser-style request —
Story 2.9's AC1 verification is the first to do so. Fixed by removing `?html` from both
occurrences (auto-escaping alone is sufficient and correct). Without this fix, AC1 could
not be verified at all — the Sign-in surface never rendered, ThaiD button or otherwise.

### PKCE and the `sub` claim — findings that shaped `tests/integration/thaid-broker.bats`

Two additional hands-on findings shaped the `drive_thaid_broker_login()` test helper
(not realm config changes, but worth recording here since they were only discoverable
by actually driving the flow):

- **`test-oidc-client` enforces PKCE S256** (`realm-export.json`,
  `attributes.pkce.code.challenge.method: "S256"`, Story 2.2). The initial
  `/protocol/openid-connect/auth` request MUST include `code_challenge`/
  `code_challenge_method`, or Keycloak rejects it with `invalid_request: Missing
  parameter: code_challenge_method` before any broker redirect happens — this applies
  identically to a `kc_idp_hint=thaid` broker-initiated request.
- **This realm's `access_token` does not carry a `sub` claim** for `test-oidc-client`
  (confirmed via a live token exchange against this exact realm-export.json). Only the
  `id_token` does, per the OIDC spec's ID Token requirement. The test helper decodes
  `id_token`, matching `tests/helpers/common.bash`'s existing `get_envocc_test_token()`
  convention, which reads `id_token` for the same reason.
