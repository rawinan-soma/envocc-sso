---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-06-23'
storyId: '1.1'
storyKey: 1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases
storyFile: _bmad-output/implementation-artifacts/1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md
generatedTestFiles:
  - tests/integration/docker-compose-stack.bats
  - tests/fixtures/env-example-keys.sh
---

# ATDD Checklist: Story 1.1 — Docker Compose Stack (Pinned Keycloak + PostgreSQL)

## Step 1: Preflight & Context

**Stack Detection:** `backend` (no `package.json` with frontend deps, no `playwright.config.*` — deliverables are `compose.yaml`, shell scripts, and `.env.example`)

**Execution Mode:** Sequential (backend project → AI generation; no browser recording needed)

**Story File:** `_bmad-output/implementation-artifacts/1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md`

**Test Framework:** `bats-core` (Bash Automated Testing System) — idiomatic for shell/compose/infrastructure tests. No TypeScript or Playwright involved.

**TEA Config Flags:**
- `tea_use_playwright_utils`: true (not applicable for backend-only stack story)
- `tea_use_pactjs_utils`: false
- `tea_browser_automation`: auto (not applicable — backend stack)
- `test_stack_type`: auto → resolved to `backend`

---

## Step 2: Generation Mode

**Mode chosen:** AI Generation (backend stack, clear acceptance criteria, no UI)

**Rationale:** Story 1.1 produces infrastructure files only (`compose.yaml`, `postgres/init/01-init-dbs.sh`, `.env.example`). No API endpoints, no browser UI. Tests are shell/docker integration assertions using `bats-core`.

---

## Step 3: Test Strategy

### Acceptance Criteria → Test Scenarios

| AC | Test Scenario | Level | Priority |
|----|---------------|-------|----------|
| AC3 | `compose.yaml` exists at repo root | Integration (file) | P0 |
| AC3 | Keycloak image pinned `26.6.3@sha256:...` — no `:latest` | Integration (file) | P0 |
| AC3 | PostgreSQL image pinned `16.x@sha256:...` — no `:latest` | Integration (file) | P0 |
| AC3 | No service uses `:latest` tag | Integration (file) | P1 |
| AC4 | `.env.example` committed with all 10 required keys | Integration (file) | P0 |
| AC4 | `.env` is NOT tracked by git | Integration (git) | P0 |
| AC4 | `gitleaks` passes on `compose.yaml` + init script | Integration (SAST) | P0 |
| AC4 | No plaintext passwords in `compose.yaml` | Integration (file) | P1 |
| AC2 | `postgres/init/01-init-dbs.sh` exists | Integration (file) | P0 |
| AC2 | Init script creates `keycloak_db` | Integration (file) | P0 |
| AC2 | Init script creates `admin` database | Integration (file) | P0 |
| AC2 | Init script creates `keycloak_user` least-privilege role | Integration (file) | P0 |
| AC2 | Init script creates `admin_user` least-privilege role | Integration (file) | P0 |
| AC2 | No SUPERUSER in any role creation | Integration (file) | P1 |
| AC2 | No CREATEDB in any role creation | Integration (file) | P1 |
| AC2 | No CREATEROLE in any role creation | Integration (file) | P1 |
| AC1 | `docker compose config` validates without errors | Integration (compose) | P0 |
| AC1 | `docker compose up --wait` completes successfully (slow) | Integration (e2e-docker) | P0 |
| AC1 | Keycloak `/health/ready` returns HTTP 200 | Integration (e2e-docker) | P0 |
| AC2 | Both `keycloak_db` + `admin` databases exist in running Postgres | Integration (e2e-docker) | P0 |
| AC2 | `keycloak_user` has no superuser privileges (running stack) | Integration (e2e-docker) | P0 |
| AC2 | `admin_user` has no superuser privileges (running stack) | Integration (e2e-docker) | P0 |
| AC1 | `docker compose down -v` cleans up cleanly | Integration (e2e-docker) | P1 |

**Total:** 23 test cases

**Test Levels Used:**
- **Integration (file)**: Assert file content / structure without running the stack (fast, offline)
- **Integration (git)**: Assert git tracking state
- **Integration (SAST)**: Run `gitleaks` against specific files
- **Integration (e2e-docker)**: Require a running Docker stack (slow, labelled for selective CI runs)

