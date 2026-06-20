---
name: EnvOcc SSO
status: final
sources:
  - ../../prds/prd-envocc-sso-2026-06-19/prd.md
  - ../../prds/prd-envocc-sso-2026-06-19/addendum.md
updated: 2026-06-20
---

# EnvOcc SSO — Experience Spine

> The experience contract for EnvOcc's first single sign-on and central identity system. Visual identity lives in `DESIGN.md` (Civic Register / Ministry Bronze); this spine owns *how it works* — IA, voice, behavior, states, accessibility, and journeys. Product requirements are inherited by reference from the PRD in `sources:` and not re-stated; this file holds design/experience decisions. Trust and security are the product, so they get first-class sections here.

## Foundation

**Web only.** Two postures inside one trust register:

- **Branded staff-auth surface group** — the IdP-hosted login, MFA, first-login activation, and self-service reset. **Responsive** (works on phone and desktop). Credentials never transit apps; these surfaces are served by the IdP itself and **render top-level only** — never iframed (CSP `frame-ancestors 'none'`), because the brand chrome and the URL are part of how staff tell a real login from a phishing page.
- **One role-gated admin app** — a single branded shell holding two sections: the **HR-lifecycle section** (employee joiner/mover/leaver) and the **System-administration section** (OIDC clients, admin users, audit log). Separation of duties is **enforced by role**, not by two separate apps: an HR Administrator sees only the HR section; a System Administrator sees only the System section. **Desktop-first**, data-dense, responsive-tolerant.

**UI system = custom.** No component library is named or inherited; `DESIGN.md` is the visual reference and the single source for tokens. Build stack (frontend/backend/DB) is open by design (PRD OQ2) and out of scope for this spine.

This is **two co-equal halves**, not "a login page with an admin screen bolted on" — the experience treats the admin app with the same rigor as the staff auth surfaces.

## Information Architecture

Every PRD surface has a home below. The two groups share one brand; role gates the admin nav.

### Staff-auth surface group (responsive, top-level only)

| Surface | Reached from | Purpose | PRD |
|---|---|---|---|
| Sign in | RP redirect to IdP / direct | Email + password, then MFA | FR1, FR2, FR12 |
| Verification code (MFA) | After password step | Enter 6-digit TOTP code | FR13, FR14 |
| Forgot password | Sign-in link | Request a reset by email | FR17, FR20 |
| Email-sent confirmation | After reset/activation request | Generic "if an account exists…" notice | FR20 |
| Reset password | Reset email link | Set a new password (does not clear MFA) | FR17, FR48 |
| Activate account | Activation email link | Set first password + enroll MFA (TOTP QR + manual key) | FR16, FR13 |
| MFA enrollment | During activation / after MFA reset | Scan QR or enter setup key, confirm a code | FR13, FR44 |
| Re-activation | After admin MFA reset | Re-set password **and** re-enroll MFA via single-use link | FR44 |
| Signed out | RP-initiated logout / forced logout | Confirmation of session end | FR10, FR46 |
| Auth error / invalid-link | Expired or used token, generic failures | Generic, enumeration-safe message + recover path | FR20, FR48 |

Security-event notifications (account activated, password changed, MFA reset, "signed out everywhere") are delivered by **email**, each with "if this wasn't you" guidance — see Trust & Security UX.

### Admin app — one shell, role-gated nav

| Section | Surface | Reached from | Purpose | PRD |
|---|---|---|---|---|
| (shell) | App header + role-gated nav | Sign in as admin | Branded shell; nav shows only the signed-in role's section | FR33 |
| **HR** | User list / search | HR nav | List + search staff, see lifecycle state | FR27 |
| **HR** | Create user | User list | Create one account (name + work email) → pending, sends activation | FR26 |
| **HR** | User detail | User-list row | View account; enable/disable; trigger reset; reset MFA; edit profile | FR28, FR29, FR31 |
| **HR** | CSV bulk import | User list | Upload → validate → preview/confirm → create pending accounts | FR30, FR49 |
| **System** | Client (OIDC app) list | System nav | List registered relying-party apps | FR32 |
| **System** | Register / edit client | Client list | Client credentials, exact-match redirect URIs, scopes; rotate secret (overlap) | FR32 |
| **System** | Admin users | System nav | Create/disable HR & System Admins; assign role (separation of duties) | FR33 |
| **System** | Audit log | System nav | View + export auth events & admin actions (every read is itself audited) | FR34, FR35–39 |

