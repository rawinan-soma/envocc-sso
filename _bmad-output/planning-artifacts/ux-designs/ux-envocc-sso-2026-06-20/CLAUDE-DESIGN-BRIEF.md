# Claude Design brief — envocc-sso

**How to use this:** Open **claude.ai/design**, connect/point it at this repository (it reads codebases + design files to build the system), and paste the prompt below. The two spec files named here are its source of truth. When the screens are ready, use Claude Design's **handoff bundle → Claude Code** to bring them back for the build.

> Access note: Claude Design is a gated research preview (Claude Pro / Max / Team / Enterprise; rolling out since 2026-04-17). If it isn't enabled for you, ask me to render HTML key-screens or assemble a Google Stitch handoff instead.

---

## Files to point Claude Design at (source of truth)
- `_bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-20/DESIGN.md` — visual identity: tokens, type scale, component specs.
- `_bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-20/EXPERIENCE.md` — IA, flows, states, voice, accessibility.
- `_bmad-output/planning-artifacts/prds/prd-envocc-sso-2026-06-19/prd.md` — the product requirements behind them.
- Visual reference mocks: `ux-designs/ux-envocc-sso-2026-06-20/.working/directions-login.html` (login layout) and `.working/color-themes-civic.html` (palette in context).

---

## Paste this prompt into Claude Design

> Build the screens for **envocc-sso** — EnvOcc's first single sign-on / central identity system. EnvOcc is the Division of Occupational and Environmental Diseases, a Thai government public-health division. The users are ~100–150 **non-technical staff** plus a small number of **HR administrators** and one **System administrator**. Use `DESIGN.md` and `EXPERIENCE.md` (in `ux-designs/ux-envocc-sso-2026-06-20/`) as the source of truth — `DESIGN.md` for visuals, `EXPERIENCE.md` for behavior, flows, states, and copy. The spines win on any conflict.
>
> **Visual identity (locked — "Civic Register / Ministry Bronze"):** institutional, calm, trustworthy government-health register. Light mode only. WCAG 2.1 AA.
> - Primary navy `#1B3354` (hover `#142744`), white on navy. Accent bronze `#A9711B`; links `#7A4F0E`.
> - Ground white `#FFFFFF`; warm-greige surface `#F7F5F1`; border `#DED7CB`. Text `#1E2A3D`; muted `#6A6356`.
> - States — success `#2A6B3E`/bg `#E9F2EA`; warning `#97601A`/bg `#F7EEDD`; error `#AD2B1E`/bg `#FBEAE6`; info `#245B8C`/bg `#E9F0F6`.
> - Type — **Noto Serif** (+ Noto Serif Thai) for the EnvOcc wordmark + headings; **Noto Sans** (+ Noto Sans Thai) for body/forms/data; Noto Sans Mono for the verification-code input. English-first, structured for Thai.
>
> **Voice (non-negotiable):** plain language, **no jargon** — say "verification code" / "authenticator app", never "TOTP/OIDC/token". **Anti-phishing guidance is first-class and visible** ("We'll never ask for your verification code"; "Don't share this link — it signs in as you"). **Enumeration-resistant** messages — identical whether or not an account exists ("If an account exists for this email, we've sent a link"). Security-event copy always includes an "if this wasn't you" path.
>
> **Platform:** web only. Staff auth = responsive (phone + desktop), rendered top-level (never embedded/iframed). Admin app = desktop-first, data-dense.
>
> **Generate these surfaces** (group A = branded staff auth; group B = one role-gated admin app):
>
> *A — Staff auth (responsive, branded card on a calm canvas):*
> 1. Sign in — email + password, "Forgot password?", pinned anti-phishing reassurance.
> 2. Verification code — 6-digit input, "open your authenticator app".
> 3. Activation — set first password (live policy hints: ≥12 chars, passphrases welcome) → enroll MFA (QR + manual key + confirm) → "account active".
> 4. Password reset — request → generic "link sent" → set new password → "you've been signed out everywhere else" (framed as protection).
> 5. Key states — lockout/throttle ("Too many attempts…"), expired/used link, session-expired re-auth.
>
> *B — Admin app (one branded shell, role-gated nav: HR section vs System section):*
> 6. Admin shell — header with EnvOcc wordmark + the signed-in role's nav only.
> 7. HR · User list & search — table with Active / Pending / Disabled status pills.
> 8. HR · User detail — enable/disable, trigger reset, **reset MFA behind a required identity-proofing attestation modal**, edit profile.
> 9. HR · CSV import — upload → validate & preview (per-row errors) → confirm.
> 10. System · Client list + Register/edit client — credentials, exact-match redirect URIs, scopes.
> 11. System · Audit log — filterable table of auth events + admin actions.
> 12. System · Admin users — create/disable HR & System admins; **step-up re-auth modal** for sensitive actions.
>
> Keep one task per auth card; tables calm and scannable; the identity-proofing and step-up modals should feel like deliberate trust gates, not friction. Produce an interactive prototype, then a Claude Code handoff bundle.

---

## When the screens come back
Hand the Claude Design **handoff bundle** to me (Claude Code) and I'll implement the real frontend against `DESIGN.md` + `EXPERIENCE.md`. The architecture phase (`bmad-create-architecture`) can run in parallel — it owns the build stack, key custody, and HA that the PRD deferred.
