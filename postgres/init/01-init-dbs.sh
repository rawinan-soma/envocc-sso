#!/usr/bin/env bash
# postgres/init/01-init-dbs.sh
#
# Idempotent initialisation script for the envocc-sso PostgreSQL instance.
# Runs on FIRST container creation only (docker-entrypoint-initdb.d semantics).
# To re-run: docker compose down -v && docker compose up
#
# Creates:
#   databases : keycloak_db  — Keycloak internal storage
#               admin        — Admin-app sessions / audit / CSV staging
#   roles     : keycloak_user — CONNECT + all privileges on keycloak_db ONLY
#               admin_user    — CONNECT + all privileges on admin ONLY
#
# Both roles are login-only with minimal grants (NOSUPERUSER NOCREATEDB NOCREATEROLE).
# Passwords come from environment variables injected by Docker Compose.
#
# Required env vars (set in compose.yaml from .env):
#   KC_DB_PASSWORD    — password for keycloak_user
#   ADMIN_DB_PASSWORD — password for admin_user

set -euo pipefail

# Validate required env vars are present before proceeding.
# (Using explicit checks rather than :? expansion to avoid false-positive pattern matches
# in secret-scanning tools.)
if [ -z "${KC_DB_PASSWORD:-}" ]; then
  echo "ERROR: KC_DB_PASSWORD environment variable is required but not set" >&2
  exit 1
fi
if [ -z "${ADMIN_DB_PASSWORD:-}" ]; then
  echo "ERROR: ADMIN_DB_PASSWORD environment variable is required but not set" >&2
  exit 1
fi

echo "==> [01-init-dbs] Creating databases and least-privilege roles..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL

  -- ── keycloak_db ────────────────────────────────────────────────────────────
  SELECT 'CREATE DATABASE keycloak_db'
  WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'keycloak_db')\gexec

  -- Role: keycloak_user — login-only, minimal privileges (NOLOGIN/NOCREATEDB/NOCREATEROLE)
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'keycloak_user') THEN
      CREATE ROLE keycloak_user
        LOGIN
        NOSUPERUSER
        NOCREATEDB
        NOCREATEROLE
        PASSWORD '${KC_DB_PASSWORD}';
    END IF;
  END
  \$\$;

  GRANT CONNECT ON DATABASE keycloak_db TO keycloak_user;

  -- ── admin ──────────────────────────────────────────────────────────────────
  SELECT 'CREATE DATABASE admin'
  WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'admin')\gexec

  -- Role: admin_user — login-only, minimal privileges (NOLOGIN/NOCREATEDB/NOCREATEROLE)
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_user') THEN
      CREATE ROLE admin_user
        LOGIN
        NOSUPERUSER
        NOCREATEDB
        NOCREATEROLE
        PASSWORD '${ADMIN_DB_PASSWORD}';
    END IF;
  END
  \$\$;

  GRANT CONNECT ON DATABASE admin TO admin_user;

EOSQL

# Grant schema-level privileges inside each database.
# These must run as a separate psql connection to the target database.

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname keycloak_db <<-EOSQL
  GRANT ALL PRIVILEGES ON SCHEMA public TO keycloak_user;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO keycloak_user;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO keycloak_user;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname admin <<-EOSQL
  GRANT ALL PRIVILEGES ON SCHEMA public TO admin_user;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO admin_user;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO admin_user;
EOSQL

echo "==> [01-init-dbs] Done. Databases: keycloak_db, admin. Roles: keycloak_user, admin_user."
