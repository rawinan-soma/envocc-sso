# Story 1.5: Agentic-build / CI Security Gate

Status: ready-for-dev

## Story

As the System Administrator,
I want a security/quality gate that runs locally pre-commit and in CI,
so that every change is held to the project's standards automatically.

## Acceptance Criteria

**AC1 — Pre-commit hook blocks on failure**
Given a commit,
When the pre-commit hook runs,
Then gitleaks, Semgrep, and realm-config lint execute and block on failure (NFR8, NFR9, AR8).

**AC2 — CI gate runs full suite on push**
Given a pushed branch,
When CI runs,
Then the gate runs the full applicable suite (formatting check, SAST, secret-scan, dependency audit, realm-config lint) and fails the build on any violation.

**AC3 — Language-specific checks no-op gracefully until admin app exists**
Given the admin app does not yet exist,
When the gate runs,
Then language-specific checks (ESLint/tsc/svelte-check/bun audit/tests) are wired but no-op gracefully until that app lands — no forward dependency.

## Tasks / Subtasks

- [ ] Task 1: Wire `lefthook.yml` pre-commit hook (AC1)
  - [ ] 1.1: Create `lefthook.yml` at the repo root
  - [ ] 1.2: Add `pre-commit` hook group that runs gitleaks (`gitleaks protect --staged --redact`), Semgrep (`semgrep scan --config auto --error`), and realm-config lint (`python3 scripts/lint-realm-export.py`)
  - [ ] 1.3: Each command must exit non-zero on violation so lefthook blocks the commit
  - [ ] 1.4: Run `lefthook install` to register the hook; verify `.git/hooks/pre-commit` is created
  - [ ] 1.5: Add a developer onboarding note to `README.md` under a "Pre-commit setup" section: `lefthook install` must be run once after cloning; list tool prerequisites (gitleaks, semgrep, python3)

- [ ] Task 2: Expand `.github/workflows/ci.yml` with all CI gate jobs (AC2)
  - [ ] 2.1: Add `format-check` job: Prettier (`npx prettier --check`) — no-op gracefully when `admin/` does not exist (conditional on directory presence)
  - [ ] 2.2: Add `sast` job: Semgrep with `semgrep scan --config auto --error --sarif --output semgrep.sarif`; upload SARIF as artifact; add `permissions: security-events: write` at the job level so GitHub can ingest the SARIF file
  - [ ] 2.3: Ensure `gitleaks` job already present (Story 1.1) scans full git history
  - [ ] 2.4: Add `dependency-audit` job: `bun audit` inside `admin/` — no-op gracefully (skip with `continue-on-error: false` only when directory exists; guard with `if: hashFiles('admin/package.json') != ''`)
  - [ ] 2.5: Add `realm-lint` job: run `python3 scripts/lint-realm-export.py`; include `actions/setup-python@v5` with `python-version: '3.x'` since ubuntu-latest has Python 3 but pinning the setup action is safer and explicit
  - [ ] 2.6: Add `language-checks` job: `eslint`, `tsc`/`svelte-check` inside `admin/` — guarded with `if: hashFiles('admin/package.json') != ''`
  - [ ] 2.7: Ensure all job names/ids follow kebab-case; all jobs use `ubuntu-latest`

- [ ] Task 3: Create `scripts/lint-realm-export.py` (or shell equivalent) for realm-config lint (AC1, AC2)
  - [ ] 3.1: Script reads `keycloak/realm-export.json`
  - [ ] 3.2: Validates JSON is parseable (exit 1 on parse error)
  - [ ] 3.3: Asserts required baseline fields: `realm`, `enabled`, `bruteForceProtected`, `accessTokenLifespan`
  - [ ] 3.4: Asserts no key material (`privateKey`, `certificate` > 64 chars, `clientSecret` > 8 chars) — mirrors gitleaks rules
  - [ ] 3.5: Prints human-readable error + exits 1 on failure, exits 0 on success

- [ ] Task 4: Verify pre-commit hook fires on local commit (AC1)
  - [ ] 4.1: Run `lefthook install`
  - [ ] 4.2: Stage a test commit; confirm gitleaks, Semgrep, and realm-lint all run
  - [ ] 4.3: Confirm a staged secret triggers gitleaks and blocks the commit
  - [ ] 4.4: Confirm a malformed realm-export.json triggers lint and blocks the commit

