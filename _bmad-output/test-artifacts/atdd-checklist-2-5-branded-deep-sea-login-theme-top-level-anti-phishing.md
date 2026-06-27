---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-06-27'
storyId: '2.5'
storyKey: 2-5-branded-deep-sea-login-theme-top-level-anti-phishing
storyFile: _bmad-output/implementation-artifacts/2-5-branded-deep-sea-login-theme-top-level-anti-phishing.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-2-5-branded-deep-sea-login-theme-top-level-anti-phishing.md
generatedTestFiles:
  - tests/theme/login-theme.test.mjs
  - tests/unit/theme-config.bats
inputDocuments:
  - _bmad-output/implementation-artifacts/2-5-branded-deep-sea-login-theme-top-level-anti-phishing.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-2.md
  - _bmad/tea/config.yaml
---

# ATDD Checklist: Story 2.5 — Branded Deep Sea Login Theme (top-level, anti-phishing)

## TDD Red Phase (Current)

All tests are scaffolded and skipped (`it.skip()` / `skip`). They will FAIL when the theme files do not exist or do not satisfy the acceptance criteria, and PASS after correct implementation.

**Total tests: 111 (all skipped — TDD red phase)**
- `tests/theme/login-theme.test.mjs`: 82 tests (Node.js built-in runner)
- `tests/unit/theme-config.bats`: 29 tests (BATS)

### Test Files

**Node.js static / grep tests:**

`tests/theme/login-theme.test.mjs`

Run command:
```bash
node --test tests/theme/login-theme.test.mjs
```

**BATS shell tests (also static, no stack required):**

`tests/unit/theme-config.bats`

Run command:
```bash
BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/unit/theme-config.bats
```

---

## Stack Detection

- **Detected stack:** backend / infrastructure (no package.json with frontend deps; no playwright.config; project is Keycloak + Nginx + Docker)
- **Generation mode:** AI generation (acceptance criteria are clear; static file checks; no browser recording required)
- **Test framework:** Node.js built-in test runner (`node:test`) for JS static checks + BATS for shell/grep assertions
- **Execution mode:** Sequential

---

## Step 1: Preflight Summary

| Config Key | Value |
|---|---|
| story_key | `2-5-branded-deep-sea-login-theme-top-level-anti-phishing` |
| story_id | `2.5` |
| story_file | `_bmad-output/implementation-artifacts/2-5-branded-deep-sea-login-theme-top-level-anti-phishing.md` |
| test_artifacts | `_bmad-output/test-artifacts` |
| tea_use_playwright_utils | `true` (unused — no browser; theme is static HTML/CSS/FTL) |
| test_framework | auto → `node:test` (Node.js 18+ built-in) + BATS |

---

## Step 2: Generation Mode

**Selected mode:** AI generation

The story produces static configuration files (CSS, FreeMarker templates, `.properties` files, Dockerfile updates, JSON config). All acceptance criteria can be verified by static file analysis (regex/grep) without a running Docker stack. No browser recording is needed for the core test suite.

---

## Step 3: Test Strategy

### Acceptance Criteria → Test Mapping

| AC | Description | Test Count | Priority | Level |
|---|---|---|---|---|
| AC1 | Deep Sea tokens applied — login.css uses `var()` only, no raw hex; all required token refs present | 18 | P0 | Static (node:test grep) |
| AC2 | Top-level only — `realm-export.json` does NOT set conflicting `contentSecurityPolicy` | 4 | P0 | Static (node:test + BATS) |
| AC3 | Pinned non-dismissible anti-phishing banner in `login.ftl` and `login-otp.ftl` | 11 | P0 | Static (node:test + BATS) |
| AC4 | All strings externalized — `messages_en.properties` has all required keys; no hardcoded literals in `.ftl` | 22 | P0 | Static (node:test grep) |
| AC5 | WCAG 2.1 AA — `:focus-visible` in CSS; persistent `<label>` elements in templates | 12 | P1 | Static (node:test + BATS) |
| AC6 | Theme wired — `realm-export.json` sets `loginTheme`; Dockerfile COPYs theme BEFORE `kc.sh build` | 22 | P0 | Static (node:test + BATS) |
| AC7 | No-JS login path — forms use standard `method="post"` without `onsubmit` handlers | 8 | P0 | Static (node:test + BATS) |
| **Total** | | **97 unique** *(111 incl. duplicated cross-file checks)* | | |

### Test Level Rationale

This story is purely Keycloak theming (CSS + FreeMarker + `.properties`). There is no runtime API surface to test. The appropriate test levels are:

- **Static file / grep tests** — verify file existence, CSS variable usage, externalized strings, FreeMarker markup patterns, JSON config correctness, Dockerfile ordering
- **No unit/integration/E2E tests at this stage** — visual rendering and full accessibility audit are post-implementation manual checks (see Smoke Test section below)

