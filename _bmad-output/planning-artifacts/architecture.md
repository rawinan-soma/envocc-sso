---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
inputDocuments:
  - _bmad-output/planning-artifacts/briefs/brief-envocc-sso-2026-06-19/brief.md
  - _bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-21/prd.md
  - _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/EXPERIENCE.md
workflowType: 'architecture'
project_name: 'envocc-sso'
user_name: 'Rawinan'
date: '2026-06-22'
status: 'complete'
completedAt: '2026-06-22'
---

# Architecture Decision Document — envocc-sso

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

> **Change Note (2026-06-22) — two login methods.** Per user decision, staff may sign in via
> **(1) email + password + TOTP MFA** (native Keycloak) *or* **(2) Login with ThaiD**, the
> latter implemented as **Keycloak identity brokering** — ThaiD configured as an external OIDC
> Identity Provider in realm config-as-code (native Keycloak, no custom auth code), with a
> first-broker-login flow that links by **national ID (PID)**. Both resolve to the same
> canonical identity; **Keycloak remains the IdP** to relying parties. The password+TOTP path
> is the always-available baseline/fallback; ThaiD uses a **mock OIDC IdP** in dev/CI. See
> Decision 2; affects Decision 1's engine note, the data store, component mappings, the
> implementation sequence, and the project tree. Open with DOPA: RP terms + claims (esp. PID).

## Workflow Context (Step 1)

**Project:** envocc-sso — EnvOcc's single sign-on / central identity system. Two co-equal halves: staff-auth (login, MFA, activation, reset) + one role-gated admin console (HR + System). Security rigor is the definition of done; built solo; phased pilot.

**The headline decision this workflow must make — PRD OQ2:** the **build approach is OPEN** — *(a) build the IdP ground-up, (b) self-host **Keycloak**, or (c) self-host **Authentik*** (or comparable inspectable self-hostable OSS IdP). The PRD is capability-level and names no stack; this architecture chooses it, weighed against the security bar, the solo-operator burden, and the UX-ownership requirement.

