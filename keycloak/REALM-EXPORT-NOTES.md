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