Test design Epic 2 maps the following E2E checks to post-implementation:
- `Story 2.5 AC-1:` Auth surfaces served with `frame-ancestors 'none'` CSP (Integration curl) — verified by nginx (story 1.3); not duplicated here
- `Story 2.5 AC-1:` Login page uses Deep Sea CSS variables (Integration curl/grep) — covered by static tests
- `Story 2.5 AC-2:` Anti-phishing banner present on sign-in surface (E2E Playwright) — post-implementation
- `Story 2.5 AC-4:` WCAG 2.1 AA axe-core violations (E2E Playwright + axe) — post-implementation

### Red Phase Requirements

- All tests use `it.skip()` (node:test) or `skip` (BATS) — define expected behavior without running
- Tests assert EXPECTED behavior, not placeholders
- Removing `it.skip()` → `it()` / removing `skip` activates each test task-by-task
- Activated tests FAIL until the corresponding task is implemented (TDD red)

---

## Step 4: Generated Test Infrastructure

### Static File Tests (Node.js)

**File:** `tests/theme/login-theme.test.mjs`

Test suites:
1. `AC6 — Theme directory structure exists` (10 tests)
2. `AC6 — realm-export.json wires loginTheme` (2 tests)
3. `AC6 — Dockerfile COPYs theme before kc.sh build` (3 tests)
4. `AC2 — realm-export.json does not set conflicting contentSecurityPolicy` (2 tests)
5. `AC1 — login.css imports design-tokens/deep-sea.css` (1 test)
6. `AC1 — login.css uses CSS variables for all colors (no raw hex)` (14 tests)
7. `AC1 — login.css anti-phishing banner uses info color tokens` (4 tests)
8. `AC5 — login.css focus rings (WCAG AA)` (3 tests)
9. `AC3 — login.ftl has pinned non-dismissible anti-phishing banner` (6 tests)
10. `AC3 — login-otp.ftl has pinned non-dismissible anti-phishing banner` (4 tests)
11. `AC4 — messages_en.properties has all required string keys` (12 tests)
12. `AC4 — login.ftl has no hardcoded English UI strings` (8 tests)
13. `AC4 — login-otp.ftl has no hardcoded English UI strings` (2 tests)
14. `AC5 — login.ftl has persistent <label> for each <input>` (4 tests)
15. `AC5 — login-otp.ftl has persistent <label> for TOTP code input` (2 tests)
16. `AC7 — login.ftl uses standard HTML POST form (no-JS path)` (3 tests)
17. `AC7 — Any <script> tags in templates are additive` (1 test)

**Total: 82 tests, 17 suites — all skipped (TDD red phase)**

Verified: `node --test tests/theme/login-theme.test.mjs` → 82 skip, 0 pass, 0 fail

### Static Shell Tests (BATS)

**File:** `tests/unit/theme-config.bats`

Test groups:
1. `TS-251 [P0]` — AC6: Theme directory structure (6 tests: a–f)
2. `TS-251g/h/i [P0]` — AC6: realm-export.json and Dockerfile wiring (3 tests)
3. `TS-252 [P0]` — AC2: No conflicting CSP in realm config (2 tests: a–b)
4. `TS-253 [P0/P1]` — AC1: CSS variable usage in login.css (4 tests: a–d)
5. `TS-254 [P0]` — AC3: Anti-phishing banner in login.ftl (3 tests: a–c)
6. `TS-255 [P0]` — AC3: Anti-phishing banner in login-otp.ftl (2 tests: a–b)
7. `TS-256 [P0/P1]` — AC4: messages_en.properties required keys (3 tests: a–c)
8. `TS-257 [P0]` — AC4: No hardcoded strings in .ftl templates (2 tests: a–b)
9. `TS-258 [P1]` — AC5: WCAG focus ring and persistent labels (2 tests: a–b)
10. `TS-259 [P0]` — AC7: No-JS POST form (2 tests: a–b)

**Total: 29 tests — all skipped (TDD red phase)**

---

## Step 5: Validation

- [x] Prerequisites satisfied (story has clear acceptance criteria, all 7 ACs well-defined)
- [x] Test file created: `tests/theme/login-theme.test.mjs`
- [x] Test file created: `tests/unit/theme-config.bats`
- [x] All tests scaffolded as `it.skip()` / `skip` (TDD red phase)
- [x] Tests assert expected behavior (not placeholders)
- [x] All 7 acceptance criteria have test coverage
- [x] Node.js built-in runner — no external dependencies required for JS tests
- [x] `node --test` run verified: 82 skip, 0 pass, 0 fail (correct red-phase behavior)
- [x] No orphaned temp artifacts

---

## Activation Guide (Task-by-Task)

During implementation of each task, activate the corresponding tests:

**Task 1 (Create theme directory structure):**
```
Remove skip in:
  Node.js — "AC6 — Theme directory structure exists" (10 tests)
  BATS — TS-251a through TS-251f (6 tests)
```

**Task 2 (Create main theme CSS applying Deep Sea tokens):**
```
Remove skip in:
  Node.js — "AC1 — login.css imports design-tokens/deep-sea.css"
  Node.js — "AC1 — login.css uses CSS variables for all colors (no raw hex)"
  BATS — TS-253a, TS-253b, TS-253d
```