**Hard inputs carried in:**
- **PRD (final):** FR1–FR50, NFR1–NFR19. Security/PDPA hard gates (NFR10 independent ASVS review + pen-test; NFR15 PDPA RoPA/DPO/breach-runbook pre-pilot). NFR8: no hand-rolled crypto/token/session logic — use audited components only. 24/7 target, single-instance baseline.
- **UX (final):** DESIGN.md (Calm Clinical / Deep Sea tokens, light-mode, WCAG AA — branded UX is the #1 anti-phishing signal) + EXPERIENCE.md (17 surfaces, role-gated admin, top-level-only auth). **Stack-agnostic** — custom design system, no framework named.
- **Brief:** sovereignty/self-hosted/fully-owned mandate; full ownership of the branded UX regardless of approach.

**Open items from the PRD to resolve or carry:** OQ1 (pilot apps), OQ3 (named DPO/second person), OQ4 (assessment funding), and the confidential-client `[ASSUMPTION]`.

## Project Context Analysis

### Requirements Overview
- FRs (FR1–FR50, 8 groups): FG-1 OIDC core, FG-2 staff experience, FG-3 identity
  store, FG-4 HR console, FG-5 System console, FG-6 audit, FG-7 integration,
  FG-8 security hardening. How many are "configure" vs "build" depends on OQ2.
- NFRs (NFR1–NFR19): security/crypto custody, standards + independent-validation
  HARD GATES (NFR10), PDPA pre-pilot gates (NFR15), 24/7 single-instance, low scale.
- Driving forces: SECURITY + COMPLIANCE, not performance.

### Scale & Complexity
- Split-profile: LOW scale/perf (~150 users, p95 ≤ 500 ms), HIGH security-criticality
  + PDPA compliance.
- Domain: self-hosted, on-prem identity platform (auth surface + admin console +
  audit pipeline + security edge).

### Technical Constraints & Dependencies
- **OQ2 OPEN:** ground-up vs self-hosted Keycloak vs self-hosted Authentik — the
  headline decision (Step 4). NFR8 (no hand-rolled crypto) weighs against ground-up
  for the credential core.
- Sovereignty: on-prem, self-hosted, fully inspectable; no foreign SaaS.
- Full UX ownership required regardless of approach (branded auth + admin console).
- SMTP critical-path; audit must ship off-host/WORM; abuse protection at the edge.
- UX = form-CRUD admin + themed auth, no real-time/offline → low client complexity.

### Cross-Cutting Concerns
- Security (authn primitives audited, not hand-rolled); audit/observability
  (off-host WORM + audited reads); PDPA (RoPA/retention/erasure-pseudonymization);
  separation of duties (role-gated); localization (externalized strings, Thai later);
  agentic-build verification loop (owner priority); deployment topology (on-prem
  containers + single security edge).

## Starter / Foundation Evaluation

- For this project the "starter" is the **OQ2 build-approach choice** (Step 4), not a
  generic template. **Approach-independent foundation:** on-prem Docker containers +
  PostgreSQL + single Nginx security edge + config-as-code, pinned versions.
- Contingent on OQ2 (resolved Step 4): the engine/scaffold (Keycloak image vs
  Authentik deployment vs ground-up skeleton), the admin-layer stack, and exact
  version pins (web-verified at the point of choice).

## Core Architectural Decisions

### Decision 1 — Build approach (PRD OQ2): **self-hosted Keycloak**
The IdP engine is **self-hosted Keycloak** (on-prem). Rationale: NFR8 forbids
hand-rolled crypto/token/session logic → an audited engine is required (rules out
ground-up); among audited engines, Keycloak is the most OpenID-certified, most
CVE-patched, best-documented, and most battle-tested — the right fit for a
security-critical, sole-system-of-record IdP run by a solo operator where "security
rigor is the definition of done." Authentik was the runner-up (more modern, less
proven). Keycloak provides: OIDC + PKCE, MFA (TOTP + WebAuthn), **identity brokering**
(used for **Login with ThaiD**, Decision 2), password policy + breach screening, brute-force,
session/token/key rotation, email flows, Admin REST API, custom theming, and an events system
for the audit pipeline.
**Residual risk (R10):** Keycloak operational expertise — mitigated by config-as-code,
the official hardening guide, pinned versions, and the NFR10 independent review.
**Custom surface this leaves to build:** (1) a branded login **theme**, (2) a thin
**admin layer** over the Keycloak Admin REST API (the FG-4/FG-5 console), (3) the
**off-host audit pipeline**, (4) the **reference client + integration guide**. *(Login with
ThaiD adds **no custom auth code** — it is realm-level IdP brokering config; Decision 2.)*

> Versions (web-verified, Jun 2026; re-pin at finalize): Keycloak **26.6.3**,
> SvelteKit **2.57** / Svelte **5.55**, **Bun 1.3.x**, Node **24 LTS**, Tailwind **v4**,
> shadcn-svelte (Svelte 5-native). Pin all by exact version/digest — never `:latest`.

### Decision 2 — Custom-surface stack
- **Login theme:** a **native Keycloak theme** styled with the DESIGN.md **Deep Sea**
  CSS tokens. Keeps the security-critical auth surface minimal — **no JS framework in
  the login path** (NFR8-aligned), **top-level-only** (anti-phishing, FR12), and
  **externalized strings** (English-first, Thai-later).
- **Admin layer:** a **SvelteKit (Svelte 5 / TypeScript)** app over the Keycloak Admin
  REST API — the FG-4/FG-5 console. Typed (agentic-build verification), form-CRUD fits,
  and it consumes the **same Deep Sea tokens** as the theme (visual parity, no shared
  framework — just shared CSS variables).
- **Login with ThaiD — alternative login (user decision, 2026-06-22):** alongside
  email+password+TOTP, the realm offers **"Login with ThaiD"** via **Keycloak identity
  brokering** — ThaiD configured as an external **OIDC Identity Provider** in
  `realm-export.json` (config-as-code, **native Keycloak — no hand-rolled auth, NFR8-aligned**).
  A **first-broker-login** flow links the incoming ThaiD identity to the pre-created staff
  account by **national ID (PID)**. Both paths resolve to the same canonical identity and
  tokens; **Keycloak stays the IdP** to relying parties. In dev/CI the broker points at a
  **mock OIDC IdP** (no DOPA access needed). **Residual (R8a):** the ThaiD path depends on DOPA
  availability — but the **password+TOTP path is the always-available fallback**, so DOPA
  downtime never blocks all logins; **confirm RP terms + claims (esp. PID) with DOPA**
  (external unknown, alongside OQ1/OQ3/OQ4).

