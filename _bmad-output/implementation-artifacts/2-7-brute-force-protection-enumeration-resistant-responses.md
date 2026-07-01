---
baseline_commit: 67899fd51c2f44ce4677cc995fb607089c29e4dc
---

# Story 2.7: Brute-force protection & enumeration-resistant responses

Status: review

## Story

As the System Administrator,
I want guessing attacks throttled and account existence hidden,
so that the auth surface resists abuse.

## Acceptance Criteria

1. **Progressive delays, per-account and per-IP (FR19):**
   - **Per-account (Keycloak native brute-force detection):** `keycloak/realm-export.json` has `"bruteForceProtected": true` (already set) with **tuned** progressive-delay values — replace the story-1.2 placeholder values with deliberately chosen ones:
     - `"failureFactor"` lowered from the placeholder `30` to a small number (recommend `5`) — the number of failed attempts before the account is temporarily locked.
     - `"permanentLockout": false` (temporary lockout only — no permanent admin-unlock-required state for a failed-login count; stays as-is).
     - `"waitIncrementSeconds"` and `"maxFailureWaitSeconds"` define the progressive backoff curve — keep `waitIncrementSeconds: 60` (wait grows by 60s per additional failure past the quick-login threshold) and `maxFailureWaitSeconds: 900` (cap at 15 min) — these are reasonable and may stay, but must be re-affirmed/documented as deliberate (not a leftover placeholder).
     - `"minimumQuickLoginWaitSeconds": 60` and `"quickLoginCheckMilliSeconds": 1000` stay — these detect rapid-fire retries within 1s of each other and apply the minimum wait immediately.
     - `"maxDeltaTimeSeconds": 43200` (12h failure-count reset window) stays.
     - Document the final chosen values and rationale in Dev Notes / a comment-equivalent (realm-export.json has no native comment support — document in `keycloak/REALM-EXPORT-NOTES.md` or story Dev Notes) so a future reader knows these are deliberate, not defaults.
   - **Per-IP (nginx, already implemented in story 1.3 — verify, do not duplicate):** `nginx/nginx.conf` already defines `limit_req_zone $binary_remote_addr zone=login_zone:10m rate=10r/m;` applied with `limit_req zone=login_zone burst=20 nodelay;` on the `/realms/`, `/auth/`, and `/admin/` location blocks, returning HTTP 429 (`limit_req_status 429`). Confirm this is unchanged and still covers the login and TOTP POST endpoints (both are under `/realms/.../protocol/openid-connect/auth` and `.../login-actions/...`, which fall under the `^/realms(/|$)` block). No nginx changes are expected unless a gap is found.

2. **Identical, generic response for any login failure — enumeration-resistant (FR20, UX-DR9):**
   - **Verify (do not regress) existing enumeration-safe messaging:** `keycloak/themes/envocc/login/messages/messages_en.properties` already sets `invalidUserMessage=Incorrect email or password.` and `invalidPasswordMessage=Incorrect email or password.` (identical). Keycloak's **base** theme (inherited, not overridden by envocc) sets `accountTemporarilyDisabledMessage` and `accountPermanentlyDisabledMessage` to the same generic "Invalid username or password" family — i.e., a brute-force-locked account shows the SAME message as a wrong password. Do not override these two keys with anything account-state-revealing.
   - **Scope note — `accountDisabledMessage` is intentionally out of scope for identical-wording:** the envocc theme overrides `accountDisabledMessage=This account is not available. Contact HR if you need help.` — this fires only for HR-admin-disabled accounts (story 2.8/FR25), not brute-force lockout, and is a distinct, already-accepted UX exception (a disabled account is a different concern than "does this account exist"). Do not conflate this with AC2; leave `accountDisabledMessage` as-is unless testing surfaces a genuine enumeration leak through it (e.g. if it renders in a context reachable pre-authentication in a way that reveals existence — verify it does not).
   - **Identical timing:** the response time for "wrong password on an existing account," "correct-looking email for a nonexistent account," and "brute-force-locked account" must not be distinguishably different to a network observer. Keycloak's built-in brute-force + password-hash check (Argon2/bcrypt-class, constant-effort) is expected to already be timing-safe by design (NFR8 — audited engine, no hand-rolled logic) — this AC requires **verification** via manual timing sampling (Dev Notes → Testing), not new application code. If a measurable timing gap is found (e.g. nonexistent-user short-circuits before the password-hash step), flag it as a finding — do NOT attempt to hand-roll a timing-safe compare; investigate whether it's a known Keycloak behavior/config knob first.
   - **Scope boundary:** activation and reset-password flows (also named in FR20) are Epic 3 (stories 3.3, 3.4) — `resetPasswordAllowed` is currently `false` and no reset/activation theme templates exist yet. This story's enumeration-resistance work is scoped to **login (email+password) and TOTP verification only**. Do not build reset/activation templates in this story.

## Tasks / Subtasks