Nav is **role-gated**: the HR section and the System section never appear together for one user. Modal stacks one level deep only.

→ Composition reference: `.working/directions-login.html` (Civic Register login layout) and `.working/color-themes-civic.html` (Ministry Bronze in-context preview). Spine wins on conflict.

## Voice and Tone

Microcopy rules. Brand voice and aesthetic posture live in `DESIGN.md`. Audience: **non-technical staff**. Three hard rules: **plain language / no jargon**, **anti-phishing guidance is first-class**, **generic enumeration-resistant messages**.

| Do | Don't |
|---|---|
| "Enter your verification code" | "Enter your TOTP / OTP token" |
| "Open your authenticator app" | "Use your TOTP app to generate an OIDC factor" |
| "If an account exists for this email, we've sent a link to reset your password." | "No account found for that email." / "Reset email sent to jane@…" |
| "We'll never ask for your verification code by email, phone, or chat." | (omitting anti-phishing reassurance entirely) |
| "Don't share this link — it signs in as you." | "This is a secure tokenized URL." |
| "Too many attempts. Please wait a few minutes and try again." | "Account locked: failed_login_count exceeded threshold." |
| "Your account is now active." / "Your password was changed." | "Activation transaction committed (200 OK)." |
| "If this wasn't you, reset your password now and tell your administrator." | (a security event email with no "if this wasn't you" path) |
| Same wording whether or not the account exists | Any message whose presence/wording reveals an account exists |
| Security-critical strings prioritized for Thai (activation, reset, MFA, "don't share this link") | Leaving the anti-phishing/recovery copy English-only for non-technical staff |

Never say: TOTP, OTP, OIDC, token, JWT, session-fixation, claim. Say: verification code, authenticator app, sign-in link / reset link, signed in, account.

## Component Patterns

Behavioral rules. Visual specs live in `DESIGN.md.Components` (cross-referenced by name).

| Component | Use | Behavioral rules |
|---|---|---|
| Branded shell / header (`DESIGN.md` `app-header`, `wordmark`) | Every surface | Wordmark is non-interactive trust signal on auth; in the admin app it links Home. Header shows the signed-in admin's role; nav renders only that role's section. |
| Auth card (`auth-card`) | All staff-auth surfaces | One task per card. The anti-phishing banner is pinned inside, always visible — never dismissible on sign-in. |
| Text input (`text-input`) | Email, name, profile | Label always visible (never placeholder-as-label). Errors appear below the field, associated via `aria-describedby`. |
| Password input (`password-input`) | Set/reset password, sign-in | Show/hide reveal toggle. New-password fields show live policy hints (≥12 chars; long passphrases welcome; rejects known-breached) — guidance, not red nagging, until submit. |
| 6-digit code input (`code-input`) | Verification code, MFA confirm | Auto-advance per digit; accepts paste of a full code; `Backspace` steps back. One labeled group for screen readers, not six unlabeled boxes. Verify on the 6th digit or explicit submit. |
| Primary / secondary / link buttons (`button-*`) | Throughout | Primary = the one forward action per surface. Destructive actions (disable, force-logout) use the destructive variant and a step-up confirm. Buttons disable + show progress during async; never double-submit. |
| Status pill (`status-pill-*`) | User list, user detail | Active / Pending / Disabled. Carries a text label + tone, never color alone. |
| Data table row (`data-table-row`) | HR user list, System client/admin lists | Whole row opens detail. Trailing status pill. Sortable/searchable; paginate, never infinite-scroll. |
| Alert / banner — 4 states (`alert-info/success/warning/error`) | All surfaces | Info = standing anti-phishing + generic confirmations; Success = completed security event; Warning = expiry/throttle; Error = lockout/invalid. Always icon + text, never color alone. |
| Modal / step-up dialog (`modal`, `step-up-dialog`) | Sensitive admin ops | Step-up re-auth required before reset MFA, register/edit client, manage admins (FR50). Focus trapped; a required step-up must be completed or cancelled — `Esc` cancels, never silently bypasses. |
| File-upload / CSV preview (`file-upload`, `csv-preview-table`) | HR CSV import | Parse client-side into a preview before any account is created. Clean / invalid / duplicate rows visibly distinguished; a confirm step gates creation; per-import size cap enforced; activation-email dispatch throttled (FR49). |

