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
if [ -z "${POSTGRES_USER:-}" ]; then
  echo "ERROR: POSTGRES_USER environment variable is required but not set" >&2
  exit 1
fi
if [ -z "${KC_DB_PASSWORD:-}" ]; then
  echo "ERROR: KC_DB_PASSWORD environment variable is required but not set" >&2
  exit 1
fi
if [ -z "${ADMIN_DB_PASSWORD:-}" ]; then
  echo "ERROR: ADMIN_DB_PASSWORD environment variable is required but not set" >&2
  exit 1
fi

echo "==> [01-init-dbs] Creating databases and least-privilege roles..."

# Passwords are passed to psql as variables (-v) and interpolated only at the top
# SQL level via :'var' (psql client-side quoting — NOT shell). That value is then
# fed to format(%L), which produces a safe SQL literal at execution time. This makes
# a password containing single quotes, backslashes, or other special characters safe
# (no broken DDL, no SQL injection through the password value).
#
# NOTE: psql :'var' substitution does NOT occur inside dollar-quoted DO blocks, so the
# role creation is split out of the idempotent DB block and run as top-level statements
# built with format(); each is wrapped in its own NOT EXISTS guard for idempotency.
psql -v ON_ERROR_STOP=1 \
  -v kc_db_password="$KC_DB_PASSWORD" \
  -v admin_db_password="$ADMIN_DB_PASSWORD" \
  --username "$POSTGRES_USER" --dbname postgres <<-EOSQL

  -- ── keycloak_db ────────────────────────────────────────────────────────────
  SELECT 'CREATE DATABASE keycloak_db'
  WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'keycloak_db')\gexec

  -- Role: keycloak_user — login-only, minimal privileges (NOSUPERUSER/NOCREATEDB/NOCREATEROLE).
  -- Build the CREATE ROLE via format(%L) so the password is safely quoted by PostgreSQL.
  SELECT format(
    'CREATE ROLE keycloak_user LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L',
    :'kc_db_password'
  )
  WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'keycloak_user')\gexec

  -- Isolation: PostgreSQL grants CONNECT to PUBLIC by default, which would let any
  -- role (incl. admin_user) connect to keycloak_db. Revoke it, then grant CONNECT
  -- back to keycloak_user only — enforcing the "two isolated databases" boundary (AC2).
  REVOKE CONNECT ON DATABASE keycloak_db FROM PUBLIC;
  GRANT CONNECT ON DATABASE keycloak_db TO keycloak_user;

  -- ── admin ──────────────────────────────────────────────────────────────────
  SELECT 'CREATE DATABASE admin'
  WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'admin')\gexec

  -- Role: admin_user — login-only, minimal privileges (NOSUPERUSER/NOCREATEDB/NOCREATEROLE).
  SELECT format(
    'CREATE ROLE admin_user LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L',
    :'admin_db_password'
  )
  WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_user')\gexec

  -- Isolation: revoke the default PUBLIC CONNECT so keycloak_user cannot reach the
  -- admin DB, then grant CONNECT back to admin_user only (AC2 — isolated databases).
  REVOKE CONNECT ON DATABASE admin FROM PUBLIC;
  GRANT CONNECT ON DATABASE admin TO admin_user;

EOSQL

# Grant schema-level privileges inside each database.
# These run as separate psql connections to each target database.
#
# GRANT ALL ON SCHEMA public conveys USAGE + CREATE. On PostgreSQL 15+ the public
# schema no longer grants CREATE to PUBLIC by default, so this CREATE grant is what
# actually lets the app role create its own tables — it is the load-bearing grant.
# Do NOT remove CREATE here or the app (Keycloak migrations) will fail at boot.
#
# The ALTER DEFAULT PRIVILEGES statements use FOR ROLE so they apply to objects
# created BY the app role itself (Keycloak/admin connect as that role and create
# their own tables). Without FOR ROLE, default privileges would only cover objects
# created by the connected superuser — inert for the app's own tables.

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname keycloak_db <<-EOSQL
  GRANT ALL PRIVILEGES ON SCHEMA public TO keycloak_user;
  ALTER DEFAULT PRIVILEGES FOR ROLE keycloak_user IN SCHEMA public GRANT ALL ON TABLES TO keycloak_user;
  ALTER DEFAULT PRIVILEGES FOR ROLE keycloak_user IN SCHEMA public GRANT ALL ON SEQUENCES TO keycloak_user;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname admin <<-EOSQL
  GRANT ALL PRIVILEGES ON SCHEMA public TO admin_user;
  ALTER DEFAULT PRIVILEGES FOR ROLE admin_user IN SCHEMA public GRANT ALL ON TABLES TO admin_user;
  ALTER DEFAULT PRIVILEGES FOR ROLE admin_user IN SCHEMA public GRANT ALL ON SEQUENCES TO admin_user;
EOSQL

echo "==> [01-init-dbs] Done. Databases: keycloak_db, admin. Roles: keycloak_user, admin_user."
