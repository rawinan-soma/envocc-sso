---
stepsCompleted: [1, 2, 3, 4, 5, 6]
status: 'complete'
completedAt: '2026-06-20'
inputDocuments:
  - prds/prd-envocc-sso-2026-06-19/prd.md
  - prds/prd-envocc-sso-2026-06-19/addendum.md
  - architecture.md
  - epics.md
  - ux-designs/ux-envocc-sso-2026-06-20/DESIGN.md
  - ux-designs/ux-envocc-sso-2026-06-20/EXPERIENCE.md
date: 2026-06-20
---

# Implementation Readiness Assessment Report

> ⚠️ **SUPERSEDED (2026-06-20).** This report assessed the **pre-pivot stack** (SvelteKit + Bun + node-oidc-provider + Drizzle/Redis/Vault/daisyUI). It is **superseded by `sprint-change-proposal-2026-06-20.md`**, which re-architects envocc-sso to **self-hosted Keycloak (IdP) + Ruby on Rails (admin layer)**. The "✅ READY" verdict below applies to the old stack only. **Re-run `bmad-check-implementation-readiness` against the revised PRD / Architecture / Epics before sprint planning.** The structural findings (100% FR coverage, no forward dependencies, etc.) remain methodologically valid and should re-validate easily; the stack-specific notes (Bun⇄provider watch-item, daisyUI reconciliation) no longer apply.

**Date:** 2026-06-20
**Project:** envocc-sso

## Step 1 — Document Inventory

| Type | Document(s) | Format | Status |
|------|-------------|--------|--------|
| **PRD** | `prds/prd-envocc-sso-2026-06-19/prd.md` (+ `addendum.md`) | whole | ✅ found |
| **Architecture** | `architecture.md` | whole | ✅ found |
| **Epics & Stories** | `epics.md` | whole | ✅ found |
| **UX Design** | `ux-designs/ux-envocc-sso-2026-06-20/DESIGN.md` + `EXPERIENCE.md` | whole | ✅ found |

**Issues:** none. No sharded/whole duplicates, no missing required documents. Supporting files (security review, reconcile, decision logs, Claude Design brief) are present but not primary assessment inputs.

## Step 2 — PRD Analysis

### Functional Requirements (50)
- **FG-1 OIDC core:** FR1 Auth Code+PKCE · FR2 IdP-hosted login · FR3 no Implicit/ROPC · FR4 exact redirect match · FR5 signed ID token+JWKS · FR6 state/nonce · FR7 SSO session · FR8 session lifetimes · FR9 short tokens+refresh rotation · FR10 RP-initiated logout · FR11 discovery
- **FG-2 Staff auth:** FR12 branded login · FR13 MFA enroll · FR14 TOTP verify · FR15 admin MFA reset · FR16 activation · FR17 self-service reset · FR18 password policy · FR19 brute-force protection · FR20 enumeration resistance
- **FG-3 Identity store:** FR21 canonical identity · FR22 work-email key · FR23 minimal attributes · FR24 lifecycle states · FR25 disable blocks auth everywhere
- **FG-4 HR console:** FR26 create user · FR27 search/list · FR28 enable/disable · FR29 trigger reset/MFA reset · FR30 CSV import · FR31 profile edit
- **FG-5 System console:** FR32 client registration+secret rotation · FR33 admin-user management · FR34 audit view/export
- **FG-6 Audit:** FR35 auth events · FR36 admin actions · FR37 token/key events · FR38 append-only/off-host/12-mo · FR39 no-secrets + second-person export
- **FG-7 Integration:** FR40 guide · FR41 integration contract · FR42 claim contract · FR43 reference client
- **FG-8 Operational security:** FR44 admin-reset hardening · FR45 session-id regeneration · FR46 revocation on disable · FR47 auth-code/PKCE/nonce single-use · FR48 token hygiene · FR49 CSV validation · FR50 edge abuse protection + step-up
**Total FRs: 50**

### Non-Functional Requirements (20)
NFR1 Argon2id+pepper · NFR2 token/MFA-secret protection · NFR2a token TTL ≤15 min · NFR3 RS256/rotatable JWKS · NFR4 TLS/cookies/CSP · NFR5 RFC 9700 · NFR6 ASVS L2 + independent review · NFR7 NIST 800-63B password/brute-force · NFR8 audited libraries only · NFR9 CI dep-scan+SAST · NFR10 independent pen test + ASVS gates · NFR11 lawful basis/RoPA · NFR12 no §26 sensitive data · NFR13 data minimization/encryption-at-rest · NFR14 retention/erasure reconciliation · NFR15 PDPA gates before pilot · NFR16 SMTP critical path · NFR17 24/7 + SPOF + tested backups · NFR18 ~150 users, p95 ≤500 ms · NFR19 English-first/Thai-ready
**Total NFRs: 20**

