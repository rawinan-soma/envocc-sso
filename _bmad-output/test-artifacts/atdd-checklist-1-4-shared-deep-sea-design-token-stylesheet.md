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
storyId: '1.4'
storyKey: 1-4-shared-deep-sea-design-token-stylesheet
storyFile: _bmad-output/implementation-artifacts/1-4-shared-deep-sea-design-token-stylesheet.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-4-shared-deep-sea-design-token-stylesheet.md
generatedTestFiles:
  - tests/design-tokens/deep-sea-token-coverage.test.mjs
inputDocuments:
  - _bmad-output/implementation-artifacts/1-4-shared-deep-sea-design-token-stylesheet.md
  - _bmad/tea/config.yaml
---

# ATDD Checklist: Story 1.4 — Shared Deep Sea Design-Token Stylesheet

## TDD Red Phase (Current)

All tests are scaffolded and skipped (`it.skip()`). They will FAIL when `design-tokens/deep-sea.css` does not exist or does not satisfy the acceptance criteria, and PASS after correct implementation.

**Total tests: 124 (all skipped — TDD red phase)**

### Test File

`tests/design-tokens/deep-sea-token-coverage.test.mjs`

Run command:
```bash
node --test tests/design-tokens/deep-sea-token-coverage.test.mjs
```

---

## Stack Detection

- **Detected stack:** static CSS (no package.json, no playwright.config, no backend framework at monorepo root)
- **Generation mode:** AI generation (acceptance criteria are clear, no browser recording required)
- **Test framework:** Node.js built-in test runner (`node:test`)
- **Execution mode:** Sequential

---

## Step 1: Preflight Summary

| Config Key | Value |
|---|---|
| story_key | `1-4-shared-deep-sea-design-token-stylesheet` |
| story_id | `1.4` |
| story_file | `_bmad-output/implementation-artifacts/1-4-shared-deep-sea-design-token-stylesheet.md` |
| test_artifacts | `_bmad-output/test-artifacts` |
| tea_use_playwright_utils | `true` (unused — no browser) |
| test_framework | auto → `node:test` |

---

## Step 3: Test Strategy

### Acceptance Criteria → Test Mapping

| AC | Description | Test Count | Priority | Level |
|---|---|---|---|---|
| AC1 | File exists at `design-tokens/deep-sea.css` | 2 | P0 | Static asset validation |
| AC2 | Complete token coverage (colors, typography, spacing, radius) | 100 | P0 | CSS parse / value check |
| AC3 | WCAG AA comment block with all verified pairings | 5 | P1 | Comment content check |
| AC4 | Plain CSS only — no Sass/Less/PostCSS syntax | 4 | P1 | Lint / syntax check |
| AC5 | Import path math from `admin/src/app.css` | 2 | P1 | Path resolution check |
| AC6 | Naming convention documented in file header | 5 | P2 | Comment content check |
| **Total** | | **118** | | |

> Note: individual token spot-checks (AC2) account for the high test count: 27 hex color value checks + spacing value checks + radius value checks + per-token existence checks.

### Red Phase Requirements

- All tests use `it.skip()` — they define expected behavior without running
- Tests assert EXPECTED behavior, not placeholders
- Removing `it.skip()` → `it()` activates each test task-by-task
- Activated tests FAIL until `design-tokens/deep-sea.css` is correctly implemented (TDD red)

---

## Step 4: Generated Test Infrastructure

### API Tests

N/A — this story produces a static CSS file with no runtime API surface.

### Static Asset Tests (Node.js)

**File:** `tests/design-tokens/deep-sea-token-coverage.test.mjs`

