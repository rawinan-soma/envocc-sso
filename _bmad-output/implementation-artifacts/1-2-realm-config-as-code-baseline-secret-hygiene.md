---
baseline_commit: 4da01ef
---

# Story 1.2: Realm config-as-code baseline & secret hygiene

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the System Administrator,
I want the realm defined as version-controlled, secret-stripped config that imports on bring-up,
so that realm state is reproducible and auditable.

**Epic:** 1 — Secure Platform Foundation
**GH Issue:** #3
**Scope boundary:** This story delivers ONLY the realm config file and import wiring — `keycloak/realm-export.json` committed and secret-free, Keycloak auto-importing it on stack bring-up, and the import confirmed by a gitleaks scan. It does NOT include the Nginx security edge (Story 1.3), the CI/pre-commit gate (Story 1.5), the full identity model (Epic 2), the login theme (Epic 2), or SMTP configuration. Keep this minimal: a clean checkout + `.env` must produce a Keycloak instance that auto-imports the baseline realm settings and passes a `gitleaks detect` scan of the exported file.

## Acceptance Criteria

1. **AC1 — Realm auto-imports on bring-up.** Given `keycloak/realm-export.json` in git, when the stack starts (`docker compose up`), then the realm is imported automatically and baseline settings (realm name, login settings) are applied without manual intervention.
2. **AC2 — Realm file is gitleaks-clean.** Given the exported realm file, when I inspect it (and run `gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml --redact --verbose`), then it contains no client secrets, passwords, or signing-key material — i.e. no secret fields are populated with real values.
3. **AC3 — Realm change round-trip.** Given a realm change made through the Keycloak Admin UI, when it is exported back to the repo (using the documented export procedure), then the resulting diff is reviewable (no sensitive material) and the updated file is re-importable on a fresh stack (`docker compose down -v && docker compose up`) with the change applied.

## Tasks / Subtasks

- [ ] **Task 1 — Extend Keycloak Dockerfile with realm import support (AC1)**
  - [ ] Add `COPY realm-export.json /opt/keycloak/data/import/realm-export.json` to `keycloak/Dockerfile` so the file is baked into the image.
  - [ ] Add `--import-realm` to the `CMD` in `keycloak/Dockerfile` so KC auto-imports on every fresh start: `CMD ["start", "--optimized", "--import-realm"]`.
  - [ ] CRITICAL: `--import-realm` only works with Keycloak 26 when the import file is present at `/opt/keycloak/data/import/`. If the file is absent, KC boots without error but without the realm. Confirm the `COPY` path is exact.
  - [ ] Do NOT use `KC_IMPORT` environment variable — in KC 26 with Quarkus, the import is triggered by `--import-realm` CLI flag and the presence of the import file, not by an env var.
  - [ ] Do NOT change `--health-enabled=true` in `kc.sh build` — it was baked in Story 1.1 and must not be removed.
  - [ ] Rebuild the image after any Dockerfile change: `docker compose build keycloak`.
