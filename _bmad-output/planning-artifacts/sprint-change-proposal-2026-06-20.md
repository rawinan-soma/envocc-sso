---
title: "Sprint Change Proposal — envocc-sso stack pivot to Keycloak + Rails"
status: proposed
created: 2026-06-20
author: Rawinan (via BMad Correct-Course workflow)
change_scope: MAJOR
mode: Batch
inputDocuments:
  - prds/prd-envocc-sso-2026-06-19/prd.md
  - prds/prd-envocc-sso-2026-06-19/addendum.md
  - prds/prd-envocc-sso-2026-06-19/review-security.md
  - architecture.md
  - epics.md
  - ux-designs/ux-envocc-sso-2026-06-20/DESIGN.md
  - ux-designs/ux-envocc-sso-2026-06-20/EXPERIENCE.md
  - implementation-readiness-report-2026-06-20.md
---

# Sprint Change Proposal — envocc-sso

> Significant stack change navigated via the BMad Correct-Course workflow. Propagates a single architectural pivot — **custom-built OIDC IdP → self-hosted Keycloak + a Ruby on Rails admin layer** — across the finalized PRD, Architecture, and Epics. No code exists yet and no sprint has started, so this is a **pure planning-artifact propagation** with zero rollback.

---

## Section 1 — Issue Summary

**Trigger:** A deliberate, owner-confirmed strategic decision (not a discovered defect). Issue category: **Strategic pivot** + **Failed-approach-avoided** — we are retiring the highest-risk part of the plan *before* building it.

**Problem statement.** The finalized architecture builds the OIDC Identity Provider from scratch — `node-oidc-provider` assembled with SvelteKit/Bun, custom session/token/credential handling, Vault-held keys + pepper, a hand-built audit chain. The PRD names this honestly as the **headline risk (R1): "Solo build of a security-critical IdP, no independent review — off-the-shelf would have been faster *and* safer."** The whole compensating-controls apparatus (ASVS L2 self-check, independent pen test, no-hand-rolled-crypto rule) exists as *damage control for a knowingly harder path*.

**The change.** Replace the custom auth engine with **self-hosted Keycloak** as the IdP — its OIDC/OAuth, MFA (TOTP/WebAuthn), password policy, brute-force/lockout, session and token/key management with rotation, and email flows are community-reviewed and CVE-patched. Build the genuinely custom part — the **HR admin console, System workflows, org audit views, integration guide, and reference client** — as a **Ruby on Rails** application that drives Keycloak through its **Admin REST API** and signs its own admins in via Keycloak (OIDC). The branded experience is preserved as a **custom Keycloak theme** (staff auth surfaces) + **Rails styling** (admin app), both driven by the unchanged `DESIGN.md` Ministry Bronze tokens.

**Mandate reconciliation (load-bearing).** The brief/PRD treated "build in-house" as a mandate, and the addendum recorded that off-the-shelf "would have been faster and safer" as an *accepted* cost of that mandate. **The product owner has confirmed the mandate permits a self-hosted open-source component:** Keycloak runs on EnvOcc's own on-prem servers — no foreign SaaS, no data leaving the ministry, fully inspectable open-source code. **Sovereignty is preserved; the honest "we chose the harder, riskier path" admission is now *resolved* by adopting the safer path for the auth core** while still building the custom admin layer in-house, in a language the team is fluent in.

**Evidence this is the right call (already in our own docs):**
- PRD §1 + addendum §A: "Keycloak/Authentik deliver OIDC, MFA, password policy, account lockout, token rotation, and ongoing CVE patching out of the box, in days not months… Branded login did not require a custom build — Keycloak supports full custom themes."
- The adversarial security review's four CRITICAL findings (C1 admin-reset, C2 self-audited god-mode, C3 audit integrity, C4 key custody) are precisely the *operational primitives a from-scratch solo build owns alone*. Keycloak ships hardened, tested implementations of C4 (key custody/rotation) and most of C1/C3's mechanics, shrinking the custom attack surface to the Rails admin layer + Keycloak configuration.

---

## Section 2 — Impact Analysis

### 2.1 Epic Impact

The 6-epic spine and its **user-outcome framing survive**; the *implementation* of each epic re-pivots. No epic is deleted; no new epic is required (the work redistributes within the existing six).

