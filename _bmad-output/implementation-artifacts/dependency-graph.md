# Story Dependency Graph
_Last updated: 2026-06-23T14:00:00Z_

## Stories

| Story | Epic | Title | Sprint Status | Issue | PR | PR Status | Dependencies | Ready to Work |
|-------|------|-------|--------------|-------|----|-----------|--------------|---------------|
| 1.1   | 1    | Docker Compose stack — pinned Keycloak + PostgreSQL | done | #2 | #1 | merged | none | ✅ Yes (done) |
| 1.2   | 1    | Realm config-as-code baseline & secret hygiene | done | #3 | #1 | merged | 1.1 | ✅ Yes (done) |
| 1.3   | 1    | Nginx security edge | backlog | #4 | — | — | 1.1, 1.2 | ✅ Yes |
| 1.4   | 1    | Shared Deep Sea design-token stylesheet | backlog | #5 | — | — | 1.1, 1.2 | ✅ Yes |
| 1.5   | 1    | Agentic-build / CI security gate | backlog | #6 | — | — | 1.1, 1.2 | ✅ Yes |
| 2.1   | 2    | Canonical identity model & lifecycle states | backlog | #7 | — | — | epic 1 | ❌ No (epic 1 not complete: 1.3, 1.4, 1.5 not merged) |
| 2.2   | 2    | OIDC Authorization Code + PKCE login | backlog | #8 | — | — | epic 1, 2.1 | ❌ No (epic 1 not complete) |
| 2.3   | 2    | Signed tokens, JWKS & OIDC discovery | backlog | #9 | — | — | epic 1, 2.2 | ❌ No (epic 1 not complete) |
| 2.4   | 2    | SSO session, lifetimes & RP-initiated logout | backlog | #10 | — | — | epic 1, 2.2, 2.3 | ❌ No (epic 1 not complete) |
| 2.5   | 2    | Branded Deep Sea login theme | backlog | #11 | — | — | epic 1, 1.4 | ❌ No (epic 1 not complete) |
| 2.6   | 2    | TOTP MFA enforcement & verification hardening | backlog | #12 | — | — | epic 1, 2.2 | ❌ No (epic 1 not complete) |
| 2.7   | 2    | Brute-force protection & enumeration-resistant responses | backlog | #13 | — | — | epic 1, 2.2 | ❌ No (epic 1 not complete) |
| 2.8   | 2    | Disable blocks authentication & revokes sessions | backlog | #14 | — | — | epic 1, 2.2 | ❌ No (epic 1 not complete) |
| 2.9   | 2    | Login with ThaiD (brokered federation & account linking) | backlog | #15 | — | — | epic 1, 2.1, 2.2 | ❌ No (epic 1 not complete) |
| 3.1   | 3    | Password policy & breach screening | backlog | #16 | — | — | epic 1, epic 2 | ❌ No (epic 1 not complete) |
| 3.2   | 3    | Email delivery & link-token hygiene | backlog | #17 | — | — | epic 1, epic 2 | ❌ No (epic 1 not complete) |
| 3.3   | 3    | First-login activation | backlog | #18 | — | — | epic 1, epic 2, 3.1, 3.2 | ❌ No (epic 1 not complete) |
| 3.4   | 3    | Self-service password reset | backlog | #19 | — | — | epic 1, epic 2, 3.1, 3.2 | ❌ No (epic 1 not complete) |
| 3.5   | 3    | MFA reset re-activation flow | backlog | #20 | — | — | epic 1, epic 2, epic 3 partial, 3.2, 3.3 | ❌ No (epic 1 not complete) |
| 4.1   | 4    | Admin app scaffold & gate activation | backlog | #21 | — | — | epic 1 | ❌ No (epic 1 not complete) |
| 4.2   | 4    | Admin OIDC sign-in & role-gated shell | backlog | #22 | — | — | epic 1, epic 2, 4.1 | ❌ No (epic 1 not complete) |
| 4.3   | 4    | Typed Keycloak Admin REST adapter & Valibot contracts | backlog | #23 | — | — | epic 1, 4.1, 4.2 | ❌ No (epic 1 not complete) |
| 4.4   | 4    | Create user & search/list | backlog | #24 | — | — | epic 1, epic 2, epic 3, 4.1, 4.2, 4.3 | ❌ No (epic 1 not complete) |
| 4.5   | 4    | User detail — enable/disable & profile edit | backlog | #25 | — | — | epic 1, epic 2, 4.1, 4.2, 4.3, 4.4 | ❌ No (epic 1 not complete) |
| 4.6   | 4    | Front-line reset (password + MFA) with attestation & step-up | backlog | #26 | — | — | epic 1, epic 2, epic 3, 4.1, 4.2, 4.3 | ❌ No (epic 1 not complete) |
| 4.7   | 4    | CSV bulk import (validate → preview → confirm) | backlog | #27 | — | — | epic 1, epic 2, epic 3, 4.1, 4.2, 4.3 | ❌ No (epic 1 not complete) |
| 5.1   | 5    | Audit event capture pipeline | backlog | #28 | — | — | epic 1, epic 2, epic 4, 4.1, 4.2 | ❌ No (epic 1 not complete) |
| 5.2   | 5    | Off-host append-only audit sink, retention & out-of-band copy | backlog | #29 | — | — | epic 1, epic 2, 5.1 | ❌ No (epic 1 not complete) |
| 5.3   | 5    | Register & manage OIDC clients with secret rotation | backlog | #30 | — | — | epic 1, epic 2, epic 4, 4.1, 4.2, 4.3 | ❌ No (epic 1 not complete) |
| 5.4   | 5    | Manage admin users & roles (separation of duties) | backlog | #31 | — | — | epic 1, epic 2, epic 4, 4.1, 4.2, 4.3 | ❌ No (epic 1 not complete) |
| 5.5   | 5    | Audit log view & export (itself audited) | backlog | #32 | — | — | epic 1, epic 2, epic 4, 5.1 | ❌ No (epic 1 not complete) |
| 6.1   | 6    | Minimal reference / sample OIDC client | backlog | #33 | — | — | epic 1, epic 2, epic 5 | ❌ No (epic 1 not complete) |
| 6.2   | 6    | OIDC integration guide — full contract & claim mapping | backlog | #34 | — | — | epic 1, epic 2, epic 5, 6.1 | ❌ No (epic 1 not complete) |
| 6.3   | 6    | Pilot integration validation | backlog | #35 | — | — | epic 1, epic 2, epic 5, 6.1, 6.2 | ❌ No (epic 1 not complete) |
| 7.1   | 7    | PDPA documentation — RoPA, lawful basis & data-subject rights | backlog | #36 | — | — | epic 1, epic 2, epic 3, epic 4, epic 5 | ❌ No (epic 1 not complete) |
| 7.2   | 7    | Tested 72-hour breach-response runbook & DPO sign-off | backlog | #37 | — | — | epic 1, epic 5, 7.1 | ❌ No (epic 1 not complete) |
| 7.3   | 7    | Tested backup/restore & key-loss/compromise runbook | backlog | #38 | — | — | epic 1, epic 2 | ❌ No (epic 1 not complete) |
| 7.4   | 7    | Independent ASVS L2 review (pre-pilot gate) | backlog | #39 | — | — | epic 1, epic 2, epic 3, epic 4, epic 5 | ❌ No (epic 1 not complete) |
| 7.5   | 7    | Independent penetration test (pre-broad-rollout gate) | backlog | #40 | — | — | epic 1, epic 2, epic 3, epic 4, epic 5, epic 6, 7.4 | ❌ No (epic 1 not complete) |