### Additional Requirements / Constraints
- **Open questions:** OQ1 pilot apps (TBD) · OQ2 build stack (resolved in Architecture → SvelteKit+node-oidc-provider) · OQ3 named second person for audit oversight (TBD).
- **Standing assumptions:** pilot apps are confidential server-side clients (confirm at integration); protagonist names illustrative.
- **Mandate/constraints:** in-house build (organizational mandate); sole credential system of record; solo build; phased pilot; security rigor = definition of done; no fixed deadline.

### PRD Completeness Assessment
**Strong / final.** The PRD completed the full coached workflow plus an adversarial security review and finalize pass (status `final`). 50 FRs (stable IDs, nested by feature group), 20 NFRs with product-specific thresholds, named counter-metrics, honest scope boundaries, and a small, healthy set of open items (3 OQs, 2 assumptions) — none of which block the build. Security-critical mechanisms are explicit. No gaps that would impede traceability validation.

## Step 3 — Epic Coverage Validation

### Coverage Matrix (by epic)
| FRs | Epic | Status |
|-----|------|--------|
| FR1–FR12, FR14, FR19–FR23, FR35, FR37, FR45, FR47 | Epic 1 — Foundation & SSO Core | ✓ Covered |
| FR13, FR16, FR17, FR18, FR24, FR48 | Epic 2 — Onboarding & Recovery | ✓ Covered |
| FR15, FR25, FR26–FR31, FR44, FR46, FR49 | Epic 3 — HR Console | ✓ Covered |
| FR4 (registration UI), FR32, FR33, FR50 (step-up) | Epic 4 — System Console | ✓ Covered |
| FR34, FR35–FR39 | Epic 5 — Audit & Compliance | ✓ Covered |
| FR40–FR43, FR50 (edge) | Epic 6 — Integration & Hardening | ✓ Covered |

*Note: FR35/FR37 appear in both Epic 1 (audit-write foundation) and Epic 5 (complete capture) — intentional layering, not a gap. FR50 spans Epic 4 (step-up) + Epic 6 (edge) by design.*

### Missing Requirements
**None.** All 50 PRD FRs map to at least one epic/story with addressing acceptance criteria. No orphan FRs (FRs in epics not in the PRD) — the additional AR/UX-DR items are architecture/UX requirements woven into story ACs, not stray FRs.

### Coverage Statistics
- **Total PRD FRs: 50**
- **FRs covered in epics: 50**
- **Coverage: 100%**
- NFRs (20) and Architecture/UX requirements: woven into the relevant stories' acceptance criteria.

## Step 4 — UX Alignment Assessment

### UX Document Status
**Found** — `DESIGN.md` (visual identity, final) + `EXPERIENCE.md` (IA, flows, states, voice, a11y, final). Both produced from the PRD in the UX workflow.

### UX ↔ PRD Alignment
- ✅ EXPERIENCE.md inherits the PRD by reference (`sources:`) and mirrors the PRD's 8 user journeys (UJ-1…UJ-8) verbatim with named protagonists.
- ✅ Every PRD surface (staff auth + the two admin consoles) has a home in the EXPERIENCE.md IA; voice/tone rules (plain language, anti-phishing, enumeration-resistance) trace to PRD FR20/NFR19.
- ✅ No UX requirements contradict the PRD; UX adds implementation-level detail (states, microcopy) consistent with PRD scope.

### UX ↔ Architecture Alignment
- ✅ Architecture explicitly honors the UX: SvelteKit **SSR for the top-level login** (FR2/NFR4, never iframed), a custom **Ministry Bronze daisyUI theme** from DESIGN.md tokens, **Noto** bilingual fonts, **Paraglide** for the EXPERIENCE.md localization (NFR19), **WCAG 2.1 AA** floor, and the component set (AuthCard, CodeInput, StatusPill, etc.).
- ✅ Performance budget (p95 ≤500 ms, NFR18) supports the required responsiveness; no UI component is unsupported by the architecture.

### Alignment Issues / Warnings
- ⚠️ **Minor (already noted, non-blocking):** EXPERIENCE.md states *"UI system = custom"*, but the Architecture adopted **daisyUI (themed to Ministry Bronze)** as the component base. The Architecture/Epics already record this reconciliation (daisyUI customized to the DESIGN.md spec; spine wins on conflict). Recommend a one-line UX-doc note at implementation time. No functional impact.
- No major misalignments. UX is complete and fully supported by both PRD and Architecture.

