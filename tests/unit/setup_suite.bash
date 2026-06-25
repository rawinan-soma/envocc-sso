#!/usr/bin/env bash
# tests/unit/setup_suite.bash
# BATS 1.5+ suite-level setup for unit tests.
#
# Called once before any @test in the suite runs (across all unit .bats files
# when invoked as `bats tests/unit/`).
#
# Purpose: ensure a .env file exists so that `docker compose config` calls in
# TS-138a/b/c/d (nginx-config.bats) succeed even in a clean CI checkout where
# no .env has been manually created. Without a .env, compose may error on
# unresolved variable substitutions and the tests fail for the wrong reason.

# Resolve project root — two levels up from tests/unit/
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PROJECT_ROOT

# Load shared helpers (defines env_setup)
# shellcheck source=tests/helpers/common.bash
source "${PROJECT_ROOT}/tests/helpers/common.bash"

setup_suite() {
    env_setup
}