- [ ] **Task 2 — Create the baseline realm-export.json (AC1, AC2)**
  - [ ] Create `keycloak/realm-export.json` — a minimal, baseline realm configuration for the `envocc` realm. This is the baseline config (Story 1.2 scope); full OIDC clients, MFA flows, ThaiD broker, and complete settings are added in Epic 2.
  - [ ] Baseline realm settings to include in the JSON:
    - `"realm": "envocc"` (realm name)
    - `"enabled": true`
    - `"displayName": "EnvOcc SSO"` (anti-phishing display name)
    - `"loginWithEmailAllowed": true`
    - `"duplicateEmailsAllowed": false`
    - `"registrationAllowed": false` (HR admin creates accounts — no self-registration)
    - `"resetPasswordAllowed": false` (self-service password reset wired in Epic 3 flows)
    - `"rememberMe": false`
    - `"bruteForceProtected": true` (Keycloak native brute-force — configured fully in Epic 2 Story 2.7, but enable now)
    - `"permanentLockout": false`
    - `"maxFailureWaitSeconds": 900`
    - `"minimumQuickLoginWaitSeconds": 60`
    - `"waitIncrementSeconds": 60`
    - `"quickLoginCheckMilliSeconds": 1000`
    - `"maxDeltaTimeSeconds": 43200`
    - `"failureFactor": 30`
    - `"ssoSessionIdleTimeout": 1800` (30 min idle — FR8; tightened in Epic 2)
    - `"ssoSessionMaxLifespan": 36000` (10 hr absolute max — FR8; tightened in Epic 2)
    - `"accessTokenLifespan": 300` (5 min — short-lived tokens FR9; Epic 2 tightens to ≤15 min)
    - `"defaultSignatureAlgorithm": "RS256"` (asymmetric signing, FR5)
    - `"internationalizationEnabled": false` (Thai localization deferred; NFR19)
    - Empty or minimal `"clients": []`, `"roles": {}`, `"groups": []` arrays (clients/roles added in Epic 2+)
  - [ ] Keycloak auto-generates signing keys on first boot. DO NOT include `privateKey`, `certificate`, `secret`, or any `KeyProvider` component entries with populated key material. Leave the `"components"` field absent or with empty entries only — KC will generate fresh keys at boot.
  - [ ] DO NOT include client credentials. If any placeholder clients are added, set `"secret": ""` (empty string, not a real value). Better: omit all clients for this baseline.
  - [ ] Validate JSON syntax: `python3 -m json.tool keycloak/realm-export.json > /dev/null` (or `jq .`).
- [ ] **Task 3 — Secret hygiene verification (AC2)**
  - [ ] Run gitleaks spot-check: `gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml --redact --verbose`. Must exit 0 (no findings).
  - [ ] Confirm no fields matching `privateKey`, `certificate`, `secret` (with a real value ≥8 chars), `clientSecret`, or `HMAC` keys appear in the file. Empty strings `""` and absent fields are fine.
  - [ ] The `.gitleaks.toml` already contains rules `keycloak-client-secret`, `keycloak-private-key`, and `keycloak-hmac-secret` that cover these patterns — no changes to `.gitleaks.toml` needed.
- [ ] **Task 4 — Update CI to confirm realm-export check (AC2)**
  - [ ] The `.github/workflows/ci.yml` already has a `realm-export-check` job that runs `gitleaks detect --source keycloak/realm-export.json ...`. No changes needed to the CI file itself.
  - [ ] Confirm the `realm-export-check` job will pass against the new `realm-export.json`. The file must be clean before pushing.
  - [ ] Note: the CI `realm-export-check` job was added in a prior commit anticipating this story — it references `keycloak/realm-export.json` which did not yet exist. The job was failing silently (gitleaks on a nonexistent file path exits 0 in some versions, or may fail). Verify behavior once the file exists.
- [ ] **Task 5 — Document export procedure (AC3)**
  - [ ] Add a `keycloak/REALM-EXPORT-NOTES.md` (already path-allowlisted in `.gitleaks.toml` — safe to commit) with the export procedure:
    1. Make realm changes via Admin UI at `http://localhost:8080/admin/master/console/#/envocc`.
    2. Export: Admin UI → Realm Settings → Action → Export → enable "Export clients" + "Export groups and roles" → Export. Save as `keycloak/realm-export.json`.
    3. Alternative (CLI): ONLY works when KC is NOT running. Stop KC first (`docker compose stop keycloak`), then: `docker compose run --rm keycloak export --realm envocc --dir /tmp/export` — then copy the file out. The in-container `kc.sh export` command cannot run while the server is already started (Quarkus server mode conflict in KC 26). Use Admin UI export for a running stack.
    4. Strip secrets: inspect the exported file for `"privateKey"`, `"certificate"`, `"secret"`, `"clientSecret"` — remove or empty any populated values.
    5. Run gitleaks check: `gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml --redact`.
    6. Commit the cleaned file. The diff is reviewable — only realm setting changes appear.
  - [ ] Note: `keycloak/REALM-EXPORT-NOTES.md` is already in `.gitleaks.toml` allowlist paths section. Do NOT remove or rename this file.
