---
stepsCompleted: [1, 2, 3, 4]
status: final
completedAt: '2026-06-22'
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-21/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/EXPERIENCE.md
  - _bmad-output/planning-artifacts/briefs/brief-envocc-sso-2026-06-19/brief.md
project_name: envocc-sso
user_name: Rawinan
---

# envocc-sso - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for envocc-sso, decomposing the requirements from the PRD, UX Design, and Architecture into implementable stories.

## Change Note — Two Login Methods (2026-06-22)

**Decision (user, 2026-06-22):** staff may sign in by **(1) email + password + TOTP MFA** *or* **(2) Login with ThaiD** (Keycloak brokers the ThaiD OIDC IdP). Both resolve to the same canonical Keycloak identity and emit the same claims; **Keycloak remains the IdP** — apps still see only Keycloak. The password+TOTP path is the always-available baseline (works in dev/CI with no external service, and is the DOPA-down fallback); ThaiD is an opt-in alternative **linked by national ID (PID)** captured at account creation.

**How ThaiD is built:** native **Keycloak identity brokering** — ThaiD configured as an external OIDC Identity Provider in realm config-as-code, with a first-broker-login flow for PID linking. **No custom auth code** (NFR8-aligned). Dev/CI point the broker at a **mock OIDC IdP**.

**Effect:** the original TOTP design stands (FR13/FR14, password policy, reset, MFA reset). Adds **FR13a** and **Story 2.9** (Login with ThaiD). HR create + CSV now capture **national ID (PID)** (FR23/FR26/FR30). **Open with DOPA:** RP onboarding for "Login with ThaiD" and the claims it asserts (esp. PID), alongside OQ1/OQ3/OQ4.

## Requirements Inventory

### Functional Requirements

**FG-1 — Login & SSO (core)**
- FR1: Authenticate staff using OIDC Authorization Code flow with PKCE for all client applications.
- FR2: Host the login experience itself; user credentials MUST never transit relying-party applications.
- FR3: MUST NOT offer Implicit or Resource Owner Password Credentials (ROPC) grant types.
- FR4: Each client registers redirect URIs; enforce exact-match redirect URIs (no wildcard/substring).
- FR5: On success, issue an asymmetrically-signed ID token with agreed claims (incl. work-email reconciliation key); publish signing keys via JWKS endpoint (with `kid`).
- FR6: Bind each authentication request to its session using `state` (CSRF) and `nonce` (ID-token replay protection).
- FR7: Establish a single sign-on session so an authenticated staff member reaches every integrated app without re-entering credentials, until the session ends.
- FR8: Enforce both idle and absolute session lifetimes; require re-authentication when either expires.
- FR9: Issue short-lived tokens; where refresh tokens are issued, rotate on use with reuse-detection that revokes the token family on replay.
- FR10: Support RP-initiated logout — terminate the session and honor a validated post-logout redirect.
- FR11: Expose a standard OIDC discovery document (`.well-known`) so clients self-configure.

**FG-2 — Staff Authentication Experience**
- FR12: Present a branded login (anti-phishing trust signal), top-level (never framed), with standing plain-language anti-phishing guidance; all UI copy externalized, English-first, localization-ready.
- FR13: Enforce MFA via TOTP for staff authenticating with email + password; users enroll a TOTP authenticator during first-login activation.
- FR13a: Also offer "Login with ThaiD" as an alternative authentication method via brokered federation (Keycloak brokers the ThaiD OIDC IdP; Keycloak remains the IdP). On first use, link ThaiD to the canonical account by national ID (PID). Both methods resolve to the same identity/tokens. Dev/CI use a mock OIDC IdP.
- FR14: Verify TOTP with bounded clock-drift window, rate-limit verification, treat verified code as single-use within its time step.
- FR15: Allow an administrator to reset a user's MFA enrollment (admin-assisted recovery, subject to FG-8); user re-enrolls on next sign-in.
- FR16: First-login activation — admin-created account starts pending; user gets single-use, time-limited activation link and, on first sign-in, sets own password and enrolls MFA; alerts the user; token-hygiene per FG-8/NFR2.
- FR17: Self-service password reset by email using single-use, short-lived, high-entropy token; MUST NOT clear MFA; alerts user on completion; subject to FG-8.
- FR18: Password policy — minimum length ≥ 12, support passphrases, screen against known-breached lists, NO composition rules or forced rotation.
- FR19: Brute-force protection on login and TOTP via progressive delays, per-account and per-IP.
- FR20: Login, activation, reset flows enumeration-resistant — identical generic responses regardless of account existence.

**FG-3 — Identity & User Store (system of record)**
- FR21: Maintain exactly one canonical identity per staff member, identified by a stable internal subject identifier (never reused).
- FR22: Each identity carries a unique work email = reconciliation key, emitted as a claim to integrating apps.
- FR23: Store only the minimal attribute set required (data minimization); MUST NOT store PDPA §26 sensitive personal data.
- FR24: Each identity has a defined lifecycle state — pending activation → active → disabled — with controlled transitions.
- FR25: Disabling an account immediately blocks all new authentication across every integrated app and triggers server-side revocation (FG-8); residual local-session window named/accepted.

**FG-4 — HR Admin Console (employee lifecycle)**
- FR26: HR Admin can create a user (name + work email), placing account in pending and sending the activation email (FR16).
- FR27: HR Admin can search/list users and view each account's lifecycle state.
- FR28: HR Admin can enable or disable an account (joiner/mover/leaver); disable behaves per FR25 + FG-8 revocation.
- FR29: HR Admin can trigger a password reset and reset MFA enrollment as front-line support, subject to FG-8.
- FR30: HR Admin can bulk-create pending accounts via CSV import, subject to FG-8 import validation.
- FR31: HR Admin can correct minimal profile attributes; changing the reconciliation key (work email) is a controlled, flagged action.

**FG-5 — System Admin Console (service administration)**
- FR32: System Admin can register/manage OIDC client applications — credentials, exact-match redirect URIs (FR4), allowed scopes — and rotate a client secret with a dual-secret overlap window.
- FR33: System Admin can manage admin users — create/disable HR Admins and System Admins and assign roles — enforcing two-role separation of duties.
- FR34: System Admin can view and export the audit log (FG-6); every read/export of the audit log MUST itself be audited.

