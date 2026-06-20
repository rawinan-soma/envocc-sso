---
title: "Product Brief: envocc-sso"
status: final
created: 2026-06-19
updated: 2026-06-19
---

# Product Brief: envocc-sso

## Executive Summary

**envocc-sso** is a custom, in-house **OpenID Connect (OIDC) Identity Provider (IdP)** for the **Division of Occupational and Environmental Diseases** — built frontend and backend from the ground up rather than deployed from an off-the-shelf product like Keycloak or Authentik. It exists to solve a concrete organizational problem: today, ~100–150 staff each maintain separate accounts across 10–15 internal applications, and there is **no central record of who works here**. envocc-sso becomes that missing source of truth — one identity, one login, one place to grant and revoke access.

The system has two halves. For **staff**, a single branded login (with multi-factor authentication and self-service password reset) replaces a drawer full of separate app credentials. For **HR administrators**, an admin console replaces the impossible task of tracking accounts scattered across a dozen systems — they provision people once, and disable them when they leave.

Building this in-house is an organizational mandate, not a convenience choice. That mandate is accepted with eyes open: a custom IdP is security-critical infrastructure, so this brief scopes v1 deliberately tight (authentication only), phases the rollout to prove safety before scale, and treats security rigor — not feature count — as the definition of done. There is no fixed deadline; readiness is the deadline.

## The Problem

EnvOcc runs 10–15 internal applications, each with its own login and its own user table. The same ~100–150 people appear again and again across these systems — Somchai in the lab system, Somchai in the reporting tool, Somchai in the document archive — as a dozen disconnected accounts that no one system can see as one person.

This creates real, daily costs:

- **For staff:** a different username and password for every app. Forgotten passwords, reused passwords, sticky notes — the usual insecure coping mechanisms.
- **For administrators:** no way to answer "what can this person access?" or "is everyone who left actually locked out?" Onboarding means creating accounts in many places; offboarding means *remembering* to remove them from many places — and missed offboarding is a live security hole.
- **For the organization:** there is no central identity record at all. Access lives implicitly inside each app's database. There is no single point to enforce a password policy, require MFA, or audit who can get in.

The status quo isn't just inconvenient — for an organization handling occupational and environmental health data, scattered and un-revoked access is a genuine security and governance liability.

## The Solution

A purpose-built OIDC Identity Provider that becomes EnvOcc's first central identity system. Apps redirect users to envocc-sso to log in; envocc-sso authenticates them and issues a standard OIDC token the app trusts. One identity, reused everywhere.

Core capabilities for the first version:

- **Single sign-on via OIDC** (standard Authorization Code flow) so internal apps can adopt it with off-the-shelf OIDC client libraries.
- **Custom, branded login experience** — fully owned frontend, matching EnvOcc's identity.
- **Multi-factor authentication (MFA)** from day one (e.g. TOTP authenticator app).
- **Self-service password reset** via email, so 150 users don't funnel reset requests through admins.
- **Admin console for HR administrators** — provision accounts, assign access, and disable leavers from one place. This is a first-class half of the product, not an afterthought.
- **First-login account activation** — since legacy app passwords can't be migrated, admins create accounts and each user sets their own password on first sign-in via an emailed activation link.
- **Integration documentation** so each app's owner can wire their app to envocc-sso themselves.

The interface is built **English-first** during development, designed for localization; Thai (the target locale) is translated separately by the owner after the UI stabilizes.

## Scope

**In scope (v1):**
- OIDC Identity Provider (authentication + token issuance)
- Central user store — envocc-sso is the system of record for identity
- Branded login UI + MFA (TOTP) + self-service password reset
- Admin console: user provisioning, enable/disable, password reset, basic account management for HR admins
- Activation/first-login password-set flow (email-based)
- Account reconciliation: collapsing each person's scattered per-app accounts into one canonical identity
- OIDC integration guide for app owners
- Pilot integration with the first 1–2 apps