- [ ] **Task 6 — End-to-end verification (all ACs)**
  - [ ] From clean state: `docker compose down -v && docker compose up --build`.
  - [ ] AC1: After Keycloak reaches healthy state, navigate to `http://localhost:8080/admin/master/console/#/envocc` — the `envocc` realm must exist and be selectable. Alternatively: `curl -s http://localhost:8080/realms/envocc/.well-known/openid-configuration | jq '.issuer'` → must return `"http://localhost:8080/realms/envocc"` (not a 404).
  - [ ] AC2: `gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml --redact --verbose` → exit 0, no findings.
  - [ ] AC3 round-trip: make a trivial change via Admin UI (e.g., set `ssoSessionIdleTimeout` to 2000), export, confirm diff is clean, run gitleaks, `docker compose down -v && docker compose up --build`, verify the change was imported. Revert the test change before final commit.
  - [ ] Confirm `keycloak/Dockerfile` still passes `docker compose config` with no warnings.
  - [ ] Confirm the existing unit/integration BATS tests in `tests/` still pass (no regressions from Dockerfile changes).

## Dev Notes

### Source of truth & key decisions

- **Realm import mechanism (binding):** Keycloak 26 (Quarkus) auto-imports realms placed in `/opt/keycloak/data/import/` when started with `--import-realm`. Triggered at startup. [Source: Keycloak 26 Server Admin Guide — Importing and Exporting Realms]
- **Import behavior on existing DB (CRITICAL — two distinct cases):**
  - **Fresh stack (`docker compose down -v` + `up --build`):** KC creates the realm from the import file. This always works as expected.
  - **Existing stack restart (volumes retained, `up --build` without `down -v`):** By default, KC 26 `--import-realm` uses `IGNORE_EXISTING` strategy — if the realm already exists in the DB, the import file is **SKIPPED** (no overwrite). To force overwrite an existing realm, you must add `--import-strategy=OVERWRITE_EXISTING` to the CMD. For the baseline story (fresh dev stacks), `IGNORE_EXISTING` (default) is acceptable. For config-as-code discipline where the file is the source of truth, consider `OVERWRITE_EXISTING`. Document both behaviors in REALM-EXPORT-NOTES.md so operators know what to expect.
  - **Recommended for this story:** use the default (`IGNORE_EXISTING`) — this means `docker compose down -v` is required to re-apply the realm config on an existing stack. This is the simplest behavior and avoids accidental overwrite of live config. Document clearly in REALM-EXPORT-NOTES.md.
