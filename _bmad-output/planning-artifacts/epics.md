---
stepsCompleted: [1, 2, 3, 4]
status: 'complete'
completedAt: '2026-06-20'
revisedAt: '2026-06-20'
revisionNote: 'Reshaped for the stack pivot to Keycloak (IdP) + Ruby on Rails (admin layer over the Keycloak Admin REST API). FG-1/2/6/8 become stand up + configure + theme Keycloak; FG-4/5 become the Rails app over the Admin API. See sprint-change-proposal-2026-06-20.md.'
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-19/prd.md
  - _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-19/addendum.md
  - _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-19/review-security.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-06-20.md
  - _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-20/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-20/EXPERIENCE.md
---

# envocc-sso - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for envocc-sso (EnvOcc's single sign-on and central identity system), decomposing the requirements from the PRD, the UX Design (DESIGN.md + EXPERIENCE.md), the Architecture, and the adversarial security review into implementable stories.

> **Revised 2026-06-20 — stack pivot.** The IdP is **self-hosted Keycloak** (configured + themed, not built from scratch); the custom HR/System control plane is a **Ruby on Rails** app over the **Keycloak Admin REST API** that signs admins in via Keycloak (OIDC). The 6-epic spine and user outcomes are unchanged; each epic's *implementation* re-pivots: **FG-1/2/6/8 → stand up + configure + theme Keycloak**, **FG-4/5 → the Rails app over the Admin API**. Full delta: `sprint-change-proposal-2026-06-20.md`.

## Requirements Inventory

### Functional Requirements

> FR *capabilities* are unchanged by the pivot; the implementing mechanism moves to Keycloak configuration and/or the Rails admin layer (noted per FR where useful).

**FG-1 — OIDC Authentication & SSO (core)** *(→ configure Keycloak)*
- FR1: Authenticate staff via OIDC Authorization Code flow with PKCE for all clients.
- FR2: IdP hosts the login itself; credentials never transit relying-party apps.
- FR3: MUST NOT offer Implicit or ROPC grant types.
- FR4: Clients register redirect URIs; exact-match enforced (no wildcard/substring).
- FR5: On success, issue an asymmetrically-signed ID token (agreed claims incl. work-email key); publish signing keys via JWKS.
- FR6: Bind each auth request with `state` (CSRF) and `nonce` (ID-token replay).
- FR7: Establish an SSO session — reach every integrated app without re-entering credentials until session ends.
- FR8: Enforce idle and absolute session lifetimes; re-auth on expiry.
- FR9: Issue short-lived tokens; refresh tokens (if issued) rotate on use with reuse-detection revoking the family.
- FR10: Support RP-initiated logout (terminate IdP session, honor validated post-logout redirect).
- FR11: Expose a standard OIDC discovery document (`.well-known`).

**FG-2 — Staff Authentication Experience** *(→ custom Keycloak theme + Keycloak flows)*
- FR12: Branded login matching the EnvOcc brand; English-first, externalized strings for localization.
- FR13: Enforce MFA via TOTP for all staff; enroll an authenticator during first-login activation.
- FR14: Verify TOTP with bounded drift window, rate-limited, single-use-per-step.
- FR15: Admin can reset a user's MFA enrollment (admin-assisted recovery, hardened by FR44); user re-enrolls on next sign-in.
- FR16: First-login activation — admin-created account starts pending; single-use, time-limited activation link by email; on first sign-in the user sets a password + enrolls MFA; user alerted.
- FR17: Self-service password reset by email (single-use, short-lived, high-entropy token); does not clear MFA; alert on completion.
- FR18: Password policy — min length ≥12, support long passphrases, screen against breached lists, no composition rules, no forced rotation.
- FR19: Brute-force protection — progressive delays, per-account and per-IP, on login and TOTP.
- FR20: Login/activation/reset flows enumeration-resistant — identical generic responses.

**FG-3 — Identity & User Store (system of record)** *(→ Keycloak users + claim mapper)*
- FR21: Exactly one canonical identity per staff member (system of record); stable internal subject id, never reused.
- FR22: Each identity carries a unique work email = the reconciliation key emitted as a claim.
- FR23: Store only the minimal attribute set (data minimization); no PDPA §26 sensitive data.
- FR24: Lifecycle states — pending activation → active → disabled, with controlled transitions.
- FR25: Disabling immediately blocks all new authentication everywhere and triggers server-side revocation (FR46); RP local sessions bounded by token lifetime (no back-channel SLO; RPs must bound local session per FR41).

**FG-4 — HR Admin Console (employee lifecycle)** *(→ Rails over the Admin API)*
- FR26: HR Admin creates a user (name + work email) → pending + activation email.
- FR27: HR Admin searches/lists users and views lifecycle state.
- FR28: HR Admin enables/disables an account; disable behaves per FR25/FR46.
- FR29: HR Admin triggers password reset and resets MFA (subject to FR44).
- FR30: HR Admin bulk-creates pending accounts via CSV import (subject to FR49).
- FR31: HR Admin corrects minimal profile attributes; changing the work-email key is a controlled action.

**FG-5 — System Admin Console (IdP administration)** *(→ Rails over the Admin API)*
- FR32: System Admin registers/manages OIDC clients (credentials, exact-match redirect URIs, scopes) and rotates client auth with overlap (`private_key_jwt` preferred).
- FR33: System Admin manages admin users (create/disable HR + System Admins, assign realm role) — separation of duties.
- FR34: System Admin views and exports the audit log; reads/exports are themselves audited.

