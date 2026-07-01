# EnvOcc Identity Model — Lifecycle States Reference

**Story:** 2.1 — Canonical identity model & lifecycle states
**Epic:** 2 — Staff Authentication & SSO Identity
**Requirements:** FR21, FR22, FR23, FR24

---

## Overview

Every staff member maps to exactly **one** canonical Keycloak identity in the `envocc` realm. This document defines how that identity is modelled — its stable subject, reconciliation key, minimal attribute set, and lifecycle state machine.

---

## 1. Stable Subject — UUID (`sub` claim)

The Keycloak user `id` field is a UUID assigned at creation. It is the **permanent anchor** for that identity:

- Mapped directly to the `sub` claim in all issued OIDC tokens.
- Used as the primary key in Keycloak's database — never reassigned, never recycled.
- Stable for the entire lifetime of the identity record, even across password changes, email updates, or realm configuration changes.

> **No configuration required.** UUID stability is a built-in Keycloak invariant (FR21). The `sub`+`email` pair is the identity contract used by integrating apps: `sub` is the stable anchor; `email` is the human-readable reconciliation key.

---

## 2. Work-Email Reconciliation Key

Two realm settings enforce the email-as-reconciliation-key contract (FR22):

| Setting | Value | Effect |
|---|---|---|
| `loginWithEmailAllowed` | `true` | Email is the login identifier; maps to the `email` OIDC claim |
| `duplicateEmailsAllowed` | `false` | Realm enforces email uniqueness at the DB level; Admin REST returns HTTP 409 on duplicate |

The `email` scope is a built-in Keycloak default scope — no additional mapper configuration is required. The `email` claim is included in all tokens when the `email` scope is in the client's default scopes.

---

## 3. Minimal Attribute Set — Data Minimization (FR23)

Keycloak 26 uses **Declarative User Profile** (enabled by default since KC 23; cannot be disabled in KC 25+). The user profile configuration restricts which attributes can be stored.

### Allowed attributes (only these four)

| Attribute | Type | Required | Notes |
|---|---|---|---|
| `username` | string | yes | System-managed login identifier (email used for login) |
| `email` | string | yes | Work email; unique across realm; reconciliation key |
| `firstName` | string | optional | Display name — first |
| `lastName` | string | optional | Display name — last |

### Forbidden attributes — PDPA §26 sensitive data

The following fields **must never** appear in the user `attributes` map or any field visible via the standard user endpoint:

- National ID / citizen ID / PID (`nationalId`, `pid`, `citizenId`)
- Date of birth (`dateOfBirth`)
- Gender, ethnicity, religion (`gender`, `ethnicity`, `religion`)
- Health status / health information (`healthInfo`)
- Biometric data (`biometric`)
- Criminal record (`criminalRecord`)
- Political opinion (`politicalOpinion`)
- Sexual orientation (`sexualOrientation`)
- Trade union membership (`tradeUnion`)
- Genetic data (`geneticData`)

> **PID / ThaiD:** National ID (PID) for the ThaiD federated identity is stored **only** in the Keycloak identity broker link — a separate subsystem, not in user `attributes`. See Decision 2 in `_bmad-output/planning-artifacts/architecture.md`.

### Admin REST API bypass caveat

In KC 26, the Admin REST API can bypass Declarative User Profile restrictions when an admin explicitly sets attributes on a user object (admin bypass is by design — admins have full control). The user-profile configuration enforces restrictions on **user-initiated** attribute writes and on the **standard creation flow**.

The integration test TS-210c/TS-210e validates the **clean-creation invariant**: a standard `POST /admin/realms/envocc/users` request with only the four allowed fields produces a user record with no PDPA §26 sensitive attributes. This is the boundary enforced by this story.

---

## 4. Lifecycle State Machine (FR24)

An identity moves through exactly three states via controlled transitions:

```
  [CREATE]
     ↓
  pending ──────────────────────────────────────────→ (never → active directly
     ↓ (Story 3.3: activation email completed)          without email verification)
   active
     ↓ (Story 2.8: HR Admin disables)
  disabled
```

### State definitions

