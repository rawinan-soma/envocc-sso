# Brief → PRD Reconciliation — envocc-sso

Comparing the source brief + brief addendum against the PRD + PRD addendum.
Goal: find brief content with no home in the PRD, weakened intent, or contradictions —
with special attention to qualitative/intent framing that an FR list tends to flatten.

Inputs:
- brief.md
- brief/addendum.md
- prd.md
- prd/addendum.md

Legend: **Missing** = no home in PRD or PRD addendum · **Weakened** = present but diluted/flattened ·
**Contradicted** = PRD says something at odds with the brief.

---

## A. Qualitative / intent content (highest priority)

### A1. "What makes this different is honesty/mandate, not a moat" — the *honesty* framing is weakened
- **Brief said:** "This brief deliberately records that an off-the-shelf option exists, so the decision is documented and honest." and "The justification for building it is **fit and mandate, not a technical moat**." (brief §What Makes This Different)
- **Status: Weakened.** The PRD addendum §A captures the build-vs-buy *facts* ("off-the-shelf would have been faster and safer", driver weighting, "explicitly accepted with compensating controls"). But the brief's deliberate *posture of honesty* — "we are recording this so the decision is documented and honest", "this is **not** a market-differentiation play" — is reduced to a neutral rejected-alternatives table. The self-aware, candid voice ("eyes open", "documented and honest") is gone. The point of that section in the brief is not just *what* was decided but *the intellectual honesty of having decided it openly*.
- **Where it should go:** PRD §1 Mandate & guiding constraints (one line preserving "an off-the-shelf option exists; building anyway is a mandate, recorded honestly"), or strengthen PRD addendum §A's "Outcome" bullet to keep the honesty framing rather than just the accepted-risk fact.

### A2. "Off-the-shelf would have been faster AND safer" — the *safer* admission is softened
- **Brief said (addendum):** "Off-the-shelf would have been faster **and safer** — Keycloak/Authentik deliver ... ongoing CVE patching out of the box, in days not months."
- **Status: Present but worth flagging.** PRD addendum §A reproduces this almost verbatim — GOOD. But the *tension* it creates with "security rigor is the definition of done" (we knowingly chose the less-safe path and compensate for it) is never made explicit anywhere in the PRD body. The brief's honesty is that building in-house is *less safe* and the compensating controls are damage control, not a wash. PRD §1 and §8/R1 present compensating controls confidently without surfacing that they are mitigating a knowingly-accepted safety regression.
- **Where it should go:** PRD §8 R1 (one clause: "off-the-shelf would have been safer; these controls compensate for, not eliminate, that gap") or PRD addendum §D intro.

### A3. The human framing of the problem — partially preserved, one nuance lost
- **Brief said:** "Forgotten passwords, reused passwords, sticky notes — the usual insecure coping mechanisms." (brief §The Problem, staff bullet)
- **Status: Missing (the texture).** The PRD §1 keeps the "Somchai in the lab system…" vignette (GOOD) and "password sprawl", but drops the visceral "sticky notes / insecure coping mechanisms" image that conveys *why* this is a security problem and not just an annoyance. The brief deliberately ties staff inconvenience to security risk via that image.
- **Where it should go:** PRD §1 problem paragraph, or §2 Staff success cell.

### A4. "Admin console is a first-class half of the product, not an afterthought"
- **Brief said:** "Admin console for HR administrators ... **This is a first-class half of the product, not an afterthought.**" Also: "The system has two halves." (brief §The Solution / §Executive Summary)
- **Status: Weakened.** The PRD does treat admin consoles substantively (FG-4, FG-5) and even improves on the brief by splitting HR vs System Admin. But the explicit *intent statement* — that the admin experience is co-equal to the staff experience, "two halves" — is never asserted as a guiding principle. A reader of the PRD could rank the admin console as secondary tooling. The brief is emphatic that it is not.
- **Where it should go:** PRD §1 (a "two halves" framing line) or §3 In-scope preamble.

### A5. "Readiness is the deadline" — present but the *spirit* is thinner
- **Brief said:** "There is no fixed deadline; **readiness is the deadline.**" (brief §Executive Summary)
- **Status: Present.** PRD §1 has "no fixed deadline — readiness gates release." GOOD — preserved. No gap, noted to confirm it survived.

