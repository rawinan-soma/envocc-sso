# PRD Addendum — envocc-sso

> Downstream depth that supports the PRD but doesn't belong in its main narrative — the build-vs-buy decision (now resolved), the parked roadmap, technical "how" for architecture, and the security posture. The PRD states *what*; this preserves the *why* and the *later*.
>
> **Updated 2026-06-20** — revised for the stack pivot to **self-hosted Keycloak (IdP) + Ruby on Rails (admin layer)**. See `sprint-change-proposal-2026-06-20.md` for the full change record.

---

## A. Options Considered — Build vs. Buy *(resolved)*

The in-house mandate was originally read as "build the IdP from scratch." The product owner has **confirmed the mandate permits a self-hosted open-source component**, because its true intent is **sovereignty and control** — on-prem, no foreign SaaS, no data leaving the ministry, fully inspectable code. A self-hosted **Keycloak** satisfies that intent.

- **Off-the-shelf is faster *and* safer for the auth core** — Keycloak delivers OIDC/OAuth, MFA (TOTP + WebAuthn), password policy, brute-force lockout, session/token/key management with rotation, email flows, and ongoing CVE patching, all community-reviewed. Re-implementing these solo was the headline risk (R1).
- **Branded login needs no custom engine** — Keycloak supports full custom themes (login/account/email), so the UX-control driver is satisfied by a **custom Keycloak theme** built from the `DESIGN.md` Ministry Bronze tokens.
- **The genuinely custom part stays in-house** — the **HR/System admin console, org audit views, integration guide, and reference client** are built as a **Ruby on Rails** app that drives Keycloak via its **Admin REST API** and signs admins in via Keycloak (OIDC). This keeps the control plane in a language the team is fluent in.
- **Outcome:** **adopt self-hosted Keycloak for the auth core (mandate-compliant) + build the custom admin layer in Rails.** The residual risk shifts from "did we implement crypto/tokens/sessions correctly" to "did we configure and harden Keycloak correctly + build the Rails layer correctly" — a **smaller, better-supported** surface (PRD R1 reframed; new R10–R12 named).

## B. Parked Roadmap (post-v1)

Rough priority order:
1. **Centralized authorization** — manage roles/groups in Keycloak, emit as token claims so apps stop maintaining their own role tables (the most natural next step; v1 is *who you are*, not *what you may do*).
2. **Migrate remaining apps** — all 10–15 behind SSO within ~a year of pilot success.
3. **Self-service MFA recovery** — recovery codes (v1 is admin-assisted only; Keycloak supports recovery codes natively, so this is low-cost to add).
4. **Back-channel Single Logout (SLO)** — propagate logout to all apps (v1 is RP-initiated only; Keycloak supports back-channel logout, also low-cost to enable later).
5. **Federation / external IdP + SCIM provisioning** — Keycloak has native user federation/brokering if org needs grow.
6. **Passwordless / WebAuthn** — stronger, phishing-resistant auth. **Now natively available in Keycloak** — the v1 TOTP-only decision is a scope choice, not a build constraint, and is cheap to reverse (R8).

## C. Downstream Technical Implications (for architecture)

- **Build stack** — **resolved (OQ2):** self-hosted **Keycloak** (IdP engine) + **Ruby on Rails** (admin layer over the Admin REST API) + **PostgreSQL** (separate databases for Keycloak and Rails) + **Nginx** (single security edge) — on-prem via Docker.
- **Password hashing** — **Keycloak's native Argon2id provider** at OWASP params (≥19 MiB / t≥2 / p=1), unique per-password salt. **No application pepper** (Keycloak does not use one); stolen-DB risk is met by salt + DB encryption-at-rest + network isolation.
- **Token & session lifetimes** — Keycloak realm settings: access/ID token lifespan **≤15 min**; **refresh-token rotation with reuse-revocation** enabled ("Revoke Refresh Token"); SSO idle + absolute session limits.
- **Signing-key management** — **Keycloak realm keys** (RS256-class), published at the realm JWKS endpoint with `kid`, rotated via Keycloak key providers with an **active/passive overlap window ≥ max token lifetime**. Key loss is catastrophic → recovery via **realm export + DB backup** (mandatory, tested). Optional HSM-/Vault-backed key provider deferred.
- **Account lifecycle (pending → active → disabled)** — modeled on Keycloak: *pending* = user created with outstanding **required actions** (`UPDATE_PASSWORD`, `CONFIGURE_TOTP`, `VERIFY_EMAIL`) and `emailVerified=false`; *active* = required actions cleared; *disabled* = `enabled=false` + session/token revocation via the Admin API.
- **Reconciliation key mechanics** — Keycloak emits the stable **`sub`** (Keycloak user id, never reused) **plus the work-email claim** (native `email` claim + protocol mapper); integrating apps match on email at first-login, then persist the durable `sub`.
  - **Why work email:** reliable org email already exists for every staff member, is central to activation/reset, and every legacy app already stores it — the lowest-friction key. National ID rejected for PDPA data-minimization weight; a consistent dedicated staff ID was not assumed. **Residual:** if a work email changes, the durable `sub` remains the stable link (apps told to persist `sub` — FR41/FR42).
