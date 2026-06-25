# PRD Quality Review — envocc-sso (2026-06-21)

## Overall verdict

This is a strong, launch-grade PRD for a security-critical internal SSO. It earns its rigor: the thesis (security readiness — not a date — gates release) is stated up front, governs scope, and is traced through hard gates (NFR10/NFR15), success metrics, and risks. FRs are unusually atomic and testable for a capability-level spec, the security/PDPA gates are concrete (named owners, pre-pilot/pre-broad-rollout timing, pass/fail metrics), and stack-agnosticism is a deliberate, well-defended posture rather than a gap. What's at risk is mostly mechanical and clarity-level: a handful of FRs bundle multiple testable obligations into one ID (FR48, FR49, FR50, FR35–FR36), a few quantitative bounds live only in NFRs and aren't back-referenced from the FR that needs them, and one or two requirements brush against implementation specificity. None of these block the gate; they are tightening passes.

**Gate verdict: PASS-WITH-FIXES.**

## 1. Decision-readiness — strong

A decision-maker can act on this. The central trade-off — solo build of security-critical infra without a standing second reviewer — is named in the Vision (§1 "Built honestly, with eyes open"), not buried, and the compensating posture (hard independent gates substituting for the missing reviewer) is explicit at NFR10 and R1/R2. The "budget-permitting" hedge that would normally weaken such a gate has been deliberately removed: NFR10 reads "Not 'budget-permitting' — these are the substitute for the missing second reviewer and must pass." That is a real decision, dated and attributed (2026-06-21).

Open Questions are genuinely open (OQ1 pilot apps, OQ2 build approach, OQ3 named DPO/budget) and each is a real downstream dependency, not rhetorical. The residuals that are *accepted* rather than resolved are labeled as such (R8 TOTP phishability; FR25 already-running local session window) — honest, not smoothed.

### Findings
- **low** OQ3 bundles two distinct unknowns (§8) — the named second person/DPO and the independent-assessment budget are one row but gate different things (FR39 vs NFR10). *Fix:* split into OQ3a/OQ3b so each can close independently.

## 2. Substance over theater — strong

Little furniture. The NFRs carry product-specific thresholds, not boilerplate: ≤ 15 min token ceiling (NFR2a), Argon2id-class at OWASP params (NFR1), ≤ 128-bit token entropy / ≤ 20 min (NFR2), p95 ≤ 500 ms at 100–150 staff (NFR18), 12-month audit retention tied to the PDPA 72-hour reconstruction duty (FR38/NFR14). Each cites an authoritative source (RFC 9700, ASVS, NIST 800-63B, PDPA B.E. 2562) rather than gesturing at "secure/scalable/reliable."

Personas (4) each drive decisions: the HR/System Admin split is a load-bearing separation-of-duties control (FR33, §2), not thoroughness theater; "Staff are non-technical" directly motivates enumeration-resistance and self-recovery FRs. No innovation theater — the PRD explicitly disclaims novelty ("authentication layer," standard OIDC).

### Findings
- *(none material)*

## 3. Strategic coherence — strong

The PRD has a clear thesis and bets on it consistently: "Security rigor — not feature count — is the definition of done" (§1 North-star). Scope discipline follows from it (narrow v1, authn-not-authz, disable-not-delete, HA deferred), and the Success Metrics validate the thesis rather than measuring activity — SM5/SM6/SM7 are security/compliance pass-gates, and counter-metrics (CM1–CM3) are present and pointed (lockouts from over-tight controls, admin-ticket abuse spikes, stalled activations). The MVP is coherently a "problem-solving" scope kind (kill scattered un-revoked access), and the feature set maps to that problem rather than reading as a backlog.

### Findings
- **low** SM9 "24/7, no unplanned downtime" is aspirational against NFR17's "single instance to start, HA deferred" (§7 vs §6.D) — the health metric implies an availability posture the v1 topology can't guarantee. *Fix:* soften SM9 to a measured-availability target with the SLO deferred to architecture, matching NFR17's own hedge.

## 4. Done-ness clarity — adequate (strong FRs, a few bundling defects)

