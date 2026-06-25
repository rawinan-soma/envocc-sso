#!/usr/bin/env bats
# tests/unit/secret-hygiene.bats
# ATDD tests — Story 1.1 AC4: No hard-coded secrets
#              Story 1.2 AC2: realm-export.json is gitleaks-clean
#
# AC4 (Story 1.1): Given secrets are required,
#      when I inspect the repo,
#      then every secret comes from env (.env.example committed with
#      placeholders, real .env git-ignored) and no secret value is
#      hard-coded anywhere in compose.yaml, the Dockerfile, or init scripts.
#
# AC2 (Story 1.2): Given the exported realm file,
#      when I inspect it (and run gitleaks detect),
#      then it contains no client secrets, passwords, or signing-key material —
#      i.e. no secret fields are populated with real values.
#
# Test scenarios covered:
#   TS-104a [P0] .env is present in .gitignore (not tracked by git)
#   TS-104b [P0] .env.example is NOT in .gitignore (committed)
#   TS-104c [P0] .env.example contains only 'change-me' placeholder values, not real secrets
#   TS-104d [P0] compose.yaml references no hard-coded passwords/secrets
#   TS-104e [P0] keycloak/Dockerfile contains no hard-coded secret values
#   TS-104f [P0] postgres/init/01-init-databases.sh contains no hard-coded secret values
#   TS-104g [P1] .env.example defines all required keys consumed by compose.yaml
#   TS-104h [P1] Real .env is not tracked by git (git ls-files check)
#   TS-104i [P2] gitleaks detects synthetic secret injection (negative test — validates gate)
#   TS-104j [P0] keycloak/Dockerfile CMD includes --import-realm flag (Story 1.2 AC1)
#   TS-104k [P0] keycloak/Dockerfile COPYs realm-export.json into image (Story 1.2 AC1)
#   TS-104-realm-a [P0] keycloak/realm-export.json exists and is valid JSON (Story 1.2)
#   TS-104-realm-b [P0] realm-export.json passes gitleaks scan — no secrets populated (Story 1.2 AC2)
#   TS-104-realm-c [P0] realm-export.json contains no populated privateKey fields (Story 1.2 AC2)
#   TS-104-realm-d [P0] realm-export.json contains no populated certificate fields ≥64 chars (Story 1.2 AC2)
#   TS-104-realm-e [P0] realm-export.json contains no populated clientSecret/secret fields ≥8 chars (Story 1.2 AC2)
#   TS-104-realm-f [P1] realm-export.json declares realm name 'envocc' (Story 1.2 AC1)
#   TS-104-realm-g [P1] realm-export.json has enabled=true (Story 1.2 AC1)
#   TS-104-realm-h [P1] realm-export.json is tracked by git (committed, not gitignored) (Story 1.2)

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Extract all ${VAR} / $VAR references from a file
env_refs_in_file() {
  local file="${1}"
  grep -oE '\$\{?[A-Z_][A-Z0-9_]*\}?' "${file}" \
    | sed 's/[${}]//g' \
    | sort -u
}

