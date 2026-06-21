---
title: "Product Brief: envocc-sso"
status: final
created: 2026-06-19
updated: 2026-06-21
---

# Product Brief: envocc-sso

> Product brief — fixes the **what** and the **why**, not the **how**. All implementation, stack, and tooling choices are deferred to the architecture phase.

## Executive Summary

**envocc-sso** is a single sign-on and central identity system for the **Division of Occupational and Environmental Diseases (EnvOcc)**. Today ~100–150 staff each maintain separate accounts across 10–15 internal applications, and there is **no central record of who works here**. envocc-sso becomes that missing source of truth — one identity, one login, one place to grant and revoke access.

The system has **two co-equal halves**. For **staff**, a single branded login (with multi-factor authentication and self-service password reset) replaces a drawer full of separate app credentials. For **HR administrators**, an admin console replaces the impossible task of tracking accounts scattered across a dozen systems — they provision people once, and disable them when they leave.

This is security-critical infrastructure: it guards every other app and is the system of record for staff credentials. v1 is therefore scoped deliberately tight (authentication only), the rollout is phased to prove safety before scale, and **security rigor — not feature count — is the definition of done**. There is no fixed deadline; readiness is the deadline.

## The Problem

EnvOcc runs 10–15 internal applications, each with its own login and its own user table. The same ~100–150 people appear again and again across these systems — Somchai in the lab system, Somchai in the reporting tool, Somchai in the document archive — as a dozen disconnected accounts that no one system can see as one person.

This creates real, daily costs:

- **For staff:** a different username and password for every app. Forgotten passwords, reused passwords, sticky notes — the usual insecure coping mechanisms.
- **For administrators:** no way to answer "what can this person access?" or "is everyone who left actually locked out?" Onboarding means creating accounts in many places; offboarding means *remembering* to remove them from many places — and missed offboarding is a live security hole.
- **For the organization:** there is no central identity record at all. Access lives implicitly inside each app's database. There is no single point to enforce a password policy, require MFA, or audit who can get in.

For an organization handling occupational and environmental health data, scattered and un-revoked access is a genuine security and governance liability.

## The Solution

A central identity provider that becomes EnvOcc's first single sign-on. Apps redirect users to envocc-sso to sign in; it authenticates them and issues a standard token the app trusts. One identity, reused everywhere.

Core capabilities for v1:

- **Standards-based single sign-on** so internal apps can integrate using off-the-shelf client libraries.
- **Branded, organization-owned login experience** matching EnvOcc's identity — the branding is a **trust / anti-phishing signal**: a non-technical staff member, redirected here from another app, must immediately recognize this as the real, sanctioned login and not an imitation.
- **Multi-factor authentication (MFA)** from day one.
- **Self-service password reset** via email, so ~150 users don't funnel reset requests through admins.
- **Admin console for HR administrators** — provision accounts, enable/disable, basic account management. A first-class half of the product, not an afterthought.
- **First-login account activation** — admins create accounts and each user sets their own password on first sign-in via an emailed activation link.
- **Integration documentation** so each app's owner can wire their app to envocc-sso themselves.

Built **English-first**, structured for localization; Thai is translated separately by the owner after the UI stabilizes.

## Scope

**In scope (v1):**
- Identity provider — authentication + token issuance via standards-based SSO
- Central user store — envocc-sso is the system of record for identity
- Branded login + MFA + self-service password reset
- Admin console — user provisioning, enable/disable, password reset, basic account management
- Activation / first-login password-set flow (email-based)
- Account reconciliation — collapsing each person's scattered per-app accounts into one canonical identity
- Integration guide for app owners
- Pilot integration with the first 1–2 apps

**Out of scope (v1) — explicitly deferred:**
- **Centralized authorization** — roles, groups, and permissions stay inside each app for now. envocc-sso answers *who you are*, not *what you may do*.
- Wiring all 10–15 apps — each app's owner does their own integration; this project delivers the IdP and the guide.
- External / public / partner users — internal staff only.
- Social login, federation with external IdPs, SCIM provisioning, passwordless/WebAuthn — future vision, not v1.

## Who This Serves

- **Staff (~100–150 employees)** — primary, non-technical end users. Success = one login, no password sprawl, quick self-service recovery.
- **HR administrators** — operate the admin console; own the joiner/mover/leaver lifecycle. Success = provision and de-provision a person in one place, with confidence it takes effect everywhere.
- **App owners** — integrate their apps as clients. Success = a clear guide and a stable IdP they can adopt without deep auth expertise.