## Dependency Chains

- **1.2** depends on: 1.1
- **1.3** depends on: 1.1, 1.2
- **1.4** depends on: 1.1, 1.2
- **1.5** depends on: 1.1, 1.2
- **2.1** depends on: epic 1 complete
- **2.2** depends on: epic 1 complete, 2.1
- **2.3** depends on: epic 1 complete, 2.2
- **2.4** depends on: epic 1 complete, 2.2, 2.3
- **2.5** depends on: epic 1 complete, 1.4
- **2.6** depends on: epic 1 complete, 2.2
- **2.7** depends on: epic 1 complete, 2.2
- **2.8** depends on: epic 1 complete, 2.2
- **2.9** depends on: epic 1 complete, 2.1, 2.2
- **3.1** depends on: epic 1 complete, epic 2 complete
- **3.2** depends on: epic 1 complete, epic 2 complete
- **3.3** depends on: epic 1 complete, epic 2 complete, 3.1, 3.2
- **3.4** depends on: epic 1 complete, epic 2 complete, 3.1, 3.2
- **3.5** depends on: epic 1 complete, epic 2 complete, 3.2, 3.3
- **4.1** depends on: epic 1 complete
- **4.2** depends on: epic 1 complete, epic 2 complete, 4.1
- **4.3** depends on: epic 1 complete, 4.1, 4.2
- **4.4** depends on: epic 1 complete, epic 2 complete, epic 3 complete, 4.1, 4.2, 4.3
- **4.5** depends on: epic 1 complete, epic 2 complete, 4.1, 4.2, 4.3, 4.4
- **4.6** depends on: epic 1 complete, epic 2 complete, epic 3 complete, 4.1, 4.2, 4.3
- **4.7** depends on: epic 1 complete, epic 2 complete, epic 3 complete, 4.1, 4.2, 4.3
- **5.1** depends on: epic 1 complete, epic 2 complete, 4.1, 4.2
- **5.2** depends on: epic 1 complete, epic 2 complete, 5.1
- **5.3** depends on: epic 1 complete, epic 2 complete, 4.1, 4.2, 4.3
- **5.4** depends on: epic 1 complete, epic 2 complete, 4.1, 4.2, 4.3
- **5.5** depends on: epic 1 complete, epic 2 complete, 4.1, 5.1
- **6.1** depends on: epic 1 complete, epic 2 complete, epic 5 complete
- **6.2** depends on: epic 1 complete, epic 2 complete, epic 5 complete, 6.1
- **6.3** depends on: epic 1 complete, epic 2 complete, epic 5 complete, 6.1, 6.2
- **7.1** depends on: epic 1 complete, epic 2 complete, epic 3 complete, epic 4 complete, epic 5 complete
- **7.2** depends on: epic 1 complete, epic 5 complete, 7.1
- **7.3** depends on: epic 1 complete, epic 2 complete
- **7.4** depends on: epic 1 complete, epic 2 complete, epic 3 complete, epic 4 complete, epic 5 complete
- **7.5** depends on: epic 1 complete, epic 2 complete, epic 3 complete, epic 4 complete, epic 5 complete, epic 6 complete, 7.4