**FG-6 — Audit Logging (compliance)** *(→ Keycloak events → off-host WORM + Rails audit)*
- FR35: Record authentication events (login success/fail [throttled vs failed], MFA outcome, session create/terminate/expiry, logout, activation, reset) with source IP/UA.
- FR36: Record admin actions (user create/enable/disable, password/MFA reset [with FR44 attestation], profile change, client register/secret rotation, signing-key rotation, admin-user changes).
- FR37: Record token & key events (token issuance, refresh-rotation/reuse-detection trips, JWKS/key rotation).
- FR38: Audit log append-only + integrity-verifiable, shipped off-host the operator can't rewrite, retained 12 months. *(Pivot: integrity provided by the off-host append-only/WORM sink + scheduled second-person export; the original "hash-chained" wording is relaxed to "append-only / integrity-verifiable at the sink" to avoid hand-rolled crypto — NFR8.)*
- FR39: Audit log excludes credentials/secrets/tokens, doesn't leak account existence; scheduled out-of-band copy to a named second person.

**FG-7 — App-Owner Integration Enablement**
- FR40: Publish an OIDC integration guide ("integrate as a Keycloak client"); the reference client is the testable "without deep auth expertise" artifact.
- FR41: Guide documents the full integration contract (discovery, Auth Code + PKCE, redirect-URI registration, ID-token/JWKS validation incl. iss/aud/exp/nonce/azp); RPs must bound local session to IdP token lifetime + honor `kid` with bounded JWKS cache TTL.
- FR42: Guide documents the identity claim contract (stable subject + work-email key) and how an app maps an SSO identity to its existing local account.
- FR43: Provide a minimal reference/sample OIDC client (the documented pilot integration).

**FG-8 — Operational Security & Account-Protection Controls**
- FR44: Admin MFA/password reset requires documented out-of-band identity-verification attested in the audit record; notifies the affected user; an MFA reset returns the account to pending re-activation (re-enroll MFA + re-set password via single-use link); rate-limited with abuse alert. *(→ Rails-enforced over the Admin API + Keycloak `execute-actions-email`.)*
- FR45: Regenerate session id on every auth-state transition; server-side session records; host-prefixed Secure/HttpOnly/SameSite cookies. *(→ Keycloak-native.)*
- FR46: Disabling immediately revokes all outstanding refresh-token families and invalidates all server-side IdP sessions; System Admin can force-terminate active sessions. *(→ Admin API logout-all + refresh revoke.)*
- FR47: Authorization codes single-use, short-lived, replay-detected; PKCE verifier binding enforced server-side; nonce verified exactly once. *(→ Keycloak-native.)*
- FR48: Issuing a new activation/reset token invalidates prior; completing invalidates all other sessions + outstanding tokens; reset/activation requests rate-limited per-account/per-IP; pending accounts expire after a bounded window. *(→ Keycloak action-token settings.)*
- FR49: CSV import validates + de-duplicates against existing identities, enforces a size cap, throttles activation dispatch, sanitizes CSV/formula injection, and has a preview/confirm step. *(→ Rails.)*
- FR50: Public unauthenticated endpoints protected by edge rate-limiting/abuse controls; JWKS/discovery cacheable; admin-console actions carry CSRF + step-up re-auth for sensitive ops. *(→ Nginx edge + Keycloak/Rails step-up.)*

### NonFunctional Requirements

- NFR1: **Keycloak native Argon2id** password hashing (≥19 MiB / ≥2 iters / p=1) + unique salt; **no application pepper** (DB encryption-at-rest + isolation cover stolen-DB risk).
- NFR2: TOTP secrets + email/action tokens handled by Keycloak (single-use, short-lived, hashed/encrypted at rest).
- NFR2a: Access/ID token maximum lifetime **≤15 min** (Keycloak realm setting).
- NFR3: Asymmetric (RS256) signing via **Keycloak realm keys**; JWKS with `kid`; rotation via key providers with active/passive overlap ≥ max token lifetime; `alg:none` rejected; recovery via realm export + DB backup.
- NFR4: TLS/HSTS at Nginx; host-prefixed Secure/HttpOnly/SameSite cookies; CSP `frame-ancestors 'none'` on auth surfaces (Keycloak Security Defenses + Nginx headers).
- NFR5: Conform to OAuth 2.0 Security BCP (RFC 9700) + OIDC Core security — Keycloak is OIDC-certified.
- NFR6: Built + verified to OWASP ASVS L2 (L3 for credential/key handling), scoped to the **Keycloak hardening config + Rails layer**; independently reviewed before SM5 passes.
- NFR7: Password policy per NIST SP 800-63B; brute-force per-account (Keycloak) + per-IP (Nginx).
- NFR8: **Audited engine (Keycloak) + maintained gems only**; no hand-rolled crypto/token/session logic; the Rails layer never re-implements an auth primitive.
- NFR9: CI includes dependency/vulnerability scanning (`bundler-audit`) + SAST (`brakeman`) + secret scan (`gitleaks`).
- NFR10: Independent pen test before broad rollout; independent review of the **Keycloak configuration + Rails layer** before the pilot processes real data.
- NFR11: Lawful basis = contractual necessity / legal obligation / legitimate interest (not consent), documented per purpose in a RoPA.
- NFR12: No PDPA §26 sensitive data; biometric/WebAuthn MFA (if ever) gated by explicit consent + heightened safeguards.
- NFR13: Data minimization; encryption at rest for credentials/secrets; least-privilege admin + Admin-API access.
- NFR14: Retention — audit/events 12 months; identity records retained per employment; erasure reconciliation (pseudonymize subject in retained events); DSR dispositions stated.
- NFR15: RoPA, lawful-basis doc, DPO sign-off, tested 72h breach runbook = gates before the pilot processes real staff data; named owner + date.
- NFR16: Keycloak SMTP is a monitored critical-path dependency (retries, monitoring, bounce handling); Rails-triggered admin reset is the fallback.
- NFR17: Single point of dependency; 24/7 target; edge DoS protection (Nginx); tested backup/restore of Keycloak Postgres + realm export/keys + Rails DB with RTO/RPO; key-loss/compromise runbook.
- NFR18: Sized for ~100–150 staff; p95 ≤500 ms login/token latency; not high-scale.
- NFR19: English-first UI structured for localization; security-critical strings prioritized for Thai — Keycloak `messages_th` + Rails i18n.