### Decision 3 — Supporting stack & cross-cutting (confirmed slate)

**Data Architecture**
- **PostgreSQL**, two separate databases: Keycloak's store (identities, credentials,
  TOTP secrets, the ThaiD broker link (PID mapping), sessions) and the **admin DB** (app sessions + app-side audit + CSV
  staging only — **no canonical identities**; Keycloak stays system of record, NFR13).
- **Drizzle** ORM + `drizzle-kit` migrations. Encryption at rest; least-privilege,
  network-isolated DB access (NFR1/NFR13).
- Boundary validation: **Valibot** on every Admin-API response and form payload.

**Authentication & Security**
- **Admin sign-in:** OIDC Auth Code + PKCE into Keycloak via **`openid-client`** (NFR8).
- **Sessions:** server-side, **DB-backed**, `__Host-` Secure/HttpOnly/SameSite=Lax;
  **regenerate session id on every auth-state transition** (FR45); server-side
  invalidation on disable/force-logout (FR46).
- **Step-up re-auth:** fresh OIDC re-auth (`max_age=0`) before reset-MFA /
  register-client / manage-admins (FR50).
- **Role gating:** Keycloak **realm roles** (`hr-admin`, `system-admin`) enforced
  server-side in `hooks.server.ts` (FR33; HR & System sections never shown together).
- **Admin-API authority:** a dedicated **least-privilege service-account client**
  (`realm-management` roles) behind a **thin, typed, Valibot-validated adapter**;
  Keycloak version pinned; **integration-tested against a running Keycloak** (R11);
  every privileged call audited.
- **CSRF:** SvelteKit form-actions `Origin` checking (the reason for `adapter-node`)
  + explicit checks on sensitive admin actions (FR50).
- **No hand-rolled auth primitives** — Keycloak owns crypto/tokens/sessions/keys/
  brute-force for end users (NFR8).

**Frontend Architecture (admin app)**
- **Svelte 5 runes**; SvelteKit file-based routing with **role-gated route groups**.
- **Tailwind v4 + shadcn-svelte** (copy-in, bits-ui-accessible) **rethemed to Deep Sea,
  light-mode only**; component mappings — code-input (6-digit TOTP), a **Login-with-ThaiD** button, data-table (user list),
  badge (status pills, text+icon not color alone), alert (4-state + anti-phishing),
  dialog (step-up). WCAG 2.1 AA per EXPERIENCE.md.

**API & Communication**
- **Keycloak Admin REST API adapter (R11):** thin typed module, Valibot contracts,
  pinned KC, KC integration tests in CI — the single coupling point.
- Internal: SvelteKit **`load`** (reads) + **form actions** (mutations), typed end-to-end.
  **Generic, enumeration-safe** user-facing errors (FR20); structured logs feed audit.
- **Audit:** Keycloak **events (Event Listener SPI)** + admin-app events → **off-host
  append-only / WORM sink** (e.g., object storage with object-lock; product deferred);
  **audit reads/exports themselves audited** (FR34); **12-month retention** (FR38/FR39).

**Infrastructure & Deployment**
- **Foundation:** Keycloak 26.6.x (pinned by digest) + PostgreSQL + **single Nginx
  security edge** (TLS/HSTS, rate-limiting/abuse per FR50), on-prem **Docker Compose**.
  Realm **config-as-code** (exported JSON in git, secrets stripped). SMTP via Keycloak
  (activation/reset/verify), monitored critical-path with admin-reset fallback (NFR16).
- **Admin app:** built with `adapter-node`, **run under the Bun runtime**, behind the
  same Nginx edge.
- **Agentic-build / CI gate (inner loop + CI):** Prettier · ESLint · `tsc` +
  `svelte-check` · **Semgrep** (SAST) · **gitleaks** · `bun audit` · Vitest/Playwright
  · Keycloak realm-config lint (NFR9).