**FG-6 — Audit Logging (compliance)**
- FR35: Record authentication events (login success/failure, MFA outcome, session create/terminate/expiry, logout, activation, reset) with source IP and user-agent/device.
- FR36: Record administrative actions (user create/enable/disable, password/MFA reset with FR44 attestation, profile change, client registration/secret rotation, signing-key rotation, admin-user changes).
- FR37: Record token & key events (issuance, refresh-rotation, reuse-detection trips, JWKS/signing-key rotation) sufficient to scope incident blast radius.
- FR38: Audit log append-only and integrity-verifiable, shipped off-host to operator-unrewritable storage, retained 12 months.
- FR39: Audit log MUST NOT store credentials/MFA secrets/token values, MUST not leak account existence; scheduled out-of-band copy delivered to a named second person.

**FG-7 — App-Owner Integration Enablement**
- FR40: Publish an OIDC integration guide enabling app owners to integrate using standard OIDC libraries; reference client (FR43) is the testable artifact.
- FR41: Guide documents the full integration contract — discovery, Auth Code+PKCE, redirect-URI registration, ID-token/JWKS validation (iss/aud/exp/nonce/azp), require bounding local session to token lifetime, honor `kid` with bounded JWKS cache TTL.
- FR42: Guide documents the identity-claim contract — stable subject + reconciliation key (work email) — and how an app maps an SSO identity to its existing local account.
- FR43: Provide a minimal reference/sample client (the documented pilot integration) demonstrating the contract end-to-end.

**FG-8 — Operational Security & Account-Protection Controls**
- FR44: Admin-initiated MFA/password reset requires a documented out-of-band identity-verification step attested in the audit record; notify the affected user; MFA reset returns account to pending re-activation; rate-limited with abuse alert.
- FR45: Regenerate the session identifier on every authentication-state transition; keep server-side session records; pin session cookies host-prefixed Secure/HttpOnly/SameSite.
- FR46: Disabling an account immediately revokes all outstanding refresh-token families and invalidates all server-side sessions; System Admin can force-terminate active sessions.
- FR47: Authorization codes single-use, short-lived, replay-detected; PKCE verifier binding enforced server-side; `nonce` verified exactly once.
- FR48: Issuing a new activation/reset token invalidates prior outstanding token; completing activation/reset invalidates all other active sessions and outstanding tokens; requests rate-limited per-account and per-IP; pending accounts expire after a bounded window.
- FR49: CSV bulk import validates/de-duplicates rows against existing identities, enforces a per-import size cap, throttles activation-email dispatch, sanitizes against CSV/formula injection, presents a preview/confirm step.
- FR50: Public unauthenticated endpoints protected by edge rate-limiting/abuse controls; JWKS and discovery cacheable; admin-console actions carry CSRF protection + step-up re-auth for sensitive operations.

### NonFunctional Requirements

**A. Cryptography & Credential Custody**
- NFR1: Passwords hashed with memory-hard algorithm (Argon2id-class) at OWASP params, unique salt, encryption-at-rest, restricted network-isolated datastore access.
- NFR2: MFA (TOTP) secrets encrypted at rest; the ThaiD broker link reference (FR13a) also encrypted at rest; email activation/reset tokens stored hashed, single-use, short-lived (≤ ~20 min), ≥ 128-bit entropy.
- NFR2a: Token-lifetime ceiling — access/ID tokens hard maximum ≤ 15 minutes.
- NFR3: Token signing uses asymmetric keys (RS256-class), published via JWKS with `kid`, rotated with active/passive overlap ≥ max token lifetime; `alg:none` rejected; signing keys recoverable via tested backup; key custody hardened.
- NFR4: All transport over TLS (HSTS); session cookies host-prefixed Secure/HttpOnly/SameSite; login UI sets CSP including `frame-ancestors 'none'` plus standard security headers.

**B. Standards Conformance & Independent Validation**
- NFR5: Conform to OAuth 2.0 Security BCP (RFC 9700) and OpenID Connect Core security requirements.
- NFR6: Built/verified to OWASP ASVS Level 2 (L3 for credential/key handling); ASVS L2 checklist independently reviewed by a second qualified person before the pilot.
- NFR7: Password policy per NIST SP 800-63B; brute-force protection per-account and per-IP via progressive delays (FR19).
- NFR8: No hand-rolled crypto, token, or session logic anywhere; use only established, maintained, audited components/libraries.
- NFR9: CI pipeline includes dependency/vulnerability scanning + SAST + secret scanning.
- NFR10: HARD GATES — independent review of the ASVS L2 checklist REQUIRED before the pilot; independent penetration test REQUIRED before broad rollout.

**C. Privacy & Compliance (PDPA)**
- NFR11: Lawful basis = contractual necessity / legal obligation / legitimate interest (NOT consent), documented per purpose in a RoPA; accountable owner named.
- NFR12: No PDPA §26 sensitive personal data stored.
- NFR13: Data minimization; encryption at rest for credentials/secrets; least-privilege admin access.
- NFR14: Retention & erasure — audit logs 12 months; identity records for employment duration; on erasure request, non-legal-obligation PII erased/pseudonymized, audit-row data-subject reference pseudonymized not deleted; data-subject rights disposition stated.
- NFR15: HARD GATE — completed RoPA, lawful-basis docs, DPO sign-off, tested 72-hour breach-response runbook are GATES before the pilot processes real staff data; named owner + date tied to pilot go-live.

**D. Reliability & Operations**
- NFR16: SMTP is a monitored critical-path dependency (retries, monitoring, bounce handling); admin-initiated reset is the fallback when self-service email fails.
- NFR17: Service is a single point of dependency; target 24/7 availability, planned maintenance in brief announced windows; edge DoS/abuse protection; resilient deployment + tested backup/restore of identity/credential store, signing keys, config, admin data; stated RTO/RPO; key-loss/compromise runbook; single instance to start, HA deferred.

**E. Scale, Performance & Localization**
- NFR18: Sized for ~100–150 staff + pilot apps; target login/token-issuance latency p95 ≤ 500 ms; not a high-scale system.
- NFR19: English-first UI, structured for localization (externalized strings, FR12); Thai translation handled by owner after UI stabilizes.

### Additional Requirements

(From Architecture — implementation decisions that shape epics/stories.)

