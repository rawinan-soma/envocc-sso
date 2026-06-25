# Story 1.1: Docker Compose stack — pinned Keycloak + PostgreSQL (two databases)

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the System Administrator,
I want a reproducible on-prem stack that brings up Keycloak backed by PostgreSQL,
so that every later capability has a running, version-pinned foundation.

**Epic:** 1 — Secure Platform Foundation
**GH Issue:** #2
**Scope boundary:** This story delivers ONLY the bring-up foundation — `compose.yaml`, the pinned Keycloak image build, two-database Postgres init, and `.env`-driven secret hygiene. It does NOT include the full realm config-as-code (Story 1.2), the Nginx security edge (Story 1.3), the Deep Sea tokens (Story 1.4), or the CI/pre-commit gate (Story 1.5). Keep this story minimal: a clean checkout + `.env` must produce a healthy Keycloak reachable on its admin console, nothing more.

## Acceptance Criteria

1. **AC1 — Stack boots healthy.** Given a clean checkout with a populated `.env`, when I run `docker compose up`, then Keycloak starts healthy against PostgreSQL and its admin console is reachable.
2. **AC2 — Two least-privilege databases.** Given the Postgres container initialises, when bring-up completes, then two separate databases exist — `keycloak` and `admin` — each owned by a distinct, least-privilege role (NFR1, AR4). The `admin` DB role MUST NOT have access to the `keycloak` DB and vice-versa.
3. **AC3 — Exact version pinning.** Given the compose file, when images are resolved, then Keycloak (26.6.x) and PostgreSQL are pinned by exact version **and digest (`@sha256:…`)** — never `:latest`, never a floating tag.
4. **AC4 — No hard-coded secrets.** Given secrets are required, when I inspect the repo, then every secret comes from env (`.env.example` committed with placeholders, real `.env` git-ignored) and no secret value is hard-coded anywhere in `compose.yaml`, the Dockerfile, or init scripts.

## Tasks / Subtasks

- [ ] **Task 1 — Reconcile stale leftover files to current architecture (AC2, AC4)**
  - [ ] Rewrite `/.env.example` — remove stale keys (`RAILS_DB_*`, `keycloak_db` DB name, deprecated `KEYCLOAK_ADMIN`/`KEYCLOAK_ADMIN_PASSWORD`) and replace with: `KC_BOOTSTRAP_ADMIN_USERNAME`, `KC_BOOTSTRAP_ADMIN_PASSWORD`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `KC_DB_USERNAME` (keycloak role), `KC_DB_PASSWORD` (keycloak role), `ADMINAPP_DB_USERNAME` (admin role), `ADMINAPP_DB_PASSWORD` (admin role). Use `change-me` placeholders only — never real secrets.
  - [ ] Update `/.gitignore` — verify `.env` is ignored, `!.env.example` is allowed. Remove dead stale lines (`admin/config/master.key`, `.kamal/secrets`) — leave generic `*.key` / `secrets/` / `.env.*` protections.