### Additional Requirements

*(From Architecture — these shape Epic 1 and cross-cutting setup. Re-pointed for the pivot.)*
- **AR1 — Scaffold (Epic 1):** stand up **Keycloak** (pinned Docker image) + import a **baseline realm**; then `rails new admin --database=postgresql --css=tailwind`; add `omniauth_openid_connect`/`faraday` (verify maintenance/version at scaffold) + `brakeman`/`bundler-audit`/`rspec`.
- **AR2 — Persistence:** PostgreSQL with **separate databases for Keycloak and Rails**; **no Redis** (Keycloak manages its own sessions/cache; Rails uses cookie/DB sessions).
- **AR3 — OIDC engine:** **Keycloak** (configured, not built); realm config-as-code (exported JSON, secrets stripped, imported on boot). *(No Bun-conformance watch-item.)*
- **AR4 — Key custody:** **Keycloak-managed realm keys** (active/passive rotation overlap); recovery via realm export + DB backup. *(No Vault.)*
- **AR5 — Audit infrastructure:** **Keycloak login + admin events** via the Event Listener SPI shipped **off-host to an append-only/WORM sink** + **Rails-side audit**; scheduled out-of-band export to a named second person.
- **AR6 — Edge / deployment:** **Nginx** single security edge (internal-CA TLS, per-IP rate-limiting, security headers) fronting Keycloak + Rails; **Kamal** deploys the Rails app (zero-downtime via `kamal-proxy`, behind Nginx); Keycloak + Postgres as pinned managed containers; nightly off-site **tested** backups (Keycloak Postgres + realm export/keys + Rails DB) with stated RTO/RPO.
- **AR7 — CI/CD:** `gitleaks` + `rubocop` + `brakeman` + `bundler-audit` + RSpec/system tests (against a running Keycloak) + realm-config lint + theme build.
- **AR8 — Secret hygiene (hard rule):** **never commit credentials — real or test**; `gitleaks` pre-commit + CI; `.env`/Rails `master.key`/Kamal secrets never committed; **realm exports committed only with secrets stripped**; tests use generated fakes.
- **AR9 — Observability:** uptime + error alerting; **Keycloak health/metrics**; SMTP deliverability monitoring (critical path).
- **AR10 — Org/compliance gates (before pilot):** named second person for audit oversight (OQ3); pilot apps identified (OQ1); independent **Keycloak-config + Rails review** + pen test (NFR10).

### UX Design Requirements

*(From DESIGN.md + EXPERIENCE.md — first-class, story-generating. DESIGN tokens now drive a custom **Keycloak theme** + **Rails styling**; "UI system = custom" holds literally — no daisyUI.)*
- UX-DR1: **Ministry Bronze** identity from DESIGN.md tokens, realized as **(a) a custom Keycloak theme** (staff auth surfaces) and **(b) Rails styling** (admin app) — primary navy `#1B3354`, accent bronze `#A9711B`, full semantic set; light mode only; WCAG AA verified.
- UX-DR2: **Noto bilingual type system** (Noto Serif headings/wordmark + Noto Sans body + Noto Sans Mono code; with Thai companions) per the DESIGN.md type scale — served as theme static assets (Keycloak) + Rails asset pipeline.
- UX-DR3: **Component set per DESIGN.md, split by surface:** *Keycloak theme* (AuthCard/login layout, CodeInput 6-digit, PasswordInput, Alert/anti-phishing banner) for staff auth; *Rails views* (StatusPill, DataTable, StepUpModal, file-upload/CSV-preview, branded shell/header + wordmark) for the admin app. Each component derives from DESIGN.md tokens in its surface's native templating (FreeMarker / ERB + Tailwind).
- UX-DR4: **Staff-auth surfaces (Keycloak theme, top-level, never iframed):** Sign in · Verification code (OTP) · Forgot password · Email-sent confirmation · Reset password · Activate (set password + enroll MFA with QR + manual key) · Re-activation · Signed out · Auth error/invalid-link.
- UX-DR5: **Admin app shell (Rails)** — one role-gated shell (HR section + System section); nav shows only the signed-in role's section.
- UX-DR6: **HR console screens (Rails):** User list/search · Create user · User detail (enable/disable, reset, MFA reset with identity-proof attestation modal) · Profile edit · CSV import (upload → validate/preview → confirm → result).
- UX-DR7: **System console screens (Rails):** Client list · Register/edit client (+ rotation) · Admin-user management (+ step-up re-auth modal) · Audit-log view + export · Force-logout / active-session view.
- UX-DR8: **State patterns** — every view handles loading/empty/error/success + lockout/throttle, token-expired/invalid-link, pending-expired, email-sent confirmation, enumeration-resistant generic, session-expired/re-auth, step-up-required, disabled-mid-session revocation.
- UX-DR9: **Voice & tone** — plain language, no jargon; anti-phishing first-class ("we'll never ask for your code", "don't share this link"); enumeration-resistant messages; security-event notifications with "if this wasn't you" guidance.
- UX-DR10: **Accessibility floor WCAG 2.1 AA** — keyboard, focus, labels, error association, Thai-script readiness — across the Keycloak theme + Rails views.
- UX-DR11: **Localization** — **Keycloak `messages_en`/`messages_th`** (staff auth) + **Rails i18n `en.yml`/`th.yml`** (admin); security-critical strings translated to Thai first (NFR19).
- UX-DR12: **Trust & Security UX** — MFA enrollment (QR + manual key + confirm), identity-proofing attestation prompt, honest "signed out everywhere" copy, session-expiry/re-auth prompts, step-up re-auth for sensitive admin actions.

### FR Coverage Map

