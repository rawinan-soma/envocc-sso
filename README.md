# envocc-sso

Keycloak-based SSO for the EnvOcc (Environmental & Occupational Health) platform.

## Architecture

- **Keycloak 26.2.5** (Quarkus distribution) — OIDC identity provider
- **PostgreSQL 17** — two databases: `keycloak_db` (Keycloak-owned) + `rails_db` (Rails app, Story 3.1)
- **Mailpit** — local SMTP trap for email testing
- **Rails** — admin layer (scaffolded in Story 3.1)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose v2
- [gitleaks](https://github.com/gitleaks/gitleaks) — `brew install gitleaks`
- [lefthook](https://github.com/evilmartians/lefthook) — `brew install lefthook` (for pre-commit hooks)

## Quick Start

```bash
# 1. Clone and enter the repo
git clone <repo-url> envocc-sso && cd envocc-sso

# 2. Copy example env file and fill in dev passwords
cp .env.example .env
# Edit .env — replace all "change-me" values with real dev passwords

# 3. Install pre-commit hooks (requires lefthook + gitleaks)
lefthook install

# 4. Start all services
docker compose up -d

# 5. Wait for Keycloak to import the realm (~30-60 seconds)
docker compose logs -f keycloak

# 6. Verify
curl http://localhost:8080/realms/envocc/.well-known/openid-configuration
```

## Services & Ports

| Service | Port | URL |
|---------|------|-----|
| Keycloak | 8080 | http://localhost:8080 |
| Keycloak Admin UI | 8080 | http://localhost:8080/admin |
| PostgreSQL | 5432 | postgres://localhost:5432 |
| Mailpit SMTP | 1025 | (SMTP only) |
| Mailpit Web UI | 8025 | http://localhost:8025 |

**Keycloak Admin credentials** — set in `.env` (`KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD`).

## Realm

The `envocc` realm is automatically imported on `docker compose up` from `keycloak/realm-export.json`.

OIDC discovery endpoint:
```
http://localhost:8080/realms/envocc/.well-known/openid-configuration
```

## Secret Hygiene Rule

> **NEVER commit real secrets.** This is a hard rule enforced by tooling.

| What | Rule |
|------|------|
| `.env` | **Gitignored** — never committed. Contains real dev passwords. |
| `.env.example` | **Committed** — placeholder values only (`change-me`). |
| `keycloak/realm-export.json` | **Committed** — secrets stripped before commit. See `keycloak/REALM-EXPORT-NOTES.md`. |
| `*.pem`, `*.key`, `*.full-export.json` | **Gitignored** — never committed. |
| `admin/config/master.key` | **Gitignored** — Rails credentials key, never committed. |

### Secret Scanning

- **Pre-commit**: `lefthook` runs `gitleaks protect --staged` on every commit. A secret pattern **blocks the commit**.
- **CI**: GitHub Actions runs `gitleaks detect --source .` as a required gate. A match **fails the build**.

To test the pre-commit hook:
```bash
lefthook install
# Try staging a file with a fake secret — the hook should block it
```

## Keycloak Version

Pinned to `quay.io/keycloak/keycloak:26.2.5`. See `keycloak/PINNED-VERSION.md` for upgrade instructions and digest record.

## Running Tests

Integration tests use [bats-core](https://github.com/bats-core/bats-core):

```bash
# Install bats-core (once)
brew install bats-core

# Run all ATDD tests (requires Docker Compose running)
bash tests/run-atdd.sh
```

## Project Structure

```
envocc-sso/
├── compose.yaml              # Dev: keycloak · postgres · mailpit
├── .env.example              # Placeholder env vars (committed)
├── .gitignore                # Excludes .env, *.pem, *.key, etc.
├── .gitleaks.toml            # Secret scanning rules
├── lefthook.yml              # Pre-commit hooks
├── keycloak/
│   ├── Dockerfile            # Pinned FROM + realm import
│   ├── realm-export.json     # Baseline envocc realm (secrets stripped)
│   ├── PINNED-VERSION.md     # Image tag, digest, upgrade guide
│   └── REALM-EXPORT-NOTES.md # Which fields stripped + re-injection guide
├── postgres/
│   └── init.sql              # Creates keycloak_db + rails_db
├── admin/                    # Rails app (Story 3.1)
├── reference-client/         # OIDC reference client (Story 1.7)
├── nginx/                    # Reverse proxy (Story 6.3)
├── docs/                     # OIDC integration guide (Story 6.1)
├── tests/                    # BATS integration + secret hygiene tests
└── .github/workflows/
    └── ci.yml                # CI: gitleaks gate (grows in later stories)
```
