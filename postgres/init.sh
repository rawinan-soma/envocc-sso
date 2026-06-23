#!/usr/bin/env bash
# PostgreSQL initialization script for envocc-sso
# Runs ONCE on first container start (when the data directory is empty).
# The official postgres entrypoint sources *.sh files from
# /docker-entrypoint-initdb.d/ with the container env available, so we can read
# KC_DB_PASSWORD / RAILS_DB_PASSWORD here and set the role passwords at runtime.
#
# Creates two databases, each OWNED by its own login role:
#   1. keycloak_db  — owned by `keycloak`; schema managed entirely by Keycloak
#   2. admin        — owned by `rails`;    reserved for the SvelteKit admin app (Story 4.1)
#
# Why OWNER (not just GRANT): on PostgreSQL 15+ the `public` schema no longer
# grants CREATE to non-owners. Keycloak/admin app must create their own tables, so
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
  echo "init.sh: ERROR — RAILS_DB_PASSWORD is not set; cannot create the admin DB role." >&2
  exit 1
fi

# Run as the superuser the entrypoint already authenticated us as.
# Passwords are passed as psql variables (:'varname') so psql handles quoting,
# preventing SQL injection from passwords that contain single quotes or backslashes.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --no-password \
  -v kc_user="${KC_DB_USERNAME}" \
  -v kc_pass="${KC_DB_PASSWORD}" \
  -v rails_user="${RAILS_DB_USERNAME}" \
  -v rails_pass="${RAILS_DB_PASSWORD}" \
  <<-'SQL'
	-- ─── Keycloak role + database ──────────────────────────────────────────────
	DO $$
	BEGIN
	  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'kc_user') THEN
	    EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', :'kc_user', :'kc_pass');
	  ELSE
	    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'kc_user', :'kc_pass');
	  END IF;
	END
	$$;

	SELECT format('CREATE DATABASE keycloak_db OWNER %I', :'kc_user')
	  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak_db')\gexec

	-- ─── Admin app role + database (Story 4.1 scaffolds the schema) ────────────
	DO $$
	BEGIN
	  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'rails_user') THEN
	    EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', :'rails_user', :'rails_pass');
	  ELSE
	    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'rails_user', :'rails_pass');
	  END IF;
	END
	$$;

	SELECT format('CREATE DATABASE admin OWNER %I', :'rails_user')
	  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'admin')\gexec
SQL

echo "init.sh: keycloak_db (owner ${KC_DB_USERNAME}) and admin (owner ${RAILS_DB_USERNAME}) ready."