- **Backup/restore (NFR17):** Keycloak PostgreSQL + realm export/keys + admin DB —
  tested, with stated RTO/RPO and a key-loss/compromise runbook. **Single instance to
  start; HA deferred.**
- **Deferred:** the WORM sink product; the Keycloak pin (latest 26.6.x patch line vs an
  LTS line); refresh-token issuance (optional in v1 — if issued, rotate + reuse-revoke,
  FR9).

### Decision Impact Analysis

**Implementation sequence:**
1. Docker Compose foundation — pinned Keycloak + PostgreSQL + Nginx; realm config-as-code.
2. Keycloak realm config — clients, Auth Code+PKCE, MFA (TOTP), **Login with ThaiD** via
   identity brokering (ThaiD OIDC IdP + first-broker-login PID linking; mock OIDC IdP in dev),
   password policy + breach screening, brute-force, token/session lifetimes (≤15 min),
   events enabled.
3. Native **Deep Sea** login/account/email theme (externalized strings, top-level-only).
4. SvelteKit admin scaffold (Bun, TS, Tailwind, shadcn-svelte, ESLint/Prettier/Playwright)
   + the agentic-build gate wired into CI and the agent loop.
5. OIDC admin sign-in (`openid-client`) + DB-backed sessions + role gating.
6. Typed Keycloak Admin REST API adapter + Valibot contracts + KC integration tests.
7. HR features (FG-4): create/search, enable/disable, reset (FR44 attestation), CSV
   import (FR49 preview).
8. System features (FG-5): clients, admin users, audit views.
9. Audit pipeline → off-host WORM sink (FR38); audit-read auditing (C2/C3).
10. Reference client + OIDC integration guide (FG-7).

**Cross-component dependencies:** `adapter-node` ← form-action CSRF/`Origin`; role gating
← Keycloak realm roles; admin DB scope ← sessions + app-audit only; agentic gate ← every
story (standing verification layer).

## Implementation Patterns & Consistency Rules

> Consistency rules so multiple AI agents write compatible code. The stack has strong
> idiomatic defaults — these pin the choices agents could otherwise make differently.

### Naming
- **Database (PostgreSQL / Drizzle):** `snake_case`; **plural tables** (`audit_events`,
  `admin_sessions`, `csv_imports`); `id` primary key; `*_at` for timestamps; foreign keys
  `<entity>_id`; indexes `idx_<table>_<cols>`.
- **TypeScript:** `camelCase` variables/functions; `PascalCase` types, interfaces, and
  `.svelte` components; Valibot schemas named `XxxSchema`; adapter methods are verbs
  (`createUser`, `disableUser`, `registerClient`).
- **Routes (SvelteKit):** file-based; role-gated route groups `(auth)` / `(hr)` /
  `(system)`; `+page.server.ts` for server logic, `+page.svelte` for UI.
- **Keycloak:** realm roles and client IDs `kebab-case` (`hr-admin`, `system-admin`).
- **Audit events:** `domain.action`, **past tense** (`user.disabled`, `client.registered`,
  `mfa.reset`, `audit.exported`).

### Structure
- `src/lib/server/**` = **server-only** (Keycloak adapter, db, sessions, secrets) — an
  **ESLint rule blocks any client-side import** of this path.
- `src/lib/server/keycloak/` (Admin-API adapter) · `src/lib/server/db/` (Drizzle schema +
  migrations) · `src/lib/validation/` (Valibot schemas) · `src/lib/components/` (UI).
- Unit tests **co-located** as `*.test.ts`; Playwright e2e in `tests/`; **Keycloak
  integration tests** in `tests/integration/` (run against a live Keycloak in CI).
- `keycloak/realm-export.json` (config-as-code, secrets stripped) · `keycloak/themes/envocc/`
  (native Deep Sea theme) · `compose.yaml` at repo root.

### Formats
- **Dates/times:** ISO-8601 UTC strings everywhere (API, DB, logs).
- **Validation:** **Valibot at every server boundary** (form actions + Admin-API adapter)
  is the source of truth; client-side hints are **UX-only, never the security boundary**.