**Out of scope (v1) — explicitly deferred:**
- **Centralized authorization** — roles, groups, and permissions stay inside each app for now. envocc-sso answers *who you are*, not *what you may do*. (Strong candidate for a later phase.)
- Wiring OIDC into all 10–15 apps — each app's owner does their own integration; this project delivers the IdP and the guide.
- External / public / partner users — internal staff only.
- Social login, federation with external IdPs, SCIM provisioning, passwordless/WebAuthn — future vision, not v1.

## Who This Serves

- **Staff (~100–150 employees)** — primary, non-technical end users. Success = one login, no password sprawl, quick self-service recovery.
- **HR administrators** — operate the admin console; own the joiner/mover/leaver lifecycle. Success = provision and de-provision a person in one place, with confidence it takes effect everywhere.
- **App owners** — integrate their apps as OIDC clients. Success = a clear guide and a stable IdP they can trust and adopt without deep auth expertise.

## What Makes This Different

This is **not** a market-differentiation play — Keycloak and Authentik do this well, and a custom theme on Keycloak could deliver the branded login alone. The justification for building it is **fit and mandate, not a technical moat**:

- **In-house mandate** — the organization requires the code to be owned and run internally; that requirement is the load-bearing reason and is taken as given.
- **Full ownership** — complete control of the codebase, data, and user experience, with no third-party software in the trust path.
- **Right-sized** — purpose-built for one organization's exact needs (auth-only, ~150 users), without the surface area of a general-purpose platform.

This brief deliberately records that an off-the-shelf option exists, so the decision is documented and honest.

## Risk Accepted & Mitigation

A custom IdP is among the most security-sensitive systems one can build: it guards every other app, stores credentials as the system of record, and is being built **solo**. The in-house mandate manages this risk rather than removing it. Accepted risk, with mitigations:

- **Tight v1 surface** — authentication only; no authorization logic to get wrong.
- **No fixed deadline** — readiness, not a date, gates release; time to do it carefully and get review.
- **Phased rollout** — prove the IdP in production with 1–2 apps before the rest depend on it.
- **Stand on vetted foundations** — use established, audited OIDC and cryptography libraries; do not hand-roll crypto or token logic. (Detailed choices belong to the architecture phase.)
- **MFA from v1** — limits damage from any single credential compromise.

**Residual risk — no independent security review.** Review is solo (self-review), which is *not* independent assurance for security-critical auth: blind spots stay blind. This is an explicitly accepted limitation. Compensating controls to lean on instead:
- Build only on audited OIDC/crypto libraries; treat any custom security code as a red flag.
- Automated tooling in the pipeline — dependency/vulnerability scanning and SAST.
- Work against a published checklist — OWASP ASVS and the OIDC/OAuth security best-practice guidance — rather than ad-hoc judgment.
- Consider a one-time external penetration test before broad rollout, if budget ever allows.

## Success Criteria

*(Proposed — confirm or adjust.)*
- The pilot apps authenticate staff exclusively through envocc-sso, with zero separate logins for those apps.
- A staff member can log in once and reach every integrated app without re-authenticating.
- HR admins can fully onboard a new hire and fully disable a leaver from the admin console alone.
- MFA is enforced and self-service password reset works end-to-end via email.
- No security defect in the token-handling, session, or credential-storage class is outstanding when an app goes live.

## Vision

If v1 proves out, envocc-sso becomes EnvOcc's identity backbone: all 10–15 apps behind one secure login within the following year, then a natural progression into **centralized authorization** (roles and groups managed once, read by every app), audit logging, and — further out — federation or passwordless sign-in. The end state is that identity and access for the whole organization are managed in one trustworthy place that EnvOcc fully owns.

## Open Questions (for PRD / Architecture)

- Any regulatory/compliance regime that applies to a Thai public-health division's identity data (e.g. PDPA)?
- Which specific apps are the pilot, and what are their stacks?
- Build stack — frontend, backend, database (deferred to architecture).
- The canonical-identity key used to reconcile duplicate accounts into one person (e.g. a reliable org identifier).
- Whether any external security assurance (one-time pen test) is achievable given the solo build.

## Resolved Decisions

- **Organization:** Division of Occupational and Environmental Diseases.
- **Localization:** English-first in development; Thai translation handled by the owner later.
- **Security review:** solo / self-review (accepted, with the compensating controls in *Risk Accepted & Mitigation*).
