# Story Dependency Graph
_Last updated: 2026-06-27T04:00:00Z_

## Stories

| Story | Epic | Title | Sprint Status | Issue | PR | PR Status | Dependencies | Ready to Work |
|-------|------|-------|--------------|-------|----|-----------|--------------|---------------|
| 1.1 | 1 | Docker Compose stack — pinned Keycloak + PostgreSQL | done | #2 | #43 | merged | none | ✅ Yes (done) |
| 1.2 | 1 | Realm config-as-code baseline & secret hygiene | done | #3 | #45 | merged | 1.1 | ✅ Yes (done) |
| 1.3 | 1 | Nginx security edge | done | #4 | #46 | merged | 1.1 | ✅ Yes (done) |
| 1.4 | 1 | Shared Deep Sea design-token stylesheet | done | #5 | #44 | merged | none | ✅ Yes (done) |
| 1.5 | 1 | Agentic-build / CI security gate | done | #6 | #47 | open | 1.2, 1.3, 1.4 | ✅ Yes (done) |
| 2.1 | 2 | Canonical identity model & lifecycle states | backlog | #7 | — | — | epic 1 complete | ❌ No (PR #47 not merged) |
| 2.2 | 2 | OIDC Authorization Code + PKCE login | backlog | #8 | — | — | epic 1 complete | ❌ No (PR #47 not merged) |
| 2.3 | 2 | Signed tokens, JWKS & OIDC discovery | backlog | #9 | — | — | epic 1 complete | ❌ No (PR #47 not merged) |
| 2.4 | 2 | SSO session, lifetimes & RP-initiated logout | backlog | #10 | — | — | epic 1 complete | ❌ No (PR #47 not merged) |
| 2.5 | 2 | Branded Deep Sea login theme | backlog | #11 | — | — | epic 1 complete, 1.4 | ❌ No (PR #47 not merged) |
| 2.6 | 2 | TOTP MFA enforcement & verification hardening | backlog | #12 | — | — | epic 1 complete, 2.2 | ❌ No (PR #47 not merged) |
| 2.7 | 2 | Brute-force protection & enumeration-resistant responses | backlog | #13 | — | — | epic 1 complete, 2.2 | ❌ No (PR #47 not merged) |
| 2.8 | 2 | Disable blocks authentication & revokes sessions | backlog | #14 | — | — | epic 1 complete, 2.2 | ❌ No (PR #47 not merged) |
| 2.9 | 2 | Login with ThaiD (brokered federation & account linking) | backlog | #15 | — | — | epic 1 complete, 2.2, 2.1 | ❌ No (PR #47 not merged) |
| 3.1 | 3 | Password policy & breach screening | backlog | #16 | — | — | epic 1 complete | ❌ No (epic 1 not complete) |
| 3.2 | 3 | Email delivery & link-token hygiene | backlog | #17 | — | — | epic 1 complete | ❌ No (epic 1 not complete) |
| 3.3 | 3 | First-login activation | backlog | #18 | — | — | epic 1+2 complete, 3.1, 3.2 | ❌ No (epics 1+2 not complete) |
| 3.4 | 3 | Self-service password reset | backlog | #19 | — | — | epic 1+2 complete, 3.1, 3.2 | ❌ No (epics 1+2 not complete) |
| 3.5 | 3 | MFA reset re-activation flow | backlog | #20 | — | — | epic 1+2 complete, 3.3, 3.4 | ❌ No (epics 1+2 not complete) |
| 4.1 | 4 | Admin app scaffold & gate activation | backlog | #21 | — | — | epic 1+2+3 complete | ❌ No (epics 1–3 not complete) |
| 4.2 | 4 | Admin OIDC sign-in & role-gated shell | backlog | #22 | — | — | epic 1+2+3 complete, 4.1 | ❌ No (epics 1–3 not complete) |
| 4.3 | 4 | Typed Keycloak Admin REST adapter & Valibot contracts | backlog | #23 | — | — | epic 1+2+3 complete, 4.1 | ❌ No (epics 1–3 not complete) |
| 4.4 | 4 | Create user & search/list | backlog | #24 | — | — | epic 1+2+3 complete, 4.2, 4.3 | ❌ No (epics 1–3 not complete) |
| 4.5 | 4 | User detail — enable/disable & profile edit | backlog | #25 | — | — | epic 1+2+3 complete, 4.4 | ❌ No (epics 1–3 not complete) |
| 4.6 | 4 | Front-line reset with attestation & step-up | backlog | #26 | — | — | epic 1+2+3 complete, 4.5 | ❌ No (epics 1–3 not complete) |
| 4.7 | 4 | CSV bulk import (validate → preview → confirm) | backlog | #27 | — | — | epic 1+2+3 complete, 4.3, 4.4 | ❌ No (epics 1–3 not complete) |
| 5.1 | 5 | Audit event capture pipeline | backlog | #28 | — | — | epic 1–4 complete | ❌ No (epics 1–4 not complete) |
| 5.2 | 5 | Off-host append-only audit sink, retention & out-of-band copy | backlog | #29 | — | — | epic 1–4 complete, 5.1 | ❌ No (epics 1–4 not complete) |
| 5.3 | 5 | Register & manage OIDC clients with secret rotation | backlog | #30 | — | — | epic 1–4 complete, 4.2, 4.3 | ❌ No (epics 1–4 not complete) |
| 5.4 | 5 | Manage admin users & roles (separation of duties) | backlog | #31 | — | — | epic 1–4 complete, 4.2 | ❌ No (epics 1–4 not complete) |
| 5.5 | 5 | Audit log view & export (itself audited) | backlog | #32 | — | — | epic 1–4 complete, 5.1, 5.2 | ❌ No (epics 1–4 not complete) |
| 6.1 | 6 | Minimal reference / sample OIDC client | backlog | #33 | — | — | epic 1–5 complete | ❌ No (epics 1–5 not complete) |
| 6.2 | 6 | OIDC integration guide — full contract & claim mapping | backlog | #34 | — | — | epic 1–5 complete | ❌ No (epics 1–5 not complete) |
| 6.3 | 6 | Pilot integration validation | backlog | #35 | — | — | epic 1–5 complete, 6.1, 6.2 | ❌ No (epics 1–5 not complete) |
| 7.1 | 7 | PDPA documentation — RoPA, lawful basis & data-subject rights | backlog | #36 | — | — | epic 1–5 complete | ❌ No (epics 1–5 not complete) |
| 7.2 | 7 | Tested 72-hour breach-response runbook & DPO sign-off | backlog | #37 | — | — | epic 1–5 complete, 7.1 | ❌ No (epics 1–5 not complete) |
| 7.3 | 7 | Tested backup/restore & key-loss/compromise runbook | backlog | #38 | — | — | epic 1–5 complete | ❌ No (epics 1–5 not complete) |
| 7.4 | 7 | Independent ASVS L2 review (pre-pilot gate) | backlog | #39 | — | — | epic 1–6 complete | ❌ No (epics 1–6 not complete) |
| 7.5 | 7 | Independent penetration test (pre-broad-rollout gate) | backlog | #40 | — | — | epic 1–6 complete, 7.4 | ❌ No (epics 1–6 not complete) |

