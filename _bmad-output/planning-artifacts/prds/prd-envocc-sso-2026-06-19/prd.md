---
title: "Product Requirements Document — envocc-sso"
status: final
created: 2026-06-19
updated: 2026-06-20
---

# Product Requirements Document — envocc-sso

> Built section-by-section via the BMad PRD coaching workflow, then hardened against an adversarial security & compliance review. Security rigor — not feature count — is the definition of done.

---

## 1. Vision & Problem

**envocc-sso is EnvOcc's first single sign-on and central identity system — the HR-administered single source of truth for who works here.** It collapses a dozen scattered per-app logins into one branded, MFA-protected identity, and gives HR one console to grant and revoke access across the organization. Its ambition is to become the authentication layer for *all* of EnvOcc's internal applications; v1 proves the model by authenticating staff for the first pilot apps — answering *who you are*, not yet *what you may do* — with **security rigor, not feature count, as the definition of done**.

**The problem it kills:** today the same ~100–150 people exist as a dozen disconnected accounts that no single system can see as one person — *Somchai in the lab system, Somchai in the reporting tool, Somchai in the document archive*. Each app has its own login and its own user table. There is no central record of who works here, no single point to enforce a password policy or require MFA, and no reliable way to confirm that someone who left is actually locked out everywhere. For a division handling occupational and environmental health work, scattered and un-revoked access is a genuine security and governance liability.

**Two co-equal halves.** This product is not "a login page with an admin screen bolted on." It is **two first-class halves**: the **staff identity experience** (login, MFA, self-service recovery) and the **HR/admin control plane** (the joiner/mover/leaver lifecycle). The admin console is a co-equal half of the product, not an afterthought.

**Mandate & guiding constraints (load-bearing context):**
- Building in-house is an **organizational mandate** — **confirmed to permit a self-hosted open-source component.** The mandate's intent is **sovereignty and control** (no foreign SaaS, no data leaving the ministry, fully inspectable code), which a **self-hosted Keycloak on EnvOcc's own on-prem servers satisfies.** We therefore **adopt Keycloak as the reviewed, CVE-patched auth engine** and **build the custom HR/System admin layer in-house as a Ruby on Rails app over Keycloak's Admin REST API.** This *resolves* the earlier honest admission that off-the-shelf would be "faster and safer" (addendum §A): we take the safer path for the credential-handling core while keeping the custom control plane in-house, in a language the team is fluent in.
- **Security rigor is the definition of done**; there is **no fixed deadline** — readiness gates release.
- envocc-sso becomes the **sole system of record for credentials** (no external AD/LDAP/HR feed exists) — persisted in **Keycloak's store (on-prem PostgreSQL)**, with the **Rails layer as the HR/System control plane** over it.
- Built and maintained **solo**; rollout is **phased**, proving the model on 1–2 pilot apps first.

---

## 2. Users & Stakeholders

| Role | Who | What they need | Success looks like |
|------|-----|----------------|--------------------|
| **Staff** (~100–150) | Non-technical end users | One login to reach every integrated app; painless self-recovery | Log in once, no password sprawl, reset their own password without calling anyone |
| **HR Administrator** | Owner of the employee lifecycle; the **single source of truth** for "who is a valid employee" | Provision a person once, disable a leaver once — *with confidence it takes effect everywhere* | Onboard/offboard fully from the console alone |
| **System Administrator** | The technical owner (Rawinan) | Register apps as OIDC clients, manage admin users, configure security policy | The IdP runs, apps are onboarded, separation of duties from HR is enforced |
| **App Owner / team** | Engineers integrating their apps | A clear guide + a stable IdP | Wire their app in as an OIDC client without deep auth expertise |

*Admin model:* **two-role separation of duties** — the System Administrator administers the IdP itself; the HR Administrator manages only employee records.

---

## 3. Scope (v1 boundary)

