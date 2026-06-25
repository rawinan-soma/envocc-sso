---
name: EnvOcc SSO
status: final
sources:
  - ../../prds/prd-envocc-sso-2026-06-21/prd.md
created: 2026-06-21
updated: 2026-06-22
---

# EnvOcc SSO — Experience Spine

> **Change Note (2026-06-22) — two login methods.** Sign in offers **email + password + TOTP** (the 6-digit code-input surface) **or** a **"Login with ThaiD"** button (brokered federation). Both land on the same account. The password+TOTP path is the dev/CI and DOPA-down baseline; ThaiD links by national ID (PID). Keycloak remains the IdP. See the PRD/Architecture change notes.

> How it works: information architecture, behavior, states, interactions, accessibility, and the journeys. `DESIGN.md` owns the visual identity (palette, type, spacing, component looks); this spine owns the experience. **Both spines win on conflict** — where one is silent, the other governs; where both speak, they must agree. Tokens are cross-referenced by name using `{path.to.token}` (e.g. `{colors.primary}`, `{colors.surface}`); components are referenced by the shared names below.

## Foundation

**Web only, two postures, custom design system.** EnvOcc SSO is two co-equal halves built on one custom design system (the build stack is an open architecture decision — this spine names no framework, library, or product).

- **Staff-auth surfaces** (sign in, MFA, activation, reset, sign-out) are **responsive** and render **top-level only — never iframed**. This is a security requirement, not a layout preference: the brand chrome plus the real address-bar URL *are* the anti-phishing trust signal, so the login may not be embedded in any other page. The platform sets a CSP including `frame-ancestors 'none'`.
- **The admin console** is **desktop-first and data-dense**, delivered as **one role-gated shell**. The HR section and the System section are **never shown together** — navigation shows only the section for the role the signed-in admin holds, enforcing the separation of duties (no single person manages both employees and the system).

Audience is **non-technical**: all microcopy is plain-language with no jargon, and anti-phishing guidance is first-class. All UI strings are externalized (English-first, Thai-script ready) so the owner can translate after the UI stabilizes.

## Information Architecture

Every screen maps to its PRD functional requirement. Three groups: staff-auth (responsive, top-level), admin HR section, admin System section. The HR and System sections never appear in the same shell.

### Staff-auth (responsive, top-level only)

| Surface | Reached from | Purpose | FR |
|---|---|---|---|
| Sign in | App redirect / direct URL | Email + password entry **or** "Login with ThaiD" button; anti-phishing banner pinned | FR1, FR2, FR12, FR13a |
| Verification code (MFA) | After password accepted | Enter the 6-digit code from the authenticator app | FR13, FR14 |
| ThaiD sign-in (brokered) | "Login with ThaiD" on Sign in | Redirect to ThaiD, authenticate, return signed in (PID-linked) | FR13a |
| Forgot password | Sign in → "Forgot password" link | Enter email to request a sign-in link | FR17, FR20 |
| Email-sent confirmation | After forgot-password / activation request | Generic "if an account exists, we've sent a link" | FR20 |
| Reset password | Reset link in email | Set a new password; all other sessions end | FR17, FR48 |
| Activate account | Activation link in email | Set first password and enroll the authenticator | FR16, FR13 |
| Re-activation (after admin MFA reset) | Re-activation link after admin resets MFA | Re-set password and re-enroll authenticator | FR44 |
| Signed out | Logout / session end | Confirms sign-out; offers sign back in | FR10, FR46 |
| Auth error / invalid-link | Expired or invalid link | Generic explanation; request a fresh link | FR20, FR48 |

### Admin — HR section (desktop-first)

| Surface | Reached from | Purpose | FR |
|---|---|---|---|
| User list / search | HR nav home | Search and list staff with lifecycle state | FR27 |
| Create user | User list → "Create user" | Add name + work email; account starts pending | FR26 |
| User detail | User-list row | Enable/disable, reset password, reset MFA, edit profile | FR28, FR29, FR31 |
| CSV import | User list → "Import" | Upload → preview → confirm bulk pending accounts | FR30, FR49 |

### Admin — System section (desktop-first)

| Surface | Reached from | Purpose | FR |
|---|---|---|---|
| Client / app list | System nav home | List registered OIDC client applications | FR32 |
| Register / edit client | Client list row or "Register" | Credentials, exact-match redirect URIs, scopes | FR32 |
| Admin users | System nav | Create/disable HR & System admins, assign role | FR33 |
| Audit log | System nav | View and export the audit log (export is itself audited) | FR34 |

→ Visual composition reference lives in `DESIGN.md`. Spine wins on conflict.

## Voice and Tone

Microcopy only; aesthetic posture lives in `DESIGN.md`. The audience is non-technical staff, so we name the *thing*, not the *protocol*.