- FR1: Epic 1 — Keycloak Auth Code + PKCE (client config)
- FR2: Epic 1 — Keycloak-hosted login
- FR3: Epic 1 — disable Implicit/ROPC
- FR4: Epic 1 — exact redirect-URI match (registration UI in Epic 4)
- FR5: Epic 1 — RS256 realm keys + JWKS
- FR6: Epic 1 — state/nonce (Keycloak/OIDC)
- FR7: Epic 1 — SSO session
- FR8: Epic 1 — session lifetimes
- FR9: Epic 1 — short tokens + refresh rotation/revoke
- FR10: Epic 1 — RP-initiated logout
- FR11: Epic 1 — discovery document
- FR12: Epic 2 — branded Keycloak theme
- FR13: Epic 2 — MFA enrollment (verify at sign-in in Epic 1)
- FR14: Epic 1 — TOTP verification (OTP policy)
- FR15: Epic 3 — admin MFA reset (Rails)
- FR16: Epic 2 — first-login activation (Keycloak required actions)
- FR17: Epic 2 — self-service password reset
- FR18: Epic 1 (policy) + Epic 2 (enforced in set-password)
- FR19: Epic 1 — brute-force (Keycloak per-user) + Epic 6 (Nginx per-IP)
- FR20: Epic 1/Epic 2 — enumeration resistance (Keycloak flows)
- FR21: Epic 1 — canonical identity (Keycloak user, stable sub)
- FR22: Epic 1 — work-email claim mapper
- FR23: Epic 1 — minimal User Profile
- FR24: Epic 1 (model) + Epic 2 (transitions) — lifecycle states
- FR25: Epic 3 — disable blocks auth (mechanics in Epic 1; revoke via Admin API)
- FR26: Epic 3 — create user (Admin API)
- FR27: Epic 3 — search/list users
- FR28: Epic 3 — enable/disable
- FR29: Epic 3 — trigger reset / MFA reset
- FR30: Epic 3 — CSV bulk import
- FR31: Epic 3 — profile edit
- FR32: Epic 4 — client registration + rotation
- FR33: Epic 4 — admin-user/realm-role management
- FR34: Epic 5 — audit view/export
- FR35: Epic 1 (events on) + Epic 5 (capture/ship) — auth events
- FR36: Epic 5 (+ Rails audit per-feature) — admin-action events
- FR37: Epic 1 (events on) + Epic 5 — token/key events
- FR38: Epic 5 — append-only / off-host WORM / 12-mo retention
- FR39: Epic 5 — exclude secrets + second-person export
- FR40: Epic 6 — integration guide
- FR41: Epic 6 — integration contract doc
- FR42: Epic 6 — claim-contract doc
- FR43: Epic 6 — reference client (minimal client seeded in Epic 1)
- FR44: Epic 3 — admin-reset hardening (Rails + execute-actions-email)
- FR45: Epic 1 — session-id regeneration (Keycloak-native)
- FR46: Epic 3 — revocation on disable (Admin API)
- FR47: Epic 1 — auth-code/PKCE/nonce single-use (Keycloak-native)
- FR48: Epic 2 — token hygiene (Keycloak action tokens)
- FR49: Epic 3 — CSV import validation (Rails)
- FR50: Epic 4 (step-up) + Epic 6 (edge rate-limiting)

## Epic List

### Epic 1: Keycloak IdP Foundation & SSO Core
Stand up and configure self-hosted Keycloak so a returning, active staff member signs in once (email + password + verification code) and reaches a connected app with a valid OIDC token — every event recorded by Keycloak. Establishes the Docker stand-up, the realm config-as-code, OIDC clients (Auth-Code+PKCE-only), RS256 realm keys + rotation, token/session settings, password policy + brute-force, the canonical-identity + work-email claim, and a reference client proving SSO end-to-end.
**FRs covered:** FR1–FR11, FR14, FR18 *(policy)*, FR19 *(per-account)*, FR20, FR21, FR22, FR23, FR24 *(model)*, FR45, FR47, FR35/FR37 *(events enabled)*
**Also:** AR1–AR4, AR8, NFR1–NFR5, NFR7, NFR8

### Epic 2: Ministry Bronze Theme, Staff Experience & Recovery
Build the custom Keycloak theme from DESIGN.md tokens and wire the staff auth flows so a new hire activates their own account (sets a password, enrolls an authenticator) from an emailed link, and any staff member recovers a forgotten password by email — all branded, accessible, and bilingual.
**FRs covered:** FR12, FR13, FR16, FR17, FR24 *(transitions)*, FR48 *(+ FR18/FR20 in the themed flows)*
**Also:** NFR2, NFR4, NFR19, UX-DR1–UX-DR4, UX-DR9–UX-DR12

### Epic 3: Rails HR Admin Console (Employee Lifecycle)
A Rails app — admins signed in via Keycloak (OIDC), role-gated to the HR section — provisions and offboards staff entirely over the Keycloak Admin REST API: create, search, enable/disable (effective everywhere immediately), trigger hardened password/MFA resets, and bulk-import a roster by CSV.
**FRs covered:** FR15, FR25, FR26, FR27, FR28, FR29, FR30, FR31, FR44, FR46, FR49
**Also:** AR1 *(Rails)*, UX-DR5, UX-DR6

### Epic 4: Rails System Admin Console & App Onboarding
The Rails System section (System Admin role) connects internal apps as Keycloak OIDC clients (with `private_key_jwt`/secret rotation) and manages admin users + realm roles, with role-based separation of duties, CSRF, and step-up re-authentication for sensitive actions.
**FRs covered:** FR32, FR33, FR50 *(step-up)* *(+ FR4 registration UI)*
**Also:** UX-DR7 *(client/admin screens)*

### Epic 5: Audit, Compliance & Oversight
Keycloak login + admin events and Rails-side admin-action audit are shipped to a tamper-evident, append-only off-host sink; the System Admin reviews and exports them in Rails; retention and a scheduled out-of-band export to a named second person satisfy PDPA and solo-operator oversight.
**FRs covered:** FR34, FR35, FR36, FR37, FR38, FR39
**Also:** NFR11–NFR15, UX-DR7 *(audit view)*