### In scope — v1
- **OIDC Identity Provider** — Authorization Code flow + PKCE; IdP-hosted login (credentials never transit apps).
- **Central user store** — the HR-administered system of record for identity.
- **Branded staff login** + **MFA (TOTP)** + **self-service password reset** (email).
- **First-login activation** — admin creates account → emailed activation link → user sets own password.
- **HR Admin console** (employee lifecycle) **+ System Admin console** (clients, admins, security config).
- **Identity reconciliation** — *operational seeding from HR's roster + a canonical-key claim contract*: the IdP emits a stable subject plus the **work-email reconciliation key**, which integrating apps match against their existing local accounts. Console provides **create / search / validated CSV bulk-import**. **No automated merge engine.**
- **Operational account-protection controls** — identity-proofing + user-notification on admin resets, session-fixation defenses, server-side session/refresh-token revocation on disable, admin forced-logout, and abuse protection on public endpoints (see FG-8).
- **Audit log** — authentication events + admin actions, append-only and shipped off-host (compliance-driven; see FG-6).
- **OIDC integration guide** for app owners (a v1 deliverable).

### Validation activity (not a product feature)
- **Pilot integration** of the first 1–2 apps is performed by the System Administrator to prove the IdP and to source the integration guide from real experience.

> **Note — when PDPA attaches:** the **pilot is live processing of real staff personal data** the moment the first real employee activates. PDPA obligations attach *then*, not at "broad rollout" — so the compliance gates in NFR15 are tied to the pilot, not to a later date.

