#!/usr/bin/env bash
# =============================================================================
# ATDD Test Runner — Story 1.2: Realm config-as-code baseline & secret hygiene
#
# Usage:
#   ./tests/run-atdd.sh               # run all tests
#   ./tests/run-atdd.sh secrets       # run only AC2 secret-hygiene tests
#   ./tests/run-atdd.sh integration   # run only AC1 realm-config tests
#   ./tests/run-atdd.sh smoke         # run only AC1 docker-compose smoke tests
#
# Dependencies:
#   brew install bats-core gitleaks
#   docker + docker compose
#
# TDD Phase: RED — static tests fail until implementation files exist;
# runtime tests (needing a running stack) self-skip when Keycloak is not up.
# Start the stack first (`docker compose up -d`) to exercise runtime tests.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Check for bats
if ! command -v bats >/dev/null 2>&1; then
  echo "ERROR: bats-core not installed. Install via: brew install bats-core"
  echo "       or: npm install -g bats"
  exit 1
fi

cd "$REPO_ROOT"

FILTER="${1:-all}"

case "$FILTER" in
  secrets|secret-hygiene)
    echo "Running AC2 Secret Hygiene tests..."
    bats tests/secret-hygiene/ac2-secret-hygiene.bats
    ;;
  integration)
    echo "Running AC1 Realm Config tests..."
    bats tests/integration/ac1-realm-config.bats
    ;;
  smoke)
    echo "Running AC1 Docker Compose smoke tests..."
    bats tests/integration/ac1-docker-compose-smoke.bats
    ;;
  all|*)
    echo "Running all Story 1.2 ATDD acceptance tests..."
    echo "=========================================="
    echo "NOTE: runtime tests self-skip if the stack is not running."
    echo "      Run 'docker compose up -d' first to exercise them."
    echo "=========================================="
    bats tests/secret-hygiene/ac2-secret-hygiene.bats
    bats tests/integration/ac1-docker-compose-smoke.bats
    bats tests/integration/ac1-realm-config.bats
    ;;
esac