## Notes

**Current state:** Epic 1 is in-progress. Stories 1.1 and 1.2 are done (merged together in PR #1). Stories 1.3, 1.4, and 1.5 are ready to work in parallel — all can be started now since they only depend on 1.1+1.2 being merged.

**Parallelization opportunities:**
- 1.3 (Nginx edge), 1.4 (Design tokens), and 1.5 (CI gate) can all be built in parallel right now.
- Once all of Epic 1 is merged, Epic 2 stories 2.1–2.9 can begin. Within Epic 2: 2.1 is a prerequisite for most; 2.3, 2.6, 2.7, 2.8, 2.9 can proceed in parallel after 2.1+2.2 are done.
- 4.1 (Admin scaffold) depends only on Epic 1 and can start as soon as Epic 1 is complete, in parallel with Epic 2.
- Epic 3 (3.1, 3.2) can be parallelized after Epic 2 is complete.

**Bottlenecks:**
- Epic 1 must be fully merged before any Epic 2+ stories begin.
- Epic 2 is a hard prerequisite for Epics 3, 4 (except 4.1), 5 (except parts), 6, and 7.
- Stories 7.4 (ASVS review) and 7.5 (pen test) are the final gates — they block go-live.

**Note on PR #1:** The merged PR covers both Story 1.1 (Docker Compose stack) and Story 1.2 (Realm config/secret hygiene) — these were implemented together and both are marked `done`. The PR used "Story 1-1" (dash) notation rather than dot notation.
