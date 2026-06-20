# Realm Export Notes — `envocc` Realm

## What This File Is

`realm-export.json` is the **secrets-stripped** baseline realm configuration for the `envocc` Keycloak realm. It is committed to version control and imported automatically on `docker compose up`.

## Fields Stripped Before Commit

The following fields have been **blanked (set to `""`)** or are emitted empty. Keycloak re-generates them on first import — they are never stored in VCS.

| Field | Location in JSON | Action |
|-------|------------------|--------|
| `privateKey` | `components["org.keycloak.keys.KeyProvider"][*].config.privateKey` | Set to `[""]` |
| `certificate` | Same location | Set to `[""]` |
| `secret` | Key provider `hmac-generated` and `aes-generated` configs | Set to `[""]` |
| `clientSecret` | Any `clients[*].secret` | Set to `""` |
| `secretData` | User credential representations | Not present (no users exported) |
| `credentialData` | User credential representations | Not present (no users exported) |

## How Secrets Are Re-Injected at Runtime

1. **Realm signing/encryption keys** (`rsa-generated`, `hmac-generated`, `aes-generated`): Keycloak **auto-generates** new keys on first import. The blank values in the export trigger this auto-generation.

2. **Client secrets** (e.g., `account` client): Built-in clients have blank secrets in the export; Keycloak regenerates them. For the Rails OIDC client (added in Story 3.1), the secret will be injected via environment variable using Keycloak's Admin REST API at container startup.

3. **Admin password**: Set via `KEYCLOAK_ADMIN_PASSWORD` environment variable (from `.env`, never committed).

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
