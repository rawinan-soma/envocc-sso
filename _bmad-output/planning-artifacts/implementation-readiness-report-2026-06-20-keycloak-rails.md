---
stepsCompleted: [1, 2, 3, 4, 5, 6]
status: 'complete'
date: 2026-06-20
supersedes: implementation-readiness-report-2026-06-20.md
context: 'Fresh readiness assessment of the post-pivot artifact set (Keycloak IdP + Ruby on Rails admin layer). See sprint-change-proposal-2026-06-20.md.'
inputDocuments:
  - prds/prd-envocc-sso-2026-06-19/prd.md
  - prds/prd-envocc-sso-2026-06-19/addendum.md
  - prds/prd-envocc-sso-2026-06-19/review-security.md
  - architecture.md
  - epics.md
  - ux-designs/ux-envocc-sso-2026-06-20/DESIGN.md
  - ux-designs/ux-envocc-sso-2026-06-20/EXPERIENCE.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-06-20 (re-run after the Keycloak + Rails stack pivot)
**Project:** envocc-sso

## Step 1 — Document Inventory

| Type | Document(s) | Format | Status |
|------|-------------|--------|--------|
| **PRD** | `prds/prd-envocc-sso-2026-06-19/prd.md` (+ `addendum.md`, `review-security.md`) | whole | ✅ found (revised) |
| **Architecture** | `architecture.md` | whole | ✅ found (re-architected → Keycloak + Rails) |
| **Epics & Stories** | `epics.md` | whole | ✅ found (reshaped, 6 epics re-pivoted) |
| **UX Design** | `ux-designs/ux-envocc-sso-2026-06-20/DESIGN.md` + `EXPERIENCE.md` | whole | ✅ found (unchanged by pivot) |

**Issues:** none. No whole/sharded duplicates; no missing required documents. The prior `implementation-readiness-report-2026-06-20.md` is **superseded** (banner added). Supporting files (`sprint-change-proposal-2026-06-20.md`, reconcile, rubric, decision logs, Claude Design brief) are present as context, not primary assessment inputs.

## Step 2 — PRD Analysis

> The pivot kept FRs and NFRs at the **capability level** (50 FRs / 20 NFRs); only the implementing mechanism moved (Keycloak config and/or the Rails layer). Count and IDs are stable.

### Functional Requirements (50)
- **FG-1 OIDC core (→ configure Keycloak):** FR1 Auth Code+PKCE · FR2 IdP-hosted login · FR3 no Implicit/ROPC · FR4 exact redirect match · FR5 signed ID token+JWKS · FR6 state/nonce · FR7 SSO session · FR8 session lifetimes · FR9 short tokens+refresh rotation · FR10 RP-initiated logout · FR11 discovery
- **FG-2 Staff auth (→ Keycloak theme + flows):** FR12 branded login · FR13 MFA enroll · FR14 TOTP verify · FR15 admin MFA reset · FR16 activation · FR17 self-service reset · FR18 password policy · FR19 brute-force · FR20 enumeration resistance
- **FG-3 Identity store (→ Keycloak users + claim mapper):** FR21 canonical identity · FR22 work-email key · FR23 minimal attributes · FR24 lifecycle states · FR25 disable blocks auth everywhere
- **FG-4 HR console (→ Rails over Admin API):** FR26 create · FR27 search/list · FR28 enable/disable · FR29 trigger reset/MFA reset · FR30 CSV import · FR31 profile edit
- **FG-5 System console (→ Rails over Admin API):** FR32 client registration+rotation · FR33 admin-user/role mgmt · FR34 audit view/export
- **FG-6 Audit (→ Keycloak events → off-host WORM + Rails audit):** FR35 auth events · FR36 admin actions · FR37 token/key events · FR38 append-only/off-host/12-mo *(hash-chain relaxed to WORM integrity)* · FR39 no-secrets + second-person export
- **FG-7 Integration:** FR40 guide · FR41 integration contract · FR42 claim contract · FR43 reference client
- **FG-8 Operational security:** FR44 admin-reset hardening (Rails+execute-actions-email) · FR45 session-id regeneration (KC-native) · FR46 revocation on disable (Admin API) · FR47 auth-code/PKCE/nonce single-use (KC-native) · FR48 token hygiene · FR49 CSV validation (Rails) · FR50 edge abuse protection (Nginx) + step-up
**Total FRs: 50**