- AR1: Foundation / "starter" = on-prem Docker Compose stack — pinned Keycloak 26.6.x + PostgreSQL + single Nginx security edge; realm config-as-code (exported JSON in git, secrets stripped). **This is Epic 1, Story 1.**
- AR2: Self-hosted Keycloak is the IdP engine — FG-1/FG-3/FG-8 are realm configuration, not custom code (NFR8: audited engine, no hand-rolled crypto).
- AR3: Admin layer = SvelteKit (Svelte 5 / TypeScript) on the Bun runtime, `adapter-node`, over the Keycloak Admin REST API.
- AR4: Two separate PostgreSQL databases — Keycloak store (identities/credentials/TOTP-secrets/ThaiD-broker-link/sessions) vs admin DB (app sessions + app-side audit + CSV staging only; NO canonical identities; user reference = Keycloak `sub` UUID only).
- AR5: Drizzle ORM + drizzle-kit migrations; Valibot validation at every server boundary; thin typed Keycloak Admin REST adapter integration-tested against a live Keycloak in CI (R11 — the single coupling point).
- AR6: Admin sign-in via OIDC Auth Code + PKCE (`openid-client`); DB-backed server-side sessions (`__Host-` cookies, regenerate on auth-state transition); realm-role gating (`hr-admin`, `system-admin`) in `hooks.server.ts`; `max_age=0` step-up re-auth for sensitive ops.
- AR7: Audit pipeline = Keycloak Event Listener SPI + admin-app events → off-host append-only/WORM sink (12-month retention; audit reads/exports themselves audited). WORM-sink product deferred.
- AR8: Agentic-build / CI gate (standing layer on EVERY story) — Prettier · ESLint · tsc/svelte-check · Semgrep (SAST) · gitleaks · bun audit · Vitest/Playwright · Keycloak realm-config lint.

### UX Design Requirements

- UX-DR1: Shared Deep Sea design-token stylesheet (`design-tokens/deep-sea.css`) imported by both the Keycloak theme and the admin app (visual parity via shared CSS variables, no shared framework). Light-mode only, WCAG AA palette.
- UX-DR2: Native Keycloak theme (login / account / email templates) styled with Deep Sea tokens — top-level-only, externalized strings (English-first, Thai-ready), no JS framework in the login path.
- UX-DR3: Nine staff-auth surfaces — Sign in, Verification code (MFA), Forgot password, Email-sent confirmation, Reset password, Activate account, Re-activation (after admin MFA reset), Signed out, Auth error / invalid-link.
- UX-DR4: Four HR admin surfaces — User list/search, Create user, User detail (enable/disable, reset password, reset MFA, edit profile), CSV import (upload → preview → confirm).
- UX-DR5: Four System admin surfaces — Client/app list, Register/edit client, Admin users, Audit log.
- UX-DR6: Themed shadcn-svelte component set (Tailwind v4, light-mode, rethemed to Deep Sea) — code-input (6-digit TOTP), Login-with-ThaiD button (secondary, on Sign in), data-table (user list, pagination), status-pill (text+icon+dot), 4-state alert, modal/step-up-dialog, file-upload + csv-preview-table (clean/invalid/duplicate marking).
- UX-DR7: Anti-phishing banner — pinned, non-dismissible, full-contrast info alert on Sign in and Verification code surfaces.
- UX-DR8: WCAG 2.1 AA floor across every surface — keyboard-complete with always-visible focus ring, persistent visible labels (never placeholder-only), aria-associated field errors, status by text+icon (never color alone), 6-digit code as one labeled group, 200% zoom/reflow.
- UX-DR9: Enumeration-safe, plain-language voice — identical generic copy + timing across sign-in/activation/reset; name the thing not the protocol ("verification code" not "TOTP"; "Login with ThaiD" not "OIDC broker"); standing anti-phishing line; "don't share this link" in every activation/reset email.
- UX-DR10: Role-gated single shell — HR and System sections never shown together (separation of duties enforced in navigation); lists paginate (never infinite-scroll); one primary action per surface.

### FR Coverage Map

- FR1: Epic 2 — OIDC Authorization Code + PKCE
- FR2: Epic 2 — hosted login; credentials never transit RPs
- FR3: Epic 2 — no Implicit / ROPC grants
- FR4: Epic 2 — exact-match redirect URI enforcement (registration UI in Epic 5/FR32)
- FR5: Epic 2 — signed ID token + JWKS (`kid`)
- FR6: Epic 2 — `state` + `nonce` binding
- FR7: Epic 2 — single sign-on session
- FR8: Epic 2 — idle + absolute session lifetimes
- FR9: Epic 2 — short-lived tokens / refresh rotation + reuse-detection
- FR10: Epic 2 — RP-initiated logout
- FR11: Epic 2 — OIDC discovery document
- FR12: Epic 2 — branded top-level anti-phishing login + externalized strings
- FR13: Epic 2 — TOTP MFA enforcement (enrollment at activation in Epic 3)
- FR13a: Epic 2 — Login with ThaiD (brokered federation + PID account linking)
- FR14: Epic 2 — TOTP verify hardening (drift window, rate-limit, single-use)
- FR15: Epic 3 — MFA reset re-enrollment flow (admin trigger in Epic 4/FR29)
- FR16: Epic 3 — first-login activation
- FR17: Epic 3 — self-service password reset
- FR18: Epic 3 — password policy (≥12, breach-screened)
- FR19: Epic 2 — brute-force protection (login + TOTP)
- FR20: Epic 2 — enumeration resistance (applied in Epic 3 flows too)
- FR21: Epic 2 — one canonical identity + stable subject
- FR22: Epic 2 — unique work-email reconciliation key claim
- FR23: Epic 2 — minimal attribute set (no §26 data)
- FR24: Epic 2 — lifecycle states (pending→active→disabled)
- FR25: Epic 2 — disable immediately blocks new authentication
- FR26: Epic 4 — HR create user (pending + activation email)
- FR27: Epic 4 — HR search/list users + lifecycle state
- FR28: Epic 4 — HR enable/disable account
- FR29: Epic 4 — HR trigger password reset / reset MFA
- FR30: Epic 4 — HR CSV bulk-create pending accounts
- FR31: Epic 4 — HR correct profile attributes (controlled email change)
- FR32: Epic 5 — register/manage OIDC clients + secret rotation
- FR33: Epic 5 — manage admin users + role assignment (SoD)
- FR34: Epic 5 — view/export audit log (export itself audited)
- FR35: Epic 5 — record authentication events
- FR36: Epic 5 — record administrative actions
- FR37: Epic 5 — record token & key events
- FR38: Epic 5 — append-only off-host 12-month audit log
- FR39: Epic 5 — no-secrets audit + out-of-band copy to named second person
- FR40: Epic 6 — OIDC integration guide
- FR41: Epic 6 — full integration contract documented
- FR42: Epic 6 — identity-claim contract + local-account mapping
- FR43: Epic 6 — minimal reference/sample client
- FR44: Epic 4 — hardened admin reset (out-of-band attestation, re-activation; re-enroll flow in Epic 3)
- FR45: Epic 2 — session-id regeneration on auth-state transition (admin-app sessions in Epic 4)
- FR46: Epic 2 — immediate revocation on disable (System Admin force-terminate in Epic 5)
- FR47: Epic 2 — auth-code/PKCE/nonce hygiene
- FR48: Epic 3 — activation/reset token invalidation + pending expiry
- FR49: Epic 4 — CSV import validation/de-dup/throttle/preview
- FR50: Epic 1 — edge rate-limiting + cacheable JWKS/discovery (admin CSRF + step-up in Epic 4)