- [x] Task 1: Tune Keycloak per-account brute-force parameters (AC: 1)
  - [x] Subtask 1.1: In `keycloak/realm-export.json`, change `"failureFactor"` from `30` to `5`.
  - [x] Subtask 1.2: Re-affirm the six other pre-existing brute-force timing fields listed in AC1 (`permanentLockout`, `waitIncrementSeconds`, `maxFailureWaitSeconds`, `minimumQuickLoginWaitSeconds`, `quickLoginCheckMilliSeconds`, `maxDeltaTimeSeconds`) are unchanged and intentional for the progressive-delay curve (5 failures → temporary lockout, escalating wait capped at 15 min, 12h reset window).
  - [x] Subtask 1.3: Run `python3 scripts/lint-realm-export.py` — must still pass (it asserts `bruteForceProtected: true` is present; changing `failureFactor` must not break the lint gate).
  - [x] Subtask 1.4: Run `python3 -m json.tool keycloak/realm-export.json > /dev/null` to confirm valid JSON after edits.
  - [x] Subtask 1.5: Run `gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml --redact` — must exit 0 (no secrets introduced).

- [x] Task 2: Verify nginx per-IP rate-limiting still covers login + TOTP endpoints (AC: 1)
  - [x] Subtask 2.1: Read `nginx/nginx.conf` — confirm `limit_req_zone` (10r/m, `login_zone`) and `limit_req zone=login_zone burst=20 nodelay;` are applied on the `^/realms(/|$)` block (covers `/realms/envocc/protocol/openid-connect/auth`, `/realms/envocc/login-actions/*` — both the password-submit and TOTP-submit POST targets).
  - [x] Subtask 2.2: No nginx.conf changes expected. If a gap is found (e.g., a login/TOTP POST path not covered by the regex), document it as a finding and fix minimally, following the existing `location ~ ^/realms(/|$)` pattern — do not introduce a new rate-limit zone unless the existing one demonstrably does not cover the path.

- [x] Task 3: Verify enumeration-resistant messaging (AC: 2)
  - [x] Subtask 3.1: Confirm `keycloak/themes/envocc/login/messages/messages_en.properties` does NOT override `accountTemporarilyDisabledMessage`, `accountTemporarilyDisabledMessageTotp`, `accountPermanentlyDisabledMessage`, or `accountPermanentlyDisabledMessageTotp` — these must inherit Keycloak's base theme values (which already equal the generic "Invalid username or password." / "Invalid authenticator code." family, enumeration-safe by Keycloak design).
  - [x] Subtask 3.2: Confirm `invalidUserMessage` and `invalidPasswordMessage` remain identical (`Incorrect email or password.`) — already true from story 2.5, do not diverge them.
  - [x] Subtask 3.3: Confirm `accountDisabledMessage` (HR-disabled account, story 2.8 scope) stays distinct and is not conflated with brute-force lockout messaging — this is an intentional, accepted exception (see AC2 scope note), not a defect to fix.
  - [ ] Subtask 3.4: **DEFERRED — requires live stack.** Manually trigger each path against a running stack and record the observed message: (a) wrong password on a real account, (b) any password on a nonexistent email, (c) an account brute-force-locked after `failureFactor` failures, (d) wrong TOTP code repeated until locked. Confirm (a), (b), (c) render identical text; (d) TOTP-specific messages (`accountTemporarilyDisabledMessageTotp`) are also generic and do not leak whether the account exists. Not executable in this sandboxed dev session (no Docker daemon available) — see Dev Agent Record for the exact procedure to run before merge.

- [ ] Task 4: Verify identical timing across enumeration-relevant failure paths (AC: 2)
  - [ ] Subtask 4.1: **DEFERRED — requires live stack.** With a running stack, sample response latency for: nonexistent email + any password, existing email + wrong password, existing-but-locked account + any password. Use repeated `curl -w '%{time_total}'` POSTs to `/realms/envocc/login-actions/authenticate` (the browser-flow POST target — works against any client, no ROPC needed) and compare distributions. Sample at least 10 requests per path and compare median `time_total`. Document raw findings in Dev Agent Record — do not require statistical rigor beyond that, just confirm no order-of-magnitude difference (e.g. one path failing in <5ms while another takes 200ms would indicate a short-circuit leak). Not executable in this sandboxed dev session (no Docker daemon available) — see Dev Agent Record for the exact procedure to run before merge.
  - [ ] Subtask 4.2: **DEFERRED — contingent on 4.1.** If a timing gap is found, research whether it is a known/documented Keycloak behavior before attempting any code change — this realm has NFR8 (no hand-rolled crypto/timing logic); any fix must stay within Keycloak native configuration, not custom SPI code, unless explicitly re-scoped with the user.

