#!/usr/bin/env bash
# Fixture: Required .env keys for Story 1.1
# Used by ATDD tests to assert .env.example completeness.
# Source this file in bats tests if you need the canonical required-keys list.

REQUIRED_ENV_KEYS=(
  "KEYCLOAK_ADMIN"
  "KEYCLOAK_ADMIN_PASSWORD"
  "POSTGRES_USER"
  "POSTGRES_PASSWORD"
  "KC_DB"
  "KC_DB_URL"
  "KC_DB_USERNAME"
  "KC_DB_PASSWORD"
  "KC_HOSTNAME"
  "ADMIN_DB_PASSWORD"
)
export REQUIRED_ENV_KEYS
