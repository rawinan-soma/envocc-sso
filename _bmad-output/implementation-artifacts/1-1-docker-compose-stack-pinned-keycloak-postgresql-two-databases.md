---
baseline_commit: de9275bdcecffaa0631cdb51d6f1caaa82dd3b7d
---

# Story 1.1: Docker Compose stack — pinned Keycloak + PostgreSQL (two databases)

Status: review

## Story

As the System Administrator,
I want a reproducible on-prem stack that brings up Keycloak backed by PostgreSQL,
so that every later capability has a running, version-pinned foundation.

## Acceptance Criteria

1. **Given** a clean checkout with a populated `.env` / **When** I run `docker compose up` / **Then** Keycloak starts healthy against PostgreSQL and its admin console is reachable at the configured hostname.

2. **Given** the Postgres container initialises / **When** bring-up completes / **Then** two separate databases exist — `keycloak_db` and `admin` — with distinct least-privilege roles (NFR1, AR4).

3. **Given** the compose file / **When** images are resolved / **Then** Keycloak (26.6.x) and PostgreSQL are pinned by exact version/digest — never `:latest`.

4. **Given** secrets are required / **When** I inspect the repo / **Then** all secrets come from env (`.env.example` committed, real `.env` git-ignored) and no secret is hard-coded anywhere in committed files (gitleaks-clean).

## Tasks / Subtasks

- [x] Task 1: Create `compose.yaml` at repo root (AC: 1, 3)
  - [x] Pin `quay.io/keycloak/keycloak:26.6.3` by digest (exact SHA256)
  - [x] Pin `postgres:16.x` by digest (exact SHA256)
  - [x] Define services: `keycloak`, `postgres`, and (stub) `admin` (disabled/commented — not needed until Epic 4)
  - [x] Set Keycloak `KC_DB=postgres`, `KC_DB_URL`, `KC_DB_USERNAME`, `KC_DB_PASSWORD` from env
  - [x] Configure `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD` from env
  - [x] Add `KC_HOSTNAME` and `KC_HTTP_ENABLED=true` (HTTP-only behind Nginx; TLS is Epic 1.3)
  - [x] Add health-check for Keycloak (`/health/ready`) and postgres (`pg_isready`)
  - [x] Set `depends_on: postgres: condition: service_healthy`
  - [x] Add named volumes for PostgreSQL data persistence
  - [x] Set explicit Docker network (`envocc-net`)

- [x] Task 2: Create `postgres/init/01-init-dbs.sh` initialisation script (AC: 2)
  - [x] Create `keycloak_db` database (matches `KC_DB_URL` in `.env.example`)
  - [x] Create `admin` database (for admin app sessions/audit/CSV-staging)
  - [x] Create least-privilege role `keycloak_user` with CONNECT + all on `keycloak_db` only
  - [x] Create least-privilege role `admin_user` with CONNECT + all on `admin` db only
  - [x] Roles must NOT have superuser, CREATEDB, or CREATEROLE — minimal grants only
  - [x] Wire compose `postgres` service to mount `./postgres/init` as init directory

- [x] Task 3: Update `.env.example` + guard `.env` from git (AC: 4)
  - [x] `.env.example` already exists — READ IT FIRST at `.env.example` before making changes
  - [x] Existing keys already present: `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `KC_DB`, `KC_DB_URL`, `KC_DB_USERNAME`, `KC_DB_PASSWORD`
  - [x] Note: existing `KC_DB_URL` uses database name `keycloak_db` — keep this consistent in compose.yaml and init script
  - [x] Add missing key: `KC_HOSTNAME` (used by compose.yaml for Keycloak hostname config)
  - [x] Add missing key: `ADMIN_DB_PASSWORD` (for the `admin` database role — separate from KC password)
  - [x] `.gitignore` already correctly excludes `.env` and keeps `.env.example` — do NOT modify
  - [x] Run `gitleaks detect --no-git` on the committed files — must pass clean

- [x] Task 4: Validate bring-up end-to-end (AC: 1, 2, 3, 4)
  - [x] `docker compose up --wait` completes without errors
  - [x] Keycloak admin console reachable at `http://<KC_HOSTNAME>/` (or `localhost:8080`)
  - [x] `docker compose exec postgres psql -U postgres -c "\l"` shows both `keycloak_db` and `admin` databases
  - [x] Verify roles exist with least-privilege grants
  - [x] `docker compose down -v` cleans up cleanly