- **Dockerfile CMD choice:** `CMD ["start", "--optimized", "--import-realm"]` with default `IGNORE_EXISTING`. If the team wants strict config-as-code (file always wins), append `--import-strategy=OVERWRITE_EXISTING` — note this will overwrite live realm state on every container restart, including manual UI changes that weren't exported. For this baseline story, the default is correct.
- **File location (binding):** `keycloak/realm-export.json` in the repo; baked into image via `COPY` in `keycloak/Dockerfile`; served to KC at `/opt/keycloak/data/import/realm-export.json`. Do not use environment-variable-based import paths in KC 26.
- **Dockerfile continuity (binding):** `keycloak/Dockerfile` already exists (Story 1.1) and must be updated, NOT replaced. Preserve: FROM digest pin (`quay.io/keycloak/keycloak:26.6.3@sha256:9b0330756022422149aa6502eb2def8cd47c6e1b000c7c65cdb13e7c0133e992`), `kc.sh build --db=postgres --health-enabled=true`. Add after `RUN`: `COPY realm-export.json /opt/keycloak/data/import/realm-export.json`. Change `CMD` to `CMD ["start", "--optimized", "--import-realm"]`.
- **Secret-stripped file (binding):** the `.gitleaks.toml` rules `keycloak-private-key` and `keycloak-hmac-secret` catch populated `"privateKey"`, `"certificate"` (≥64 chars), and HMAC/AES `"secret"` (≥16 chars in array form). The `keycloak-client-secret` rule catches `"clientSecret"` or `"secret"` (≥8 chars) at the realm level. Populate none of these fields — leave absent or empty string.
- **Scope limit (binding):** this story creates the baseline realm only. Full OIDC clients (`envocc-admin`, `envocc-sample`), realm roles (`hr-admin`, `system-admin`), MFA required actions (TOTP), login flows, ThaiD identity provider, password policy, and events configuration belong to Epic 2 stories (2.1–2.9). Do not add these here.
- **Realm name (binding):** `"realm": "envocc"` — lowercase, no spaces. The OIDC issuer will be `http://localhost:8080/realms/envocc`. This name is the canonical realm identifier for all subsequent stories.
- **CI job already exists:** the `realm-export-check` job in `.github/workflows/ci.yml` was created in Story 1.1 anticipating this story. No CI changes are needed; only ensure the file exists and is clean.
- **gitleaks config (out of scope):** `.gitleaks.toml` and `.gitleaksignore` are already correct and cover `realm-export.json`. Do NOT modify either file unless a specific false-positive finding requires it.

### Files being modified (UPDATE, not NEW)

- **`keycloak/Dockerfile`** — UPDATE: add `COPY realm-export.json /opt/keycloak/data/import/realm-export.json` and change `CMD` to include `--import-realm`. Current CMD: `CMD ["start", "--optimized"]`. Target CMD: `CMD ["start", "--optimized", "--import-realm"]`. All other lines unchanged.

### New files for this story

- **`keycloak/realm-export.json`** — NEW: baseline realm config, secret-free.
- **`keycloak/REALM-EXPORT-NOTES.md`** — NEW: export procedure documentation (path-allowlisted in `.gitleaks.toml`).

### Files NOT to touch

- `compose.yaml` — no changes needed; the realm import is baked into the Docker image.
- `.gitleaks.toml` — already correct; has all needed rules and allowlists.
- `.gitleaksignore` — no changes.
- `.github/workflows/ci.yml` — the `realm-export-check` job already exists; no changes needed.
- `postgres/init/01-init-databases.sh` — out of scope for this story.
- `tests/` directory — BATS tests from Story 1.1 must still pass. Do not break them. Verify with `bats tests/unit/` before committing.

### Keycloak 26 import technical details

1. **Import file placement:** KC 26 expects import files at `/opt/keycloak/data/import/`. The file can be named anything ending in `.json`. KC will import all files in that directory matching `*-realm.json` OR explicitly named files when `--import-realm` is used.
   
2. **`--import-realm` flag:** Must be on the `start` or `start-dev` command. Since Story 1.1 uses `start --optimized`, the correct form is `CMD ["start", "--optimized", "--import-realm"]`.

3. **Import strategy:** KC 26 default is `IGNORE_EXISTING` — if the realm already exists in the database, the import file is skipped. A realm only imports on the first boot against a fresh (empty) database. To force overwrite an existing realm, add `--import-strategy=OVERWRITE_EXISTING` to the CMD. For dev stacks that use `down -v` between iterations, the default is fine. For strict config-as-code environments, use `OVERWRITE_EXISTING`. This story uses the default (`IGNORE_EXISTING`) — document this clearly in REALM-EXPORT-NOTES.md.

4. **Empty vs absent fields:** KC realm export typically includes many fields. For our baseline, it is acceptable to produce a compact JSON with only the fields we care about; KC fills in defaults for missing fields at import time. A minimal file is preferable to a bloated one that includes generated fields that change between exports (e.g., `id` UUIDs for keys).

5. **Realm ID:** It is acceptable to omit the `"id"` field from the realm JSON — KC assigns a UUID on import. If the `"id"` is included, KC uses it (idempotent re-import on same DB).