### Non-Functional Requirements (20)
NFR1 **Keycloak Argon2id, no app pepper** · NFR2 TOTP/action-token protection (KC) · NFR2a token TTL ≤15 min · NFR3 **Keycloak realm keys** RS256/rotatable JWKS · NFR4 TLS/cookies/CSP (Nginx+KC) · NFR5 RFC 9700 (certified engine) · NFR6 ASVS L2 **scoped to KC config + Rails** + independent review · NFR7 NIST 800-63B + per-account (KC)/per-IP (Nginx) brute-force · NFR8 **audited engine (Keycloak) + maintained gems; no hand-rolled security logic** · NFR9 CI dep-scan (`bundler-audit`)+SAST (`brakeman`) · NFR10 independent KC-config+Rails review + pen test · NFR11 lawful basis/RoPA · NFR12 no §26 sensitive data · NFR13 data minimization/encryption-at-rest · NFR14 retention/erasure reconciliation · NFR15 PDPA gates before pilot · NFR16 Keycloak SMTP critical path · NFR17 24/7 + SPOF + tested backups (KC Postgres+realm/keys+Rails DB) · NFR18 ~150 users, p95 ≤500 ms · NFR19 English-first/Thai-ready (KC `messages_th` + Rails i18n)
**Total NFRs: 20**

### Additional Requirements / Constraints
- **Architecture (AR1–AR10, re-pointed):** AR1 scaffold = stand up Keycloak + baseline realm import **then** `rails new`; AR2 Postgres KC+Rails DBs, **no Redis**; AR3 Keycloak engine (configured), **no Bun-conformance**; AR4 **Keycloak-native keys, no Vault**; AR5 Keycloak events→WORM + Rails audit; AR6 Nginx edge + **Kamal** Rails deploy + realm-export backups; AR7 Rails CI gates; AR8 secret hygiene (realm exports secret-stripped); AR9 +Keycloak health/metrics; AR10 org gates before pilot.
- **Open questions:** OQ1 pilot apps (TBD) · **OQ2 build stack RESOLVED** → Keycloak + Rails + Postgres + Nginx · OQ3 named second person for audit oversight (TBD).
- **New risks from the pivot:** R10 Keycloak ops/hardening expertise · R11 Admin-API coupling · R12 two-runtime surface. **R1 headline risk materially reduced** (community-reviewed engine replaces the from-scratch build).
- **Standing assumptions:** pilot apps are confidential server-side clients (confirm at integration; `private_key_jwt` preferred); protagonist names illustrative.

### PRD Completeness Assessment
**Strong / final, and internally consistent post-pivot.** The PRD retains its 50 FRs (stable IDs) and 20 NFRs with product-specific thresholds; the mandate/risk framing was revised coherently (sovereignty reading; R1 reframed; R10–R12 added; OQ2 resolved). NFR1 (no app pepper) and NFR3/NFR8 (Keycloak-owned crypto) are the substantive reframes and are internally consistent with the addendum and architecture. No gaps that would impede traceability validation.

## Step 3 — Epic Coverage Validation