### A6. Localization *intent* — preserved factually, the "designed for localization" rationale is intact
- **Brief said:** "built **English-first** during development, designed for localization; Thai (the target locale) is translated separately by the owner after the UI stabilizes."
- **Status: Present.** Captured in FR12, NFR19, and PRD addendum. GOOD — the "structured for localization" intent (not just English-only) survived. No gap.

---

## B. Substantive content missing or weakened

### B1. "No single point to enforce a password policy, require MFA, or audit who can get in" — the org-level governance gap
- **Brief said:** "there is no central identity record at all ... There is no single point to enforce a password policy, require MFA, or audit who can get in." (brief §The Problem, organization bullet)
- **Status: Present.** PRD §1 keeps "no single point to enforce a password policy or require MFA." GOOD. No gap.

### B2. Pen test — slightly weakened in conditionality
- **Brief said:** "Consider a one-time external penetration test before broad rollout, **if budget ever allows.**" (brief §Risk Accepted, compensating controls) — framed as a genuine aspiration.
- **Status: Present (consistent).** PRD NFR10 / R1 / addendum §D all carry "one-time external penetration test before broad rollout (recommended, budget-permitting)." Consistent. No gap.

### B3. "Treat any custom security code as a red flag"
- **Brief said:** "Build only on audited OIDC/crypto libraries; **treat any custom security code as a red flag.**" (brief §Risk Accepted) and addendum: "no hand-rolled crypto or token logic."
- **Status: Weakened.** PRD NFR8 / addendum §D say "no hand-rolled crypto or token logic" — which covers crypto and tokens. But the brief's rule is broader: *any custom security code* is a red flag (a posture/heuristic, not just crypto+tokens). The PRD narrows a general engineering discipline to two specific categories.
- **Where it should go:** PRD addendum §D (add the "any custom security code is a red flag" heuristic) or NFR8 phrasing.

### B4. Open question: "regulatory/compliance regime ... (e.g. PDPA)?"
- **Brief said:** open question — "Any regulatory/compliance regime that applies to a Thai public-health division's identity data (e.g. PDPA)?"
- **Status: Resolved/expanded.** PRD turned this into NFR11–15, PDPA detail in addendum §E, and OQ3. This is an *upgrade*, not a gap. No action.

### B5. Open question: "canonical-identity key used to reconcile ... (e.g. a reliable org identifier)"
- **Brief said:** open question — the canonical key "(e.g. a reliable org identifier)". The brief left the key TBD and floated "a reliable org identifier".
- **Status: Resolved — but note a quiet decision.** The PRD *decided* the reconciliation key = **work email** (FR22, FR5, FR42). The brief's addendum had already hinted "likely keyed on a reliable org identifier — TBD." The PRD picks work-email instead of an org identifier. This is a legitimate decision, but it is a **silent resolution of an open brief question** — worth flagging that "reliable org identifier" (e.g. employee ID) was the brief's leading candidate and the PRD chose email instead. If email is not actually unique/stable per person org-wide, this contradicts the brief's "reliable org identifier" instinct.
- **Where it should go:** PRD §8 OQ or addendum §C "Reconciliation key mechanics" — record *why* work-email was chosen over an org identifier, since the brief explicitly raised the org-identifier option.

### B6. "Stand on vetted foundations ... Detailed choices belong to the architecture phase."
- **Brief said:** "(Detailed choices belong to the architecture phase.)"
- **Status: Present.** PRD repeatedly defers crypto params/library choices to architecture (FR4 preamble, addendum §C). GOOD. No gap.

---

## C. Scope / boundary checks

### C1. "Account reconciliation: collapsing each person's scattered per-app accounts into one canonical identity"
- **Brief said (Scope, in-scope v1):** "Account reconciliation: collapsing each person's scattered per-app accounts into one canonical identity."
- **Status: Reframed — verify intent.** The brief's phrasing ("collapsing scattered per-app accounts into one canonical identity") could be read as an active merge. The PRD explicitly reframes this to "operational seeding from HR's roster + a canonical-key claim contract ... **No automated merge engine**" (FR §3, FR21–22, FR42). The brief addendum already supports this softer reading ("v1 must collapse duplicates into one canonical identity (likely keyed on ...)"). This is a *clarification*, not a contradiction — the PRD correctly recognizes the IdP can't see app DBs. **Not a gap**, but the brief's strong verb "collapsing" vs PRD's "seeding + claim contract" is a meaningful narrowing the owner should confirm is acceptable.
- **Where it should go:** Already handled in PRD §3 and addendum §C. Flag only for owner confirmation that "seeding + claim contract" satisfies the brief's "one canonical identity" goal (SM8 = 0 duplicates covers the integrity intent).