- [ ] Task 5: Verify CI workflow is syntactically valid and passes on the current codebase (AC2, AC3)
  - [ ] 5.1: Run `gh workflow list` or `act` dry-run to confirm YAML is valid
  - [ ] 5.2: Push the branch; confirm all jobs pass (gitleaks, sast, realm-lint) or skip gracefully (format-check, dependency-audit, language-checks with no admin app)
  - [ ] 5.3: Confirm the `gitleaks` and `realm-export-check` jobs from Story 1.1 still pass (no regressions)

## Dev Notes

### Overview

This story wires the "standing verification layer" described in AR8 — a two-layer gate:
1. **Inner loop (pre-commit):** Lefthook runs gitleaks + Semgrep + realm-lint locally before any commit lands.
2. **CI (GitHub Actions):** `.github/workflows/ci.yml` runs the full suite (formatting, SAST, secret-scan, dependency audit, realm-lint, language checks) on every push/PR.

The admin app (`admin/`) does not exist yet (arrives in Story 4.1). All admin-app-specific jobs (ESLint, tsc, svelte-check, bun audit, Vitest/Playwright) **must be wired but skip gracefully** via a directory-presence guard so they activate automatically when Story 4.1 lands without this workflow needing modification.

### Key Tools & Versions

| Tool | Purpose | Notes |
|------|---------|-------|
| **Lefthook** | Pre-commit hook manager | Replace any existing ad-hoc hook. `lefthook install` registers `.git/hooks/pre-commit`. Install via `brew install lefthook` or as a dev binary. |
| **gitleaks 8.24.0** | Secret scan | Already in CI (Story 1.1). Pre-commit: `gitleaks protect --staged --redact`. Config: `.gitleaks.toml`. |
| **Semgrep** (latest OSS) | SAST | `semgrep scan --config auto --error`. No account/token needed for `--config auto`. CLI install: `pip install semgrep` or `brew install semgrep`. |
| **Prettier** | Formatting check | `npx prettier --check '**/*.{ts,svelte,js,json,css,md}'` from `admin/`. Skip gracefully when `admin/` absent. |
| **ESLint** | JS/TS linting | `cd admin && npx eslint .` — skip gracefully. |
| **tsc + svelte-check** | Type check | `cd admin && npx tsc --noEmit && npx svelte-check` — skip gracefully. |
| **bun audit** | Dependency vulnerability | `cd admin && bun audit` — skip gracefully. |
| **realm-lint script** | JSON + field + secret check | `scripts/lint-realm-export.py` (or shell) — runs in both pre-commit and CI. |

### Existing CI File to Extend

**Current state of `.github/workflows/ci.yml`** (from Story 1.1):
- Two jobs: `gitleaks` (full history scan) and `realm-export-check` (targeted gitleaks on realm file)
- Both jobs manually install gitleaks 8.24.0 with SHA256 verification
- Triggers: push to `main`/`develop`/`story-*`, PR to `main`/`develop`

**What Story 1.5 adds to ci.yml:**
- `format-check` — Prettier (guarded on `admin/package.json` existing)
- `sast` — Semgrep (always runs; SARIF upload)
- `dependency-audit` — `bun audit` (guarded)
- `realm-lint` — `scripts/lint-realm-export.py` (always runs)
- `language-checks` — ESLint + tsc + svelte-check (guarded)

Do NOT remove or alter the existing `gitleaks` and `realm-export-check` jobs — they are the Story 1.1/1.2 gate.

### Lefthook Configuration Pattern

`lefthook.yml` lives at the **monorepo root** alongside `compose.yaml` (architecture tree, line 279).

```yaml
# lefthook.yml — pre-commit agentic-build gate
pre-commit:
  commands:
    secret-scan:
      run: gitleaks protect --staged --redact --config .gitleaks.toml
    sast:
      run: semgrep scan --config auto --error
    realm-lint:
      run: python3 scripts/lint-realm-export.py
```

The `run:` command must exit non-zero on failure — lefthook blocks the commit if any command fails.

**Important:** Semgrep runs a full-repo scan in pre-commit, which can be slow on large codebases. For this project (small repo), this is acceptable. If scan time becomes a concern, scope with `semgrep scan --config auto --error --include='*.py,*.ts,*.svelte,*.js'`. Do NOT use `--no-error` — that defeats the blocking purpose.

