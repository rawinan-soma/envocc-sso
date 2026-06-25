---
title: "Product Requirements Document — envocc-sso"
status: final
created: 2026-06-21
updated: 2026-06-22
---

# Product Requirements Document — envocc-sso

> **Final.** Built fresh from the tooling-agnostic product brief (`brief-envocc-sso-2026-06-19/brief.md`, rev. 2026-06-21). **Capabilities only**; the implementation/stack (ground-up vs Keycloak vs Authentik) is an **open architecture decision (OQ2)**, not made here.
>
> **Change Note (2026-06-22) — two login methods.** Staff may authenticate by **(1) email + password + TOTP MFA** *or* **(2) Login with ThaiD** (Keycloak brokers the ThaiD OIDC IdP). Both resolve to the same canonical Keycloak identity and emit the same claims; **Keycloak remains the IdP**. The local password+TOTP path is the always-available baseline (works in dev with no external service, and is the DOPA-down fallback); ThaiD is an opt-in alternative **linked by national ID (PID)** at account creation. Adds **FR13a**; the original TOTP requirements stand. **Open with DOPA:** RP onboarding for "Login with ThaiD" and the claims it asserts (esp. PID).

## 1. Vision & Problem

**envocc-sso is EnvOcc's first single sign-on and central identity system — the HR-administered single source of truth for who works here.** It replaces a dozen scattered per-app logins with one branded, MFA-protected identity, and gives HR one console to grant and revoke access across the organization. Its ambition is to become the **authentication layer for all of EnvOcc's internal applications**; v1 proves the model by authenticating staff for the first 1–2 pilot apps — answering *who you are*, not yet *what you may do*.

**The problem it kills.** Today the same ~100–150 people exist as a dozen disconnected accounts that no single system can see as one person — *Somchai in the lab system, Somchai in the reporting tool, Somchai in the document archive.* Each app has its own login and its own user table. There is no central record of who works here, no single point to enforce a password policy or require MFA, and — the sharpest edge — **no reliable way to confirm that someone who left is actually locked out everywhere.** For a division handling occupational and environmental health data, scattered and un-revoked access is a genuine security and governance liability.

**Two co-equal halves.** This is not "a login page with an admin screen bolted on." It is two first-class halves: the **staff identity experience** (login, MFA, self-service recovery) and the **HR/admin control plane** (the joiner/mover/leaver lifecycle). The admin console is a co-equal half of the product, not an afterthought.

**North-star — readiness, not a date.** **Security rigor — not feature count — is the definition of done. There is no fixed deadline; readiness gates release.** This principle governs the whole PRD: it is what justifies a deliberately narrow v1, scope cuts under pressure, and independent-assurance gates before go-live.

**Built honestly, with eyes open.** envocc-sso is **security-critical infrastructure** — it guards every other app and is the **sole system of record for staff credentials** — and it is **built and operated solo, without independent security review.** This is stated here at the top, not buried in a later section: it is the reason v1 is scoped tight, rolled out in phases (proving on 1–2 pilot apps first), and held to published security checklists plus — budget permitting — one independent assessment before broad rollout. The in-house mandate *manages* this risk; it does not remove it.

**End-state.** If v1 proves out, envocc-sso becomes EnvOcc's identity backbone — **all 10–15 internal apps behind one secure login within ~a year**, then a natural progression to **centralized authorization** (roles and groups managed once, read by every app). v1 deliberately stops at authentication.

**Guiding constraints (load-bearing context):**
- **In-house mandate** — its intent is **sovereignty and control**: no foreign SaaS, no data leaving the ministry, fully inspectable and self-hostable. *The build approach that satisfies this (custom-built vs self-hosted open-source) is an open architecture decision; this PRD stays capability-level.*
- **Sole system of record for credentials** — no external AD/LDAP/HR feed exists to defer to.
- **Built and maintained solo**; rollout is **phased**, proving the model on 1–2 pilot apps first.
- **Security rigor is the definition of done; there is no fixed deadline** — readiness gates release.

## 2. Users & Stakeholders

