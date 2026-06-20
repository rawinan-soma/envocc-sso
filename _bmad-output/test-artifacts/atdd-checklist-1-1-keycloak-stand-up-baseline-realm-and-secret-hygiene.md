---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-06-20'
storyId: '1.1'
storyKey: 1-1-keycloak-stand-up-baseline-realm-and-secret-hygiene
storyFile: _bmad-output/implementation-artifacts/1-1-keycloak-stand-up-baseline-realm-and-secret-hygiene.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-1-keycloak-stand-up-baseline-realm-and-secret-hygiene.md
generatedTestFiles:
  - tests/secret-hygiene/ac2-secret-hygiene.bats
  - tests/integration/ac1-docker-compose-smoke.bats
  - tests/integration/ac1-realm-config.bats
  - tests/run-atdd.sh
inputDocuments:
  - _bmad-output/implementation-artifacts/1-1-keycloak-stand-up-baseline-realm-and-secret-hygiene.md
  - _bmad/tea/config.yaml
  - resources/knowledge/data-factories.md
  - resources/knowledge/test-quality.md
  - resources/knowledge/test-healing-patterns.md
  - resources/knowledge/test-levels-framework.md
  - resources/knowledge/test-priorities-matrix.md
  - resources/knowledge/risk-governance.md
  - resources/knowledge/probability-impact.md
---

# ATDD Checklist: Story 1.1 — Keycloak Stand-Up, Baseline Realm & Secret Hygiene

## TDD Status: RED PHASE

All tests are scaffolded with `skip` — they document **expected behavior** before implementation.
They will fail when activated, until the infrastructure is built. This is intentional.

## Stack Detection

- **Detected stack:** `backend` (infrastructure-only — Docker Compose, Keycloak, bash)
- **Test framework:** `bats-core` (Bash Automated Testing System) — appropriate for shell/CLI/Docker smoke tests
- **Generation mode:** AI (no browser; no UI flows in this story)
- **Execution mode:** Sequential

## Test Files Generated

| File | Type | Tests | Phase |
|------|------|-------|-------|
| `tests/integration/ac1-docker-compose-smoke.bats` | Smoke/Integration | 11 | RED |
| `tests/integration/ac1-realm-config.bats` | Integration/Static | 15 | RED |
| `tests/secret-hygiene/ac2-secret-hygiene.bats` | Static/CI | 15 | RED |
| `tests/run-atdd.sh` | Runner | — | — |

**Total scaffolded tests: 41** (all skipped — RED phase)

## Acceptance Criteria Coverage

### AC1 — Docker Compose brings up Keycloak + PostgreSQL, imports the baseline realm

| Scenario | Test ID | Priority | File |
|----------|---------|----------|------|
| All compose services start | AC1-01 | P0 | ac1-docker-compose-smoke.bats |
| Keycloak health endpoint responds 200 | AC1-02 | P0 | ac1-docker-compose-smoke.bats |
| OIDC discovery endpoint responds | AC1-03 | P0 | ac1-docker-compose-smoke.bats |
| Issuer URL matches realm URL | AC1-04 | P0 | ac1-docker-compose-smoke.bats |
| PostgreSQL has keycloak_db and rails_db | AC1-05 | P0 | ac1-docker-compose-smoke.bats |
| envocc realm present after import | AC1-06 | P0 | ac1-docker-compose-smoke.bats |
| sslRequired=external | AC1-07 | P0 | ac1-docker-compose-smoke.bats |
| accessTokenLifespan=900 | AC1-08 | P0 | ac1-docker-compose-smoke.bats |
| Mailpit web UI reachable | AC1-09 | P1 | ac1-docker-compose-smoke.bats |
| .env.example has placeholder keys | AC1-10 | P1 | ac1-docker-compose-smoke.bats |
| .env.example has only placeholder values | AC1-11 | P1 | ac1-docker-compose-smoke.bats |
| registrationAllowed=false | AC1-RC-01 | P0 | ac1-realm-config.bats |
| resetPasswordAllowed=true | AC1-RC-02 | P0 | ac1-realm-config.bats |
| rememberMe=false | AC1-RC-03 | P0 | ac1-realm-config.bats |
| loginWithEmailAllowed=true | AC1-RC-04 | P0 | ac1-realm-config.bats |
| SSO session timeouts correct | AC1-RC-05 | P0 | ac1-realm-config.bats |
| eventsEnabled + adminEventsEnabled=true | AC1-RC-06 | P0 | ac1-realm-config.bats |
| eventsExpiration=2592000 | AC1-RC-07 | P0 | ac1-realm-config.bats |
| displayName='EnvOcc SSO' | AC1-RC-08 | P0 | ac1-realm-config.bats |
| realm-export.json is valid JSON | AC1-RC-09 | P1 | ac1-realm-config.bats |
| realm-export.json has realm=envocc | AC1-RC-10 | P1 | ac1-realm-config.bats |
| Dockerfile: pinned image + import | AC1-RC-11 | P1 | ac1-realm-config.bats |
| compose.yaml has required services | AC1-RC-12 | P1 | ac1-realm-config.bats |
| compose.yaml has no hardcoded passwords | AC1-RC-13 | P1 | ac1-realm-config.bats |
| postgres/init.sql creates both DBs | AC1-RC-14 | P1 | ac1-realm-config.bats |
| REALM-EXPORT-NOTES.md documents stripped fields | AC1-RC-15 | P2 | ac1-realm-config.bats |

### AC2 — Secret hygiene: no secrets committed; gitleaks blocks any leak

