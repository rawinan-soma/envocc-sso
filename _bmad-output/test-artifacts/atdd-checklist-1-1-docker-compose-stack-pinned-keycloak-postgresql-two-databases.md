---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-06-25'
storyId: '1.1'
storyKey: 1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases
storyFile: _bmad-output/implementation-artifacts/1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md
generatedTestFiles:
  - tests/integration/stack-boot.bats
  - tests/integration/db-isolation.bats
  - tests/unit/version-pinning.bats
  - tests/unit/secret-hygiene.bats
  - tests/helpers/common.bash
inputDocuments:
  - _bmad-output/implementation-artifacts/1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-1.md
  - _bmad/tea/config.yaml
---

# ATDD Checklist: Story 1.1 — Docker Compose Stack (Pinned Keycloak + PostgreSQL Two Databases)

**Date:** 2026-06-25
**TDD Phase:** RED (all tests skipped until implementation)
**Stack Type:** backend / infrastructure (shell + Docker Compose)
**Test Framework:** bats (Bash Automated Testing System)

---

## TDD Red Phase Status

All acceptance test scaffolds are generated and **marked `skip`** — this is the intentional TDD red phase.

- Integration Tests: 12 tests (all skipped — `skip` in each `@test`)
- Unit Tests: 13 tests (all skipped — `skip` in each `@test`)
- **Total: 25 red-phase scaffold tests**

---

## Stack Detection

| Indicator | Found | Notes |
| --------- | ----- | ----- |
| `package.json` | No | No frontend/Node app yet (arrives Story 4.1) |
| `playwright.config.*` | No | Playwright wired in Story 4.1 |
| `pyproject.toml` / `go.mod` | No | Not a Python/Go project |
| `docker-compose*.yaml` | Yes (target) | The artifact being created by this story |
| Shell scripts | Yes | `postgres/init/01-init-databases.sh` |

**Resolved stack type:** `backend` (infrastructure/shell)
**Generation mode:** AI generation (no browser recording needed)
**Test framework:** `bats` — correct choice for shell/Docker Compose integration tests

---

## Acceptance Criteria Coverage

| AC | Description | Test File | Priority | Tests |
| -- | ----------- | --------- | -------- | ----- |
| AC1 | Stack boots healthy; KC admin console reachable | `tests/integration/stack-boot.bats` | P0/P1 | 5 |
| AC2 | Two least-privilege databases; cross-DB isolation enforced | `tests/integration/db-isolation.bats` | P0/P1 | 8 |
| AC3 | Exact version pinning (tag + @sha256: digest); no :latest | `tests/unit/version-pinning.bats` | P1/P2 | 6 |
| AC4 | No hard-coded secrets; .env.example committed; real .env ignored | `tests/unit/secret-hygiene.bats` | P0/P1/P2 | 9 |

---

## Generated Test Files

### `tests/integration/stack-boot.bats` (AC1)

| Test | ID | Priority | Skip Reason |
| ---- | -- | -------- | ----------- |
| postgres reaches healthy within 60 s | TS-101a | P0 | compose.yaml not yet created |
| keycloak reaches healthy within 120 s | TS-101a | P0 | compose.yaml / Dockerfile not yet created |
| HTTP port 8080 returns HTTP response | TS-101b | P0 | Keycloak not yet running |
| Admin console page returns HTTP response | TS-101b | P0 | Keycloak not yet running |
| Stack restarts without error | TS-101c | P1 | compose.yaml not yet created |
| depends_on condition: service_healthy enforced | TS-101d | P1 | compose.yaml not yet created |

### `tests/integration/db-isolation.bats` (AC2)

| Test | ID | Priority | Skip Reason |
| ---- | -- | -------- | ----------- |
| Database 'keycloak' exists | TS-102a | P0 | init script not yet created |
| Database 'admin' exists | TS-102a | P0 | init script not yet created |
| Role 'keycloak' exists | TS-102b | P0 | init script not yet created |
| Role 'adminapp' exists | TS-102b | P0 | init script not yet created |
| Roles are distinct | TS-102b | P0 | init script not yet created |
| keycloak role denied to 'admin' DB | TS-102c | P0 | init script not yet created |
| adminapp role denied to 'keycloak' DB | TS-102d | P0 | init script not yet created |
| keycloak role connects to 'keycloak' DB | TS-102e | P0 | init script not yet created |
| adminapp role connects to 'admin' DB | TS-102f | P0 | init script not yet created |
| Special chars in password don't break KC | TS-102g | P1 | init script not yet created |

### `tests/unit/version-pinning.bats` (AC3)

