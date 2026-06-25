#!/usr/bin/env bash
# tests/integration/setup_suite.bash
#
# Suite-level setup for ALL integration tests under tests/integration/.
# BATS 1.5+ automatically sources this file before running any test in
# the directory (BW03 companion pattern).
#
# Ensures a populated .env exists for integration tests that require a
# live stack.  In CI this runs on a fresh checkout; locally it is a
# no-op if .env already exists.

# Resolve project root from this file's location (tests/integration/ → repo root)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

setup_suite() {
  # Load the shared env_setup helper
  # shellcheck source=../helpers/common.bash
  source "${PROJECT_ROOT}/tests/helpers/common.bash"
  env_setup
}