- [x] Task 5: Automated test coverage — realm config (AC: 1)
  - [x] Subtask 5.1: Create `tests/unit/brute-force-config.bats` — static assertions against `keycloak/realm-export.json`:
    - `TS-271a [P0] realm-export.json sets bruteForceProtected: true`
    - `TS-271b [P1] realm-export.json sets failureFactor to 5 (not the story-1.2 placeholder of 30)`
    - `TS-271c [P1] realm-export.json sets permanentLockout: false`
    - `TS-271d [P2] realm-export.json sets waitIncrementSeconds, maxFailureWaitSeconds, minimumQuickLoginWaitSeconds, quickLoginCheckMilliSeconds, maxDeltaTimeSeconds (all present, all positive integers)`
  - [x] Subtask 5.2: Create `tests/unit/enumeration-resistant-messages.bats` — static assertions against `keycloak/themes/envocc/login/messages/messages_en.properties`:
    - `TS-272a [P0] invalidUserMessage equals invalidPasswordMessage (byte-identical)`
    - `TS-272b [P0] messages_en.properties does NOT define accountTemporarilyDisabledMessage (must inherit base theme, not diverge)`
    - `TS-272c [P0] messages_en.properties does NOT define accountPermanentlyDisabledMessage (must inherit base theme, not diverge)`
    - `TS-272d [P2] messages_en.properties does NOT define accountTemporarilyDisabledMessageTotp or accountPermanentlyDisabledMessageTotp`
  - [x] Subtask 5.3: Follow the exact bats file header/index-comment convention used in `tests/unit/nginx-config.bats` (file header comment block listing all TS-IDs with `[P#]` priority and one-line description before the `@test` blocks).

- [x] Task 6: Integration test coverage — live lockout + enumeration behavior (AC: 1, 2)
  - [x] Subtask 6.0: **Prerequisite check — `test-ropc-client` does not exist yet.** `keycloak/realm-export.json` currently only has `test-oidc-client`, which has `"directAccessGrantsEnabled": false` (ROPC disabled). `tests/integration/identity-model.bats` (TS-210d) already anticipates a `test-ropc-client` and `.env.example` already has a placeholder `KC_TEST_ROPC_CLIENT_SECRET`, but the client itself was never added to the realm export in story 2.1. Before writing Task 6 tests, either: (a) add `test-ropc-client` to `keycloak/realm-export.json` (`directAccessGrantsEnabled: true`, confidential client, secret sourced from `KC_TEST_ROPC_CLIENT_SECRET`) — this also unblocks the pre-existing skip-stubbed TS-210d test, or (b) write Task 6 tests entirely against the browser-flow POST (`/realms/envocc/login-actions/authenticate` with a session cookie from `/realms/envocc/protocol/openid-connect/auth`) instead of ROPC. **Resolved: option (b) chosen** (ATDD scaffold already implements the browser-flow approach — see `_bf_browser_login()` in `tests/integration/brute-force-lockout.bats`); option (a) remains open as deferred groundwork for a future story, not re-scoped here.
  - [x] Subtask 6.1: Create `tests/integration/brute-force-lockout.bats` using the existing `tests/integration/setup_suite.bash` + `tests/helpers/common.bash` harness (`compose_up()`, `wait_for_healthy()`, `get_admin_token()`) — follow the pattern in `tests/integration/realm-import.bats` (TS-201x) for creating a throwaway test user via Admin REST API and cleaning it up after.
    - `TS-273a [P0] account is NOT locked before failureFactor failed attempts` — create test user, submit `failureFactor - 1` wrong passwords via the chosen login path (Subtask 6.0), confirm the next attempt still returns "invalid credentials" rather than a lockout-specific state, and a correct password on this attempt still succeeds.
    - `TS-273b [P0] account IS locked after failureFactor failed attempts` — repeat with `failureFactor` wrong passwords, confirm the account is now locked (Admin REST API `GET /users/{id}` — check for lockout indication, or confirm a subsequent CORRECT password also fails while locked).
    - `TS-273c [P1] locked-account response is identical to wrong-password response` — compare the HTTP status/error body shape between a wrong-password attempt (pre-lockout) and any-password attempt (post-lockout) — both must be indistinguishable to the client (same status code, same generic error message).
    - `TS-273d [P1] nonexistent-user response is identical to wrong-password response` — compare a nonexistent email vs a real email with wrong password — same status/message.
  - [x] Subtask 6.2: Mark tests `skip`-guarded consistent with existing integration bats (most require a live `docker compose up --build` stack) — follow the pattern already used in `tests/integration/*.bats`.
  - [x] Subtask 6.3: Clean up via a bats `teardown()` function (not inline code at the end of each `@test` body) so cleanup still runs if an assertion fails mid-test: reset the test user's brute-force failure count via Admin REST API (`DELETE /admin/realms/envocc/attack-detection/brute-force/users/{id}` — `POST .../reset-password` does NOT reset brute-force state) and delete the test user.