- [ ] **Task 2 — Postgres two-database init with least-privilege roles (AC2)**
  - [ ] Create `/postgres/init/01-init-databases.sh` mounted to `/docker-entrypoint-initdb.d/`. This script runs only once on a fresh volume. Create two databases — `keycloak` and `admin` — and two distinct roles, each owning exactly one DB.
  - [ ] Implement safe role creation using `SELECT format('CREATE ROLE %I WITH LOGIN PASSWORD %L', :'varname', :'varname') WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname=:'varname') \gexec` — `CREATE ROLE IF NOT EXISTS` is invalid PostgreSQL (critical bug from prior implementation).
  - [ ] Pass credentials to psql via `-v` flags so they are referenced as `:'varname'` in SQL — never interpolate shell vars into SQL strings (SQL injection / quoting breakage on passwords containing `'`, `$`, `\`).
  - [ ] Use `format('%I', :'var')` for identifier quoting (DB names, role names) and `format('%L', :'var')` for literal quoting (passwords).
  - [ ] After creating roles/DBs: `REVOKE ALL ON DATABASE keycloak FROM PUBLIC; GRANT CONNECT ON DATABASE keycloak TO {kc_role}; REVOKE ALL ON DATABASE admin FROM PUBLIC; GRANT CONNECT ON DATABASE admin TO {admin_role}`.
  - [ ] Add `: "${POSTGRES_USER:?}"` and guards for all 4 role/password vars (`:?` guard) at script top to fail fast on unset.
  - [ ] Do NOT claim the script is idempotent for re-runs on existing volumes — it only runs on empty data dirs.
- [ ] **Task 3 — Pinned Keycloak image build (AC1, AC3)**
  - [ ] Create `/keycloak/Dockerfile` FROM `quay.io/keycloak/keycloak:26.6.3@sha256:<digest>` (pinned by exact version AND digest — verify current 26.6.3 digest from quay.io at build time).
  - [ ] Run `kc.sh build --db=postgres --health-enabled=true` (CRITICAL: `KC_HEALTH_ENABLED` is a BUILD-TIME option in KC 26 — it must be in `kc.sh build`, not in `compose.yaml` env. Omitting it causes crash-loop on start with `--optimized`).
  - [ ] `CMD ["start", "--optimized"]` for fast, deterministic production boots.
  - [ ] Do NOT add realm import, themes, or event-listener providers — those belong to Stories 1.2/1.4/5.1.
- [ ] **Task 4 — Compose stack wiring (AC1, AC3, AC4)**
  - [ ] Create `/compose.yaml` at repo root with services: `postgres` (pinned by exact version+digest) and `keycloak` (built from `keycloak/Dockerfile`).
  - [ ] Configure KC → Postgres: `KC_DB=postgres`, `KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak` (DB name is `keycloak`, NOT `keycloak_db`), `KC_DB_USERNAME`/`KC_DB_PASSWORD` from env.
  - [ ] For Keycloak service: use an explicit `environment:` block listing ONLY the 6 vars KC needs (KC_DB, KC_DB_URL, KC_DB_USERNAME, KC_DB_PASSWORD, KC_BOOTSTRAP_ADMIN_USERNAME, KC_BOOTSTRAP_ADMIN_PASSWORD) — do NOT use `env_file: .env` for Keycloak (would leak Postgres superuser + admin-app credentials into KC process env unnecessarily).
  - [ ] For Postgres service: use `env_file: .env` or explicit `environment:` with the `POSTGRES_*` vars.
  - [ ] KC healthcheck on MANAGEMENT PORT 9000 (`/health/ready`) — NOT port 8080. Since KC 25+, health endpoints moved to the management interface. The ubi9-micro base image has no curl/wget; use a bash TCP socket or `java`-based check. Assert HTTP 200 status line + `"status": "UP"` (with space — KC 26 JSON format) + absence of `"status": "DOWN"`.
  - [ ] Do NOT publish port 9000 to host (`9000:9000`) — management port is in-container only. Only publish KC's main HTTP port (e.g. `8080:8080`).
  - [ ] Add Postgres healthcheck (`pg_isready`) and `depends_on: condition: service_healthy` on Keycloak.
  - [ ] Set `KC_HTTP_ENABLED=true` and `KC_HOSTNAME_STRICT=false` for HTTP-only local stack (TLS termination via Nginx is Story 1.3).
- [ ] **Task 5 — Verify end-to-end (all ACs)**
  - [ ] From clean state (`docker compose down -v`), copy `.env.example` → `.env`, fill placeholders, run `docker compose up --build`. Confirm both services reach `healthy`.
  - [ ] AC1: `curl http://localhost:8080/` → 302 redirect; KC admin console page returns HTTP response. Confirm KC admin console is reachable.
  - [ ] AC2: `psql -U <kc_role> -d admin` → `FATAL: permission denied`; `psql -U <admin_role> -d keycloak` → `FATAL: permission denied`; each role connects to its own DB successfully.
  - [ ] AC2 special: test a `KC_DB_PASSWORD` value containing `'`, `$`, `\` characters — KC must connect successfully (validates SQL quoting fix).
  - [ ] AC3: `grep -r ':latest' compose.yaml keycloak/Dockerfile` returns no matches; both images have `@sha256:` digest pinning.
  - [ ] AC4: `grep -r 'change-me\|password\|secret' compose.yaml keycloak/Dockerfile postgres/init/` returns no hard-coded secret values.
  - [ ] Update `README.md` with bring-up steps: copy `.env.example`, fill placeholders, `docker compose up`.

## Dev Notes

### Source of truth & key decisions
- **Stack (locked):** self-hosted Keycloak as the IdP engine; on-prem **Docker Compose**; **two separate PostgreSQL databases** — Keycloak's store vs the admin app's DB. [Source: architecture.md#Decision 1, #Decision 3 → Data Architecture, #Infrastructure & Deployment]
- **Database naming (binding):** the two DBs are `keycloak` and `admin`. DB roles are `keycloak` (KC role) and `adminapp` (admin app role). The admin DB holds **only** app sessions / app-side audit / CSV staging — **never canonical identities** (Keycloak is the system of record). For Story 1.1 you only create the empty DBs + roles; schema comes later (Stories 4.x). [Source: architecture.md#Decision 3 → Data Architecture, AR4; epics.md Story 1.1 AC2]
- **Version pinning (binding):** Keycloak 26.6.3 + PostgreSQL pinned by exact version + digest, never `:latest`. Architecture pins Keycloak **26.6.3** (web-verified Jun 2026). Re-verify digest from `quay.io` at implementation time. [Source: architecture.md#Decision 1 version note; epics.md Story 1.1 AC3]
- **Secret hygiene (binding):** all secrets from env; `.env.example` committed, real `.env` git-ignored; nothing hard-coded; gitleaks-clean. [Source: architecture.md#Project Tree (`.env.example`), epics.md Story 1.1 AC4]
- **Project tree (target locations):** `compose.yaml` at repo root; `keycloak/Dockerfile`; `postgres/init/` (creates separate DBs `keycloak`, `admin`); `.env.example` at root. [Source: architecture.md#Complete Project Tree]

### EXISTING FILES — READ AND CORRECT (do not blindly reuse)
The repo carries leftover config from a **discarded Rails-based admin plan** (superseded by SvelteKit/Bun architecture; files not cleaned in reset):

- **`/.env.example` (STALE — must rewrite):** currently defines `RAILS_DB_USERNAME`/`RAILS_DB_PASSWORD` ("reserved for Story 3.1"), a `keycloak_db` DB name (wrong — should be `keycloak`), and the **deprecated** `KEYCLOAK_ADMIN`/`KEYCLOAK_ADMIN_PASSWORD` vars (deprecated in KC 26). None match current architecture. Replace entirely per Task 1.
- **`/.gitignore` (MOSTLY OK — trim):** correctly ignores `.env`, `.env.*`, allows `!.env.example`, ignores `secrets/`, `*.key`. Has dead Rails/Kamal lines (`admin/config/master.key`, `.kamal/secrets`) — remove them; keep env/secret protections.
- **`/.gitleaks.toml` (OUT OF SCOPE here):** the gitleaks secret-scanning config. Do NOT modify — belongs to Story 1.5's CI gate. It exists and is correct; do not break it.
- **`/.github/workflows/ci.yml` (OUT OF SCOPE here):** leave untouched — the CI gate is Story 1.5.

### Keycloak 26 critical technical guardrails (prevents boot failures)
These are lessons from a prior implementation of this exact story that was code-reviewed and fixed:

1. **Bootstrap admin renamed:** KC 26 uses `KC_BOOTSTRAP_ADMIN_USERNAME` / `KC_BOOTSTRAP_ADMIN_PASSWORD` for the temporary first-boot admin. `KEYCLOAK_ADMIN*` is deprecated in KC 26. Using the old names may not create the admin.

2. **`KC_HEALTH_ENABLED` is a BUILD-TIME option (CRITICAL):** In KC 26, `KC_HEALTH_ENABLED=true` must be passed to `kc.sh build` in the Dockerfile — NOT set as a `compose.yaml` environment variable. Setting it only in `compose.yaml` environment causes crash-loop on `start --optimized` because the feature was not compiled in. Correct: `RUN /opt/keycloak/bin/kc.sh build --db=postgres --health-enabled=true`.

3. **Health on management port 9000:** Since KC 25, `/health`, `/health/ready`, `/health/live` are served on the **management interface (port 9000)**, not main HTTP port (8080). The compose `healthcheck` must target `:9000/health/ready` — targeting `:8080/health` will never go healthy and `depends_on: service_healthy` will hang forever. The ubi9-micro base image has no curl/wget; use bash TCP socket (`/dev/tcp/localhost/9000`) or similar.

4. **Healthcheck assertion (not just `grep UP`):** `grep -q UP` matches any "UP" substring (including partial sub-check statuses). Assert: (a) HTTP 200 status line, (b) `"status": "UP"` (with space — KC 26 JSON format), (c) absence of `"status": "DOWN"`. A simpler alternative: `curl -sf http://localhost:9000/health/ready | grep -q '"status": "UP"'` using a multi-step exec check.

5. **Do NOT publish management port:** `9000:9000` in `ports:` exposes health/metrics to the host. Drop it — port 9000 is in-container only for the healthcheck.

6. **DB URL database name:** `KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak` — the database name is `keycloak` (not `keycloak_db`). The stale `.env.example` has the wrong value.

7. **`env_file: .env` for Keycloak is too broad:** `env_file: .env` injects ALL env vars into the container, including Postgres superuser password and admin-app DB credentials that KC does not need. Use an explicit `environment:` block for Keycloak listing only the 6 vars it requires.

8. **Quarkus `start --optimized`:** after `kc.sh build`, use `CMD ["start", "--optimized"]` for fast deterministic production boots. `start-dev` is throwaway dev only and is not appropriate for the foundation image.

### PostgreSQL init script critical guardrails (prevents SQL errors and injection)
From the prior code-review on this story:

1. **`CREATE ROLE IF NOT EXISTS` is INVALID PostgreSQL:** this syntax does not exist and causes `psql` to abort with `ON_ERROR_STOP=1`. All role creation must use the pattern: `SELECT format('CREATE ROLE %I WITH LOGIN PASSWORD %L', :'rolename', :'password') WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'rolename') \gexec`.

2. **SQL injection / quoting failure:** raw shell variable interpolation (`PASSWORD '${VAR}'`) breaks on passwords containing `'`, `"`, `\`, `$` (which are valid and likely). Always parameterize via `psql -v varname="$SHELL_VAR"` and reference as `:'varname'` in SQL. Use `format('%I', :'var')` for identifiers and `format('%L', :'var')` for literals.

3. **Heredoc quoting:** use single-quoted heredoc `<<'EOSQL'` to prevent shell expansion inside the SQL body. Variables are passed via `-v` flags, not shell interpolation.

4. **`:?` guards for all env vars:** all variables consumed by the init script must be validated with `${VAR:?error message}` at the top of the script to fail fast with a clear error on unset/empty.

5. **Script only runs on empty data dir:** `/docker-entrypoint-initdb.d/` scripts only execute when the Postgres data directory is empty (first boot with a fresh volume). Do NOT claim or implement idempotency for re-runs on existing volumes — that claim is false and the guards exist only for the empty-volume case.

6. **DB isolation grants:** after creating DBs and roles, the isolation sequence is:
   ```sql
   REVOKE ALL ON DATABASE keycloak FROM PUBLIC;
   GRANT CONNECT ON DATABASE keycloak TO :kc_role;
   REVOKE ALL ON DATABASE admin FROM PUBLIC;
   GRANT CONNECT ON DATABASE admin TO :admin_role;
   ```

### Deferred items from prior code review (do not implement here)
These were noted as improvements for later stories:
- **D2:** Postgres service could use a named volume with `external: false` for explicit volume naming — acceptable as implicit for now, defer to Story 1.5 or infra hardening.

### Testing standards for this story
- No app test framework exists yet (SvelteKit admin app arrives in Story 4.1; Vitest/Playwright wired then). Verification for this infra story is **operational**, per Task 5: clean bring-up → healthy services; `psql` proof of two DBs with isolated roles; `grep` proof of digest pins; no `:latest`.
- Optional: `bats` shell tests for compose smoke / secret-hygiene are acceptable but NOT required to pass the ACs. The CI gate that would run them is Story 1.5.
- The epic-level test design (test-design-epic-1.md) covers Story 1.1 via scenarios TS-101 (stack boots with .env.example), TS-102 (two-DB isolation), TS-103 (version pinning), and TS-104 (secret hygiene / gitleaks). These are integration scenarios; the current story's Task 5 covers the same verification manually.

### Project Structure Notes
- **New files this story:** `/compose.yaml`, `/keycloak/Dockerfile`, `/postgres/init/01-init-databases.sh`, rewritten `/.env.example`, updated `/.gitignore`, `/README.md` (bring-up section).
- **Deliberately deferred (do not create):** `keycloak/realm-export.json` (Story 1.2), `nginx/` (Story 1.3), `design-tokens/` (Story 1.4), `lefthook.yml` + CI gate expansion (Story 1.5), `admin/` (Story 4.1).
- **Variance:** surviving `/.env.example` and `/.gitignore` reflect an abandoned Rails stack. They are corrected/trimmed here, not treated as the spec. The architecture doc + epic ACs are the spec.

### Prior implementation intelligence (git history — verified patterns and lessons)
A prior implementation of this story was built (`8b15841`), code-reviewed (`acdef80`), patched (`3dd3811`), and marked done — then reset as part of a planning baseline reset (`b2ebe72`). The code-review found a CRITICAL defect plus 6 additional patches; all were fixed and live boot was verified. This story file incorporates all those learnings so the dev agent does not re-encounter the same bugs.

Key verified facts from prior implementation:
- Keycloak 26.6.3 digest from quay.io: `sha256:5fdbf2dbb5897cc34e82de49d13e23db011f9925089dbc555fc095f2c8bc1dac` (verify at implementation time — may have been superseded by patch releases)
- PostgreSQL 17.5 multi-arch manifest digest from Docker Hub: `sha256:eeb22524f0cc61ad88dcea43049ddb5683d94047594d71c362ff2c340019a4d3` (verify at implementation time)
- KC health probe via bash `/dev/tcp` works on ubi9-micro (no curl/wget available)
- `REVOKE ALL ON DATABASE ... FROM PUBLIC` + targeted `GRANT CONNECT` correctly enforces AC2 cross-DB isolation
- `KC_HTTP_ENABLED=true` + `KC_HOSTNAME_STRICT=false` required for HTTP-only local stack (TLS via Nginx deferred to Story 1.3)
- DB role names from prior implementation: `keycloak` (KC role), `adminapp` (admin role) — these are the canonical names to use

### References
- [Source: _bmad-output/planning-artifacts/architecture.md#Core Architectural Decisions — Decision 1 (build approach + versions), Decision 3 (Data Architecture, Infrastructure & Deployment)]
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure & Boundaries — Complete Project Tree, Data boundary, Architectural Boundaries]
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 1 → Story 1.1 (AC1–AC4); AR1, AR4; NFR1, NFR4]
- [Source: _bmad-output/test-artifacts/test-design/test-design-epic-1.md — Story 1.1 test scenarios TS-101 through TS-104, risks R-001/R-002/R-005/R-006]
- [Source: git commit 8b15841 — prior implementation; acdef80 — code review; 3dd3811 — patches applied + live boot verified]

## ATDD Artifacts

- **Checklist:** `_bmad-output/test-artifacts/atdd-checklist-1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md`
- **Integration tests (AC1):** `tests/integration/stack-boot.bats`
- **Integration tests (AC2):** `tests/integration/db-isolation.bats`
- **Unit tests (AC3):** `tests/unit/version-pinning.bats`
- **Unit tests (AC4):** `tests/unit/secret-hygiene.bats`
- **Shared helpers:** `tests/helpers/common.bash`

All tests are red-phase scaffolds (marked `skip`). Remove `skip` per task during implementation.

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (Claude Code — bmad-create-story workflow)

### Debug Log References

### Completion Notes List

### File List