### Epic 6: Integration Enablement & Production Hardening
App owners self-integrate as Keycloak OIDC clients via a clear guide + a copyable reference client; the system is deployed (Kamal for Rails; Keycloak + Postgres as managed containers) behind Nginx with edge abuse-protection, monitored, backed up (tested restore), and run through CI security gates — ready for the independent review and the pilot.
**FRs covered:** FR40, FR41, FR42, FR43, FR50 *(edge)*
**Also:** AR5–AR10, NFR9, NFR10, NFR16, NFR17

## Epic 1: Keycloak IdP Foundation & SSO Core

Stand up + configure Keycloak so a returning active staff member signs in once and reaches a connected app with a valid OIDC token. Establishes the realm config-as-code, OIDC core, realm keys, identity model, and a reference client.

### Story 1.1: Keycloak stand-up, baseline realm & secret hygiene

As a developer,
I want Keycloak running locally and in-repo as config-as-code with secret-hygiene guards,
So that all later work builds on a consistent, reproducible, secure IdP foundation.

**Acceptance Criteria:**

**Given** a clean repository
**When** `docker compose up` runs
**Then** a **pinned** Keycloak image starts against PostgreSQL and **imports a baseline `envocc` realm** from a version-controlled `realm-export.json`, and Keycloak is reachable over HTTP on localhost (no certificate required for dev) — AR1, AR3

**Given** the realm export and any config files
**When** they are committed
**Then** **all secrets are stripped** from `realm-export.json`, the `lefthook` + `gitleaks` pre-commit hook blocks any secret (real or test), CI also runs `gitleaks`, and `.env`/`master.key`/Kamal secrets are gitignored (only `.env.example` with placeholders is committed) — AR8

### Story 1.2: Realm OIDC client configuration (Auth Code + PKCE only)

As an integrated application,
I want a conformant Keycloak OIDC client,
So that I can authenticate users via the standard Authorization Code + PKCE flow and nothing weaker.

**Acceptance Criteria:**

**Given** the `envocc` realm
**When** an OIDC client is configured
**Then** only the **Standard flow (Authorization Code)** is enabled with **PKCE `S256` required**; **Implicit and Direct-Grant/ROPC are disabled**; **`validRedirectUris` are exact** (no wildcard/substring); and `.well-known/openid-configuration` returns valid metadata (FR1, FR3, FR4, FR11)

**Given** an authorization request
**When** it is processed
**Then** authorization codes are single-use and replay-detected, PKCE verifier binding is enforced server-side, and `nonce` is verified once — all by Keycloak (FR6, FR47)

### Story 1.3: Realm keys & token issuance

As the System,
I want Keycloak realm keys and short-lived signed tokens,
So that clients can validate identity tokens and master signing material is rotatable and recoverable.

**Acceptance Criteria:**

**Given** the realm key providers
**When** the JWKS endpoint is queried
**Then** Keycloak publishes RS256 public key(s) with a `kid`, `alg:none` is rejected, and an **active/passive key overlap ≥ the max token lifetime** is configured for rotation (FR5, NFR3)

**Given** a completed authentication
**When** tokens are issued
**Then** access/ID tokens have a **≤15-minute** lifetime, refresh-token **rotation with reuse-revocation** is enabled, and the token carries the agreed claims (NFR2a, FR9)

**Given** the realm configuration and keys
**Then** they are recoverable via **realm export + database backup** (no Vault) — AR4

### Story 1.4: Sessions, brute-force, password policy & enumeration resistance

As an active staff member,
I want sane session limits, lockout protection, a modern password policy, and no account-existence leaks,
So that my account is protected without footguns.

**Acceptance Criteria:**

**Given** realm session settings
**Then** **idle and absolute SSO session lifetimes** are enforced (re-auth on expiry), **RP-initiated logout** terminates the session and honors a validated post-logout redirect, and the **session id is regenerated on every auth-state transition** (FR7, FR8, FR10, FR45)

**Given** the realm password policy
**Then** it requires **min length ≥12**, allows long passphrases, **screens against a breached-password blacklist (HIBP list)**, and imposes **no composition rules or forced rotation** (FR18, NFR7)

**Given** repeated failed logins or OTP attempts
**Then** Keycloak **per-account brute-force** applies progressive `wait` (per-IP throttling added at Nginx in Epic 6) and responses are **generic / enumeration-resistant** (FR19, FR20)

### Story 1.5: Canonical identity model & work-email claim

As the System,
I want a Keycloak user model with a stable subject and a work-email reconciliation claim,
So that each staff member is one authoritative identity that integrating apps can match on.

**Acceptance Criteria:**

**Given** Keycloak users
**Then** each has a **stable, never-reused `sub`** (Keycloak user id) as the system-of-record identifier, a **UNIQUE work email**, and a **minimal User Profile** (no PDPA §26 sensitive attributes) — FR21, FR22 *(uniqueness)*, FR23

**Given** the realm client scopes
**When** an ID token is issued
**Then** a **protocol mapper emits the work-email reconciliation key** as a claim (FR22)

**Given** the lifecycle model
**Then** **pending** = outstanding required actions (`UPDATE_PASSWORD`, `CONFIGURE_TOTP`, `VERIFY_EMAIL`) + `emailVerified=false`; **active** = cleared; **disabled** = `enabled=false` — the controlled transitions for FR24 (transitions exercised in Epics 2–3)

### Story 1.6: Sign-in + verification-code (TOTP) flow

As an active staff member,
I want to sign in with my email + password and then my authenticator code,
So that my sign-in is protected by a second factor.

**Acceptance Criteria:**

**Given** a seeded **active** fixture user (credentials generated at runtime, never committed)
**When** they submit a correct email + password on the Keycloak-hosted login
**Then** the password is verified (Keycloak Argon2id) and a Keycloak session is created with host-prefixed Secure/HttpOnly/SameSite cookies (FR2, NFR1, NFR4)

**Given** a user with an enrolled authenticator
**When** they enter a 6-digit code
**Then** Keycloak's **OTP policy** verifies it with a **bounded drift window**, **single-use per time step**, and **rate-limiting** (FR14); an invalid/replayed code is denied generically and throttled

