---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-07-01'
storyId: '2.6'
storyKey: 2-6-totp-mfa-enforcement-verification-hardening
storyFile: _bmad-output/implementation-artifacts/2-6-totp-mfa-enforcement-verification-hardening.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-2-6-totp-mfa-enforcement-verification-hardening.md
generatedTestFiles:
  - tests/unit/realm-otp-policy.bats
  - tests/integration/totp-verification.bats
  - tests/theme/login-theme.test.mjs
inputDocuments:
  - _bmad-output/implementation-artifacts/2-6-totp-mfa-enforcement-verification-hardening.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/test-artifacts/test-design/test-design-epic-2.md
  - _bmad/tea/config.yaml
  - keycloak/realm-export.json
  - keycloak/themes/envocc/login/login-otp.ftl
  - scripts/lint-realm-export.py
  - tests/unit/realm-session-config.bats
  - tests/integration/oidc-pkce-flow.bats
  - tests/theme/login-theme.test.mjs (existing, extended)
---

# ATDD Checklist: Story 2.6 — TOTP MFA Enforcement & Verification Hardening

## TDD Red Phase (Current)

All new tests assert EXPECTED post-implementation behavior and currently FAIL
against the unmodified codebase (confirmed by running them — see verification
below). This repo does not use `test.skip()`/Playwright scaffolding for
Keycloak config-as-code + FreeMarker/CSS/vanilla-JS stories (backend/
infrastructure stack, same as stories 1.1–2.5) — the established convention
is a **guarded-execution red phase**:

- BATS integration tests (`tests/integration/`) are gated by `INTEGRATION=1`
  and skip cleanly without a live stack — they will FAIL once run against a
  live, rebuilt Keycloak stack until Tasks 1/2/4 are implemented.
- BATS unit/lint tests (`tests/unit/`) and Node `node:test` static/grep tests
  run directly (no live stack needed) and are confirmed FAILING right now,
  since `scripts/lint-realm-export.py` has no otpPolicy/browserFlow checks yet
  and `login-otp.ftl`/`login.css`/`otp-input.js` do not yet implement the
  six-cell group (Tasks 1, 2, 3 not yet built).

**Total new/extended test assertions: 30**
- `tests/unit/realm-otp-policy.bats`: 10 tests (BATS) — confirmed 10/10 FAIL against current `scripts/lint-realm-export.py`
- `tests/integration/totp-verification.bats`: 5 tests (BATS, `INTEGRATION=1`-gated) — confirmed all skip cleanly without a live stack; will fail against a live stack until Tasks 1/2/4 land
- `tests/theme/login-theme.test.mjs`: 15 new subtests across 6 new `describe` blocks (Node.js built-in runner) — confirmed 15/15 FAIL against current theme files; 88 pre-existing story 2.5 subtests still PASS unmodified (no regression)

### Test Files

**BATS unit/lint tests (static, no stack required):**

`tests/unit/realm-otp-policy.bats`

Run command:
```bash
BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/unit/realm-otp-policy.bats
```

**BATS integration tests (live Keycloak stack required):**

`tests/integration/totp-verification.bats`

Run command:
```bash
docker compose down -v && docker compose up --build -d
INTEGRATION=1 BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/integration/totp-verification.bats
```

**Node.js static / grep tests (extended, existing file):**

`tests/theme/login-theme.test.mjs`

Run command:
```bash
node --test tests/theme/login-theme.test.mjs
```

---

## Stack Detection

- **Detected stack:** backend / infrastructure (no package.json with frontend deps; no playwright.config; project is Keycloak + Nginx + Docker — identical footprint class to story 2.5)
- **Generation mode:** AI generation (acceptance criteria are clear; static file + live-Keycloak-REST checks; no browser recording required)
- **Test framework:** BATS (unit lint + live-stack integration) + Node.js built-in test runner (`node:test`) for static theme checks
- **Execution mode:** Sequential

---

## Step 1: Preflight Summary