| Do | Don't |
|---|---|
| "verification code" / "Login with ThaiD" | "TOTP" / "OTP" / "OIDC broker" |
| "sign-in link" | "token" / "magic link token" |
| "Enter the 6-digit code from your authenticator app." | "Submit your time-based one-time password." |
| "We'll never ask for your verification code by phone, email, or chat." | (omitting the standing anti-phishing line) |
| "Don't share this link — it signs in as you." (in every activation/reset email) | "This token is bound to your session." |
| "If an account exists for that email, we've sent a sign-in link." | "No account found for that email." (leaks existence) |
| "Something went wrong with that link. Request a new one below." | "Invalid or expired JWT / nonce mismatch." |

**Anti-phishing guidance is first-class.** A standing, **never-dismissible** banner sits inside the auth-card on the Sign in and Verification code surfaces. Enumeration-resistance is a voice rule as much as a behavior rule: sign-in, activation, and reset responses use **identical generic wording and timing** whether or not an account exists.

## Component Patterns

Behavioral rules only; visual specs live in `DESIGN.md`. Referenced by shared name.

| Component | Behavioral rules |
|---|---|
| app-header / wordmark | Carries the EnvOcc wordmark on every staff-auth surface; part of the anti-phishing trust signal. Always top-level, never inside a frame. |
| auth-card | The single focused container on each staff-auth surface. On Sign in and Verification code it has the anti-phishing-banner pinned inside it, **non-dismissible**. |
| text-input | Label is **always visible** (never placeholder-only). Errors associate to the field via `aria` and are carried in text. |
| password-input | Reveal toggle. Live, plain-language policy hints (minimum 12 characters; new password is screened and rejected if found in a known-breached list). No composition rules shown — length and breach only. |
| code-input | One labeled group for the 6-digit verification code. Auto-advances cell to cell; accepts a pasted full code; verifies automatically on the 6th digit. Announced as a single field to assistive tech. |
| thaid-login-button | A "Login with ThaiD" button on the Sign in surface (below the email/password form, after an "or" divider). Activating it redirects top-level to ThaiD; on return the user is signed in (PID-linked). Visually subordinate to the primary email/password path; keyboard-focusable; never embedded/framed. |
| buttons | Exactly **one primary action per surface**. Destructive actions (disable account, force-logout) are styled destructive **and** require step-up re-auth. |
| status-pill | Conveys account lifecycle (pending / active / disabled) with **text + icon, never color alone**. |
| data-table-row | The **whole row opens the detail** view. Lists **paginate — never infinite-scroll**. |
| alert | Four states — info / success / warning / error — each conveyed by text + icon, not color alone. |
| modal / step-up-dialog | Sensitive actions require **step-up re-authentication before proceeding**: reset MFA, register/edit a client, manage admin users. `Esc` cancels the dialog but **never silently bypasses** the step-up — cancelling abandons the action. |
| file-upload / csv-preview | Parses the file to a **preview before any account is created**. Distinguishes clean / invalid / duplicate rows. Enforces a per-import size cap. Activation emails are **throttled** on confirm. |

## State Patterns

| State | Where | Treatment |
|---|---|---|
| Account: pending | User detail, status-pill | "Pending — activation link sent." Account cannot sign in until activated. |
| Account: active | User detail, status-pill | Normal signed-in-capable state. |
| Account: disabled | User detail, status-pill | All new authentication blocked immediately; sessions and tokens revoked. |
| Loading | Auth surfaces, tables | Inline progress on buttons; **skeleton rows** for tables. No layout shift on resolve. |
| Empty | Lists (users, clients, admins, audit) | Plain sentence + the single primary action ("No users yet. Create the first one."). |
| Error (generic) | Any auth surface | Generic message; **preserves the user's input** so they don't retype. |
| Success | After any auth action | Confirmation + a **security-event email** is sent (activation, reset, MFA change). |
| Lockout / throttle | Sign in, code entry | **Progressive delay**, per-account and per-IP. **Identical message regardless of whether the account exists.** |
| Token expired / invalid-link | Reset / activate / re-activate | Generic "that link no longer works" + request a fresh one. Never reveals account state. |
| Pending-expired | Activation flow | A bounded-window expiry; user is told to ask HR for a new activation link. |
| Email-sent confirmation | Forgot password / activation | Generic "if an account exists, we've sent a link" — enumeration-resistant. |
| Session-expired / re-auth | Admin console, in-session | Idle or absolute lifetime reached → re-authenticate to continue. |
| Step-up-required | Admin sensitive actions | Inline step-up-dialog before reset-MFA / register-client / manage-admins. |
| Disabled mid-session | Any surface, after revocation | Next request fails → generic signed-out screen; no special "you were disabled" message. |

## Interaction Primitives

**Keyboard-complete, mouse-optional.** Every flow — both staff-auth and admin — is fully operable from the keyboard, in reading order, with a visible focus ring at all times.