- **Errors:** typed; user-facing messages are **generic and enumeration-safe** (FR20);
  internal detail is logged, never returned; adapter errors mapped centrally.
- **User reference:** the Keycloak **`sub` (UUID)** only — **no identity PII persisted in
  the admin DB** (Keycloak is the system of record).

### Process & Communication
- **Reads via `load`, mutations via form actions** (server-side `Origin`/CSRF). Local UI
  state via **Svelte 5 runes**; no global state library.
- **Every protected route** checks session + role in `hooks.server.ts`; **sensitive ops**
  (reset MFA, register client, manage admins) require a **`max_age=0` step-up** re-auth.
- **Logging:** structured JSON with levels; **never log credentials, tokens, MFA secrets,
  or PII** (FR39). **Audit events** are distinct from application logs and ship to the
  off-host WORM sink.

### Enforcement (mandatory for all agents)
1. Validate at the boundary with Valibot — no unparsed external data flows inward.
2. Identities stay in Keycloak; the admin DB holds only sessions/audit/CSV-staging.
3. Never hand-roll an auth primitive — drive Keycloak via the typed adapter only.
4. All auth-flow responses are generic and enumeration-safe.
5. Never log secrets/tokens/PII.
The **agentic-build gate** (Prettier · ESLint · `tsc`/`svelte-check` · Semgrep · gitleaks ·
`bun audit` · Vitest/Playwright · realm-config lint) enforces these on every change, in the
agent's inner loop and in CI.

## Project Structure & Boundaries

### Complete Project Tree (monorepo, on-prem)

```
envocc-sso/
├── compose.yaml                 # Keycloak + Postgres(es) + Nginx + admin app
├── .env.example                 # secrets never committed; gitleaks-checked
├── README.md
├── lefthook.yml                 # pre-commit: the agentic-build gate
├── .github/workflows/ci.yml     # gate in CI: prettier·eslint·tsc·svelte-check·semgrep·gitleaks·tests
├── design-tokens/
│   └── deep-sea.css             # SHARED Deep Sea CSS variables (theme + admin both import)
├── nginx/
│   └── nginx.conf               # single security edge: TLS/HSTS, rate-limit/abuse (FR50)
├── keycloak/
│   ├── Dockerfile               # pinned Keycloak 26.6.x + theme + event provider
│   ├── realm-export.json        # config-as-code (secrets stripped) — FG-1/3/8 realm config + ThaiD IdP broker (Decision 2)
│   ├── themes/envocc/           # FG-2 native Deep Sea theme (login / account / email)
│   └── providers/               # Event Listener SPI → audit (FG-6)
├── postgres/
│   └── init/                    # creates separate DBs: keycloak, admin
├── admin/                       # SvelteKit + Bun admin app (FG-4 / FG-5)
│   ├── package.json  svelte.config.js (adapter-node)  vite.config.ts  tsconfig.json
│   ├── drizzle.config.ts  playwright.config.ts  eslint.config.js  .prettierrc
│   ├── src/
│   │   ├── app.html   app.css (imports ../../design-tokens/deep-sea.css)
│   │   ├── hooks.server.ts      # session + role gate + CSRF (FR33/FR45/FR50)
│   │   ├── lib/
│   │   │   ├── server/keycloak/ # typed Admin-REST adapter + Valibot (R11)
│   │   │   ├── server/db/        # Drizzle schema + migrations
│   │   │   ├── server/auth/      # openid-client, sessions, step-up
│   │   │   ├── server/audit/     # emit audit events → WORM (FG-6)
│   │   │   ├── validation/       # Valibot schemas
│   │   │   └── components/       # shadcn-svelte (Deep Sea, light-only)
│   │   └── routes/
│   │       ├── (auth)/           # admin OIDC sign-in + callback
│   │       ├── (hr)/             # FG-4: users · create · detail · csv-import
│   │       └── (system)/         # FG-5: clients · admins · audit
│   ├── tests/integration/       # against a live Keycloak in CI
│   └── tests/e2e/               # Playwright
├── reference-client/            # FG-7 sample OIDC client
└── docs/
    ├── integration-guide.md     # FG-7
    ├── runbooks/                # key-loss, breach (NFR15/NFR17)
    └── pdpa/                    # RoPA, lawful-basis (NFR11/NFR15)
```

