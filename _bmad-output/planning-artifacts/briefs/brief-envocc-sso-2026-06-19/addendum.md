---
title: "Addendum: envocc-sso Product Brief"
status: final
created: 2026-06-19
updated: 2026-06-19
---

# Addendum — envocc-sso

Depth that belongs downstream (PRD / architecture), not in the 2-page brief. Captured during discovery.

## Options Considered (rationale detail)

The decision (build custom; reject Keycloak/Authentik) and its headline rationale live in **brief §What Makes This Different**. Additional depth captured here:

- **Off-the-shelf would have been faster and safer** — Keycloak/Authentik deliver OIDC, MFA, password policy, account lockout, token rotation, and ongoing CVE patching out of the box, in days not months.
- **Branded login does not require a custom build.** Keycloak supports full custom themes (own HTML/CSS/JS over login, registration, reset, account pages) and a replaceable account console; Authentik has flows + branding. So driver #2 (UX control) alone was satisfiable off-the-shelf.
- **Drivers, by weight:** #3 in-house mandate (load-bearing, decisive) > #4 own/understand the auth layer > #2 full UX control. #4 and #2 would not justify the build on their own.

## Parked Roadmap (post-v1)

In rough priority order, candidates once v1 is proven:

1. **Centralized authorization** — manage roles/groups in the IdP and emit them as token claims so apps stop maintaining their own role tables. (v1 is auth-only; this is the most natural next step.)
2. **Migrate the remaining apps** — all 10–15 behind SSO within ~a year of pilot success.
3. **Audit logging** — centralized record of authentication and admin actions.
4. **Federation / external IdP** and **SCIM provisioning** — if the org's needs grow.
5. **Passwordless / WebAuthn** — stronger, phishing-resistant auth.

## Downstream Technical Implications (for architecture)

These follow directly from decisions made in the brief and should inform the architecture phase:

- **System of record for credentials.** No external store (no AD/LDAP/HR feed) exists, so the IdP stores passwords itself → modern password hashing (Argon2id-class), strong password policy, account lockout/brute-force protection are mandatory.
- **No password migration.** The 10–15 legacy apps hash differently; their passwords cannot be carried over. Onboarding = admin creates account → emailed activation link → user sets own password on first login.
- **Identity reconciliation.** The same ~100–150 people hold scattered accounts across apps; v1 must collapse duplicates into one canonical identity (likely keyed on a reliable org identifier — TBD).
- **OIDC flow.** Standard Authorization Code flow (with PKCE) so apps integrate via standard OIDC client libraries; login page hosted by the IdP (credentials never transit relying parties).
- **Email/SMTP dependency.** Reliable org email confirmed; both self-service reset and activation depend on it. Architecture should treat mail deliverability as a critical path.
- **App-owner integration boundary.** This project ships the IdP + an OIDC integration guide; each app owner wires their own app. The guide is a v1 deliverable.
- **Localization.** Build English-first, structured for localization; Thai translation handled by the owner after UI stabilizes.
- **Solo build, no independent review.** Mitigations in brief §Risk Accepted & Mitigation apply; architecturally this mandates audited libraries only, with no hand-rolled crypto or token logic.