- `Tab` / `Shift+Tab` move through every interactive element in reading order; the focus ring is always visible (`{colors.focus-ring}` per `DESIGN.md`).
- The **code-input** is one group: typing auto-advances, `Backspace` steps back, a full pasted code fills all six cells, and the 6th digit triggers verification.
- **Login with ThaiD** is a single top-level button; activating it leaves the app for ThaiD and returns the user signed in. It is keyboard-focusable and clearly the secondary option.
- `Enter` submits the single primary action on a surface.
- `Esc` cancels a modal or step-up-dialog — but for step-up it **abandons the protected action rather than bypassing it**.
- The **whole data-table-row** is activatable by keyboard (Enter/Space) to open detail.
- Status is always carried in **text + icon**, never color alone, so it survives a screen reader and a monochrome view.

**Banned everywhere:** iframing any staff-auth surface; infinite scroll (paginate instead); placeholder-only labels; color-only status; silently bypassing step-up on `Esc`; showing the HR and System sections in the same shell.

## Accessibility Floor

**WCAG 2.1 AA across every surface.** Behavioral; contrast ratios live in `DESIGN.md`.

- **Keyboard-complete** flows end to end (sign-in, MFA, activation, reset, every admin action) with a **visible focus ring**.
- **Persistent, visible labels** on every field — never placeholder-as-label.
- **Errors associate to their field via `aria`** and are described in text, not by color or position alone.
- **Status carried by text + icon, not color alone** (status-pill, alerts).
- The **6-digit code is one labeled group**, announced and operated as a single field.
- **200% zoom and reflow** supported without loss of content or function.
- **Thai-script readiness**: all strings externalized; generous line-height so Thai diacritics render cleanly after the owner translates.

## Key Flows

The eight PRD user journeys, verbatim, with the climax beat and FR refs.

### UJ-1 · Staff SSO login (returning) — *Somchai, lab technician*

1. Opens the reporting app → redirected to the branded login.
2. Enters email + password, then his MFA code (or instead taps "Login with ThaiD").
3. Redirected back, signed in.
4. **Climax:** Later opens the document archive → **already signed in, no re-prompt.**

*(FR1, FR2, FR7, FR13)*

### UJ-2 · New-hire first-login activation — *Anong, newly hired epidemiologist*

1. HR creates her account.
2. She receives an **activation email**.
3. Clicks the single-use link.
4. **Sets her own password and enrolls an MFA authenticator.**
5. **Climax:** Lands signed in, alerted her account is active.

*(FR16, FR13, FR26, FR48)*

### UJ-3 · Self-service password reset — *Somchai forgot his password*

1. Clicks "forgot password".
2. Enters email (same generic confirmation regardless).
3. Receives a single-use, short-lived link.
4. Sets a new password.
5. **Climax:** **All his other sessions are invalidated** and he is alerted → signs in with MFA. No admin involved.

*(FR17, FR20, FR48)*

### UJ-4 · HR onboarding a joiner — *Pranee, HR administrator*

1. Creates the new hire (name + work email).
2. Account is **pending**, activation email auto-sent.
3. **Climax:** For a batch she **CSV-imports** through a **validate-and-preview** step.

*(FR26, FR30, FR49)*

### UJ-5 · HR offboarding a leaver — *Pranee, when someone resigns*

1. Finds the person.
2. **Disables** the account.
3. **Climax:** They can **no longer obtain a login at any integrated app**, and their **tokens + sessions are revoked immediately**. Apps that bound their local session drop them within the token window.

*(FR28, FR25, FR46)*

### UJ-6 · App-owner integration — *Wirat, owner of an internal app*

1. Requests a client → System Admin registers it.
2. Wirat follows the **integration guide**, copies the **reference client**, wires standard OIDC, validates tokens, bounds his local session, and maps the **work-email claim** to his app's records.
3. **Climax:** His app is now behind SSO.

*(FR32, FR40–FR43)*

### UJ-7 · Lost MFA device (admin-assisted, hardened) — *Somchai loses his phone*

1. Contacts HR.
2. **Pranee verifies his identity out-of-band and attests to it.**
3. **Resets his MFA**; Somchai is **notified** and his account returns to **re-activation**.
4. **Climax:** He re-sets his password and re-enrolls a new authenticator via a single-use link.

### UJ-9 · Staff signs in with ThaiD — *Somchai prefers ThaiD*

1. On the Sign in surface he taps **Login with ThaiD** (instead of email + password).
2. Redirected top-level to ThaiD; authenticates there.
3. Returns to envocc-sso; Keycloak matches his **PID** to his canonical account.
4. **Climax:** Signed in with the same SSO session his apps expect — no password or code entered on this path.

*(FR13a, FR1, FR7)*

*(FR15, FR29, FR44)*

### UJ-8 · System Admin registers a client — *Rawinan, System Administrator*

1. An app owner requests onboarding.
2. In the System console he **registers a new OIDC client** — exact-match redirect URIs, allowed scopes, client credentials.
3. **Climax:** Hands the credentials + integration guide to the app owner.

*(FR32, FR40)*