- **RP local-session bounding** — relying parties run their own local session after consuming the ID token; the integration guide (FR41) MUST require RPs to bound that session to the Keycloak token lifetime and honor `kid` with a bounded JWKS cache TTL, else IdP-side disable (FR25/FR46) is not effective at that app until its local session expires.
- **Client authentication method** — for confidential clients prefer **`private_key_jwt`** (Keycloak "Signed JWT" client authenticator with the client's JWKS), which gives **key-rotation overlap** and satisfies FR32's dual-secret-overlap intent (Keycloak holds only one client *secret* at a time); coordinated secret rotation is the fallback. Resolve the confidential-vs-public client assumption before integration (security review M1).
- **Admin REST API integration** — Rails drives Keycloak (create/disable users, set required actions, trigger `execute-actions-email`, register clients, manage realm roles, read events) through a **thin Rails adapter** over the Admin REST API; pin the Keycloak version and integration-test against a running instance (R11).
- **SMTP relay** — configured in Keycloak (forgot-password, verify-email, execute-actions-email); deliverability is a monitored critical-path dependency (retries, bounce handling) with **Rails-triggered admin reset as fallback**.
- **Availability / HA topology** — supports the **24/7** target (NFR17): resilient deployment, backup/recovery, brief announced maintenance windows. Single Keycloak + Rails instance to start; Keycloak clustering/HA deferred. Precise SLO set in architecture.
- **Audit log** — **Keycloak login + admin events** shipped via the Event Listener SPI to an **off-host append-only/WORM sink** the operator cannot rewrite, plus **Rails-side audit** for Rails admin actions; **12-month retention**; excludes credentials/secrets/tokens. Integrity is provided by the WORM sink + scheduled out-of-band export (FR38's hash-chain relaxed accordingly).
- **Encryption at rest** — Keycloak's PostgreSQL (credentials, TOTP secrets) and the Rails DB encrypted at rest; least-privilege DB and Admin-API access.

## D. Compensating Controls (security posture)

The auth engine is now **community-reviewed, CVE-patched Keycloak**, so the controls that previously stood in for "a from-scratch security build reviewed by one person" now target the **smaller custom surface — the Keycloak hardening configuration and the Rails admin layer**:
- Tight v1 surface (authentication only); no fixed deadline (readiness gates release); phased rollout proving on 1–2 pilot apps first.
- **Keycloak configured per the official hardening guidance**; realm **config-as-code** (exported JSON in git, secrets stripped) for review and reproducibility; pinned Keycloak version.
- **Audited engine + maintained gems only — no hand-rolled crypto, token, or session logic** anywhere; the Rails layer never re-implements an auth primitive.
- CI pipeline: **Rails SAST (`brakeman`) + dependency/vulnerability scanning (`bundler-audit`) + secret scanning (`gitleaks`)**; realm-config lint.
- Build and verify the **custom surface** against **OWASP ASVS Level 2** (L3 for credential/key handling) and the **OAuth 2.0 Security BCP (RFC 9700)** — Keycloak is OIDC-certified and tracks the BCP.
- One **independent assessment** before the pilot — an **independent review of the Keycloak configuration + Rails layer** and a **penetration test** (the in-house mandate forbids buying the *product*, not buying *one independent assessment* — the cheapest substitute for the missing second reviewer).

## E. Compliance Detail (PDPA, Thailand — B.E. 2562)

Supports NFR11–15. Sourced from PDPA 2019, the PDPC breach-notification notification, OWASP, and NIST during Discovery research. *(Unchanged by the pivot — Keycloak stores the staff PII on-prem; the RoPA spans both Keycloak and the Rails layer.)*
- **Applicability** — PDPA applies to the division as a data controller; no blanket public-sector exemption. Staff identity/credential data is **ordinary** personal data, **not** §26 sensitive (provided no health/disability attributes or biometrics are stored; if WebAuthn/biometric MFA is ever enabled in Keycloak, gate it by explicit consent + heightened safeguards).
- **Lawful basis** — contractual necessity / legal obligation / legitimate interest (not employee consent); documented in a **Record of Processing Activities (RoPA)** covering Keycloak and Rails.
- **DPO** — generally required for public authorities (§41); this is an **organization-level role**, not the builder's. Loop in the department's DPO/legal for sign-off.
- **Breach notification** — PDPC within **72 hours** of awareness; high-risk breaches also notify affected individuals. The 12-month off-host audit retention (FR38) keeps the 72h reconstruction executable.
- **Data-subject rights** — access + rectification supported via the Rails console (over the Admin API); retention tied to employment with a deactivation/erasure process for leavers; on erasure, identity PII not held under a legal-obligation basis is erased/pseudonymized and the **subject reference in retained audit/event rows is pseudonymized rather than deleted** (NFR14).