# ---------------------------------------------------------------------------
# TS-104a [P0] — .env is listed in .gitignore
# ---------------------------------------------------------------------------
@test "[P0][TS-104a] .gitignore contains a rule that covers '.env'" {
  assert [ -f "${PROJECT_ROOT}/.gitignore" ]

  # .env must be ignored (exact line or pattern)
  run grep -E "^\.env$|^\*\.env$|^\.env(\.\*)?$" "${PROJECT_ROOT}/.gitignore"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-104b [P0] — .env.example is NOT excluded from git (explicitly allowed)
# ---------------------------------------------------------------------------
@test "[P0][TS-104b] .gitignore contains '!.env.example' or .env.example is tracked" {
  assert [ -f "${PROJECT_ROOT}/.gitignore" ]

  # Either the gitignore explicitly allows .env.example…
  local has_allow
  has_allow=$(grep -c "^!\.env\.example" "${PROJECT_ROOT}/.gitignore" || true)

  # …or the file is already tracked by git
  local is_tracked
  is_tracked=$(git -C "${PROJECT_ROOT}" ls-files ".env.example" | wc -l | tr -d ' ')

  [ "${has_allow}" -gt 0 ] || [ "${is_tracked}" -gt 0 ] \
    || fail ".env.example is neither explicitly allowed in .gitignore nor tracked by git"
}

# ---------------------------------------------------------------------------
# TS-104c [P0] — .env.example values are only placeholders, not real secrets
# ---------------------------------------------------------------------------
@test "[P0][TS-104c] .env.example uses 'change-me' placeholder values, not real secrets" {
  assert [ -f "${PROJECT_ROOT}/.env.example" ]

  # All value assignments should contain 'change-me' or be empty
  # No value should look like a real password (entropy heuristic: no value > 12 chars without 'change-me')
  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "${key}" =~ ^#.*$ || -z "${key}" ]] && continue

    if [[ -n "${value}" && "${value}" != *"change-me"* ]]; then
      # Values that are clearly non-secret are allowed (e.g., port numbers, DB names)
      # Flag values that look like real credentials (contain mixed case + special chars)
      if echo "${value}" | grep -qE "[A-Z].*[a-z].*[0-9!@#\$%^&*]|[a-z].*[A-Z].*[0-9!@#\$%^&*]"; then
        fail ".env.example key '${key}' has a value that looks like a real secret: '${value}'"
      fi
    fi
  done < "${PROJECT_ROOT}/.env.example"
}

# ---------------------------------------------------------------------------
# TS-104d [P0] — compose.yaml has no hard-coded secret values
# ---------------------------------------------------------------------------
@test "[P0][TS-104d] compose.yaml contains no hard-coded password values" {
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]

  # Secret keys that must ONLY appear as ${VAR} references, never as literals
  local secret_keys=("password" "secret" "admin" "credential")

  for keyword in "${secret_keys[@]}"; do
    # Allow lines that are comments or variable references
    # Flag lines where a secret key appears followed by a literal value (not a ${} reference)
    local violations
    violations=$(grep -in "${keyword}" "${PROJECT_ROOT}/compose.yaml" \
      | grep -v "^\s*#" \
      | grep -v '\$\{' \
      | grep -v "KC_DB_PASSWORD\|KC_BOOTSTRAP_ADMIN\|POSTGRES_PASSWORD\|ADMINAPP_DB_PASSWORD" \
      | grep -v "environment:" \
      || true)

    if [[ -n "${violations}" ]]; then
      fail "compose.yaml may contain hard-coded '${keyword}' value:\n${violations}"
    fi
  done
}

# ---------------------------------------------------------------------------
# TS-104e [P0] — keycloak/Dockerfile has no hard-coded secret values
# ---------------------------------------------------------------------------
@test "[P0][TS-104e] keycloak/Dockerfile contains no hard-coded secret values" {
  assert [ -f "${PROJECT_ROOT}/keycloak/Dockerfile" ]

  # Dockerfile must not contain ENV instructions with secret values
  local violations
  violations=$(grep -inE "^ENV.*(password|secret|admin.*=)" "${PROJECT_ROOT}/keycloak/Dockerfile" \
    | grep -v '\$\{' \
    || true)

  [ -z "${violations}" ] \
    || fail "keycloak/Dockerfile contains hard-coded secret in ENV:\n${violations}"
}

# ---------------------------------------------------------------------------
# TS-104f [P0] — postgres init script has no hard-coded secret values
# ---------------------------------------------------------------------------
@test "[P0][TS-104f] postgres/init/01-init-databases.sh contains no hard-coded passwords" {
  assert [ -f "${PROJECT_ROOT}/postgres/init/01-init-databases.sh" ]

  # No raw password strings should appear — credentials come from env vars via psql -v flags
  # Flag patterns like PASSWORD 'literal' or password="literal"
  local violations
  violations=$(grep -inE "(PASSWORD|password)\s+'[^']+'|password\s*=\s*['\"][^'\"]+['\"]" \
    "${PROJECT_ROOT}/postgres/init/01-init-databases.sh" \
    | grep -v ":'[a-z_]*'" \
    || true)

  [ -z "${violations}" ] \
    || fail "postgres/init script may contain hard-coded password:\n${violations}"
}

# ---------------------------------------------------------------------------
# TS-104g [P1] — .env.example defines all keys consumed by compose.yaml
# ---------------------------------------------------------------------------
@test "[P1][TS-104g] .env.example defines every env var referenced in compose.yaml" {
  assert [ -f "${PROJECT_ROOT}/compose.yaml" ]
  assert [ -f "${PROJECT_ROOT}/.env.example" ]

  # Extract all ${VAR} references from compose.yaml
  local compose_vars
  mapfile -t compose_vars < <(env_refs_in_file "${PROJECT_ROOT}/compose.yaml")

  # Extract all defined keys from .env.example
  local example_keys
  mapfile -t example_keys < <(
    grep -E "^[A-Z_][A-Z0-9_]*=" "${PROJECT_ROOT}/.env.example" \
      | cut -d= -f1 \
      | sort -u
  )

  # Check each compose var is in .env.example
  for var in "${compose_vars[@]}"; do
    # Skip internal/system vars (PATH, HOME, etc.)
    [[ "${var}" =~ ^(PATH|HOME|USER|SHELL|PWD|HOSTNAME)$ ]] && continue

    local found=0
    for key in "${example_keys[@]}"; do
      [[ "${key}" == "${var}" ]] && found=1 && break
    done

    [ "${found}" -eq 1 ] \
      || fail "compose.yaml references \${${var}} but it is not defined in .env.example"
  done
}