## Step 5 — Epic Quality Review

### Best-Practices Compliance (per epic)
| Epic | User value | Independent | Stories sized | No fwd deps | DB-when-needed | Clear ACs | FR traceability |
|------|:---------:|:----------:|:-------------:|:-----------:|:--------------:|:---------:|:---------------:|
| 1 Foundation & SSO | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 Onboarding & Recovery | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 3 HR Console | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 4 System Console | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 5 Audit & Compliance | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 6 Integration & Hardening | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### Validated specifics
- **User value, not technical milestones:** every epic is framed by a user outcome (sign-in, onboard, manage, oversee, integrate). Epic 1 bundles scaffold/infra but is the *minimum* needed for its user outcome (the standard "Epic 1 = setup + first capability" pattern) — not a standalone "setup" epic.
- **Starter template:** Epic 1 **Story 1.1** = scaffold (`bunx sv create envocc-sso`), matching the Architecture — present and first.
- **Incremental DB:** `users` (1.2), `audit_events` (1.8), clients via Epic 4 — no all-tables-upfront.
- **No forward dependencies:** stories build only on earlier ones. Two intentional layerings verified as *backward* dependencies (not defects): audit-write (Epic 1) → audit compliance (Epic 5); MFA challenge (1.6) tests against a **seeded fixture user** (real enrollment in Epic 2).
- **Acceptance criteria:** Given/When/Then throughout, testable, and include error/edge conditions (enumeration resistance, throttling, invalid/expired links, replayed codes).

### 🔴 Critical violations
**None.**

### 🟠 Major issues
**None.**

### 🟡 Minor concerns (advisory, non-blocking)
- **Epic 1 is the heaviest (10 stories).** Acceptable — it's the foundation and each story is well-sized — but it is the longest pole; sequence it carefully.
- **Heavier security CI gates land in Epic 6 (Story 6.5).** `gitleaks` + basic CI are already in Story 1.1, but SAST + dependency-scanning arrive in Epic 6. For a security-critical build, consider enabling SAST/dep-scan earlier.
- **`MFA challenge` fixture dependency (Story 1.6):** a developer must seed the fixture user (per Story 1.2) to test Epic 1's verification flow — flagged so it isn't overlooked.
- **UX "custom UI system" → daisyUI reconciliation** (from Step 4): a one-line EXPERIENCE.md note recommended at implementation time.

## Summary and Recommendations

### Overall Readiness Status
**✅ READY FOR IMPLEMENTATION.**

The four planning pillars (PRD · UX · Architecture · Epics & Stories) are complete, final, and mutually aligned. **100% FR coverage**, no missing requirements, no critical or major epic-quality defects, and no PRD↔UX↔Architecture contradictions. The only findings are four minor, non-blocking advisories.

### Findings Tally
- 🔴 Critical: **0**
- 🟠 Major: **0**
- 🟡 Minor (advisory): **4** — heavy Epic 1; security CI gates arrive in Epic 6; the MFA fixture-user note; the daisyUI UX-doc reconciliation.

### Critical Issues Requiring Immediate Action
**None.** Nothing blocks the start of implementation.

### Recommended Next Steps
1. **Proceed to Sprint Planning** (`bmad-sprint-planning`) → the story cycle (Create Story → Dev Story → Code Review), starting at **Story 1.1 (scaffold)**.
2. **Verify `node-oidc-provider` on Bun early** (Architecture watch-item) — fall back to running the provider on Node if needed.
3. **Consider enabling SAST + dependency-scanning in CI earlier** than Epic 6 (advisory, given the security criticality).
4. **Add a one-line EXPERIENCE.md note** recording daisyUI (themed to Ministry Bronze) as the component base.
5. **Before the *pilot* (not before building):** confirm OQ1 (pilot apps), OQ3 (named second person for audit oversight), complete the PDPA artifacts (RoPA / breach runbook), and schedule the independent ASVS L2 review + pen test (NFR10).

### Final Note
This assessment reviewed 4 documents across 6 validation steps and identified **4 minor advisory issues and 0 blocking issues**. The planning artifacts are coherent, complete, and traceable end-to-end — implementation can begin immediately, with the advisories addressed opportunistically and the pre-pilot org/compliance items lined up in parallel.

**Assessor:** Implementation Readiness workflow · **Date:** 2026-06-20
