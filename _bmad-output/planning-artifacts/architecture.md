---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-06-20'
revisedAt: '2026-06-20'
revisionNote: 'Re-architected from custom node-oidc-provider build to self-hosted Keycloak (IdP) + Ruby on Rails (admin layer over the Keycloak Admin REST API). See sprint-change-proposal-2026-06-20.md.'
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-19/prd.md
  - _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-19/addendum.md
  - _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-19/review-security.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-06-20.md
  - _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-20/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-20/EXPERIENCE.md
workflowType: 'architecture'
project_name: 'envocc-sso'
user_name: 'Rawinan'
date: '2026-06-20'
---

# Architecture Decision Document — envocc-sso

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

> **Revised 2026-06-20 — stack pivot.** The IdP is no longer built from scratch. It is **self-hosted Keycloak** (the reviewed, CVE-patched OIDC engine); the custom HR/System control plane is a **Ruby on Rails** app that drives Keycloak through its **Admin REST API** and signs admins in via Keycloak (OIDC). The branded experience is a **custom Keycloak theme** (staff auth surfaces) + **Rails styling** (admin app), both from the unchanged `DESIGN.md` Ministry Bronze tokens. Full rationale and the before/after delta: `sprint-change-proposal-2026-06-20.md`.

## Carried-in decisions (the stack pivot)

- **Stack — PRD OQ2 resolved → Keycloak (IdP) + Ruby on Rails (admin layer) + PostgreSQL + Nginx, on-prem via Docker.**
  - **IdP engine: self-hosted Keycloak** (Quarkus distribution) — owns OIDC/OAuth, MFA (TOTP + WebAuthn-capable), password policy, brute-force/lockout, SSO sessions, token issuance + lifetimes, **realm key management + rotation**, email flows (activation/reset/verify), and the **Admin REST API** the Rails layer calls. Branded with a **custom Keycloak theme** built from the `DESIGN.md` Ministry Bronze tokens.
  - **Admin/management layer: Ruby on Rails 8 (Ruby 3.4)** — the genuinely custom part: HR console (provision/disable, CSV import), System workflows (client registration, admin-user/role management) over the **Keycloak Admin REST API**, org audit views, the OIDC integration guide, and the reference client. **Rails admins authenticate via Keycloak (OIDC)** and are role-gated. UI: **Hotwire (Turbo + Stimulus) + ERB**, styled with **Tailwind (`tailwindcss-rails`)** themed to Ministry Bronze.
  - **Persistence: PostgreSQL** — one on-prem server, **separate databases** for Keycloak and Rails.
  - **Edge: Nginx** — the single public security gateway (TLS, rate-limiting, security headers) fronting both Keycloak and Rails.
  - **Deploy: Kamal 2** for the Rails app; Keycloak + Postgres as managed containers; **Docker Compose** for dev.
- **Why the pivot:** the solo from-scratch IdP was the PRD's headline risk (R1) and the target of every CRITICAL security-review finding (C1–C4). Keycloak's auth core is community-reviewed and CVE-patched, removing most of that risk; Rails lets us build the custom admin in a language the team is fluent in. The in-house mandate is satisfied as **sovereignty** — Keycloak is self-hosted on-prem, open-source, inspectable; no foreign SaaS, no data leaving the ministry. _Supersedes the prior SvelteKit 2 / Bun / node-oidc-provider / Drizzle / Redis-BullMQ / Vault / daisyUI / Paraglide assembly._
- **Visual reference:** the Claude Design prototype `EnvOcc SSO.dc.html` and `DESIGN.md` tokens are the source of truth — now ported to **Keycloak FreeMarker theme templates + theme CSS** (staff auth) and **Rails ERB views + Tailwind** (admin), not Svelte/daisyUI.

## Project Context Analysis

### Requirements Overview

**Functional Requirements (50 FRs across 8 feature groups) — capability preserved, mechanism remapped to Keycloak/Rails:**
- **FG-1 OIDC core** (FR1–11) — Authorization Code + PKCE, IdP-hosted login, asymmetric token issuance + JWKS, SSO session, RP-initiated logout, discovery → **Keycloak realm + per-client configuration** (Standard flow only; Implicit/ROPC disabled; PKCE `S256`; exact `validRedirectUris`; RS256 realm keys + `certs` JWKS; `.well-known` discovery; SSO idle/absolute sessions; end-session endpoint).
- **FG-2 Staff auth** (FR12–20) — branded login, TOTP MFA, self-service reset, first-login activation, NIST password policy, progressive-delay lockout, enumeration resistance → **custom Keycloak theme + Keycloak auth flows/required actions + password policy + brute-force detection** (per-IP throttling added at Nginx).
- **FG-3 Identity store** (FR21–25) — one canonical identity per person, work-email reconciliation key, lifecycle states, minimal attributes → **Keycloak users** (stable `sub`), the native `email` claim + a protocol mapper as the reconciliation key, **User Profile** restricted to minimal attributes, lifecycle modeled on `enabled` + required actions.
- **FG-4/5 Admin app** (FR26–34) — HR lifecycle + System administration → the **Rails app over the Keycloak Admin REST API**, role-gated (`HR_ADMIN` vs `SYSTEM_ADMIN` realm roles).
- **FG-6 Audit logging** (FR35–39) — append-only, off-host, **12-month** retention → **Keycloak login + admin events** shipped via the Event Listener SPI to an **off-host append-only/WORM sink** + **Rails-side audit** for Rails actions.
- **FG-7 Integration enablement** (FR40–43) — OIDC integration guide ("integrate as a Keycloak client") + reference client.
- **FG-8 Operational security** (FR44–50) — admin-reset hardening (Rails-enforced over the Admin API), session-id regeneration (Keycloak-native), revocation on disable (Admin API logout + refresh-token revoke), single-use codes/nonce (Keycloak-native), CSV import validation (Rails), public-endpoint abuse protection (Nginx) + step-up (Keycloak/Rails).

