#!/usr/bin/env bats
# tests/integration/ci-gate-jobs.bats
# ATDD RED-PHASE scaffolds — Story 1.5: Agentic-build / CI Security Gate
#
# AC2: Given a pushed branch,
#      when CI runs,
#      then the gate runs the full applicable suite (formatting check, SAST,
#      secret-scan, dependency audit, realm-config lint) and fails the build
#      on any violation.
#
# NOTE: All tests are in RED PHASE (skip).
#       Remove the `skip` annotation from a test when you start implementing
#       the corresponding task, then verify it fails, then implement until green.
#
# Test scenarios covered:
#   TS-152a [P0] ci.yml contains a sast job (Semgrep)
#   TS-152b [P0] sast job uses semgrep with --error flag
#   TS-152c [P0] sast job includes SARIF output flag
#   TS-152d [P0] sast job has permissions.security-events: write
#   TS-152e [P0] ci.yml contains a realm-lint job
#   TS-152f [P0] realm-lint job runs scripts/lint-realm-export.py
#   TS-152g [P0] realm-lint job includes actions/setup-python@v5
#   TS-152h [P1] ci.yml existing gitleaks job is preserved (Story 1.1 regression)
#   TS-152i [P1] ci.yml existing realm-export-check job is preserved (Story 1.2 regression)
#   TS-152j [P1] all job IDs in ci.yml follow kebab-case naming
#   TS-152k [P1] all jobs use runs-on: ubuntu-latest
#   TS-152l [P2] sast job uploads SARIF artifact via codeql-action/upload-sarif
#   TS-152m [P2] realm-lint exits 0 locally (smoke test of the Python script)
#   TS-152n [P2] ci.yml YAML is syntactically valid (python3 -c yaml.safe_load)
#   TS-152o [P2] scripts/ directory is not listed in .gitignore

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

CI_YML="${PROJECT_ROOT}/.github/workflows/ci.yml"

