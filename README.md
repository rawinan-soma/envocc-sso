# envocc-sso

Self-hosted SSO platform — Keycloak backed by PostgreSQL.

## Quick Start

### Prerequisites

- Docker with Compose v2 (`docker compose version`)
- No other process listening on port 8080

### Bring-up

```bash
# 1. Copy the example env file and fill in all placeholders
cp .env.example .env
#    Edit .env and replace every `change-me-*` value with real credentials.
#    Do NOT commit your real .env — it is git-ignored.

# 2. Build and start the stack
docker compose up --build
```

Wait for both services to report `healthy` (Keycloak may take 60–90 s on first boot):

```
envocc-sso-postgres-1   ... healthy
envocc-sso-keycloak-1   ... healthy
```

### Access

- **Admin console:** <http://localhost:8080/admin/>
  Sign in with `KC_BOOTSTRAP_ADMIN_USERNAME` / `KC_BOOTSTRAP_ADMIN_PASSWORD` from your `.env`.

### Stop and clean up

```bash
# Stop containers (keep volumes)
docker compose down

# Stop and wipe all data volumes (fresh start on next up)
docker compose down -v
```

## Architecture

| Component | Version | Notes |
|-----------|---------|-------|
| Keycloak  | 26.6.3  | Pinned by digest; built with `--health-enabled=true` at build time |
| PostgreSQL | 17.5   | Pinned by digest; two isolated databases |

### Databases

| Database | Owning Role | Purpose |
|----------|-------------|---------|
| `keycloak` | `keycloak` (from `KC_DB_USERNAME`) | Keycloak identity store |
| `admin` | `adminapp` (from `ADMINAPP_DB_USERNAME`) | Admin app sessions & audit (Story 4.x) |

Each role has `CONNECT` access only to its own database — cross-database access is revoked from `PUBLIC`.

## Development

See `_bmad-output/planning-artifacts/` for architecture decisions and epics.