**Non-Functional Requirements (architecture-driving):**
- **Cryptography & credentials** — **Keycloak native Argon2id** password hashing (no application pepper); TOTP secrets + action tokens stored by Keycloak (encrypted at rest via DB); asymmetric **RS256** signing via **Keycloak realm keys** with active/passive rotation overlap; token TTL **≤15 min**; TLS/HSTS at Nginx; host-prefixed Secure/HttpOnly/SameSite cookies; CSP `frame-ancestors 'none'` on auth surfaces.
- **Standards** — RFC 9700 (OAuth Security BCP), **OWASP ASVS L2** (L3 for credential/key handling) now scoped to **Keycloak hardening config + the Rails layer**; **Keycloak is OIDC-certified; no hand-rolled crypto/token/session logic**.
- **Privacy / PDPA** — non-consent lawful basis + RoPA; no §26 sensitive data; data minimization + encryption at rest; 12-month audit retention; 72h breach runbook; erasure-vs-retention reconciliation (pseudonymize subject in retained events).
- **Reliability / ops** — Keycloak SMTP is a **monitored critical path**; **24/7** target; **single point of dependency** for all apps; tested backup/restore of **Keycloak Postgres + realm export/keys + Rails DB** with RTO/RPO; edge DoS protection at Nginx.
- **Scale / perf** — ~100–150 staff, modest load, p95 ≤500 ms auth latency.
- **Localization** — English-first, Thai-ready (Noto): **Keycloak theme message bundles** (`messages_en`/`messages_th`) + **Rails i18n** (`en.yml`/`th.yml`); security-critical strings Thai-first.

**Adversarial security review — how Keycloak + Rails answer the mechanisms the review demanded:**
- **Signing-key custody/rotation/recovery (C4):** Keycloak realm keys, active/passive overlap ≥ token TTL, rotation via key providers, recovery via realm export + DB backup. *(Largely satisfied by the engine.)*
- **Audit-log integrity (C2/C3):** Keycloak events + Rails audit shipped **off-host to an append-only/WORM sink** the operator can't rewrite; reads/exports themselves audited; scheduled out-of-band export to a named second person; 12-month retention. FR38's hash-chain **relaxed** to append-only/WORM integrity (no hand-rolled crypto).
- **Admin-reset as a bypass primitive (C1/FR44):** Rails enforces out-of-band identity-proof + attestation, victim notification, rate-limit + abuse alert, and drives Keycloak's `execute-actions-email` so an MFA reset returns the account to re-activation (re-enroll MFA + re-set password) — no "password-known/MFA-cleared" window.
- **Session & token hardening (H1/H2):** Keycloak TTL ceiling, refresh-rotation/revoke, server-side session invalidation + session-id regeneration on auth transitions, disable → Admin-API logout-all + refresh-family revoke.
- **Independent assurance (H5/NFR10):** ASVS L2 + pen test now target the small custom surface (Keycloak config + Rails).
- **PDPA (H6):** owner/deadline gates before the pilot; erasure/retention reconciliation with subject pseudonymization in retained events.

### Scale & Complexity
- **Primary domain:** full-stack web — a **configured** security-critical OIDC IdP (Keycloak) + a custom **Rails** management app + a custom Keycloak theme.
- **Complexity level: MODERATE–HIGH** — driven by **security sensitivity** (sole credential system of record), correct **Keycloak hardening/configuration**, the **Admin-API integration**, compliance (PDPA), and the standards bar — but **materially lower than a from-scratch build** because the OIDC/crypto/session engine is no longer ours to write.
- **Estimated architectural components (~7):** Keycloak (IdP) · Keycloak theme · PostgreSQL · Rails admin app · audit shipping (events → off-host WORM) · Nginx edge · reference client / integration assets.
- Multi-tenancy: none (single realm). Real-time: minimal. Regulatory: **PDPA**.

### Technical Constraints & Dependencies
- **Stack fixed:** Keycloak (IdP) + Rails 8 (admin over Admin REST API) + PostgreSQL + Nginx; Kamal for the Rails deploy.
- **Audited engine + maintained gems only** — no hand-rolled crypto/token/session logic (NFR8); Rails never re-implements an auth primitive.
- **Hard external dependencies:** SMTP relay (critical path, configured in Keycloak); the off-host audit sink; the Keycloak Admin REST API (Rails couples to it — pin the version, wrap behind an adapter).
- **No external identity store** (no AD/LDAP/HR feed) — Keycloak is the system of record.
- **24/7 availability + single point of dependency** → resilient deployment, backup/recovery, edge protection; Keycloak HA/clustering deferred (single instance to start — honest trade vs NFR17).
- **Solo build, no independent runtime oversight** → compensating controls become architectural requirements (off-host audit, out-of-band export, tested recovery, config-as-code review).