## Epic List

### Epic 1: Secure Platform Foundation
A hardened, version-pinned identity platform (Keycloak + PostgreSQL ×2 + single Nginx security edge) runs on-prem via Docker Compose, with realm config-as-code, secret hygiene, shared Deep Sea design tokens, and the agentic-build/CI security gate enforcing standards on every later change.
**FRs covered:** FR50 (edge rate-limit/abuse, cacheable JWKS/discovery) — plus AR1, AR2, AR4, AR8 and NFR1, NFR4, NFR8, NFR9, UX-DR1.

### Epic 2: Staff Authentication & SSO Identity
A staff member signs in once — via email+password+TOTP MFA **or** Login with ThaiD — through the branded, top-level, anti-phishing login, and reaches every integrated app in-session; their canonical identity is the system of record.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR8, FR9, FR10, FR11, FR12, FR13, FR13a, FR14, FR19, FR20, FR21, FR22, FR23, FR24, FR25, FR45, FR46, FR47 — plus UX-DR2, UX-DR3 (sign-in/MFA/signed-out), UX-DR6, UX-DR7, UX-DR8, UX-DR9.

### Epic 3: Account Activation & Self-Service Recovery
New hires activate their own accounts (set password + enroll MFA), and any staff member recovers a forgotten password or re-enrolls MFA without IT — all via single-use, hardened email links.
**FRs covered:** FR15, FR16, FR17, FR18, FR48 — plus NFR2, NFR2a, NFR16 and UX-DR3 (forgot/email-sent/reset/activate/re-activation/auth-error).

### Epic 4: HR Admin Console — Employee Lifecycle
From one console, HR creates/searches users, runs the joiner/mover/leaver lifecycle (enable/disable with immediate revocation), provides front-line reset support, and bulk-seeds the roster via validated CSV import. Builds the admin-app scaffold + OIDC admin sign-in + DB sessions + role-gating + Keycloak adapter as its early stories.
**FRs covered:** FR26, FR27, FR28, FR29, FR30, FR31, FR44, FR49 — plus AR3, AR5, AR6 and UX-DR4, UX-DR6, UX-DR10.

### Epic 5: System Admin Console & Audit Trail
The System Admin registers/manages OIDC clients (secret rotation), manages admin users with enforced separation of duties, and views/exports a tamper-evident, off-host audit trail recording every authentication and privileged action.
**FRs covered:** FR32, FR33, FR34, FR35, FR36, FR37, FR38, FR39 — plus AR7, NFR14, UX-DR5.

### Epic 6: App Integration Enablement & Pilot
An app owner integrates their app behind SSO using the published integration guide and a working reference client, mapping the work-email claim to their local accounts.
**FRs covered:** FR40, FR41, FR42, FR43.

### Epic 7: Compliance, Assurance & Go-Live Gates
The hard gates that govern release are met — RoPA / lawful-basis / DPO sign-off + tested 72-hour breach runbook (pre-pilot), independent ASVS L2 review (pre-pilot), independent penetration test (pre-broad-rollout), plus tested backup/restore + key-loss runbook.
**FRs covered:** (NFR-driven) NFR6, NFR10, NFR11, NFR12, NFR13, NFR15, NFR17.

## Epic 1: Secure Platform Foundation

A hardened, version-pinned identity platform (Keycloak + PostgreSQL ×2 + single Nginx security edge) runs on-prem via Docker Compose, with realm config-as-code, secret hygiene, shared Deep Sea design tokens, and the agentic-build/CI security gate enforcing standards on every later change.

### Story 1.1: Docker Compose stack — pinned Keycloak + PostgreSQL (two databases)

**GH Issue:** #2

As the System Administrator,
I want a reproducible on-prem stack that brings up Keycloak backed by PostgreSQL,
So that every later capability has a running, version-pinned foundation.

**Acceptance Criteria:**

**Given** a clean checkout with a populated `.env`
**When** I run `docker compose up`
**Then** Keycloak starts healthy against PostgreSQL and its admin console is reachable.

**Given** the Postgres container initialises
**When** bring-up completes
**Then** two separate databases exist — `keycloak` and `admin` — with distinct least-privilege roles (NFR1, AR4).

**Given** the compose file
**When** images are resolved
**Then** Keycloak (26.6.x) and PostgreSQL are pinned by exact version/digest — never `:latest`.

**Given** secrets are required
**When** I inspect the repo
**Then** all secrets come from env (`.env.example` committed, real `.env` git-ignored) and no secret is hard-coded.

### Story 1.2: Realm config-as-code baseline & secret hygiene

**GH Issue:** #3

As the System Administrator,
I want the realm defined as version-controlled, secret-stripped config that imports on bring-up,
So that realm state is reproducible and auditable.

**Acceptance Criteria:**

**Given** `keycloak/realm-export.json` in git
**When** the stack starts
**Then** the realm is imported automatically and baseline settings (realm name, login settings) are applied.

**Given** the exported realm file
**When** I inspect it
**Then** it contains no client secrets, passwords, or signing-key material (gitleaks-clean).

**Given** a realm change
**When** it is exported back to the repo
**Then** the diff is reviewable and re-importable on a clean stack.

### Story 1.3: Nginx security edge

**GH Issue:** #4

As the System Administrator,
I want a single Nginx security edge in front of the platform,
So that all public traffic is TLS-terminated, header-hardened, and abuse-protected.

**Acceptance Criteria:**

**Given** the edge config
**When** any request arrives
**Then** it is served over TLS with HSTS and standard security headers, and a CSP including `frame-ancestors 'none'` is set on auth surfaces (NFR4).

**Given** public unauthenticated endpoints
**When** they receive excessive traffic
**Then** edge rate-limiting/abuse controls throttle it (FR50).

**Given** the JWKS and discovery endpoints
**When** clients fetch them through the edge
**Then** responses are cacheable (FR50).

### Story 1.4: Shared Deep Sea design-token stylesheet

**GH Issue:** #5

As a developer,
I want one canonical Deep Sea token stylesheet,
So that the Keycloak theme and the admin app render with identical, AA-verified visual identity.

**Acceptance Criteria:**

**Given** `design-tokens/deep-sea.css`
**When** I inspect it
**Then** it exposes all DESIGN.md tokens (colors, type, spacing, radius) as CSS variables, light-mode only (UX-DR1).

**Given** the stylesheet
**When** a downstream surface imports it
**Then** every documented text/background pairing meets WCAG AA.

### Story 1.5: Agentic-build / CI security gate