| State | `enabled` | `emailVerified` | Auth allowed | Description |
|---|---|---|---|---|
| `pending` | `true` | `false` | **No** | User created by HR Admin (Epic 4). Activation email not yet completed (Story 3.3). Keycloak enforces `VERIFY_EMAIL` required action — login redirects to verification page and returns HTTP 400 from the token endpoint. |
| `active` | `true` | `true` | **Yes** | User completed email activation. Can authenticate via the login flow (Story 2.2). |
| `disabled` | `false` | any | **No** | User disabled by HR Admin (Story 2.8). Keycloak immediately rejects all authentication attempts and revokes active sessions/tokens. |

> **Note:** There is no direct `pending → disabled` transition. A user must always be activated before being disabled. There is no dedicated "un-disable" endpoint distinct from the disable endpoint — re-enabling uses the same `PUT /users/{id}` call with `{"enabled": true}`. This is a deliberate symmetry, not an irreversible state: a disabled account CAN be re-enabled by a future HR Admin action (Story 4.5 scope). Story 2.8's `[P1][TS-280d]` integration test proves this re-enable path.

---

## 5. Admin REST API Transitions

All transitions are driven by Keycloak's Admin REST API. An admin token from `get_admin_token` is required for all calls.

**Base path:** `http://localhost:8080/admin/realms/envocc`

### Create → pending

```http
POST /users
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "username": "jdoe@envocc.local",
  "email": "jdoe@envocc.local",
  "enabled": true,
  "emailVerified": false,
  "requiredActions": ["VERIFY_EMAIL"],
  "firstName": "John",
  "lastName": "Doe"
}
```

Response: `201 Created` with `Location: /admin/realms/envocc/users/{uuid}` header.

### pending → active

Driven by the Story 3.3 activation flow after the user clicks the email verification link:

```http
PUT /users/{id}
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "emailVerified": true,
  "requiredActions": []
}
```

Response: `204 No Content`.

### active → disabled

Driven by the Story 2.8 HR Admin disable action:

```http
PUT /users/{id}
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "enabled": false
}
```

Response: `204 No Content`. This call alone blocks all **new** authentication
(FR25) but does **NOT** by itself invalidate already-issued tokens or already-active
sessions. **A second call is required** to satisfy FR46 (session/refresh-token
revocation): `POST /users/{id}/logout`. See `keycloak/REALM-EXPORT-NOTES.md`
Section "Story 2.8 — Disable Blocks Authentication & Revokes Sessions" for the full
two-call procedure, response codes, and the integration tests
(`tests/integration/account-disable.bats`, TS-280a–TS-280h) that prove both halves.

---

## 6. Subject Claim (`sub`) in OIDC Tokens

The `sub` claim in all OIDC tokens issued by the `envocc` realm equals the Keycloak user `id` (UUID):

```json
{
  "sub": "550e8400-e29b-41d4-a716-446655440000",
  "email": "jdoe@envocc.local",
  ...
}
```

Keycloak **never reuses** a UUID, even after user deletion. If a user is deleted and a new account is created with the same email, the new account receives a **different** UUID. This is verified by integration test TS-210a.

---

## 7. Test-Only ROPC Client

The `test-ropc-client` in the realm is used **exclusively** for integration tests (specifically TS-210d — verifying that a `pending` user cannot authenticate via ROPC).

| Property | Value |
|---|---|
| Client ID | `test-ropc-client` |
| Grant type | Direct Access Grants (ROPC) only |
| Standard flow | Disabled |
| Secret | Populated from `KC_TEST_ROPC_CLIENT_SECRET` in `.env` |
| Production use | **FORBIDDEN — remove before production deployment** |

See `keycloak/REALM-EXPORT-NOTES.md` for the warning and export procedure.

---

## References

- [FR21–FR25] `_bmad-output/planning-artifacts/epics.md#FG-3 — Identity & User Store`
- [Decision 1] Keycloak 26.6.3 as IdP engine — `_bmad-output/planning-artifacts/architecture.md`
- [Decision 2] PID stored in broker link, not user attributes — `_bmad-output/planning-artifacts/architecture.md`
- [Decision 3] `duplicateEmailsAllowed: false`, `loginWithEmailAllowed: true` — `_bmad-output/planning-artifacts/architecture.md`
- [Test scenarios] TS-210a–TS-210e — `_bmad-output/test-artifacts/test-design/test-design-epic-2.md`
- [Integration tests] `tests/integration/identity-model.bats`
- [Export procedure] `keycloak/REALM-EXPORT-NOTES.md`