| Scenario | Test ID | Priority | File |
|----------|---------|----------|------|
| realm-export.json passes gitleaks | AC2-01 | P0 | ac2-secret-hygiene.bats |
| No real clientSecret in realm-export.json | AC2-02 | P0 | ac2-secret-hygiene.bats |
| No real privateKey in realm-export.json | AC2-03 | P0 | ac2-secret-hygiene.bats |
| No real secretData in realm-export.json | AC2-04 | P0 | ac2-secret-hygiene.bats |
| Full repo passes gitleaks detect | AC2-05 | P0 | ac2-secret-hygiene.bats |
| .env is gitignored | AC2-06 | P0 | ac2-secret-hygiene.bats |
| *.pem and *.key are gitignored | AC2-07 | P0 | ac2-secret-hygiene.bats |
| admin/config/master.key is gitignored | AC2-08 | P0 | ac2-secret-hygiene.bats |
| .kamal/secrets is gitignored | AC2-09 | P0 | ac2-secret-hygiene.bats |
| .env.example is tracked by git | AC2-10 | P0 | ac2-secret-hygiene.bats |
| lefthook.yml configures gitleaks hook | AC2-11 | P1 | ac2-secret-hygiene.bats |
| ci.yml has gitleaks job | AC2-12 | P1 | ac2-secret-hygiene.bats |
| .gitleaks.toml exists | AC2-13 | P1 | ac2-secret-hygiene.bats |
| .gitleaks.toml allows 'change-me' placeholder | AC2-14 | P1 | ac2-secret-hygiene.bats |
| gitleaks blocks staged secret (hook behavioral) | AC2-15 | P1 | ac2-secret-hygiene.bats |

## Priority Summary

| Priority | Count | All tests RED (skipped) |
|----------|-------|------------------------|
| P0 — Critical | 21 | yes |
| P1 — High | 17 | yes |
| P2 — Medium | 1 | yes |
| P3 — Low | 0 | — |
| **Total** | **41** | |

## Task-by-Task Activation Guide

As you implement each task in Story 1.1, activate the corresponding test(s) by removing the `skip` line.

### Task 1: Scaffold repo structure and gitignore

Activate:
- `AC2-06` — .env is gitignored
- `AC2-07` — *.pem and *.key are gitignored
- `AC2-08` — admin/config/master.key is gitignored
- `AC2-09` — .kamal/secrets is gitignored
- `AC1-10` — .env.example has required placeholder keys
- `AC1-11` — .env.example has only placeholder values
- `AC2-10` — .env.example is tracked by git

### Task 2: Produce the baseline envocc realm export

Activate:
- `AC1-RC-09` — realm-export.json is valid JSON (static check, no docker needed)
- `AC1-RC-10` — realm-export.json has realm=envocc (static check)
- `AC2-01` — realm-export.json passes gitleaks
- `AC2-02` — No real clientSecret
- `AC2-03` — No real privateKey
- `AC2-04` — No real secretData
- `AC1-RC-15` — REALM-EXPORT-NOTES.md documents stripped fields

### Task 3: Write keycloak/Dockerfile and compose.yaml

Activate:
- `AC1-RC-11` — Dockerfile exists with pinned image + import (static)
- `AC1-RC-12` — compose.yaml has required services (static)
- `AC1-RC-13` — compose.yaml has no hardcoded passwords (static)
- `AC1-RC-14` — postgres/init.sql creates both databases (static)

Then bring up the stack and activate live integration tests:
- `AC1-01` through `AC1-09` (smoke.bats)
- `AC1-RC-01` through `AC1-RC-08` (realm-config.bats)

### Task 4: Install and configure gitleaks

Activate:
- `AC2-13` — .gitleaks.toml exists
- `AC2-11` — lefthook.yml configures gitleaks hook
- `AC2-12` — ci.yml has gitleaks job
- `AC2-14` — .gitleaks.toml allows 'change-me' placeholder
- `AC2-15` — gitleaks blocks staged secret (behavioral)
- `AC2-05` — Full repo passes gitleaks detect

### Task 5: Verify end-to-end

All tests should now be active and passing (GREEN phase).

## Running Tests

```bash
# Prerequisites
brew install bats-core gitleaks

# Run all (RED phase — all skip)
./tests/run-atdd.sh

# Run only secret hygiene tests (offline — no docker needed)
./tests/run-atdd.sh secrets

# Run only integration/smoke tests (requires docker compose up)
./tests/run-atdd.sh integration

# Run with explicit KC port override
KC_PORT=8080 ./tests/run-atdd.sh

# Bring down compose after integration tests
ATDD_TEARDOWN=true ./tests/run-atdd.sh integration
```

## Key Risks & Assumptions

1. **bats-core** must be installed on dev machines and CI runners. Add to CI workflow setup step.
2. **gitleaks** must be installed. Pin the version in CI to avoid ruleset drift.
3. The `_admin_token()` helper in `ac1-realm-config.bats` uses env vars `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD` — never hardcode real values. Tests use `change-me` placeholder which only works in local dev (not production).
4. AC2-05 (full repo gitleaks scan) may flag `.env.example` placeholders if allowlist is not configured — AC2-14 validates the allowlist is correct.
5. AC1-06 through AC1-08 require Keycloak to be fully up and the realm imported — add a retry/wait loop in CI before running these.

## Next Steps

1. **Run `dev-story`** workflow for Story 1.1 — this checklist is the acceptance gate
2. Implement tasks in order (Tasks 1 → 2 → 3 → 4 → 5)
3. Activate tests as each task completes
4. All 41 tests must be GREEN before the story is marked `done`
5. After story `done`, run `/bmad-testarch-automate` to generate the CI-integrated test suite