**No E2E browser tests** — story has no UI component.
**No unit tests** — no business logic functions to test in isolation.
**No API tests** — no REST endpoints exposed by this story.

---

## Step 4: TDD Red Phase — Generated Tests

### TDD RED Phase Status

All 23 test cases emitted as `skip "RED: ..."` scaffolds (bats-core `skip` directive = equivalent to Playwright `test.skip()`).

**Activated tests will FAIL until the feature is implemented. This is intentional.**

### Generated Files

| File | Tests | Phase |
|------|-------|-------|
| `tests/integration/docker-compose-stack.bats` | 23 | RED (all skipped) |
| `tests/fixtures/env-example-keys.sh` | — | fixture |

---

## Step 5: TDD Red Phase — Acceptance Criteria Coverage

| AC | Coverage | Test Count |
|----|----------|------------|
| AC1 — Keycloak starts healthy, admin console reachable | Full | 4 |
| AC2 — Two databases + least-privilege roles | Full | 10 |
| AC3 — Exact version/digest pins, no `:latest` | Full | 4 |
| AC4 — Secrets from env, gitleaks-clean, `.env` git-ignored | Full | 5 |

All 4 acceptance criteria covered. No gaps.

---

## Next Steps (Task-by-Task TDD Activation)

During implementation of each task, activate the relevant tests:

### Task 1 — `compose.yaml` (AC1, AC3)

Remove `skip` from:
- `[P0][AC3] compose.yaml exists at repo root`
- `[P0][AC3] Keycloak image is pinned to exact version 26.6.3 with digest`
- `[P0][AC3] PostgreSQL image is pinned to postgres:16.x with digest`
- `[P1][AC3] No service in compose.yaml uses ':latest' tag`
- `[P1][AC4] No plaintext password appears hard-coded in compose.yaml`
- `[P0][AC1] docker compose config validates without errors`

Run: `bats tests/integration/docker-compose-stack.bats`
Verify they FAIL first (red), then PASS after implementation (green).

### Task 2 — `postgres/init/01-init-dbs.sh` (AC2)

Remove `skip` from all `[AC2]` file-level tests (8 tests).

### Task 3 — `.env.example` update (AC4)

Remove `skip` from:
- `[P0][AC4] .env.example is committed and contains all required keys`
- `[P0][AC4] .env is NOT committed to the repository`
- `[P0][AC4] gitleaks detects no secrets`

### Task 4 — End-to-end bring-up (AC1, AC2 — docker-required tests)

Remove `skip` from all `[AC1]` and `[AC2]` docker-required tests (6 tests).
These require Docker daemon and a real `.env` with valid credentials.
Run with: `bats --filter "requires running stack" tests/integration/docker-compose-stack.bats`
Or simply: `bats tests/integration/docker-compose-stack.bats`

---

## ATDD Artifacts

- **Test file:** `tests/integration/docker-compose-stack.bats`
- **Fixture:** `tests/fixtures/env-example-keys.sh`
- **Checklist:** `_bmad-output/test-artifacts/atdd-checklist-1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md`

---

## Key Risks & Assumptions

1. **`bats-core` must be installed** on developer machines and CI. Install: `brew install bats-core` or via npm `bats`.
2. **Docker-required tests are slow** (60–90s for Keycloak startup). Mark them with a tag or run selectively in CI.
3. **Gitleaks** must be installed: `brew install gitleaks`. CI gate is Story 1.5 — for this story, run manually.
4. **Real `.env` needed** for the stack bring-up tests — developers copy `.env.example` to `.env` and fill in real values (not checked in).
5. **SHA256 digests** for `quay.io/keycloak/keycloak:26.6.3` and `postgres:16.x` must be obtained via `docker pull --platform linux/amd64` + `docker inspect` before writing `compose.yaml`.

---

## Next Recommended Workflow

`dev-story` → Implement Tasks 1–5 in order, activating and running tests per task.

After implementation: run `bmad-testarch-automate` to promote scaffolds to full CI-integrated tests.
