---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-06-26'
storyId: '1.5'
storyKey: 1-5-agentic-build-ci-security-gate
storyFile: _bmad-output/implementation-artifacts/1-5-agentic-build-ci-security-gate.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-5-agentic-build-ci-security-gate.md
generatedTestFiles:
  - tests/unit/ci-security-gate.bats
  - tests/integration/ci-gate-jobs.bats
inputDocuments:
  - _bmad-output/implementation-artifacts/1-5-agentic-build-ci-security-gate.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-1.md
  - _bmad/tea/config.yaml
  - .github/workflows/ci.yml
  - tests/helpers/common.bash
  - tests/unit/secret-hygiene.bats
  - tests/unit/version-pinning.bats
  - tests/integration/stack-boot.bats
---

# ATDD Checklist: Story 1.5 — Agentic-build / CI Security Gate

## TDD Red Phase (Current)

Red-phase test scaffolds generated.

- Unit Tests (`tests/unit/ci-security-gate.bats`): 20 tests (all skipped — RED PHASE)
- Integration Tests (`tests/integration/ci-gate-jobs.bats`): 15 tests (all skipped — RED PHASE)
- **Total:** 35 tests, all with `skip "RED PHASE — ..."` annotation

## Stack & Generation Mode

- **Detected stack:** `backend` (infrastructure/CI — no browser UI, no API endpoints)
- **Generation mode:** AI generation (no browser recording needed for CI/shell tests)
- **Test framework:** BATS (matches existing `tests/unit/*.bats` and `tests/integration/*.bats` patterns)
- **Execution mode:** Sequential

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | Pre-commit hook (lefthook) runs gitleaks, Semgrep, realm-lint and blocks on failure | TS-151a through TS-151q (17 tests) | P0–P2 |
| AC2 | CI gate runs full applicable suite on push; fails on violation | TS-152a through TS-152o (15 tests) | P0–P2 |
| AC3 | Language-specific checks (ESLint/tsc/svelte-check/bun audit) no-op gracefully when admin/ absent | TS-153a through TS-153c (3 tests) | P0 |

## Test File Summary

### `tests/unit/ci-security-gate.bats`

Covers AC1 (pre-commit hook structure and behavior) and AC3 (graceful no-op guards in CI YAML).

| Test ID | Priority | Description | Task |
|---------|----------|-------------|------|
| TS-151a | P0 | lefthook.yml exists at repo root | Task 1.1 |
| TS-151b | P0 | lefthook.yml defines pre-commit group + secret-scan command | Task 1.1, 1.2 |
| TS-151c | P0 | lefthook.yml has sast command (semgrep) | Task 1.2 |
| TS-151d | P0 | lefthook.yml has realm-lint command | Task 1.2 |
| TS-151e | P0 | gitleaks protect uses --staged flag | Task 1.2 |
| TS-151f | P0 | gitleaks protect uses --redact flag | Task 1.2 |
| TS-151g | P0 | gitleaks protect references .gitleaks.toml | Task 1.2 |
| TS-151h | P1 | semgrep command uses --error flag | Task 1.2 |
| TS-151i | P1 | realm-lint command invokes scripts/lint-realm-export.py | Task 1.2 |
| TS-151j | P1 | scripts/lint-realm-export.py exists | Task 3 |
| TS-151k | P1 | lint-realm-export.py reads keycloak/realm-export.json | Task 3.1 |
| TS-151l | P1 | lint-realm-export.py exits 0 against valid realm-export.json | Task 3 |
| TS-151m | P1 | lint-realm-export.py exits 1 for malformed JSON | Task 3.2 |
| TS-151n | P1 | lint-realm-export.py exits 1 when required field missing | Task 3.3 |
| TS-151o | P2 | lint-realm-export.py detects clientSecret > 8 chars | Task 3.4 |
| TS-151p | P2 | lint-realm-export.py detects privateKey > 64 chars | Task 3.4 |
| TS-151q | P2 | README.md contains pre-commit setup section | Task 1.5 |
| TS-153a | P0 | ci.yml format-check job guarded on hashFiles(admin/package.json) | Task 2.1 |
| TS-153b | P0 | ci.yml dependency-audit job guarded on hashFiles(admin/package.json) | Task 2.4 |
| TS-153c | P0 | ci.yml language-checks job guarded on hashFiles(admin/package.json) | Task 2.6 |

### `tests/integration/ci-gate-jobs.bats`

Covers AC2 (CI workflow structure, job definitions, and regression preservation).