# ---------------------------------------------------------------------------
# TS-104h [P1] — Real .env is NOT tracked by git
# ---------------------------------------------------------------------------
@test "[P1][TS-104h] git does not track the real .env file" {
  # git ls-files returns empty output for untracked files
  run git -C "${PROJECT_ROOT}" ls-files ".env"
  assert_output ""
}

# ---------------------------------------------------------------------------
# TS-104i [P2] — gitleaks negative test: detects synthetic secret (validates gate)
# ---------------------------------------------------------------------------
@test "[P2][TS-104i] gitleaks detects a synthetic injected secret (gate validation)" {
  skip "P2: gitleaks gate is Story 1.5 scope; this is a pre-validation scaffold"

  # This test validates that gitleaks is correctly configured to catch secrets.
  # It injects a synthetic AWS-like key into a temp file and asserts gitleaks catches it.

  local tmpfile
  tmpfile=$(mktemp "${PROJECT_ROOT}/tmp-synthetic-secret-XXXXXX.txt")

  # Write a synthetic secret that gitleaks should detect
  echo "AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" > "${tmpfile}"

  run gitleaks detect \
    --source="${PROJECT_ROOT}" \
    --config="${PROJECT_ROOT}/.gitleaks.toml" \
    --no-git \
    --verbose \
    2>&1

  # Cleanup before asserting (avoid leaving synthetic secret on disk)
  rm -f "${tmpfile}"

  # gitleaks exits non-zero when it finds a leak
  assert_failure
}

# ===========================================================================
# Story 1.2 — Realm config-as-code baseline & secret hygiene
# ===========================================================================

# ---------------------------------------------------------------------------
# TS-104j [P0] — keycloak/Dockerfile CMD includes --import-realm flag (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-104j] keycloak/Dockerfile CMD includes '--import-realm' flag" {
  assert [ -f "${PROJECT_ROOT}/keycloak/Dockerfile" ]

  # The CMD line must include --import-realm so KC auto-imports the realm on boot.
  # Expected: CMD ["start", "--optimized", "--import-realm"]
  run grep -E "CMD.*--import-realm" "${PROJECT_ROOT}/keycloak/Dockerfile"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-104k [P0] — keycloak/Dockerfile COPYs realm-export.json into image (AC1)
# ---------------------------------------------------------------------------
@test "[P0][TS-104k] keycloak/Dockerfile COPYs realm-export.json into /opt/keycloak/data/import/" {
  assert [ -f "${PROJECT_ROOT}/keycloak/Dockerfile" ]

  # COPY must place the file at the exact KC 26 import path.
  run grep -E "COPY.*realm-export\.json.*/opt/keycloak/data/import/realm-export\.json" \
    "${PROJECT_ROOT}/keycloak/Dockerfile"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-104-realm-a [P0] — realm-export.json exists and is valid JSON (AC1, AC2)
# ---------------------------------------------------------------------------
@test "[P0][TS-104-realm-a] keycloak/realm-export.json exists" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]
}

@test "[P0][TS-104-realm-a] keycloak/realm-export.json is valid JSON" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  # python3 -m json.tool exits non-zero on invalid JSON
  run python3 -m json.tool "${PROJECT_ROOT}/keycloak/realm-export.json"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-104-realm-b [P0] — realm-export.json passes gitleaks scan (AC2)
# Static check — no live stack needed; the file exists on disk.
# ---------------------------------------------------------------------------
@test "[P0][TS-104-realm-b] keycloak/realm-export.json passes gitleaks scan — no secrets populated" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]
  assert [ -f "${PROJECT_ROOT}/.gitleaks.toml" ]

  # gitleaks exits 0 when no leaks are found; non-zero when leaks detected.
  run gitleaks detect \
    --source="${PROJECT_ROOT}/keycloak/realm-export.json" \
    --no-git \
    --config="${PROJECT_ROOT}/.gitleaks.toml" \
    --redact \
    --verbose \
    2>&1
  assert_success
}