**GH Issue:** #6

As the System Administrator,
I want a security/quality gate that runs locally pre-commit and in CI,
So that every change is held to the project's standards automatically.

**Acceptance Criteria:**

**Given** a commit
**When** the pre-commit hook runs
**Then** gitleaks, Semgrep, and realm-config lint execute and block on failure (NFR8, NFR9, AR8).

**Given** a pushed branch
**When** CI runs
**Then** the gate runs the full applicable suite (formatting, SAST, secret-scan, dependency audit, realm-config lint) and fails the build on any violation.

**Given** the admin app does not yet exist
**When** the gate runs
**Then** language-specific checks (ESLint/tsc/svelte-check/bun audit/tests) are wired but no-op gracefully until that app lands — no forward dependency.

## Epic 2: Staff Authentication & SSO Identity

A staff member signs in once — via email+password+TOTP MFA **or** Login with ThaiD — through the branded, top-level, anti-phishing login, and reaches every integrated app in-session; their canonical identity is the system of record. Mostly Keycloak realm configuration + the native Deep Sea theme + ThaiD identity brokering (realm config; mock OIDC IdP in dev).

### Story 2.1: Canonical identity model & lifecycle states

**GH Issue:** #7

As a staff member,
I want to exist as exactly one canonical identity,
So that every app recognizes the same "me."

**Acceptance Criteria:**

**Given** the realm user model
**When** an identity is created
**Then** it carries a stable internal subject (never reused) and a unique work email as the reconciliation key (FR21, FR22).

**Given** data-minimization rules
**When** I inspect stored attributes
**Then** only the minimal auth/identification set is stored and no PDPA §26 sensitive data is held (FR23).

**Given** the lifecycle
**When** an identity changes state
**Then** it moves only through pending → active → disabled via controlled transitions (FR24).

### Story 2.2: OIDC Authorization Code + PKCE login (hosted credentials)

**GH Issue:** #8

As a staff member,
I want to authenticate through the identity service's own login,
So that my credentials never touch the apps.

**Acceptance Criteria:**

**Given** a registered client
**When** it initiates login
**Then** only Authorization Code flow with PKCE is accepted; Implicit and ROPC are unavailable (FR1, FR3).

**Given** a login request
**When** credentials are entered
**Then** they are submitted to the identity service only and never transit the relying party (FR2).

**Given** a client's redirect URIs
**When** a redirect is requested
**Then** only an exact-match URI is honored (no wildcard/substring) (FR4).

**Given** an issued authorization code
**When** it is exchanged
**Then** it is single-use, short-lived, replay-detected, with PKCE verifier binding enforced server-side (FR47).

### Story 2.3: Signed tokens, JWKS & OIDC discovery

**GH Issue:** #9

As an integrating app,
I want verifiable tokens and a discovery document,
So that I can validate identities and self-configure.

**Acceptance Criteria:**

**Given** a successful authentication
**When** a token is issued
**Then** the ID token is asymmetrically signed (RS256-class) and carries the agreed claims including the work-email key (FR5).

**Given** token validation
**When** a client fetches keys
**Then** signing keys are published via a JWKS endpoint with `kid` (FR5).

**Given** an auth request
**When** it is created
**Then** it is bound to the session via `state` and `nonce`, and `nonce` is verified exactly once (FR6, FR47).

**Given** a client bootstrapping
**When** it reads `.well-known`
**Then** the standard OIDC discovery document lets it self-configure (FR11).

### Story 2.4: SSO session, lifetimes & RP-initiated logout

**GH Issue:** #10

As a staff member,
I want one session that carries me across apps and ends cleanly,
So that I sign in once and sign out securely.

**Acceptance Criteria:**

**Given** an authenticated session
**When** I open another integrated app
**Then** I reach it without re-entering credentials (FR7).

**Given** session policy
**When** idle or absolute lifetime expires
**Then** re-authentication is required (FR8); access/ID tokens never exceed a 15-minute lifetime (NFR2a), and any refresh tokens rotate on use with family revocation on replay (FR9).

**Given** an auth-state transition (login, MFA success)
**When** it occurs
**Then** the session identifier is regenerated and a server-side session record is kept (FR45).

**Given** RP-initiated logout
**When** an app requests it
**Then** the session terminates and a validated post-logout redirect is honored, landing on the branded signed-out surface (FR10, UX-DR3).

### Story 2.5: Branded Deep Sea login theme (top-level, anti-phishing)

**GH Issue:** #11

As a non-technical staff member,
I want an unmistakably legitimate login,
So that I can tell the real login from a phishing copy.

**Acceptance Criteria:**

**Given** the native Keycloak theme
**When** any auth surface renders
**Then** it uses the shared Deep Sea tokens and renders top-level only (`frame-ancestors 'none'`), never embedded/framed (FR12, UX-DR2).

**Given** the sign-in and MFA surfaces
**When** they load
**Then** a pinned, non-dismissible, full-contrast anti-phishing banner is shown ("we'll never ask for your code…") (UX-DR7, UX-DR9).

**Given** all theme copy
**When** I inspect it
**Then** every string is externalized, English-first and localization-ready (no hard-coded text) (FR12, UX-DR2).

**Given** WCAG 2.1 AA
**When** I audit the surfaces
**Then** they are keyboard-complete with a visible focus ring, persistent labels, and aria-associated errors (UX-DR8).

### Story 2.6: TOTP MFA enforcement & verification hardening

**GH Issue:** #12

As a staff member,
I want a second factor at sign-in,
So that a stolen password alone can't impersonate me.

**Acceptance Criteria:**

**Given** any active staff account
**When** signing in with email + password
**Then** a TOTP code is required after the password (FR13).

**Given** the verification surface
**When** I enter the code
**Then** it is a single labeled 6-digit group (auto-advance, paste, verify-on-6th) announced as one field to assistive tech (UX-DR6, UX-DR8).

**Given** code verification
**When** a code is checked
**Then** it is accepted only within a bounded clock-drift window, verification is rate-limited, and a verified code is single-use within its time step (FR14).

### Story 2.7: Brute-force protection & enumeration-resistant responses

**GH Issue:** #13

As the System Administrator,
I want guessing attacks throttled and account existence hidden,
So that the auth surface resists abuse.

**Acceptance Criteria:**

**Given** repeated failed attempts
**When** they occur on login or TOTP
**Then** progressive delays apply per-account and per-IP (FR19).

**Given** a login attempt
**When** it fails for any reason
**Then** the response is identical and generic whether or not the account exists, with identical timing (FR20, UX-DR9).

### Story 2.8: Disable blocks authentication & revokes sessions

**GH Issue:** #14

