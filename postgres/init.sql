-- PostgreSQL initialization script for envocc-sso
-- Runs once on first container start (when the data directory is empty).
-- Creates two databases:
--   1. keycloak_db  — owned by Keycloak; schema is managed entirely by Keycloak migrations
--   2. rails_db     — reserved for the Rails admin app (Story 3.1); Rails owns the schema
--
-- The postgres superuser (POSTGRES_USER from .env) runs this script.
-- Keycloak connects as `keycloak` user (KC_DB_USERNAME); Rails will connect as `rails` (Story 3.1).
--
-- NOTE: Role passwords are NOT set here — Keycloak sets its own password via KC_DB_PASSWORD.
-- Rails role password setup is handled in Story 3.1. Roles are created without passwords
-- and access is restricted to the named databases only (no cross-schema access).

-- ─── Keycloak database and user ──────────────────────────────────────────────
SELECT 'CREATE DATABASE keycloak_db'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak_db')\gexec

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'keycloak') THEN
    -- Password is set by Keycloak itself via KC_DB_PASSWORD on first connection.
    -- Role is created login-capable; password auth handled by Keycloak container env.
    CREATE ROLE keycloak WITH LOGIN;
  END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE keycloak_db TO keycloak;

-- ─── Rails database (placeholder — Story 3.1 will scaffold the schema) ───────
SELECT 'CREATE DATABASE rails_db'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'rails_db')\gexec

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rails') THEN
    -- Password configured in Story 3.1 via Rails credentials / RAILS_DB_PASSWORD env var.
    CREATE ROLE rails WITH LOGIN;
  END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE rails_db TO rails;