### CI Job Grace Pattern for Admin App

Use GitHub Actions `hashFiles()` guard to make admin-app jobs no-op until Story 4.1 lands:

```yaml
  format-check:
    name: Format Check (Prettier)
    runs-on: ubuntu-latest
    if: hashFiles('admin/package.json') != ''
    steps:
      - uses: actions/checkout@v4
      - name: Install Bun
        uses: oven-sh/setup-bun@v2
      - run: cd admin && bun install --frozen-lockfile
      - run: cd admin && bunx prettier --check '**/*.{ts,svelte,js,json,css,md}'
```

This way: right now the job is **skipped entirely** (GitHub Actions shows it as skipped, not failed), after Story 4.1 adds `admin/package.json` it activates automatically. The same pattern applies to `language-checks` and `dependency-audit`.

**Note on SARIF upload permissions:** The `sast` job needs job-level permissions set or the workflow-level `permissions` block must include `security-events: write`. Example:

```yaml
  sast:
    name: SAST (Semgrep)
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - run: pip install semgrep
      - run: semgrep scan --config auto --error --sarif --output semgrep.sarif
      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: semgrep.sarif
```

### Realm-Lint Script Spec

`scripts/lint-realm-export.py` (Python 3, no external dependencies):

1. Read `keycloak/realm-export.json`
2. `json.loads()` — exit 1 with message if parse fails
3. Assert presence of: `realm`, `enabled`, `bruteForceProtected`, `accessTokenLifespan`
4. Scan for key material: `privateKey` values > 64 chars, `clientSecret` > 8 chars — exit 1 if found
5. Exit 0 with "realm-export.json passed lint" on success

This mirrors the gitleaks rules already in `.gitleaks.toml` for defense-in-depth at the script level.

### Project Structure Notes

Files to **CREATE** (new):
- `lefthook.yml` — at monorepo root (architecture tree: `├── lefthook.yml # pre-commit: the agentic-build gate`)
- `scripts/lint-realm-export.py` — Python 3 lint script; `scripts/` is a new directory at monorepo root (alongside `compose.yaml`, `lefthook.yml`)
- `scripts/` directory — ensure it is NOT gitignored; source files, not build artifacts

Files to **MODIFY** (existing):
- `.github/workflows/ci.yml` — add 4–5 new jobs (gitleaks + realm-export-check jobs from Story 1.1 are preserved unchanged)
- `README.md` — add `### Pre-commit gate` subsection under `## Quick Start > ### Prerequisites` (after the existing `### TLS (local dev)` subsection added in Story 1.3) documenting: `lefthook install` run once after cloning, plus required tools (gitleaks 8.24.0, semgrep, python3)

Files that are **NOT touched** in this story:
- `compose.yaml`, `keycloak/`, `nginx/`, `postgres/`, `design-tokens/` — no changes
- `admin/` — does not exist yet; no forward dependency
- `.gitleaks.toml`, `.gitleaksignore` — already configured in Story 1.1/1.2; no changes needed
- `keycloak/realm-export.json` — read-only input to lint; not modified

### Dependency Context

- **Depends on 1.2** (realm-export.json exists and is gitleaks-clean) — lint script reads this file
- **Depends on 1.3** (Nginx edge in compose, port hygiene established) — no direct code dependency; gate validates the whole repo including nginx config
- **Depends on 1.4** (design-tokens/deep-sea.css exists) — gate will cover this file in Prettier/format checks once admin lands