### Story 1.7: Reference client proving end-to-end SSO

As a developer,
I want a minimal connected app that signs in through Keycloak,
So that the SSO core is verifiably working end-to-end.

**Acceptance Criteria:**

**Given** a tiny relying-party app registered as a Keycloak OIDC client
**When** the fixture user signs in through envocc-sso
**Then** the app receives and validates the ID token (signature via JWKS, `iss`/`aud`/`exp`/`nonce`) and shows the signed-in identity including the **work-email claim** (proves FR1–FR11 end-to-end; seeds FR43)

### Story 1.8: Keycloak event capture enabled

As the System Administrator,
I want Keycloak login and admin events recording from day one,
So that there is an audit trail foundation before any real data flows.

**Acceptance Criteria:**

**Given** the realm event settings
**Then** **login events and admin events are enabled** with a retention period set, capturing auth outcomes, session lifecycle, and admin actions with source IP/UA — the capture foundation for FR35/FR37 (off-host shipping + the unified console come in Epic 5)

## Epic 2: Ministry Bronze Theme, Staff Experience & Recovery

Build the custom Keycloak theme from DESIGN.md and wire the staff auth flows: branded login, first-login activation, MFA enrollment, and self-service reset — accessible and bilingual.

### Story 2.1: Ministry Bronze Keycloak theme

As a non-technical staff member,
I want the login experience to look unmistakably official and on-brand,
So that I can trust it is the real login and not a phishing page.

**Acceptance Criteria:**

**Given** DESIGN.md tokens
**When** the custom Keycloak **login theme** (`ministry-bronze`) is built
**Then** sign-in, verification-code, forgot-password, email-sent, reset, activate, re-activation, signed-out, and error pages render with the navy `#1B3354` / bronze `#A9711B` palette, Noto Serif/Sans (+ Thai) fonts, the branded shell/wordmark, and the standing **anti-phishing banner** — light mode only, **WCAG 2.1 AA**, rendered **top-level only** with CSP `frame-ancestors 'none'` (FR12, NFR4, UX-DR1–UX-DR4, UX-DR9, UX-DR10)

### Story 2.2: Bilingual localization (en + th)

As a non-technical Thai-speaking staff member,
I want the safety-critical messages available in Thai,
So that I understand the anti-phishing guidance.

**Acceptance Criteria:**

**Given** the theme `messages_en.properties` + `messages_th.properties` and the realm `th` locale enabled
**When** the app builds
**Then** **all theme copy is externalized message keys** (no hard-coded text), and the **security-critical strings** (activation, reset, MFA enrollment, "don't share this link", security-event notices) are **translated to Thai first**, even while the rest stays English-first (FR12, NFR19, UX-DR11)

### Story 2.3: First-login activation (set password + enroll MFA)

As a new hire,
I want to activate my account from an emailed link, set my own password, and enroll my authenticator,
So that I can access my account, protected by MFA, without anyone else knowing my password.

**Acceptance Criteria:**

**Given** an account created in **pending** (required actions `UPDATE_PASSWORD` + `CONFIGURE_TOTP`, `emailVerified=false`)
**When** the activation email is sent (Keycloak `execute-actions-email`)
**Then** it contains a **single-use, time-limited (≤~20 min)** action link with prominent anti-phishing copy, and the token is stored hashed by Keycloak (FR16, NFR2)

**Given** a valid activation link
**When** the user sets a password and enrolls TOTP
**Then** the password is accepted only if **≥12 chars and not breached** (no composition rules — FR18); a TOTP secret is offered as **QR + manual key** with plain-language guidance and confirmed by a valid code (FR13, UX-DR12); the TOTP secret is encrypted at rest (NFR2); the account moves **pending → active** (FR24) and the user is **alerted**

### Story 2.4: Self-service password reset

As a staff member who forgot my password,
I want to reset it by email,
So that I can regain access without contacting an administrator.

**Acceptance Criteria:**

**Given** the Keycloak forgot-password flow
**When** I submit my email
**Then** the response is **identical whether or not the account exists** (FR20), and if it exists a **single-use, short-lived** reset link is emailed

**Given** a valid reset link
**When** I set a new password
**Then** the policy (FR18) applies, **MFA enrollment is NOT cleared**, all my **other sessions + outstanding tokens are invalidated**, and I am alerted ("you've been signed out everywhere else") (FR17, FR48)

### Story 2.5: Email/action-token hygiene & pending-account expiry

As the System,
I want strict lifecycle rules on Keycloak action tokens and pending accounts,
So that stale or duplicate links cannot be abused.

**Acceptance Criteria:**

**Given** Keycloak action-token lifespans
**Then** issuing a new activation/reset token **invalidates the prior one**, completing an action **invalidates other sessions + outstanding tokens**, and **pending accounts expire** after a bounded window and require a re-issued link (FR48)

**Given** the reset/activation request endpoints
**Then** requests are **rate-limited per-account and per-IP** (Keycloak + Nginx) (FR48, FR19)

## Epic 3: Rails HR Admin Console (Employee Lifecycle)

A Rails app — admins signed in via Keycloak, role-gated to HR — provisions and offboards staff over the Keycloak Admin REST API, with hardened resets and CSV import.

### Story 3.1: Rails app, Keycloak-OIDC login, role gate & Admin-API adapter

As an administrator,
I want a single branded Rails admin app I sign into via Keycloak that shows only my role's section,
So that separation of duties is enforced by the interface and all Keycloak actions go through one tested adapter.

**Acceptance Criteria:**

**Given** the Rails app
**When** I sign in
**Then** authentication is delegated to **Keycloak via OIDC** (no local passwords), and the **role gate** renders only the signed-in role's section — an `HR_ADMIN` sees only the HR section (the System section is neither rendered nor reachable), enforced server-side (FR33-support, UX-DR5)