This is the dimension to be unforgiving on, and the PRD mostly holds. Nearly every FR carries a testable consequence and avoids adjectives — "exact-match redirect URIs (no wildcard/substring)" (FR4), "single-use within its time step" (FR14), "regenerate the session identifier on every authentication-state transition" (FR45), "return the account to pending re-activation — never leaving a 'password known, MFA cleared' window" (FR44). Vague-language scan came back nearly clean; there is no "handles gracefully" or "user-friendly" smuggled in.

The weakness is **requirement atomicity**: several FG-8 and console FRs bundle 4–6 independently-testable obligations under one ID, which will force downstream story-splitting and muddies traceability.

### Findings
- **medium** FR48 bundles five distinct testable rules under one ID (§4 FG-8) — (a) new token invalidates prior, (b) completion invalidates other sessions+tokens, (c) per-account rate-limit, (d) per-IP rate-limit, (e) pending-account expiry. *Fix:* split, or at minimum enumerate as FR48.1–.5 so each gets its own acceptance test and audit trace.
- **medium** FR49 bundles five obligations (validate/de-dupe, size cap, email throttle, CSV/formula-injection sanitization, preview/confirm) under one ID (§4 FG-4 controls). *Fix:* enumerate sub-items; the injection-sanitization rule especially should be independently verifiable.
- **medium** FR50 bundles edge rate-limiting, JWKS/discovery cacheability, and admin CSRF+step-up under one ID (§4) — three unrelated control families. *Fix:* split admin-console CSRF/step-up out from public-endpoint protection.
- **medium** Quantitative bounds for "short-lived" / "time-limited" live only in NFRs and aren't back-referenced from the binding FR (§4 vs §6) — FR16/FR17/FR47/FR48 say "short-lived/time-limited" but the testable number (≤ 20 min, ≤ 128-bit, NFR2; ≤ 15 min, NFR2a) is in §6. FR9/FR25 do back-reference NFR2a; FR16/FR17/FR48 do not. *Fix:* add the NFR2/NFR2a cross-ref inline so an engineer testing FR16 doesn't have to discover the bound elsewhere.
- **low** FR35 and FR36 each enumerate long event lists under one ID (§4 FG-6) — acceptable as a logging-coverage contract, but "session creation/termination and expiry" inside FR35 is the audit counterpart to FR45/FR46 and should cross-reference them for completeness traceability. *Fix:* add cross-refs; optionally tabulate the event catalog.
- **low** "bounded clock-drift window" (FR14), "bounded JWKS cache TTL" (FR41), "bounded window" pending expiry (FR48) — "bounded" is correct at capability level but carries no testable floor/ceiling. *Fix:* acceptable to defer to architecture, but state explicitly that the bound value is an architecture deliverable so it isn't silently dropped.

## 5. Scope honesty — strong

Omissions are explicit and do real work. The §3 "Out of scope / deferred" list is concrete (centralized authz, all-app wiring, external/partner users, social login, external-IdP federation, SCIM, passwordless/WebAuthn, automated cross-app merge), and the deferrals are tied to the thesis ("who you are, not what you may do"). Accepted residuals are named where they could otherwise be silently assumed: FR25's already-running-local-session window, R8's TOTP phishability with a roadmap commitment, R2's solo-operator-as-sole-log-reader. `[ASSUMPTION]` tags are present and indexed (§8 standing assumptions: confidential-client pilot, illustrative protagonist names).

Open-items density is appropriate for the stakes: 3 Open Questions + 2 assumptions on a launch-grade security PRD is low and all three OQs are correctly *outside* the capability scope (pilot selection, build approach, named DPO) — none of them block a green light to architecture.

### Findings
- **low** The validation activity (§3 "Pilot integration… not a product feature") is the trigger for PDPA obligations but isn't represented in §3's in/out scope binary — it's a third category. This is handled well in prose but a reader skimming the scope table could miss that the pilot is in-v1 work. *Fix:* fine as-is; consider a one-line callout in the In-scope list pointing to the validation subsection.

## 6. Downstream usability — strong