## State Patterns

The full PRD state set. Each names its surface and treatment; copy follows the Voice rules.

| State | Surface(s) | Treatment |
|---|---|---|
| **Account pending** | User list/detail; activation | Pending pill (warning tone). User can't sign in yet; only the activation link works. Detail shows "Awaiting activation" + re-send / expiry. |
| **Account active** | User list/detail | Active pill (success tone). Normal sign-in. |
| **Account disabled** | User list/detail; sign in | Disabled pill (muted). On any sign-in attempt → the **generic** sign-in failure (no "this account is disabled" — that would confirm existence). Detail offers re-enable. |
| **Loading** | All async | Inline progress on the triggering control; skeleton rows for tables. No full-page spinner blocking a typed form. |
| **Empty** | User list, client list, admin list, audit log, CSV preview | Plain one-liner + the primary action. e.g. user list: "No staff accounts yet. Create the first one, or import a roster." Audit log empty only before first event. |
| **Error (generic / unexpected)** | Any | `alert-error`: "Something went wrong. Please try again." Never leaks stack/internal detail. Preserves typed input. |
| **Success** | Activation, reset, admin actions | `alert-success` + the matching security-event email. "Your account is now active." / "Saved." |
| **Lockout / throttle** | Sign in, verification code, reset/activation request | `alert-warning`: "Too many attempts. Please wait a few minutes and try again." Progressive delay (per-account + per-IP), not a hard named-account lockout. Same message regardless of whether the email exists. |
| **Token expired / invalid link** | Activation, reset, MFA links | `alert-error`, generic: "This link has expired or already been used." + a path to request a fresh one. Never reveals which account it belonged to. |
| **Pending expired** | Activation link; user detail | Activation token past its window → "This activation link has expired." Admin sees expired-pending state and can re-issue (FR48); counts toward CM3 (never-activated). |
| **Email-sent confirmation** | After forgot-password / activation request | `alert-info`, identical every time: "If an account exists for this email, we've sent a link." No "check your inbox, jane@…". |
| **Enumeration-resistant generic** | Sign in, forgot, activate, reset | Login/activation/reset responses are identical in wording and timing whether or not an account exists (FR20). This is a cross-cutting rule, not one screen. |
| **Session expired / re-auth** | Admin app, returning staff | Idle or absolute lifetime hit (FR8) → "Your session has ended. Please sign in again." Returns to sign-in; no silent data loss prompt-before-expiry where feasible. |
| **Step-up required** | Sensitive admin ops | Before reset MFA / register client / manage admins, a step-up dialog: "Confirm it's you to continue." Re-enter password (and code if configured). Cancel returns without performing the action. |
| **Disabled mid-session (revocation)** | A signed-in user who is disabled / force-logged-out | Next IdP request is rejected; refresh-token families revoked and server-side sessions invalidated immediately (FR46). User lands on the generic signed-out surface: "You've been signed out." (No accusatory detail.) |

## Interaction Primitives

- **Forward-only forms.** One primary action per surface. `Enter` submits the focused form; the primary button shows progress and locks against double-submit.
- **Code entry.** The 6-digit input auto-advances, accepts a pasted code, and verifies on completion. No "resend" spam — resend is rate-limited with a visible cooldown.
- **Reveal, don't guess.** Password fields offer show/hide; the system never silently transforms input.
- **Confirm destructive + sensitive.** Disable account, force-logout, reset MFA, rotate secret, manage admins → explicit confirm, and step-up re-auth where FR50 requires it.
- **Preview before commit.** CSV import always previews; nothing is created from a drop alone.
- **Generic + constant-time responses** on all auth endpoints — timing must not leak account existence.
- **Banned everywhere:** auto-dismissing security messages; placeholder-as-label; infinite scroll on admin tables; embedding any auth surface in an iframe; revealing whether an email maps to an account; jargon in user-facing copy.

## Accessibility Floor

**WCAG 2.1 AA** across every surface (contrast already AA-verified in `DESIGN.md`). Behavioral commitments:

- **Keyboard:** every flow completable by keyboard alone — sign-in, MFA entry, activation, all admin CRUD. Logical `Tab` order matches reading order. `Esc` closes the topmost modal/popover; a required step-up cancels rather than silently bypasses.
- **Focus:** visible navy focus ring (`{colors.primary}`, ≥9:1) on all interactive elements; focus moves into a dialog on open and returns to the trigger on close; focus is trapped within open modals.
- **Labels:** every input has a persistent visible label and a programmatic name. The 6-digit code input is a single labeled group, not six anonymous boxes. Buttons have text or an accessible name; icons are never the only label.
- **Error association:** validation errors are tied to their field via `aria-describedby` and announced via an `aria-live` region; an error summary is announced, not just colored.
- **Status, not color alone:** Active/Pending/Disabled and all four alert states pair tone with a text label and an icon.
- **Thai-script readiness:** all copy is externalized strings (FR12), never baked into images; security-critical strings are prioritized for Thai (FR19); type tokens use generous line-height so Thai diacritics are not clipped at the largest comfortable zoom. UI must survive 200% zoom and text reflow without loss of function.

## Trust & Security UX

Security is the product, so its experience is specified here, not left implicit.

- **Anti-phishing, first-class.** A standing reassurance banner is pinned to sign-in and code entry: "We'll never ask for your verification code by email, phone, or chat." Activation and reset emails carry "Don't share this link — it signs in as you," prioritized for Thai. These are never demoted to muted text or a dismissible tooltip.
- **MFA enrollment.** During activation (and after an admin MFA reset → re-activation), the user enrolls an authenticator app: a **QR code** to scan **plus a manual setup key** for users who can't scan, then a confirming 6-digit entry. Plain-language steps; no "TOTP secret" jargon.
- **Identity-proofing attestation prompt (admin side).** When an admin resets a user's MFA or password, the console requires an explicit **out-of-band identity-verification attestation** before completing — a checkbox/confirm: "I verified this person's identity out-of-band (e.g., known voice on a call-back, in person)." The attestation is written to the audit record (FR44). This is a deliberate friction, surfaced clearly, not buried.
- **Honest "signed out everywhere."** When a password reset or MFA reset completes, or an admin force-logs-out a user, the affected person is told plainly that **all other sessions were ended**, and the security-event email says so with an "if this wasn't you" recovery path. The UI does not pretend nothing changed.
- **Security-event notifications.** Account activated, password changed, MFA reset, and "signed out everywhere" each trigger an email to the user, each with explicit "if this wasn't you, do X" guidance. The in-app confirmation and the email agree.
- **MFA reset is never a half-state.** An admin MFA reset returns the account to **re-activation** (re-set password *and* re-enroll MFA via a single-use link) — the UI never presents a "password known, MFA cleared" window (FR44).

## Key Flows

Named-protagonist journeys mirroring the PRD's UJ names verbatim, each with its climax beat. Protagonist names are illustrative (PRD `[ASSUMPTION]`).

### UJ-1 · Staff SSO login (returning) — *Somchai, lab technician*

1. Somchai opens the reporting app; it redirects him to the EnvOcc branded sign-in (top-level, real URL visible).
2. He enters email + password; the anti-phishing banner sits below the form the whole time.
3. The verification-code surface appears; he enters the 6-digit code from his authenticator app.
4. He's redirected back to the reporting app, signed in.
5. **Climax:** later he opens the document archive — and is **already signed in, no second prompt**. One login reached a second app; the SSO promise is felt, not explained. *(FR1, FR2, FR7, FR13)*

Failure: too many code attempts → throttle warning, identical wording regardless of account state; he waits and retries.

### UJ-2 · New-hire first-login activation — *Anong, newly hired epidemiologist*

1. HR creates Anong's account; she receives an **activation email** ("Don't share this link").
2. She clicks the single-use link → the Activate surface.
3. She sets her own password (live policy hints, breached-list check) and enrolls an authenticator (QR + manual key, confirm a code).
4. She lands signed in.
5. **Climax:** an in-app success and a **security-event email** both say "Your account is now active" with "if this wasn't you" guidance — she's in, and the trust loop is closed. *(FR16, FR13, FR26, FR48)*

