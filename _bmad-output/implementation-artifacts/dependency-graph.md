# Story Dependency Graph
_Last updated: 2026-07-01T15:05:00Z_

## Stories

| Story | Epic | Title | Sprint Status | Issue | PR | PR Status | Dependencies | Ready to Work |
|-------|------|-------|--------------|-------|----|-----------|--------------|---------------|
| 1.1 | 1 | Docker Compose stack — pinned Keycloak + PostgreSQL | done | #2 | #43 | merged | none | ✅ Yes (done) |
| 1.2 | 1 | Realm config-as-code baseline & secret hygiene | done | #3 | #45 | merged | 1.1 | ✅ Yes (done) |
| 1.3 | 1 | Nginx security edge | done | #4 | #46 | merged | 1.1 | ✅ Yes (done) |
| 1.4 | 1 | Shared Deep Sea design-token stylesheet | done | #5 | #44 | merged | none | ✅ Yes (done) |
| 1.5 | 1 | Agentic-build / CI security gate | done | #6 | #47 | merged | 1.2, 1.3, 1.4 | ✅ Yes (done) |
| 2.1 | 2 | Canonical identity model & lifecycle states | done | #7 | #48 | merged | epic 1 complete | ✅ Yes (done) |
| 2.2 | 2 | OIDC Authorization Code + PKCE login | done | #8 | #51 | merged | epic 1 complete | ✅ Yes (done) |
| 2.3 | 2 | Signed tokens, JWKS & OIDC discovery | done | #9 | #50 | merged | epic 1 complete | ✅ Yes (done) |
| 2.4 | 2 | SSO session, lifetimes & RP-initiated logout | done | #10 | #49 | merged | epic 1 complete | ✅ Yes (done) |
| 2.5 | 2 | Branded Deep Sea login theme | done | #11 | #52 | merged | epic 1 complete, 1.4 | ✅ Yes (done) |
| 2.6 | 2 | TOTP MFA enforcement & verification hardening | atdd-done | #12 | — | — | epic 1 complete, 2.2 | ✅ Yes |
| 2.7 | 2 | Brute-force protection & enumeration-resistant responses | atdd-done | #13 | — | — | epic 1 complete, 2.2 | ✅ Yes |
| 2.8 | 2 | Disable blocks authentication & revokes sessions | ready-for-dev | #14 | — | — | epic 1 complete, 2.2 | ✅ Yes |
| 2.9 | 2 | Login with ThaiD (brokered federation & account linking) | backlog | #15 | — | — | epic 1 complete, 2.2, 2.1 | ✅ Yes |
| 3.1 | 3 | Password policy & breach screening | backlog | #16 | — | — | epic 1+2 complete | ❌ No (epic 2 not complete) |
| 3.2 | 3 | Email delivery & link-token hygiene | backlog | #17 | — | — | epic 1+2 complete | ❌ No (epic 2 not complete) |
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

- **Epic 1 fully complete and merged**: All 5 stories done, all PRs merged. PR #47 (story-1-5) merged 2026-06-26T23:55Z.
- **Worktree cleanup**: story-1-2, story-1-3, and story-1-5 worktrees removed; remote branches deleted.
- **Completed stories (merged PRs)**: 1.1 (PR #43), 1.2 (PR #45), 1.3 (PR #46), 1.4 (PR #44), 1.5 (PR #47) — all merged into main.
- **Epic 2 batch-1 merged 2026-06-27**: Stories 2.1 (PR #48), 2.2 (PR #51), 2.3 (PR #50), 2.4 (PR #49), 2.5 (PR #52) all merged. PR number correction: sprint-status.yaml had 2.2/2.4 swapped — corrected to #51 and #49 respectively (verified from GitHub).
- **Epic 2 second batch now unlocked**: Stories 2.6, 2.7, 2.8 all depend only on epic 1 complete + 2.2 merged → now ready. Story 2.9 depends on 2.1 + 2.2 merged → now ready. All four (2.6, 2.7, 2.8, 2.9) are Ready to Work in parallel.
- **Parallelization opportunity**: Stories 2.6, 2.7, 2.8, and 2.9 can all be started in parallel — 2.6/2.7/2.8 depend only on 2.2 (merged), 2.9 depends on 2.1+2.2 (both merged).
- **Batch-2 in progress (2026-07-01)**: Worktrees active for story-2.6 (atdd-done, red-phase ATDD scaffolds committed), story-2.7 (atdd-done, red-phase ATDD scaffolds committed), and story-2.8 (ready-for-dev, story file created). No PRs opened yet for any of the four batch-2 stories (2.6, 2.7, 2.8, 2.9) — `gh pr list` confirms none exist. Story 2.9 has no worktree yet.
- **Current epic**: Epic 2 — Staff Authentication & SSO Identity (second batch).
- **All stories done**: false.
