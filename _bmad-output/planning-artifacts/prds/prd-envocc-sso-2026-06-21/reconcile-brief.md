---
title: "Input Reconciliation — Brief vs PRD (envocc-sso)"
status: review
created: 2026-06-21
sources:
  brief: "briefs/brief-envocc-sso-2026-06-19/brief.md (rev. 2026-06-21)"
  prd:   "prds/prd-envocc-sso-2026-06-21/prd.md (draft)"
---

# Input Reconciliation — Brief vs PRD

A finalization pass comparing the source product brief against the finished PRD draft.
Goal: surface what the PRD **dropped, weakened, or contradicted** — with emphasis on the
brief's qualitative intent — and verify the **capability-level / no-stack-leakage** constraint.

## Verdict

The PRD is a faithful and in most places *strengthened* expansion of the brief. It honors the
co-equal-halves framing, the honest solo-risk framing (promoted to the headline risk R1), the
sovereignty/in-house mandate as load-bearing context, English-first/owner-translates, and the
capability-level constraint with **no stack leakage** (Keycloak/Authentik/ground-up appear only
inside the open OQ2 decision and as parenthetical "applies to every build approach" notes — never
as a chosen mechanism). The gaps are narrow and mostly **qualitative-tone erosion**, plus one
genuine **scope contradiction** worth a decision before finalization.

---

## CONTRADICTIONS

### C1 — Independent assurance: "if budget allows" → "HARD GATE, REQUIRED." [SEVERITY: MED]
- **Brief:** the external pen test is soft — *"Consider a one-time external penetration test before
  broad rollout, **if budget allows**"* (line 97), and "Whether any external security assurance
  (one-time pen test) is achievable given the solo build" is an **open question** (line 117). The
  brief frames solo/self-review as the **accepted** review posture (line 123: *"Security review:
  solo / self-review (accepted...)"*).
- **PRD:** NFR10 / SM5 / SM7 / R1 convert this into **HARD GATES**: independent ASVS L2 review
  REQUIRED before pilot, independent pen test REQUIRED before broad rollout — *"Not 'budget-
  permitting'."*
- **Assessment:** This is a deliberate, attributed change (*"user decision, 2026-06-21"*), not an
  accidental drift, so it is a **legitimate evolution** rather than an error. But it directly
  reverses the brief's stated posture, and OQ3 still carries the *"independent-assessment budget"*
  as **Open** — so the PRD simultaneously asserts the gate is mandatory and that its funding is
  unresolved. Flag for the brief to be back-updated (or a one-line note added) so the two artifacts
  don't contradict on whether external assurance is optional. Severity MED because intentional, but
  the internal PRD tension (hard gate vs. open budget) should be reconciled.

---

## GAPS — qualitative intent dropped or weakened

### G1 — Brand-as-anti-phishing trust signal: present but **diluted** from the brief's emphasis. [SEVERITY: MED]
- **Brief:** states this twice and forcefully — branding is *"a **trust / anti-phishing signal**:
  a non-technical staff member, redirected here from another app, must immediately recognize this
  as the real, sanctioned login and not an imitation"* (line 39), and again ties UX-ownership to
  anti-phishing for non-technical staff (line 78).
- **PRD:** FR12 requires a *"branded login experience matching the EnvOcc brand"* but frames the
  requirement almost entirely around **localization/externalized strings**. The *anti-phishing
  rationale* — the **whole reason** branding is a security requirement and not mere cosmetics —
  appears only as a one-clause aside in §2 (*"makes anti-phishing clarity ... a first-class
  requirement downstream"*) and is **never carried into an FR or NFR**. The login UI's
  `frame-ancestors 'none'` (NFR4) is an anti-framing control but is not connected to the
  "recognizable real login" intent.
- **Why it matters:** The brief's load-bearing claim is that **owning the branded UX is a security
  control** (recognizability defeats phishing for non-technical users). The PRD treats branding as
  a localization/UX requirement and treats anti-phishing as a downstream side-note, weakening the
  brief's explicit security framing of branded UX. Recommend an explicit FR/NFR: the login must be
  visually distinctive and consistently recognizable as the sanctioned EnvOcc login (anti-phishing),
  reachable at a stable canonical URL.

### G2 — UX-ownership as a *sovereignty/control* requirement is under-stated. [SEVERITY: LOW]
- **Brief:** *"Full control of the user experience — the branded login ... and the HR admin console
  must be **owned and shaped by EnvOcc**, not constrained to a vendor's stock screens"* (line 78),
  and *"This UX-ownership requirement holds regardless of the implementation approach chosen."*
- **PRD:** The "regardless of approach" clause survives well for crypto (NFR8) and the mandate
  (§1), but the specific intent that **both halves' UX must be EnvOcc-owned, not vendor stock
  screens** is not asserted as a requirement. It is implied by "branded login" (FR12) and the
  custom admin consoles (FG-4/FG-5), but the explicit "not constrained to a vendor's stock screens"
  control — which is what makes this a non-negotiable that constrains OQ2 — is dropped.
- **Why it matters:** This is the brief's bridge between sovereignty and the build decision; losing
  it weakens the constraint that whatever stack OQ2 picks must permit full custom theming of *both*
  consoles, not just the login. Severity LOW because FG-4/FG-5 already imply owned consoles.

### G3 — "Right-sized / purpose-built, not a general-purpose platform" rationale dropped. [SEVERITY: LOW]
- **Brief:** lists *"Right-sized — purpose-built for one organization's exact needs (auth-only,
  ~150 users), without the surface area of a general-purpose platform"* (line 79) as one of the
  four "what makes this different" justifications.
- **PRD:** Captures the *facts* (auth-only, ~150 users, NFR18 "Not a high-scale system") but drops
  the **intent**: minimizing attack/operational surface by being purpose-built rather than adopting
  a general-purpose platform's surface area. This is a security-posture rationale (less surface =
  less to get wrong, reinforcing the solo-operator risk story), not just a sizing fact.