6. **Getting a clean baseline export:** The cleanest approach is to boot the stack without `--import-realm`, create the realm via Admin UI with the desired baseline settings, then export it (Realm Settings → Action → Export). Then strip all generated key material from the exported JSON before committing.

### Keycloak Admin UI export vs CLI export

**Admin UI export (recommended for baseline):**
- Admin UI → Select realm (`envocc`) → Realm settings → Action dropdown → Export
- Check "Export clients" and "Export groups and roles" if you have any defined (baseline: neither, so uncheck both for a cleaner file)
- Downloads as `realm-export.json` directly

**KC CLI export (alternative — requires stopped KC):**
```bash
# IMPORTANT: kc.sh export CANNOT run while the Keycloak server is already running.
# The Quarkus server process conflicts with the export command in KC 26.
# Use Admin UI export for a running stack. For CLI export:

# 1. Stop KC (not postgres — keep the DB up so realm data exists)
docker compose stop keycloak

# 2. Run export via a new container (reuses same image/config, no server start)
docker compose run --rm --entrypoint "" keycloak \
  /opt/keycloak/bin/kc.sh export \
  --realm envocc \
  --dir /tmp/export \
  --users skip \
  --db-url-database keycloak \
  --db-username "${KC_DB_USERNAME}" \
  --db-password "${KC_DB_PASSWORD}" \
  --db-url-host postgres

# 3. Copy the export from the (now exited) container
# (Alternative: mount a host volume in step 2 to avoid docker cp)

# 4. Restart KC
docker compose start keycloak
```
Note: `--users skip` omits user records (correct for config-as-code — we don't commit user data). In practice, use Admin UI export for the running stack — it is simpler and avoids the stopped-server requirement.

### Secret field stripping checklist

After export, inspect and clear/remove these fields:
- `"privateKey": "..."` → remove or set to `""`
- `"certificate": "..."` → remove or set to `""`  
- `"secret": ["..."]` (array form, in KeyProvider components) → remove or set to `[""]`
- `"clientSecret": "..."` → remove or set to `""`
- Any `"components"` entries of type `rsa-generated` or `hmac-generated` that contain populated key values → remove the value fields or remove the whole component (KC regenerates keys on boot)

The gitleaks rules cover exactly these patterns. Run the scan after stripping.

### Testing standards for this story

- **No new test framework:** Vitest/Playwright arrives in Story 4.1. Testing here is operational verification (Task 6) and gitleaks scan.
- **Regression guard:** run `bats tests/unit/` (Story 1.1 unit tests cover version pinning and secret hygiene) before committing. These tests inspect `compose.yaml` and `keycloak/Dockerfile` — the Dockerfile change in Task 1 must not break `tests/unit/version-pinning.bats`.
  - The `version-pinning.bats` test checks for `@sha256:` in the Dockerfile — this is still present, so it will pass.
  - The `secret-hygiene.bats` test scans `compose.yaml` and `keycloak/Dockerfile` for hardcoded secrets — adding `COPY realm-export.json ...` does not introduce secrets, so it will pass.
- **Gitleaks scan:** `gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml --redact --verbose` must exit 0 before committing.
- **OIDC discovery endpoint as AC1 proof:** `curl -sf http://localhost:8080/realms/envocc/.well-known/openid-configuration | jq '.issuer'` returning `"http://localhost:8080/realms/envocc"` is the cleanest, most unambiguous confirmation that the realm imported correctly.
- **Optional BATS integration test scaffold:** Story 1.1 established the pattern of creating `skip`-guarded BATS integration test scaffolds. For this story, optionally add a `tests/integration/realm-import.bats` with a `skip`-guarded test that checks `curl -s http://localhost:8080/realms/envocc/.well-known/openid-configuration` returns HTTP 200. This is NOT required to pass the ACs — the CI gate (Story 1.5) will run it — but following the 1.1 pattern is good practice. If added, it must be `skip`-guarded (no live stack in unit test runs).
- **Unit test for gitleaks-clean realm export:** optionally add to `tests/unit/secret-hygiene.bats` a test that runs `gitleaks detect --source keycloak/realm-export.json --no-git ...` as a static check (similar to TS-104e). The file exists statically, so this can run without a live stack. Tag it `[P0][TS-104-realm]`.

### Previous story intelligence (Story 1.1 learnings)

From Story 1.1 dev notes and code review — directly applicable here:

1. **KC digest re-verified at implementation time:** The Dockerfile currently uses `sha256:9b0330756022422149aa6502eb2def8cd47c6e1b000c7c65cdb13e7c0133e992` for KC 26.6.3 (re-verified during 1.1 implementation). Do NOT change this digest unless upgrading the KC version (out of scope for 1.2). The story dev notes had a different digest from the original story file — always trust the Dockerfile, not the notes, as the Dockerfile was the last-verified value.
2. **`KC_HEALTH_ENABLED` is BUILD-TIME:** already baked into the image via `kc.sh build --db=postgres --health-enabled=true`. Adding `--import-realm` to CMD does NOT affect this — health is still enabled.
3. **`CMD` format in Dockerfile:** Story 1.1 uses `CMD ["start", "--optimized"]` (JSON array form). Keep JSON array form for `CMD ["start", "--optimized", "--import-realm"]`.
4. **Docker Compose `$$VAR` escaping:** In `compose.yaml` healthcheck CMD-SHELL strings, `$$` is used to escape `$` for compose variable interpolation. The Dockerfile does not have this issue — `CMD` in JSON array form needs no escaping.
5. **gitleaks allowlist paths:** `keycloak/REALM-EXPORT-NOTES.md` is already in the `.gitleaks.toml` `[allowlist].paths` list. This was added in Story 1.1 anticipating Story 1.2. Safe to create this file.
6. **`tests/lib/` in `.gitignore`:** vendored bats libraries are in `tests/lib/` (gitignored). Bats tests require `BATS_LIB_PATH` to point to this absolute path for helper loading.

### Project structure notes

- **New files this story:** `keycloak/realm-export.json`, `keycloak/REALM-EXPORT-NOTES.md`.
- **Updated files this story:** `keycloak/Dockerfile` (COPY + CMD change only).
- **Unchanged:** everything else.
- **Architecture mapping:** `keycloak/realm-export.json` is the FG-1/FG-3/FG-8 realm config-as-code entry point per the project tree in architecture.md. This story establishes the file; Epic 2 populates it with full OIDC, MFA, and security hardening settings.
- **No admin app changes:** The SvelteKit admin app (`admin/`) is created in Story 4.1. Nothing in `admin/` is touched here.

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Core Architectural Decisions — Decision 1 (version note), Decision 2 (realm config-as-code)]
- [Source: _bmad-output/planning-artifacts/architecture.md#Infrastructure & Deployment (realm config-as-code, secrets stripped)]
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries — Complete Project Tree (keycloak/realm-export.json)]
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 1 → Story 1.2 (AC1–AC3); AR1, AR2, NFR1, NFR8, NFR9]
- [Source: _bmad-output/implementation-artifacts/1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md — Dockerfile patterns, digest values, gitleaks config, BATS test setup]
- [Source: .github/workflows/ci.yml — realm-export-check job already present]
- [Source: .gitleaks.toml — keycloak-private-key, keycloak-hmac-secret, keycloak-client-secret rules; REALM-EXPORT-NOTES.md path allowlist]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (Claude Code — bmad-create-story workflow)

### Debug Log References

### Completion Notes List

### ATDD Artifacts

- **Checklist:** `_bmad-output/test-artifacts/atdd-checklist-1-2-realm-config-as-code-baseline-secret-hygiene.md`
- **Unit tests (extended):** `tests/unit/secret-hygiene.bats` (Story 1.2 additions: TS-104j, TS-104k, TS-104-realm-a through h)
- **Integration tests (new):** `tests/integration/realm-import.bats` (TS-201a through g)

### File List