As the organization,
I want a disabled account locked out instantly,
So that a leaver cannot authenticate anywhere.

**Acceptance Criteria:**

**Given** an account set to disabled
**When** it attempts to authenticate at any integrated app
**Then** all new authentication is blocked immediately (FR25).

**Given** an account is disabled
**When** the transition completes
**Then** all outstanding refresh-token families are revoked and all server-side sessions for that subject are invalidated (FR46).

### Story 2.9: Login with ThaiD (brokered federation & account linking)

**GH Issue:** #15

As a staff member,
I want to sign in with ThaiD instead of a password,
So that I can use my national digital ID and skip the password + code.

**Acceptance Criteria:**

**Given** the Sign in surface
**When** it renders
**Then** a "Login with ThaiD" button is shown as a secondary option below the email/password form, after an "or" divider (FR13a, UX-DR6).

**Given** ThaiD configured as an external OIDC Identity Provider in realm config-as-code
**When** a user chooses Login with ThaiD
**Then** Keycloak brokers the flow top-level, the user authenticates at ThaiD, and Keycloak issues its own token — Keycloak remains the IdP (FR13a, FR2).

**Given** a first Login with ThaiD
**When** the ThaiD identity returns
**Then** a first-broker-login flow links it to the pre-created staff account by national ID (PID); both login methods then resolve to the same canonical identity (FR13a, FR21).

**Given** a disabled account
**When** it attempts Login with ThaiD
**Then** brokered login is blocked just like password login (FR25).

**Given** dev/CI without DOPA access
**When** the ThaiD flow runs
**Then** the broker points at a mock OIDC IdP, exercising the full brokered path without real ThaiD (AR8).

## Epic 3: Account Activation & Self-Service Recovery

New hires activate their own accounts (set password + enroll MFA), and any staff member recovers a forgotten password or re-enrolls MFA without IT — all via single-use, hardened email links.

### Story 3.1: Password policy & breach screening

**GH Issue:** #16

As the System Administrator,
I want a strong-by-default password policy,
So that every password staff set resists guessing and known-breach reuse.

**Acceptance Criteria:**

**Given** a new password is being set
**When** it is submitted
**Then** it is accepted only at ≥ 12 characters and long passphrases are supported (FR18).

**Given** the policy
**When** a password is checked
**Then** it is screened against known-breached lists and rejected if found (FR18, NFR7).

**Given** the policy
**When** I inspect it
**Then** no composition rules and no forced periodic rotation are imposed (FR18).

**Given** the reset/set surfaces
**When** a user types
**Then** live plain-language hints show length + breach rules only (UX-DR8).

### Story 3.2: Email delivery & link-token hygiene

**GH Issue:** #17

As the System Administrator,
I want monitored email delivery and hardened link tokens,
So that activation/reset links are reliable and unforgeable.

**Acceptance Criteria:**

**Given** SMTP
**When** the platform sends mail
**Then** it is treated as a monitored critical-path dependency with delivery retries and bounce handling (NFR16).

**Given** an activation/reset token
**When** it is issued
**Then** it is single-use, short-lived (≤ ~20 min), ≥ 128-bit entropy, and stored hashed (NFR2).

**Given** a new token is issued for a user
**When** issuance completes
**Then** any prior outstanding token for that user is invalidated (FR48).

**Given** an expired or invalid link
**When** it is opened
**Then** a generic "that link no longer works — request a new one" surface is shown, never revealing account state (UX-DR3, FR20).

### Story 3.3: First-login activation

**GH Issue:** #18

As a new hire,
I want to activate my own account from an email link,
So that I set my password and enroll MFA without IT.

**Acceptance Criteria:**

**Given** an admin-created account in pending
**When** the user opens the activation link
**Then** they reach the branded activate surface to set a password and enroll a TOTP authenticator (FR16, FR13).

**Given** activation completes
**When** the user finishes
**Then** the account moves pending → active and the user is alerted and lands signed in (FR16).

**Given** a bounded activation window
**When** it elapses unused
**Then** the pending account expires and the user is told to ask HR for a new link (FR48).

### Story 3.4: Self-service password reset

**GH Issue:** #19

As a staff member,
I want to reset a forgotten password by email,
So that I recover access without calling anyone.

**Acceptance Criteria:**

**Given** the forgot-password surface
**When** I submit my email
**Then** I always see the same generic "if an account exists, we've sent a link" confirmation (FR17, FR20, UX-DR3).

**Given** a valid reset link
**When** I set a new password
**Then** the reset completes, I am alerted, and MFA enrollment is NOT cleared (FR17).

**Given** a completed reset
**When** it finishes
**Then** all my other active sessions and outstanding tokens are invalidated (FR48).

### Story 3.5: MFA reset re-activation flow

**GH Issue:** #20

As a staff member who lost my authenticator,
I want a safe re-enrollment path,
So that recovering MFA never leaves my account half-protected.

**Acceptance Criteria:**

**Given** an admin has reset my MFA
**When** I next sign in
**Then** my account is in re-activation and I must re-set my password and re-enroll a new authenticator via a single-use link (FR15, FR44 flow side).

**Given** the re-activation flow
**When** it completes
**Then** there is never a "password known, MFA cleared" window — both are re-established together (FR44).

## Epic 4: HR Admin Console — Employee Lifecycle

From one console, HR creates/searches users, runs the joiner/mover/leaver lifecycle (enable/disable with immediate revocation), provides front-line reset support, and bulk-seeds the roster via validated CSV import. Builds the admin-app scaffold + OIDC admin sign-in + DB sessions + role-gating + Keycloak adapter as its early stories.

### Story 4.1: Admin app scaffold & gate activation

**GH Issue:** #21

As a developer,
I want the SvelteKit admin app scaffolded and held to the full gate,
So that HR/System features have a typed, themed, verified foundation.

**Acceptance Criteria:**

**Given** the `admin/` app
**When** it is built
**Then** it is SvelteKit (Svelte 5/TS) on Bun with `adapter-node`, Tailwind v4 + shadcn-svelte rethemed to Deep Sea importing the shared tokens (AR3, UX-DR6).

**Given** the previously-stubbed gate checks
**When** CI runs against the admin app
**Then** ESLint, `tsc`, `svelte-check`, and `bun audit` are now active and blocking (AR8).

**Given** the route structure
**When** I inspect it
**Then** role-gated route groups `(auth)`/`(hr)`/`(system)` exist and `lib/server/**` is ESLint-blocked from client import.

### Story 4.2: Admin OIDC sign-in & role-gated shell

**GH Issue:** #22

As an administrator,
I want to sign in and see only my section,
So that separation of duties is enforced from the first screen.

**Acceptance Criteria:**