# ---------------------------------------------------------------------------
# TS-152a [P0] — ci.yml contains a sast job
# ---------------------------------------------------------------------------
@test "[P0][TS-152a] ci.yml defines a sast job for Semgrep SAST" {
  skip "RED PHASE — Task 2.2: add sast job to ci.yml"

  assert [ -f "${CI_YML}" ]

  run grep -E "^  sast:" "${CI_YML}"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-152b [P0] — sast job uses semgrep --error
# ---------------------------------------------------------------------------
@test "[P0][TS-152b] sast job runs semgrep with --error flag" {
  skip "RED PHASE — Task 2.2: semgrep scan --config auto --error in sast job"

  assert [ -f "${CI_YML}" ]

  run grep "semgrep" "${CI_YML}"
  assert_output --partial "--error"
}

# ---------------------------------------------------------------------------
# TS-152c [P0] — sast job includes --sarif --output semgrep.sarif
# ---------------------------------------------------------------------------
@test "[P0][TS-152c] sast job generates SARIF output (--sarif --output semgrep.sarif)" {
  skip "RED PHASE — Task 2.2: add --sarif --output semgrep.sarif to semgrep command"

  assert [ -f "${CI_YML}" ]

  run grep "semgrep" "${CI_YML}"
  assert_output --partial "--sarif"
  assert_output --partial "semgrep.sarif"
}

# ---------------------------------------------------------------------------
# TS-152d [P0] — sast job has security-events: write permission
# ---------------------------------------------------------------------------
@test "[P0][TS-152d] sast job has permissions.security-events: write" {
  skip "RED PHASE — Task 2.2: add permissions.security-events: write to sast job"

  assert [ -f "${CI_YML}" ]

  # The permission must appear somewhere in the file for the sast job
  run grep "security-events: write" "${CI_YML}"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-152e [P0] — ci.yml contains a realm-lint job
# ---------------------------------------------------------------------------
@test "[P0][TS-152e] ci.yml defines a realm-lint job" {
  skip "RED PHASE — Task 2.5: add realm-lint job to ci.yml"

  assert [ -f "${CI_YML}" ]

  run grep -E "^  realm-lint:" "${CI_YML}"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-152f [P0] — realm-lint job runs scripts/lint-realm-export.py
# ---------------------------------------------------------------------------
@test "[P0][TS-152f] realm-lint job runs python3 scripts/lint-realm-export.py" {
  skip "RED PHASE — Task 2.5: run lint-realm-export.py in realm-lint CI job"

  assert [ -f "${CI_YML}" ]

  run grep "lint-realm-export.py" "${CI_YML}"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-152g [P0] — realm-lint job includes actions/setup-python@v5
# ---------------------------------------------------------------------------
@test "[P0][TS-152g] realm-lint job uses actions/setup-python@v5" {
  skip "RED PHASE — Task 2.5: add actions/setup-python@v5 to realm-lint job"

  assert [ -f "${CI_YML}" ]

  run grep "setup-python" "${CI_YML}"
  assert_output --partial "v5"
}

# ---------------------------------------------------------------------------
# TS-152h [P1] — existing gitleaks job is preserved (Story 1.1 regression guard)
# ---------------------------------------------------------------------------
@test "[P1][TS-152h] ci.yml still contains the gitleaks job from Story 1.1" {
  skip "RED PHASE — Task 2.3: do not remove gitleaks job; verify preservation"

  assert [ -f "${CI_YML}" ]

  run grep -E "^  gitleaks:" "${CI_YML}"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-152i [P1] — existing realm-export-check job is preserved (Story 1.2 regression guard)
# ---------------------------------------------------------------------------
@test "[P1][TS-152i] ci.yml still contains the realm-export-check job from Story 1.2" {
  skip "RED PHASE — Task 2.3: do not remove realm-export-check job; verify preservation"

  assert [ -f "${CI_YML}" ]

  run grep -E "^  realm-export-check:" "${CI_YML}"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-152j [P1] — all job IDs in ci.yml follow kebab-case naming
# ---------------------------------------------------------------------------
@test "[P1][TS-152j] all job IDs in ci.yml follow kebab-case naming" {
  skip "RED PHASE — Task 2.7: ensure all job IDs are kebab-case"

  assert [ -f "${CI_YML}" ]

  # Extract top-level job IDs (lines like '  job-id:' in the jobs: block)
  # A well-formed job ID must match [a-z][a-z0-9-]+ (kebab-case, no underscores)
  local bad_ids
  bad_ids=$(python3 - "${CI_YML}" <<'EOF'
import re, sys

with open(sys.argv[1]) as f:
    content = f.read()

# Find the jobs: block
jobs_match = re.search(r'^jobs:\n(.*)', content, re.MULTILINE | re.DOTALL)
if not jobs_match:
    print("NO_JOBS_BLOCK")
    sys.exit(0)

jobs_block = jobs_match.group(1)

# Extract job IDs: lines indented with exactly 2 spaces followed by an identifier and colon
bad = []
for m in re.finditer(r'^  ([A-Za-z][A-Za-z0-9_-]*):', jobs_block, re.MULTILINE):
    job_id = m.group(1)
    # kebab-case: lowercase, digits, hyphens only; no underscores, no uppercase
    if not re.fullmatch(r'[a-z][a-z0-9-]*', job_id):
        bad.append(job_id)

for b in bad:
    print(b)
EOF
)

  run echo "${bad_ids}"
  assert_output ""
}

# ---------------------------------------------------------------------------
# TS-152k [P1] — all jobs use runs-on: ubuntu-latest
# ---------------------------------------------------------------------------
@test "[P1][TS-152k] all CI jobs use runs-on: ubuntu-latest" {
  skip "RED PHASE — Task 2.7: verify all jobs are on ubuntu-latest"

  assert [ -f "${CI_YML}" ]

  # Count job IDs (scoped to the jobs: block) vs ubuntu-latest occurrences.
  # Use the same broad pattern as TS-152j ([A-Za-z][A-Za-z0-9_-]*) so ALL job
  # entries are counted — including any with invalid names (underscores, uppercase)
  # that TS-152j would flag separately. A narrow pattern like [a-z][a-z0-9-]* would
  # silently under-count invalid job names, letting a missing ubuntu-latest slip through.
  local job_count ubuntu_count
  job_count=$(python3 - "${CI_YML}" <<'PYEOF'
import re, sys
with open(sys.argv[1]) as f:
    content = f.read()
jobs_match = re.search(r'^jobs:\n(.*)', content, re.MULTILINE | re.DOTALL)
if not jobs_match:
    print(0)
    sys.exit(0)
jobs_block = jobs_match.group(1)
count = len(re.findall(r'^  [A-Za-z][A-Za-z0-9_-]*:', jobs_block, re.MULTILINE))
print(count)
PYEOF
)
  ubuntu_count=$(grep -c "ubuntu-latest" "${CI_YML}" || true)

  # Every job must have exactly one runs-on line with ubuntu-latest
  run python3 -c "
import sys
jc, uc = int(sys.argv[1]), int(sys.argv[2])
if uc < jc:
    print(f'FAIL: {jc} jobs but only {uc} ubuntu-latest occurrences')
    sys.exit(1)
" "${job_count}" "${ubuntu_count}"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-152l [P2] — sast job uploads SARIF via codeql-action/upload-sarif
# ---------------------------------------------------------------------------
@test "[P2][TS-152l] sast job uploads SARIF via github/codeql-action/upload-sarif" {
  skip "RED PHASE — Task 2.2: upload SARIF artifact using codeql-action/upload-sarif@v3"

  assert [ -f "${CI_YML}" ]

  run grep "upload-sarif" "${CI_YML}"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-152m [P2] — realm-lint smoke test: exits 0 against current valid realm-export.json
# ---------------------------------------------------------------------------
@test "[P2][TS-152m] scripts/lint-realm-export.py exits 0 against current realm-export.json (smoke)" {
  skip "RED PHASE — Task 3: implement lint-realm-export.py; must pass against current export"

  assert [ -f "${PROJECT_ROOT}/scripts/lint-realm-export.py" ]
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  # Pass explicit path so the script does not depend on CWD.
  run python3 "${PROJECT_ROOT}/scripts/lint-realm-export.py" \
    "${PROJECT_ROOT}/keycloak/realm-export.json"
  assert_success
  assert_output --partial "passed"
}

# ---------------------------------------------------------------------------
# TS-152n [P2] — ci.yml YAML is syntactically valid
# ---------------------------------------------------------------------------
@test "[P2][TS-152n] ci.yml is syntactically valid YAML (python3 yaml.safe_load)" {
  skip "RED PHASE — Task 2: after adding all CI jobs, verify YAML is parseable"

  assert [ -f "${CI_YML}" ]

  run python3 -c "
import yaml, sys
with open(sys.argv[1]) as f:
    yaml.safe_load(f)
print('ci.yml YAML is valid')
" "${CI_YML}"
  assert_success
  assert_output --partial "valid"
}

# ---------------------------------------------------------------------------
# TS-152o [P2] — scripts/ directory is not gitignored
# ---------------------------------------------------------------------------
@test "[P2][TS-152o] scripts/ directory is not listed in .gitignore" {
  skip "RED PHASE — Task 3: ensure scripts/ is not accidentally gitignored"

  assert [ -f "${PROJECT_ROOT}/.gitignore" ]

  # scripts/ or /scripts must NOT appear as a gitignore entry
  run grep -E "^/?scripts/?$" "${PROJECT_ROOT}/.gitignore"
  assert_failure
}