### Out of scope / deferred — v1
- **Centralized authorization** (roles / groups / permissions) — stays inside each app: *who you are, not what you may do*.
- Wiring all 10–15 apps — each app owner does their own integration.
- External / public / partner users — internal staff only.
- Social login, external-IdP federation, SCIM provisioning, passwordless / WebAuthn *(phishing-resistant auth — see named residual risk R8)*.
- **Automated cross-app account merge** — the IdP cannot see app databases; reconciliation is seeding + claim contract.
- **Back-channel Single Logout (SLO)** — v1 covers RP-initiated logout *plus* IdP-side forced logout (FR46); cross-app back-channel propagation is deferred.
- Refresh tokens are **optional** in v1 (architecture's decision); if issued, they must rotate with reuse-detection (FR9) and be revocable on disable (FR46).

---

## 4. Functional Requirements

> FRs are globally numbered with stable IDs that survive regrouping. Requirements are stated at the capability/contract level; exact cryptographic parameters and library choices are deferred to architecture (see addendum) and echoed as NFRs in Section 5. Domain terms are defined once in the **Glossary** (Appendix A).

### FG-1 — OIDC Authentication & SSO *(IdP core)*

| ID | Functional Requirement |
|----|------------------------|
| **FR1** | The IdP MUST authenticate staff using the OIDC **Authorization Code flow with PKCE** for all client applications. |
| **FR2** | The IdP MUST **host the login experience itself**; user credentials MUST never transit relying-party applications. |
| **FR3** | The IdP MUST **NOT** offer the Implicit or Resource Owner Password Credentials (ROPC) grant types. |
| **FR4** | Each client MUST register its redirect URIs, and the IdP MUST enforce **exact-match** redirect URIs (no wildcard/substring matching). |
| **FR5** | On successful authentication the IdP MUST issue an **asymmetrically-signed ID token** carrying the agreed identity claims (including the work-email reconciliation key), and MUST publish its signing keys via a **JWKS endpoint** (with `kid`) for client validation. |
| **FR6** | The IdP MUST bind each authentication request to its session using **`state`** (CSRF) and **`nonce`** (ID-token replay protection). |
| **FR7** | The IdP MUST establish a **single sign-on session** so an authenticated staff member can reach every integrated app **without re-entering credentials**, until the session ends. |
| **FR8** | The IdP MUST enforce both **idle and absolute session lifetimes**, requiring re-authentication when either expires. |
| **FR9** | The IdP MUST issue **short-lived tokens** (lifetime ceiling per NFR2a); where refresh tokens are issued, it MUST **rotate them on use** with reuse-detection that revokes the token family on replay. |
| **FR10** | The IdP MUST support **RP-initiated logout** — terminating the IdP session and honoring a validated post-logout redirect. |
| **FR11** | The IdP MUST expose a standard **OIDC discovery document** (`.well-known`) so clients can self-configure endpoints. |

### FG-2 — Staff Authentication Experience

| ID | Functional Requirement |
|----|------------------------|
| **FR12** | The IdP MUST present a **branded login experience** matching the EnvOcc brand reference (named brand asset to be supplied), built so that **all UI copy is externalized strings** (no hard-coded text) for localization. |
| **FR13** | The IdP MUST enforce **MFA via TOTP** for all staff; users **enroll a TOTP authenticator** during first-login activation. |
| **FR14** | The IdP MUST verify TOTP codes with a **bounded clock-drift window**, **rate-limit** verification, and treat a verified code as **single-use within its time step** (reject replay inside the window). |
| **FR15** | The IdP MUST allow an administrator to **reset a user's MFA enrollment** as admin-assisted recovery — subject to the safeguards in **FR44**. *(Self-service recovery codes deferred to post-v1.)* |
| **FR16** | **First-login activation:** an admin-created account starts **pending**; the user receives a **single-use, time-limited activation link** by email and, on first sign-in, **sets their own password and enrolls MFA**. Activation MUST **alert the user** and is subject to the token-hygiene rules in **FR48**. |
| **FR17** | The IdP MUST offer **self-service password reset by email** using a **single-use, short-lived, high-entropy** token. A reset MUST **not** clear MFA enrollment, MUST alert the user on completion, and is subject to **FR48**. |
| **FR18** | **Password policy** MUST require a **minimum length of ≥ 12 characters**, support long passphrases (≥ 64), **screen new passwords against known-breached lists**, and MUST **NOT** impose composition rules or forced periodic rotation. |
| **FR19** | The IdP MUST apply **brute-force protection** on login and TOTP verification using **progressive delays** (preferred over hard per-account lockout, to avoid targeted denial-of-service against a named user — see FR50), per-account and per-IP. |
| **FR20** | Login, activation, and reset flows MUST be **enumeration-resistant** — identical, generic responses whether or not an account exists. |

### FG-3 — Identity & User Store *(system of record)*

| ID | Functional Requirement |
|----|------------------------|
| **FR21** | The IdP MUST maintain **exactly one canonical identity per staff member** as the system of record, identified by a **stable internal subject identifier** (`sub`, never reused). |
| **FR22** | Each identity MUST carry a **unique work email**, which serves as the **reconciliation key** emitted as a claim to integrating apps. |
| **FR23** | The IdP MUST store only the **minimal attribute set** required for authentication and identification (data minimization) and MUST **NOT** store PDPA §26 sensitive personal data. |
| **FR24** | Each identity MUST have a defined **lifecycle state** — *pending activation → active → disabled* — with controlled transitions. |
| **FR25** | **Disabling an account MUST immediately block all new authentication** for that person across every integrated app, and MUST trigger the server-side revocation in **FR46**. Lockout of an app's *already-running local session* is bounded by that app's session lifetime (v1 has no back-channel SLO) — integrating apps MUST bound their local session to the IdP token lifetime per **FR41**; until they do, disable is not effective at that app until its local session expires. This residual is named and accepted. |

### FG-4 — HR Admin Console *(employee lifecycle)*

| ID | Functional Requirement |
|----|------------------------|
| **FR26** | The HR Admin MUST be able to **create a user** (name + work email), placing the account in **pending** state and **sending the activation email** (FR16). |
| **FR27** | The HR Admin MUST be able to **search and list users** and view each account's **lifecycle state**. |
| **FR28** | The HR Admin MUST be able to **enable or disable** an account (joiner/mover/leaver), with disable behaving per FR25/FR46. |
| **FR29** | The HR Admin MUST be able to **trigger a password reset** and **reset MFA enrollment** for a user, as front-line account support — subject to **FR44**. |
| **FR30** | The HR Admin MUST be able to **bulk-create pending accounts via CSV import** to seed the canonical roster, subject to the import validation in **FR49**. |
| **FR31** | The HR Admin MUST be able to **correct a user's minimal profile attributes** (e.g., name, work email); changing the **reconciliation key (work email)** is a **controlled action** flagged for its reconciliation impact. |

*Leavers are **disabled, not deleted** in v1 (preserves audit trail + reconciliation); PDPA erasure/retention reconciliation is in NFR14.*

### FG-5 — System Admin Console *(IdP administration)*

| ID | Functional Requirement |
|----|------------------------|
| **FR32** | The System Admin MUST be able to **register and manage OIDC client applications** — client credentials, **exact-match redirect URIs** (FR4), and allowed scopes — and to **rotate a client secret with a dual-secret overlap window** so rotation does not break a live RP. |
| **FR33** | The System Admin MUST be able to **manage admin users** — create/disable HR Admins and System Admins and **assign their role** — enforcing the two-role separation of duties. |
| **FR34** | The System Admin MUST be able to **view and export the audit log** (FG-6); **every read/export of the audit log MUST itself be audited** to the off-host sink (FR39). |

*Security policy (password rules, token/session lifetimes, MFA enforcement, throttling thresholds) is **vetted deployment configuration**, not a console screen, in v1.*

### FG-6 — Audit Logging *(compliance)*

| ID | Functional Requirement |
|----|------------------------|
| **FR35** | The IdP MUST record **authentication events** — login success/failure (throttled vs. failed distinguished), MFA outcome, **session creation/termination and expiry**, logout, activation, and password reset — each with **source IP, user-agent/device**. |
| **FR36** | The IdP MUST record **administrative actions** — user create/enable/disable, password/MFA reset (with the FR44 identity-proof attestation), profile change, client registration/secret rotation, signing-key rotation, and admin-user changes. |
| **FR37** | The IdP MUST record **token & key events** — token issuance, refresh-rotation and reuse-detection trips (FR9), and JWKS/signing-key rotation — sufficient to scope which sessions and keys an incident touched. |
| **FR38** | The audit log MUST be **append-only and integrity-verifiable** (e.g., hash-chained or signed sequence), **shipped off-host to storage the application/operator cannot rewrite**, and **retained for 12 months** (aligns to realistic breach detection-to-disclosure windows; see NFR14/NFR15). |
| **FR39** | The audit log MUST **NOT** store credentials, MFA secrets, or token values, MUST not leak account existence, and a **scheduled copy MUST be delivered out-of-band to a named second person** (e.g., department DPO/manager) so the solo operator is not the sole reader of his own privileged actions (compensates R1/C2). |

### FG-7 — App-Owner Integration Enablement

| ID | Functional Requirement |
|----|------------------------|
| **FR40** | The project MUST publish an **OIDC integration guide** enabling an app owner to integrate using **standard OIDC libraries**; the **reference client (FR43)** is the testable artifact that demonstrates "without deep auth expertise." |
| **FR41** | The guide MUST document the **full integration contract** — discovery (FR11), Auth Code + PKCE (FR1), redirect-URI registration (FR4/FR32), ID-token/JWKS validation (FR5) including `iss`/`aud`/`exp`/`nonce`/`azp` checks — and MUST **require RPs to bound their local session lifetime to the IdP token lifetime** and to honor `kid` with a **bounded JWKS cache TTL**. |
| **FR42** | The guide MUST document the **identity claim contract** — the stable subject + **reconciliation key (work email)** — and **how an app maps an SSO identity to its existing local account** (FR22). |
| **FR43** | The project MUST provide a **minimal reference/sample OIDC client** — the documented pilot integration — demonstrating the contract end-to-end as a copyable adoption asset. |

### FG-8 — Operational Security & Account-Protection Controls *(added from the adversarial security review)*

| ID | Functional Requirement |
|----|------------------------|
| **FR44** | Admin-initiated MFA/password reset (FR15/FR29) MUST require a **documented out-of-band identity-verification step** that the admin **attests to in the audit record**; MUST **notify the affected user** on every reset of their credentials/MFA; and an MFA reset MUST return the account to **pending re-activation** (re-enroll MFA *and* re-set password via single-use email link) — never leaving a "password known, MFA cleared" window. Admin resets MUST be rate-limited with an **abuse alert** (not merely counted). |
| **FR45** | The IdP MUST **regenerate the session identifier on every authentication-state transition** (login, MFA success, password set, step-up), keep **server-side session records**, and pin session cookies as host-prefixed **Secure / HttpOnly / SameSite**. |
| **FR46** | Disabling an account MUST **immediately revoke all outstanding refresh-token families and invalidate all server-side IdP sessions** for that subject; the System Admin MUST be able to **force-terminate a user's active IdP sessions** for incident response. |
| **FR47** | **Authorization codes** MUST be single-use, short-lived, and replay-detected (reuse revokes the issued tokens); **PKCE verifier binding** MUST be enforced server-side; **`nonce`** MUST be verified exactly once. |
| **FR48** | Issuing a new activation/reset token MUST **invalidate any prior outstanding token** for that account; **completing** an activation or reset MUST invalidate all other active sessions and outstanding tokens; reset/activation **requests** MUST be rate-limited per-account and per-IP; **pending accounts MUST expire** after a bounded window and require re-issue. |
| **FR49** | CSV bulk import (FR30) MUST **validate and de-duplicate** rows against existing identities, enforce a **per-import size cap**, **throttle activation-email dispatch**, sanitize against CSV/formula injection, and present a **preview/confirm step** before creating accounts. |
| **FR50** | The IdP's **public unauthenticated endpoints** (authorize, token, JWKS, discovery, reset/activation) MUST be protected by **edge rate-limiting/abuse controls**; JWKS and discovery MUST be **cacheable**; admin-console actions MUST carry **CSRF protection + step-up re-auth** for sensitive operations (reset MFA, register client, manage admins). |

---

## 5. Cross-cutting Non-Functional Requirements

> Grounded in authoritative sources (OAuth 2.0 Security BCP / RFC 9700, OWASP ASVS & cheat sheets, NIST SP 800-63B, Thailand PDPA B.E. 2562). Security rigor is the project's definition of done.

### A. Cryptography & Credential Custody
- **NFR1** — Passwords are hashed by **Keycloak's native Argon2id provider** (OWASP floor: ≥19 MiB memory, ≥2 iterations, parallelism 1) with a unique per-password salt, stored in Keycloak's on-prem PostgreSQL with **encryption-at-rest and restricted, network-isolated DB access**. *No application-level pepper:* Keycloak's hashing does not use one; the stolen-database threat is met by salt + at-rest encryption + DB isolation rather than a separately-custodied secret. *(Removes the former Vault-held pepper and its loss-catastrophe.)*
- **NFR2** — TOTP secrets encrypted at rest; email **activation/reset tokens** stored **hashed**, single-use, ≤~20 min lifetime, ≥128-bit entropy.
- **NFR2a** — **Token-lifetime ceiling:** access/ID tokens MUST have a hard maximum lifetime of **≤ 15 minutes** (this is the bound behind FR9/FR25 "short-lived").
- **NFR3** — Token signing uses **Keycloak realm keys** — **asymmetric RS256-class**, published via the realm **JWKS endpoint with `kid`**, **rotated via Keycloak's key providers with an active/passive overlap window ≥ the max token lifetime**; `alg:none` rejected. Private keys live in Keycloak's on-prem store, recoverable via **realm export + database backup**; a hardware-/Vault-backed key provider is an optional future enhancement (deferred).
- **NFR4** — All transport over **TLS (HSTS)**; session cookies **host-prefixed, Secure / HttpOnly / SameSite=Lax** (justify any `None`); the login UI MUST set a **CSP including `frame-ancestors 'none'`** (clickjacking) plus standard security headers.

### B. Standards Conformance & Independent Validation
- **NFR5** — Conform to **OAuth 2.0 Security BCP (RFC 9700)** and OpenID Connect Core security requirements.
- **NFR6** — Built and verified to **OWASP ASVS Level 2** (Level 3 controls for credential/key handling). Because the auth engine is now **Keycloak**, ASVS verification targets the far smaller custom surface — **the Keycloak deployment-hardening configuration and the Rails admin layer** — focusing on Authentication, Session Management, Cryptography, and Access Control. The **ASVS L2 checklist (SM5) MUST be independently reviewed by a second qualified person** before it can be marked passed — a self-graded exam by the sole builder is not assurance.
- **NFR7** — Password policy per **NIST SP 800-63B**; brute-force protection per-account and per-IP using progressive delays (FR19).
- **NFR8** — The auth engine is **Keycloak** — an OpenID-certified, community-reviewed, CVE-patched implementation; there is **no hand-rolled crypto, token, or session logic** anywhere in the system. The **Rails admin layer uses only established, maintained gems** and **never re-implements an auth primitive** — it drives Keycloak through its Admin REST API. Any custom security code remains a red flag.
- **NFR9** — CI pipeline includes **dependency/vulnerability scanning + SAST**.
- **NFR10** — An **independent penetration test is a REQUIRED go-live gate before broad rollout**, and an **independent review of the ASVS L2 checklist is required before the pilot** processes real staff data. The in-house *build* mandate does not forbid buying **one independent assessment** — the cheapest substitute for the missing second reviewer.

### C. Privacy & Compliance (PDPA)
- **NFR11** — Lawful basis = **contractual necessity / legal obligation / legitimate interest** (NOT employee consent), documented per processing purpose in a **Record of Processing Activities (RoPA)**; accountable owner named (NFR15).
- **NFR12** — **No PDPA §26 sensitive personal data** is stored; if biometric MFA is ever introduced it MUST be gated by explicit consent and heightened safeguards.
- **NFR13** — **Data minimization**; encryption at rest for credentials and secrets; **least-privilege** admin access.
- **NFR14** — **Retention & erasure reconciliation:** audit logs **12 months** (FR38); identity records retained for the duration of employment. On a PDPA **erasure** request, identity PII not held under a legal-obligation basis is erased/pseudonymized, and the **data-subject reference in retained audit rows is pseudonymized rather than deleted** (preserving forensic integrity). The PRD states the disposition of each data-subject right — **access + rectification supported via the console; objection/restriction/portability/erasure honored or limited per the documented legal basis**, with the reason stated.
- **NFR15** — A completed **RoPA, lawful-basis documentation, DPO sign-off, and a tested 72-hour breach-response runbook are GATES before the pilot processes real staff data** — with a **named accountable owner (Rawinan + the department DPO/legal) and a date tied to pilot go-live**.

### D. Reliability & Operations
- **NFR16** — **SMTP is a monitored critical-path dependency** (delivery retries, monitoring, bounce handling); **admin-initiated reset (FR29/FR44) is the fallback** when self-service email fails.
- **NFR17** — The IdP is a **single point of dependency** for all integrated apps. **Target: 24/7 availability** — aim for **no unplanned downtime**, planned maintenance in **brief, announced windows**. Public endpoints MUST have **edge DoS/abuse protection** (availability is a security property here, FR50). **Resilient deployment + tested backup/restore** of **Keycloak's PostgreSQL (identities/credentials/sessions), the Keycloak realm configuration + realm keys (export), and the Rails application database** is required — with a **stated RTO/RPO** and a **key-loss / compromise runbook** (loss is catastrophic — a backup never restored is not a control). Precise SLO and HA topology defined in architecture.

### E. Scale, Performance & Localization
- **NFR18** — Sized for **~100–150 staff** plus the pilot apps; **target login/token-issuance latency p95 ≤ 500 ms** at that scale (formal SLO refined in architecture). Not a high-scale system.
- **NFR19** — **English-first** UI, **structured for localization**; **security-critical strings** (activation, reset, MFA enrollment, "do not share this link" warnings) **prioritized for Thai** so non-technical staff comprehend the anti-phishing guidance, even while the rest stays English-first until the UI stabilizes.

---

## 6. User Journeys

> Captured with named protagonists; persona context lives inline. These feed the UX phase. *(Protagonist names are illustrative — `[ASSUMPTION]`.)*

**UJ-1 · Staff SSO login (returning)** — *Somchai, lab technician.* Opens the reporting app → redirected to the envocc-sso branded login → enters email + password, then his TOTP code → redirected back, signed in. Later opens the document archive → **already signed in, no re-prompt**. *(FR1, FR2, FR7, FR13)*

**UJ-2 · New-hire first-login activation** — *Anong, newly hired epidemiologist.* HR creates her account → she receives an **activation email** → clicks the single-use link → **sets her own password and enrolls a TOTP authenticator** → lands signed in, and is **alerted that her account was activated**. *(FR16, FR13, FR26, FR48)*

**UJ-3 · Self-service password reset** — *Somchai forgot his password.* Clicks "forgot password" → enters email (same generic confirmation regardless) → receives a **single-use, short-lived reset link** → sets a new password → **all his other sessions are invalidated** and he is alerted → signs in with MFA. No admin involved. *(FR17, FR20, FR48)*

**UJ-4 · HR onboarding a joiner** — *Pranee, HR administrator.* Creates the new hire (name + work email) → account is **pending**, activation email auto-sent. For a batch she **CSV-imports** them through a **validate-and-preview** step. *(FR26, FR30, FR49)*

**UJ-5 · HR offboarding a leaver** — *Pranee, when someone resigns.* Finds the person → **disables** the account → they can **no longer obtain a login at any integrated app**, and their **refresh tokens + IdP sessions are revoked immediately**. Apps that bound their local session to the IdP (per the guide) drop them within the token window. *(FR28, FR25, FR46)*

**UJ-6 · App-owner integration** — *Wirat, owner of an internal app.* Requests a client → System Admin registers it → Wirat follows the **integration guide**, copies the **reference client**, wires standard OIDC, validates tokens, bounds his local session to the IdP, and maps the **work-email claim** to his app's existing user records → his app is now behind SSO. *(FR32, FR40–FR43)*

**UJ-7 · Lost MFA device (admin-assisted, hardened)** — *Somchai loses his phone.* Contacts HR → **Pranee verifies his identity out-of-band** and attests to it → **resets his MFA**; Somchai is **notified** and his account returns to **re-activation**, so he re-sets his password and re-enrolls a new authenticator via a single-use link. *(FR15, FR29, FR44)*

**UJ-8 · System Admin registers a client** — *Rawinan, System Administrator.* An app owner requests onboarding → in the System Admin console he **registers a new OIDC client** — exact-match redirect URIs, allowed scopes, client credentials → hands the credentials + integration guide to the app owner. *(FR32, FR40)*

---

## 7. Success Metrics

> **Go-live gates** are pass/fail per app; **health metrics** are tracked post-launch; **counter-metrics** guard against winning on paper while losing in reality.

### Go-live gates *(pass/fail)*
| ID | Metric | Target |
|----|--------|--------|
| **SM1** | Pilot-app logins routed exclusively through envocc-sso | **100%** — zero separate logins remain |
| **SM2** | Single authentication reaches all integrated apps in-session | **0 re-authentications** within a valid session |
| **SM3** | Onboard/offboard completed **from the console alone** | **100%** — no out-of-band account creation/removal |
| **SM4** | MFA enforced for all staff | **100%** of active accounts |
| **SM5** | Outstanding security defects (token / session / credential-storage class) at go-live | **0**, with the **OWASP ASVS L2 checklist passed *and independently reviewed*** (NFR6) |
| **SM6** | **PDPA gates** (RoPA, lawful-basis doc, DPO sign-off, tested breach runbook) complete **before the pilot processes real staff data** | **Done**, owner + date assigned (NFR15) |
| **SM7** | **Independent penetration test** passed | **Before broad rollout** (NFR10) |

### Health metrics *(tracked post-launch)*
| ID | Metric | Target |
|----|--------|--------|
| **SM8** | Self-service password-reset completion (no admin) | **≥ 95%** complete unaided |
| **SM9** | IdP availability | **24/7**, no unplanned downtime (NFR17) |
| **SM10** | Staff with more than one active canonical identity | **0** (reconciliation integrity) |

### Counter-metrics *(guard against gaming / unintended harm)*
| ID | Watching for… | Initial threshold † |
|----|---------------|---------------------|
| **CM1** | Legitimate staff locked out / failed logins from over-tight controls | **< 5 legitimate-staff lockouts/week** (≈ <3% of staff/week) |
| **CM2** | Admin support load **and abuse** from MFA-lost-device + reset tickets (abuse threshold alerts, not just volume — FR44) | **< 5 admin-handled MFA/password tickets/week**; any spike alerts |
| **CM3** | New-hire accounts that never complete activation (expired per FR48) | low / actively chased down |

† *CM1/CM2 are provisional starting thresholds for ~150 staff; recalibrate once the pilot establishes a real traffic baseline.*

---

## 8. Risks & Open Questions

### Risks & mitigations

| ID | Risk | Compensating controls |
|----|------|----------------------|
| **R1** ⚠️ *headline (now materially reduced)* | **Configuring + hardening Keycloak and building the custom Rails admin layer solo**, without an independent reviewer — the original, larger risk (a from-scratch IdP build) is **retired** in favor of a community-reviewed engine | **Community-reviewed, CVE-patched engine (Keycloak)** replaces the hand-built core; **config-as-code** (realm export in git, secrets stripped); follow the Keycloak hardening guide; **audited gems only, no hand-rolled security code** (NFR8); CI dep-scan + SAST (NFR9); ASVS L2 **independently reviewed** (NFR6) + **independent pen test gate** (NFR10) — now scoped to the small custom surface |
| **R2** | **Sole operator self-audits god-mode runtime actions** — can mint admins/clients/tokens and read the only log | **Append-only, off-host audit log** (FR38) + **scheduled out-of-band export to a named second person** (FR39); **audit-log reads are themselves audited** (FR34); named as an **explicitly accepted residual risk** where no second reviewer can be staffed |
| **R3** | **IdP is a single point of failure** — downtime = no logins anywhere; 24/7 raises the bar for a solo operator | Resilient deployment + edge DoS protection (NFR17, FR50); tested backup/restore with RTO/RPO |
| **R4** | **Signing-key loss or theft is catastrophic** — private-key theft = total impersonation | **Keycloak-managed realm keys** with rotation + active/passive overlap (NFR3); recovery via **realm export + DB backup**; compromise/rotation runbook + tested restore (NFR17). *(Pepper-loss removed — no application pepper under Keycloak.)* |
| **R5** | **Email/SMTP failure blocks activation + reset** | Monitoring, retries, bounce handling + **admin-reset fallback** (NFR16); reliable org relay confirmed |
| **R6** | **Reconciliation errors** — duplicate or wrong canonical identities during seeding | HR-authoritative roster (direct); unique work-email key; validated import (FR49); **SM10/CM3 = 0 duplicates** |
| **R7** | **Adoption stall** — app owners self-integrate; if it's hard, rollout stalls | Integration guide + **reference client** (FR40–43); prove with the pilot |
| **R8** | **TOTP is phishable** (real-time AITM) — WebAuthn is post-v1 | **Named, accepted v1 residual** with a roadmap commitment to WebAuthn — **now natively available in Keycloak**, so the deferral is low-cost to reverse; anti-phishing user guidance prioritized for Thai (NFR19) |
| **R9** | **PDPA compliance exposure** — obligations attach at the pilot, not "broad rollout" | NFR11–15 + RoPA + breach runbook + **DPO/legal sign-off gated to the pilot**, with owner + date |
| **R10** *(new — from the pivot)* | **Keycloak operational expertise** — solo operator must configure, harden, and upgrade Keycloak correctly; **misconfiguration is the new principal residual risk** | Config-as-code + self-review against the Keycloak hardening checklist; pinned Keycloak version; **pre-pilot independent review of the Keycloak configuration** (folds into NFR10) |
| **R11** *(new)* | **Admin-API coupling** — the Rails layer depends on Keycloak's Admin REST API staying stable across upgrades | Pin the Keycloak version; **wrap the Admin API behind a thin Rails adapter**; integration tests against a running Keycloak in CI (ties to NFR9) |
| **R12** *(new)* | **Two-runtime surface** — Keycloak (JVM) + Rails (Ruby) + a custom theme is more heterogeneous than one app | Containerized with clear boundaries (**Docker Compose** for dev, **Kamal** for the Rails deploy); **single Nginx security edge** fronting both; CI for both runtimes; minimal moving parts (no Redis/Vault in v1) |

### Open questions *(carried into architecture / integration)*
| ID | Question | Blocks… |
|----|----------|---------|
| **OQ1** | Which **1–2 apps are the pilot**, and their stacks? | integration, reference client |
| **OQ2** | **Build stack** (frontend / backend / DB)? | **Resolved** — self-hosted **Keycloak** (IdP) + **Ruby on Rails** (admin layer over the Admin REST API) + **PostgreSQL** + **Nginx**, on-prem via Docker. |
| **OQ3** | Who is the **named second reviewer / DPO** for R2 and the PDPA sign-off, and the independent-assessment budget? | R2/NFR10/NFR15 sign-off |

### Standing assumptions *(flagged for confirmation downstream)*
- **[ASSUMPTION]** Pilot apps are **confidential server-side web clients** — public/SPA clients are still supported via PKCE, but client-auth method and token storage differ; confirm at integration (per security review M1).
- **[ASSUMPTION]** Protagonist names (Somchai, Anong, Pranee, Wirat) are **illustrative**.

---

## Appendix A — Glossary

| Term | Canonical meaning |
|------|-------------------|
| **Canonical identity** | The single authoritative identity record for one staff member; the IdP is its system of record (FR21). |
| **Stable subject (`sub`)** | The IdP's durable internal identifier for a canonical identity, emitted in tokens and never reused (FR21). |
| **Reconciliation key (work email)** | The unique work email emitted as a token claim that integrating apps match against their existing local accounts (FR22, FR42). *Canonical surface form: "reconciliation key (work email)."* |
| **Lifecycle state** | One of *pending activation → active → disabled* (FR24). |
| **Relying Party (RP)** | An integrated application that delegates authentication to the IdP. |
| **OIDC client** | A registered RP with credentials, redirect URIs, and scopes (FR32). |
| **Activation link** | The single-use, time-limited email link by which a new user first sets a password and enrolls MFA (FR16). |
| **System Admin / HR Admin** | The two-role separation of duties — IdP administration vs. employee-record lifecycle (Section 2). |