All 1.x dependencies are merged to main (PRs #43–#46).

### Learnings from Previous Stories

**From Story 1.1 (Docker Compose):**
- Commit style: `feat(story-1-5): ...` prefix
- gitleaks 8.24.0 SHA256: `cb49b7de5ee986510fe8666ca0273a6cc15eb82571f2f14832c9e8920751f3a4` — do NOT change this in the existing jobs (already pinned)
- Tests use BATS at `tests/unit/` and `tests/integration/`; BATS tests exist for secret-hygiene and version-pinning

**From Story 1.2 (Realm config-as-code):**
- `keycloak/realm-export.json` is already gitleaks-clean and contains the required baseline fields (`realm`, `enabled`, `bruteForceProtected`, `accessTokenLifespan`) — the lint script should pass against the current file
- The realm-export-check CI job already exists and must NOT be removed

**From Story 1.3 (Nginx security edge):**
- `.gitignore` already has `nginx/certs/*.key|*.crt|*.pem` rules — gitleaks already covers these
- No Nginx-specific changes needed in this story

**From Story 1.4 (Design tokens):**
- `design-tokens/deep-sea.css` exists — Prettier format-check will eventually cover it once admin/ is present (same `**/*.css` glob applies)
- Tests for story 1.4 live at `tests/design-tokens/deep-sea-token-coverage.test.mjs`

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-1-5-agentic-build-ci-security-gate.md`
- Unit tests: `tests/unit/ci-security-gate.bats` (20 red-phase tests — AC1, AC3)
- Integration tests: `tests/integration/ci-gate-jobs.bats` (15 red-phase tests — AC2)

### Testing Approach

No new automated BATS tests are required (the gate IS the testing mechanism). Verification is:

1. **`lefthook install` smoke test:** After creating `lefthook.yml`, run `lefthook install` and confirm `.git/hooks/pre-commit` is created.
2. **Pre-commit gate negative test:** Stage a file with a known-bad secret pattern → confirm gitleaks blocks. Stage a malformed realm-export.json temporarily → confirm realm-lint blocks.
3. **CI YAML validity:** Use `gh workflow view ci` or push branch → confirm all new jobs appear and pass (or skip gracefully for admin-app jobs).
4. **Realm-lint script unit test:** Run `python3 scripts/lint-realm-export.py` directly against the current `keycloak/realm-export.json` — expect exit 0.
5. **Regression check:** Existing `gitleaks` and `realm-export-check` CI jobs must still pass.

### NFR / AR Compliance

- **NFR8** (no hand-rolled crypto) — enforced by AR8/this gate; Semgrep SAST detects crypto antipatterns
- **NFR9** (CI must include dependency/vulnerability scan + SAST + secret scan) — fully satisfied by this story
- **AR8** (standing layer on every story) — this story creates that standing layer; all subsequent stories inherit it

### Architecture References

- `lefthook.yml` at repo root: [Source: architecture.md#Complete Project Tree, line 279]
- `.github/workflows/ci.yml` at repo root: [Source: architecture.md#Complete Project Tree, line 280]
- Full gate tool list: Prettier · ESLint · `tsc`/`svelte-check` · Semgrep · gitleaks · `bun audit` · Vitest/Playwright · realm-config lint: [Source: architecture.md#Infrastructure & Deployment, line 181–183]
- AR8 definition: [Source: epics.md#Additional Requirements, AR8]
- NFR9 definition: [Source: prds/prd-envocc-sso-2026-06-21/prd.md#NFR9]
- Story 1.5 ACs: [Source: epics.md#Story 1.5, lines 334–355]
- "agentic gate ← every story (standing verification layer)": [Source: architecture.md#Cross-component dependencies, line 212]

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.5: Agentic-build / CI security gate] — story ACs
- [Source: _bmad-output/planning-artifacts/architecture.md#Infrastructure & Deployment] — tool list (Prettier, ESLint, tsc/svelte-check, Semgrep, gitleaks, bun audit, realm-config lint)
- [Source: _bmad-output/planning-artifacts/architecture.md#Complete Project Tree] — lefthook.yml and ci.yml file locations
- [Source: _bmad-output/planning-artifacts/architecture.md#Enforcement (mandatory for all agents)] — AR8 standing gate requirement
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements AR8] — gate scope
- [Source: _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-21/prd.md#NFR9] — CI dependency/vulnerability scan + SAST + secret scan requirement
- [Source: _bmad-output/implementation-artifacts/1-1-docker-compose-stack-pinned-keycloak-postgresql-two-databases.md] — gitleaks SHA256, existing CI job patterns
- [Source: _bmad-output/implementation-artifacts/1-2-realm-config-as-code-baseline-secret-hygiene.md] — realm-export.json baseline field set
- [Source: _bmad-output/implementation-artifacts/dependency-graph.md] — story 1.5 dependencies (1.2, 1.3, 1.4 all merged)
- [Source: .github/workflows/ci.yml] — existing gitleaks + realm-export-check jobs (must not regress)
- [Source: .gitleaks.toml] — existing gitleaks rules (realm-lint script mirrors these)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (Claude Code — bmad-create-story workflow, 2026-06-26)

### Debug Log References

None.

### Completion Notes List

### File List