### Coverage Matrix (by epic — re-pivoted, all FRs re-pointed)
| FRs | Epic | Mechanism | Status |
|-----|------|-----------|--------|
| FR1–FR11, FR14, FR18(policy), FR19(per-acct), FR20, FR21–FR23, FR24(model), FR45, FR47, FR35/FR37(events on) | **Epic 1 — Keycloak IdP Foundation & SSO Core** | configure Keycloak realm/keys/clients | ✓ Covered |
| FR12, FR13, FR16, FR17, FR24(transitions), FR48 (+FR18/FR20 in flows) | **Epic 2 — Ministry Bronze Theme, Staff Experience & Recovery** | custom Keycloak theme + flows | ✓ Covered |
| FR15, FR25, FR26–FR31, FR44, FR46, FR49 | **Epic 3 — Rails HR Admin Console** | Rails over Admin API | ✓ Covered |
| FR4(registration), FR32, FR33, FR50(step-up) | **Epic 4 — Rails System Admin Console** | Rails over Admin API | ✓ Covered |
| FR34, FR35–FR39 | **Epic 5 — Audit, Compliance & Oversight** | KC events→WORM + Rails audit | ✓ Covered |
| FR40–FR43, FR19(per-IP), FR50(edge) | **Epic 6 — Integration & Hardening** | guide + Nginx/Kamal/CI | ✓ Covered |

*Intentional layering (verified backward dependencies, not gaps): FR35/FR37 events enabled in Epic 1, captured/shipped in Epic 5; FR18/FR20 set as Keycloak policy in Epic 1, exercised in the themed Epic 2 flows; FR24 model in Epic 1, transitions in Epic 2; FR19 per-account (Keycloak) in Epic 1, per-IP (Nginx) in Epic 6; FR50 step-up (Epic 4) + edge (Epic 6); FR43 client seeded in Epic 1, productionized in Epic 6.*