**Given** an admin
**When** they sign in
**Then** authentication uses OIDC Auth Code + PKCE into Keycloak via `openid-client` with DB-backed server-side sessions and `__Host-` cookies (AR6).

**Given** an auth-state transition
**When** it occurs
**Then** the session id is regenerated server-side (FR45).

**Given** a signed-in admin's realm role
**When** the shell renders
**Then** only their section is shown — HR and System are never shown together — enforced in `hooks.server.ts` (UX-DR10, FR33 enforcement).

**Given** an unauthenticated or wrong-role request to a protected route
**When** it is made
**Then** it is rejected server-side.

### Story 4.3: Typed Keycloak Admin REST adapter & Valibot contracts

**GH Issue:** #23

As a developer,
I want one typed, validated adapter over the Keycloak Admin API,
So that every privileged call is safe and integration-tested.

**Acceptance Criteria:**

**Given** the adapter in `lib/server/keycloak/`
**When** it calls Keycloak
**Then** it uses a dedicated least-privilege service-account client and returns Valibot-validated data (AR5).

**Given** any Admin-API response or form payload
**When** it crosses a server boundary
**Then** it is validated with Valibot before flowing inward (AR5).

**Given** CI
**When** the gate runs
**Then** adapter integration tests execute against a live Keycloak and must pass (R11).

### Story 4.4: Create user & search/list

**GH Issue:** #24

As an HR Administrator,
I want to create staff and find them,
So that I can onboard people and see their state.

**Acceptance Criteria:**

**Given** the create-user surface
**When** I submit name + work email + national ID (PID, for ThaiD linking)
**Then** the account is created in pending and an activation email is sent (FR26).

**Given** the user list
**When** I search/browse
**Then** I see staff with their lifecycle state as a text+icon status pill, paginated (never infinite-scroll) (FR27, UX-DR4, UX-DR6, UX-DR10).

**Given** the admin DB
**When** users are listed
**Then** no identity PII is persisted admin-side — the user reference is the Keycloak `sub` only (AR4).

### Story 4.5: User detail — enable/disable & profile edit

**GH Issue:** #25

As an HR Administrator,
I want to manage a person's status and details,
So that I can handle movers and leavers.

**Acceptance Criteria:**

**Given** a user-detail surface
**When** I disable an account
**Then** the disable takes effect per Epic 2 (new auth blocked + sessions/tokens revoked), styled destructive and requiring step-up (FR28, FR25, FR46).

**Given** I re-enable an account
**When** I confirm
**Then** the account returns to active (FR28).

**Given** profile editing
**When** I change minimal attributes
**Then** they update; changing the work email (reconciliation key) is a controlled action flagged for its reconciliation impact (FR31).

### Story 4.6: Front-line reset (password + MFA) with attestation & step-up

**GH Issue:** #26

As an HR Administrator,
I want hardened reset support,
So that recovery is helpful but cannot be abused.

**Acceptance Criteria:**

**Given** a sensitive reset action
**When** I initiate it
**Then** a `max_age=0` step-up re-auth is required before proceeding (FR50).

**Given** an admin-initiated MFA/password reset
**When** I perform it
**Then** I must record a documented out-of-band identity-verification attestation, and the affected user is notified (FR29, FR44).

**Given** an MFA reset
**When** it completes
**Then** the account returns to pending re-activation (re-enroll MFA + re-set password) — never "password known, MFA cleared" (FR44).

**Given** admin resets
**When** they occur
**Then** they are rate-limited with an abuse alert (FR44).

### Story 4.7: CSV bulk import (validate → preview → confirm)

**GH Issue:** #27

As an HR Administrator,
I want to seed many pending accounts from a CSV,
So that I can onboard a batch safely.

**Acceptance Criteria:**

**Given** a CSV upload
**When** it is parsed
**Then** rows are shown in a preview marked clean / invalid / duplicate (color + marker), before any account is created (FR30, FR49, UX-DR6).

**Given** the preview
**When** rows are validated
**Then** they are de-duplicated against existing identities (by work email and national ID/PID), a per-import size cap is enforced, and CSV/formula injection is sanitized (FR49).

**Given** I confirm the import
**When** it runs
**Then** pending accounts are created and activation-email dispatch is throttled (FR30, FR49).

## Epic 5: System Admin Console & Audit Trail

The System Admin registers/manages OIDC clients (secret rotation), manages admin users with enforced separation of duties, and views/exports a tamper-evident, off-host audit trail recording every authentication and privileged action.

### Story 5.1: Audit event capture pipeline

**GH Issue:** #28

As the System Administrator,
I want every security-relevant event captured,
So that incidents can be reconstructed.

**Acceptance Criteria:**

**Given** the Keycloak Event Listener SPI + admin-app audit emitter
**When** an authentication event occurs (login success/failure, MFA outcome, session create/terminate/expiry, logout, activation, reset)
**Then** it is recorded with source IP and user-agent/device (FR35, AR7).

**Given** an administrative action (user create/enable/disable, password/MFA reset with attestation, profile change, client registration/secret rotation, key rotation, admin-user changes)
**When** it occurs
**Then** it is recorded as a `domain.action` past-tense event (FR36).

**Given** token & key events (issuance, refresh-rotation, reuse-detection trips, JWKS/signing-key rotation)
**When** they occur
**Then** they are recorded sufficient to scope incident blast radius (FR37).

### Story 5.2: Off-host append-only audit sink, retention & out-of-band copy

**GH Issue:** #29

As the organization,
I want the audit log beyond the operator's reach,
So that even the solo admin cannot quietly rewrite it.

**Acceptance Criteria:**

**Given** audit events
**When** they are written
**Then** they ship off-host to append-only / integrity-verifiable storage the operator cannot rewrite, retained 12 months (FR38, NFR14).

**Given** audit content
**When** events are stored
**Then** they never contain credentials, MFA secrets, or token values, and do not leak account existence (FR39).

**Given** retention policy
**When** the schedule runs
**Then** a copy is delivered out-of-band to a named second person (e.g., DPO/manager) (FR39).

### Story 5.3: Register & manage OIDC clients with secret rotation

**GH Issue:** #30

As the System Administrator,
I want to onboard and maintain client apps,
So that apps can integrate without breaking on rotation.

**Acceptance Criteria:**

**Given** the client surfaces
**When** I register/edit a client
**Then** I set credentials, exact-match redirect URIs, and allowed scopes (FR32, FR4, UX-DR5).

**Given** a sensitive client action
**When** I initiate it
**Then** a step-up re-auth is required and the action is audited (FR50, FR36).

**Given** a live client
**When** I rotate its secret
**Then** a dual-secret overlap window lets rotation complete without breaking the running app (FR32).

