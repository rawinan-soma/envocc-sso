#!/usr/bin/env bats
# =============================================================================
# ATDD Red-Phase Acceptance Tests — Story 1.1
# AC2: Secret hygiene — no secrets committed; gitleaks pre-commit + CI block any leak
#
# TDD Phase: RED — all tests are @skip until secret tooling is implemented.
# To activate: remove the `skip` call from the test you are implementing.
#
# Run:  bats tests/secrets/ac2-secret-hygiene.bats
# Deps: gitleaks, git, lefthook (optional for hook tests)
# Note: These tests are static/offline — no docker required.
# =============================================================================

# ---------------------------------------------------------------------------
# [P0] AC2-01 — gitleaks detects zero findings on realm-export.json
# ---------------------------------------------------------------------------
@test "[P0][AC2-01] realm-export.json passes gitleaks scan (zero findings)" {
  skip "RED PHASE — realm-export.json not yet created"

  [ -f "keycloak/realm-export.json" ] || {
    echo "keycloak/realm-export.json does not exist yet"
    return 1
  }

  # gitleaks must be installed
  command -v gitleaks >/dev/null 2>&1 || {
    echo "gitleaks not installed — install via: brew install gitleaks"
    return 1
  }

  run gitleaks detect --source keycloak/realm-export.json --no-git --verbose
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-02 — realm-export.json does NOT contain real clientSecret values
# ---------------------------------------------------------------------------
@test "[P0][AC2-02] realm-export.json has no real clientSecret values (must be empty string or absent)" {
  skip "RED PHASE — realm-export.json not yet created"

  [ -f "keycloak/realm-export.json" ]

  # clientSecret must be absent or set to empty string ""
  # This test fails if any clientSecret has a non-empty value
  if grep -o '"clientSecret":"[^"]*"' keycloak/realm-export.json | grep -v '"clientSecret":""'; then
    echo "FAIL: realm-export.json contains non-empty clientSecret values"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# [P0] AC2-03 — realm-export.json does NOT contain privateKey values
# ---------------------------------------------------------------------------
@test "[P0][AC2-03] realm-export.json has no real privateKey values" {
  skip "RED PHASE — realm-export.json not yet created"

  [ -f "keycloak/realm-export.json" ]

  if grep -o '"privateKey":"[^"]*"' keycloak/realm-export.json | grep -v '"privateKey":""'; then
    echo "FAIL: realm-export.json contains non-empty privateKey values"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# [P0] AC2-04 — realm-export.json does NOT contain secretData values
# ---------------------------------------------------------------------------
@test "[P0][AC2-04] realm-export.json has no real secretData values" {
  skip "RED PHASE — realm-export.json not yet created"

  [ -f "keycloak/realm-export.json" ]

  # secretData with a real value (non-empty JSON object or non-empty string) is forbidden
  if grep -o '"secretData":"[^"]*"' keycloak/realm-export.json | grep -v '"secretData":""' | grep -v '"secretData":"{}"'; then
    echo "FAIL: realm-export.json contains non-empty secretData values"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# [P0] AC2-05 — gitleaks scans the full repo working tree with zero findings
# ---------------------------------------------------------------------------
@test "[P0][AC2-05] Full repo passes gitleaks detect (no secrets anywhere)" {
  skip "RED PHASE — .gitleaks.toml and tooling not yet configured"

  command -v gitleaks >/dev/null 2>&1 || {
    echo "gitleaks not installed"
    return 1
  }

  [ -f ".gitleaks.toml" ] || {
    echo ".gitleaks.toml not found — create it first"
    return 1
  }

  run gitleaks detect --source . --no-git --config .gitleaks.toml --verbose
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-06 — .env is in .gitignore (must never be committed)
# ---------------------------------------------------------------------------
@test "[P0][AC2-06] .env is listed in .gitignore" {
  skip "RED PHASE — .gitignore not yet written"

  [ -f ".gitignore" ]
  run git check-ignore -q .env
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-07 — *.pem and *.key patterns are in .gitignore
# ---------------------------------------------------------------------------
@test "[P0][AC2-07] *.pem and *.key are in .gitignore" {
  skip "RED PHASE — .gitignore not yet written"

  [ -f ".gitignore" ]

  run git check-ignore -q dummy.pem
  [ "$status" -eq 0 ]

  run git check-ignore -q dummy.key
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-08 — admin/config/master.key is in .gitignore
# ---------------------------------------------------------------------------
@test "[P0][AC2-08] admin/config/master.key is excluded by .gitignore" {
  skip "RED PHASE — .gitignore not yet written"

  [ -f ".gitignore" ]
  run git check-ignore -q admin/config/master.key
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-09 — .kamal/secrets is in .gitignore
# ---------------------------------------------------------------------------
@test "[P0][AC2-09] .kamal/secrets is excluded by .gitignore" {
  skip "RED PHASE — .gitignore not yet written"

  [ -f ".gitignore" ]
  run git check-ignore -q .kamal/secrets
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P0] AC2-10 — .env.example IS tracked by git (must be committed)
# ---------------------------------------------------------------------------
@test "[P0][AC2-10] .env.example is tracked by git (not gitignored)" {
  skip "RED PHASE — .env.example not yet created"

  [ -f ".env.example" ]

  # git check-ignore returns exit 1 (not ignored) — we want NOT ignored
  run git check-ignore -q .env.example
  # status 1 = file is NOT ignored (correct)
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# [P1] AC2-11 — lefthook.yml exists and configures gitleaks protect --staged
# ---------------------------------------------------------------------------
@test "[P1][AC2-11] lefthook.yml exists with gitleaks pre-commit hook" {
  skip "RED PHASE — lefthook.yml not yet created"

  [ -f "lefthook.yml" ]
  grep -q "gitleaks" lefthook.yml
  grep -q "protect" lefthook.yml
  grep -q "staged" lefthook.yml
}

# ---------------------------------------------------------------------------
# [P1] AC2-12 — .github/workflows/ci.yml exists with a gitleaks job
# ---------------------------------------------------------------------------
@test "[P1][AC2-12] ci.yml contains a gitleaks detection job" {
  skip "RED PHASE — CI workflow not yet created"

  [ -f ".github/workflows/ci.yml" ]
  grep -q "gitleaks" .github/workflows/ci.yml
  grep -q "detect" .github/workflows/ci.yml
}

# ---------------------------------------------------------------------------
# [P1] AC2-13 — .gitleaks.toml exists at repo root
# ---------------------------------------------------------------------------
@test "[P1][AC2-13] .gitleaks.toml configuration file exists" {
  skip "RED PHASE — .gitleaks.toml not yet created"

  [ -f ".gitleaks.toml" ]
}

# ---------------------------------------------------------------------------
# [P1] AC2-14 — .gitleaks.toml allowlists placeholder values like 'change-me'
# ---------------------------------------------------------------------------
@test "[P1][AC2-14] .gitleaks.toml allows placeholder value 'change-me' in .env.example" {
  skip "RED PHASE — .gitleaks.toml not yet configured with allowlist"

  [ -f ".gitleaks.toml" ]
  [ -f ".env.example" ]

  command -v gitleaks >/dev/null 2>&1 || {
    echo "gitleaks not installed"
    return 1
  }

  # .env.example with placeholder values must NOT trigger gitleaks
  run gitleaks detect --source .env.example --no-git --config .gitleaks.toml
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# [P1] AC2-15 — gitleaks BLOCKS a staged file containing a fake secret pattern
#               (pre-commit hook behavioral test — requires lefthook installed)
# ---------------------------------------------------------------------------
@test "[P1][AC2-15] gitleaks protect --staged blocks commit of file with secret pattern" {
  skip "RED PHASE — lefthook and gitleaks not yet configured"

  command -v gitleaks >/dev/null 2>&1 || {
    echo "gitleaks not installed"
    return 1
  }

  command -v lefthook >/dev/null 2>&1 || {
    echo "lefthook not installed"
    return 1
  }

  # Create a temp file with an obvious fake secret pattern, stage it
  local tmpfile
  tmpfile=$(mktemp /tmp/test-secret-XXXX.env)
  echo 'AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY' > "$tmpfile"
  cp "$tmpfile" /tmp/test-secret-staged.env

  # Stage the file in the repo (if in git repo context)
  if git rev-parse --git-dir > /dev/null 2>&1; then
    cp /tmp/test-secret-staged.env test-secret-staged.env
    git add test-secret-staged.env

    # gitleaks protect --staged must exit non-zero (finds the secret)
    run gitleaks protect --staged --config .gitleaks.toml 2>&1
    local gitleaks_exit="$status"

    # Clean up
    git rm -f test-secret-staged.env 2>/dev/null || rm -f test-secret-staged.env
    git reset HEAD test-secret-staged.env 2>/dev/null || true

    # Must have found a secret (non-zero exit)
    [ "$gitleaks_exit" -ne 0 ]
  else
    skip "Not in a git repository context — skipping staged file test"
  fi

  rm -f "$tmpfile" /tmp/test-secret-staged.env
}