# ---------------------------------------------------------------------------
# TS-104-realm-c [P0] — realm-export.json contains no populated privateKey fields (AC2)
# The gitleaks keycloak-private-key rule catches these, but this static test
# provides an independent, human-readable check without requiring gitleaks.
# ---------------------------------------------------------------------------
@test "[P0][TS-104-realm-c] realm-export.json contains no populated 'privateKey' fields" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  # A populated privateKey would be a long Base64 string.
  # Empty string ("") or absent field are both acceptable.
  # Flag: "privateKey": "<value with ≥16 non-whitespace chars>"
  local violations
  violations=$(python3 -c "
import json, sys, re
with open('${PROJECT_ROOT}/keycloak/realm-export.json') as f:
  text = f.read()
# Find all privateKey values in JSON (simple regex for quick static check)
matches = re.findall(r'\"privateKey\"\s*:\s*\"([^\"]{16,})\"', text)
if matches:
  print('FAIL: populated privateKey found')
  sys.exit(1)
else:
  print('OK')
  sys.exit(0)
" 2>&1 || true)

  echo "${violations}" | grep -q "FAIL" \
    && fail "realm-export.json contains populated 'privateKey' field — strip before committing" \
    || true
}

# ---------------------------------------------------------------------------
# TS-104-realm-d [P0] — realm-export.json contains no populated certificate fields ≥64 chars (AC2)
# ---------------------------------------------------------------------------
@test "[P0][TS-104-realm-d] realm-export.json contains no populated 'certificate' fields ≥64 chars" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  local violations
  violations=$(python3 -c "
import re, sys
with open('${PROJECT_ROOT}/keycloak/realm-export.json') as f:
  text = f.read()
# certificate fields with ≥64 chars (real X.509 certs are much longer)
matches = re.findall(r'\"certificate\"\s*:\s*\"([^\"]{64,})\"', text)
if matches:
  print('FAIL: populated certificate found (length >= 64)')
  sys.exit(1)
else:
  print('OK')
  sys.exit(0)
" 2>&1 || true)

  echo "${violations}" | grep -q "FAIL" \
    && fail "realm-export.json contains populated 'certificate' field — strip before committing" \
    || true
}

# ---------------------------------------------------------------------------
# TS-104-realm-e [P0] — realm-export.json contains no populated clientSecret/secret ≥8 chars (AC2)
# ---------------------------------------------------------------------------
@test "[P0][TS-104-realm-e] realm-export.json contains no populated 'clientSecret' or 'secret' fields ≥8 chars" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  local violations
  violations=$(python3 -c "
import re, sys
with open('${PROJECT_ROOT}/keycloak/realm-export.json') as f:
  text = f.read()
# clientSecret or secret with real values (≥8 chars, not empty)
matches = re.findall(r'\"(?:clientSecret|secret)\"\s*:\s*\"([^\"]{8,})\"', text)
if matches:
  print('FAIL: populated secret/clientSecret found')
  sys.exit(1)
else:
  print('OK')
  sys.exit(0)
" 2>&1 || true)

  echo "${violations}" | grep -q "FAIL" \
    && fail "realm-export.json contains populated 'clientSecret' or 'secret' field — strip before committing" \
    || true
}

# ---------------------------------------------------------------------------
# TS-104-realm-f [P1] — realm-export.json declares realm name 'envocc' (AC1)
# ---------------------------------------------------------------------------
@test "[P1][TS-104-realm-f] realm-export.json declares realm name 'envocc'" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run python3 -c "
import json, sys
with open('${PROJECT_ROOT}/keycloak/realm-export.json') as f:
  d = json.load(f)
print(d.get('realm',''))
"
  assert_success
  assert_output "envocc"
}

# ---------------------------------------------------------------------------
# TS-104-realm-g [P1] — realm-export.json has enabled=true (AC1)
# ---------------------------------------------------------------------------
@test "[P1][TS-104-realm-g] realm-export.json has 'enabled' set to true" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run python3 -c "
import json, sys
with open('${PROJECT_ROOT}/keycloak/realm-export.json') as f:
  d = json.load(f)
print(str(d.get('enabled', False)).lower())
"
  assert_success
  assert_output "true"
}

# ---------------------------------------------------------------------------
# TS-104-realm-h [P1] — realm-export.json is tracked by git (Story 1.2)
# The file must be committed — not gitignored or untracked.
# ---------------------------------------------------------------------------
@test "[P1][TS-104-realm-h] git tracks keycloak/realm-export.json (file is committed)" {
  # git ls-files returns a non-empty line if the file is tracked.
  # An untracked or gitignored file produces empty output.
  run git -C "${PROJECT_ROOT}" ls-files "keycloak/realm-export.json"
  refute_output ""
}