| Role | Who | What they need | Success looks like |
|------|-----|----------------|--------------------|
| **Staff** (~100–150) | Non-technical end users | One login to reach every integrated app; painless self-recovery | Sign in once, no password sprawl, reset their own password without calling anyone |
| **HR Administrator** | A member of HR staff; owner of the employee lifecycle and the **single source of truth** for "who is a valid employee" | Provision a person once, disable a leaver once — *with confidence it takes effect everywhere* | Onboard/offboard fully from the console alone |
| **System Administrator** | Rawinan — the technical owner | Connect apps, manage admin users, configure security policy | The system runs, apps are onboarded, separation of duties from HR is enforced |
| **App Owner / team** | Engineers integrating their apps | A clear guide + a stable login service to integrate against | Wire their app in without deep auth expertise |

**Separation of duties (two distinct roles).** The **HR Administrator** manages **only** employee records (create / enable / disable, front-line reset support). The **System Administrator** manages **only** the system itself (app registration, admin users, security configuration). **No single role can do both** — a deliberate security control so that no one person holds every key. Staff are **non-technical**, which makes anti-phishing clarity and painless self-recovery first-class requirements downstream.

## 3. Scope (v1 boundary)

### In scope — v1
- **Single sign-on login** — apps redirect staff to envocc-sso to authenticate; the login is **hosted by the identity service itself** (credentials never transit the apps).
- **Central user store** — the HR-administered system of record for identity.
- **Branded staff login — email + password + TOTP MFA, *or* Login with ThaiD (brokered) — + self-service password reset** (by email).
- **First-login activation** — admin creates a *pending* account → emailed single-use activation link → user sets their own password and enrolls MFA (or signs in via Login with ThaiD).
- **HR Admin console** (employee lifecycle) **+ System Admin console** (apps, admins, security config).
- **Identity reconciliation** — collapse each person's scattered per-app accounts into one canonical identity; console provides **create / search / validated CSV bulk-import**. *No automated cross-app merge.*
- **Audit log** — a record of authentication events and admin actions, retained for compliance and breach reconstruction. **In v1** — the PDPA 72-hour breach-notification duty makes it a must, not a later nicety.
- **Integration guide** for app owners.

### Validation activity (not a product feature)
- **Pilot integration** of the first 1–2 apps, performed by the System Administrator, to prove the service and source the integration guide from real experience. *(PDPA obligations attach the moment the first real employee activates — at the pilot, not at "broad rollout.")*

### Out of scope / deferred — v1
- **Centralized authorization** (roles / groups / permissions) — stays inside each app: *who you are, not what you may do.*
- Wiring all 10–15 apps — each app owner integrates their own.
- External / public / partner users — internal staff only.
- Social login, broad external-IdP federation, SCIM provisioning, passwordless / WebAuthn. *(Exception: **"Login with ThaiD"** is offered as an alternative brokered login method — a deliberate, scoped use of one external digital ID, not general federation; Keycloak remains the IdP and system of record.)*
- Automated cross-app account merge.

## 4. Functional Requirements

> FRs are globally numbered with stable IDs that survive regrouping. Requirements are stated at the **capability / contract level**; exact mechanisms, cryptographic parameters, and library/stack choices are **deferred to architecture**. Domain terms are defined once in the **Glossary** (Appendix A). "OIDC" denotes the interoperability standard the service must speak, not an implementation choice.

### FG-1 — Login & SSO *(core)*

| ID | Functional Requirement |
|----|------------------------|
| **FR1** | The service MUST authenticate staff using the **OIDC Authorization Code flow with PKCE** for all client applications. |
| **FR2** | The service MUST **host the login experience itself**; user credentials MUST never transit relying-party applications. |
| **FR3** | The service MUST **NOT** offer the **Implicit** or **Resource Owner Password Credentials (ROPC)** grant types. |
| **FR4** | Each client MUST register its redirect URIs, and the service MUST enforce **exact-match** redirect URIs (no wildcard/substring matching). |
| **FR5** | On successful authentication the service MUST issue an **asymmetrically-signed ID token** carrying the agreed identity claims (including the **work-email reconciliation key**), and MUST publish its signing keys via a **JWKS endpoint** (with `kid`) for client validation. |
| **FR6** | The service MUST bind each authentication request to its session using **`state`** (CSRF) and **`nonce`** (ID-token replay protection). |
| **FR7** | The service MUST establish a **single sign-on session** so an authenticated staff member can reach every integrated app **without re-entering credentials**, until the session ends. |
| **FR8** | The service MUST enforce both **idle and absolute session lifetimes**, requiring re-authentication when either expires. |
| **FR9** | The service MUST issue **short-lived tokens**; where refresh tokens are issued, it MUST **rotate them on use** with reuse-detection that revokes the token family on replay. |
| **FR10** | The service MUST support **RP-initiated logout** — terminating the session and honoring a validated post-logout redirect. |
| **FR11** | The service MUST expose a standard **OIDC discovery document** (`.well-known`) so clients can self-configure. |