| Test ID | Priority | Description | Task |
|---------|----------|-------------|------|
| TS-152a | P0 | ci.yml defines a sast job for Semgrep | Task 2.2 |
| TS-152b | P0 | sast job uses semgrep --error | Task 2.2 |
| TS-152c | P0 | sast job generates SARIF output | Task 2.2 |
| TS-152d | P0 | sast job has permissions.security-events: write | Task 2.2 |
| TS-152e | P0 | ci.yml defines a realm-lint job | Task 2.5 |
| TS-152f | P0 | realm-lint job runs lint-realm-export.py | Task 2.5 |
| TS-152g | P0 | realm-lint job uses actions/setup-python@v5 | Task 2.5 |
| TS-152h | P1 | gitleaks job from Story 1.1 preserved (regression) | Task 2.3 |
| TS-152i | P1 | realm-export-check job from Story 1.2 preserved (regression) | Task 2.3 |
| TS-152j | P1 | all job IDs follow kebab-case naming | Task 2.7 |
| TS-152k | P1 | all jobs use runs-on: ubuntu-latest | Task 2.7 |
| TS-152l | P2 | sast job uploads SARIF via codeql-action/upload-sarif | Task 2.2 |
| TS-152m | P2 | lint-realm-export.py exits 0 smoke test (integration) | Task 3 |
| TS-152n | P2 | ci.yml YAML is syntactically valid | Task 2 |
| TS-152o | P2 | scripts/ directory is not in .gitignore | Task 3 |

## Next Steps (Task-by-Task Activation)

During implementation of each task:

1. Identify which test(s) correspond to the task you are implementing (see "Task" column above).
2. Remove the `skip "RED PHASE — ..."` annotation from those tests.
3. Run the activated tests: `bats tests/unit/ci-security-gate.bats` or `bats tests/integration/ci-gate-jobs.bats`
4. Verify the activated test **fails** first (confirming the red phase).
5. Implement the task until the test passes (green phase).
6. Commit passing tests with the implementation.

### Recommended Activation Order

- **Task 1 (lefthook.yml):** Activate TS-151a, TS-151b, TS-151c, TS-151d, TS-151e, TS-151f, TS-151g, TS-151h, TS-151i
- **Task 2 (ci.yml expansion):** Activate TS-152a through TS-152o, TS-153a, TS-153b, TS-153c
- **Task 3 (lint-realm-export.py):** Activate TS-151j through TS-151p, TS-152m, TS-152o
- **Task 4 (verify pre-commit locally):** Manual verification per story Dev Notes; no additional test activation
- **Task 5 (verify CI passes):** Manual verification; activate TS-152n, TS-152h, TS-152i as regression checks
- **Task 1.5 (README.md):** Activate TS-151q

## Implementation Guidance

### Files to create:
- `lefthook.yml` — repo root; pre-commit group with secret-scan, sast, realm-lint commands
- `scripts/lint-realm-export.py` — Python 3, no external deps; reads `keycloak/realm-export.json`
- `scripts/` directory — must NOT be gitignored

### Files to modify:
- `.github/workflows/ci.yml` — add sast, format-check (guarded), dependency-audit (guarded), realm-lint, language-checks (guarded) jobs
- `README.md` — add pre-commit gate section with `lefthook install` instruction

### Key constraints:
- DO NOT remove or modify existing `gitleaks` and `realm-export-check` jobs in ci.yml
- All admin-app-specific CI jobs MUST use `if: hashFiles('admin/package.json') != ''` guard
- Semgrep command MUST include `--error` (no `--no-error`)
- gitleaks pre-commit MUST use `protect --staged --redact --config .gitleaks.toml`

## Key Risks and Assumptions

- **R-009 (TECH):** CI gate runs language-specific checks before admin app exists — mitigated by `hashFiles()` guards (AC3). Tests TS-153a/b/c validate this.
- **lint-realm-export.py path argument:** TS-151m/n/o/p assume the script accepts an optional path argument for testability. If the script reads `keycloak/realm-export.json` as a hard-coded path only, adjust tests to use a temp symlink or env variable override. Document the approach in `scripts/README.md` or script docstring.
- **Semgrep scan time:** Full-repo scan in pre-commit can be slow. The story notes this is acceptable for the current small repo. If it becomes a concern, scope with `--include` glob.

## ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-1-5-agentic-build-ci-security-gate.md`
- Unit tests: `tests/unit/ci-security-gate.bats`
- Integration tests: `tests/integration/ci-gate-jobs.bats`
- Story file: `_bmad-output/implementation-artifacts/1-5-agentic-build-ci-security-gate.md`