### Cross-Cutting Concerns Identified
- **Security** (token/session/credential/key handling) — now largely **inside Keycloak**; our job is correct configuration + hardening + the Rails layer.
- **Auditability** — Keycloak events + Rails audit, append-only, off-host; spans auth + admin + token/key events.
- **PDPA compliance & data governance** — lawful basis, retention/erasure, breach response.
- **Availability & resilience** — Keycloak is the single point of failure; realm-key loss is catastrophic.
- **Separation of duties + solo-operator oversight** — HR vs System realm roles; mitigations for self-audited god-mode (off-host events).
- **Localization** — English-first, Thai-ready across the Keycloak theme + Rails.

## Starter Template Evaluation

### Primary Technology Domain
Full-stack web — Keycloak (configured, not built) + a Rails admin app + a custom Keycloak theme. The IdP is **deployed and configured**, not composed from libraries, which is the central simplification of the pivot.

### Verified current versions (confirm exact patch at scaffold, June 2026)
- **Keycloak** — latest stable Quarkus distribution (pin the exact version; upgrades require care for DB migration + theme/Admin-API compatibility). Postgres-backed; realm config-as-code via export/import.
- **Ruby on Rails 8** on **Ruby 3.4**; **PostgreSQL 18.x**; **Hotwire** (Turbo + Stimulus) + **ViewComponent** (optional) + **Tailwind via `tailwindcss-rails`**.
- **Keycloak integration gems (verify maintenance + version at scaffold — same diligence that rejected `doorkeeper-openid_connect`):**
  - OIDC login for Rails admins: a maintained OIDC/OmniAuth gem (e.g. `omniauth_openid_connect`) — or `openid_connect` directly.
  - Admin REST API: prefer a **thin Faraday-based adapter** we own (most stable across Keycloak upgrades) over a heavy third-party gem; if a maintained `keycloak-admin`-style gem is current, evaluate it.
- **Kamal 2** (Rails deploy) with `kamal-proxy`; **Nginx** (edge); **Docker / Docker Compose** (dev).

### Selected scaffold
```bash
# IdP — Keycloak via Docker (pinned), with a baseline realm import
#   docker run quay.io/keycloak/keycloak:<pinned> start --import-realm ...
# Admin layer — Rails 8 app
rails new admin --database=postgresql --css=tailwind --skip-jbuilder
bundle add omniauth_openid_connect faraday        # verify versions/maintenance at scaffold
bundle add --group development,test rspec-rails
bundle add --group development brakeman bundler-audit rubocop
```
(Exact flags/gems confirmed at scaffold time; **Story 1.1 = stand up Keycloak + import a baseline realm**, then scaffold Rails.)

### Architectural decisions the scaffold makes / implies
- **IdP:** Keycloak owns auth — we configure a realm (config-as-code, secrets stripped), not write an engine.
- **Admin app:** Rails 8, server-rendered (Hotwire), Postgres, Tailwind themed to Ministry Bronze.
- **Theme:** a custom Keycloak **login/account/email** theme from `DESIGN.md` tokens (FreeMarker `.ftl` + `theme.properties` + `messages_*.properties` + compiled CSS + Noto fonts).
- **No Svelte, no daisyUI, no Bun, no Vault, no Redis, no Paraglide, no node-oidc-provider.**

### UX reconciliation note
EXPERIENCE.md states **"UI system = custom"** — this now holds **literally**: the staff-auth surfaces are a custom Keycloak theme and the admin app is custom Rails views, both from `DESIGN.md` tokens. **The prior "daisyUI strict" reconciliation note is withdrawn** — there is no component-library imposition to reconcile. `DESIGN.md` remains the visual source of truth; the EXPERIENCE.md spine is unchanged.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical decisions (block implementation) — settled:**
- Stack: Keycloak + Rails + PostgreSQL + Nginx (pivot).
- **Hosting: on-premises** (ministry-controlled servers).
- **Key custody: Keycloak-managed realm keys** (no Vault); active/passive rotation overlap; realm-export + DB backup for recovery.
- **Data layer:** Keycloak's own schema (managed by Keycloak) + Rails via Active Record/migrations, on separate Postgres databases.
- **Audit:** Keycloak Events SPI → off-host WORM sink + Rails-side audit.
- **Edge: Nginx** (TLS, per-IP rate-limiting, security headers) fronting Keycloak + Rails.

