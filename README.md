# envocc-sso

Self-hosted SSO platform — Keycloak backed by PostgreSQL.

## Quick Start

### Prerequisites

- Docker with Compose v2 (`docker compose version`)
- `openssl` installed (for TLS cert generation)
- No other process listening on ports 80 or 443

### Pre-commit gate

A two-layer security gate runs locally (pre-commit) and in CI on every push.

**One-time setup after cloning:**

```bash
lefthook install
```

This registers `.git/hooks/pre-commit`. The hook runs three checks before every commit:

| Check | Tool | Purpose |
| --- | --- | --- |
| Secret scan | gitleaks 8.24.0+ | Blocks any staged secrets |
| SAST | semgrep (latest OSS) | Static analysis for security antipatterns |
| Realm config lint | python3 | Validates `keycloak/realm-export.json` structure |

**Required tool prerequisites** (install once):

```bash
# macOS
brew install lefthook gitleaks semgrep
# python3 is included with macOS; verify: python3 --version

# Linux / CI
pip install semgrep
# Install gitleaks from https://github.com/gitleaks/gitleaks/releases
```

### TLS (local dev)

Before starting the stack for the first time, generate a self-signed certificate for local development:

```bash
# Generate a self-signed TLS certificate (valid for 365 days)
openssl req -x509 -newkey rsa:4096 \
  -keyout nginx/certs/dev.key \
  -out nginx/certs/dev.crt \
  -days 365 -nodes \
  -subj "/CN=localhost"
```

The private key (`nginx/certs/dev.key`) and certificate (`nginx/certs/dev.crt`) are git-ignored and must be regenerated on each new checkout. The `nginx/certs/.gitkeep` placeholder file keeps the directory tracked in git.

> **Note:** This self-signed certificate is for **local development only**. Production TLS is handled by an organizational CA or Let's Encrypt (outside the scope of this repo).

### Bring-up

```bash
# 1. Generate TLS certs (see above — one time per checkout)

# 2. Copy the example env file and fill in all placeholders
cp .env.example .env
#    Edit .env and replace every `change-me-*` value with real credentials.
#    Do NOT commit your real .env — it is git-ignored.

# 3. Build and start the stack
docker compose up --build
```

Wait for all three services to report `healthy` (Keycloak may take 60–90 s on first boot):

```
envocc-sso-postgres-1   ... healthy
envocc-sso-keycloak-1   ... healthy
envocc-sso-nginx-1      ... healthy
```

### Access

- **Admin console:** <https://localhost/admin/>
  Sign in with `KC_BOOTSTRAP_ADMIN_USERNAME` / `KC_BOOTSTRAP_ADMIN_PASSWORD` from your `.env`.
  > Use `-k` / `--insecure` with curl or accept the self-signed cert warning in your browser.

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