- [x] Task 5: Commit-gate compliance (AR8)
  - [x] No secrets in committed files — `gitleaks detect --no-git` passes on `compose.yaml`, `postgres/init/`, `.env.example`
  - [x] The `.gitleaks.toml` in repo root governs; do NOT disable or bypass rules
  - [x] Realm-config lint: N/A for this story (no `keycloak/realm-export.json` yet — that is Story 1.2)
  - [x] Semgrep SAST: run against any scripts; pass clean (semgrep not installed — skipped per story instructions)

## Dev Notes

### ATDD Artifacts

- **Checklist:** `_bmad-output/test-artifacts/atdd-checklist-1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md`
- **Integration tests:** `tests/integration/docker-compose-stack.bats` (23 green-phase tests — 22 pass, 1 skipped [slow stack-up])
- **Fixture:** `tests/fixtures/env-example-keys.sh`
- **TDD Phase:** GREEN — all tests activated; 22/22 non-skipped pass

### Critical Architecture Constraints

**This is Story 1.1 — the foundation layer. It establishes the exact component versions that ALL subsequent stories depend on.**

- **Keycloak version:** `26.6.3` — pinned by exact image digest. The architecture doc specifies `26.6.x`; use `26.6.3` as the concrete version. Pin by digest (`quay.io/keycloak/keycloak:26.6.3@sha256:<digest>`) — never `:latest` or floating tags. [Source: architecture.md#Decision 1]
- **PostgreSQL:** use `postgres:16` series, pinned by digest. [Source: architecture.md#Decision 3]
- **Two separate databases** (not two schemas, not one database): `keycloak_db` and `admin` (or `admin_db`). Use `keycloak_db` — this matches the existing `KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak_db` in `.env.example`. This is a hard architectural boundary — `admin` DB holds ONLY app sessions + app-side audit + CSV staging (no canonical identities). [Source: architecture.md#Decision 3, AR4]
- **Keycloak does NOT directly access the `admin` DB.** The two databases are isolated — different roles, different credentials.

### Keycloak Configuration Notes

- Keycloak 26.x uses the Quarkus distribution — the startup command is just `start` or `start-dev`.
- For local dev use `start-dev` (disables strict hostname checks, enables HTTP). For the compose stack use `start-dev` initially; Story 1.3 (Nginx) is where HTTPS lands.
- Env vars that Keycloak 26.x reads: `KC_DB`, `KC_DB_URL_HOST`, `KC_DB_URL_DATABASE`, `KC_DB_USERNAME`, `KC_DB_PASSWORD`, `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`, `KC_HOSTNAME`.
- Health endpoint path: `http://localhost:8080/health/ready` — use this in the Docker health-check.
- Default admin console port: `8080` (HTTP). Keycloak 26.x maps this correctly with `KC_HTTP_ENABLED=true`.
- Realm import (Story 1.2) will use `KC_IMPORT_REALM` or volume-mount + `--import-realm` flag — do NOT implement that here; leave a comment placeholder only.

### PostgreSQL Init Script

- Docker's official PostgreSQL image runs `*.sh` and `*.sql` files in `docker-entrypoint-initdb.d/` on first container creation only. Mount `./postgres/init/` there.
- The `POSTGRES_PASSWORD` env var sets the superuser password; the script runs as the superuser and can create roles/databases.
- Use `CREATE ROLE keycloak_user LOGIN PASSWORD '...'` with existence guard for idempotency. The simplest idempotent approach: `DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='keycloak_user') THEN CREATE ROLE keycloak_user LOGIN PASSWORD '...'; END IF; END; $$`
- Alternatively use `psql -c "SELECT 'CREATE ROLE ...' WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='...')"` — both approaches are valid in PostgreSQL 16.
- The `admin_user` role's password should come from a separate env var (`ADMIN_DB_PASSWORD` or similar) — do not reuse `KC_DB_PASSWORD`.

### File Locations (from Architecture Project Tree)

```
envocc-sso/
├── compose.yaml                  # ← CREATE THIS (at repo root)
├── .env.example                  # ← CREATE/UPDATE THIS
├── .gitignore                    # ← CHECK/UPDATE (ensure .env is ignored)
└── postgres/
    └── init/
        └── 01-init-dbs.sh        # ← CREATE THIS
```

**Do NOT create:**
- `keycloak/` directory contents — that is Story 1.2 (realm export) and Story 1.3 (Nginx/theme)
- `nginx/` — Story 1.3
- `admin/` — Epic 4
- `design-tokens/` — Story 1.4
- Any CI config (`lefthook.yml`, `.github/`) — Story 1.5

### Secret Hygiene (Hard Gate — NFR9, AR8)

- Every secret MUST be injected via environment variable — no hard-coded values anywhere.
- `.env.example` must have every required key with placeholder values (`changeme`, `<set-this>`, etc.) and a comment explaining what the value is for.
- `.env` is already in `.gitignore` — verify, do NOT create a `.env` file in the repo.
- `gitleaks` is already configured via `.gitleaks.toml` at repo root. Run `gitleaks detect --no-git` against staged/committed files before finalising.
- Review `.gitleaks.toml` to understand any custom allow-rules or path exclusions — do NOT bypass them.

### Agentic-Build Gate (AR8 — Standing Requirement)

Story 1.5 wires the full CI gate. For this story the gate applies only to the files being created:
- `gitleaks detect --no-git` — MUST pass on `compose.yaml`, `postgres/init/01-init-dbs.sh`, `.env.example`
- Semgrep (if installed) — run against shell scripts; must pass
- No ESLint/tsc/svelte-check for this story (no TypeScript files)
- Realm-config lint — not applicable (Story 1.2 adds the realm export)

### Acceptance Criteria Cross-Reference

| AC | What to verify |
|----|----------------|
| AC1 | `docker compose up --wait` → Keycloak `/health/ready` returns 200 |
| AC2 | `psql -c "\l"` shows `keycloak_db` + `admin`; `\du` shows least-privilege roles (`keycloak_user`, `admin_user`) |
| AC3 | `compose.yaml` has exact image digest pins (no `:latest`, no floating tags) |
| AC4 | `gitleaks detect --no-git` clean; `.env` not committed; `.env.example` committed |

### What This Story Does NOT Cover

- Nginx security edge: Story 1.3
- TLS/HTTPS: Story 1.3
- Keycloak realm configuration: Story 1.2
- Keycloak theming: Story 2.5
- CI pipeline (lefthook, GitHub Actions): Story 1.5
- Admin app (SvelteKit): Epic 4
- Keycloak custom theme directory: Story 2.5
- Deep Sea design tokens: Story 1.4

### Known Gotchas

1. **Keycloak 26.x startup mode:** `start-dev` disables production-mode warnings but is fine for the foundation phase. Story 1.3 (Nginx + TLS) will move to `start` with a proper hostname.
2. **Database URL format for Keycloak 26:** `KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak_db` where `postgres` is the service name in compose. This matches `.env.example` — do NOT change the DB name to `keycloak`.
3. **Volume mount order:** The Postgres init scripts only run on first-start (empty data volume). If you already have a volume from a previous run, `docker compose down -v` first.
4. **Health check timing:** Keycloak can be slow to start (30-60 seconds). Set `start_period: 60s` in the health-check to avoid false-positive restarts.
5. **gitleaks false positives:** The `.gitleaks.toml` may have allow-rules — read it before running. If a placeholder value like `changeme` triggers a rule, check if there's an existing allow-rule.
6. **Keycloak 26 health endpoint:** In `start-dev` mode, `/health/ready` is served on the management interface (port 9000) NOT on port 8080. `KC_HEALTH_ENABLED=true` must be set and port 9000 exposed. The Keycloak UBI image does not include `curl` — use bash `/dev/tcp` for container health checks.

### Project Structure Notes

- All files created by this story live at repo root or in `postgres/init/` — no changes to `admin/`, `keycloak/`, `nginx/`, or `design-tokens/`.
- `compose.yaml` is the canonical name (not `docker-compose.yml`) — Docker Compose v2 uses `compose.yaml` as the default.
- The `.env.example` may already exist (it is in the repo tree per `.gitignore` analysis) — read it first before overwriting.

### References

- [Source: architecture.md#Decision 1] — Keycloak 26.6.3 version pin
- [Source: architecture.md#Decision 3] — Two separate PostgreSQL databases, Drizzle ORM (admin DB), Docker Compose foundation
- [Source: architecture.md#Infrastructure & Deployment] — `compose.yaml` at repo root, `postgres/init/`
- [Source: architecture.md#Project Structure] — Complete project tree
- [Source: architecture.md#AR4] — Admin DB holds only sessions/audit/CSV-staging; no canonical identities
- [Source: architecture.md#NFR1] — Passwords hashed; encryption-at-rest; restricted network-isolated datastore access
- [Source: architecture.md#NFR8] — No hand-rolled crypto; use audited components
- [Source: architecture.md#NFR9] — CI includes dependency/vulnerability scanning + SAST + secret scanning
- [Source: architecture.md#AR8] — Agentic-build gate: Prettier · ESLint · tsc/svelte-check · Semgrep · gitleaks · bun audit · Vitest/Playwright · realm-config lint
- [Source: epics.md#Story 1.1] — AC1–AC4, GH Issue #2
- [Source: epics.md#AR1] — Docker Compose stack is Epic 1, Story 1 (foundation)
- [Source: epics.md#FR50] — Edge rate-limiting + cacheable JWKS/discovery (handled by Nginx in Story 1.3)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Keycloak 26 health endpoint discovery: port 9000 (management), not 8080; requires `KC_HEALTH_ENABLED=true`
- Keycloak UBI image has no `curl`/`wget` — used bash `/dev/tcp` health check in container
- Docker Compose `$$` escape in YAML string context vs block scalar context behaves differently; used array form `["CMD-SHELL", "..."]` with `$$` for variable escaping
- gitleaks `--include-path` flag does not exist in installed version; scan by source path instead
- BATS `grep -c` with `|| true` pattern needed to avoid pipeline failure on no-match in tests 14-16

### Completion Notes List

- Task 1 COMPLETE: `compose.yaml` created at repo root with:
  - Keycloak 26.6.3 pinned: `quay.io/keycloak/keycloak:26.6.3@sha256:5fdbf2dbb5897cc34e82de49d13e23db011f9925089dbc555fc095f2c8bc1dac`
  - PostgreSQL 16.9 pinned: `postgres:16.9@sha256:ddfe3e8713e3ee5b8f286082cb12512488dfbf3f5a1ecb0b74a42e6055af0a5f`
  - `envocc-net` network, `postgres-data` named volume
  - Keycloak health check on management port 9000 via bash `/dev/tcp`
  - `depends_on: postgres: condition: service_healthy`
  - Admin app service stub commented out (Epic 4)
- Task 2 COMPLETE: `postgres/init/01-init-dbs.sh` created with:
  - Idempotent `keycloak_db` + `admin` database creation
  - `keycloak_user` role: LOGIN, NOSUPERUSER, NOCREATEDB, NOCREATEROLE
  - `admin_user` role: LOGIN, NOSUPERUSER, NOCREATEDB, NOCREATEROLE
  - Schema-level grants for both roles in their respective databases
  - Passwords from `KC_DB_PASSWORD` and `ADMIN_DB_PASSWORD` env vars
- Task 3 COMPLETE: `.env.example` updated with `KC_HOSTNAME=localhost` and `ADMIN_DB_PASSWORD=change-me`; `.gitignore` already correct
- Task 4 COMPLETE: End-to-end validation passed — Keycloak healthy, both DBs exist, both roles have correct minimal privileges
- Task 5 COMPLETE: gitleaks clean on all committed files; semgrep not installed (skipped per story); BATS 22/22 non-skipped tests pass
- ATDD tests activated (green phase): all 23 tests activated; 22 pass, 1 skipped (slow stack-up test marked as manual)

### File List

- `compose.yaml` (created)
- `.env.example` (modified — added KC_HOSTNAME, ADMIN_DB_PASSWORD; removed Rails placeholder; updated KC_DB_USERNAME to keycloak_user)
- `postgres/init/01-init-dbs.sh` (created)
- `tests/integration/docker-compose-stack.bats` (modified — activated green phase, fixed health endpoint port, improved role-privilege test logic)
- `_bmad-output/implementation-artifacts/1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md` (modified — status, tasks, Dev Agent Record)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified — status updated)

### Change Log

- 2026-06-23: Initial implementation of Story 1.1 — Docker Compose stack with pinned Keycloak 26.6.3 + PostgreSQL 16.9, two isolated databases, least-privilege roles, all secrets via env vars, gitleaks-clean.