## What Makes This Different

This is **not** a market-differentiation play. The justification is **fit and mandate**:

- **In-house mandate** — the organization requires the system to be **self-hosted, fully owned, and inspectable**: no foreign SaaS, no data leaving the ministry, complete control of code, data, and user experience. This **sovereignty and control** requirement is the load-bearing reason and is taken as given.
- **Full ownership** — no third-party software in the trust path that the organization cannot host and inspect.
- **Full control of the user experience** — the branded login (a trust / anti-phishing signal for non-technical staff) and the HR admin console must be **owned and shaped by EnvOcc**, not constrained to a vendor's stock screens. *This UX-ownership requirement holds regardless of the implementation approach chosen — a ground-up build provides it inherently; a self-hosted engine (Keycloak / Authentik) provides it through full custom theming.*
- **Right-sized** — purpose-built for one organization's exact needs (auth-only, ~150 users), without the surface area of a general-purpose platform.

> The product requirement is a **single sign-on / central identity system**. The **implementation approach** that satisfies the sovereignty constraint is an **architecture decision, deliberately left open here** — the candidates are **(a) building the IdP ground-up**, **(b) self-hosting Keycloak**, or **(c) self-hosting Authentik** (or another inspectable, self-hostable open-source IdP). The brief fixes the *need*, not the *how*.

## Risk Accepted & Mitigation

Identity infrastructure is among the most security-sensitive systems one can run: it guards every other app, holds credentials as the system of record, and is operated **solo**. The mandate manages this risk rather than removing it. Accepted risk, with mitigations:

- **Tight v1 surface** — authentication only; no authorization logic to get wrong.
- **No fixed deadline** — readiness, not a date, gates release.
- **Phased rollout** — prove the IdP in production with 1–2 apps before the rest depend on it.
- **Stand on vetted, audited foundations** — never hand-roll cryptography, token, or session logic. (Detailed choices belong to the architecture phase.)
- **MFA from v1** — limits damage from any single credential compromise.

**Residual risk — no independent security review.** Solo self-review is *not* independent assurance for security-critical auth. This is an explicitly accepted limitation, with compensating controls:
- Build only on audited, maintained components; treat any custom security code as a red flag.
- Automated tooling in the pipeline — dependency/vulnerability scanning and SAST.
- Work against published checklists — OWASP ASVS and OIDC/OAuth security best-practice guidance.
- Consider a one-time external penetration test before broad rollout, if budget allows.

## Success Criteria

- The pilot apps authenticate staff exclusively through envocc-sso, with zero separate logins for those apps.
- A staff member can sign in once and reach every integrated app without re-authenticating.
- HR admins can fully onboard a new hire and fully disable a leaver from the admin console alone.
- MFA is enforced and self-service password reset works end-to-end via email.
- No security defect in the token-handling, session, or credential-storage class is outstanding when an app goes live.

## Vision

If v1 proves out, envocc-sso becomes EnvOcc's identity backbone: all 10–15 apps behind one secure login within the following year, then a natural progression into **centralized authorization** (roles and groups managed once, read by every app), audit logging, and — further out — federation or passwordless sign-in. The end state is that identity and access for the whole organization are managed in one trustworthy place that EnvOcc fully owns.

## Open Questions (for PRD / Architecture)

- Any regulatory/compliance regime that applies to a Thai public-health division's identity data (e.g. PDPA)?
- Which specific apps are the pilot, and what are their stacks?
- **Implementation approach — undecided (deferred to architecture).** Which approach best satisfies the sovereignty constraint: **ground-up custom build**, **self-hosted Keycloak**, or **self-hosted Authentik** (or another self-hostable open-source IdP)? To be evaluated against security risk, solo-operator burden, and degree of control.
- The canonical-identity key used to reconcile duplicate accounts into one person (e.g. a reliable org identifier).
- Whether any external security assurance (one-time pen test) is achievable given the solo build.

## Resolved Decisions

- **Organization:** Division of Occupational and Environmental Diseases.
- **Localization:** English-first in development; Thai translation handled by the owner later.
- **Security review:** solo / self-review (accepted, with the compensating controls above).