### Architectural Boundaries
- **API boundary:** the only integration into Keycloak is its **Admin REST API**, wrapped by
  `lib/server/keycloak/` (typed, Valibot, pinned, integration-tested), plus Keycloak's OIDC
  endpoints (admin sign-in + RP integration). The admin app **never touches Keycloak's DB**.
- **Server/client boundary:** `lib/server/**` is server-only (ESLint-blocked from client).
- **Data boundary:** two separate Postgres DBs — Keycloak's (identities/credentials) and the
  admin DB (sessions/audit/CSV-staging only). No cross-DB access.
- **Audit boundary:** Keycloak events (SPI) + admin events → off-host WORM (write-only from
  the app's perspective; reads are audited).

### Requirements → Structure Mapping
- FG-1 OIDC core / FG-3 identity store / FG-8 hardening → `keycloak/realm-export.json`.
- FG-2 staff experience → `keycloak/themes/envocc/` + realm flows.
- FG-4 HR console → `admin/src/routes/(hr)/` + `lib/server/keycloak/`.
- FG-5 System console → `admin/src/routes/(system)/`.
- FG-6 audit → `keycloak/providers/` + `admin/src/lib/server/audit/` → WORM.
- FG-7 integration → `reference-client/` + `docs/integration-guide.md`.

## Architecture Validation Results

### Coherence ✅
All technology choices compatible and version-aligned (Keycloak 26.6 · SvelteKit 2.57 /
Svelte 5 · Bun 1.3 · Node 24 LTS · Drizzle · PostgreSQL · Tailwind v4 / shadcn-svelte ·
Valibot · openid-client); patterns support the decisions; project structure + boundaries
enable the chosen stack. No contradictions.

### Requirements Coverage ✅
- **FR1–FR50:** every FG mapped — FG-1/3/8 → Keycloak config; FG-2 → theme + flows;
  FG-4/5 → SvelteKit admin; FG-6 → events SPI + admin audit → WORM; FG-7 → reference client.
- **NFR1–NFR19:** crypto/custody (Keycloak), standards + independent-validation HARD GATES
  (NFR10), PDPA (docs + NFR15 gates), reliability/backup (NFR17), scale/localization — addressed.

### Implementation Readiness ✅
Decisions versioned; patterns + consistency rules enforceable via the agentic-build gate;
complete project tree + explicit boundaries; FR→structure mapping done.

### Gap Analysis
- **Important (deferred, named):** WORM-sink product; Keycloak pin line (26.6.x vs LTS);
  refresh-token issuance (optional v1).
- **Process (not architecture):** OQ1 pilot apps, OQ3 named DPO, OQ4 assessment budget.
- **No critical gaps.**

### Architecture Completeness Checklist
**Requirements Analysis** — [x] context · [x] scale/complexity · [x] constraints · [x] cross-cutting
**Architectural Decisions** — [x] versioned decisions · [x] stack specified · [x] integration patterns · [x] performance/security
**Implementation Patterns** — [x] naming · [x] structure · [x] communication · [x] process
**Project Structure** — [x] directory tree · [x] boundaries · [x] integration points · [x] requirements mapping

### Architecture Readiness Assessment
**Overall Status:** READY FOR IMPLEMENTATION (16/16 checklist items; no critical gaps).
**Confidence Level:** high.
**Key Strengths:** audited engine (NFR8-aligned); minimal auth-path surface; typed
agentic-build verification loop; clean Keycloak/admin boundary; security/PDPA gates as
hard requirements.
**Future Enhancements:** HA topology; WebAuthn (post-v1); WORM-sink hardening.

### Implementation Handoff
- **AI agents must:** follow the decisions exactly; apply the consistency rules; respect
  the boundaries (`lib/server/**` server-only; identities stay in Keycloak; no hand-rolled
  auth); validate at boundaries with Valibot; keep errors enumeration-safe; never log secrets.
- **First priority:** the Docker Compose foundation (pinned Keycloak + PostgreSQL + Nginx,
  realm config-as-code), then the SvelteKit admin scaffold + agentic gate.