**Given** the `app/services/keycloak` adapter
**Then** all user/client/role/event operations go through this **thin Admin REST API adapter** (typed responses, error mapping, retries), the **Keycloak version is pinned**, and an integration test exercises it against a running Keycloak (AR3, R11)

**Given** DESIGN.md tokens
**Then** the Rails shell/header/wordmark + components are styled **Ministry Bronze via Tailwind**, WCAG 2.1 AA (UX-DR1, UX-DR6, UX-DR10)

### Story 3.2: Create & search users

As an HR Administrator,
I want to create staff accounts and find existing ones,
So that I can onboard people and manage the roster.

**Acceptance Criteria:**

**Given** the HR console
**When** I create a user with name + work email
**Then** the Rails app calls the Admin API to create a **pending** user (required actions set) and triggers the **activation email** (FR26)

**Given** the user list
**When** I search
**Then** I can find users (Admin API query) and see each one's **lifecycle state**; the list handles loading/empty/error states (FR27, UX-DR8)

### Story 3.3: Enable / disable with immediate revocation

As an HR Administrator,
I want to disable a leaver in one action,
So that they immediately lose access everywhere.

**Acceptance Criteria:**

**Given** an active account
**When** I disable it
**Then** the Rails app sets **`enabled=false`**, **logs the user out of all sessions**, and **revokes outstanding refresh-token families** via the Admin API, blocking all new authentication immediately; the action is audited (FR25, FR28, FR46)

**Given** a disabled account
**When** I re-enable it
**Then** it can authenticate again per its lifecycle state

### Story 3.4: Hardened admin password & MFA reset

As an HR Administrator,
I want to reset a user's password or MFA only after verifying who they are,
So that the reset power can't be abused by a phisher.

**Acceptance Criteria:**

**Given** a reset request
**When** I perform an admin password or MFA reset
**Then** I must complete and **attest to a documented out-of-band identity check** (recorded in the Rails audit), the **affected user is notified**, and the action is **rate-limited with an abuse alert** (FR15, FR29, FR44)

**Given** an admin MFA reset
**Then** the Rails app removes the OTP credential and sets required actions via the Admin API (`execute-actions-email` with `UPDATE_PASSWORD` + `CONFIGURE_TOTP`), returning the account to **pending re-activation** — never a "password known, MFA cleared" state (FR44)

### Story 3.5: CSV bulk import

As an HR Administrator,
I want to import a roster by CSV,
So that I can seed many accounts at once safely.

**Acceptance Criteria:**

**Given** a CSV upload
**When** it is processed
**Then** Rails **validates, de-duplicates against existing Keycloak identities, sanitizes against CSV/formula injection, and caps the size**, with a **preview/confirm step** before any account is created (FR30, FR49)

**Given** a confirmed import
**Then** pending accounts are batch-created via the Admin API and activation emails dispatched **with throttling** (FR49, NFR16)

### Story 3.6: Profile edit with controlled email-key change

As an HR Administrator,
I want to correct a user's details,
So that records stay accurate — while protecting the reconciliation key.

**Acceptance Criteria:**

**Given** a user record
**When** I edit minimal attributes (e.g., name)
**Then** the change is saved via the Admin API and audited (FR31)

**Given** a change to the work-email (reconciliation key)
**Then** it is a **controlled action** with an explicit confirmation warning about reconciliation impact (FR31)

## Epic 4: Rails System Admin Console & App Onboarding

The Rails System section connects internal apps as Keycloak OIDC clients and manages admin users + realm roles, with step-up re-auth.

### Story 4.1: System section, step-up re-auth & CSRF

As a System Administrator,
I want sensitive actions to require a fresh re-auth,
So that a hijacked session can't silently perform high-impact changes.

**Acceptance Criteria:**

**Given** the System section of the Rails app
**When** I attempt a sensitive action (register client, manage admins, trigger reset)
**Then** a **step-up re-authentication** is required (Keycloak `max_age`/`prompt=login` or `acr`), forms carry **CSRF protection**, and the section is visible only to `SYSTEM_ADMIN` (FR50, UX-DR7)

### Story 4.2: Register & manage OIDC clients

As a System Administrator,
I want to register internal apps as Keycloak OIDC clients,
So that they can use envocc-sso for sign-on.

**Acceptance Criteria:**

