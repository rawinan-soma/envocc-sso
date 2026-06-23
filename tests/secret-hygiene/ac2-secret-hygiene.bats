#!/usr/bin/env bats
# =============================================================================
# ATDD Acceptance Tests — Story 1.2
# AC2: Secret hygiene — no secrets committed; gitleaks clean export;
#      KeyProvider component group entirely absent (not blanked).
#
# TDD Phase: RED — all tests fail until:
#   - keycloak/realm-export.json exists (with secrets stripped)
#   - .gitignore, .gitleaks.toml, lefthook.yml exist
#   - gitleaks binary is available
#
# Run:  bats tests/secret-hygiene/ac2-secret-hygiene.bats
# Deps: gitleaks (brew install gitleaks), git, python3, bats-core
# Note: Static/offline — no Docker stack required.
# =============================================================================

# ---------------------------------------------------------------------------
# [P0] AC2-01 — gitleaks detects zero findings on realm-export.json
# ---------------------------------------------------------------------------
@test "[P0][AC2-01] realm-export.json passes gitleaks scan with zero findings" {
  [ -f "keycloak/realm-export.json" ] || {
    echo "keycloak/realm-export.json does not exist yet"; return 1
  }

  command -v gitleaks >/dev/null 2>&1 \
    || skip "gitleaks not installed — install via: brew install gitleaks"

  [ -f ".gitleaks.toml" ] || {
    echo ".gitleaks.toml not found"; return 1
  }

  run gitleaks detect \
    --source keycloak/realm-export.json \
    --no-git \
    --config .gitleaks.toml \
    --verbose
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-02 — realm-export.json has no real client secret values
# ---------------------------------------------------------------------------
@test "[P0][AC2-02] realm-export.json has no non-empty clientSecret or client secret fields" {
  [ -f "keycloak/realm-export.json" ]

  # clientSecret field must be absent or empty string
  if grep -o '"clientSecret":"[^"]*"' keycloak/realm-export.json \
      | grep -v '"clientSecret":""'; then
    echo "FAIL: realm-export.json contains non-empty clientSecret values"
    return 1
  fi

  # secret field on a client must be absent or empty string
  # (Key-provider HMAC/AES use the array form "secret":["..."] — covered by AC2-01)
  if grep -o '"secret":"[^"]*"' keycloak/realm-export.json \
      | grep -v '"secret":""'; then
    echo "FAIL: realm-export.json contains non-empty client secret values"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# [P0] AC2-03 — realm-export.json does NOT contain privateKey values
# ---------------------------------------------------------------------------
@test "[P0][AC2-03] realm-export.json has no real privateKey values" {
  [ -f "keycloak/realm-export.json" ]

  run python3 -c "
import json, sys
with open('keycloak/realm-export.json') as f:
    data = json.load(f)
def scan(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == 'privateKey':
                if isinstance(v, str) and len(v) > 0:
                    print(f'FAIL: non-empty privateKey string: {repr(v[:30])}')
                    sys.exit(1)
                elif isinstance(v, list):
                    for item in v:
                        if isinstance(item, str) and len(item) > 0:
                            print(f'FAIL: non-empty privateKey list item: {repr(item[:30])}')
                            sys.exit(1)
            else:
                scan(v)
    elif isinstance(obj, list):
        for item in obj:
            scan(item)
scan(data)
print('OK')
"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-04 — KeyProvider component group is ENTIRELY ABSENT (not blanked)
# ---------------------------------------------------------------------------
# Critical: committing a blanked privateKey:[""] causes InvalidKeySpecException
# on Keycloak 26 --import-realm. The entire KeyProvider group must be absent.
# Keycloak auto-generates fresh keys when the group is missing.
@test "[P0][AC2-04] realm-export.json has NO KeyProvider component group (must be entirely absent)" {
  [ -f "keycloak/realm-export.json" ]

  run python3 -c "
import json, sys
with open('keycloak/realm-export.json') as f:
    data = json.load(f)
components = data.get('components', {})
keyprovider_group = 'org.keycloak.keys.KeyProvider'
if keyprovider_group in components:
    entries = components[keyprovider_group]
    print(f'FAIL: KeyProvider group present with {len(entries)} entries')
    for entry in entries[:3]:
        print(f'  - {entry.get(\"name\", \"?\")} (providerId={entry.get(\"providerId\", \"?\")})')
    sys.exit(1)
print('OK: KeyProvider group is absent')
"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-05 — realm-export.json has no real secretData values
# ---------------------------------------------------------------------------
@test "[P0][AC2-05] realm-export.json has no non-empty secretData values" {
  [ -f "keycloak/realm-export.json" ]

  # secretData with a real value (non-empty JSON object or non-empty string) is forbidden
  if grep -o '"secretData":"[^"]*"' keycloak/realm-export.json \
      | grep -v '"secretData":""' \
      | grep -v '"secretData":"{}"'; then
    echo "FAIL: realm-export.json contains non-empty secretData values"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# [P0] AC2-06 — Full repo passes gitleaks detect with zero findings
# ---------------------------------------------------------------------------
@test "[P0][AC2-06] Full repo passes gitleaks detect --no-git with zero findings" {
  command -v gitleaks >/dev/null 2>&1 \
    || skip "gitleaks not installed — install via: brew install gitleaks"

  [ -f ".gitleaks.toml" ] || { echo ".gitleaks.toml not found"; return 1; }

  run gitleaks detect --source . --no-git --config .gitleaks.toml --verbose
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-07 — .env is listed in .gitignore
# ---------------------------------------------------------------------------
@test "[P0][AC2-07] .env is git-ignored (must never be committed)" {
  [ -f ".gitignore" ]
  run git check-ignore -q .env
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-08 — *.pem and *.key patterns are in .gitignore
# ---------------------------------------------------------------------------
@test "[P0][AC2-08] *.pem and *.key are git-ignored" {
  [ -f ".gitignore" ]

  run git check-ignore -q dummy.pem
  [ "$status" -eq 0 ]

  run git check-ignore -q dummy.key
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-09 — .env.example IS tracked (not gitignored) — must be committed
# ---------------------------------------------------------------------------
@test "[P0][AC2-09] .env.example is NOT git-ignored (must be committed)" {
  [ -f ".env.example" ]

  # git check-ignore returns exit 1 when the file is NOT ignored (correct)
  run git check-ignore -q .env.example
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-10 — gitleaks passes on .env.example (placeholder values allowed)
# ---------------------------------------------------------------------------
@test "[P0][AC2-10] .env.example passes gitleaks (placeholder values are allowlisted)" {
  [ -f ".env.example" ]
  [ -f ".gitleaks.toml" ]

  command -v gitleaks >/dev/null 2>&1 \
    || skip "gitleaks not installed"

  run gitleaks detect \
    --source .env.example \
    --no-git \
    --config .gitleaks.toml
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P1] AC2-11 — lefthook.yml exists with gitleaks protect --staged hook
# ---------------------------------------------------------------------------
@test "[P1][AC2-11] lefthook.yml exists with gitleaks pre-commit hook" {
  # RED: will fail until lefthook.yml is created
  [ -f "lefthook.yml" ]
  grep -q "gitleaks" lefthook.yml
  grep -q "protect" lefthook.yml
  grep -q "staged" lefthook.yml
}

# ---------------------------------------------------------------------------
# [P1] AC2-12 — lefthook.yml includes keycloak-realm-lint pre-commit step (Story 1.2 AC)
# ---------------------------------------------------------------------------
@test "[P1][AC2-12] lefthook.yml includes a keycloak-realm-lint pre-commit step" {
  [ -f "lefthook.yml" ]
  grep -q "keycloak-realm-lint" lefthook.yml
}

# ---------------------------------------------------------------------------
# [P1] AC2-13 — keycloak/lint-realm.sh exists and asserts security settings
# ---------------------------------------------------------------------------
@test "[P1][AC2-13] keycloak/lint-realm.sh exists and checks required security settings" {
  # RED: will fail until lint-realm.sh is created
  [ -f "keycloak/lint-realm.sh" ]
  [ -x "keycloak/lint-realm.sh" ] || chmod +x keycloak/lint-realm.sh

  # Must assert at least the required security settings
  grep -q "bruteForceProtected" keycloak/lint-realm.sh
  grep -q "accessTokenLifespan" keycloak/lint-realm.sh
  grep -q "sslRequired" keycloak/lint-realm.sh
  grep -q "registrationAllowed" keycloak/lint-realm.sh
  grep -q "eventsEnabled" keycloak/lint-realm.sh
}

# ---------------------------------------------------------------------------
# [P1] AC2-14 — lint-realm.sh passes on the current realm-export.json
# ---------------------------------------------------------------------------
@test "[P1][AC2-14] keycloak/lint-realm.sh passes on keycloak/realm-export.json" {
  [ -f "keycloak/lint-realm.sh" ]
  [ -f "keycloak/realm-export.json" ]
  [ -x "keycloak/lint-realm.sh" ] || chmod +x keycloak/lint-realm.sh

  run bash keycloak/lint-realm.sh keycloak/realm-export.json
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P1] AC2-15 — .gitleaks.toml exists at repo root
# ---------------------------------------------------------------------------
@test "[P1][AC2-15] .gitleaks.toml configuration file exists at repo root" {
  [ -f ".gitleaks.toml" ]
}

# ---------------------------------------------------------------------------
# [P1] AC2-16 — gitleaks protect --staged blocks staged fake-secret (behavioral)
# ---------------------------------------------------------------------------
@test "[P1][AC2-16] gitleaks protect --staged blocks commit of staged file with secret pattern" {
  command -v gitleaks >/dev/null 2>&1 \
    || skip "gitleaks not installed"

  git rev-parse --git-dir > /dev/null 2>&1 \
    || skip "Not in a git repository context"

  # Stage a fake-secret file at repo root (NOT under tests/ allowlist path)
  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  local staged="${repo_root}/test-fake-secret-staged.txt"

  # A non-placeholder Keycloak admin password — caught by the custom gitleaks rule
  echo 'KEYCLOAK_ADMIN_PASSWORD=Xy9Zq2Lm8Bv4Nc7Rt1Wp' > "$staged"
  git -C "$repo_root" add -f "test-fake-secret-staged.txt"

  # gitleaks protect --staged must exit non-zero (detects the secret)
  run gitleaks protect --staged --config "${repo_root}/.gitleaks.toml"
  local gitleaks_exit="$status"

  # Cleanup: unstage and remove temp file regardless of outcome
  git -C "$repo_root" reset -q HEAD "test-fake-secret-staged.txt" 2>/dev/null || true
  rm -f "$staged"

  # Assert gitleaks found a secret (non-zero exit)
  [ "$gitleaks_exit" -ne 0 ]
}

# ---------------------------------------------------------------------------
# [P2] AC2-17 — REALM-EXPORT-NOTES.md documents the round-trip and stripped fields
# ---------------------------------------------------------------------------
@test "[P2][AC2-17] keycloak/REALM-EXPORT-NOTES.md documents stripped fields and KeyProvider omission" {
  # RED: will fail until REALM-EXPORT-NOTES.md is created
  [ -f "keycloak/REALM-EXPORT-NOTES.md" ]
  grep -q "clientSecret" keycloak/REALM-EXPORT-NOTES.md
  grep -q "privateKey" keycloak/REALM-EXPORT-NOTES.md
  grep -q "KeyProvider" keycloak/REALM-EXPORT-NOTES.md
}

# ---------------------------------------------------------------------------
# [P2] AC2-18 — PINNED-VERSION.md exists and records 26.6.x tag + digest
# ---------------------------------------------------------------------------
@test "[P2][AC2-18] keycloak/PINNED-VERSION.md records the Keycloak 26.6.x tag and digest" {
  # RED: will fail until PINNED-VERSION.md is created
  [ -f "keycloak/PINNED-VERSION.md" ]
  # Must reference 26.6.x version
  grep -qE "26\.6\." keycloak/PINNED-VERSION.md
  # Must include a digest (sha256)
  grep -q "sha256" keycloak/PINNED-VERSION.md
}