- [ ] Task 7: Manual smoke test (AC: all)
  - [ ] Subtask 7.1: **DEFERRED — requires live stack.** `docker compose up --build -d` — rebuild/restart with the updated `realm-export.json`. Note: realm-export.json is imported with `IGNORE_EXISTING` strategy (story 1.2) — if the realm already exists in the Postgres volume from a prior run, the new `failureFactor` will NOT be picked up. Use `docker compose down -v` (drop volumes) then `docker compose up --build -d` for a clean re-import, OR update the value via Admin REST API / Admin Console UI for an already-running stack, per `keycloak/REALM-EXPORT-NOTES.md` guidance if such a note exists. Not executable in this sandboxed dev session (no Docker daemon available).
  - [ ] Subtask 7.2: **DEFERRED — requires live stack.** Sign in with a test account, deliberately fail the password 5 times, confirm the 5th (or the attempt after) shows the same generic "Incorrect email or password." message with no indication of lockout state.
  - [ ] Subtask 7.3: **DEFERRED — requires live stack.** Attempt a 6th login with the CORRECT password while locked — confirm it still fails with the same generic message (proves lockout is enforced, not just cosmetic).
  - [ ] Subtask 7.4: **DEFERRED — requires live stack.** Wait out `minimumQuickLoginWaitSeconds` (60s) or use Admin REST API to clear the brute-force state, then confirm login succeeds again with the correct password.
  - [ ] Subtask 7.5: **DEFERRED — requires live stack.** Flood the login endpoint from a script (>10 requests within a minute) — confirm nginx returns HTTP 429 (per-IP limit, story 1.3, unchanged) — `curl -sI` repeated against `/realms/envocc/protocol/openid-connect/auth?...`.

## Dev Notes

### What This Story Builds

This story is primarily a **tuning and verification** story, not a greenfield build:
1. Tunes the per-account Keycloak brute-force parameters that story 1.2 deliberately left as placeholders ("configured fully in Epic 2 Story 2.7") — chiefly lowering `failureFactor` from 30 to 5.
2. Verifies (does not rebuild) the per-IP nginx rate-limiting already shipped in story 1.3 (`login_zone`, 10r/m, 429) still covers the login/TOTP endpoints.
3. Verifies (does not rebuild) the enumeration-resistant messaging already shipped in story 2.5 (`invalidUserMessage` = `invalidPasswordMessage`) and confirms Keycloak's inherited base-theme messages for brute-force lockout (`accountTemporarilyDisabledMessage` etc.) are NOT overridden with anything that would leak account-lockout state.
4. Adds the FIRST automated test coverage for brute-force/enumeration behavior in this repo — none currently exists.

**What this story does NOT build:**
- The TOTP MFA flow logic itself (story 2.6, still backlog as of this story's creation — TOTP verification exists visually per story 2.5 theming, but the underlying required-action / credential flow is 2.6's scope). This story's TOTP-related work is limited to brute-force/enumeration behavior on the TOTP surface, assuming 2.6 lands the flow logic. **If 2.6 has not yet been implemented when this story is dev'd, TOTP-specific tests (accountTemporarilyDisabledMessageTotp checks, TOTP lockout) may need to be deferred** — the login (password) path's brute-force/enumeration behavior does not depend on 2.6 and can be fully implemented and tested regardless.
- Account-disable blocking (story 2.8, FR25/FR46) — `accountDisabledMessage` is a different, already-implemented concern (HR disabling an account) and is explicitly out of this story's identical-wording requirement.
- Reset-password / activation enumeration-resistance (Epic 3, stories 3.3/3.4) — `resetPasswordAllowed` is currently `false`; no templates exist yet.
- New nginx rate-limit zones or WAF-style abuse detection beyond what story 1.3 already ships.

### Critical Architectural Context

**Per-account vs per-IP is a two-layer defense, both already scaffolded:**
- **Per-account** = Keycloak's native `bruteForceProtected` mechanism (`keycloak/realm-export.json`). This is the ONLY layer this story meaningfully changes (tuning `failureFactor` from a placeholder).
- **Per-IP** = nginx `limit_req_zone` (`nginx/nginx.conf`, story 1.3, already complete — 10r/m, burst 20, 429 status). This story only verifies it, does not rebuild it.

**`failureFactor: 30` was a deliberate placeholder, not a bug.** [Source: `_bmad-output/implementation-artifacts/1-2-realm-config-as-code-baseline-secret-hygiene.md` line 47]: `"bruteForceProtected": true (Keycloak native brute-force — configured fully in Epic 2 Story 2.7, but enable now)`. Story 1.2 enabled the flag to satisfy the CI lint gate (`scripts/lint-realm-export.py` requires `bruteForceProtected: true`) but left the numeric tuning for this story. Confirmed: `scripts/lint-realm-export.py` (lines 22, 50, 60-66, 249) only asserts the boolean, not `failureFactor` — changing the number will not break the existing lint gate.

**Enumeration-resistance is ALREADY substantially in place — verify, don't rebuild:**
- `invalidUserMessage=Incorrect email or password.` and `invalidPasswordMessage=Incorrect email or password.` are already identical (story 2.5).
- Keycloak's own base theme (inherited by `envocc`, not overridden) ships `accountTemporarilyDisabledMessage=Invalid username or password.` and `accountPermanentlyDisabledMessage=Invalid username or password.` — i.e. Keycloak upstream ALREADY designs brute-force lockout messaging to be indistinguishable from wrong-password, specifically to prevent enumeration. **Do not add an override for these keys.** Verified via Keycloak 26.6.3 base theme `messages_en.properties` (upstream source).
- The one deliberate divergence is `accountDisabledMessage="This account is not available. Contact HR if you need help."` (envocc override, story 2.5) — this is the HR-disable path (story 2.8/FR25), a conceptually different state than "wrong password" or "brute-force locked," and is an accepted UX exception per the epics.md Story 2.8 scope. Do not merge this into the generic message as part of this story.

