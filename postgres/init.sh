#!/usr/bin/env bash
# PostgreSQL initialization script for envocc-sso
# Runs ONCE on first container start (when the data directory is empty).
# The official postgres entrypoint sources *.sh files from
# /docker-entrypoint-initdb.d/ with the container env available, so we can read
# KC_DB_PASSWORD / RAILS_DB_PASSWORD here and set the role passwords at runtime.
#
# Creates two databases, each OWNED by its own login role:
#   1. keycloak_db  — owned by `keycloak`; schema managed entirely by Keycloak
#   2. rails_db     — owned by `rails`;    reserved for the Rails admin app (Story 3.1)
#
# Why OWNER (not just GRANT): on PostgreSQL 15+ the `public` schema no longer
# grants CREATE to non-owners. Keycloak/Rails must create their own tables, so
# each role must OWN its database (which makes it owner of the public schema).
#
# Why passwords are set here: the official postgres image uses scram-sha-256 for
# TCP connections, so a login role MUST have a stored password to authenticate.
# Keycloak connects over TCP as `keycloak` using KC_DB_PASSWORD — that exact
# password must be set on the role here.
#
# Secret hygiene: NO passwords are hardcoded. They come from the container env
# (sourced from .env via compose). If a password var is unset, the script fails
# loudly rather than creating a passwordless (unauthenticatable) role.

set -euo pipefail

: "${KC_DB_USERNAME:=keycloak}"
: "${RAILS_DB_USERNAME:=rails}"

if [ -z "${KC_DB_PASSWORD:-}" ]; then
  echo "init.sh: ERROR — KC_DB_PASSWORD is not set; cannot create the keycloak DB role." >&2
  exit 1
fi
if [ -z "${RAILS_DB_PASSWORD:-}" ]; then
  echo "init.sh: ERROR — RAILS_DB_PASSWORD is not set; cannot create the rails DB role." >&2
  exit 1
fi

# Run as the superuser the entrypoint already authenticated us as.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --no-password <<-SQL
	-- ─── Keycloak role + database ──────────────────────────────────────────────
	DO \$\$
	BEGIN
	  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${KC_DB_USERNAME}') THEN
	    CREATE ROLE "${KC_DB_USERNAME}" WITH LOGIN PASSWORD '${KC_DB_PASSWORD}';
	  ELSE
	    ALTER ROLE "${KC_DB_USERNAME}" WITH LOGIN PASSWORD '${KC_DB_PASSWORD}';
	  END IF;
	END
	\$\$;

	SELECT 'CREATE DATABASE keycloak_db OWNER "${KC_DB_USERNAME}"'
	  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak_db')\gexec

	-- ─── Rails role + database (Story 3.1 scaffolds the schema) ────────────────
	DO \$\$
	BEGIN
	  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${RAILS_DB_USERNAME}') THEN
	    CREATE ROLE "${RAILS_DB_USERNAME}" WITH LOGIN PASSWORD '${RAILS_DB_PASSWORD}';
	  ELSE
	    ALTER ROLE "${RAILS_DB_USERNAME}" WITH LOGIN PASSWORD '${RAILS_DB_PASSWORD}';
	  END IF;
	END
	\$\$;

	SELECT 'CREATE DATABASE rails_db OWNER "${RAILS_DB_USERNAME}"'
	  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'rails_db')\gexec
SQL

echo "init.sh: keycloak_db (owner ${KC_DB_USERNAME}) and rails_db (owner ${RAILS_DB_USERNAME}) ready."