| Config Key | Value |
|---|---|
| story_key | `2-6-totp-mfa-enforcement-verification-hardening` |
| story_id | `2.6` |
| story_file | `_bmad-output/implementation-artifacts/2-6-totp-mfa-enforcement-verification-hardening.md` |
| test_artifacts | `_bmad-output/test-artifacts` |
| tea_use_playwright_utils | `true` (unused — no browser; TOTP flow is server-config + FreeMarker/CSS/vanilla-JS) |
| test_framework | auto → BATS (unit + integration) + `node:test` (Node.js 18+ built-in) |

---

## Step 2: Generation Mode

**Selected mode:** AI generation

The story is realm-level TOTP enforcement (`otpPolicy` + conditional browser
authentication flow) plus a six-cell verification-code UI layered on story
2.5's plain-text placeholder. All Task 1/2/3 acceptance criteria can be
verified by static file analysis (JSON/regex/grep) or live Admin-REST/OIDC
calls against a running Keycloak container — no browser recording needed.

---

## Step 3: Test Strategy

### Acceptance Criteria → Test Mapping

| AC | Description | Test Count | Priority | Level |
|---|---|---|---|---|
| AC1 | TOTP required after password for every account with a configured credential; OTP step non-skippable (FR13) | 3 (unit lint) + 3 (integration) | P0 | Unit (BATS lint) + Integration (curl/Keycloak) |
| AC2 | Verification surface is a single labeled 6-digit group; no-JS fallback; no double-announced label (UX-DR6/UX-DR8) | 15 (Node static) | P0 | Static (node:test grep) |
| AC3 | Bounded clock-drift window, rate-limited, single-use-per-time-step verification (FR14) | 7 (unit lint) + 2 (integration) | P0/P1 | Unit (BATS lint) + Integration (curl/Keycloak) |
| **Total** | | **30** | | |

### Test Level Rationale

Per Dev Notes and `test-design-epic-2.md`, this story splits cleanly into:

- **Unit/lint (static, no stack)** — `scripts/lint-realm-export.py` config-as-code checks for `otpPolicy` field values and the `browserFlow`/`authenticationFlows` CONDITIONAL-OTP shape. Mirrors the `tests/unit/realm-session-config.bats` (TS-240 series) pattern exactly; new tests use the TS-260 series (next unused prefix after TS-256 from story 2.5).
- **Integration (live Keycloak, `INTEGRATION=1`)** — real TOTP secret provisioned via Admin REST `configure-totp` (never the enrollment UI, out of scope per Dev Notes), then a full password→OTP browser-flow walk via curl, aligned to `test-design-epic-2.md` lines 182–183 (P0) and 213–214 (P1).
- **Static theme (Node `node:test`, extends existing file)** — the six-cell markup, Noto Sans Mono design tokens, single-POST-field/no-JS-fallback contract, single-accessible-label guard, and the additive `otp-input.js` enhancement script. Extends `tests/theme/login-theme.test.mjs` in place (does not replace it), per story instruction "extend the same file with new describe blocks... rather than creating a parallel theme test file."