**FR20's "identical timing" requirement is a verification task, not new code (NFR8).** NFR8 forbids hand-rolled crypto/timing logic — Keycloak's credential-check pipeline (password hashing + brute-force check) is the audited component of record. This story's job is to sample and confirm no observable timing leak exists in the current configuration, and if one is found, to research Keycloak-native configuration fixes before ever considering custom code (which would need explicit re-scoping — do not silently add SPI/custom auth code).

**`realm-export.json` re-import caveat:** Per story 1.2/1.4/2.5 learnings, the realm is imported via `--import-realm` with an `IGNORE_EXISTING` strategy — editing `failureFactor` in `realm-export.json` will NOT retroactively apply to an already-imported realm in a running Postgres volume. Manual verification requires either a fresh `docker compose down -v && up --build -d`, or applying the change via the Admin Console/REST API to the live realm, then reconciling the exported JSON to match. Document whichever path was used in Dev Agent Record.

**`test-ropc-client` referenced by tests but not yet in the realm.** `tests/integration/identity-model.bats` (TS-210d) already anticipates a `test-ropc-client` and `.env.example` has a placeholder `KC_TEST_ROPC_CLIENT_SECRET`, but `keycloak/realm-export.json` currently only defines `test-oidc-client` with `"directAccessGrantsEnabled": false` (ROPC disabled) — the client was never added in story 2.1. See Task 6, Subtask 6.0 for the two options (add the client now, or use the browser-flow POST instead).

**Test suite has NO existing brute-force/enumeration coverage.** [Source: research of `tests/unit/`, `tests/integration/`] — the only prior references to `bruteForceProtected` are the CI lint gate test (`tests/unit/ci-security-gate.bats`, boolean-presence only) and a fixture value inside `tests/unit/oidc-pkce-lint.bats` (unrelated OIDC lint fixtures that happen to include the key). This story is the first to add real brute-force-behavior and enumeration-resistance test coverage — claim the next unused TS-ID range: **TS-271 through TS-273** (highest existing ID at story creation time was TS-259a/b in story 2.5's theme tests; TS-260-270 unclaimed as of 2026-07-01 — no formal TS-ID reservation system exists in this repo, IDs are simply claimed sequentially by whichever story lands next. Story 2.6 is being worked in parallel per the dependency graph and could independently claim overlapping IDs — if a collision surfaces at merge time, whichever PR merges second renumbers its own IDs; do not overwrite the other story's test file).

### Project Structure — Files to Update

**Update (modify):**
- `keycloak/realm-export.json` — change `"failureFactor"` from `30` to `5`; re-affirm (no value change expected) `permanentLockout`, `waitIncrementSeconds`, `maxFailureWaitSeconds`, `minimumQuickLoginWaitSeconds`, `quickLoginCheckMilliSeconds`, `maxDeltaTimeSeconds`.

**Create (new):**
```
tests/unit/brute-force-config.bats           # static realm-export.json assertions (TS-271x)
tests/unit/enumeration-resistant-messages.bats # static messages_en.properties assertions (TS-272x)
tests/integration/brute-force-lockout.bats     # live lockout + enumeration-timing behavior (TS-273x)
```

**No change expected (verify only):**
- `nginx/nginx.conf` — per-IP rate-limiting already complete (story 1.3).
- `keycloak/themes/envocc/login/messages/messages_en.properties` — enumeration-safe messages already correct (story 2.5); do NOT add overrides for `accountTemporarilyDisabledMessage*`/`accountPermanentlyDisabledMessage*`.
- `keycloak/themes/envocc/login/login.ftl`, `login-otp.ftl` — no template changes expected; both already render `messagesPerField`/global messages generically.
- `scripts/lint-realm-export.py` — no change needed; already correctly gates on the boolean only.

### Previous Story Learnings