### C2. Vision: "all 10–15 apps behind one secure login within the following year"
- **Brief said (§Vision):** "all 10–15 apps behind one secure login within the following year, then a natural progression into centralized authorization ..., audit logging, and — further out — federation or passwordless."
- **Status: Present.** PRD addendum §B Parked Roadmap captures all of these in priority order (adds self-service MFA recovery and SLO, which is fine). GOOD. No gap.

### C3. Brief's deferred items vs PRD's deferred items
- **Brief explicitly deferred:** centralized authorization; wiring all 10–15 apps; external/public/partner users; social login, external-IdP federation, SCIM, passwordless/WebAuthn.
- **Status: Correctly deferred in PRD §3.** The PRD also *adds* deferrals (back-channel SLO, automated cross-app merge, optional refresh tokens, self-service MFA recovery codes). These are legitimate v1-scoping decisions consistent with the brief's "tight v1 surface". Per instructions, **not flagged** — brief deferred, PRD also defers.

---

## D. Success criteria mapping

### D1. All five brief success criteria → mapped to SM1–SM5. One nuance to verify.
- **Brief said:** "No security defect in the **token-handling, session, or credential-storage class** is outstanding when an app goes live."
- **Status: Present and strengthened.** SM5 = "0 outstanding ... with the OWASP ASVS L2 checklist passed." GOOD — the PRD adds the ASVS gate. No gap.
- Brief criteria "log in once and reach every integrated app without re-authenticating" → SM2. "HR can fully onboard/disable from the console alone" → SM3. "MFA enforced + self-service reset works end-to-end" → SM4 (MFA) + SM6 (reset completion, health). All mapped. No gap.

---

## E. Smaller items / nothing-burgers (recorded for completeness)

- **E1. "no third-party software in the trust path"** (brief §What Makes This Different, Full ownership) — *Weakened.* The "full ownership / no third-party in the trust path" rationale is in the build-vs-buy discussion but the specific phrase "no third-party software in the trust path" (a meaningful security argument *for* the build) is not preserved. Minor. Could go in PRD addendum §A.
- **E2. "without the surface area of a general-purpose platform"** (brief, Right-sized) — *Missing.* The "right-sized / less attack surface than Keycloak" argument — a genuine security upside of the custom build that partially offsets A2 — is dropped. Worth one line in PRD addendum §A or §D, as it's the counterweight to "off-the-shelf would have been safer."
- **E3. Protagonist/illustrative-names** — PRD adds named protagonists (Somchai, Anong, Pranee, Wirat) and flags them illustrative. Consistent with brief's Somchai example. No gap.

---

## Summary table

| # | Brief content | Status | Suggested home |
|---|---------------|--------|----------------|
| A1 | "documented and honest" / "fit and mandate, not a moat" posture | Weakened | PRD §1 or addendum §A "Outcome" |
| A2 | "off-the-shelf would have been ... safer" tension unsurfaced | Weakened | PRD §8 R1 or addendum §D intro |
| A3 | "sticky notes / insecure coping mechanisms" human texture | Missing | PRD §1 or §2 Staff cell |
| A4 | "admin console is a first-class half, not an afterthought" / "two halves" | Weakened | PRD §1 or §3 preamble |
| B3 | "treat any custom security code as a red flag" (broader than crypto/tokens) | Weakened | PRD addendum §D or NFR8 |
| B5 | reconciliation key: brief floated "reliable org identifier"; PRD silently chose work-email | Resolved silently | PRD §8 OQ or addendum §C |
| E1 | "no third-party software in the trust path" | Weakened | PRD addendum §A |
| E2 | "right-sized / less surface area than a general-purpose platform" | Missing | PRD addendum §A or §D |

Items confirmed faithfully carried (no action): A5 readiness-deadline, A6 localization intent, B1 governance gap, B2 pen test, B4/PDPA (upgraded), B6 arch-deferral, C2 vision/roadmap, C3 deferrals, D1 success criteria.