| Test | ID | Priority | Skip Reason |
| ---- | -- | -------- | ----------- |
| compose.yaml has no ':latest' | TS-103a | P1 | compose.yaml not yet created |
| Dockerfile has no ':latest' | TS-103a | P1 | Dockerfile not yet created |
| compose.yaml postgres has @sha256: | TS-103b | P1 | compose.yaml not yet created |
| Dockerfile FROM has @sha256: | TS-103c | P1 | Dockerfile not yet created |
| Dockerfile tag is 26.6.x | TS-103d | P1 | Dockerfile not yet created |
| Runtime digest matches compose pin | TS-103e | P2 | compose.yaml + stack not running |

### `tests/unit/secret-hygiene.bats` (AC4)

| Test | ID | Priority | Skip Reason |
| ---- | -- | -------- | ----------- |
| .gitignore covers '.env' | TS-104a | P0 | .gitignore not yet trimmed |
| .env.example not excluded from git | TS-104b | P0 | .gitignore not yet in final form |
| .env.example uses only 'change-me' placeholders | TS-104c | P0 | .env.example not yet rewritten |
| compose.yaml has no hard-coded passwords | TS-104d | P0 | compose.yaml not yet created |
| Dockerfile has no hard-coded secrets | TS-104e | P0 | Dockerfile not yet created |
| init script has no hard-coded passwords | TS-104f | P0 | init script not yet created |
| .env.example defines all compose vars | TS-104g | P1 | compose.yaml + .env.example not final |
| git does not track real .env | TS-104h | P1 | .gitignore not yet in final form |
| gitleaks detects synthetic secret (gate validation) | TS-104i | P2 | gitleaks gate is Story 1.5 scope |

---

## Helper Infrastructure

### `tests/helpers/common.bash`

Provides shared utilities for all bats tests:
- `wait_for_healthy <service> <timeout>` — polls `docker compose ps` until service is healthy
- `compose_up` / `compose_down_volumes` — stack lifecycle helpers
- `env_setup` — copies `.env.example` → `.env` with CI-safe placeholder substitution

---

## Test Design Traceability

| Test Scenario (test-design-epic-1.md) | Covered By |
| ------------------------------------- | ---------- |
| TS-101 Stack boots with .env.example | `stack-boot.bats` [P0] TS-101a/b |
| TS-102 Two-DB isolation | `db-isolation.bats` [P0] TS-102a–f |
| TS-103 Version pinning | `version-pinning.bats` [P1] TS-103a–e |
| TS-104 Secret hygiene / gitleaks | `secret-hygiene.bats` [P0] TS-104a–i |

---

## Implementation Guidance for Dev Agent

### Task Activation Order

When implementing each story task, activate the corresponding tests by removing `skip`:

| Task | Activate These Tests |
| ---- | ------------------- |
| Task 1 — Rewrite .env.example / .gitignore | `secret-hygiene.bats` TS-104a, 104b, 104c, 104h |
| Task 2 — Postgres init script | `db-isolation.bats` all tests; `secret-hygiene.bats` TS-104f |
| Task 3 — Keycloak Dockerfile | `version-pinning.bats` TS-103a(Dockerfile), 103c, 103d; `secret-hygiene.bats` TS-104e |
| Task 4 — Compose stack wiring | `stack-boot.bats` all tests; `version-pinning.bats` TS-103a(compose), 103b; `secret-hygiene.bats` TS-104d, 104g |
| Task 5 — End-to-end verify | All tests; `version-pinning.bats` TS-103e (runtime); `db-isolation.bats` TS-102g |

### How to Run Tests

Prerequisites:
```bash
# Install bats and support libraries (once)
brew install bats-core
git clone https://github.com/bats-core/bats-support.git /usr/local/lib/bats-support
git clone https://github.com/bats-core/bats-assert.git /usr/local/lib/bats-assert
```

Run all tests (most will skip in red phase):
```bash
bats tests/unit/ tests/integration/
```

Run a specific file:
```bash
bats tests/unit/secret-hygiene.bats
```

Activate a single test (remove `skip` and run):
```bash
# Edit the test file, remove the `skip` line from the target @test block
bats tests/unit/version-pinning.bats
```

---

## Next Steps

1. **Dev agent implements Story 1.1** (Task 1 → Task 5 in order)
2. **For each task:** remove `skip` from the relevant tests → run → verify RED (fail) → implement → run → verify GREEN (pass) → commit
3. After all tests pass: run `bmad-dev-story` to finalize the story
4. After implementation: run `bmad-testarch-automate` for broader automated coverage

---

**Generated by:** BMad TEA Agent — ATDD Test Architect Module
**Workflow:** `bmad-testarch-atdd` (Create mode, sequential execution)
**Version:** 4.0 (BMad v6)