**From story 2.5 (branded Deep Sea login theme — done):**
- `messages_en.properties` uses Java `MessageFormat` — a lone apostrophe is a quoting metacharacter and must be doubled (`''`) to render as one `'`. Relevant if any new/edited message string in this story contains an apostrophe.
- `login.ftl` / `login-otp.ftl` already correctly wire `aria-describedby` from input → error span (fixed in 2.5 code review) and suppress the global message when a field-level error exists (`displayMessage=!messagesPerField.existsError(...)`) — this pattern is already enumeration-safe (doesn't reveal which field was wrong beyond what the generic message says).
- Docker build context is `./keycloak/` (Dockerfile COPY paths relative to that dir) — irrelevant to this story (no Dockerfile changes expected) but keep in mind if any theme file needs touching.
- Testing approach for theme/config stories in this repo is manual (`docker compose up --build`, curl, browser inspection) supplemented by static grep-style bats/node assertions — no live-stack CI wiring exists yet (bats/mjs tests are not in `.github/workflows/ci.yml`; run manually or via `lefthook`).

**From story 1.3 (nginx security edge — done):**
- `limit_req_zone` uses `$binary_remote_addr` (per-IP) at `10r/m` with `burst=20 nodelay`, returns `429` via `limit_req_status 429`. Applied identically across `/realms/`, `/auth/`, `/admin/` blocks (nginx `add_header`/directive inheritance requires repeating directives per location block — already done).

**From story 1.2 (realm config-as-code — done):**
- `bruteForceProtected` and the six numeric brute-force fields were pre-seeded as placeholders explicitly deferred to this story. `scripts/lint-realm-export.py` only checks the boolean.
- `realm-export.json` secrets must remain stripped; any manual re-export after Admin Console changes must re-run the story 1.2 secret-stripping procedure (`keycloak/REALM-EXPORT-NOTES.md`) and `gitleaks detect`.

### git Commit Style

Two distinct conventions, both established in stories 2.3–2.5:
- **Individual work commits** (conventional-commit style, scoped to the story): `feat(story-2-7): <description>`, `fix(story-2-7): <description>`, `test(story-2-7): <description>` — e.g. `827bc8e feat(story-2-5): implement branded Deep Sea login theme...`, `e8bc441 fix(story-2-5): apply code-review findings...`.
- **Final PR/merge-commit title** (squash-merge into main): `story-2-7-brute-force-protection-enumeration-resistant-responses - fixes #13 (#<PR>)` — e.g. `3e04d3f story-2-5-branded-deep-sea-login-theme-top-level-anti-phishing - fixes #11 (#52)`, `baa0429 story-2-4-sso-session-lifetimes-rp-initiated-logout - fixes #10 (#49)`.

### Testing / Verification Approach

No unit-testable application logic is added (this is realm-config tuning + Keycloak-native message inheritance verification). Verification is:
1. **Static config assertions (bats):** `tests/unit/brute-force-config.bats`, `tests/unit/enumeration-resistant-messages.bats` — grep/jq-style assertions against `realm-export.json` and `messages_en.properties`, following the exact header/TS-ID convention in `tests/unit/nginx-config.bats`.
2. **Live-stack integration tests (bats):** `tests/integration/brute-force-lockout.bats` — using `tests/integration/setup_suite.bash` + `tests/helpers/common.bash` (`compose_up()`, `wait_for_healthy()`, `get_admin_token()`), following the pattern in `tests/integration/realm-import.bats`.
3. **Manual smoke test:** `docker compose up --build -d` (or `down -v && up --build -d` for a clean realm re-import), deliberately fail login 5+ times, confirm generic message + verify actual lockout (correct password also rejected while locked), confirm nginx 429 under flood, confirm timing is not observably different across enumeration-relevant failure modes.
4. **Existing gates that must still pass unmodified:** `python3 scripts/lint-realm-export.py`, `python3 -m json.tool keycloak/realm-export.json`, `gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml --redact`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.7] — story requirements and ACs (FR19, FR20, UX-DR9)
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 2] — epic context; UX-DR9 full definition (enumeration-safe voice + timing)
- [Source: _bmad-output/planning-artifacts/epics.md#UX Design Requirements] — UX-DR9: "identical generic copy + timing across sign-in/activation/reset"
- [Source: _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-21/prd.md#FR19,FR20] — FR19 progressive delays per-account/per-IP; FR20 enumeration-resistant identical generic responses
- [Source: _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-21/prd.md#NFR7] — password policy + brute-force protection per NIST SP 800-63B
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/EXPERIENCE.md#State Patterns] — "Lockout / throttle: Progressive delay, per-account and per-IP. Identical message regardless of whether the account exists."
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/EXPERIENCE.md#Voice and Tone] — enumeration-resistance as a voice rule, not just a behavior rule
- [Source: _bmad-output/planning-artifacts/architecture.md#Decision 1] — Keycloak provides brute-force natively (audited component, NFR8)
- [Source: _bmad-output/planning-artifacts/architecture.md#Decision 3 — Infrastructure] — nginx single security edge, rate-limiting/abuse per FR50
- [Source: _bmad-output/implementation-artifacts/1-2-realm-config-as-code-baseline-secret-hygiene.md] — brute-force fields pre-seeded as placeholders, explicitly deferred to story 2.7
- [Source: _bmad-output/implementation-artifacts/2-5-branded-deep-sea-login-theme-top-level-anti-phishing.md] — existing enumeration-safe `invalidUserMessage`/`invalidPasswordMessage`, `accountDisabledMessage` override, apostrophe-doubling gotcha in `messages_en.properties`
- [Source: keycloak/realm-export.json] — current brute-force field values (lines 11-18)
- [Source: nginx/nginx.conf] — `login_zone` rate-limit zone (lines 39-50) and its application on `/realms/`, `/auth/`, `/admin/` (lines 146-147, 167-168, 194-195)
- [Source: keycloak/themes/envocc/login/messages/messages_en.properties] — current message overrides; confirmed `accountTemporarilyDisabledMessage`/`accountPermanentlyDisabledMessage` NOT overridden (inherits Keycloak base)
- [Source: scripts/lint-realm-export.py lines 22, 50, 60-66, 249] — CI lint only asserts `bruteForceProtected: true`, not the numeric tuning fields
- [Source: Keycloak 26.6.3 upstream base theme `messages_en.properties`] — confirms `accountTemporarilyDisabledMessage=Invalid username or password.`, `accountPermanentlyDisabledMessage=Invalid username or password.` (enumeration-safe by Keycloak design, verified via upstream source fetch)
- [Source: tests/unit/nginx-config.bats] — TS-ID + `[P#]` priority + file-header-index convention to follow for new bats files
- [Source: tests/integration/realm-import.bats, tests/integration/setup_suite.bash, tests/helpers/common.bash] — live-stack integration test harness pattern (`compose_up`, `wait_for_healthy`, `get_admin_token`, test-user create/cleanup via Admin REST API)
- [Source: _bmad-output/implementation-artifacts/dependency-graph.md] — story 2.7 depends on epic 1 complete + story 2.2 (both merged); ready to work; parallel with 2.6/2.8/2.9

## Dev Agent Record

### Agent Model Used

claude-sonnet-5 (Claude Code)

### Debug Log References

- No implementation blockers. This story was primarily config-tuning + verification, matching the Dev Notes framing ("tuning and verification story, not a greenfield build").
- Confirmed pre-existing, unrelated BATS failures (`TS-220l`, `TS-220m`, `TS-220m2`, `TS-240a` in `tests/unit/`) exist identically both before and after this story's change (verified via `git stash` bisection) — not caused by or in scope for this story; not fixed here.
- **Environment constraint:** no Docker daemon was running in this sandboxed autonomous dev session (`docker ps` failed — OrbStack socket unavailable), so the live-stack verification portions of Task 3 (Subtask 3.4), Task 4 (Subtask 4.1/4.2), and Task 7 (manual smoke test) could not be executed. Left unchecked rather than falsely marked complete. Exact re-run procedure below for whoever picks up the review with a live stack.

### Completion Notes List

- **Task 1** (AC1): Changed `keycloak/realm-export.json` `"failureFactor"` from the story-1.2 placeholder `30` to `5`. Re-affirmed the other six brute-force timing fields (`permanentLockout: false`, `waitIncrementSeconds: 60`, `maxFailureWaitSeconds: 900`, `minimumQuickLoginWaitSeconds: 60`, `quickLoginCheckMilliSeconds: 1000`, `maxDeltaTimeSeconds: 43200`) are unchanged. Documented rationale for all seven fields in a new `## Story 2.7` section in `keycloak/REALM-EXPORT-NOTES.md`. Verified: `python3 scripts/lint-realm-export.py` exits 0, `python3 -m json.tool` confirms valid JSON, `gitleaks detect --source keycloak/realm-export.json --no-git --config .gitleaks.toml --redact` reports no leaks.
- **Task 2** (AC1): Verified (no change needed) — `nginx/nginx.conf` still defines `limit_req_zone $binary_remote_addr zone=login_zone:10m rate=10r/m;` (line 47) applied via `limit_req zone=login_zone burst=20 nodelay;` on the `^/realms(/|$)`, `^/auth(/|$)`, and `^/admin(/|$)` blocks (lines 145-147, 166-168, 193-195), covering the login/TOTP POST targets under `/realms/envocc/protocol/openid-connect/auth` and `/realms/envocc/login-actions/*`. No gap found; no nginx.conf change made.
- **Task 3** (AC2): Verified (no change needed) — `keycloak/themes/envocc/login/messages/messages_en.properties` does not define `accountTemporarilyDisabledMessage`, `accountPermanentlyDisabledMessage`, or their `*Totp` variants (inherits Keycloak base theme). `invalidUserMessage` and `invalidPasswordMessage` remain byte-identical (`Incorrect email or password.`). `accountDisabledMessage` remains its own distinct, accepted HR-disable-path string. Subtasks 3.1-3.3 confirmed via static file inspection. **Subtask 3.4 (manual live-trigger of each path) deferred** — requires a running stack; re-run procedure: `docker compose down -v && docker compose up --build -d`, then manually attempt (a) wrong password, (b) nonexistent email, (c) 5x-failed/locked account, (d) wrong TOTP code repeated, and visually confirm identical rendered text for (a)/(b)/(c) and a generic TOTP-lockout message for (d).
- **Task 4** (AC2): **Deferred in full** — timing-sample verification requires a live stack (`curl -w '%{time_total}'` against `/realms/envocc/login-actions/authenticate`, ≥10 samples per path: nonexistent-email, wrong-password, locked-account, compare medians). Not executable without Docker in this session. No code change is anticipated regardless of outcome per NFR8 (Keycloak's native Argon2/bcrypt-class credential-check pipeline is the audited, timing-safe component of record) — if a gap is found on re-run, research Keycloak-native config options before any code change, per Dev Notes.
- **Task 5** (AC1): ATDD red-phase scaffolds `tests/unit/brute-force-config.bats` (TS-271a-d) and `tests/unit/enumeration-resistant-messages.bats` (TS-272a-d) were already committed prior to this dev pass. No file changes needed to the test files themselves — ran them post-Task-1-fix: **all 7 + 7 = 14 assertions pass** (TS-271b flipped from red to green after the `failureFactor` fix; all others were already-passing regression guards). Verified with `BATS_LIB_PATH=<bats-support/bats-assert path> bats tests/unit/brute-force-config.bats tests/unit/enumeration-resistant-messages.bats`.
- **Task 6** (AC1, AC2): ATDD scaffold `tests/integration/brute-force-lockout.bats` (TS-273a-d) was already committed, already implementing Subtask 6.0 option (b) — browser-flow POST against `/realms/envocc/login-actions/authenticate` rather than `test-ropc-client` ROPC (which still does not exist in the realm; left as future groundwork, not re-scoped here). Confirmed the file correctly `skip`s all 4 tests unless `INTEGRATION=1` is set (verified via `bats` run below — all 4 report `skip`), and cleanup is implemented via a `teardown()` function per Subtask 6.3. No file changes needed.
- **Task 7** (all ACs): **Deferred in full** — manual smoke test requires a live stack. Re-run procedure: `docker compose down -v && docker compose up --build -d` (clean re-import needed because `realm-export.json` uses `IGNORE_EXISTING` import strategy — see `keycloak/REALM-EXPORT-NOTES.md`), fail login 5x on a test account (confirm generic message, no lockout-state leak), attempt a 6th CORRECT-password login while locked (confirm it still fails identically), wait 60s or clear brute-force state via Admin REST API then confirm login succeeds, flood the login endpoint (>10 req/min) and confirm nginx 429.
- **Regression check:** ran the full `tests/unit/*.bats` suite (145 tests) after the `failureFactor` change — 141 pass, 4 pre-existing unrelated failures (bisected via `git stash`, confirmed present before this story's change too — not introduced or fixed by this story).
- **Test-runner setup note (for whoever re-runs):** this sandbox had no `tests/lib/bats-support`/`tests/lib/bats-assert` checked into the repo (consistent with story 2.5's note that "no live-stack CI wiring exists yet"); ran via `BATS_LIB_PATH` pointing at externally-installed copies of `bats-support`/`bats-assert` rather than committing them into the repo tree.

### File List

- `keycloak/realm-export.json` — modified: `"failureFactor"` changed from `30` to `5`.
- `keycloak/REALM-EXPORT-NOTES.md` — modified: added `## Story 2.7 — Brute-Force Protection & Enumeration-Resistant Responses` section documenting the tuned per-account brute-force field values/rationale and the (already-shipped, unchanged) enumeration-resistant messaging.
- `tests/unit/brute-force-config.bats` — no change (pre-existing ATDD scaffold; now green after Task 1).
- `tests/unit/enumeration-resistant-messages.bats` — no change (pre-existing ATDD scaffold; already green as a regression guard).
- `tests/integration/brute-force-lockout.bats` — no change (pre-existing ATDD scaffold; correctly skip-guarded without `INTEGRATION=1`).

## Change Log

- 2026-07-01: Story created via bmad-create-story workflow. Comprehensive context assembled from epics.md, PRD, architecture.md, UX EXPERIENCE.md, story 1.2/1.3/2.5 learnings, current realm-export.json/nginx.conf/messages_en.properties state, and upstream Keycloak 26.6.3 base theme message keys (verified `accountTemporarilyDisabledMessage`/`accountPermanentlyDisabledMessage` are enumeration-safe by Keycloak design and must not be overridden). Status → ready-for-dev.
- 2026-07-01: Validation pass. Fixed: (1) Task 4/6 wrongly assumed a `test-ropc-client` exists — it doesn't (only `test-oidc-client` with ROPC disabled is in the realm); added Subtask 6.0 prerequisite check with two resolution options and switched Task 4's timing test to the browser-flow POST. (2) Git Commit Style section conflated individual-commit and PR-merge-title conventions — split into two correctly-cited patterns. (3) Softened the TS-ID collision claim (no formal reservation system exists; documented the actual renumber-on-collision resolution). (4) Added sample-size guidance (10 requests, compare median) to the timing verification subtask. (5) Directed Task 6 cleanup to use bats `teardown()` instead of inline end-of-test cleanup so it survives assertion failures. (6) De-duplicated the six-field brute-force parameter list between AC1 and Task 1.
- 2026-07-01: Dev implementation. Tuned `keycloak/realm-export.json` `failureFactor` from `30` to `5` (Task 1); documented rationale for all seven brute-force fields plus the already-shipped enumeration-safe messaging in a new `keycloak/REALM-EXPORT-NOTES.md` Story 2.7 section. Verified (no changes needed) nginx per-IP rate-limiting (Task 2) and enumeration-resistant message config (Task 3, static portion). Ran the pre-committed ATDD scaffolds (`tests/unit/brute-force-config.bats`, `tests/unit/enumeration-resistant-messages.bats`) — all 14 assertions pass (Task 5); `tests/integration/brute-force-lockout.bats` correctly skip-guards without `INTEGRATION=1` (Task 6). Full unit suite: 141/145 pass, 4 pre-existing failures unrelated to this story confirmed via git-stash bisection. Deferred to a live-stack review pass: Task 3 Subtask 3.4 (manual message-rendering check), Task 4 (timing-sample verification), Task 7 (manual smoke test) — no Docker daemon available in this sandboxed session; exact re-run procedures documented in Dev Agent Record. Status → review.
