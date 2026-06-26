#!/usr/bin/env bats
# tests/unit/ci-security-gate.bats
# ATDD RED-PHASE scaffolds — Story 1.5: Agentic-build / CI Security Gate
#
# AC1: Given a commit,
#      when the pre-commit hook runs,
#      then gitleaks, Semgrep, and realm-config lint execute and block on failure.
#
# AC3: Given the admin app does not yet exist,
#      when the gate runs,
#      then language-specific checks (ESLint/tsc/svelte-check/bun audit/tests)
#      are wired but no-op gracefully until that app lands — no forward dependency.
#
# NOTE: All tests are in RED PHASE (skip).
#       Remove the `skip` annotation from a test when you start implementing
#       the corresponding task, then verify it fails, then implement until green.
#
# Test scenarios covered:
#   TS-151a [P0] lefthook.yml exists at repo root
#   TS-151b [P0] lefthook.yml defines pre-commit group with secret-scan command (gitleaks)
#   TS-151c [P0] lefthook.yml defines pre-commit group with sast command (semgrep)
#   TS-151d [P0] lefthook.yml defines pre-commit group with realm-lint command (python3)
#   TS-151e [P0] gitleaks protect command uses --staged flag (not full history in pre-commit)
#   TS-151f [P0] gitleaks protect command uses --redact flag (no secret in hook output)
#   TS-151g [P0] gitleaks protect command uses --config pointing to .gitleaks.toml
#   TS-151h [P1] semgrep command uses --error flag (exits non-zero on violations)
#   TS-151i [P1] realm-lint command invokes python3 scripts/lint-realm-export.py
#   TS-151j [P1] scripts/lint-realm-export.py exists and is executable
#   TS-151k [P1] lint-realm-export.py reads keycloak/realm-export.json
#   TS-151l [P1] lint-realm-export.py exits 0 against the current valid realm-export.json
#   TS-151m [P1] lint-realm-export.py exits 1 when realm-export.json is malformed JSON
#   TS-151n [P1] lint-realm-export.py exits 1 when required baseline field is absent
#   TS-151o [P2] lint-realm-export.py exits 1 when a long clientSecret is detected
#   TS-151p [P2] lint-realm-export.py exits 1 when a long privateKey value is present
#   TS-151q [P2] README.md contains a pre-commit setup section mentioning lefthook install
#   TS-153a [P0] ci.yml format-check job is absent or guarded (admin/ not yet present)
#   TS-153b [P0] ci.yml dependency-audit job is absent or guarded (admin/ not yet present)
#   TS-153c [P0] ci.yml language-checks job is absent or guarded (admin/ not yet present)

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# TS-151a [P0] — lefthook.yml exists at repo root
# ---------------------------------------------------------------------------
@test "[P0][TS-151a] lefthook.yml exists at repo root" {
  skip "RED PHASE — Task 1.1: create lefthook.yml"

  assert [ -f "${PROJECT_ROOT}/lefthook.yml" ]
}

# ---------------------------------------------------------------------------
# TS-151b [P0] — lefthook.yml defines pre-commit group with gitleaks command
# ---------------------------------------------------------------------------
@test "[P0][TS-151b] lefthook.yml defines pre-commit group" {
  skip "RED PHASE — Task 1.1: create lefthook.yml"

  assert [ -f "${PROJECT_ROOT}/lefthook.yml" ]

  run grep -E "^pre-commit:" "${PROJECT_ROOT}/lefthook.yml"
  assert_success
}

