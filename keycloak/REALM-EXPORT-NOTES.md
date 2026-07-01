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

## Story 2.7 — Brute-Force Protection & Enumeration-Resistant Responses

This section documents the per-account brute-force tuning added in Story 2.7,
covering FR19 (progressive delays, per-account and per-IP) and FR20
(enumeration-resistant identical generic responses).

### Per-account brute-force field reference

`bruteForceProtected: true` was enabled in Story 1.2 to satisfy the CI lint gate
(`scripts/lint-realm-export.py`, which only asserts the boolean), with the numeric
tuning fields deliberately left as **placeholders** pending this story. The
following table documents the final, deliberate values chosen in Story 2.7:

| Field | Value | Rationale |
|---|---|---|
| `bruteForceProtected` | `true` | Enables Keycloak's native per-account brute-force detection (audited component, NFR8 — no hand-rolled lockout logic). |
| `failureFactor` | `5` | **Tuned down from the Story 1.2 placeholder of `30`.** Number of failed attempts before an account is temporarily locked. 5 is low enough to blunt credential-stuffing/guessing quickly while still tolerant of a couple of genuine typos. |
| `permanentLockout` | `false` | Lockout is always temporary (progressive-delay based) — never requires an admin-unlock action for a failed-login count. Keeps the lockout experience self-resolving for legitimate users. |
| `waitIncrementSeconds` | `60` | Wait time grows by 60 seconds for each additional failure past the quick-login threshold — the progressive-delay curve. |
| `maxFailureWaitSeconds` | `900` (15 min) | Caps the maximum single lockout wait at 15 minutes, bounding the worst-case delay for a legitimate user who forgot their password. |
| `minimumQuickLoginWaitSeconds` | `60` | Applies an immediate 60-second wait when retries happen faster than `quickLoginCheckMilliSeconds` apart — deters rapid-fire scripted attempts specifically. |
| `quickLoginCheckMilliSeconds` | `1000` | Attempts within 1 second of each other are treated as "quick" (scripted) retries and immediately trigger the minimum wait, rather than waiting for the full `failureFactor` count. |
| `maxDeltaTimeSeconds` | `43200` (12 h) | Failure count resets after 12 hours without a new failure — bounds how long a stale failure count can linger and contribute toward a future lockout. |

Together these implement a two-stage defense: **quick-retry throttling**
(`minimumQuickLoginWaitSeconds` / `quickLoginCheckMilliSeconds`) catches
scripted rapid-fire attempts immediately, while the **progressive lockout**
(`failureFactor` / `waitIncrementSeconds` / `maxFailureWaitSeconds`) throttles
slower, distributed guessing attempts. This is the per-account layer of FR19's
two-layer defense; the per-IP layer (`nginx/nginx.conf`, `login_zone`,
10 req/min, HTTP 429) was already shipped in Story 1.3 and required no changes
in Story 2.7 — see `tests/unit/nginx-config.bats` for its regression coverage.

### Enumeration-resistant messaging (FR20, UX-DR9)

No `messages_en.properties` changes were needed for Story 2.7. The envocc theme
already (since Story 2.5):

- Sets `invalidUserMessage` and `invalidPasswordMessage` to the identical
  string `Incorrect email or password.` — a wrong password and a nonexistent
  email produce byte-identical copy.
- Does **not** override `accountTemporarilyDisabledMessage`,
  `accountPermanentlyDisabledMessage`, or their TOTP variants
  (`accountTemporarilyDisabledMessageTotp`,
  `accountPermanentlyDisabledMessageTotp`) — these inherit Keycloak's base
  theme, which already ships the same generic "Invalid username or password."
  family of copy for a brute-force-locked account (verified against Keycloak
  26.6.3 upstream base theme). A locked account is therefore indistinguishable
  from a wrong-password attempt.
- `accountDisabledMessage` (`This account is not available. Contact HR if you
  need help.`) remains a **deliberate, accepted exception**: it is the
  HR-disable path (Story 2.8, FR25), a conceptually distinct state from
  "wrong password" or "brute-force locked," and is not part of the
  identical-wording requirement.

See `tests/unit/brute-force-config.bats` (TS-271x) and
`tests/unit/enumeration-resistant-messages.bats` (TS-272x) for the automated
regression guards, and `tests/integration/brute-force-lockout.bats` (TS-273x)
for live-stack lockout + enumeration-timing verification.