## Dependency Chains

### Epic 1 (internal)
- **1.2** depends on: 1.1 (realm needs the stack running)
- **1.3** depends on: 1.1 (nginx security edge needs the stack)
- **1.5** depends on: 1.2, 1.3, 1.4 (CI gate needs all infra, theme, and config complete)

### Epic 2 (internal, after Epic 1 complete)
- **2.6** depends on: 2.2 (TOTP enforcement requires the auth flow)
- **2.7** depends on: 2.2 (brute-force sits on top of the auth flow)
- **2.8** depends on: 2.2 (disable/revoke requires active sessions to exist)
- **2.9** depends on: 2.1, 2.2 (ThaiD brokering links to canonical identity + auth flow)

### Epic 3 (internal, after Epics 1+2 complete)
- **3.3** depends on: 3.1, 3.2 (activation needs password policy + email infra)
- **3.4** depends on: 3.1, 3.2 (password reset needs policy + email infra)
- **3.5** depends on: 3.3, 3.4 (MFA re-activation is a variant of activation + reset)

### Epic 4 (internal, after Epics 1–3 complete)
- **4.2** depends on: 4.1 (OIDC sign-in needs the scaffold)
- **4.3** depends on: 4.1 (Keycloak adapter needs the scaffold)
- **4.4** depends on: 4.2, 4.3 (create/list users needs auth + adapter)
- **4.5** depends on: 4.4 (user detail requires user list)
- **4.6** depends on: 4.5 (reset actions appear in user detail)
- **4.7** depends on: 4.3, 4.4 (CSV import uses adapter + user creation)

### Epic 5 (internal, after Epics 1–4 complete)
- **5.1** depends on: (epic gate) (capture pipeline is the foundation)
- **5.2** depends on: 5.1 (off-host sink needs the capture pipeline)
- **5.3** depends on: 4.2, 4.3 (client mgmt needs admin shell + adapter)
- **5.4** depends on: 4.2 (admin users management needs admin shell)
- **5.5** depends on: 5.1, 5.2 (audit view needs capture + sink)

### Epic 6 (after Epics 1–5 complete)
- **6.3** depends on: 6.1, 6.2 (pilot validation needs both guide and sample client)

### Epic 7 (after Epics 1–6 complete for 7.4/7.5; after Epics 1–5 for 7.1–7.3)
- **7.2** depends on: 7.1 (breach runbook needs PDPA docs)
- **7.4** depends on: all epics 1–6 complete
- **7.5** depends on: 7.4 (pen test follows ASVS review)

## Notes

- **Stories 1.2 and 1.3 merged**: PR #45 (story-1-2, 2026-06-26T15:04Z) and PR #46 (story-1-3, 2026-06-26T15:01Z) are both merged into main.
- **Story 1.5 done (code review passed 2026-06-27)**: Sprint status is `done`; PR #47 is still open (not yet merged into main). Worktree `.worktrees/story-1-5-agentic-build-ci-security-gate` still active — do NOT remove until PR merges.
- **Epic 1 completion gate**: All stories are done, but PR #47 must be merged into main before Epic 2 stories unlock. Once PR #47 merges, Epic 2 stories 2.1–2.5 (no intra-epic deps) become immediately ready.
- **Worktree cleanup**: story-1-2 and story-1-3 worktrees removed; remote branches deleted (2026-06-26).
- **Completed stories (merged PRs)**: 1.1 (PR #43), 1.2 (PR #45), 1.3 (PR #46), 1.4 (PR #44) — all merged into main.
- **Done but PR open**: 1.5 (PR #47) — code done, awaiting merge.
- **Current epic**: Epic 1 — Secure Platform Foundation (lowest epic with non-merged-to-main PR).
- **All stories done**: false.