| Epic | Before (custom build) | After (Keycloak + Rails) | Net effort |
|------|----------------------|--------------------------|-----------|
| **E1 Foundation & SSO Core** | Scaffold SvelteKit/Bun; mount node-oidc-provider; Drizzle schema; Vault keys; hand-built sessions/tokens | **Stand up + configure Keycloak**: realm, OIDC clients, Auth-Code+PKCE-only, RS256 realm keys + rotation, token TTL ≤15 m, SSO/session settings, brute-force, password policy, work-email claim mapper; reference client | **↓ much lower** (config vs. build) |
| **E2 Staff Experience & Recovery** | Build branded Svelte login/MFA/activation/reset + Paraglide | **Custom Keycloak theme** (login/OTP/activation/reset/email templates) from DESIGN tokens + Noto + en/th message bundles; configure required-action flows | **↓ lower** (theme vs. build flows) |
| **E3 HR Admin Console** | SvelteKit admin routes over local DB | **Rails app** (HR role) over **Keycloak Admin REST API**: create/search/enable-disable/reset(hardened)/CSV/profile | **↔ similar** (still a real build, now in Rails) |
| **E4 System Admin Console** | SvelteKit System routes | **Rails** (System role): client registration/secret rotation, admin-user/role mgmt, step-up | **↔ similar** |
| **E5 Audit, Compliance & Oversight** | Hand-built hash-chained audit + off-host shipper | **Keycloak Events SPI → off-host WORM sink** + Rails-side audit for Rails actions; unified view/export; PDPA | **↓ lower** (events native; integrity via WORM) |
| **E6 Integration & Hardening** | Guide + Svelte reference client; Nginx; Docker; Vault backups | Guide ("integrate as a Keycloak OIDC client") + reference client; Nginx fronting Keycloak+Rails; Docker Compose; backup Postgres + Keycloak realm/keys; Rails CI gates | **↔ similar** |

**Sequencing change:** the old "verify node-oidc-provider runs on Bun" watch-item **disappears**. A new early task appears: **stand up Keycloak in Docker and import a baseline realm** (Story 1.1), which unblocks everything else.

### 2.2 Artifact Conflict Analysis

| Artifact | Conflict severity | What changes |
|----------|------------------|--------------|
| **PRD** (`prd.md`) | **Moderate** — FRs survive at capability level | §1 mandate/risk framing; NFR1 (pepper), NFR3 (key custody), NFR6/NFR8 (assurance/audited-libs), NFR17 (backup targets); R1 (headline), R4 (key/pepper loss), R8 (WebAuthn); **add R10–R12** (Keycloak ops/Admin-API/two-codebase risks). FR *tables* keep their wording — only the implementation note shifts to "Keycloak configures it" vs "we build it." |
| **PRD Addendum** (`addendum.md`) | **High** | §A build-vs-buy: decision **resolved** (adopt Keycloak core); §C technical implications: rewrite to Keycloak/Rails mechanics; §D compensating controls: reframe — the engine is now community-reviewed, controls now target config + the Rails layer. |
| **Architecture** (`architecture.md`) | **High — near-total rewrite** | Replace the entire stack section. Out: Bun, node-oidc-provider, Drizzle, Redis/BullMQ, Vault, daisyUI, Paraglide, SvelteKit. In: Keycloak (IdP), Rails 8 (admin over Admin REST API), Postgres (KC + Rails DBs), Nginx, Docker Compose, Keycloak theme, Keycloak i18n + Rails i18n. New key-custody, audit, deployment, structure, and patterns sections. |
| **Epics** (`epics.md`) | **High** | Requirements Inventory's AR1–AR10 + UX-DR1–UX-DR12 re-pointed; FR Coverage Map re-pointed; all 6 epics' stories re-pivoted to configure/theme-Keycloak + build-Rails. |
| **UX — DESIGN.md** | **None** | **Unchanged.** Tokens now feed the Keycloak theme + Rails styling. Source of truth preserved. |
| **UX — EXPERIENCE.md** | **None** | **Unchanged** — and *better aligned*: its "UI system = custom, no component library named" now describes a custom Keycloak theme + custom Rails views accurately. The architecture's old "daisyUI strict" reconciliation note is **dropped** (the conflict it managed no longer exists). |
| **Security Review** (`review-security.md`) | **Historical** | Not rewritten (it is a dated review of the old PRD). A dated header note will map which findings Keycloak now resolves vs. which migrate to the Rails layer. |
| **Implementation-Readiness Report** | **Superseded** | Asserts readiness of the *old* stack. A superseding banner will flag it stale and recommend re-running `bmad-check-implementation-readiness` against the revised artifacts. |

