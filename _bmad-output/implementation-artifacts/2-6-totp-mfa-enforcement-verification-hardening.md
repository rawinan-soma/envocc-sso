---
baseline_commit: 67899fd51c2f44ce4677cc995fb607089c29e4dc
---

# Story 2.6: TOTP MFA enforcement & verification hardening

Status: ready-for-dev

## Story

As a staff member,
I want a second factor at sign-in,
so that a stolen password alone can't impersonate me.

## Acceptance Criteria

1. **TOTP required after password for every account with a configured credential (FR13):**
   **Given** a staff account that has a TOTP credential configured
   **When** signing in with email + password
   **Then** a TOTP code is required after the password succeeds via the **browser authentication flow** (not the direct-grant/ROPC path, which is already rejected entirely per FR3/story 2.2) — the OTP step cannot be bypassed: completing only the password step and then attempting to obtain tokens without completing OTP does not yield tokens. (Enrollment for accounts that do **not yet** have a TOTP credential is Epic 3/Story 3.3 scope — out of scope here; see Dev Notes "Flow Requirement Level.")

2. **Verification surface is a single labeled 6-digit group (UX-DR6, UX-DR8):**
   **Given** the verification surface
   **When** I enter the code
   **Then** it renders as **six individual Noto-Sans-Mono cells** that behave and are announced as **one logical field**: typing in a cell auto-advances focus to the next cell, `Backspace` on an empty cell steps focus back, pasting a full 6-digit code fills all six cells in one action, and entering/pasting the 6th digit auto-submits the form. The group has exactly one accessible label bound to it (the existing `<label for="totp">` pattern from story 2.5 already satisfies this if the underlying field stays one `<input id="totp">` — see Dev Notes "Code-Input Implementation Approach" — do not add a redundant `aria-label` alongside an existing `<label for>`, that double-announces to screen readers). The existing `login-otp.ftl` single plain-text input (story 2.5 placeholder) is visually replaced by this six-cell presentation. No-JS fallback: with JavaScript disabled, the code field still form-submits a 6-digit value via standard POST (progressive enhancement, NFR8-aligned — no framework in the login path).