Test suites:
1. `AC1 — File exists at canonical path` (2 tests)
2. `AC2 — Color tokens declared on :root` (27 tests — one per token)
3. `AC2 — Typography tokens declared on :root` (25 tests — one per token)
4. `AC2 — Spacing tokens declared on :root` (9 tests — one per token)
5. `AC2 — Border-radius tokens declared on :root` (4 tests)
6. `AC2 — Key hex values match DESIGN.md exactly` (27 tests — spot-checks per color token)
7. `AC2 — Spacing values match 4-based scale` (9 tests)
8. `AC2 — Border-radius values` (4 tests)
9. `AC2 — Light-mode only (no dark-mode block)` (1 test)
10. `AC3 — WCAG AA comment block in file header` (5 tests)
11. `AC4 — Plain CSS only (no preprocessor syntax)` (4 tests)
12. `AC5 — Import path math from admin/src/app.css` (2 tests)
13. `AC6 — Naming convention documented in file header` (5 tests)

**Total: 124 tests, 13 suites — all skipped (TDD red phase)**

---

## Step 5: Validation

- [x] Prerequisites satisfied (story has clear acceptance criteria)
- [x] Test file created: `tests/design-tokens/deep-sea-token-coverage.test.mjs`
- [x] All tests scaffolded as `it.skip()` (TDD red phase)
- [x] Tests assert expected behavior (not placeholders)
- [x] All 6 acceptance criteria have test coverage
- [x] Node.js built-in runner — no external dependencies required
- [x] `node --test` run verified: 124 skip, 0 pass, 0 fail (correct red-phase behavior)
- [x] Checklist saved to `_bmad-output/test-artifacts/`
- [x] No orphaned temp artifacts

---

## Activation Guide (Task-by-Task)

During implementation of each task, activate the corresponding tests:

**Task 1 (Create directory and file):**
```
Remove it.skip → it in:
  - "AC1 — File exists at canonical path" suite (both tests)
```

**Task 2 (Color tokens):**
```
Remove it.skip → it in:
  - "AC2 — Color tokens declared on :root" suite
  - "AC2 — Key hex values match DESIGN.md exactly" suite
```

**Task 3 (Typography tokens):**
```
Remove it.skip → it in:
  - "AC2 — Typography tokens declared on :root" suite
```

**Task 4 (Spacing tokens):**
```
Remove it.skip → it in:
  - "AC2 — Spacing tokens declared on :root" suite
  - "AC2 — Spacing values match 4-based scale" suite
```

**Task 5 (Border-radius tokens):**
```
Remove it.skip → it in:
  - "AC2 — Border-radius tokens declared on :root" suite
  - "AC2 — Border-radius values" suite
```

**Task 6 (Plain CSS + import path):**
```
Remove it.skip → it in:
  - "AC2 — Light-mode only (no dark-mode block)"
  - "AC4 — Plain CSS only (no preprocessor syntax)" suite
  - "AC5 — Import path math from admin/src/app.css" suite
```

**Task 7 (Self-validation + file header):**
```
Remove it.skip → it in:
  - "AC3 — WCAG AA comment block in file header" suite
  - "AC6 — Naming convention documented in file header" suite
```

---

## Risks & Assumptions

| Risk | Mitigation |
|---|---|
| No package.json or test runner installed at monorepo root | Tests use `node:test` (built-in, no install needed, Node 18+) |
| `admin/` directory doesn't exist yet (story 4.1) | AC5 tests check path resolution math, not admin app existence |
| WCAG ratio values may differ slightly in comment wording | Tests use flexible regex: `/14\.5\s*:\s*1/` patterns |
| Token count drift (DESIGN.md updated after story written) | Each token tested individually — drift is immediately visible |

---

## Next Steps

1. **dev-story** — implement `design-tokens/deep-sea.css` following story tasks
2. Activate tests task-by-task (remove `it.skip` → `it`)
3. Run `node --test tests/design-tokens/deep-sea-token-coverage.test.mjs` — verify red then green
4. After implementation + green tests: run `bmad-code-review` (adversarial review)
5. `bmad-testarch-automate` — once file is green, if further automation is desired

---

## Handoff Path

- Story file: `_bmad-output/implementation-artifacts/1-4-shared-deep-sea-design-token-stylesheet.md`
- Test file: `tests/design-tokens/deep-sea-token-coverage.test.mjs`
- Checklist: `_bmad-output/test-artifacts/atdd-checklist-1-4-shared-deep-sea-design-token-stylesheet.md`