### Story 5.4: Manage admin users & roles (separation of duties)

**GH Issue:** #31

As the System Administrator,
I want to manage who administers the system,
So that no one person holds every key.

**Acceptance Criteria:**

**Given** the admin-users surface
**When** I create/disable an admin
**Then** I assign exactly one of the `hr-admin` / `system-admin` roles, enforcing the two-role separation of duties (FR33, UX-DR5).

**Given** an admin-user change
**When** I save it
**Then** it requires step-up re-auth and is audited (FR50, FR36).

### Story 5.5: Audit log view & export (itself audited)

**GH Issue:** #32

As the System Administrator,
I want to read and export the audit trail,
So that I can investigate and satisfy compliance.

**Acceptance Criteria:**

**Given** the audit surface
**When** I view or filter events
**Then** the log is displayed paginated and read-only (FR34, UX-DR5).

**Given** an export
**When** I run it
**Then** the export succeeds and the read/export action is itself recorded as an audit event (FR34).

## Epic 6: App Integration Enablement & Pilot

An app owner integrates their app behind SSO using the published integration guide and a working reference client, mapping the work-email claim to their local accounts.

### Story 6.1: Minimal reference / sample OIDC client

**GH Issue:** #33

As an app owner,
I want a working sample client to copy,
So that I can integrate without deep auth expertise.

**Acceptance Criteria:**

**Given** `reference-client/`
**When** I run it
**Then** it completes Authorization Code + PKCE against the service end-to-end and signs in (FR43, FR1).

**Given** the sample
**When** it receives tokens
**Then** it validates the ID token (signature via JWKS/`kid`, `iss`/`aud`/`exp`/`nonce`/`azp`) and reads the work-email claim (FR43, FR41).

**Given** the sample
**When** I read it
**Then** it is minimal and copyable as an adoption asset (FR43, FR40).

### Story 6.2: OIDC integration guide — full contract & claim mapping

**GH Issue:** #34

As an app owner,
I want a complete integration guide,
So that I can wire my app correctly using standard OIDC libraries.

**Acceptance Criteria:**

**Given** `docs/integration-guide.md`
**When** I follow it
**Then** it documents the full contract — discovery, Auth Code + PKCE, redirect-URI registration, ID-token/JWKS validation incl. `iss`/`aud`/`exp`/`nonce`/`azp` (FR40, FR41).

**Given** the guide
**When** I read the session/caching rules
**Then** it requires apps to bound their local session lifetime to the token lifetime and to honor `kid` with a bounded JWKS cache TTL (FR41).

**Given** the guide
**When** I read the identity section
**Then** it documents the identity-claim contract (stable subject + work-email reconciliation key) and how an app maps an SSO identity to its existing local account (FR42).

### Story 6.3: Pilot integration validation

**GH Issue:** #35

As the System Administrator,
I want to prove the contract with a real integration,
So that the guide is sourced from real experience.

**Acceptance Criteria:**

**Given** the reference client and guide
**When** a pilot app is integrated
**Then** it authenticates exclusively through the service with no separate login remaining (FR43, SM1).

**Given** the pilot integration
**When** issues surface
**Then** the guide and reference client are updated from real-world experience (FR40).

**Given** the pilot app
**When** a user signs in once
**Then** they reach it in-session without re-authentication (FR7, SM2).

## Epic 7: Compliance, Assurance & Go-Live Gates

The hard gates that govern release are met — RoPA / lawful-basis / DPO sign-off + tested 72-hour breach runbook (pre-pilot), independent ASVS L2 review (pre-pilot), independent penetration test (pre-broad-rollout), plus tested backup/restore + key-loss runbook.

### Story 7.1: PDPA documentation — RoPA, lawful basis & data-subject rights

**GH Issue:** #36

As the accountable owner,
I want PDPA processing documented,
So that the service is lawful before it touches real staff data.

**Acceptance Criteria:**

**Given** each processing purpose
**When** the RoPA is authored
**Then** the lawful basis (contractual necessity / legal obligation / legitimate interest — NOT consent) is documented with a named accountable owner (NFR11).

**Given** stored data
**When** it is audited
**Then** no PDPA §26 sensitive data is held and data minimization + least-privilege admin access are evidenced (NFR12, NFR13).

**Given** the rights policy
**When** documented
**Then** each data-subject right's disposition is stated, including audit-row pseudonymization on erasure (NFR14).

### Story 7.2: Tested 72-hour breach-response runbook & DPO sign-off

**GH Issue:** #37

As the organization,
I want a proven breach response and DPO approval,
So that the PDPA pre-pilot gate is cleared.

**Acceptance Criteria:**

**Given** the breach runbook
**When** it is exercised in a drill
**Then** the 72-hour notification/reconstruction duty can be met using the audit trail (NFR15).

**Given** the pre-pilot gate
**When** review completes
**Then** RoPA, lawful-basis docs, DPO sign-off, and the tested runbook are all complete with a named owner and a date tied to pilot go-live (NFR15). _(Depends on OQ3 — named DPO/second person.)_

### Story 7.3: Tested backup/restore & key-loss/compromise runbook

**GH Issue:** #38

As the System Administrator,
I want recovery proven,
So that signing-key loss or a data-loss event is survivable.

**Acceptance Criteria:**

**Given** the platform stores
**When** a restore drill runs
**Then** Keycloak PostgreSQL + realm export/keys + admin DB are restored successfully (NFR17).

**Given** recovery objectives
**When** documented
**Then** a stated RTO/RPO and a key-loss/compromise runbook exist and have been tested (NFR17, NFR3).

### Story 7.4: Independent ASVS L2 review (pre-pilot gate)

**GH Issue:** #39

As the organization,
I want a second qualified reviewer,
So that the solo-build risk is compensated before real data flows.

**Acceptance Criteria:**

**Given** the ASVS L2 checklist (L3 for credential/key handling)
**When** the build is assessed
**Then** it is completed and independently reviewed by a second qualified person before the pilot processes real staff data (NFR6, NFR10).

**Given** the review
**When** it concludes
**Then** zero outstanding token/session/credential-storage-class defects remain (SM5). _(Depends on OQ4 — assessment funding.)_

### Story 7.5: Independent penetration test (pre-broad-rollout gate)

**GH Issue:** #40

As the organization,
I want an external pen test passed,
So that broad rollout is gated on proven security.

**Acceptance Criteria:**

**Given** the pilot-validated service
**When** an independent penetration test is performed
**Then** it is passed before broad rollout (NFR10, SM7).

**Given** findings
**When** any are raised
**Then** they are remediated and re-verified before the gate is considered cleared (NFR10). _(Depends on OQ4 — assessment funding.)_