@test "[P0][TS-151b] lefthook.yml has a secret-scan command under pre-commit" {
  skip "RED PHASE — Task 1.2: wire gitleaks in lefthook pre-commit group"

  assert [ -f "${PROJECT_ROOT}/lefthook.yml" ]

  # Command name 'secret-scan' must appear in the file
  run grep -E "secret-scan:" "${PROJECT_ROOT}/lefthook.yml"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-151c [P0] — lefthook.yml has sast command (semgrep)
# ---------------------------------------------------------------------------
@test "[P0][TS-151c] lefthook.yml has a sast command under pre-commit" {
  skip "RED PHASE — Task 1.2: wire semgrep in lefthook pre-commit group"

  assert [ -f "${PROJECT_ROOT}/lefthook.yml" ]

  run grep -E "sast:" "${PROJECT_ROOT}/lefthook.yml"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-151d [P0] — lefthook.yml has realm-lint command
# ---------------------------------------------------------------------------
@test "[P0][TS-151d] lefthook.yml has a realm-lint command under pre-commit" {
  skip "RED PHASE — Task 1.2: wire realm-lint in lefthook pre-commit group"

  assert [ -f "${PROJECT_ROOT}/lefthook.yml" ]

  run grep -E "realm-lint:" "${PROJECT_ROOT}/lefthook.yml"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-151e [P0] — gitleaks protect uses --staged (correct pre-commit scope)
# ---------------------------------------------------------------------------
@test "[P0][TS-151e] gitleaks protect command in lefthook.yml uses --staged flag" {
  skip "RED PHASE — Task 1.2: use gitleaks protect --staged"

  assert [ -f "${PROJECT_ROOT}/lefthook.yml" ]

  run grep "gitleaks protect" "${PROJECT_ROOT}/lefthook.yml"
  assert_output --partial "--staged"
}

# ---------------------------------------------------------------------------
# TS-151f [P0] — gitleaks protect uses --redact (no secret in hook output)
# ---------------------------------------------------------------------------
@test "[P0][TS-151f] gitleaks protect command in lefthook.yml uses --redact flag" {
  skip "RED PHASE — Task 1.2: use gitleaks protect --redact"

  assert [ -f "${PROJECT_ROOT}/lefthook.yml" ]

  run grep "gitleaks protect" "${PROJECT_ROOT}/lefthook.yml"
  assert_output --partial "--redact"
}

# ---------------------------------------------------------------------------
# TS-151g [P0] — gitleaks protect references .gitleaks.toml config
# ---------------------------------------------------------------------------
@test "[P0][TS-151g] gitleaks protect command references .gitleaks.toml" {
  skip "RED PHASE — Task 1.2: point gitleaks to .gitleaks.toml"

  assert [ -f "${PROJECT_ROOT}/lefthook.yml" ]

  run grep "gitleaks protect" "${PROJECT_ROOT}/lefthook.yml"
  assert_output --partial ".gitleaks.toml"
}

# ---------------------------------------------------------------------------
# TS-151h [P1] — semgrep command uses --error flag
# ---------------------------------------------------------------------------
@test "[P1][TS-151h] semgrep command in lefthook.yml uses --error flag" {
  skip "RED PHASE — Task 1.2: ensure semgrep --error in lefthook"

  assert [ -f "${PROJECT_ROOT}/lefthook.yml" ]

  run grep "semgrep" "${PROJECT_ROOT}/lefthook.yml"
  assert_output --partial "--error"
}

# ---------------------------------------------------------------------------
# TS-151i [P1] — realm-lint command invokes scripts/lint-realm-export.py
# ---------------------------------------------------------------------------
@test "[P1][TS-151i] realm-lint command invokes scripts/lint-realm-export.py" {
  skip "RED PHASE — Task 1.2: wire realm-lint command in lefthook"

  assert [ -f "${PROJECT_ROOT}/lefthook.yml" ]

  run grep "realm-lint" -A 2 "${PROJECT_ROOT}/lefthook.yml"
  assert_output --partial "scripts/lint-realm-export.py"
}

# ---------------------------------------------------------------------------
# TS-151j [P1] — scripts/lint-realm-export.py exists
# ---------------------------------------------------------------------------
@test "[P1][TS-151j] scripts/lint-realm-export.py exists" {
  skip "RED PHASE — Task 3: create scripts/lint-realm-export.py"

  assert [ -f "${PROJECT_ROOT}/scripts/lint-realm-export.py" ]
}

# ---------------------------------------------------------------------------
# TS-151k [P1] — lint-realm-export.py references keycloak/realm-export.json
# ---------------------------------------------------------------------------
@test "[P1][TS-151k] lint-realm-export.py reads keycloak/realm-export.json" {
  skip "RED PHASE — Task 3.1: script reads keycloak/realm-export.json"

  assert [ -f "${PROJECT_ROOT}/scripts/lint-realm-export.py" ]

  run grep "realm-export.json" "${PROJECT_ROOT}/scripts/lint-realm-export.py"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-151l [P1] — lint-realm-export.py exits 0 against current valid realm-export.json
# ---------------------------------------------------------------------------
@test "[P1][TS-151l] lint-realm-export.py exits 0 against the current valid realm-export.json" {
  skip "RED PHASE — Task 3: implement passing lint against existing realm-export.json"

  assert [ -f "${PROJECT_ROOT}/scripts/lint-realm-export.py" ]
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py"
  assert_success
  assert_output --partial "passed"
}

# ---------------------------------------------------------------------------
# TS-151m [P1] — lint-realm-export.py exits 1 for malformed JSON
# ---------------------------------------------------------------------------
@test "[P1][TS-151m] lint-realm-export.py exits 1 when realm-export.json is malformed JSON" {
  skip "RED PHASE — Task 3.2: validate JSON is parseable, exit 1 on parse error"

  assert [ -f "${PROJECT_ROOT}/scripts/lint-realm-export.py" ]

  # Create a temp malformed JSON file and point the script at it via env or temp override
  local bad_json
  bad_json="$(mktemp /tmp/bad-realm-XXXXXX.json)"
  echo "{ this is not valid json" > "${bad_json}"

  # The script must be callable with a path argument or respect an env var override.
  # Based on the story spec it reads keycloak/realm-export.json directly.
  # We test by temporarily substituting — if the script accepts a path arg, prefer that.
  # Adjust based on actual implementation.
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${bad_json}"
  assert_failure

  rm -f "${bad_json}"
}

# ---------------------------------------------------------------------------
# TS-151n [P1] — lint-realm-export.py exits 1 when required baseline field missing
# ---------------------------------------------------------------------------
@test "[P1][TS-151n] lint-realm-export.py exits 1 when required baseline field is absent" {
  skip "RED PHASE — Task 3.3: assert required baseline fields"

  assert [ -f "${PROJECT_ROOT}/scripts/lint-realm-export.py" ]

  # Create a minimal JSON that is valid but missing 'bruteForceProtected'
  local minimal_json
  minimal_json="$(mktemp /tmp/minimal-realm-XXXXXX.json)"
  cat > "${minimal_json}" <<'EOF'
{
  "realm": "envocc",
  "enabled": true,
  "accessTokenLifespan": 300
}
EOF
  # Missing: bruteForceProtected

  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${minimal_json}"
  assert_failure
  assert_output --partial "bruteForceProtected"

  rm -f "${minimal_json}"
}

# ---------------------------------------------------------------------------
# TS-151o [P2] — lint-realm-export.py detects long clientSecret
# ---------------------------------------------------------------------------
@test "[P2][TS-151o] lint-realm-export.py exits 1 when a clientSecret > 8 chars is present" {
  skip "RED PHASE — Task 3.4: scan for key material (clientSecret > 8 chars)"

  assert [ -f "${PROJECT_ROOT}/scripts/lint-realm-export.py" ]

  local secret_json
  secret_json="$(mktemp /tmp/secret-realm-XXXXXX.json)"
  cat > "${secret_json}" <<'EOF'
{
  "realm": "envocc",
  "enabled": true,
  "bruteForceProtected": true,
  "accessTokenLifespan": 300,
  "clients": [
    {
      "clientId": "test-client",
      "clientSecret": "super-long-secret-value-that-exceeds-eight-chars"
    }
  ]
}
EOF

  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${secret_json}"
  assert_failure

  rm -f "${secret_json}"
}

# ---------------------------------------------------------------------------
# TS-151p [P2] — lint-realm-export.py detects long privateKey value
# ---------------------------------------------------------------------------
@test "[P2][TS-151p] lint-realm-export.py exits 1 when a privateKey value > 64 chars is present" {
  skip "RED PHASE — Task 3.4: scan for key material (privateKey > 64 chars)"

  assert [ -f "${PROJECT_ROOT}/scripts/lint-realm-export.py" ]

  # Build a 65-char string for privateKey
  local long_key
  long_key="$(python3 -c "print('A' * 65)")"

  local key_json
  key_json="$(mktemp /tmp/key-realm-XXXXXX.json)"
  python3 -c "
import json
data = {
  'realm': 'envocc',
  'enabled': True,
  'bruteForceProtected': True,
  'accessTokenLifespan': 300,
  'components': {
    'org.keycloak.keys.KeyProvider': [
      {'privateKey': 'A' * 65}
    ]
  }
}
print(json.dumps(data))
" > "${key_json}"

  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" "${key_json}"
  assert_failure

  rm -f "${key_json}"
}

# ---------------------------------------------------------------------------
# TS-151q [P2] — README.md contains pre-commit setup section
# ---------------------------------------------------------------------------
@test "[P2][TS-151q] README.md contains a pre-commit setup section mentioning 'lefthook install'" {
  skip "RED PHASE — Task 1.5: add pre-commit gate section to README.md"

  assert [ -f "${PROJECT_ROOT}/README.md" ]

  run grep -i "lefthook install" "${PROJECT_ROOT}/README.md"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-153a [P0] — ci.yml format-check job guarded on admin/package.json
# (admin/ does not exist yet — job must be absent or conditionally skipped)
# ---------------------------------------------------------------------------
@test "[P0][TS-153a] ci.yml format-check job is guarded (hashFiles admin/package.json)" {
  skip "RED PHASE — Task 2.1: add format-check job with admin/package.json guard"

  assert [ -f "${PROJECT_ROOT}/.github/workflows/ci.yml" ]

  # When admin/package.json does not exist, the job must not fail.
  # We verify the guard expression is present in the YAML.
  run grep "hashFiles('admin/package.json')" "${PROJECT_ROOT}/.github/workflows/ci.yml"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-153b [P0] — ci.yml dependency-audit job guarded on admin/package.json
# ---------------------------------------------------------------------------
@test "[P0][TS-153b] ci.yml dependency-audit job is guarded (hashFiles admin/package.json)" {
  skip "RED PHASE — Task 2.4: add dependency-audit job with admin/package.json guard"

  assert [ -f "${PROJECT_ROOT}/.github/workflows/ci.yml" ]

  run grep -c "hashFiles('admin/package.json')" "${PROJECT_ROOT}/.github/workflows/ci.yml"
  # Should appear at least twice: format-check guard + dependency-audit guard
  local count
  count="${output}"
  assert [ "${count}" -ge 2 ]
}

# ---------------------------------------------------------------------------
# TS-153c [P0] — ci.yml language-checks job guarded on admin/package.json
# ---------------------------------------------------------------------------
@test "[P0][TS-153c] ci.yml language-checks job is guarded (hashFiles admin/package.json)" {
  skip "RED PHASE — Task 2.6: add language-checks job with admin/package.json guard"

  assert [ -f "${PROJECT_ROOT}/.github/workflows/ci.yml" ]

  # Three guarded jobs: format-check, dependency-audit, language-checks
  run grep -c "hashFiles('admin/package.json')" "${PROJECT_ROOT}/.github/workflows/ci.yml"
  local count
  count="${output}"
  assert [ "${count}" -ge 3 ]
}