3. **Bounded clock-drift, rate-limited, single-use-per-time-step verification (FR14):**
   **Given** code verification
   **When** a code is checked
   **Then**:
   - it is accepted only within a **bounded clock-drift window** — realm `otpPolicy.lookAheadWindow` and `otpPolicy.lookBehindWindow` are both explicitly set to `1` (±1 time step = ±30s at the default 30s period; Keycloak default already resolves to this — this AC requires the value to be **explicit in `realm-export.json`**, not implicit, so it is config-as-code and lint-enforced);
   - TOTP verification is **rate-limited**: brute-force protection (already realm-enabled via `bruteForceProtected: true`, story 2.1) applies to the OTP step the same as the password step — repeated invalid TOTP submissions for one account trigger the same progressive-delay lockout as repeated invalid passwords (verified via `bruteForceProtected` covering the OTP authenticator execution, not just username/password);
   - a **verified code is single-use within its time step** — resubmitting the exact same valid code a second time within the same 30-second step is rejected (Keycloak's built-in OTP replay cache, enabled by default when TOTP is configured — this AC requires verifying it is not disabled anywhere in realm config).

## Tasks / Subtasks

- [ ] Task 1: Add explicit OTP policy to realm config (AC: 3)
  - [ ] Subtask 1.1: Add `"otpPolicy"` object to `keycloak/realm-export.json` at realm root: `type: "totp"`, `algorithm: "HmacSHA1"`, `digits: 6`, `period: 30`, `lookAheadWindow: 1`, `lookBehindWindow: 1` (all explicit — do not rely on Keycloak defaults being implicitly correct; config-as-code requires literal values)
  - [ ] Subtask 1.2: Do NOT add `initialCounter` (that field is HOTP-only; this realm uses TOTP only, per FR13/FR14 and architecture Decision 1)
  - [ ] Subtask 1.3: Verify `bruteForceProtected: true` (already set, story 2.1) has no scope restriction that would exclude the OTP authenticator execution — Keycloak's brute-force protection applies at the user/flow level, not per-authenticator, so no additional realm field is needed; document this in Dev Notes for the reviewer

- [ ] Task 2: Require TOTP in the browser authentication flow for users with a credential (AC: 1)
  - [ ] Subtask 2.1: Add an `"authenticationFlows"` array to `realm-export.json` defining a custom browser flow (copy-and-modify pattern from Keycloak's built-in `browser` flow) where the OTP Form execution's `requirement` is `"CONDITIONAL"`, with its condition sub-flow set to `condition-user-configured` scoped to the OTP credential type (Keycloak's standard "conditional OTP" pattern: **if** the user has a TOTP credential, OTP becomes non-skippable within that branch; **if not**, the branch is skipped entirely and login succeeds on password alone). This is the final, locked decision for this story — do NOT implement hard `REQUIRED` (see Dev Notes "Flow Requirement Level" for why: `REQUIRED` would strand any account without a TOTP credential, and this story does not build the Epic-3 enrollment/`CONFIGURE_TOTP` redirect that would be needed to recover from that).
  - [ ] Subtask 2.2: Set `"browserFlow"` at the realm root to reference the new/modified flow so it is bound as the realm's active browser flow
  - [ ] Subtask 2.3: Confirm the flow still starts with Cookie → Kerberos (disabled) → Identity Provider Redirector → forms (username/password) → OTP, matching Keycloak's standard browser-flow shape — do not remove or reorder the non-OTP executions
  - [ ] Subtask 2.4: Extend `scripts/lint-realm-export.py` to assert: `otpPolicy.lookAheadWindow == 1`, `otpPolicy.lookBehindWindow == 1`, `otpPolicy.digits == 6`, `otpPolicy.type == "totp"`, and that a `browserFlow` is set and its referenced flow contains an OTP execution set to `CONDITIONAL` with a `condition-user-configured` sub-flow (not `DISABLED`, and not bare `REQUIRED` with no condition). Add corresponding BATS test cases in `tests/unit/` (new file `tests/unit/realm-otp-policy.bats`, following the `tests/unit/realm-session-config.bats` TS-240 pattern — use TS-260 series IDs)
  - [ ] Subtask 2.5: **Mandatory regression fix** — `tests/integration/oidc-pkce-flow.bats` creates a fresh test user with `"requiredActions": []` and no TOTP credential (setup block ~line 142-162), then its `acquire_auth_code()` helper (lines 66-122) posts username+password and expects the auth code directly in the response `Location` header, with no OTP step. Under `CONDITIONAL`-scoped-to-configured-credential (Subtask 2.1), this test is **unaffected** — a user with no TOTP credential skips the OTP branch exactly as before, so `acquire_auth_code()` keeps working unmodified. Run this file after the flow change and confirm all existing `TS-220*` cases (including `TS-220f`/`TS-220g`, P0) still pass; if any fail, the flow config was implemented wrong (most likely: `REQUIRED` was used instead of `CONDITIONAL`, or the condition sub-flow is missing) — fix the flow config, do not modify the pre-existing test to work around it.

- [ ] Task 3: Build the six-cell code-input group in the theme (AC: 2)
  - [ ] Subtask 3.1: Rewrite `keycloak/themes/envocc/login/login-otp.ftl` — replace the single `<input id="totp" name="totp" ...>` with a **visually six-celled, functionally single-field** group. Two implementation paths are viable; pick the one that satisfies the no-JS fallback requirement (AC2) — see Dev Notes "Code-Input Implementation Approach"
  - [ ] Subtask 3.2: The group has exactly one accessible label. If the recommended single-`<input id="totp">` approach (Dev Notes) is used, the existing `<label for="totp">${msg("loginTotpOneTime")}</label>` pattern from story 2.5 already satisfies this — keep it, do not add an additional `aria-label`. Only if the alternative six-real-inputs approach is chosen does the group need a wrapping container with `role="group"` + `aria-labelledby` pointing at one visible label (and in that case the six inputs themselves must NOT carry individual labels).
  - [ ] Subtask 3.3: Preserve existing behavior from story 2.5: anti-phishing banner stays pinned above the form; credential-selector radio list (multiple TOTP credentials) stays inside the `<form>`; inline error span + `aria-describedby` wiring (fixed in story 2.5 review) is preserved for the new field structure
  - [ ] Subtask 3.4: Add `keycloak/themes/envocc/login/resources/js/otp-input.js` (or inline `<script>` in the template) implementing: per-cell auto-advance on digit entry, `Backspace` step-back, full-paste-fills-all-six, auto-submit on 6th digit. Script is additive only — the underlying `<input name="totp">` (or six inputs merged server-side) must still work with JS disabled
  - [ ] Subtask 3.5: Style the six cells in `login.css` using `var(--font-code-family)` (Noto Sans Mono), `var(--font-code-size)` (24px), `var(--color-border)` cell border, `var(--color-accent)` focus-cell border — matching the `code-input` design-token spec (DESIGN.md#Components)
  - [ ] Subtask 3.6: Update `messages_en.properties` if any new message keys are introduced for the group's accessible label (reuse `loginTotpOneTime` where possible; do not hardcode strings — externalize per FR12/UX-DR2, the standing rule from story 2.5)

- [ ] Task 4: Verify single-use-within-time-step behavior (AC: 3)
  - [ ] Subtask 4.1: Confirm no realm or theme config disables Keycloak's built-in OTP replay protection (there is no config flag to check "off" — absence of any override is the pass condition; document the check in Dev Notes so the reviewer can verify by inspection)
  - [ ] Subtask 4.2: Add an integration test (`tests/integration/totp-verification.bats`, new file) that authenticates with a real TOTP secret (configured via Admin REST `PUT /admin/realms/{realm}/users/{id}/configure-totp` on a test user — do NOT build a UI-driven enrollment flow, that is Epic 3 scope) then: (a) submits a valid code → success; (b) immediately resubmits the same code → rejected; (c) skips the OTP step entirely after password → no token issued; (d) submits several invalid codes in a row → rate-limited/delayed response

- [ ] Task 5: Manual + automated verification (AC: all)
  - [ ] Subtask 5.1: `docker compose up --build -d` — rebuild Keycloak image with updated realm config + theme
  - [ ] Subtask 5.2: Configure TOTP for a test user via Admin REST API; sign in with password; confirm the six-cell verification surface renders with Deep Sea styling and the anti-phishing banner from story 2.5
  - [ ] Subtask 5.3: Type a code across the six cells — confirm auto-advance; paste a 6-digit code — confirm all cells fill and form auto-submits; enter a wrong code — confirm generic error, `aria-describedby` announces it
  - [ ] Subtask 5.4: Disable JavaScript — confirm the code field(s) still POST a 6-digit `totp` value and the form still submits
  - [ ] Subtask 5.5: Run `node --test tests/theme/login-theme.test.mjs`, `bats tests/unit/realm-otp-policy.bats`, `bats tests/integration/totp-verification.bats` — all green
  - [ ] Subtask 5.6: Run the full agentic-build gate locally (`lefthook run pre-commit` or equivalent) before marking review-ready

## Dev Notes

### What This Story Builds

Realm-level TOTP enforcement (`otpPolicy` + browser-flow OTP requirement) plus the accessible six-cell verification-code UI on top of the plain-text placeholder story 2.5 shipped. This is almost entirely Keycloak config-as-code (`realm-export.json`) + FreeMarker/CSS/vanilla-JS theme work — **no admin-app code, no SvelteKit, no Drizzle** (same pattern as story 2.5).

**What this story does NOT build (explicitly out of scope, confirmed by epics.md FR coverage map and test-design-epic-2.md):**
- TOTP **enrollment** UX (`CONFIGURE_TOTP` required action screen, QR code, secret display) — that is Epic 3 / Story 3.3 (first-login activation). This story assumes a TOTP credential already exists on the user (test setup uses Admin REST `configure-totp`, never the enrollment UI).
- Admin-triggered MFA reset — FR15, Epic 3/Story 3.5 and Epic 4/Story 4.6.
- Brute-force *tuning* (failure thresholds, delay schedule) — that is Story 2.7's explicit scope (FR19). This story only confirms the *existing* `bruteForceProtected: true` mechanism also covers the OTP step; it does not change lockout thresholds.
- "Login with ThaiD" — Story 2.9. ThaiD is an alternative to the password+TOTP path entirely, not layered on top of it.

### Critical: What Story 2.5 Already Built (Read This First)

`keycloak/themes/envocc/login/login-otp.ftl` **already exists** — it was created in story 2.5 as a **visual-styling-only placeholder**: a single plain `<input id="totp" name="totp" type="text">`, the anti-phishing banner, and the multi-credential radio selector. Story 2.5's dev notes state explicitly: *"The TOTP MFA flow logic (story 2.6) — only the visual styling of the TOTP code-input surface"* was in scope for 2.5; the flow logic and the six-cell interaction model are this story's job.

Do not recreate `login-otp.ftl` from scratch — **modify the existing file**, preserving:
- The anti-phishing banner block (lines ~9-16) — untouched.
- The credential-selector `<#if otpLogin.userOtpCredentials?? && otpLogin.userOtpCredentials?size gt 1>` block — untouched, must remain inside `<form>` so `selectedCredentialId` posts correctly.
- The `aria-describedby`-on-input pattern (input references the error span id, not the reverse) — this was a story-2.5 review fix; replicate it for whichever new field structure you introduce.
- `displayMessage=!messagesPerField.existsError('totp')` on the layout macro call — untouched, avoids duplicate error rendering.

The current single-input field posts a `name="totp"` value to `${url.loginAction}`. **Whatever six-cell markup you introduce must still ultimately POST a single `totp` form field with the full 6-digit string** — Keycloak's `OTPFormAuthenticator` (server-side, not overridable without custom SPI) reads `request.getFirstParam("totp")`. Do not attempt to change the POST parameter name or split it into six separate parameters; that would require a custom Java authenticator (forbidden by NFR8 — no hand-rolled auth logic).

### Code-Input Implementation Approach

Two ways to get "looks like six cells, behaves as one field, and still works with JS disabled":

**Recommended: single real `<input name="totp">` visually rendered as six characters, with a JS-only decorative overlay.** Keep `<input id="totp" name="totp" type="text" inputmode="numeric" maxlength="6" pattern="[0-9]{6}">` as the actual form field (this is what makes the no-JS path trivially correct — it already works, per AC2's no-JS requirement). Style it with `letter-spacing` and a repeating-gradient/background trick (or six overlaid pseudo-cell `<div>` borders positioned via CSS Grid behind a transparent-ish input) to *look* like six bordered cells. A small enhancement script can auto-submit on the 6th keystroke (`input.value.length === 6`) and could optionally visually re-render six `<div>` cells above the real input showing live characters as extra affordance, but the underlying field stays one `<input>`.

**Alternative: six separate `<input>` elements (one per digit) + JS that concatenates them into a single hidden `<input name="totp">` before submit.** This gives cleaner individual-cell CSS but is **not accessible or functional without JS** unless you also add a `<noscript>` fallback single input — more moving parts, higher risk of failing the no-JS AC. If chosen, the `<noscript>` block must render the same plain single input as a fallback, and the six visible inputs must have `aria-hidden` removed appropriately without double-announcing to assistive tech.

**Decide and document the choice in Completion Notes.** Either approach must satisfy: (a) accessible as ONE labeled field (not six unlabeled ones) to a screen reader, (b) works with JS disabled, (c) auto-advances/pastes/auto-submits with JS enabled, (d) posts a single `totp` value.

### Flow Requirement Level — Locked Decision (do not deviate)

Keycloak's built-in `browser` flow has the OTP Form execution set to `CONDITIONAL` by default, gated by a `condition-user-configured` sub-flow: OTP is asked for (and non-skippable) **only if** the user already has a TOTP credential; if not, login succeeds on password alone. This story uses exactly that shape — **`CONDITIONAL` + `condition-user-configured`, not bare `REQUIRED`.**

Why not `REQUIRED`: **TOTP enrollment itself is Epic 3's job** (test-design-epic-2.md's "Not in Scope" table confirms this story assumes enrollment already happened). A hard `REQUIRED` OTP step would strand any account that hasn't enrolled yet with no way to log in — this story does not build the `CONFIGURE_TOTP` required-action/redirect machinery that would be needed to recover from that (no `requiredActions` changes are in this story's Task list or File List; that wiring belongs to Story 3.3). Introducing `REQUIRED` without that escape hatch would be a self-inflicted regression, not a completion of AC1.

Why `CONDITIONAL` still satisfies AC1: AC1 is scoped to accounts that **have** a TOTP credential configured ("skipping the TOTP step... does not yield tokens" — see the AC1 test scenario in test-design-epic-2.md line 182-183, which explicitly authenticates a user, "completes the password step," then attempts to skip OTP). For such a user, the `condition-user-configured` branch is entered and OTP becomes non-skippable — AC1 is fully met. For a user with no credential (out of this story's scope), the branch is skipped, which is correct and matches Keycloak's default/expected behavior — it is not a bypass of AC1, because AC1 does not apply to unenrolled accounts.

**Verified compatibility with existing tests:** `tests/integration/oidc-pkce-flow.bats` creates a test user with no TOTP credential and logs in password-only via its `acquire_auth_code()` helper, expecting an immediate auth code — this is unaffected by the `CONDITIONAL` flow (the OTP branch is skipped for that user, exactly as today). Do not use `REQUIRED`; it would break this file's P0 tests (`TS-220f`, `TS-220g`) with no sanctioned fix within this story's scope. See Task 2.5 for the mandatory post-implementation regression check.

### otpPolicy Field Reference (Keycloak 26.6.x)

```json
"otpPolicy": {
  "type": "totp",
  "algorithm": "HmacSHA1",
  "digits": 6,
  "period": 30,
  "lookAheadWindow": 1,
  "lookBehindWindow": 1
}
```
`lookAheadWindow`/`lookBehindWindow` of `1` each = accept codes from 1 period before/after the server's current step (±30s at period=30s) — this is the "bounded clock-drift window" FR14 asks for and is Keycloak's documented default; making it explicit is what closes the "TOTP clock-drift window undocumented" gap flagged as an unknown in test-design-epic-2.md line 129. `HmacSHA1` is the RFC 6238 standard algorithm every authenticator app (Google Authenticator, Authy, etc.) expects — do not change to SHA256/SHA512 without confirming client-app compatibility (out of scope to explore here; use the default).

### Realm Export — Current State (verified by reading the file)

`keycloak/realm-export.json` currently has **no** `otpPolicy`, **no** `authenticationFlows`, **no** `browserFlow` key, and **no** `requiredActions` array. `bruteForceProtected: true` is already set (story 2.1). This story is the first to touch auth-flow/OTP-policy fields — there is no existing config to conflict with, but also no precedent in this repo for `authenticationFlows` JSON shape. Reference Keycloak 26.6.3's own exported default realm (or the upstream `keycloak/keycloak` repo's example realm JSON) for the exact `authenticationFlows`/`authenticationExecutions` array shape before hand-writing it — this is a verbose, easy-to-get-subtly-wrong structure (each execution needs `authenticator`, `requirement`, `priority`, `userSetupAllowed`, `autheticatorFlow` fields correctly set).

### realm-export.json Lint Extension Pattern

`scripts/lint-realm-export.py` already validates `accessTokenLifespan`, `revokeRefreshToken`, `refreshTokenMaxReuse`, boolean-exact checks on `bruteForceProtected`/`enabled`/etc., and per-client PKCE/flow checks (stories 2.1, 2.2, 2.4). Follow the same pattern: add new checks as additional functions/blocks in the same file, each printing a clear stderr message and contributing to a nonzero exit code. Add corresponding BATS fixtures in a new `tests/unit/realm-otp-policy.bats` file mirroring `tests/unit/realm-session-config.bats`'s structure (`VALID_FIXTURE` JSON heredoc + mutation-pattern tests per invalid value) — use `TS-260x` scenario IDs (next unused prefix after `TS-256` from story 2.5).

### Design Tokens for the Code-Input (from DESIGN.md)

```
--font-code-family:         "Noto Sans Mono", ui-monospace, monospace
--font-code-size:           24px
--font-code-weight:         600
--font-code-letter-spacing: 0.04em
```
Cell spec (DESIGN.md#Components `code-input`): 6 cells, `cellBackground: surface`, `cellBorder: 1.5px solid {colors.border}`, `cellRadius: {rounded.md}`, `cellFocusBorder: {colors.accent}` — i.e. reuse the same `--color-surface` / `--color-border` / `--radius-md` / `--color-accent` variables already used for other inputs in `login.css` (story 2.5), just applied per-cell.

### Testing Standards Summary

- **No custom auth Java code** (NFR8) — this story is 100% realm-config JSON + FreeMarker/CSS/vanilla-JS. If you find yourself reaching for a custom Keycloak SPI/authenticator to "properly" split the 6-digit input into separate POST fields, stop — that violates NFR8. Keep the single `name="totp"` POST field.
- **Integration tests run against a live Keycloak** in CI/dev (`tests/integration/`), per architecture.md structure rules. New file: `tests/integration/totp-verification.bats`. Use Admin REST `configure-totp` for test-user setup (test-design-epic-2.md's stated approach), not UI enrollment.
- **Unit/lint tests** (`tests/unit/`) are static JSON/script checks, no live Keycloak needed. New file: `tests/unit/realm-otp-policy.bats`.
- **Theme tests** (`tests/theme/login-theme.test.mjs`) already assert against `login-otp.ftl` for story 2.5's ACs (banner presence, no-hardcoded-strings, aria wiring) — running the full suite after your `login-otp.ftl` rewrite will catch regressions on those pre-existing assertions. Do not break story 2.5's passing tests; extend the same file with new `describe` blocks for the six-cell-group assertions (AC2) rather than creating a parallel theme test file. **Specifically:** line ~585 asserts `<label\s[^>]*for=["'](totp|otp)["']` — if you keep the recommended single-`<input id="totp">` approach this assertion passes unmodified; if you introduce a different `id` or a wrapping `role="group"` pattern instead, this pre-existing assertion will need a deliberate, reviewed update (not a silent workaround) to match the new DOM shape.
- Reference `_bmad-output/test-artifacts/test-design/test-design-epic-2.md` lines 182-183 (P0), 213-214 (P1), 244 (P2) for the exact TOTP-related test scenarios already risk-scored for this story — align new integration/E2E tests to these where practical instead of inventing a different test shape.

### Previous Story Learnings (from Story 2.5 — done)

- Keycloak `MessageFormat` consumes a lone apostrophe in `.properties` files — always double it (`We''ll`) if introducing new message strings with contractions.
- `aria-describedby` must be on the `<input>` referencing the error span's `id` — NOT the reverse. This was a real WCAG-breaking bug caught in 2.5's review; the fix is already in `login-otp.ftl`'s current single-input version — preserve this pattern in the new six-cell markup.
- `:focus` CSS rules with higher specificity than the global `:focus-visible` rule can silently kill the focus ring — story 2.5 had to add matching-specificity `input[...]:focus-visible` overrides. Watch for this when styling the new cell(s); verify the focus ring is visible on keyboard Tab, not just `:hover`.
- Docker build context for the Keycloak image is `./keycloak/` (not repo root) — any new JS/asset file for the code-input must live under `keycloak/themes/envocc/login/resources/` to be included in the COPY.
- `docker compose up --build -d` is required after any `realm-export.json` or theme change to pick it up (Keycloak bakes theme + realm-import at build/start time).
- Test suite conventions: Node `--test` files use `describe`/`it`/`before` with file content loaded once in `before()`, read-only after. BATS files use `bats-support`/`bats-assert` libraries (already installed at `tests/lib/`) and a `VALID_FIXTURE`-plus-mutations pattern for JSON lint tests.

### Project Structure Notes

- **Realm config:** `keycloak/realm-export.json` (modify) [Source: architecture.md#Complete Project Tree — FG-1/FG-3/FG-8 → `keycloak/realm-export.json`]
- **Theme:** `keycloak/themes/envocc/login/login-otp.ftl` (modify), `resources/css/login.css` (modify), possibly new `resources/js/otp-input.js` [Source: architecture.md#Complete Project Tree — FG-2 → `keycloak/themes/envocc/`]
- **Lint script:** `scripts/lint-realm-export.py` (modify, extend existing checks)
- **Tests:** `tests/unit/realm-otp-policy.bats` (new), `tests/integration/totp-verification.bats` (new), `tests/theme/login-theme.test.mjs` (extend, do not replace)
- No admin app (`admin/`), no Drizzle, no SvelteKit routes touched — this story is Keycloak-only, same footprint class as story 2.5.

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-2-6-totp-mfa-enforcement-verification-hardening.md`
- Unit lint tests: `tests/unit/realm-otp-policy.bats` (10 tests, TS-260 series — confirmed 10/10 failing against unmodified `scripts/lint-realm-export.py`)
- Integration tests: `tests/integration/totp-verification.bats` (5 tests, TS-261 series, `INTEGRATION=1`-gated — confirmed skip-clean without a live stack)
- Theme tests: `tests/theme/login-theme.test.mjs` (extended in place — 15 new failing subtests across 6 new `describe` blocks; 88 pre-existing story 2.5 subtests unaffected, 0 regressions)

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.6] — AC source (FR13, FR14; UX-DR6, UX-DR8)
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 2] — epic framing; FR13/FR13a/FR14 relationship (password+TOTP is baseline, ThaiD is Story 2.9 alternative)
- [Source: _bmad-output/planning-artifacts/epics.md#FR Coverage Map] — FR13/FR14 → Epic 2 Story 2.6; enrollment explicitly deferred to Epic 3
- [Source: _bmad-output/planning-artifacts/architecture.md#Decision 1] — Keycloak provides MFA (TOTP) natively; NFR8 forbids hand-rolled auth
- [Source: _bmad-output/planning-artifacts/architecture.md#Decision Impact Analysis] — implementation sequence step 2 groups "MFA (TOTP)" with realm config work
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/DESIGN.md#Components] — `code-input` token spec (6 cells, Noto Sans Mono, cell border/focus tokens)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/EXPERIENCE.md#Components] — code-input behavior spec: one labeled group, auto-advance, paste-fills-all, verify-on-6th
- [Source: _bmad-output/test-artifacts/test-design/test-design-epic-2.md] — R-004 risk, P0/P1/P2 TOTP test scenarios, "Not in Scope" table (enrollment excluded), unresolved-threshold notes on clock-drift/rate-limit (lines 60, 80, 129-130, 182-183, 213-214, 244, 398-403, 461, 468)
- [Source: _bmad-output/implementation-artifacts/2-5-branded-deep-sea-login-theme-top-level-anti-phishing.md] — existing `login-otp.ftl` placeholder, explicit hand-off of "TOTP MFA flow logic" to this story, aria-describedby fix, apostrophe-escaping gotcha
- [Source: keycloak/realm-export.json] — current state: no otpPolicy/authenticationFlows/browserFlow yet; bruteForceProtected already true
- [Source: keycloak/themes/envocc/login/login-otp.ftl] — file to modify, current single-input structure
- [Source: keycloak/REALM-EXPORT-NOTES.md] — confirms "MFA required actions... added in Epic 2 stories (2.2–2.9)"; import mechanics (`IGNORE_EXISTING` vs `OVERWRITE_EXISTING`)
- [Source: scripts/lint-realm-export.py] — existing lint pattern to extend
- [Source: tests/unit/realm-session-config.bats] — TS-240 series pattern to mirror for TS-260 series
- [Source: design-tokens/deep-sea.css] — `--font-code-*` token block (lines 114-118)
- [Source: _bmad-output/implementation-artifacts/dependency-graph.md] — story 2.6 depends on epic 1 complete + story 2.2 (both done); unblocked, parallelizable with 2.7/2.8/2.9

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