- **Why it matters:** Minor, but it is a piece of the brief's security reasoning that informs OQ2
  (a sprawling general-purpose platform vs. a right-sized deployment) and is silently lost.

### G4 — "No fixed deadline; readiness is the deadline" — preserved, tone intact. [NO GAP]
- Brief lines 18/88 → PRD §1 north-star and the readiness framing throughout. **Honored, strong.**

### G5 — Tone: "drawer full of separate app credentials / sticky notes / insecure coping
mechanisms." [SEVERITY: LOW]
- **Brief:** uses vivid, human framing of the staff pain — *"a drawer full of separate app
  credentials"* (line 16), *"Forgotten passwords, reused passwords, sticky notes — the usual
  insecure coping mechanisms"* (line 26).
- **PRD:** keeps the strong "Somchai in the lab system..." image (good) but drops the
  password-hygiene-failure imagery. The *security* point embedded in it — that the status quo
  actively *causes* insecure user behavior (reuse, sticky notes), which is part of the justification
  — is reduced to "no single point to enforce a password policy." Severity LOW; tone-only, the
  substantive point survives.

---

## ITEMS THE PRD STRENGTHENED (not gaps — noted for completeness)

These are brief intents the PRD **expanded correctly**, confirming fidelity:
- **Honest solo-risk framing** → promoted to top-of-document §1 "Built honestly, with eyes open"
  and headline risk **R1**. Stronger than the brief. ✔
- **Two co-equal halves** → §1 explicit ("not a login page with an admin screen bolted on"),
  reinforced by separation-of-duties (HR Admin vs System Admin) — a control the brief only implied. ✔
- **Sovereignty / in-house mandate** → §1 "Guiding constraints," intact as load-bearing. ✔
- **English-first / owner-translates** → FR12 + NFR19, faithful and precise. ✔
- **Account reconciliation** (brief line 56) → FG-3 + FR49 + SM10, well-developed. ✔
- **PDPA** (brief OQ line 113) → escalated from an open question to a full compliance section
  (§6.C) with hard gates. Strengthening, attributed to a user decision. ✔
- New separation-of-duties role split, audit log, and out-of-band second-reader (FR39) — all are
  reasonable PRD-level elaborations of the brief's "solo operator" risk, not drift.

---

## STACK-LEAKAGE CHECK (critical constraint)

**PASS.** The PRD stays capability-level throughout. Implementation candidates
(ground-up / Keycloak / Authentik) appear **only** where allowed:
- §1 header note and §1 guiding-constraints clause — framed as an **open decision**.
- **OQ2** — *"Build approach — ground-up custom vs self-hosted Keycloak vs self-hosted Authentik?
  Open — the core architecture decision (PRD stays capability-level)."* ✔
- Parenthetical "applies to every build approach — custom or self-hosted open-source" notes on
  NFR8 / FR12 — these *reinforce* tooling-agnosticism rather than leaking a choice. ✔
- "OIDC" is explicitly scoped (FR67 note / §4 preamble) as *the interoperability standard the
  service must speak, not an implementation choice.* ✔
No FR or NFR mandates a specific product, framework, or "build it ground-up" decision. Argon2id,
RS256, TOTP, PKCE, Argon2/JWKS etc. are **standards/algorithm classes** ("Argon2id-class",
"RS256-class"), not product choices — consistent with capability-level. No leakage found.

---

## RECOMMENDED ACTIONS (for finalization)
1. **C1** — Reconcile the pen-test posture: either back-update the brief to match the PRD's hard
   gate, or note explicitly that the user decision (2026-06-21) supersedes the brief; and resolve
   the internal tension between NFR10 ("REQUIRED") and OQ3 ("budget Open").
2. **G1** — Add an explicit anti-phishing / recognizability requirement for the branded login
   (the brief's primary security rationale for owning the UX), distinct from localization.
3. **G2** — State the "EnvOcc-owned UX, not vendor stock screens, for *both* consoles" constraint
   as it bears directly on OQ2.
4. **G3** — Restore the "right-sized / minimal surface vs. general-purpose platform" rationale as
   part of the security-posture reasoning.