**Important decisions (shape architecture) — settled:**
- **Rails ↔ Keycloak coupling** via the **Admin REST API**, wrapped behind a thin Rails adapter; Keycloak version pinned; integration-tested in CI against a running Keycloak.
- **Rails admin auth** via Keycloak OIDC; role gate on `HR_ADMIN` / `SYSTEM_ADMIN` realm roles.
- **Lifecycle modeling:** pending = required actions outstanding (`UPDATE_PASSWORD`, `CONFIGURE_TOTP`, `VERIFY_EMAIL`) + `emailVerified=false`; active = cleared; disabled = `enabled=false` + session/token revocation.
- **Deploy: Kamal 2** for Rails (zero-downtime via `kamal-proxy`, behind Nginx); Keycloak + Postgres as managed containers; Docker Compose for dev.
- **Backups:** nightly off-site of Keycloak Postgres + **realm export/keys** + Rails DB, with **tested restore**.

**Deferred decisions:**
- **Keycloak HA/clustering** (multi-node + DB replication) — single solid, well-backed-up instance to start (fine for ~150 staff); revisit if 24/7 zero-downtime becomes hard-required. *(Honest trade vs NFR17.)*
- **Hardware HSM / Vault-backed key provider** for realm keys — Keycloak-managed keys are the primary; adopt an HSM provider later if the ministry provides one.
- **WebAuthn as the required factor** — natively available in Keycloak; v1 stays TOTP per PRD scope (R8), cheap to enable later.

### Data Architecture
- **Database:** PostgreSQL 18.x (on-prem). **Keycloak database** — Keycloak's own schema (users, credentials, sessions, realm config, events if DB-stored). **Rails database** — audit records for Rails-side actions, CSV-import staging, app metadata. Two databases, one server; Rails has **no direct access to Keycloak's schema** (it goes through the Admin REST API).
- **Keycloak persistence:** managed by Keycloak; we treat its schema as opaque and never write to it directly. Realm configuration is **version-controlled as exported JSON (secrets stripped)** and imported on deploy.
- **Rails data layer:** Active Record + migrations (run on deploy via Kamal). Strong params + model validations at every boundary; a dedicated CSV validator for FR49.
- **No Redis** — Keycloak manages its own caching/sessions (Infinispan); Rails uses cookie or DB-backed sessions. No separate ephemeral store or job queue in v1 (CSV-import email dispatch is throttled by Keycloak's `execute-actions-email` calls; if background processing is needed, use Rails' built-in async/`solid_queue`).

