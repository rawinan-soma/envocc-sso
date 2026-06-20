# Adversarial Security & Compliance Review — envocc-sso PRD

> 📌 **Historical record + still the security bar (note added 2026-06-20).** This review targeted the **from-scratch custom IdP**. After the **pivot to self-hosted Keycloak + Rails** (`sprint-change-proposal-2026-06-20.md`), the *engine* now ships hardened implementations of the riskiest primitives: **C4 (signing-key custody/rotation/recovery)** is satisfied by Keycloak realm keys; **C3 (audit integrity/retention)** by Keycloak events → an off-host append-only/WORM sink + 12-month retention (the "hash-chained" requirement relaxed to WORM integrity, NFR8); much of **C1 (admin-reset bypass)** by Rails-enforced FR44 hardening + Keycloak `execute-actions-email` re-activation; **H2 (session fixation)** and **M7 (code/nonce/PKCE single-use)** are Keycloak-native. The remaining custom attack surface — and thus the live target of this review's findings, the ASVS L2 verification, and the independent pen test — is **the Keycloak hardening configuration + the Rails admin layer**. The HIGH residual-risk findings (H1 RP local sessions, H4 TOTP phishability, H6 PDPA owner/deadline) and the PDPA work are unchanged and still apply. Per-finding mapping: see the Sprint Change Proposal §2.3.

**Reviewer role:** Adversarial security & compliance reviewer
**Date:** 2026-06-20
**Documents reviewed:**
- `prd.md` (PRD — envocc-sso, draft, 2026-06-19)
- `addendum.md` (PRD Addendum)

**Posture:** This is a custom, in-house OIDC IdP that becomes the *sole system of record for staff credentials* for a Thai public-health division, built and reviewed by **one person**. Every credential-bypass primitive (admin reset, key custody, email token) is therefore both a single point of compromise and a single point of failure. The bar is correspondingly high. The PRD is unusually thoughtful for a draft — it cites RFC 9700, ASVS, NIST 800-63B, and PDPA, and it is honest about FR25's limits. The findings below are where that rigor is **stated as a capability but not yet pinned to a verifiable, attacker-resistant requirement**, or where it is **internally inconsistent**, or **missing outright**.

---

## VERDICT

**Conditional fail for a security-critical, sole-system-of-record IdP at this draft stage.** The OIDC core is correctly shaped, but the highest-risk *operational* primitives — admin-assisted MFA/password reset (a credential-bypass primitive with no second-actor control), signing-key custody/rotation/loss recovery, audit-log integrity and the 90-day-vs-72h-reconstruction mismatch, and the leaver-revocation guarantee — are underspecified in exactly the ways a real attacker or auditor exploits. The solo-build "compensating controls" are largely *aspirational* (ASVS L2 self-attested, pen test "budget-permitting", no independent review) and do not actually compensate for the absence of a second set of eyes on the two functions that matter most. Do not go live until the CRITICAL and HIGH findings are resolved.

---

## CRITICAL FINDINGS

### C1 — Admin-assisted MFA + password reset is an unguarded account-takeover primitive
**Location:** FR15, FR29, FR16, UJ-7, NFR16, CM2; addendum §B-roadmap item 3.
**Risk:** FR29 lets a single HR Admin both **reset MFA enrollment** and **trigger a password reset** for any user. Combine the two and an HR Admin (or anyone who has phished/coerced/compromised one HR Admin account) can take over *any* staff identity end-to-end: trigger reset → set password (or wait for the activation/reset link) → the victim's MFA is wiped so the attacker enrolls their own authenticator. This is the single most valuable bypass in the whole system and the PRD applies **no second-actor control, no out-of-band identity proofing requirement, no cooling-off, no notify-the-affected-user, and no rate limit** to it. UJ-7's recovery is "Somchai contacts HR, Pranee resets" — there is no stated requirement that Pranee verify Somchai is actually Somchai. That is the textbook help-desk social-engineering vector (the same class that breached Twitter, MGM, Twilio). For a sole-system-of-record IdP this is the crown-jewel attack.
**Why the existing controls don't cover it:** "Two-role separation of duties" (FR33) separates HR from System Admin — it does **not** separate the reset-requester from the reset-approver. One HR Admin acts alone. The audit log (FG-6) is *detective*, not *preventive*, and (see C3) is read by the same solo operator.
**Suggested fix (make these FRs, not nice-to-haves):**
- Require an **identity-verification step** before any admin MFA/password reset — a documented out-of-band proof procedure the admin must attest to in the audit record (ASVS V6/identity-proofing alignment).
- **Notify the affected user** (email + any secondary channel) on every admin reset of *their* MFA or password, so victim-initiated detection is possible.
- An admin MFA-reset MUST force the account back to **pending/activation** and require **re-enrollment of MFA *and* re-proof of password via the single-use email link** — never leave a "password already known, MFA wiped" window an attacker can walk through.
- **Rate-limit and alert** on admin resets (CM2 watches *volume for support load*, not *for abuse* — add an abuse threshold and an alert, not just a counter).
- Consider requiring resets above a threshold to be performed/confirmed by the System Admin (a true two-person rule for the highest-risk action), acknowledging the solo-operator tension this creates (see C2).