Failure: link expired/used → generic "This link has expired or already been used," with a path to ask HR for a fresh one (pending-expired).

### UJ-3 · Self-service password reset — *Somchai forgot his password*

1. From sign-in he taps "Forgot password" and enters his email.
2. He sees the **generic** confirmation: "If an account exists for this email, we've sent a link" — identical whether or not it exists.
3. He opens the single-use, short-lived reset link and sets a new password (MFA enrollment is **not** cleared).
4. **Climax:** completion **invalidates all his other sessions**, he's told so plainly, and a security-event email confirms "Your password was changed" with "if this wasn't you." He signs in with MFA, no admin involved. *(FR17, FR20, FR48)*

Failure: link expired → generic invalid-link error + request-a-fresh-one path.

### UJ-4 · HR onboarding a joiner — *Pranee, HR administrator*

1. In the HR section, Pranee creates a new hire (name + work email).
2. The account is **pending**; an activation email is auto-sent.
3. For a batch she opens **CSV import**, uploads a roster.
4. The preview shows clean / invalid / duplicate rows distinctly; a per-import cap and email throttle apply.
5. **Climax:** she hits **Confirm** on a clean preview — the pending accounts are created and activation emails dispatched in one reviewed step; nothing was created from the raw file. *(FR26, FR30, FR49)*

Failure: a row is a duplicate or malformed → flagged in preview, excluded from the commit; she fixes and re-imports just those.

### UJ-5 · HR offboarding a leaver — *Pranee, when someone resigns*

1. Pranee searches the user list and opens the leaver's detail.
2. She selects **Disable**; a confirm (destructive) explains the effect.
3. On confirm, the account is disabled.
4. **Climax:** the person can **no longer obtain a login at any integrated app**, and their **refresh-token families + IdP sessions are revoked immediately** (FR46). The pill flips to Disabled; apps that bound their local session to the IdP drop them within the token window. *(FR28, FR25, FR46)*

Failure/edge: she disabled the wrong person → re-enable from detail; the action and its reversal are both audited.

### UJ-6 · App-owner integration — *Wirat, owner of an internal app*

1. Wirat requests a client; the System Admin registers it (UJ-8) and hands him credentials + the integration guide.
2. He follows the guide, copies the **reference client**, wires standard OIDC (Auth Code + PKCE), validates the ID token/JWKS.
3. He bounds his app's local session to the IdP token lifetime and maps the **work-email claim** to his app's existing user records.
4. **Climax:** his app is now **behind EnvOcc SSO** — staff reach it through the same branded login, and a disabled account is dropped within the token window. *(FR32, FR40–FR43)*

Note: this flow is primarily docs + reference code (PRD FG-7), not an EnvOcc UI surface; the experience touchpoint is the System Admin registration screen (UJ-8) and the branded login the RP redirects to.

### UJ-7 · Lost MFA device (admin-assisted, hardened) — *Somchai loses his phone*

1. Somchai contacts HR; **Pranee verifies his identity out-of-band** (call-back, known voice / in person).
2. In his user detail she selects **Reset MFA**; a **step-up re-auth** confirms it's her, and an **identity-proofing attestation** checkbox is required before she can complete ("I verified this person's identity out-of-band").
3. She completes the reset.
4. **Climax:** Somchai's account returns to **re-activation** (never "password known, MFA cleared") — he gets a single-use link, **re-sets his password and re-enrolls a new authenticator**, and a security-event email tells him his MFA was reset with "if this wasn't you" guidance. The hardened path leaves no half-open window. *(FR15, FR29, FR44)*

Failure: admin-reset rate exceeded → abuse alert (not merely counted); the action is throttled and flagged.

### UJ-8 · System Admin registers a client — *Rawinan, System Administrator*

1. An app owner requests onboarding.
2. In the System section, Rawinan opens **Register client**; a **step-up re-auth** gates the sensitive action.
3. He enters client credentials, **exact-match redirect URIs**, and allowed scopes.
4. **Climax:** the client is registered; he hands the credentials + integration guide to the app owner, and the registration (and any later secret rotation, with its overlap window) is written to the audit log. *(FR32, FR40)*

Failure: a redirect URI isn't exact-match / is malformed → inline validation blocks save until corrected (no wildcard accepted).
