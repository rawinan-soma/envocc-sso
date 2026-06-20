# Realm Export Notes — `envocc` Realm

## What This File Is

`realm-export.json` is the **secrets-stripped** baseline realm configuration for the `envocc` Keycloak realm. It is committed to version control and imported automatically on `docker compose up`.

## Secrets & Key Material — Stripped / Omitted Before Commit

No private keys, certificates, or signing secrets are committed. Two approaches are used:

| Field | Location in JSON | Action |
|-------|------------------|--------|
| `org.keycloak.keys.KeyProvider` | `components` | **Component group OMITTED entirely.** Keycloak auto-generates fresh `rsa-generated`, `rsa-enc-generated`, `hmac-generated`, and `aes-generated` keys on first import. (Committing the providers with blanked `privateKey:[""]` made `--import-realm` fail with `InvalidKeySpecException: Unable to decode the private key` — Keycloak tries to *decode* the empty key. Omitting the group is the correct pattern.) |
| `clientSecret` / `secret` | `clients[*].secret` | Set to `""` on every built-in client. Keycloak regenerates them. |
| `secretData` | User credential representations | Not present (no users exported) |
| `credentialData` | User credential representations | Not present (no users exported) |

### Import-incompatibility fields removed

The following were removed because Keycloak 26.2.5's `--import-realm` rejects them (the import is strict about `RealmRepresentation`):

| Field | Why removed |
|-------|-------------|
| `identityFederations` | Not a valid `RealmRepresentation` field (the correct field is `identityProviders`, present and empty). |
| `userProfile` (top-level) | Not importable as a top-level key in KC 26. The default declarative user profile is already exactly the minimal set we want (`username`, `email`, `firstName`, `lastName`); `attributes.userProfileEnabled=true` keeps it on. No PDPA-sensitive fields are added. |
| `enabledEventTypes: []` | An empty array means "save NO event types". Removing the field makes Keycloak save **all** event types (the day-one capture requirement). Verified via `GET /admin/realms/envocc/events/config` — all types (`LOGIN`, `LOGIN_ERROR`, ...) are enabled. |
| `ClientRegistrationPolicy` components | Used the invalid provider id `allowed-protocol-mapper-types` (correct id: `allowed-protocol-mappers`), causing `No such provider`. These are default policies Keycloak recreates automatically. |

## How Secrets Are Re-Injected at Runtime

1. **Realm signing/encryption keys**: Keycloak **auto-generates** new keys on first import because the `KeyProvider` components are omitted from the export.

2. **Client secrets** (e.g., `account` client): Built-in clients have blank secrets in the export; Keycloak regenerates them. For the Rails OIDC client (added in Story 3.1), the secret will be injected via environment variable using Keycloak's Admin REST API at container startup.

3. **Admin password**: Set via `KC_BOOTSTRAP_ADMIN_PASSWORD` (mapped from `KEYCLOAK_ADMIN_PASSWORD` in `.env`, never committed) — Keycloak 26 renamed `KEYCLOAK_ADMIN_PASSWORD` to `KC_BOOTSTRAP_ADMIN_PASSWORD`.

## Updating the Realm Export

When you change realm settings through the Admin UI, re-export and strip secrets before committing:

```bash
# 1. Export via Admin UI: Realm Settings → Action → Partial Export
#    (include clients, groups, roles; EXCLUDE secrets)
# 2. Save as keycloak/realm-export.json (overwrite)
# 3. Strip any remaining secrets (double-check the fields in the table above)
# 4. Verify with gitleaks:
gitleaks detect --source keycloak/realm-export.json --verbose
# 5. Commit only if zero findings
```

Alternatively, use the Admin REST API export:
```bash
# Get admin token
TOKEN=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -d "client_id=admin-cli&grant_type=password&username=${KEYCLOAK_ADMIN}&password=${KEYCLOAK_ADMIN_PASSWORD}" \
  | jq -r '.access_token')

# Export realm (this exports WITHOUT secrets by default from the API)
curl -s http://localhost:8080/admin/realms/envocc \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq . > keycloak/realm-export.json
```

## Gitleaks Verification

Before committing any realm export, run:
```bash
gitleaks detect --source keycloak/realm-export.json --verbose --redact
```

Expected: **0 findings**. If findings are reported, strip the flagged values before committing.

## Realm Configuration Summary

| Setting | Value | Story |
|---------|-------|-------|
| Realm name | `envocc` | 1.1 |
| Display name | `EnvOcc SSO` | 1.1 |
| SSL Required | `external` (localhost exempt) | 1.1 |
| Locales | `en` (default), `th` | 1.1 |
| User registration | OFF | 1.1 |
| Forgot password | ON | 1.1 |
| Remember me | OFF | 1.1 |
| Email as username | ON | 1.1 |
| Login with email | ON | 1.1 |
| Access token lifespan | 900s (15 min) | 1.1 |
| SSO session idle | 1800s (30 min) | 1.1 |
| SSO session max | 28800s (8 h) | 1.1 |
| Login events | ON | 1.1 |
| Admin events | ON | 1.1 |
| Event expiration | 2592000s (30 days) | 1.1 |
| User profile fields | username, email, firstName, lastName | 1.1 |

OIDC clients (Rails app) are added in Story 3.1. Token signing keys are configured in Story 1.3.