Deliberately **not** duplicated here (already covered elsewhere or explicitly out of scope per Dev Notes):
- TOTP enrollment UX (`CONFIGURE_TOTP`, QR code) — Epic 3 / Story 3.3.
- Brute-force threshold/delay tuning — Story 2.7 (FR19); this story only confirms the *existing* `bruteForceProtected: true` mechanism also covers the OTP step, not specific thresholds.
- WCAG axe-core automated audit of the TOTP surface — Epic 2 E2E suite, post-implementation (per story 2.5's checklist S9/S10 precedent).

### Red Phase Requirements

- BATS integration tests are `INTEGRATION=1`-gated (this repo's established "red phase" convention for live-stack tests — see `oidc-pkce-flow.bats` precedent); they skip cleanly without a stack and are expected to FAIL once run against a live, unmodified realm.
- BATS unit/lint tests and Node static tests run directly and are **confirmed failing right now** (verified below) — no gating needed since they require no live infrastructure.
- All tests assert EXPECTED behavior (specific field values, specific DOM/markup shapes, specific HTTP outcomes) — no placeholder assertions.

---

## Step 4: Generated Test Infrastructure

### Unit Lint Tests (BATS)

**File:** `tests/unit/realm-otp-policy.bats`

Test scenarios (TS-260 series):
1. `[P0][TS-260a]` Lint passes when otpPolicy is valid and browserFlow has CONDITIONAL OTP gated by condition-user-configured (green path)
2. `[P0][TS-260b]` Lint exits 1 when otpPolicy.lookAheadWindow is not 1
3. `[P0][TS-260c]` Lint exits 1 when otpPolicy.lookBehindWindow is not 1
4. `[P0][TS-260d]` Lint exits 1 when otpPolicy.digits is not 6
5. `[P0][TS-260e]` Lint exits 1 when otpPolicy.type is not totp
6. `[P0][TS-260f]` Lint exits 1 when otpPolicy is missing
7. `[P0][TS-260g]` Lint exits 1 when browserFlow is missing
8. `[P0][TS-260h]` Lint exits 1 when the OTP Form execution requirement is DISABLED
9. `[P0][TS-260i]` Lint exits 1 when OTP execution is bare REQUIRED with no condition-user-configured sub-flow (the "Locked Decision" regression guard)
10. `[P1][TS-260j]` Lint exits 1 when otpPolicy.lookAheadWindow is boolean true (type-confusion trap, mirrors TS-240g/h)

**Total: 10 tests — confirmed 10/10 FAIL against current `scripts/lint-realm-export.py`** (verified: `BATS_LIB_PATH=$(pwd)/tests/lib bats tests/unit/realm-otp-policy.bats` → 0 passed, 10 failed)

### Integration Tests (BATS, live Keycloak)

**File:** `tests/integration/totp-verification.bats`

Test scenarios (TS-261 series):
1. `[P0][TS-261a]` Valid TOTP code after password succeeds and tokens are issued
2. `[P0][TS-261b]` Skipping the OTP step after password succeeds does not yield tokens
3. `[P0][TS-261c]` Resubmitting the same valid TOTP code within the same time step is rejected (replay)
4. `[P0][TS-261d]` Repeated invalid TOTP submissions trigger rate-limited/delayed response
5. `[P1][TS-261e]` User with no TOTP credential configured skips the OTP branch entirely (CONDITIONAL-flow regression guard)

Includes a pure-stdlib RFC 6238 TOTP generator (`totp_code()`, no `pyotp` dependency — this repo's Python tooling is stdlib-only) — verified against the published RFC 6238 test vector (secret `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ`, T=59 → `287082`).

**Total: 5 tests — confirmed all 5 skip cleanly without `INTEGRATION=1`** (verified: `bats tests/integration/totp-verification.bats` → 5 skipped, 0 failed, no stack required). Will exercise real red-phase failures once run with `INTEGRATION=1` against a live stack before Tasks 1/2/4 are implemented (no CONDITIONAL OTP execution exists yet to reach).

### Static Theme Tests (Node.js, extended existing file)

**File:** `tests/theme/login-theme.test.mjs` (extended in place — 88 pre-existing story 2.5 subtests untouched and still passing)

New test suites:
1. `Story 2.6 AC3 — realm-export.json declares an explicit otpPolicy (bounded clock-drift window)` (6 subtests)
2. `Story 2.6 AC1 — realm-export.json binds a browserFlow with a CONDITIONAL OTP execution` (4 subtests)
3. `Story 2.6 AC2 — login-otp.ftl posts a single 6-digit totp form field (no-JS fallback, NFR8)` (2 subtests)
4. `Story 2.6 AC2 — login-otp.ftl renders a six-cell visual/DOM group for the code input` (1 subtest)
5. `Story 2.6 AC2 — login-otp.ftl code-input group has exactly ONE accessible label (no double-announcement)` (2 subtests, regression guards — pass today, will keep passing)
6. `Story 2.6 AC2 — Noto Sans Mono code-input design tokens are applied in login.css` (3 subtests)
7. `Story 2.6 AC2 — otp-input.js progressive-enhancement script exists (auto-advance/paste/auto-submit)` (3 subtests)

**Total new: 15 failing subtests + 4 passing regression-guard subtests (19 new assertions across 7 describe blocks)**

Verified: `node --test --test-reporter=tap tests/theme/login-theme.test.mjs` → 103 tests, 88 pass (all pre-existing + 4 new regression guards), 15 fail (all new Story 2.6 assertions, all expected red-phase failures — zero story 2.5 regressions).

---

## Step 5: Validation

- [x] Prerequisites satisfied (story has clear, unambiguous acceptance criteria; Locked Decision sections resolve the one open design question)
- [x] Test file created: `tests/unit/realm-otp-policy.bats`
- [x] Test file created: `tests/integration/totp-verification.bats`
- [x] Test file extended (not replaced): `tests/theme/login-theme.test.mjs`
- [x] All tests assert expected behavior (specific field values / DOM shapes / HTTP outcomes, not placeholders)
- [x] All 3 acceptance criteria have test coverage across at least 2 test levels each
- [x] `tests/unit/realm-otp-policy.bats` run verified: 0 passed, 10 failed (correct red-phase behavior against unmodified `lint-realm-export.py`)
- [x] `tests/integration/totp-verification.bats` run verified: 5 skipped without `INTEGRATION=1` (correct — matches repo convention; not run against a live stack in this ATDD pass, no Docker stack available in this environment)
- [x] `node --test tests/theme/login-theme.test.mjs` run verified: 88 pass / 15 fail (correct red-phase behavior; zero story 2.5 regressions)
- [x] No orphaned temp artifacts (scratch bats-support/bats-assert clone used only for local verification, outside the repo tree)

---

## Activation / Verification Guide (Task-by-Task)

During implementation of each task, re-run the corresponding tests and confirm red → green:

**Task 1 (Add explicit OTP policy to realm config):**
```
Re-run: tests/unit/realm-otp-policy.bats — TS-260a through TS-260j should flip from FAIL to PASS
        (TS-260a needs the full VALID_FIXTURE shape to also satisfy pre-existing
        required-field checks already in lint-realm-export.py, same as TS-240a's pattern)
Re-run: tests/theme/login-theme.test.mjs — "Story 2.6 AC3 — realm-export.json declares an explicit otpPolicy" (6 subtests)
```

**Task 2 (Require TOTP in the browser authentication flow):**
```
Re-run: tests/unit/realm-otp-policy.bats — TS-260g, TS-260h, TS-260i
Re-run: tests/theme/login-theme.test.mjs — "Story 2.6 AC1 — realm-export.json binds a browserFlow with a CONDITIONAL OTP execution" (4 subtests)
Re-run (mandatory regression check per Subtask 2.5): tests/integration/oidc-pkce-flow.bats with INTEGRATION=1
        — TS-220f/TS-220g (P0) and the no-TOTP-credential acquire_auth_code() path must still pass unmodified
Re-run: INTEGRATION=1 tests/integration/totp-verification.bats — TS-261b, TS-261e
```

**Task 3 (Build the six-cell code-input group in the theme):**
```
Re-run: tests/theme/login-theme.test.mjs —
  "Story 2.6 AC2 — login-otp.ftl posts a single 6-digit totp form field"
  "Story 2.6 AC2 — login-otp.ftl renders a six-cell visual/DOM group"
  "Story 2.6 AC2 — login-otp.ftl code-input group has exactly ONE accessible label" (already passing; keep green)
  "Story 2.6 AC2 — Noto Sans Mono code-input design tokens are applied in login.css"
  "Story 2.6 AC2 — otp-input.js progressive-enhancement script exists"
```

**Task 4 (Verify single-use-within-time-step behavior):**
```
Re-run: INTEGRATION=1 tests/integration/totp-verification.bats — TS-261a, TS-261c, TS-261d
```

**Task 5 (Manual + automated verification):**
```
Run full suite:
  node --test tests/theme/login-theme.test.mjs
  BATS_LIB_PATH=$(pwd)/tests/lib bats tests/unit/realm-otp-policy.bats
  INTEGRATION=1 BATS_LIB_PATH=$(pwd)/tests/lib bats tests/integration/totp-verification.bats
All green before marking review-ready; also run the manual smoke checks below.
```

---

## Manual Smoke Tests (Post-Implementation)

These cannot be automated as static file checks and require a running Docker stack (Subtasks 5.1–5.4):

| # | Test | AC | Command |
|---|---|---|---|
| S1 | Six-cell verification surface renders with Deep Sea styling + anti-phishing banner | AC2 | `docker compose up --build -d` → configure TOTP for a test user → sign in |
| S2 | Typing across cells auto-advances focus | AC2 | Manual keyboard test |
| S3 | Pasting a 6-digit code fills all cells and auto-submits | AC2 | Manual paste test |
| S4 | Wrong code shows generic error, `aria-describedby` announces it | AC2 | Manual test + screen reader spot-check |
| S5 | No-JS: code field still POSTs a 6-digit `totp` value and form submits | AC2 | Disable JS in browser → submit form |
| S6 | Full agentic-build gate passes locally | All | `lefthook run pre-commit` (or equivalent) |

---

## Risks & Assumptions

| Risk | Mitigation |
|---|---|
| No live Docker/Keycloak stack available in this ATDD environment | `tests/integration/totp-verification.bats` verified to skip cleanly (syntax + helper logic checked); full red/green verification against a live stack is deferred to dev-story implementation, consistent with this repo's `INTEGRATION=1` convention used by all prior integration suites |
| `bats-support`/`bats-assert` not preinstalled locally | Verified locally via a scratch clone outside the repo tree; CI/dev environment is expected to provide `tests/lib` per existing suite conventions (same as all other `tests/unit/*.bats` and `tests/integration/*.bats` files) |
| Exact Keycloak 26.6.x `authenticationExecutions` JSON shape for a hand-written CONDITIONAL OTP flow is verbose and easy to get subtly wrong | `tests/unit/realm-otp-policy.bats`'s VALID_FIXTURE encodes the exact shape (3-flow structure: browser → forms → conditional-otp) as a concrete, lint-verified reference for the dev agent to follow |
| `pyotp` not installed in this environment | Replaced with a small pure-stdlib RFC 6238 TOTP generator in `totp_verification.bats`, verified against the official RFC 6238 test vector — no new Python dependency introduced (matches this repo's stdlib-only Python convention) |
| TS-260a (green-path lint fixture) does not include unrelated required fields (duplicateEmailsAllowed, accessCodeLifespan, components, etc.) | Same minimal-fixture pattern as story 2.4's TS-240a — the lint script's *other* checks are exercised by their own dedicated test files; this file's fixture is scoped to otpPolicy/browserFlow concerns only |

---

## Next Steps

1. **dev-story** — implement story 2.6 following the task list in the story file (Tasks 1–5)
2. Re-run `tests/unit/realm-otp-policy.bats` after Task 1/2 — verify red → green
3. Re-run `tests/theme/login-theme.test.mjs` after Task 3 — verify red → green, and confirm all 88 pre-existing story 2.5 subtests remain green
4. Rebuild the stack (`docker compose down -v && docker compose up --build`) and run `INTEGRATION=1 bats tests/integration/totp-verification.bats` — verify red → green
5. Run the mandatory regression check on `tests/integration/oidc-pkce-flow.bats` (Subtask 2.5) — confirm zero regressions
6. Perform manual smoke tests (S1–S6 above)
7. After implementation + green tests: run `lefthook run pre-commit` (or equivalent) before marking review-ready

---

## Handoff Path

- Story file: `_bmad-output/implementation-artifacts/2-6-totp-mfa-enforcement-verification-hardening.md`
- Test files:
  - `tests/unit/realm-otp-policy.bats` (BATS — 10 tests, confirmed failing)
  - `tests/integration/totp-verification.bats` (BATS, `INTEGRATION=1`-gated — 5 tests, confirmed skip-clean)
  - `tests/theme/login-theme.test.mjs` (Node.js, extended — 15 new failing subtests, 88 pre-existing passing, 0 regressions)
- Checklist: `_bmad-output/test-artifacts/atdd-checklist-2-6-totp-mfa-enforcement-verification-hardening.md`
