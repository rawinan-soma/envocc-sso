#!/usr/bin/env bash
# =============================================================================
# ATDD Test Runner — Story 1.1: Keycloak Stand-Up & Secret Hygiene
#
# Usage:
#   ./tests/run-atdd.sh               # run all tests (all will skip in RED phase)
#   ./tests/run-atdd.sh secrets       # run only AC2 secret-hygiene tests
#   ./tests/run-atdd.sh integration   # run only AC1 Docker/realm tests
#
# Dependencies:
#   brew install bats-core gitleaks lefthook
#   docker + docker compose
#
# TDD Phase: RED — all tests skip until implementation is complete.
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
    echo "Running AC1 Docker Compose + Realm Config tests..."
    bats tests/integration/ac1-docker-compose-smoke.bats
    bats tests/integration/ac1-realm-config.bats
    ;;
  all|*)
    echo "Running all Story 1.1 ATDD acceptance tests..."
    echo "=========================================="
    echo "NOTE: All tests should SKIP in RED phase."
    echo "=========================================="
    bats tests/secret-hygiene/ac2-secret-hygiene.bats
    bats tests/integration/ac1-docker-compose-smoke.bats
    bats tests/integration/ac1-realm-config.bats
    ;;
esac