### C2 — Solo operator is the auditor of his own privileged actions; no break-glass / no independent oversight of admin actions
**Location:** R1, NFR8–NFR10, FR33 (separation of duties), FR34 (System Admin views/exports audit log), §D compensating controls.
**Risk:** The "two-role separation of duties" is real for *IdP-config vs. employee-records*, but the System Admin (Rawinan) holds the keys to **everything**: he can create/disable admins (FR33), register clients (FR32), read and export the entire audit log (FR34), and operate the host (key store, DB). There is **no control that prevents the System Admin from creating a rogue admin, minting a client, impersonating a user, or editing/deleting audit entries, and then being the only person who reads the log**. The compensating-controls section explicitly accepts "no independent review" — but accepts it for *code*, and silently extends that acceptance to *runtime privileged operations*, which is a different and larger risk. A sole operator with self-audited god-mode is exactly the insider/compromise scenario PDPA breach-reconstruction is supposed to survive.
**Why existing controls don't cover it:** ASVS L2, SAST, pen test, audited libraries (NFR8–10) address *build-time* assurance. None constrain *runtime* admin abuse or single-operator compromise. R1's mitigations are all build-time.
**Suggested fix:**
- Define a **named second human** (the department DPO/manager or a second System Admin) who receives **append-only, tamper-evident audit exports out-of-band on a schedule** so the operator cannot be the sole reader of his own actions. This is the *minimum* honest compensating control for sole-operator runtime risk and it is currently absent.
- Make audit storage **append-only / write-once from the application's own credentials' perspective** (the app should not be able to delete or rewrite history — see C3).
- Document a **break-glass procedure** and ensure break-glass use is itself logged to the out-of-band sink.
- State explicitly in R1 that runtime privileged-action oversight is a *residual accepted risk* if the org will not staff a second reviewer — naming it is the minimum; pretending separation-of-duties covers it is the failure.