**Task 3 (Override FreeMarker templates — anti-phishing banner):**
```
Remove skip in:
  Node.js — "AC3 — login.ftl has pinned non-dismissible anti-phishing banner"
  Node.js — "AC3 — login-otp.ftl has pinned non-dismissible anti-phishing banner"
  Node.js — "AC4 — login.ftl has no hardcoded English UI strings"
  Node.js — "AC4 — login-otp.ftl has no hardcoded English UI strings"
  Node.js — "AC5 — login.ftl has persistent <label> for each <input>"
  Node.js — "AC5 — login-otp.ftl has persistent <label> for TOTP code input"
  Node.js — "AC7 — login.ftl uses standard HTML POST form"
  Node.js — "AC7 — Any <script> tags in templates are additive"
  BATS — TS-254a through TS-254c
  BATS — TS-255a, TS-255b
  BATS — TS-257a, TS-257b
  BATS — TS-258b
  BATS — TS-259a, TS-259b
```

**Task 4 (Externalize all strings — messages_en.properties):**
```
Remove skip in:
  Node.js — "AC4 — messages_en.properties has all required string keys"
  BATS — TS-256a, TS-256b, TS-256c
```

**Task 5 (Wire theme into realm config and Dockerfile):**
```
Remove skip in:
  Node.js — "AC6 — realm-export.json wires loginTheme"
  Node.js — "AC6 — Dockerfile COPYs theme before kc.sh build"
  Node.js — "AC2 — realm-export.json does not set conflicting contentSecurityPolicy"
  BATS — TS-251g, TS-251h, TS-251i
  BATS — TS-252a, TS-252b
```

**Task 6 (Anti-phishing banner CSS):**
```
Remove skip in:
  Node.js — "AC1 — login.css anti-phishing banner uses info color tokens"
  BATS — TS-253c
```

**Task 7 (WCAG AA and no-JS requirements):**
```
Remove skip in:
  Node.js — "AC5 — login.css focus rings (WCAG AA)"
  BATS — TS-258a
```

---

## Manual Smoke Tests (Post-Implementation)

These cannot be automated as static file checks and require a running Docker stack:

| # | Test | AC | Command |
|---|---|---|---|
| S1 | Visual: Deep Sea styling renders (teal card, warm-sand bg) | AC1 | `docker compose up --build -d` → visit login URL |
| S2 | Anti-phishing banner visible above form, non-dismissible | AC3 | Manual browser inspection |
| S3 | CSP header exactly once from nginx | AC2 | `curl -sI <login-url>` → assert single `Content-Security-Policy: frame-ancestors 'none'` |
| S4 | Login page not embeddable in iframe | AC2 | Load URL in iframe → browser blocks |
| S5 | No-JS: sign-in form submits | AC7 | Disable JS → test form POST |
| S6 | No-JS: TOTP form renders and submits | AC7 | Disable JS → test TOTP POST |
| S7 | Keyboard: all elements reachable via Tab in reading order | AC5 | Manual keyboard test |
| S8 | Focus ring visible on each focused element | AC5 | Manual keyboard test |
| S9 | WCAG AA: 0 axe-core violations on sign-in surface | AC5 | Playwright + axe-core (Epic 2 E2E suite) |
| S10 | WCAG AA: 0 axe-core violations on TOTP surface | AC5 | Playwright + axe-core (Epic 2 E2E suite) |

---

## Risks & Assumptions

| Risk | Mitigation |
|---|---|
| Keycloak 26.6.3 base `login.ftl` may differ from expected label/id attributes | Tests use patterns from the official Keycloak theme source; adjust regex if base theme differs |
| `browser-security-headers` key casing varies across Keycloak versions | Tests check both absent and empty `contentSecurityPolicy` as acceptable |
| BATS may not be installed in CI | BATS tests run in the existing `tests/unit/` suite which already has a `setup_suite.bash`; same environment as other `.bats` files |
| CSS `@import` order may be browser-dependent for `:root` overrides | Import order is also asserted (deep-sea.css imported first) |
| No playwright.config.ts exists (no browser E2E in red phase) | Playwright E2E for axe-core/banner visibility is post-implementation per Epic 2 test design |

---

## Next Steps

1. **dev-story** — implement story 2.5 following the task list in the story file
2. Activate tests task-by-task (remove `it.skip` → `it` / remove `skip` in BATS)
3. Run `node --test tests/theme/login-theme.test.mjs` — verify red then green for each task
4. Run `bats tests/unit/theme-config.bats` — verify red then green for each task
5. Perform manual smoke tests (S1–S8 above) after `docker compose up --build`
6. After implementation + green tests: run `bmad-testarch-automate` if E2E automation of smoke tests is desired

---

## Handoff Path

- Story file: `_bmad-output/implementation-artifacts/2-5-branded-deep-sea-login-theme-top-level-anti-phishing.md`
- Test files:
  - `tests/theme/login-theme.test.mjs` (Node.js — 82 skip)
  - `tests/unit/theme-config.bats` (BATS — 29 skip)
- Checklist: `_bmad-output/test-artifacts/atdd-checklist-2-5-branded-deep-sea-login-theme-top-level-anti-phishing.md`