### FG-2 — Staff Authentication Experience

| ID | Functional Requirement |
|----|------------------------|
| **FR12** | The service MUST present a **branded login experience** matching the EnvOcc brand — **branding is a trust / anti-phishing signal** so non-technical staff recognize the genuine login. The login MUST render **top-level (never embedded/framed)** and carry **standing, plain-language anti-phishing guidance** (e.g., "we will never ask for your code"). All UI copy MUST be **externalized strings** (no hard-coded text), **English-first and structured for localization**; producing translations (Thai) is the **owner's responsibility after the UI stabilizes** — the system requirement is translatable strings, not built-in translations. |
| **FR13** | The service MUST enforce **MFA via TOTP** for staff authenticating with **email + password**; users **enroll a TOTP authenticator** during first-login activation. *(Staff who choose **Login with ThaiD** authenticate via ThaiD's own assurance — see FR13a.)* |
| **FR13a** | The service MUST also offer **"Login with ThaiD"** as an **alternative** authentication method, implemented as **brokered federation** (Keycloak brokers the ThaiD OIDC IdP; **Keycloak remains the IdP** to relying parties). On first use, ThaiD is **linked to the staff member's canonical account by national ID (PID)** captured at account creation; both methods resolve to the same identity and tokens. In dev/CI the broker points at a **mock OIDC IdP** (no DOPA access required). |
| **FR14** | The service MUST verify TOTP codes with a **bounded clock-drift window**, **rate-limit** verification, and treat a verified code as **single-use within its time step** (reject replay inside the window). |
| **FR15** | The service MUST allow an administrator to **reset a user's MFA enrollment** as admin-assisted recovery — subject to the safeguards in **FG-8**; the user re-enrolls on next sign-in. |
| **FR16** | **First-login activation:** an admin-created account starts **pending**; the user receives a **single-use, time-limited activation link** by email and, on first sign-in, **sets their own password and enrolls MFA** (a staff member may instead complete sign-in via **Login with ThaiD**, FR13a). Activation MUST **alert the user** and is subject to the token-hygiene rules in **FG-8** (token entropy/lifetime per **NFR2**). |
| **FR17** | The service MUST offer **self-service password reset by email** using a **single-use, short-lived, high-entropy** token (lifetime/entropy bounds per **NFR2**). A reset MUST **not** clear MFA enrollment, MUST **alert the user** on completion, and is subject to **FG-8**. |
| **FR18** | **Password policy** MUST require a **minimum length of ≥ 12 characters**, support long passphrases, **screen new passwords against known-breached lists**, and MUST **NOT** impose composition rules or forced periodic rotation. |
| **FR19** | The service MUST apply **brute-force protection** on login and TOTP verification using **progressive delays**, **per-account and per-IP**. |
| **FR20** | Login, activation, and reset flows MUST be **enumeration-resistant** — identical, generic responses whether or not an account exists. |

### FG-3 — Identity & User Store *(system of record)*

| ID | Functional Requirement |
|----|------------------------|
| **FR21** | The service MUST maintain **exactly one canonical identity per staff member** as the system of record, identified by a **stable internal subject identifier** (never reused). |
| **FR22** | Each identity MUST carry a **unique work email**, which serves as the **reconciliation key** emitted as a claim to integrating apps. |
| **FR23** | The service MUST store only the **minimal attribute set** required for authentication and identification (data minimization) and MUST **NOT** store PDPA §26 sensitive personal data. The minimal set includes the **national ID (PID)** used to link Login with ThaiD (FR13a) — **regular** personal data under PDPA (not §26), documented in the RoPA and held under least-privilege. |
| **FR24** | Each identity MUST have a defined **lifecycle state** — *pending activation → active → disabled* — with controlled transitions. |
| **FR25** | **Disabling an account MUST immediately block all new authentication** for that person across every integrated app, and MUST trigger the server-side revocation in **FG-8**. An app's *already-running local session* is bounded by that app's session lifetime — integrating apps MUST bound their local session to the token lifetime (**FG-7**); this residual is named and accepted. |

### FG-4 — HR Admin Console *(employee lifecycle)*

| ID | Functional Requirement |
|----|------------------------|
| **FR26** | The HR Admin MUST be able to **create a user** (name + work email + **national ID/PID** for ThaiD linking, FR13a), placing the account in **pending** state and **sending the activation email** (FR16). |
| **FR27** | The HR Admin MUST be able to **search and list users** and view each account's **lifecycle state**. |
| **FR28** | The HR Admin MUST be able to **enable or disable** an account (joiner/mover/leaver), with disable behaving per FR25 (and the revocation in FG-8). |
| **FR29** | The HR Admin MUST be able to **trigger a password reset** and **reset MFA enrollment** for a user, as front-line account support — subject to **FG-8** safeguards. |
| **FR30** | The HR Admin MUST be able to **bulk-create pending accounts via CSV import** (name + work email + national ID/PID) to seed the canonical roster, subject to the import validation in **FG-8**. |
| **FR31** | The HR Admin MUST be able to **correct a user's minimal profile attributes** (e.g., name, work email); changing the **reconciliation key (work email)** is a **controlled action** flagged for its reconciliation impact. |

*Leavers are **disabled, not deleted** in v1 (preserves audit trail + reconciliation).*

### FG-5 — System Admin Console *(service administration)*

| ID | Functional Requirement |
|----|------------------------|
| **FR32** | The System Admin MUST be able to **register and manage OIDC client applications** — client credentials, **exact-match redirect URIs** (FR4), and allowed scopes — and to **rotate a client secret with a dual-secret overlap window** so rotation does not break a live app. |
| **FR33** | The System Admin MUST be able to **manage admin users** — create/disable HR Admins and System Admins and **assign their role** — enforcing the two-role separation of duties. |
| **FR34** | The System Admin MUST be able to **view and export the audit log** (FG-6); **every read/export of the audit log MUST itself be audited**. |

*Security policy (password rules, token/session lifetimes, MFA enforcement, throttling thresholds) is **vetted deployment configuration**, not a console screen, in v1.*

### FG-6 — Audit Logging *(compliance)*

| ID | Functional Requirement |
|----|------------------------|
| **FR35** | The service MUST record **authentication events** — login success/failure (throttled vs. failed distinguished), MFA outcome, **session creation/termination and expiry**, logout, activation, and password reset — each with **source IP and user-agent/device**. |
| **FR36** | The service MUST record **administrative actions** — user create/enable/disable, password/MFA reset (with the FR44 identity-proof attestation), profile change, client registration/secret rotation, signing-key rotation, and admin-user changes. |
| **FR37** | The service MUST record **token & key events** — token issuance, refresh-rotation and reuse-detection trips (FR9), and JWKS/signing-key rotation — sufficient to scope which sessions and keys an incident touched. |
| **FR38** | The audit log MUST be **append-only and integrity-verifiable**, **shipped off-host to storage the operator cannot rewrite**, and **retained for 12 months** (realistic breach detection-to-disclosure windows; supports the PDPA 72-hour reconstruction duty). |
| **FR39** | The audit log MUST **NOT** store credentials, MFA secrets, or token values, MUST not leak account existence, and a **scheduled copy MUST be delivered out-of-band to a named second person** (e.g., department DPO/manager) so the solo operator is not the sole reader of his own privileged actions. |

### FG-7 — App-Owner Integration Enablement

| ID | Functional Requirement |
|----|------------------------|
| **FR40** | The project MUST publish an **OIDC integration guide** enabling an app owner to integrate using **standard OIDC libraries**; the **reference client (FR43)** is the testable artifact demonstrating "without deep auth expertise." |
| **FR41** | The guide MUST document the **full integration contract** — discovery (FR11), Auth Code + PKCE (FR1), redirect-URI registration (FR4/FR32), ID-token/JWKS validation (FR5) including `iss`/`aud`/`exp`/`nonce`/`azp` checks — and MUST **require apps to bound their local session lifetime to the token lifetime** and honor `kid` with a **bounded JWKS cache TTL**. |
| **FR42** | The guide MUST document the **identity claim contract** — the stable subject + **reconciliation key (work email)** — and **how an app maps an SSO identity to its existing local account** (FR22). |
| **FR43** | The project MUST provide a **minimal reference/sample client** — the documented pilot integration — demonstrating the contract end-to-end as a copyable adoption asset. |

### FG-8 — Operational Security & Account-Protection Controls

| ID | Functional Requirement |
|----|------------------------|
| **FR44** | Admin-initiated MFA/password reset (FR15/FR29) MUST require a **documented out-of-band identity-verification step** that the admin **attests to in the audit record**; MUST **notify the affected user** on every reset; and an MFA reset MUST return the account to **pending re-activation** (re-enroll MFA *and* re-set password via single-use email link) — never leaving a "password known, MFA cleared" window. Admin resets MUST be **rate-limited with an abuse alert**. |
| **FR45** | The service MUST **regenerate the session identifier on every authentication-state transition** (login, MFA success, password set, step-up), keep **server-side session records**, and pin session cookies as host-prefixed **Secure / HttpOnly / SameSite**. |
| **FR46** | Disabling an account MUST **immediately revoke all outstanding refresh-token families and invalidate all server-side sessions** for that subject; the System Admin MUST be able to **force-terminate** a user's active sessions for incident response. |
| **FR47** | **Authorization codes** MUST be single-use, short-lived, and replay-detected (reuse revokes the issued tokens); **PKCE verifier binding** MUST be enforced server-side; **`nonce`** MUST be verified exactly once. |
| **FR48** | Issuing a new activation/reset token MUST **invalidate any prior outstanding token**; **completing** an activation or reset MUST invalidate all other active sessions and outstanding tokens; reset/activation **requests** MUST be rate-limited per-account and per-IP; **pending accounts MUST expire** after a bounded window. |
| **FR49** | CSV bulk import (FR30) MUST **validate and de-duplicate** rows against existing identities, enforce a **per-import size cap**, **throttle activation-email dispatch**, sanitize against CSV/formula injection, and present a **preview/confirm step**. |
| **FR50** | The service's **public unauthenticated endpoints** MUST be protected by **edge rate-limiting/abuse controls**; JWKS and discovery MUST be **cacheable**; admin-console actions MUST carry **CSRF protection + step-up re-auth** for sensitive operations (reset MFA, register client, manage admins). |

## 5. User Journeys

> Named-protagonist journeys; persona context lives inline. Protagonist names are illustrative `[ASSUMPTION]`.

**UJ-1 · Staff SSO login (returning)** — *Somchai, lab technician.* Opens the reporting app → redirected to the branded login → enters email + password, then his MFA code → redirected back, signed in. Later opens the document archive → **already signed in, no re-prompt.** *(FR1, FR2, FR7, FR13)*

**UJ-2 · New-hire first-login activation** — *Anong, newly hired epidemiologist.* HR creates her account → she receives an **activation email** → clicks the single-use link → **sets her own password and enrolls an MFA authenticator** → lands signed in, alerted her account is active. *(FR16, FR13, FR26, FR48)*

**UJ-3 · Self-service password reset** — *Somchai forgot his password.* Clicks "forgot password" → enters email (same generic confirmation regardless) → receives a single-use, short-lived link → sets a new password → **all his other sessions are invalidated** and he is alerted → signs in with MFA. No admin involved. *(FR17, FR20, FR48)*

**UJ-4 · HR onboarding a joiner** — *Pranee, HR administrator.* Creates the new hire (name + work email) → account is **pending**, activation email auto-sent. For a batch she **CSV-imports** through a **validate-and-preview** step. *(FR26, FR30, FR49)*

**UJ-5 · HR offboarding a leaver** — *Pranee, when someone resigns.* Finds the person → **disables** the account → they can **no longer obtain a login at any integrated app**, and their **tokens + sessions are revoked immediately**. Apps that bound their local session drop them within the token window. *(FR28, FR25, FR46)*

**UJ-6 · App-owner integration** — *Wirat, owner of an internal app.* Requests a client → System Admin registers it → Wirat follows the **integration guide**, copies the **reference client**, wires standard OIDC, validates tokens, bounds his local session, and maps the **work-email claim** to his app's records → his app is now behind SSO. *(FR32, FR40–FR43)*

**UJ-7 · Lost MFA device (admin-assisted, hardened)** — *Somchai loses his phone.* Contacts HR → **Pranee verifies his identity out-of-band and attests to it** → **resets his MFA**; Somchai is **notified** and his account returns to **re-activation**, so he re-sets his password and re-enrolls a new authenticator via a single-use link. *(FR15, FR29, FR44)*

**UJ-9 · Staff signs in with ThaiD** — *Somchai prefers ThaiD.* On the login screen he clicks **Login with ThaiD** → authenticates in the ThaiD app → Keycloak matches his **PID** to his canonical account, signs him in, and issues the same token his apps expect. No password or TOTP needed on this path. *(FR13a, FR1, FR7)*

**UJ-8 · System Admin registers a client** — *Rawinan, System Administrator.* An app owner requests onboarding → in the System console he **registers a new OIDC client** — exact-match redirect URIs, allowed scopes, client credentials → hands the credentials + integration guide to the app owner. *(FR32, FR40)*

## 6. Cross-cutting Non-Functional Requirements

> Grounded in authoritative sources (OAuth 2.0 Security BCP / RFC 9700, OWASP ASVS & cheat sheets, NIST SP 800-63B, Thailand PDPA B.E. 2562). Security rigor is the project's definition of done. Stated at capability level; exact parameters and the implementation that meets them are an **architecture** concern.

### A. Cryptography & Credential Custody
- **NFR1** — Passwords MUST be hashed with a **memory-hard algorithm (Argon2id-class)** at OWASP-recommended parameters, with a unique per-password salt, stored with **encryption-at-rest** and **restricted, network-isolated** datastore access.
- **NFR2** — MFA (TOTP) secrets encrypted at rest; the **ThaiD broker link reference** (FR13a) also encrypted at rest; email **activation/reset tokens** stored **hashed**, single-use, short-lived (≤ ~20 min), **≥ 128-bit entropy**.
- **NFR2a** — **Token-lifetime ceiling:** access/ID tokens MUST have a hard maximum lifetime of **≤ 15 minutes** (this is the bound behind FR9/FR25 "short-lived").
- **NFR3** — Token signing MUST use **asymmetric keys (RS256-class)**, published via the **JWKS endpoint with `kid`**, **rotated with an active/passive overlap window ≥ the max token lifetime**; `alg:none` rejected. Signing keys MUST be recoverable via **tested backup**; key custody hardened.
- **NFR4** — All transport over **TLS (HSTS)**; session cookies **host-prefixed, Secure / HttpOnly / SameSite**; the login UI MUST set a **CSP including `frame-ancestors 'none'`** plus standard security headers.

### B. Standards Conformance & Independent Validation
- **NFR5** — Conform to **OAuth 2.0 Security BCP (RFC 9700)** and OpenID Connect Core security requirements.
- **NFR6** — Built and verified to **OWASP ASVS Level 2** (Level 3 controls for credential/key handling), focused on Authentication, Session Management, Cryptography, and Access Control. The **ASVS L2 checklist MUST be independently reviewed by a second qualified person** before the pilot — a self-graded exam by the sole builder is not assurance.
- **NFR7** — Password policy per **NIST SP 800-63B**; brute-force protection per-account and per-IP using progressive delays (FR19).
- **NFR8** — **No hand-rolled crypto, token, or session logic** anywhere. Use **only established, maintained, audited components/libraries**; any custom security code is a red flag. *(Applies to every build approach — custom or self-hosted open-source.)*
- **NFR9** — CI pipeline MUST include **dependency/vulnerability scanning + SAST + secret scanning**.
- **NFR10** — **HARD GATES (user decision, 2026-06-21):** an **independent review of the ASVS L2 checklist is REQUIRED before the pilot** processes real staff data, **and an independent penetration test is a REQUIRED go-live gate before broad rollout.** Not "budget-permitting" — these are the substitute for the missing second reviewer and must pass.

### C. Privacy & Compliance (PDPA — Thailand, B.E. 2562)
- **NFR11** — Lawful basis = **contractual necessity / legal obligation / legitimate interest** (NOT employee consent), documented per processing purpose in a **Record of Processing Activities (RoPA)**; accountable owner named.
- **NFR12** — **No PDPA §26 sensitive personal data** is stored.
- **NFR13** — **Data minimization**; encryption at rest for credentials and secrets; **least-privilege** admin access.
- **NFR14** — **Retention & erasure:** audit logs **12 months** (FR38); identity records retained for the duration of employment. On a PDPA **erasure** request, identity PII not held under a legal-obligation basis is erased/pseudonymized, and the **data-subject reference in retained audit rows is pseudonymized rather than deleted** (preserving forensic integrity). The disposition of each data-subject right is stated (access + rectification supported; objection/restriction/portability/erasure honored or limited per documented legal basis).
- **NFR15** — **HARD GATE (user decision, 2026-06-21):** a completed **RoPA, lawful-basis documentation, DPO sign-off, and a tested 72-hour breach-response runbook are GATES before the pilot processes real staff data** — with a **named accountable owner and a date tied to pilot go-live**.

### D. Reliability & Operations
- **NFR16** — **SMTP is a monitored critical-path dependency** (delivery retries, monitoring, bounce handling); **admin-initiated reset (FR29/FR44) is the fallback** when self-service email fails.
- **NFR17** — The service is a **single point of dependency** for all integrated apps. **Target: 24/7 availability** — aim for no unplanned downtime, planned maintenance in **brief, announced windows**. Public endpoints MUST have **edge DoS/abuse protection** (availability is a security property; FR50). **Resilient deployment + tested backup/restore** of the identity/credential store, signing keys + configuration, and admin data is required — with a **stated RTO/RPO** and a **key-loss/compromise runbook**. **Single instance to start; high-availability deferred.** Precise SLO and topology defined in architecture.

### E. Scale, Performance & Localization
- **NFR18** — Sized for **~100–150 staff** plus the pilot apps; **target login/token-issuance latency p95 ≤ 500 ms** at that scale. Not a high-scale system.
- **NFR19** — **English-first** UI, **structured for localization** (externalized strings, FR12); **translation (Thai) is handled by the owner** after the UI stabilizes.

## 7. Success Metrics

### Go-live gates *(pass/fail)*
| ID | Metric | Target |
|----|--------|--------|
| **SM1** | Pilot-app logins routed exclusively through envocc-sso | **100%** — zero separate logins remain |
| **SM2** | Single authentication reaches all integrated apps in-session | **0 re-authentications** within a valid session |
| **SM3** | Onboard/offboard completed **from the console alone** | **100%** |
| **SM4** | MFA enforced for all staff | **100%** of active accounts |
| **SM5** | Outstanding security defects (token/session/credential-storage class) at go-live | **0**, with **OWASP ASVS L2 passed *and independently reviewed*** (NFR6/NFR10) |
| **SM6** | **PDPA gates** (RoPA, lawful-basis doc, DPO sign-off, tested breach runbook) complete **before the pilot processes real staff data** | **Done**, owner + date (NFR15) |
| **SM7** | **Independent penetration test** passed | **Before broad rollout** (NFR10) |

### Health metrics *(tracked post-launch)*
| ID | Metric | Target |
|----|--------|--------|
| **SM8** | Self-service password-reset completion (no admin) | **≥ 95%** complete unaided |
| **SM9** | Service availability | **High availability — aim for 24/7** with only brief, announced maintenance windows (single-instance baseline in v1; NFR17) |
| **SM10** | Staff with more than one active canonical identity | **0** (reconciliation integrity) |

### Counter-metrics *(guard against gaming / unintended harm)*
| ID | Watching for… | Initial threshold † |
|----|---------------|---------------------|
| **CM1** | Legitimate staff locked out by over-tight controls | **< ~5 legitimate-staff lockouts/week** |
| **CM2** | Admin reset-ticket load **and abuse** (abuse alerts, not just volume — FR44) | **< ~5 admin-handled tickets/week**; any spike alerts |
| **CM3** | New-hire accounts that never complete activation (expired per FR48) | low / actively chased down |

† *Provisional starting thresholds for ~150 staff; recalibrate once the pilot establishes a real baseline.*

## 8. Risks & Open Questions

### Risks & mitigations
| ID | Risk | Compensating controls |
|----|------|----------------------|
| **R1** ⚠️ *headline* | **Built and operated solo, without independent security review** | Audited components only, **no hand-rolled security code** (NFR8); CI dependency-scan + SAST + secret-scan (NFR9); **independent ASVS L2 review (pre-pilot) + independent penetration test (pre-broad-rollout) as HARD GATES** (NFR10); tight v1 surface; phased rollout |
| **R2** | **Solo operator can perform every privileged action and is the only reader of the log** | **Append-only, off-host audit log** (FR38) + **scheduled out-of-band copy to a named second person** (FR39); **audit-log reads are themselves audited** (FR34); named as an explicitly accepted residual where no second reviewer can be staffed |
| **R3** | **Single point of failure** — downtime = no logins anywhere | Resilient deployment + edge DoS/abuse protection (NFR17, FR50); tested backup/restore with stated RTO/RPO |
| **R4** | **Signing-key loss or theft is catastrophic** — total impersonation | Key rotation + active/passive overlap (NFR3); recovery via **tested backup**; compromise/rotation runbook (NFR17) |
| **R5** | **Email/SMTP failure blocks activation + reset** | Monitoring, retries, bounce handling + **admin-reset fallback** (NFR16) |
| **R6** | **Reconciliation errors** — duplicate or wrong canonical identities during seeding | HR-authoritative roster; unique work-email key; validated import (FR49); **SM10/CM3 = 0 duplicates** |
| **R7** | **Adoption stall** — app owners self-integrate; if it's hard, rollout stalls | Integration guide + **reference client** (FR40–43); prove with the pilot |
| **R8** | **TOTP is phishable** (real-time AITM) — phishing-resistant auth is post-v1 | **Named, accepted v1 residual** with a roadmap commitment to WebAuthn; **Login with ThaiD** (FR13a) offers a stronger alternative for staff who opt in |
| **R8a** | **ThaiD login adds a dependency on DOPA** (availability for the ThaiD path) | Brokered as **Keycloak realm config** (no hand-rolled auth, NFR8-aligned); the **email+password+TOTP path remains the always-available fallback**, so DOPA downtime never blocks all logins; dev/CI use a mock IdP; confirm RP terms with DOPA |
| **R9** | **PDPA exposure attaches at the pilot**, not "broad rollout" | NFR11–15 + RoPA + breach runbook + **DPO/legal sign-off gated to the pilot** (NFR15) |

### Open questions *(carried into architecture / integration)*
| ID | Question | Status |
|----|----------|--------|
| **OQ1** | Which **1–2 apps are the pilot**, and what are their stacks? | **Open** |
| **OQ2** | **Build approach** — ground-up custom vs self-hosted Keycloak vs self-hosted Authentik? Whichever is chosen MUST deliver **full EnvOcc ownership of the branded UX** (login + admin), not vendor stock screens — a scored selection criterion. | **Open — the core architecture decision** (PRD stays capability-level) |
| **OQ3** | Who is the **named second person / DPO** (FR39 audit copy + PDPA sign-off)? | **Open** |
| **OQ4** | **Securing the resource/budget for the independent assessment.** Note: the assessment itself is a **required hard gate** (NFR10) — only *obtaining and funding it* is open. | **Open** |

### Standing assumptions *(flagged for confirmation downstream)*
- **[ASSUMPTION]** Pilot apps are **confidential server-side web clients** — public/SPA clients are still supported via PKCE, but client-auth method and token storage differ; confirm at integration.
- **[ASSUMPTION]** Protagonist names (Somchai, Anong, Pranee, Wirat) are **illustrative**.

---

## Appendix A — Glossary

| Term | Canonical meaning |
|------|-------------------|
| **Canonical identity** | The single authoritative identity record for one staff member; the service is its system of record (FR21). |
| **Stable subject** | The service's durable internal identifier for a canonical identity, emitted in tokens and never reused (FR21). |
| **Reconciliation key (work email)** | The unique work email emitted as a token claim that integrating apps match against their existing local accounts (FR22, FR42). |
| **Lifecycle state** | One of *pending activation → active → disabled* (FR24). |
| **Relying Party (RP)** | An integrated application that delegates authentication to the service. |
| **OIDC client** | A registered RP with credentials, redirect URIs, and scopes (FR32). |
| **Activation link** | The single-use, time-limited email link by which a new user first sets a password and enrolls MFA (FR16). |
| **ThaiD** | Thailand's national digital identity app (DOPA). In envocc-sso it is an **alternative login method** offered via **brokered federation** — Keycloak brokers it and remains the IdP to relying parties; ThaiD is not the identity store. Linked to a staff account by **national ID (PID)** (FR13a). |
| **PID (national ID)** | The Thai national identification number ThaiD asserts; used as the key to link a "Login with ThaiD" sign-in to the correct canonical staff account (FR13a). |
| **System Admin / HR Admin** | The two-role separation of duties — service administration vs. employee-record lifecycle (§2). |