This PRD is explicitly chain-top (feeds architecture → epics → stories), so traceability matters, and it largely delivers. The Glossary (Appendix A) defines the load-bearing domain nouns (canonical identity, stable subject, reconciliation key, lifecycle state, RP, OIDC client, activation link, two-role separation) and they're used consistently across FRs/UJs/SMs. FR IDs are contiguous FR1–FR50 with no gaps or duplicates; NFR1–NFR19 (plus NFR2a) likewise; SM1–SM10, CM1–CM3, R1–R9, OQ1–OQ3, UJ1–UJ8 all clean. UJs each have a named protagonist carrying context inline (Somchai, Anong, Pranee, Wirat, Rawinan) and each cites its backing FRs.

Cross-references mostly resolve. Sections are largely self-contained via Glossary terms rather than "see above."

### Findings
- **low** NFR2a is an out-of-sequence insert between NFR2 and NFR3 (§6.A) — fine, but the naming (vs renumbering NFR3+) signals it was added late; verify nothing downstream hard-codes "NFR3 = signing keys." *Fix:* cosmetic; leave if downstream artifacts already reference NFR2a.
- **low** UJ list cites FR ranges (e.g., UJ-6 "FR40–FR43") — resolves fine, but range citations are slightly less greppable than explicit lists for trace tooling. *Fix:* optional; expand ranges if the trace step needs exact IDs.

## 7. Shape fit — strong

The shape matches the product. This is multi-stakeholder (staff + HR Admin + System Admin + app owners) with meaningful UX (non-technical staff, anti-phishing, self-recovery), so the named-protagonist UJs are load-bearing, not overhead — they correctly carry the journeys that the capability FRs alone wouldn't make vivid (first-login activation, admin-assisted MFA reset). Equally, the spec is correctly *not* over-formalized into a UX-heavy consumer PRD: security NFRs and compliance gates dominate, which fits security-critical internal infrastructure. The regulatory dimension (PDPA) gets constraint traceability (NFR11–15 → SM6 → R9 → FR38/FR23), which is non-negotiable for a compliance-bearing system and is present.

Stack-agnosticism is the right shape here and is defended explicitly (§1 in-house mandate note, OQ2 "the core architecture decision," FR header "deferred to architecture"). This is correct, not a gap.

### Findings
- **low** Minor implementation-leakage watch (§4/§6) — most "implementation" terms are actually interoperability-standard or capability vocabulary (OIDC, PKCE, JWKS, RS256-class, Argon2id-class, TOTP) and the PRD pre-empts this by saying "OIDC denotes the interoperability standard… not an implementation choice" (FR header) and uses "-class" hedges (RS256-class, Argon2id-class) to name a security *property* not a library. This is defensible. The one slight reach is FR45's "host-prefixed" cookie naming and NFR4's CSP `frame-ancestors 'none'` — these are specific mechanisms, but they encode genuine security requirements with no meaningful capability-level paraphrase, so the leakage is acceptable. *Fix:* none required; noting for completeness that these are deliberate, not accidental.

## Mechanical notes

- **Glossary:** present and consistent; domain nouns used identically across FR/UJ/SM. No drift detected (e.g., "reconciliation key (work email)" used uniformly).
- **ID continuity:** FR1–FR50 contiguous, unique. NFR1–NFR19 + NFR2a (intentional late insert). SM1–SM10, CM1–CM3, R1–R9, OQ1–OQ3, UJ1–UJ8 all contiguous and unique. No broken cross-refs found; FR→FG and FR→NFR references resolve.
- **Assumptions index roundtrip:** 2 inline `[ASSUMPTION]` markers (§5 protagonist names; §8 confidential-client pilot, protagonist names) — both indexed in §8 standing assumptions. Roundtrip clean.
- **UJ protagonists:** all 8 UJs have a named protagonist with inline context. No floating UJs.
- **Required sections:** Vision, Users, Scope (with Non-Goals), FRs, UJs, NFRs, Success Metrics (with counter-metrics), Risks, Open Questions, Glossary — all present for launch-grade stakes.
- **Top fixable cluster:** FR atomicity in FG-8 (FR48/FR49/FR50) and inline NFR back-references from short-lived-token FRs (FR16/FR17/FR48 → NFR2/NFR2a) are the only findings that touch downstream story-creation quality; everything else is cosmetic.