### 2.3 Technical Impact (capability → mechanism remap)

Every FR's *capability* is preserved; the *mechanism* moves. Highlights:

- **OIDC core (FR1–11):** Keycloak realm + per-client config — Standard flow only (Implicit/ROPC off), PKCE `S256` enforced, exact `validRedirectUris`, RS256 realm keys + `certs` JWKS + `.well-known` discovery, access-token lifespan ≤15 m, "Revoke Refresh Token" on, SSO idle/max session, end-session endpoint.
- **Work-email reconciliation key (FR22):** the native `email` claim plus a protocol mapper; stable `sub` = Keycloak user id.
- **Lifecycle pending→active→disabled (FR24):** modeled as Keycloak `enabled` + required actions (`UPDATE_PASSWORD`, `CONFIGURE_TOTP`, `VERIFY_EMAIL`) — pending = required actions outstanding; active = cleared; disabled = `enabled=false`.
- **Password policy (FR18/NFR7):** Keycloak password policy — `length(12)`, `passwordBlacklist` (HIBP/breached list file), `notUsername`, no expiry.
- **Brute force (FR19):** Keycloak per-user brute-force (progressive `wait`) + **Nginx `limit_req` for per-IP** (Keycloak's is per-account).
- **MFA (FR13/14):** Keycloak OTP policy (drift `lookAheadWindow`, single-use-per-step) + `CONFIGURE_TOTP` required action. WebAuthn is now **natively available** — R8's deferral becomes near-free to reverse if desired (v1 stays TOTP per scope).
- **Password hashing (NFR1):** **Keycloak's native Argon2id provider** at OWASP params. **The separate application "pepper" requirement is dropped** — Keycloak does not use an app pepper; stolen-DB risk is covered by per-password salt + DB encryption-at-rest + restricted DB access. *(This is the most material NFR change.)*
- **Key custody (NFR3/C4):** **Keycloak-managed realm keys** with active/passive rotation overlap — no Vault. Catastrophic-loss recovery = realm export + DB backup (replaces "Vault key/pepper restore").
- **Admin-reset hardening (FR44/C1):** **Rails enforces** the out-of-band identity-proof attestation + user notification + rate-limit/alert, and drives Keycloak (`execute-actions-email` with `UPDATE_PASSWORD`+`CONFIGURE_TOTP`) so an MFA reset returns the account to re-activation natively — no "password-known/MFA-cleared" window.
- **Audit (FR35–39/C2/C3):** **Keycloak login + admin events** (Events SPI) shipped to an **off-host append-only/WORM sink** + **Rails-side audit** for Rails admin actions; unified view/export in Rails (System); 12-month retention; scheduled out-of-band export to the named second person. **FR38's "hash-chained" is relaxed to "append-only / integrity-verifiable at the off-host WORM sink"** (avoids hand-rolled crypto, honoring NFR8).
- **Client secret rotation overlap (FR32/M1):** Keycloak holds one client secret at a time, so dual-secret overlap is satisfied by **`private_key_jwt` client auth (rotate client JWKS keys with overlap)** — already the addendum's preference — with coordinated secret rotation as the fallback.
- **CSV import (FR30/FR49):** Rails validates/dedupes/sanitizes/preview-confirms/throttles, then batch-creates via Admin API.
- **Localization (NFR19):** **Keycloak theme message bundles** (`messages_en`/`messages_th`, security-critical strings Thai-first) + **Rails i18n** (`en.yml`/`th.yml`) — replaces Paraglide.
- **Assurance (NFR6/NFR8/NFR10):** **NFR8 is now strongly satisfied** — the audited engine *is* Keycloak; Rails uses established gems. ASVS L2 + pen test now target **Keycloak hardening config + the Rails layer**, a far smaller custom surface.

---

## Section 3 — Recommended Approach

**Selected path: Option 1 — Direct Adjustment (re-pivot existing epics/stories in place).** No rollback (Option 2) is possible or needed — nothing is built. No MVP reduction (Option 3) — the MVP capability set is **unchanged**; only its realization changes. This is a **Major** change by classification (it re-architects the engine and re-frames the headline risk), executed as a Direct Adjustment because the requirement spine and epic structure hold.

**Effort:** Medium overall, **net-down** vs. the original plan (configuring/theming Keycloak is less work and less risk than building an OIDC engine; the Rails admin layer is comparable to the SvelteKit admin it replaces). **Risk:** **net-down** — the headline R1 risk is largely retired; three new, smaller operational risks (R10–R12) are introduced and named. **Timeline:** the "no fixed deadline, readiness gates release" posture is unchanged; readiness arrives sooner because the riskiest custom code is gone.

**Three forking decisions (confirmed with the owner this session):**
1. **Mode = Batch** — full proposal, one approval, then apply.
2. **Key custody = Keycloak-native; drop Vault from the v1 critical path** (deferred as an optional HSM/Vault enhancement). Remaining secrets (KC/Rails DB creds, Rails master key, SMTP) via Docker secrets / encrypted Rails credentials.
3. **Audit integrity = off-host WORM sink** receiving shipped Keycloak events + Rails audit; **FR38 hash-chain relaxed** to append-only/integrity-verifiable-at-sink (keeps us inside NFR8's no-hand-rolled-crypto rule).

**Rationale for keeping the requirement set intact:** the PRD's FRs were deliberately written at the capability/contract level with implementation deferred to architecture. That design choice is exactly what lets a stack pivot of this size land as edits to mechanism notes + a re-architecture, rather than a requirements rewrite. The product *contract* with EnvOcc — branded MFA SSO, HR-administered lifecycle, off-host audit, PDPA compliance, on-prem sovereignty — is honored verbatim.

---

## Section 4 — Detailed Change Proposals

> Batch mode: all edits below are proposed together. Surgical before/after is given for the PRD/addendum load-bearing passages; the Architecture and Epics are near-total rewrites, specified here as a change-spec (the full new files are produced on approval).

### 4.1 PRD (`prds/prd-envocc-sso-2026-06-19/prd.md`)

**Edit P1 — §1 Mandate bullet (lines ~22–26).**
*OLD:*
> - Building in-house is an **organizational mandate**, not a convenience choice — taken as given. We record honestly that an off-the-shelf product (Keycloak/Authentik) would have been **both faster *and* safer** (see addendum §A); the compensating controls in this PRD are **damage control for a knowingly harder path**, not a claim that building from scratch is risk-neutral. This is a documented, honest decision — not a differentiation play.

*NEW:*
> - Building in-house is an **organizational mandate** — **confirmed to permit a self-hosted open-source component**. The mandate's intent is **sovereignty and control** (no foreign SaaS, no data leaving the ministry, fully inspectable code), which a **self-hosted Keycloak on EnvOcc's own on-prem servers satisfies**. We therefore **adopt Keycloak as the reviewed, CVE-patched auth engine** and **build the custom HR/System admin layer in-house as a Ruby on Rails app over Keycloak's Admin API.** This *resolves* the earlier honest admission that off-the-shelf would be "faster and safer" (addendum §A): we take the safer path for the credential-handling core while keeping the custom control plane in-house.

**Edit P2 — §1 "sole system of record" bullet:** keep, append: *"— persisted in Keycloak's store (on-prem Postgres), with the Rails layer as the HR/System control plane over it."*

**Edit P3 — NFR1 (Cryptography & Credential Custody).**
*OLD:* Argon2id at OWASP floor + **a separately-custodied pepper (MUST)** — KMS-held, versioned, rehash-on-login, pepper-loss runbook.
*NEW:* **Passwords hashed by Keycloak's native Argon2id provider** (OWASP floor: ≥19 MiB, ≥2 iterations, parallelism 1), unique per-password salt, stored in Keycloak's on-prem Postgres with **encryption-at-rest + restricted DB access**. *No application-level pepper:* Keycloak's hashing does not use one; the stolen-DB threat is covered by salt + at-rest encryption + DB network isolation. *(Removes the Vault-pepper custody chain and the pepper-loss catastrophe from R4.)*

**Edit P4 — NFR3 (signing keys).** Keep the RS256/JWKS/`kid`/rotation/`alg:none`-rejected contract; replace custody mechanism: *"Signing handled by **Keycloak realm keys** — RS256, published at the realm JWKS endpoint with `kid`, rotated via Keycloak's key providers with an **active/passive overlap ≥ max token lifetime**; private keys held in Keycloak's store (on-prem), backed up via realm export + DB backup. Optional future HSM/Vault-backed key provider (deferred)."*

**Edit P5 — NFR6 / NFR8 (assurance + audited libraries).**
- NFR8 *NEW framing:* *"The auth engine is **Keycloak** — an OpenID-certified, community-reviewed, CVE-patched implementation; **no hand-rolled crypto/token/session logic** anywhere. The Rails admin layer uses only established, maintained gems and **never re-implements an auth primitive** — it drives Keycloak via its Admin REST API."*
- NFR6 *NEW scope:* ASVS L2 verification now targets **(a) the Keycloak deployment hardening configuration and (b) the custom Rails layer** — a far smaller custom surface than a from-scratch engine. Independent review (SM5) applies to that surface.

**Edit P6 — NFR17 (reliability/backup targets).** Replace "identity store, signing keys, and pepper" with *"Keycloak's Postgres (identities/credentials/sessions), the **Keycloak realm configuration + realm keys** (export), and the Rails app database"* with tested restore + RTO/RPO. Keycloak HA/clustering deferred (single instance to start — honest trade vs. 24/7, as before).

**Edit P7 — Risks table.**
- **R1 (headline) — reframe:** *Risk* → "**Correctly configuring and hardening Keycloak + building the custom Rails admin layer solo**, without an independent reviewer." *Controls* → "**Community-reviewed CVE-patched engine (Keycloak) replaces the from-scratch build**; config-as-code (realm export in git, no secrets); follow the Keycloak hardening guide; audited gems only; ASVS L2 + pen test now target the small custom surface (config + Rails)." Severity note: **materially reduced from the original headline.**
- **R4 — reframe:** signing-key loss now mitigated by **Keycloak key rotation + realm export/DB backup**; **pepper-loss removed** (no pepper).
- **R8 — note:** WebAuthn is now **natively available in Keycloak**; v1 stays TOTP per scope, but the deferral is now low-cost to reverse.
- **Add R10 — Keycloak operational expertise:** solo operator must configure/harden/upgrade Keycloak correctly; **misconfiguration is the new principal residual risk.** Controls: config-as-code + review, hardening checklist, pinned version, pre-pilot independent config review.
- **Add R11 — Admin-API coupling:** Rails depends on Keycloak Admin REST API stability across upgrades. Controls: pin Keycloak version; wrap the Admin API behind a thin Rails adapter; integration tests against a running Keycloak in CI.
- **Add R12 — two-runtime surface:** Keycloak (JVM) + Rails (Ruby) + theme is more heterogeneous than one app. Controls: Docker Compose, clear boundaries, CI for both, single Nginx front door.

**Edit P8 — OQ2:** mark resolved: *"Build stack — **resolved**: self-hosted Keycloak (IdP) + Ruby on Rails (admin layer) + Postgres + Nginx, on-prem via Docker."* FR tables (FR1–FR50) and the user journeys (UJ-1…UJ-8) keep their wording — they are capability/experience-level and remain true.

### 4.2 PRD Addendum (`addendum.md`)

- **§A Options Considered — rewrite outcome:** decision is now *"adopt self-hosted Keycloak for the auth core (mandate-compliant: on-prem, OSS, sovereign) + build the custom admin in Rails."* Keep the analysis; flip the conclusion.
- **§C Downstream Technical Implications — rewrite** to Keycloak/Rails mechanics (realm keys instead of self-managed JWKS; Keycloak password hashing instead of app Argon2id+pepper; Keycloak required-action flows; Admin REST API integration via Rails; `private_key_jwt` client auth; Keycloak SMTP; realm-export backups; Keycloak events → WORM audit).
- **§D Compensating Controls — reframe:** the engine is now community-reviewed; controls shift to **Keycloak hardening + Rails-layer assurance** (still: tight surface, no deadline, phased pilot, audited deps, CI dep-scan/SAST [Rails: bundler-audit/brakeman], ASVS L2 on the custom surface, one independent assessment).
- **§B Parked Roadmap:** WebAuthn note — now natively available in Keycloak (cheap to pull forward). **§E PDPA — unchanged** (Keycloak stores the PII; RoPA spans Keycloak + Rails).

### 4.3 Architecture (`architecture.md`) — near-total rewrite (change-spec)

New target architecture:
- **Carried-in decisions / Stack:** Keycloak (self-hosted, on-prem) as the OIDC IdP; **Ruby on Rails 8 (Ruby 3.4)** admin/management app (Hotwire/Turbo + ERB, **Tailwind via `tailwindcss-rails`** themed to Ministry Bronze); **PostgreSQL** (separate databases for Keycloak and Rails on one on-prem server); **Nginx** as the single public security edge fronting both; **Kamal 2** as the Rails deploy tool, **Docker Compose** for dev. *(Supersedes the SvelteKit/Bun/node-oidc-provider choice.)*
- **Keycloak responsibilities:** realm + OIDC clients, Auth-Code+PKCE-only, RS256 realm keys + rotation + JWKS + discovery, token TTL ≤15 m + refresh rotation/revoke, SSO idle/absolute sessions, RP-initiated logout, brute-force (per-user), password policy (NIST + breached-list), TOTP MFA (+ WebAuthn available), enumeration-resistant flows, required-action activation/reset, SMTP/email, **custom Ministry Bronze theme** (login/account/email), **i18n (en + th)**, login + admin **events**.
- **Rails responsibilities (over Keycloak Admin REST API):** HR console (create/search/enable-disable/reset-hardened/CSV/profile), System console (client registration + `private_key_jwt`/secret rotation, admin-user/realm-role mgmt, step-up re-auth, CSRF), org **audit views** (read Keycloak events + Rails audit), the **OIDC integration guide**, the **reference client**, Rails admins **sign in via Keycloak (OIDC)** and are role-gated (`HR_ADMIN` / `SYSTEM_ADMIN` realm roles). Rails wraps the Admin API behind a thin adapter (Faraday client or a maintained gem — **verify maintenance/version at scaffold**, per the same diligence that rejected `doorkeeper-openid_connect`); OIDC login via a maintained gem (e.g. `omniauth_openid_connect` — verify at scaffold).
- **Key custody:** Keycloak-managed realm keys (no Vault); active/passive overlap; realm-export + DB backup for catastrophic recovery. Optional HSM/Vault key provider deferred.
- **Audit subsystem:** Keycloak Event Listener SPI ships login + admin events to an **off-host append-only/WORM log sink** the operator cannot rewrite; Rails writes its own admin-action audit and ships likewise; unified view/export in Rails (System), reads/exports themselves audited; 12-month retention; scheduled out-of-band export to the named second person. **FR38 hash-chain relaxed** to append-only/WORM integrity.
- **Data architecture:** Postgres — Keycloak DB (users/credentials/sessions/realm) + Rails DB (audit, CSV-import staging, app metadata); no Redis (Keycloak manages its own session/cache via Infinispan; Rails uses cookie/DB sessions). Input validation: Rails strong params + model validations + a dedicated CSV validator.
- **Frontend:** **two custom surfaces, both from DESIGN.md tokens** — (a) Keycloak FreeMarker theme (`.ftl` + `theme.properties` + `messages_*.properties` + `resources/css` compiled from Ministry Bronze) for staff auth; (b) Rails views (ERB + ViewComponent or partials + Tailwind) for the admin app. **No daisyUI; no Svelte.** The old "daisyUI strict" reconciliation note is removed — EXPERIENCE.md's "UI system = custom" now holds literally. WCAG 2.1 AA + Noto (+ Thai) across both.
- **Patterns/house-rules:** Rails conventions (RuboCop, `snake_case` DB, `CamelCase` models, REST routes); Keycloak realm config-as-code (exported JSON in git, **secrets stripped**); thin Admin-API adapter with typed responses; audit-event schema preserved (`{actor, action, target, timestamp, source, outcome}`, `dot.snake` actions) for Rails-side events, aligned to Keycloak's event fields.
- **Deployment:** **Kamal 2** deploys the Rails admin app (SSH + Docker, zero-downtime via `kamal-proxy`, health checks). **Keycloak + PostgreSQL** run as managed Docker containers on the on-prem host (Kamal accessories or a small compose unit), pinned versions, realm imported on boot. **Nginx is the single public `:443` security edge** (internal-CA TLS + HSTS/CSP/headers + per-IP `limit_req` abuse controls per FR50 + request-size caps), routing the auth paths → Keycloak and `/` → the Rails backend; **`kamal-proxy` runs behind Nginx** doing Rails rollover only. Dev = Docker Compose (keycloak + postgres + rails + mailpit).
- **Project structure:** `keycloak/` (realm export, theme, event-listener config, Dockerfile) + `admin/` (Rails app, `config/deploy.yml` for Kamal) + `reference-client/` + `nginx/` + `compose.yaml` (dev) + `docs/oidc-integration-guide.md`. **Secret hygiene unchanged** (gitleaks pre-commit + CI; `.env`/Rails credentials/Kamal secrets never committed; realm exports secret-stripped).
- **CI/CD:** Rails — `rubocop`, `brakeman` (SAST), `bundler-audit` (dep-scan), RSpec/Minitest + system tests against a running Keycloak; `gitleaks`; theme build; realm-config lint. Docker images → on-prem deploy behind Nginx.
- **Validation/readiness sections:** rewritten to reflect the new coherence (no Bun⇄provider watch-item; new watch-items: Admin-API adapter, theme a11y parity, Keycloak hardening checklist) and the reduced risk posture.

### 4.4 Epics (`epics.md`) — reshape (change-spec)

- **Requirements Inventory:** FR descriptions keep capability wording; **AR1–AR10 rewritten** (AR1 scaffold = `docker` Keycloak + baseline realm import **and** `rails new` admin; AR2 = Postgres KC+Rails DBs, no Redis; AR3 = Keycloak engine, no Bun-conformance; AR4 = Keycloak-native keys, no Vault; AR5 = Keycloak Events→WORM + Rails audit; AR6 = Nginx+Docker, realm-export backups; AR7 = Rails CI gates; AR8 secret hygiene unchanged; AR9 +Keycloak health/metrics; AR10 org gates unchanged). **UX-DR1–UX-DR12 re-pointed** (UX-DR1 = Ministry Bronze **Keycloak theme** + **Rails styling**; UX-DR3 component set **split** auth-surface-theme vs Rails-admin; UX-DR11 = **Keycloak message bundles + Rails i18n** not Paraglide).
- **FR Coverage Map:** re-pointed per the Epic table in §2.1 (e.g., FR1–11 → "Epic 1 — configure Keycloak"; FR26–31 → "Epic 3 — Rails over Admin API"; FR38 → "Epic 5 — Keycloak events → off-host WORM").
- **Stories (all 6 epics):** re-pivoted. Representative new shapes:
  - **E1:** *1.1 Stand up Keycloak (Docker) + baseline realm + secret hygiene; 1.2 Realm OIDC config (Auth-Code+PKCE-only, exact redirect, token TTL, session, brute-force, password policy); 1.3 Realm keys + JWKS + discovery (RS256 + rotation); 1.4 User model + work-email claim mapper + lifecycle mapping; 1.5 Reference client proving end-to-end SSO; 1.6 Login + OTP flow config; 1.7 Audit/events baseline enabled.* (Collapses several old build-stories into config-stories.)
  - **E2:** *Custom Keycloak theme (login/OTP/activation/reset/email) from DESIGN tokens; Noto fonts; en/th message bundles (security-critical Thai-first); first-login activation required-action flow; self-service reset flow; token/action lifespans + pending expiry; WCAG AA + anti-phishing copy.*
  - **E3:** *Rails app + Keycloak-OIDC login + HR role gate; create/search users (Admin API); enable/disable + session revocation; hardened password/MFA reset (FR44 attestation + notify + execute-actions-email re-pending); CSV import (validate/dedupe/preview/confirm/throttle → Admin API); profile edit w/ controlled email-key change; Ministry Bronze Rails styling.*
  - **E4:** *System role gate + step-up re-auth + CSRF; register/manage OIDC clients (`private_key_jwt`/secret rotation overlap, exact redirect, scopes) via Admin API; admin-user + realm-role management.*
  - **E5:** *Keycloak event config + Event Listener → off-host WORM sink; Rails-side audit for Rails actions; unified audit view/export in Rails (reads audited); 12-month retention; scheduled second-person export; PDPA artifacts + erasure/retention reconciliation (pseudonymize subject in retained events).*
  - **E6:** *OIDC integration guide ("integrate as a Keycloak client") + polished reference client; Nginx edge (TLS/HSTS/rate-limit/headers) fronting Keycloak + Rails; Docker Compose deploy + tested backups (Postgres + realm export/keys); Rails CI security gates (rubocop/brakeman/bundler-audit/gitleaks) + monitoring (incl. Keycloak health + SMTP deliverability); pre-pilot assurance (independent Keycloak-config review + ASVS L2 on Rails surface + pen test; confirm OQ1/OQ3).*

### 4.5 UX docs — no edits

`DESIGN.md` and `EXPERIENCE.md` are **unchanged**. The DESIGN tokens drive the Keycloak theme + Rails styling; the EXPERIENCE spine (IA, flows, states, voice, a11y, journeys) is implemented across the themed Keycloak surfaces (staff auth) + Rails views (admin). The minor "custom vs daisyUI" reconciliation note tracked in the old architecture/readiness docs is now moot.

### 4.6 Stale review artifacts — pointer edits only

- `implementation-readiness-report-2026-06-20.md`: add a **superseding banner** — "Assessed the pre-pivot stack; superseded by the 2026-06-20 Keycloak+Rails Sprint Change Proposal. Re-run `bmad-check-implementation-readiness` against the revised PRD/Architecture/Epics before sprint planning."
- `prds/.../review-security.md`: add a **dated header note** — the review remains the security bar; under Keycloak, C4 (key custody) and much of C1/C3 are satisfied by the engine, the remaining hardening targets are the Rails admin layer + Keycloak configuration; full mapping in this proposal §2.3.

---

## Section 5 — Implementation Handoff

**Change scope classification: MAJOR** (re-architecture + headline-risk reframe) — but executed as a **Direct Adjustment** (requirement spine and epic structure intact, no rollback).

**Handoff recipients & responsibilities (solo project — Rawinan wears each hat):**
- **Product Manager hat:** approve the PRD §1 mandate/risk reframe + R10–R12 (this proposal, §4.1/§4.2).
- **Architect hat:** own the architecture.md rewrite (§4.3) and the Keycloak hardening checklist; verify Admin-API gem/adapter and OIDC-login gem maintenance at scaffold.
- **Scrum/PO hat:** apply the epics reshape (§4.4); then run `bmad-sprint-planning` to regenerate `sprint-status.yaml` from the revised epics (none exists yet).
- **Dev hat:** execute Story 1.1 (stand up Keycloak + baseline realm) first.

**Success criteria for this change:**
1. PRD, Addendum, Architecture, Epics updated and mutually consistent (Keycloak + Rails throughout; no residual node-oidc-provider/Bun/Vault/Redis/daisyUI/Paraglide references except as explicitly-superseded history).
2. All 50 FRs still traceable to an epic/story (capabilities preserved; mechanisms remapped).
3. Stale review artifacts flagged; readiness re-validation queued.
4. The honest "we chose the riskier path" framing is resolved in-doc to "sovereign self-hosted engine + custom in-house admin."

**Recommended next steps after approval:**
1. Apply the artifact edits (PRD + addendum + architecture + epics + pointer banners).
2. Re-run `bmad-check-implementation-readiness` against the revised set.
3. Run `bmad-sprint-planning` to generate `sprint-status.yaml`.
4. Begin Story 1.1 (Keycloak stand-up).

---

## Appendix — Change Navigation Checklist (status)

- **§1 Trigger & context:** [x] — owner-confirmed strategic pivot; evidence in PRD §1/addendum §A + security review C1–C4.
- **§2 Epic impact:** [x] — 6-epic spine kept; each re-pivoted; no add/remove; sequencing watch-item swapped (Bun→Keycloak stand-up).
- **§3 Artifact conflict:** [x] — PRD moderate, Addendum/Architecture/Epics high, UX none, review artifacts historical/superseded.
- **§4 Path forward:** [x] — Option 1 Direct Adjustment selected; Options 2 (rollback) N/A, 3 (MVP cut) N/A.
- **§5 Proposal components:** [x] — this document.
- **§6 Final review & handoff:** [ ] **Action-needed — awaiting explicit user approval** before any artifact edits (HALT gate).