### Missing Requirements
**None.** All 50 PRD FRs map to at least one epic/story with addressing acceptance criteria. No orphan FRs (no FRs in epics that aren't in the PRD) — the AR1–AR10 and UX-DR1–UX-DR12 items are architecture/UX requirements woven into story ACs, not stray FRs.

### Coverage Statistics
- **Total PRD FRs: 50**
- **FRs covered in epics: 50**
- **Coverage: 100%**
- NFRs (20) and Architecture/UX requirements: woven into the relevant stories' acceptance criteria.

## Step 4 — UX Alignment Assessment

### UX Document Status
**Found** — `DESIGN.md` (visual identity, final) + `EXPERIENCE.md` (IA, flows, states, voice, a11y, journeys, final). **Both unchanged by the pivot** — the DESIGN tokens now drive the implementation surfaces directly.

### UX ↔ PRD Alignment
- ✅ EXPERIENCE.md inherits the PRD by reference (`sources:`) and mirrors the 8 user journeys (UJ-1…UJ-8); every PRD surface (staff auth + the two admin sections) has a home in the IA.
- ✅ Voice/tone rules (plain language, anti-phishing, enumeration-resistance) trace to PRD FR20/NFR19. No UX requirement contradicts the PRD; the UJs remain accurate under Keycloak (the flows — sign-in → OTP, activation, reset — are Keycloak-native and themed).

### UX ↔ Architecture Alignment
- ✅ The architecture honors the UX through **two custom surfaces, both from DESIGN.md tokens**: a **custom Keycloak theme** (staff auth — sign-in, OTP, forgot/email-sent, reset, activate+MFA-enroll, re-activation, signed-out, error) and **Rails views + Tailwind** (the one role-gated admin shell with HR + System sections). Noto fonts, en/th localization (Keycloak `messages_*` + Rails i18n), WCAG 2.1 AA, and top-level/no-iframe (`frame-ancestors 'none'`) are all carried.
- ✅ Component set (AuthCard, CodeInput, PasswordInput, StatusPill, DataTable, Alert/anti-phishing banner, StepUpModal, file-upload/CSV-preview) is mapped **split by surface** (UX-DR3): auth-surface components in the Keycloak theme, admin components in Rails.
- ✅ Performance budget (p95 ≤500 ms, NFR18) is comfortably met by Keycloak at ~150 users; no UI component is unsupported.

### Alignment Issues / Warnings
- ✅ **RESOLVED (was the prior report's only UX warning):** EXPERIENCE.md's *"UI system = custom — no component library named or inherited"* now holds **literally**. The previous architecture imposed **daisyUI** and needed a "spine-wins" reconciliation note; the pivot removes that imposition entirely (custom Keycloak theme + custom Rails views). The reconciliation note has been **withdrawn** in the architecture — net **improvement** in UX↔Architecture coherence.
- 🟡 **New watch-item (non-blocking):** achieving pixel/behaviour parity with DESIGN.md inside **Keycloak's FreeMarker login-theme structure** (e.g. the 6-cell auto-advance/paste CodeInput, the pinned anti-phishing banner) requires custom theme CSS/JS within Keycloak's template conventions. Already captured in the architecture as a "theme a11y/visual parity" watch-item; flagged so it isn't underestimated.
- No major misalignments. UX is complete and fully supported by both the revised PRD and Architecture.

## Step 5 — Epic Quality Review

### Best-Practices Compliance (per epic)
| Epic | User value | Independent | Stories sized | No fwd deps | DB/infra-when-needed | Clear ACs | FR traceability |
|------|:---------:|:----------:|:-------------:|:-----------:|:--------------------:|:---------:|:---------------:|
| 1 Keycloak Foundation & SSO | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 Theme, Staff Experience & Recovery | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 3 Rails HR Console | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 4 Rails System Console | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 5 Audit & Compliance | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 6 Integration & Hardening | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### Validated specifics
- **User value, not technical milestones:** every epic is framed by a user outcome (sign in · onboard/recover · HR-manage · System-onboard apps · oversee · integrate). Epic 1 bundles the Keycloak stand-up but culminates in a *real sign-in + a reference client proving SSO* — the standard "Epic 1 = setup + first capability" pattern, not a standalone "infra" epic. The pivot makes Epic 1 **lighter** (configure Keycloak vs. build an OIDC engine).
- **Starter/first story present & first:** Story 1.1 = **stand up Keycloak (pinned Docker) + import a baseline realm + secret hygiene**, matching the Architecture's stated first priority. The Rails scaffold lands as Story 3.1 (app + Keycloak-OIDC login + the Admin-API adapter), correctly placed at the start of the first Rails epic.
- **No forward dependencies:** stories build only on earlier ones. Verified *backward* layerings (not defects): Epic-1 events → Epic-5 capture/ship; Epic-1 password policy/lifecycle model → Epic-2 themed flows/transitions; Epic-1 per-account brute-force → Epic-6 per-IP edge; the Admin-API adapter is built in Story 3.1 *before* the HR stories that depend on it and is integration-tested.
- **Acceptance criteria:** Given/When/Then throughout, testable, and include error/edge conditions (enumeration resistance, throttling, invalid/expired links, replayed codes, controlled email-key change, dual-secret/`private_key_jwt` rotation overlap).
- **"Configure, don't build":** security-critical stories correctly express Keycloak *configuration* (realm settings, key providers, OTP policy, required actions) rather than re-implementation — consistent with NFR8.

### 🔴 Critical violations
**None.**

### 🟠 Major issues
**None.**

### 🟡 Minor concerns (advisory, non-blocking)
- **Epic 1 is still the longest pole (8 stories)** — though lighter than the pre-pivot build. Sequence carefully (stand-up → OIDC config → keys → identity → flows → reference client → events).
- **Heavier security CI gates land in Epic 6 (Story 6.5).** `gitleaks` is in Story 1.1, but **`brakeman` (SAST) + `bundler-audit` (dep-scan)** arrive in Epic 6. For a security-critical build, enable them in CI **earlier** (as soon as the Rails app exists in Epic 3). *(Carryover advisory from the prior report — still applies.)*
- **Epic 2 activation/reset testing needs a seeded *pending* account** (created directly via the Admin API/script) until Epic 3's HR "create user" lands — the same backward-seed pattern as the Epic-1 MFA fixture user. Flagged so it isn't overlooked when sequencing.
- **New — the Admin-API adapter (R11) is a first-class deliverable, not glue.** Its contract, **pinned Keycloak version**, error mapping, and integration tests (Story 3.1 + CI against a running Keycloak) are load-bearing for every HR/System story; treat it as such.
- **New — theme visual/a11y parity (from Step 4):** budget iteration time in Epic 2 to hit DESIGN.md fidelity (CodeInput, pinned anti-phishing banner) within Keycloak's FreeMarker login-theme structure.

## Summary and Recommendations

### Overall Readiness Status
**✅ READY FOR IMPLEMENTATION** — and at a **lower risk posture** than the pre-pivot plan.

The four planning pillars (PRD · UX · Architecture · Epics & Stories) are complete, final, and mutually aligned **after the Keycloak + Rails pivot**. **100% FR coverage** (50/50), no missing requirements, no critical or major epic-quality defects, and no PRD↔UX↔Architecture contradictions. The pivot additionally **resolved** the prior report's one UX warning (daisyUI-vs-custom) and **retired the headline risk R1** (from-scratch security-critical IdP) by adopting a community-reviewed, CVE-patched engine.

### Findings Tally
- 🔴 Critical: **0**
- 🟠 Major: **0**
- 🟡 Minor (advisory): **5** — heavy Epic 1; security CI gates (brakeman/bundler-audit) arrive in Epic 6; Epic-2 activation needs a seeded pending account; the Admin-API adapter (R11) is a first-class deliverable; Keycloak theme visual/a11y parity.

### Critical Issues Requiring Immediate Action
**None.** Nothing blocks the start of implementation.

### Internal-Consistency Confirmation (post-pivot)
- ✅ No stray pre-pivot stack references remain in the live artifacts (PRD/Architecture/Epics) — verified by scan; all remaining mentions are intentional "supersedes / no Redis / no Vault" contrasts.
- ✅ Security-review CRITICALs are now answered by the engine + Rails layer: C4 (key custody) by Keycloak realm keys; C3 (audit integrity/retention) by Keycloak events → off-host WORM + 12-mo retention (FR38 hash-chain relaxed per NFR8); C1 (admin-reset) by Rails-enforced FR44 + `execute-actions-email`; H2/M7 by Keycloak-native session/code handling. Residual HIGH findings (H1 RP local sessions, H4 TOTP phishability, H6 PDPA owner/deadline) remain named/accepted.
- ✅ NFR1 (no application pepper under Keycloak) and NFR3/NFR8 (Keycloak-owned crypto) are consistent across PRD, addendum, and architecture.

### Recommended Next Steps
1. **Proceed to Sprint Planning** (`bmad-sprint-planning`) → generates `sprint-status.yaml` (none exists yet) from the reshaped epics → the story cycle (Create Story → Dev Story → Code Review), starting at **Story 1.1 (stand up Keycloak + baseline realm)**.
2. **At scaffold, verify maintenance/version** of the Rails OIDC-login gem (`omniauth_openid_connect` or equivalent) and decide thin-adapter-vs-gem for the **Keycloak Admin REST API** — same diligence that rejected `doorkeeper-openid_connect`. **Pin the Keycloak version.**
3. **Pull `brakeman` + `bundler-audit` into CI as soon as the Rails app exists** (Epic 3), ahead of their Epic 6 home (advisory).
4. **Before the *pilot* (not before building):** confirm OQ1 (pilot apps) + OQ3 (named second person for audit oversight); complete the PDPA artifacts (RoPA / breach runbook); stand up the off-host WORM sink; obtain the **internal-CA/self-signed TLS cert** for Nginx; schedule the independent **Keycloak-config + Rails review** + pen test (NFR10).
5. **Build the Admin-API adapter early** (Story 3.1) with integration tests against a running Keycloak in CI.

### Final Note
This re-assessment reviewed the **post-pivot** artifact set across 6 validation steps and identified **5 minor advisory issues and 0 blocking issues**. The planning artifacts are coherent, complete, and traceable end-to-end under Keycloak + Rails — implementation can begin immediately, with the advisories addressed opportunistically and the pre-pilot org/compliance items lined up in parallel. This report **supersedes** `implementation-readiness-report-2026-06-20.md`.

**Assessor:** Implementation Readiness workflow (re-run) · **Date:** 2026-06-20
