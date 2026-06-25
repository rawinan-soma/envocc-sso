#!/usr/bin/env bash
# postgres/init/01-init-databases.sh
#
# Runs ONCE on first boot with a fresh volume (PostgreSQL initdb behaviour).
# Creates two least-privilege databases and roles:
#   - database `keycloak`  owned by role `keycloak`   (KC_DB_USERNAME)
#   - database `admin`     owned by role `adminapp`    (ADMINAPP_DB_USERNAME)
#
# Each role has CONNECT access ONLY to its own database (cross-DB access revoked).
#
# IMPORTANT: This script does NOT run on subsequent starts with an existing volume.
# Idempotency is NOT guaranteed for re-runs on non-empty data directories.

set -euo pipefail

# ─── Fail fast on unset / empty required vars ─────────────────────────────────
: "${KC_DB_USERNAME:?KC_DB_USERNAME must be set}"
: "${KC_DB_PASSWORD:?KC_DB_PASSWORD must be set}"
: "${ADMINAPP_DB_USERNAME:?ADMINAPP_DB_USERNAME must be set}"
: "${ADMINAPP_DB_PASSWORD:?ADMINAPP_DB_PASSWORD must be set}"

echo "==> Initialising two databases: keycloak, admin"

# ─── Create roles and databases ───────────────────────────────────────────────
#
# Credentials are passed to psql via -v flags and referenced as :'varname'
# inside SQL to avoid shell variable interpolation into SQL strings.
# This correctly handles passwords containing ', $, \, and other special chars.
#
# CREATE ROLE IF NOT EXISTS is INVALID PostgreSQL syntax.
# Use the SELECT ... WHERE NOT EXISTS ... \gexec pattern instead.

psql -v ON_ERROR_STOP=1 \
     -v kc_role="${KC_DB_USERNAME}" \
     -v kc_pass="${KC_DB_PASSWORD}" \
     -v admin_role="${ADMINAPP_DB_USERNAME}" \
     -v admin_pass="${ADMINAPP_DB_PASSWORD}" \
     --username "${POSTGRES_USER}" \
     --dbname postgres <<'EOSQL'

-- Create keycloak role (if it does not already exist)
SELECT format(
  'CREATE ROLE %I WITH LOGIN PASSWORD %L',
  :'kc_role',
  :'kc_pass'
)
WHERE NOT EXISTS (
  SELECT FROM pg_roles WHERE rolname = :'kc_role'
) \gexec

-- Create adminapp role (if it does not already exist)
SELECT format(
  'CREATE ROLE %I WITH LOGIN PASSWORD %L',
  :'admin_role',
  :'admin_pass'
)
WHERE NOT EXISTS (
  SELECT FROM pg_roles WHERE rolname = :'admin_role'
) \gexec

-- Create keycloak database owned by keycloak role
SELECT format(
  'CREATE DATABASE %I OWNER %I',
  'keycloak',
  :'kc_role'
)
WHERE NOT EXISTS (
  SELECT FROM pg_database WHERE datname = 'keycloak'
) \gexec

-- Create admin database owned by adminapp role
SELECT format(
  'CREATE DATABASE %I OWNER %I',
  'admin',
  :'admin_role'
)
WHERE NOT EXISTS (
  SELECT FROM pg_database WHERE datname = 'admin'
) \gexec

-- ─── Database isolation: revoke PUBLIC access, grant only to owning role ─────

-- keycloak DB isolation
REVOKE ALL ON DATABASE keycloak FROM PUBLIC;
GRANT CONNECT ON DATABASE keycloak TO :kc_role;

-- admin DB isolation
REVOKE ALL ON DATABASE admin FROM PUBLIC;
GRANT CONNECT ON DATABASE admin TO :admin_role;

EOSQL

echo "==> Database initialisation complete."
echo "    - Database 'keycloak' owned by role '${KC_DB_USERNAME}'"
echo "    - Database 'admin' owned by role '${ADMINAPP_DB_USERNAME}'"
echo "    - Cross-database access revoked from PUBLIC."