**Given** the client registry (Rails over the Admin API)
**When** I register a client
**Then** I set **exact-match redirect URIs, allowed scopes**, and a client-auth method — **`private_key_jwt` preferred** (Signed JWT with the client's JWKS) (FR4, FR32)

**Given** an existing client
**When** I rotate its credentials
**Then** rotation uses an **overlap window** (`private_key_jwt` key rotation, or coordinated `client_secret` rotation) so a live app migrates without downtime, and all changes are audited (FR32)

### Story 4.3: Admin-user & realm-role management (separation of duties)

As a System Administrator,
I want to create and disable admin users and assign roles,
So that the right people have the right access, separated by duty.

**Acceptance Criteria:**

**Given** admin-user management (Rails over the Admin API)
**When** I create or disable an HR or System Admin and assign a **realm role** (`HR_ADMIN` / `SYSTEM_ADMIN`)
**Then** the assignment is enforced (an HR Admin can never see System functions and vice versa) and every change is audited (FR33)

## Epic 5: Audit, Compliance & Oversight

Keycloak events + Rails-side audit are shipped tamper-evidently off-host, reviewable and exportable in Rails, with PDPA retention and second-person oversight.

### Story 5.1: Complete audit-event capture

As the System Administrator,
I want every relevant event captured,
So that an incident can be fully reconstructed.

**Acceptance Criteria:**

**Given** Keycloak events (Epic 1) + Rails-side audit
**When** any admin action, session-lifecycle event, or token/key event occurs
**Then** it is recorded — Keycloak's native events for IdP-internal actions, and the Rails **`{actor, action, target, timestamp, source, outcome}`** schema for Rails admin actions — **distinguishing throttled vs failed logins** (FR35, FR36, FR37)

### Story 5.2: Off-host WORM shipping & integrity

As a compliance reviewer,
I want the audit trail stored where the operator can't rewrite it,
So that the record is trustworthy even though the system is solo-run.

**Acceptance Criteria:**

**Given** the Keycloak **Event Listener SPI** and the Rails audit
**When** events are produced
**Then** they are shipped to a **separate off-host append-only/WORM sink** the application/operator cannot edit, integrity-verifiable on export (FR38 — hash-chain relaxed to append-only/WORM per the pivot, C2/C3)

### Story 5.3: Audit console — view & export (Rails)

As a System Administrator,
I want to review and export the audit log,
So that I can investigate and respond to incidents.

**Acceptance Criteria:**

**Given** the Rails audit console (reads Keycloak events via the Admin API + Rails audit)
**When** I view/filter entries and export them
**Then** results contain **no credentials/secrets/tokens** and don't leak account existence, and **the read/export action is itself audited** (FR34, FR39)

### Story 5.4: Retention & second-person oversight

As a Data Protection Officer,
I want audit retention and an independent copy of the log,
So that oversight doesn't depend solely on the builder.

**Acceptance Criteria:**

**Given** the off-host sink + Keycloak event retention
**Then** entries are retained for **12 months** (NFR14, FR38)

**Given** a schedule
**When** it fires
**Then** an **out-of-band copy** of the log is delivered to a **named second person** (DPO/manager) (FR39)

**Given** a PDPA erasure request
**Then** identity PII not held under a legal-obligation basis is erased/pseudonymized, and the **subject reference in retained events/audit rows is pseudonymized rather than deleted** (NFR14)

### Story 5.5: PDPA compliance artifacts

As a Data Protection Officer,
I want the required PDPA documentation and breach process in place,
So that the pilot can lawfully process real staff data.

**Acceptance Criteria:**

**Given** the pilot gate
**Then** a **Record of Processing Activities** (covering Keycloak + Rails), the documented lawful basis, the data-subject-right dispositions, and a **tested 72-hour breach-response runbook** exist with a named owner — completed **before the pilot processes real staff data** (NFR11, NFR13, NFR14, NFR15)

## Epic 6: Integration Enablement & Production Hardening

App owners self-integrate as Keycloak clients via a guide + reference client; the system is deployed (Kamal + managed containers), edge-protected, monitored, backed up, and CI-gated — ready for the independent review and pilot.

### Story 6.1: OIDC integration guide

As an app owner,
I want a clear integration guide,
So that I can connect my app as a Keycloak client without deep auth expertise.

**Acceptance Criteria:**

**Given** the published guide
**Then** it documents **registering a Keycloak OIDC client**, the discovery endpoint, Authorization Code + PKCE, redirect-URI registration, ID-token/JWKS validation (`iss`/`aud`/`exp`/`nonce`/`azp`), the requirement to **bound the RP's local session to the IdP token lifetime** and honor `kid` with a bounded JWKS cache TTL, and the **claim contract** (stable `sub` + work-email key, and how to map it to a local account) (FR40, FR41, FR42)

### Story 6.2: Polished reference client

As an app owner,
I want a copyable working example,
So that I can model my integration on something proven.

**Acceptance Criteria:**

**Given** the reference client (productionized from the Epic-1 client)
**When** I follow the guide with it
**Then** it demonstrates the full Keycloak-client contract end-to-end and is documented as the adoption asset (FR43)

### Story 6.3: Nginx edge & abuse protection

As the System,
I want a hardened reverse proxy fronting Keycloak and Rails,
So that public endpoints are protected and traffic is terminated securely.

**Acceptance Criteria:**

**Given** Nginx as the single public edge
**Then** it terminates TLS with an **internal-CA (or self-signed) certificate** + HSTS, sets the required security headers, **rate-limits the public endpoints per-IP** (Keycloak authorize/token/reset/activation + Rails), enforces request-size caps, and keeps Keycloak **JWKS/discovery cacheable** — routing auth paths → Keycloak and `/` → the Rails backend (FR50, FR19 per-IP, NFR4, NFR17)

### Story 6.4: Kamal deploy + managed Keycloak/Postgres + tested backups

As the operator,
I want reproducible deployment and proven backups,
So that the single on-prem instance is recoverable.

**Acceptance Criteria:**

**Given** the Rails app
**When** it is deployed with **Kamal** (zero-downtime via `kamal-proxy`, behind Nginx)
**Then** migrations run on release and secrets come from Kamal/Rails encrypted credentials (never committed); **Keycloak + Postgres run as pinned managed containers** with the realm imported on boot (AR6)

**Given** the backup process
**Then** nightly off-site backups of **Keycloak Postgres + realm export/keys + the Rails DB** run, a **restore is tested**, and RTO/RPO are stated (NFR17)

### Story 6.5: CI security gates + monitoring

As the operator,
I want automated quality/security gates and operational visibility,
So that regressions and outages are caught.

**Acceptance Criteria:**

**Given** the CI pipeline
**Then** `gitleaks`, `rubocop`, **`brakeman` (SAST)**, **`bundler-audit` (dep-scan)**, RSpec/system tests **against a running Keycloak**, and a **realm-config lint** all run and a failure blocks the build (AR7, NFR9)

**Given** the running system
**Then** uptime + error alerting, **Keycloak health/metrics**, and **SMTP deliverability monitoring** are in place (AR9, NFR16)

### Story 6.6: Pre-pilot assurance

As the project sponsor,
I want independent security validation before real data flows,
So that going live isn't gated only on self-review.

**Acceptance Criteria:**

**Given** the pilot gate
**Then** an **independent review of the Keycloak configuration + Rails layer** (OWASP ASVS L2 on the custom surface) is completed before the pilot, an **independent penetration test** is scheduled before broad rollout, all FG-8 operational controls are verified, and the **named second person + pilot apps (OQ1/OQ3)** are confirmed (NFR10, AR10)