### C3 — Audit log: "tamper-resistant" is undefined, retention (90d) contradicts the 72h-breach-reconstruction need, and the log lacks the events needed to reconstruct a breach
**Location:** FR35–FR39, FR38 (tamper-resistant, 90-day), FR37 (actor/action/target/timestamp/source), NFR14, NFR15 (72h PDPC notification + reconstruction), addendum §C/§E.
**Risk (three compounding problems):**
1. **"Tamper-resistant" is an undefined adjective.** There is no requirement for append-only storage, hash-chaining/sequence integrity, signed entries, off-host/WORM shipping, or separation of the audit store from the operator who can write to it. As written, the solo operator (or an attacker who reaches the host) can edit the only forensic record. For a sole-system-of-record IdP, an un-pinned "tamper-resistant" is a security finding, not a feature.
2. **90-day retention is too short for its own stated purpose.** Breaches in identity systems are routinely discovered **months** after initial compromise (median dwell time is in the *months* for many breach classes). NFR15 requires the ability to reconstruct and notify within 72h *of becoming aware* — but if awareness comes on day 100, the logs that prove scope, entry point, and affected data-subjects are **already deleted**, making the 72h reconstruction impossible and undermining PDPA's "which individuals were affected" determination. 90 days is a defensible *high-volume cost* tradeoff; here volume is ~150 staff — there is no cost justification for a retention period shorter than the realistic detection-to-disclosure window.
3. **The captured event set is insufficient for reconstruction.** FR35/36 list events but omit several that breach forensics need: **token issuance/refresh-rotation/reuse-detection-trip events** (FR9 — needed to scope which sessions an attacker held), **JWKS/signing-key rotation events**, **client-secret rotation (FR32)**, **failed-vs-throttled distinction and source IP/user-agent/device** (FR37 says "source" but doesn't define it), **session creation/termination and idle/absolute-expiry events** (FR8), and **export-of-audit-log events** (who exported what, when — FR34). Without these you cannot answer "what did the attacker reach and when did it stop."
**Suggested fix:**
- Replace "tamper-resistant" with concrete requirements: **append-only**, **hash-chained or signed sequence**, **shipped off-host to storage the application/operator cannot rewrite** (WORM / external log sink with separate credentials), integrity verifiable on export.
- Raise retention to **at least 12 months** (align to realistic detection windows and PDPA scope-determination), with the *erasure* of leaver PII handled separately (pseudonymize the subject in retained audit rows rather than delete the row — reconciles with FR123/NFR14, see M2).
- Expand the captured event set to include token issuance/refresh-rotation/reuse-detection, key rotation, client-secret rotation, session lifecycle, login source (IP/UA/device), and audit-log export itself.
- Add an explicit requirement that **reading/exporting the audit log is itself audited** to an independent sink (closes the C2 self-audit gap).

### C4 — Signing-key custody, rotation cadence, and loss-recovery are named as "catastrophic" but left entirely to architecture with no requirement floor
**Location:** NFR3 (rotatable JWKS), NFR17 ("signing-key loss is catastrophic"), R3, FR5, addendum §B/§C ("key loss catastrophic → backup/recovery mandatory").
**Risk:** The PRD repeatedly says key loss is catastrophic and then **defers the entire control to "architecture"** with no floor. Concrete gaps an attacker/auditor exploits:
- **No rotation cadence or trigger.** "Rotatable" ≠ rotated. Without a defined cadence and an *overlap* requirement (old key in JWKS for validation until all short-lived tokens expire), rotation either never happens or breaks every RP on rotation day.
- **No compromise-response play.** If the signing key is suspected compromised, the requirement set says nothing about **emergency rotation + JWKS cache-busting + forced re-auth + the fact that already-issued tokens cannot be revoked** (you can only roll the key and wait out token TTL — which ties directly to FR25/C5). An attacker who exfiltrates the private key can **mint valid ID tokens for any subject** until the key is rolled *and* every RP refreshes JWKS. There is no requirement that RPs bound their JWKS cache TTL, so a stale-cache RP keeps trusting a rolled key.
- **Key-storage requirement is soft.** §C says pepper/keys in "KMS/HSM," but NFR3 doesn't *require* hardware/KMS-backed non-exportable keys; a private signing key sitting on the same host the solo operator administers is a single exfiltration away from total IdP impersonation.
- **Backup/recovery of a secret is itself an attack surface.** "Backup/recovery mandatory" with no requirement that key backups be **encrypted, access-controlled, integrity-checked, and recovery-tested** means the backup becomes the soft underbelly.
**Suggested fix (promote to NFRs with floors):**
- Signing keys generated and held in **KMS/HSM, non-exportable** where feasible; if not, encrypted at rest with a separately-custodied wrapping key.
- **Defined rotation cadence** + **dual-key overlap window ≥ max token lifetime**; publish `kid` and require RP libraries to honor `kid`.
- **Compromise runbook**: emergency rotation, JWKS propagation expectation, forced global re-auth, and an explicit statement that issued tokens cannot be recalled (short TTL is the only mitigation — make the TTL ceiling a hard requirement, not "short").
- **Tested** backup/restore of keys and store (a backup you have never restored is a hope, not a control); state RTO/RPO for the catastrophic-loss case.
- Require RPs (in the integration guide, FR41) to set a **bounded JWKS cache TTL** and re-fetch on unknown `kid`.

---

## HIGH FINDINGS

### H1 — FR25 leaver-revocation guarantee is honest about *one* limit but silent on the rest; "kept short" has no number
**Location:** FR25, FR8, FR9, UJ-5, SM-context, scope ("No back-channel SLO").
**Risk:** FR25 correctly states already-running app sessions are bounded by token/session lifetime, not instantaneous — good. But:
- **"Kept short via FR8/FR9" has no ceiling.** If the architecture sets the access/ID-token lifetime to, say, 1 hour and an RP issues its *own* long local session on top (which RPs normally do — see below), a disabled leaver can keep using apps far longer than "short." The guarantee is only as strong as the *largest* RP local-session lifetime, which the IdP does **not** control and the integration guide (FR40–43) does **not** require RPs to bound.
- **The real leak is RP local sessions, which FR25 doesn't mention.** OIDC's standard pattern: the RP consumes the ID token *once* at login and then runs its **own** session cookie for hours/days. Disabling at the IdP stops *new* logins but does nothing to an RP that already minted a multi-hour local session and never re-checks the IdP. FR25's "bounded by token/session lifetime" quietly assumes RP sessions track IdP token TTL — they don't, unless the integration guide *requires* it. This is the honest limit that is **not** stated and may **not** be acceptable for a leaver with malicious intent.
- **Refresh tokens (FR9) extend the window.** If refresh tokens are issued, a leaver's RP can keep refreshing until reuse-detection or the absolute lifetime trips — and FR25 doesn't require that disabling an account **revokes outstanding refresh-token families immediately** (which the IdP *can* do, unlike back-channel SLO).
**Suggested fix:**
- Set a **hard ceiling** on access/ID-token lifetime (e.g., ≤15 min) as an NFR, not "short."
- Require disabling an account to **immediately revoke all outstanding refresh-token families** for that subject (this is in the IdP's power and should be an FR25 sub-requirement).
- The integration guide (FR41) MUST **require RPs to bound their local session lifetime** to the IdP token TTL and/or honor `max_age`/periodic re-auth, and MUST state plainly that without this, *disable is not effective until the RP's local session expires.* State this residual as an accepted, quantified limit — currently it is invisible.
- Reconsider whether back-channel SLO truly belongs in post-v1 (roadmap §B item 4) given that leaver-revocation is a *headline* requirement; at minimum, the IdP should expose a revocation/session-status signal RPs *can* poll.

### H2 — Session fixation, SSO-session binding, and cookie scope are not addressed
**Location:** FR6 (state/nonce per-request), FR7 (SSO session), FR8 (idle/absolute lifetime), NFR4 (Secure/HttpOnly/SameSite).
**Risk:** FR6 binds the *authorization request* with state/nonce (good, and correct per OIDC), but **nothing addresses the IdP's own login-session fixation**: the requirement set does not mandate **regenerating the session identifier on privilege change (post-login, post-MFA, post-password-set)**. Session fixation is a classic, ASVS-required control (V3/Session Management) and its omission in a from-scratch IdP is exactly the kind of bug a solo builder ships. Also unspecified: cookie `Domain`/`Path` scope and the binding between the SSO cookie and the authenticated subject (to resist cookie theft/replay). `SameSite` value is unspecified — `SameSite=Lax` vs `Strict` vs `None` materially changes CSRF posture and cross-RP redirect behavior.
**Suggested fix:** Add an NFR/FR: **rotate session identifier on every authentication-state transition** (login, MFA success, password set, step-up); pin cookie `__Host-`/`Secure`/`HttpOnly`/`SameSite=Lax` (justify if `None` needed for cross-site RP flows); bind session to a server-side record so server-side revocation (and FR25 disable) can invalidate it. Add **server-side session invalidation on account disable** as the IdP-side half of FR25.

### H3 — Activation/reset email token flow: several enumeration and replay edges unclosed
**Location:** FR16, FR17, FR20, NFR2, UJ-2, UJ-3.
**Risk:** The flow is mostly well-specified (single-use, hashed-at-rest, ≥128-bit, ≤20 min, enumeration-resistant generic responses — genuinely good, NFR2/FR20). Remaining holes:
- **Token invalidation on use/issue is underspecified.** "Single-use" is stated, but not: *issuing a new reset token MUST invalidate any prior outstanding token* (otherwise multiple live tokens widen the window), and *completing a reset MUST invalidate all other auth artifacts* (active sessions, outstanding tokens — a password reset is a security event and should log out everywhere).
- **Activation link is the account's first secret and has no MFA gate behind it.** During activation the user "sets password and enrolls MFA" (FR16) — but the **activation link itself is the sole authenticator** for that bootstrap. If the email is intercepted/forwarded (and email is explicitly the critical-path channel, NFR16), an attacker activates the account, sets the password, and enrolls *their own* MFA before the real employee logs in. No second factor protects activation. There is no requirement to bind activation to anything the legitimate employee uniquely holds, nor to alert on activation, nor to expire pending accounts (CM3 *watches* never-activated accounts but no FR *expires* them — a long-lived pending account is a standing pre-auth'd target).
- **Reset does not require re-MFA.** FR17/UJ-3: "sets a new password → signs in with MFA." Good that MFA is still required at sign-in — but confirm the reset flow itself cannot be used to *bypass* MFA (it must not clear MFA enrollment; only the admin path (FR15) does that). State this explicitly; today it's implicit.
- **No rate limit on reset *requests*** (vs. verification). FR19 covers login/TOTP brute force; reset-request flooding (email-bombing a victim, or harvesting timing) is not covered.
**Suggested fix:** Add explicit requirements: issuing a token invalidates prior tokens; completing reset/activation invalidates all sessions and outstanding tokens; **alert the user on activation and on completed reset**; **expire pending accounts** after a bounded window and require re-issue; rate-limit reset *requests* per-account/per-IP; assert (and test) that no email flow clears MFA.

### H4 — MFA is single-factor-recoverable and TOTP-only with no anti-phishing acknowledgment; enrollment trust-on-first-use
**Location:** FR13, FR14, FR15, NFR2, roadmap §B item 6 (WebAuthn deferred).
**Risk:**
- **TOTP is phishable.** The PRD enforces MFA (good) but TOTP codes are real-time-phishable via reverse-proxy AITM kits (Evilginx-class). The PRD defers phishing-resistant WebAuthn to post-v1 — *acceptable for v1*, but the **residual phishing risk is not named anywhere** as an accepted limit, and for a sole-system-of-record IdP guarding a health division it should be an explicit, owned residual with a roadmap commitment, not silence.
- **MFA enrollment is trust-on-first-use** behind the activation/reset link, inheriting H3's interception risk: whoever holds the activation email controls MFA enrollment.
- **No requirement to prevent TOTP code reuse within the validity window** (a verified code must be single-use within its step to block replay inside the drift window — FR14 mentions drift window + rate-limit but not single-use-per-step).
- **Lockout/lockdown semantics on MFA failure unspecified vs. login** — FR19 throttles both, but does TOTP lockout lock the *account* (DoS-able by an attacker who knows the username) or just the attempt? Per-account lockout on a known username is a denial-of-service primitive against a named employee.
**Suggested fix:** Name TOTP phishing as an accepted v1 residual + commit WebAuthn on the roadmap with a trigger; require **single-use-per-step TOTP** (reject a code already accepted in its window); specify that per-account throttling uses **progressive delay rather than hard lockout** (NIST 800-63B guidance) to avoid the named-victim DoS; tie MFA-enrollment integrity to the H3 activation hardening.

### H5 — "OWASP ASVS L2 passed" is the go-live gate (SM5) but it is self-attested by the sole builder — the gate certifies itself
**Location:** SM5, NFR6, NFR10, R1, §D.
**Risk:** SM5 makes "OWASP ASVS L2 checklist passed" a **pass/fail go-live gate** — but the only party who runs the checklist is the same solo builder whose lack of independent review is the headline risk (R1). A self-graded security exam from the one person with no second reviewer is **not assurance**; it is documentation of intent. The pen test that *would* provide independent validation (NFR10) is **"recommended, budget-permitting"** — i.e., not a gate. So the system can go live with **zero independent security validation** while *claiming* an ASVS L2 pass as its go-live criterion. That is the compensating-control claim not actually compensating.
**Suggested fix:** Make the **independent pen test a hard go-live gate** for the sole-system-of-record IdP (not "budget-permitting") — the in-house mandate may forbid buying the *product*, but it does not forbid buying *one independent assessment*, which is the cheapest possible substitute for the missing second reviewer. At minimum, require the ASVS L2 checklist to be **independently reviewed** by a second qualified person before SM5 can be marked passed. If neither is possible, R1 must state that go-live proceeds with self-attested security and no independent validation as an explicitly accepted organizational risk — signed off above the builder.

### H6 — PDPA: lawful basis, RoPA, DPO sign-off, breach runbook, and DSR/erasure are all present as text but **non-blocking for v1 build**, and the controller obligations are pushed off the builder without an owner-with-a-deadline
**Location:** NFR11–NFR15, OQ3 ("Non-blocking for v1 build"), R7, addendum §E, FR123/NFR14 (leavers disabled-not-deleted).
**Risk:** The privacy analysis is competent (correct that lawful basis is contractual/legal/legitimate-interest *not consent*; correct that §26 sensitive data is excluded; correct on 72h). But the **organizational obligations are declared "non-blocking for v1 build"** and handed to "the department's DPO/legal" with **no named owner and no deadline tied to go-live**. Concrete exposures:
- A system can be *built and deployed* with **no completed RoPA, no DPO sign-off, no tested breach runbook** because those are "before broad rollout," and "broad rollout" is undefined. The pilot *is* live processing of real staff PII the moment the first real employee activates — PDPA obligations attach then, not at "broad rollout."
- **NFR15's 72h breach runbook is undermined by C3** (90-day retention + undefined tamper-resistance): you cannot reliably reconstruct/scope a breach you detect after 90 days.
- **Erasure vs. audit retention is internally inconsistent.** FR123/NFR14 says leavers are *disabled, not deleted* "preserves audit trail + reconciliation," and NFR14 promises a "deactivation/erasure process for leavers" and "data-subject access + rectification via the console" — but there is **no defined erasure trigger, timeline, or reconciliation between "retain for audit" and "erase on PDPA request."** A data subject's erasure request will collide with the disabled-not-deleted policy and the audit-retention requirement, with no stated resolution (which data is erased, which is retained under legal-obligation basis, how the subject reference is pseudonymized in retained audit rows).
- **DSR is only "access + rectification."** PDPA also grants **objection, restriction, data portability, and erasure** rights; the PRD scopes DSR to access+rectification only, without stating *why* the others are inapplicable (some are legitimately limited under legal-obligation basis — but that must be reasoned, not omitted).
**Suggested fix:** Make **RoPA, lawful-basis documentation, DPO sign-off, and a tested breach runbook hard gates before the *pilot* processes real staff data**, not before "broad rollout"; name an accountable owner and a date. Resolve the erasure/retention conflict explicitly: define what is erased vs. retained-under-legal-obligation, the erasure timeline, and the **pseudonymization of the data subject in retained audit rows**. State the disposition of each PDPA data-subject right (supported / limited-by-legal-basis-because-X). Fix C3 retention so the 72h runbook is actually executable.

---

## MEDIUM FINDINGS

### M1 — Client (RP) authentication and secret custody are underspecified; confidential-client assumption is load-bearing but only an "[ASSUMPTION]"
**Location:** FR32 (rotate client secret), FR1 (Auth Code + PKCE), standing assumption (confidential server-side clients), FR4 (exact-match redirect).
**Risk:** PKCE is required for all clients (good — protects public clients), but for **confidential** clients the PRD never specifies the **client authentication method** (`client_secret_basic`? `client_secret_post`? `private_key_jwt`?), secret **entropy/storage/rotation overlap** (FR32 says "rotate" but not dual-secret overlap so rotation doesn't break the RP), or what happens to **in-flight auth using the old secret**. It also doesn't require **`aud`/`azp` validation** guidance for RPs or **sender-constraining**. The confidential-vs-public client posture is only an `[ASSUMPTION]` — if a pilot app turns out to be a public SPA, several implicit assumptions (where the secret lives, token storage) change and there's no requirement covering it.
**Suggested fix:** Specify client-auth method(s) and prefer `private_key_jwt` for confidential clients where feasible; require dual-secret rotation overlap; require RP-side `aud`/`iss`/`exp`/`nonce`/`azp` validation in the integration guide; resolve the confidential/public assumption before integration and state per-type requirements.

### M2 — Audit/erasure retention math and the "disabled not deleted" reconciliation (cross-ref C3/H6)
**Location:** FR123/NFR14, FR38, C3, H6.
**Risk:** Three retention policies interact with no reconciliation: audit logs 90 days (FR38), identity retained for employment duration (NFR14), leavers disabled-not-deleted indefinitely (FR123). A leaver's `sub`/email persists in disabled identity rows *and* in audit rows; a PDPA erasure request has no defined effect on either. (Severity medium only because the data is "ordinary" not §26; the conflict is still an auditor finding.)
**Suggested fix:** As in H6/C3 — define erasure scope, retention basis per data class, and audit-row pseudonymization.

### M3 — Rate-limiting / brute-force protection lacks thresholds, and lockout is a DoS vector against named accounts
**Location:** FR14, FR19, FR19 (per-account + per-IP), CM1.
**Risk:** FR19/FR14 require throttling/lockout but specify **no thresholds, no lockout duration, no distinction between throttle and hard-lock, and no captcha/step-up alternative**. Per-account lockout keyed on a known username (work email is *predictable* — firstname.lastname@) lets an attacker **lock out any named employee at will** (a targeted-DoS / availability attack against a 24/7 system — see NFR17). CM1 watches the *symptom* (legitimate lockouts) but no requirement prevents the *attack*.
**Suggested fix:** Prefer **progressive delays + per-IP/per-ASN throttling + anomaly-based step-up** over hard per-account lockout (NIST 800-63B §5.2.2); if hard lock is used, cap it and provide self-service unlock that doesn't widen H1. Define concrete thresholds in deployment config and test them against CM1.

### M4 — Discovery/JWKS/host hardening and DoS for the single-point-of-dependency are unaddressed
**Location:** FR11 (discovery), FR5 (JWKS), NFR17 (single point of dependency, 24/7), NFR18 (not high-scale).
**Risk:** The IdP is the single dependency for all apps (NFR17) yet there are **no requirements for rate-limiting/abuse-protection on the public unauthenticated endpoints** (authorize, token, JWKS, discovery), no WAF/edge protection, no DoS posture, and no requirement that JWKS/discovery be cacheable/CDN-frontable to survive a traffic spike or a deliberate flood. "Not a high-scale system" (NFR18) is about *legitimate* load; it says nothing about an attacker who can take down authentication for the entire division by flooding one box. For a 24/7 single-point-of-failure, availability *is* a security property.
**Suggested fix:** Add edge rate-limiting/DoS protection requirements for public endpoints; make JWKS/discovery cache-friendly; define the HA topology's failure behavior; state an availability SLO with the threat-driven (not just reliability-driven) view.

### M5 — Pepper and secret-management lifecycle is "SHOULD," and rotation/loss of the pepper is unaddressed
**Location:** NFR1 ("a pepper SHOULD be used"), §C (pepper in KMS/HSM).
**Risk:** Pepper is **SHOULD**, not MUST — for a sole-system-of-record credential store, a separately-custodied pepper materially raises the bar against a stolen DB and should be **MUST**. Also, **pepper rotation/loss** is undefined: losing the pepper makes every Argon2id hash unverifiable (a quieter sibling of the signing-key-loss catastrophe in C4), and there's no backup/rotation requirement for it.
**Suggested fix:** Make pepper **MUST**, KMS-custodied, with a defined backup and a rotation strategy (e.g., versioned pepper with rehash-on-login). Add pepper loss to the catastrophic-recovery runbook alongside the signing key.

### M6 — Bulk CSV import (FR30) is an unvalidated bulk-account-creation and injection surface
**Location:** FR30, UJ-4, R5.
**Risk:** CSV import that creates pending accounts + auto-sends activation emails (FR26/FR30) is a **bulk pre-auth'd-target generator** and a classic **CSV-injection / formula-injection** and email-bombing surface, with no stated input validation, dedupe-on-import (R5 worries about duplicates but no import-side control), per-import size/rate cap, or preview/confirm step. A malformed or malicious roster could create hundreds of pending accounts and blast activation emails (interacting with H3's long-lived pending risk and SMTP critical-path NFR16).
**Suggested fix:** Require server-side validation, email-format/uniqueness checks and dedupe against existing identities, CSV-injection sanitization on any later export, a preview/confirm step, and a per-import size cap with throttled activation-email dispatch.

### M7 — `state`/`nonce`/PKCE binding and one-time-use are asserted at the request level but server-side single-use isn't required
**Location:** FR6, FR1.
**Risk:** FR6 says bind with state/nonce; FR1 requires PKCE. Not stated: **authorization codes MUST be single-use and short-lived with replay-detection** (RFC 9700), **`nonce` MUST be verified once and not replayable**, and **PKCE `code_verifier` binding MUST be enforced server-side** (not just "supported"). These are implied by "conform to RFC 9700" (NFR5) but a solo builder benefits from them being explicit FRs, because they are precisely the spots where a from-scratch implementation silently drops a check.
**Suggested fix:** Promote to explicit requirements: single-use short-lived auth codes with replay revocation of the issued tokens on code-reuse; server-enforced PKCE; one-time nonce.

---

## LOW FINDINGS

### L1 — "Draft" status with FG-2…FG-7 marked "in progress" but fully populated
**Location:** Header note (lines 11–12) vs. body.
**Risk:** The status banner says FG-2…FG-7/NFRs/journeys "in progress," but they appear complete. Stale status invites an auditor to question document control. **Fix:** update the banner; lock sections that are done.

### L2 — `SameSite`, cookie names, and CSRF for the admin consoles unspecified
**Location:** NFR4, FG-4/FG-5 consoles.
**Risk:** The admin consoles (HR + System) are high-value and their CSRF/session protections aren't called out separately from the staff login. **Fix:** require CSRF tokens + re-auth/step-up for sensitive admin actions (reset MFA, register client, manage admins) — ties to C1/C2.

### L3 — No requirement for security headers / clickjacking protection on the IdP login UI
**Location:** FR12 (branded login), NFR4.
**Risk:** A branded login page is a phishing/clickjacking target; no CSP/`frame-ancestors`/HSTS requirement is stated. **Fix:** require CSP (incl. `frame-ancestors 'none'` on login), HSTS, and standard security headers as an NFR.

### L4 — Logout is RP-initiated only; no global/admin-forced logout and no session-listing for incident response
**Location:** FR10, scope (no SLO), C2.
**Risk:** During an incident the operator cannot **force-terminate all of a user's IdP sessions** (only the user can RP-initiate). **Fix:** add admin/server-side forced-logout + active-session invalidation (overlaps H2/H1 fixes); this is in-IdP and cheap, unlike back-channel SLO.

### L5 — Localization deferral may weaken security comprehension for Thai-first non-technical staff
**Location:** FR12, NFR19, UJ-2/UJ-7.
**Risk:** English-first security-critical prompts (activation, reset, MFA enrollment warnings, "don't share this link") to non-technical Thai staff may reduce comprehension of exactly the anti-phishing guidance that mitigates H3/H4. **Fix:** prioritize Thai for the *security-critical* email/UX strings even if the rest stays English-first.

---

## SUMMARY TABLE

| ID | Sev | Title | Location |
|----|-----|-------|----------|
| C1 | Critical | Admin MFA+password reset = unguarded account-takeover primitive | FR15/FR29/UJ-7/NFR16 |
| C2 | Critical | Solo operator self-audits god-mode runtime actions; no break-glass/oversight | R1/FR33/FR34/NFR8-10 |
| C3 | Critical | Audit "tamper-resistant" undefined; 90d retention vs 72h reconstruction; events insufficient | FR35-39/NFR15 |
| C4 | Critical | Signing-key custody/rotation/loss-recovery no requirement floor | NFR3/NFR17/R3 |
| H1 | High | FR25 leaver-revocation silent on RP local sessions + refresh tokens; "short" has no number | FR25/FR8/FR9 |
| H2 | High | Session fixation / SSO cookie binding / server-side invalidation unaddressed | FR6/FR7/NFR4 |
| H3 | High | Activation/reset token replay, no activation MFA gate, no pending expiry, no request rate-limit | FR16/FR17/FR20 |
| H4 | High | MFA TOTP-only phishable (unnamed residual), TOU enrollment, per-account lockout DoS | FR13/FR14/FR15 |
| H5 | High | ASVS L2 go-live gate is self-attested; pen test only "budget-permitting" | SM5/NFR10/R1 |
| H6 | High | PDPA obligations "non-blocking for v1," no owner/deadline; erasure-vs-retention conflict | NFR11-15/OQ3 |
| M1 | Medium | Client auth method/secret custody underspecified; confidential-client only an assumption | FR32/FR1 |
| M2 | Medium | Retention math: disabled-not-deleted vs audit vs erasure unreconciled | FR123/NFR14/FR38 |
| M3 | Medium | Brute-force thresholds undefined; per-account lockout = named-victim DoS | FR14/FR19/CM1 |
| M4 | Medium | No DoS/abuse protection on public endpoints for the single point of dependency | FR11/FR5/NFR17 |
| M5 | Medium | Pepper only SHOULD; pepper rotation/loss unaddressed | NFR1 |
| M6 | Medium | CSV import = bulk pre-auth target + CSV-injection + email-bomb surface | FR30 |
| M7 | Medium | Auth-code/nonce/PKCE single-use & server-side binding not explicit | FR6/FR1 |
| L1 | Low | Stale "in progress" status banner | Header |
| L2 | Low | Admin-console CSRF/step-up unspecified | NFR4/FG-4/5 |
| L3 | Low | No CSP/clickjacking/HSTS requirement on login UI | FR12/NFR4 |
| L4 | Low | No admin-forced logout / session listing for IR | FR10 |
| L5 | Low | English-first security strings weaken anti-phishing comprehension for Thai staff | FR12/NFR19 |

---

## BOTTOM LINE FOR THE BUILDER

The OIDC *protocol* surface is well-shaped and the citations are real. The danger is not the flow — it's the **operational primitives a solo operator owns alone**: the admin reset (C1), self-audited god-mode (C2), the audit trail's integrity and lifespan (C3), and key custody (C4). These are precisely the controls that *cannot* be satisfied by "audited libraries + ASVS self-check," because they are about **second actors, out-of-band proof, tamper-evident records, and tested recovery** — none of which a library provides. Resolve the four CRITICALs and make the pen test a real gate (H5) before any real staff PII enters the system, and the honest-residuals (H1, H4, H6) become *named accepted risks* rather than silent gaps — which is the difference between a defensible sole-operator IdP and one that fails the first real audit or the first phished help-desk call.