### Authentication & Security
- **OIDC engine:** Keycloak — Authorization Code + PKCE only, Implicit/ROPC disabled (FR1, FR3); exact `validRedirectUris` (FR4); RS256 realm keys + `certs` JWKS (FR5); discovery (FR11); conforms to RFC 9700 (OIDC-certified).
- **Realm keys:** Keycloak key providers; **active/passive overlap ≥ token TTL** (NFR3, C4); JWKS published with `kid`; rotation runbook; recovery via realm export + DB backup.
- **Token lifetimes:** access/ID **≤15 min** (NFR2a); refresh-token rotation + reuse-revocation ("Revoke Refresh Token"); disabling an account **revokes refresh-token families + Keycloak sessions** via the Admin API (FR25/FR46).
- **Password hashing:** **Keycloak native Argon2id** at OWASP params (NFR1) — no application pepper; DB encryption-at-rest + isolation cover stolen-DB risk.
- **MFA:** Keycloak OTP policy (bounded drift `lookAheadWindow`, single-use-per-step, rate-limited) + `CONFIGURE_TOTP` required action (FR13/FR14); admin-assisted recovery hardened by FR44; WebAuthn available (deferred to post-v1 per scope).
- **Email tokens:** Keycloak action tokens (single-use, short-lived, stored hashed by Keycloak); enumeration-resistant flows (FR16/17/20/48); action-token lifespans configured ≤~20 min; pending accounts expire.
- **Sessions:** Keycloak server-side sessions; **session-id regenerated on auth-state transitions** (FR45, native); host-prefixed Secure/HttpOnly/SameSite cookies; CSP `frame-ancestors 'none'` on auth surfaces via Keycloak "Security Defenses" + Nginx headers (NFR4); server-side invalidation + admin forced-logout via Admin API (FR46).
- **Admin-reset hardening (C1/FR44):** enforced in **Rails** — out-of-band identity-proof + attestation recorded in the Rails audit, victim notification, rate-limit + abuse alert — then driven into Keycloak (`execute-actions-email` with `UPDATE_PASSWORD` + `CONFIGURE_TOTP`) so the account returns to re-activation.
- **Client authentication (FR32/M1):** confidential clients prefer **`private_key_jwt`** (Keycloak "Signed JWT" authenticator with the client's JWKS) for rotation overlap; coordinated `client_secret` rotation as fallback.
- **Brute force (FR19):** Keycloak per-user brute-force (progressive `wait`) + **Nginx per-IP `limit_req`** (Keycloak's detection is per-account).
- **Audit log (C2/C3/FG-6):** Keycloak login + admin events via the Event Listener SPI **shipped off-host to an append-only/WORM sink** the app/operator cannot rewrite; Rails audit for Rails actions shipped likewise; reads/exports themselves audited; **scheduled out-of-band export to a named second person** (DPO/manager — PRD OQ3); **12-month** retention; excludes credentials/secrets/tokens.
- **Assurance:** independent review of the **Keycloak configuration + Rails layer** before the pilot; independent pen test before broad rollout (NFR6/NFR10).

### API & Communication Patterns
- **OIDC endpoints:** served by **Keycloak** (`/realms/{realm}/protocol/openid-connect/*`, `/.well-known/openid-configuration`, `certs`, logout). RPs (including the Rails admin app and pilot apps) are Keycloak OIDC clients.
- **Admin app:** Rails controllers/Hotwire over the Keycloak Admin REST API via the thin adapter; server-rendered, minimal client JS (Stimulus).
- **Edge protection (FR50):** **Nginx** — TLS termination (internal ministry certs), `limit_req`/`limit_conn` per-IP on public endpoints (login/token/reset/activation), security headers (HSTS, CSP), request-size limits; Keycloak's JWKS/discovery cacheable.
- **Error handling:** Keycloak's enumeration-resistant flows (FR20); Rails returns generic errors on any user-facing lookup; detailed errors to logs only.
- **Integration enablement (FG-7):** OIDC integration guide ("register a Keycloak client; validate ID token via JWKS; map the work-email claim") + a small reference client.

### Frontend Architecture
- **Two custom surfaces, both from `DESIGN.md` tokens:**
  - **Staff auth (Keycloak theme):** a custom Keycloak **login** theme (and **account**/**email** themes) — FreeMarker `.ftl` templates + `theme.properties` + compiled Ministry Bronze CSS + Noto fonts + `messages_en`/`messages_th` bundles. Covers sign-in, OTP, first-login activation (set password + enroll TOTP), reset, re-activation, signed-out, error/invalid-link. Rendered **top-level, never iframed** (CSP `frame-ancestors 'none'`).
  - **Admin app (Rails):** ERB views (+ ViewComponent or partials) styled with **Tailwind themed to Ministry Bronze**; Hotwire for the few interactive bits (code-input auto-advance, show/hide password, CSV validate/preview, step-up modals). One role-gated shell (HR section + System section).
- **No daisyUI, no Svelte.** Components are built directly from `DESIGN.md` tokens in each surface's native templating.
- **Accessibility:** WCAG 2.1 AA across both surfaces; keyboard/focus/labels; Thai-ready (Noto). Visual reference: the Claude Design prototype.

### Infrastructure & Deployment
- **Hosting:** on-premises (ministry-controlled).
- **Edge / security gateway:** **Nginx** — the single public `:443` front door: internal-CA TLS + HSTS, CSP/security headers, **per-IP rate-limiting + abuse controls (FR50)**, request-size caps. Routes auth paths → **Keycloak**, `/` → the **Rails** backend.
- **Rails deploy:** **Kamal 2** — SSH + Docker, **zero-downtime via `kamal-proxy`** (health-checked rollover), migrations on release, secrets from Kamal/Rails encrypted credentials (never committed). `kamal-proxy` runs **behind Nginx** (TLS terminates at Nginx).
- **Keycloak + Postgres:** managed Docker containers on the host (Kamal accessories or a small compose unit), **pinned versions**, realm imported on boot.
- **On-prem services:** Nginx · Keycloak · PostgreSQL (Keycloak + Rails DBs) · Rails app · the off-host audit sink.
- **Backups:** nightly off-site of **Keycloak Postgres + realm export/keys + Rails DB**; **tested restore**; stated RTO/RPO (NFR17).
- **Availability:** single well-maintained Keycloak + Rails instance to start; HA/clustering deferred.
- **Monitoring:** uptime + error alerts; **Keycloak health/metrics** endpoints; **SMTP deliverability monitoring** (critical path, NFR16).
- **Dev:** Docker Compose (keycloak + postgres + rails + **mailpit**).
- **TLS / certificates:** **none needed for local dev** — Keycloak runs `start-dev` over plain HTTP on `localhost` (the realm "SSL Required" = `external` exempts localhost; browsers treat `http://localhost` as a secure context), Nginx is skipped in dev. To exercise HTTPS locally, use **`mkcert`** (locally-trusted dev CA) or a self-signed cert.
- **Production certificate (no *public* CA required) — pick one, in order of preference:** (1) **request a server cert from the ministry's internal/enterprise CA** for the internal hostname (e.g. `sso.envocc.internal`) — staff machines already trust that CA, so no warnings *(recommended)*; (2) **self-signed** cert for a closed network (push the cert to client trust stores); (3) **run a small internal CA** (`step-ca`/`mkcert`) and install its root on managed devices via group policy/MDM. A **public CA (Let's Encrypt/commercial) is not applicable** for an internet-unreachable internal IdP and is undesirable (internal hostname would land in public CT logs). The certificate terminates at **Nginx** — this is precisely why Nginx (manual cert) is the edge rather than `kamal-proxy`'s public-reachability auto-TLS. **Not a build blocker:** it is a go-live/pilot ops task (Story 6.3 / NFR4 / NFR17), not a prerequisite to start building.
- **CI/CD:** Rails — `rubocop`, **`brakeman` (SAST)**, **`bundler-audit` (dep-scan)**, RSpec + system tests **against a running Keycloak**; `gitleaks`; **realm-config lint** + theme build → images → Kamal deploy.

### Decision Impact Analysis

**Implementation sequence (suggested):**
1. Stand up **Keycloak** (Docker, pinned) + import a **baseline realm** + secret hygiene.
2. Configure the realm: OIDC clients (Auth-Code+PKCE-only, exact redirect), token TTL, sessions, brute-force, password policy, **realm keys + JWKS**.
3. User model: minimal **User Profile**, **work-email claim mapper**, lifecycle mapping (`enabled` + required actions).
4. **Custom Keycloak theme** (login/OTP/activation/reset/email) from `DESIGN.md` + Noto + en/th bundles.
5. **Reference client** proving end-to-end SSO.
6. **Rails app** + Keycloak-OIDC login + role gate + the **Admin-API adapter**.
7. HR console (create/search/enable-disable/reset-hardened/CSV/profile).
8. System console (client registration/rotation, admin-user/role mgmt, step-up).
9. Audit: Keycloak events → off-host WORM + Rails audit + unified view/export.
10. Nginx edge + Kamal deploy + backups + monitoring + integration guide.
11. Independent config/Rails review → pilot.

**Cross-component dependencies:**
- Keycloak must be standing before realm config, theme, and the Rails Admin-API work.
- The Admin-API adapter underpins all Rails HR/System actions — build and test it early.
- Audit spans Keycloak events + Rails actions — enable Keycloak events from the start; wire the off-host shipper before the pilot.
- Nginx edge protection is required in front of Keycloak's public endpoints (the Rails app alone is not the abuse target).
- The off-host audit sink + the named second person are **compliance-blocking before the pilot**.

## Implementation Patterns & Consistency Rules

> "House rules" for consistent code. Idiomatic Rails + a disciplined Keycloak configuration practice.

### Naming
- **Keycloak realm config:** lower-kebab realm/client ids (`envocc`, `envocc-admin`, `pilot-reporting`); realm roles UPPER_SNAKE (`HR_ADMIN`, `SYSTEM_ADMIN`); config exported as JSON, **secrets stripped**.
- **Rails (Ruby):** `snake_case` methods/vars, `CamelCase` classes; models singular (`AuditEvent`), tables plural (`audit_events`); REST routes; `timestamptz` (UTC).
- **Keycloak theme:** theme name `ministry-bronze`; FreeMarker templates per Keycloak convention (`login.ftl`, `login-otp.ftl`, `login-update-password.ftl`, …); message keys `dot.case` in `messages_en`/`messages_th`.
- **OIDC/OAuth fields:** keep the spec's `snake_case` (`client_id`, `redirect_uri`); Rails JSON: by Rails convention.

### Structure
- `keycloak/` — `realm-export.json` (secrets stripped), `themes/ministry-bronze/`, event-listener config, `Dockerfile`.
- `admin/` — the Rails app (standard Rails layout); `app/services/keycloak/` = the thin Admin-API adapter; `config/deploy.yml` = Kamal.
- `reference-client/` — a minimal OIDC client demonstrating the contract.
- `nginx/envocc-sso.conf` — edge config (TLS, rate-limits, headers, routing).
- `compose.yaml` — dev stack; `docs/oidc-integration-guide.md`.
- Rails tests: RSpec (`spec/`), system tests against a running Keycloak; theme has a manual a11y/visual checklist.

### Formats
- **Dates:** ISO 8601 UTC in APIs; `timestamptz` in the Rails DB.
- **Validation:** Rails strong params + model validations at every boundary; dedicated CSV validator (FR49); treat all Admin-API inputs as untrusted.
- **Public errors:** generic, enumeration-resistant (FR20); detail to logs only.
- Real booleans; `nil` for absent.

### Communication
- **App logs:** structured (Rails `tagged`/JSON); secrets/tokens NEVER logged.
- **Audit events (Rails-side, separate):** fixed schema `{actor, action, target, timestamp, source, outcome}`; actions `dot.snake` (`user.disabled`, `mfa.reset`, `client.registered`, `audit.exported`) — aligned to and complementing Keycloak's native event fields.
- **Keycloak events:** login + admin events enabled, retention set, shipped via the Event Listener SPI to the off-host sink.
- **Admin-API adapter:** typed responses, explicit error mapping, retries with backoff on transient failures; the Keycloak version it targets is pinned and asserted in CI.

### Process
- Staff auth flows are **Keycloak flows + required actions** themed by `ministry-bronze`; we configure, we do not re-implement.
- Every Rails data view handles loading/empty/error/success (EXPERIENCE.md states).
- Disable → Admin-API: `enabled=false` + logout-all + refresh-token revoke (FR25/FR46).
- Sensitive Rails actions require step-up re-auth (Keycloak `max_age`/`prompt=login` or `acr`) + CSRF.

### Enforcement — all code MUST
- Pass `rubocop` + `brakeman` + `bundler-audit` + tests in CI before merge.
- Keep secrets out of git (Rails encrypted credentials / Kamal secrets / env) — never in the repo, logs, or realm exports.
- Validate all external input at the boundary; treat Admin-API params and OIDC params as untrusted.
- Use the Rails audit-event schema for every Rails admin/token-relevant action; rely on Keycloak events for IdP-internal events.

**Good:** `audit_events`, `user.disabled`, `HR_ADMIN`, secrets-stripped `realm-export.json`, ISO-8601 `timestamptz`.
**Avoid:** writing to Keycloak's schema directly, logging tokens, committing secrets or un-stripped realm exports, re-implementing any auth primitive in Rails.

## Project Structure & Boundaries

### Complete Project Directory Structure
```
envocc-sso/
├── README.md
├── compose.yaml                      # DEV: keycloak · postgres · rails · mailpit
├── .gitleaks.toml                    # secret-scan rules
├── .gitignore                        # .env* (keep .env.example) · *.pem *.key · admin/config/master.key · .kamal/secrets
├── .env.example                      # config keys only — NO secrets
├── nginx/
│   └── envocc-sso.conf               # edge: TLS, per-IP rate-limits, security headers, routing KC + Rails
├── keycloak/
│   ├── Dockerfile                    # pinned Keycloak image + theme + event listener
│   ├── realm-export.json             # realm config-as-code (SECRETS STRIPPED) — imported on boot
│   ├── themes/ministry-bronze/
│   │   ├── login/                    # *.ftl (sign-in, otp, update-password, reset, etc.)
│   │   │   ├── theme.properties      # parent=keycloak; styles; locales en,th
│   │   │   ├── resources/css/        # Ministry Bronze CSS (from DESIGN.md tokens)
│   │   │   ├── resources/fonts/      # Noto Serif/Sans (+ Thai)
│   │   │   └── messages/             # messages_en.properties · messages_th.properties (security strings TH-first)
│   │   ├── account/ · email/         # branded account console + email templates
│   └── event-listener/               # ship login+admin events to the off-host WORM sink
├── admin/                            # ── Ruby on Rails 8 admin app ──
│   ├── Gemfile                       # rails, omniauth_openid_connect, faraday, tailwindcss-rails, brakeman, bundler-audit, rspec
│   ├── config/
│   │   ├── deploy.yml                # Kamal (kamal-proxy behind Nginx)
│   │   ├── initializers/omniauth.rb  # Keycloak OIDC login
│   │   └── locales/en.yml · th.yml   # Rails i18n
│   ├── app/
│   │   ├── services/keycloak/        # thin Admin REST API adapter (users, clients, roles, events, execute-actions-email)
│   │   ├── controllers/              # sessions (OIDC) · hr/* · system/* · audit/*
│   │   ├── models/                   # AuditEvent, CsvImport, ... (Rails DB only)
│   │   ├── views/                    # ERB + Tailwind (Ministry Bronze) — HR + System sections
│   │   └── components/ (optional)    # ViewComponents
│   └── spec/                         # RSpec + system tests (against a running Keycloak)
├── reference-client/                 # minimal OIDC client proving the contract (FR43)
├── docs/
│   └── oidc-integration-guide.md     # FR40–42 — "integrate as a Keycloak client"
└── .github/workflows/ci.yml          # gitleaks · rubocop · brakeman · bundler-audit · rspec(+KC) · realm-lint · theme build
```

### Requirements → Structure mapping
- **FG-1 OIDC core** → `keycloak/realm-export.json` (clients, flows, keys) + Keycloak runtime
- **FG-2 Staff auth** → `keycloak/themes/ministry-bronze/*` + Keycloak auth flows / required actions / password policy
- **FG-3 Identity store** → Keycloak users + User Profile + work-email claim mapper (in realm config)
- **FG-4 HR console** → `admin/app/{controllers/hr,services/keycloak}`
- **FG-5 System console** → `admin/app/{controllers/system,services/keycloak}`
- **FG-6 Audit** → `keycloak/event-listener/` (KC events → off-host) + `admin/app/models/audit_event.rb` + `admin/app/controllers/audit`
- **FG-7 Integration** → `docs/oidc-integration-guide.md` + `reference-client/`
- **FG-8 Operational security** → Rails admin-reset flow + step-up/CSRF + `nginx/` edge + Keycloak session/token settings
- **Localization (NFR19)** → Keycloak `messages_en`/`messages_th` (security strings TH-first) + Rails `config/locales`

### Architectural Boundaries
- **IdP boundary:** all OIDC + credential handling is **inside Keycloak**; Rails never touches Keycloak's DB or re-implements auth — it calls the **Admin REST API** only.
- **Edge boundary:** **Nginx** is the only public boundary (TLS, rate-limit, headers), fronting both Keycloak and Rails.
- **Data boundary:** Keycloak DB (opaque, Keycloak-owned) vs Rails DB (audit/app metadata, Active Record). Separation enforced by access path (Admin API), not shared tables.

### Integration Points
- **Internal:** Rails controllers → `services/keycloak` adapter → Keycloak Admin REST API; Rails views → Rails DB via Active Record.
- **External:** SMTP relay (Keycloak email), the off-host audit sink, and integrated OIDC client apps (the Rails admin app itself + pilot RPs).
- **Data flow:** browser → Nginx → (Keycloak for auth | Rails for admin); Rails → Keycloak Admin API for all lifecycle/client/role operations; Keycloak events + Rails audit → off-host WORM sink.

### Secret Hygiene (hard rule)
- **NEVER commit credentials — real or test.** `.env` never committed (only `.env.example`). Runtime secrets come from Rails encrypted credentials / Kamal secrets / env — never a committed file. **Realm exports are committed with all secrets stripped.**
- **Pre-commit:** `gitleaks` on staged changes → a secret match **blocks the commit**.
- **CI:** `gitleaks` again (second net) → a match **fails the build**.
- **Tests** generate fake credentials at runtime or use obvious placeholders; never hardcode real or real-looking secrets.
- `.gitignore` covers `.env*` (except example), `*.pem`/`*.key`, `admin/config/master.key`, `.kamal/secrets`, and any local realm export holding secrets.

### Dev / Build / Deploy
- **Dev:** `docker compose up` (keycloak, postgres, rails, mailpit) + `bin/rails s`.
- **Build:** CI runs gitleaks/rubocop/brakeman/bundler-audit/rspec(+Keycloak)/realm-lint/theme-build → Docker images.
- **Deploy:** **Kamal** deploys the Rails app (migrations on release, zero-downtime behind Nginx); Keycloak + Postgres as pinned managed containers; secrets from Kamal/credentials.

## Architecture Validation Results

### Coherence ✅
Stack composes cleanly and with **fewer moving parts** than the prior design (Keycloak · custom theme · PostgreSQL · Rails · Nginx · Kamal — no Bun/node-oidc-provider/Drizzle/Redis/Vault/daisyUI/Paraglide). Pin exact Keycloak + Rails + gem versions at scaffold. Watch-items: the **Admin-API adapter** (couple loosely, pin version, test in CI), **theme a11y/visual parity** with `DESIGN.md`, and a **Keycloak hardening checklist**.

### Requirements Coverage ✅
- **FG-1…FG-8** each mapped to a Keycloak-config and/or Rails location.
- **NFRs:** Keycloak Argon2id (no pepper) · RS256 realm keys + rotation · ≤15-min tokens · RFC 9700 (certified engine) + ASVS L2 on the custom surface · PDPA (Keycloak events + Rails audit → off-host WORM, 12-month retention, erasure/retention reconciliation, breach runbook) · Keycloak SMTP + monitoring · Keycloak `messages_th` + Rails i18n (Thai-first security strings) · p95 ≤500 ms.
- **Security review:** C1 (Rails-enforced admin-reset hardening + Keycloak re-activation), C2 (off-host events + scheduled second-person export), C3 (event integrity via WORM + 12-month retention + audited reads), C4 (Keycloak realm-key custody + rotation) — all addressed; H1–H6 covered.

### Implementation Readiness ✅
Decisions documented; the engine is configured not built; structure + boundaries + secret-hygiene explicit; the old Bun⇄provider conformance risk is gone.

### Gap Analysis Results
- **Critical (block build):** none.
- **Important (address early / before pilot):** the **Admin-API adapter + pinned Keycloak version** (build/test first); **Keycloak hardening checklist**; **theme a11y parity**; HA deferred (single instance — honest trade vs NFR17); org inputs — named **second person** (OQ3) + **pilot apps** (OQ1); independent **config + Rails review** before pilot + **pen test** before broad rollout (NFR10).
- **Nice-to-have:** explicit observability stack; written DR runbook; threat-model doc; decide whether to pull WebAuthn forward (now cheap).

### Validation Issues Addressed
No blocking issues. Important gaps documented with timing (adapter-first · hardening-checklist · deferred-HA · org-inputs-before-pilot).

### Architecture Completeness Checklist
**Requirements Analysis** — [x] context · [x] scale · [x] constraints · [x] cross-cutting
**Architectural Decisions** — [x] critical w/ versions · [x] stack · [x] integration · [x] performance
**Implementation Patterns** — [x] naming · [x] structure · [x] communication · [x] process
**Project Structure** — [x] directory tree · [x] boundaries · [x] integration points · [x] requirements mapping

### Architecture Readiness Assessment
**Overall Status:** **READY FOR IMPLEMENTATION** — Important gaps above to address early; HA + org inputs gate the *pilot / go-live*, not the *build*.
**Confidence Level:** High — and **lower-risk than the prior from-scratch design** (the headline R1 risk is largely retired).
**Key Strengths:** community-reviewed CVE-patched engine · security mechanisms satisfied by Keycloak rather than hand-built · fewer moving parts · custom admin in a fluent language · localization + theming built-in · sovereignty preserved (on-prem, OSS).
**Areas for Future Enhancement:** Keycloak HA/clustering · HSM/Vault-backed key provider · WebAuthn as required factor · deeper observability + DR runbook.

### Implementation Handoff
**AI Agent Guidelines:** configure Keycloak per these decisions (do not re-implement auth); build the Rails layer over the Admin REST API; respect the secret-hygiene + no-credentials-in-git rule; treat this document + the Sprint Change Proposal as the source of truth.
**First Implementation Priority:** stand up **Keycloak** (pinned, Docker) + import a **baseline realm** → configure OIDC clients + realm keys → `rails new admin` + Keycloak-OIDC login + the **Admin-API adapter** → the **Ministry Bronze Keycloak theme**.
