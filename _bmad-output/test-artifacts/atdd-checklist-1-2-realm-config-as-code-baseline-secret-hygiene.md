---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-06-25'
storyId: '1.2'
storyKey: 1-2-realm-config-as-code-baseline-secret-hygiene
storyFile: _bmad-output/implementation-artifacts/1-2-realm-config-as-code-baseline-secret-hygiene.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-2-realm-config-as-code-baseline-secret-hygiene.md
generatedTestFiles:
  - tests/unit/secret-hygiene.bats
  - tests/integration/realm-import.bats
inputDocuments:
  - _bmad-output/implementation-artifacts/1-2-realm-config-as-code-baseline-secret-hygiene.md
  - _bmad-output/planning-artifacts/architecture.md
  - tests/unit/secret-hygiene.bats
  - tests/integration/stack-boot.bats
  - tests/integration/db-isolation.bats
  - tests/helpers/common.bash
  - _bmad/tea/config.yaml
---

# ATDD Checklist: Story 1.2 — Realm config-as-code baseline & secret hygiene

## Context

**Story:** 1.2 — Realm config-as-code baseline & secret hygiene
**Epic:** 1 — Secure Platform Foundation
**Stack detected:** backend (BATS — no frontend framework)
**Execution mode:** sequential (single-agent)
**TDD phase:** RED (all tests are skip-guarded scaffolds)

---

## TDD Red Phase (Current)

All test scaffolds are in RED phase — they are `skip`-guarded and document **expected behavior** before implementation.

| File | Tests | Status |
|------|-------|--------|
| `tests/unit/secret-hygiene.bats` | 20 total (11 new Story 1.2) | RED — skip-guarded |
| `tests/integration/realm-import.bats` | 12 new Story 1.2 | RED — skip-guarded |

**Total new tests for Story 1.2:** 23 (11 unit + 12 integration)

---

## Acceptance Criteria Coverage

### AC1 — Realm auto-imports on bring-up

> Given `keycloak/realm-export.json` in git, when the stack starts (`docker compose up`), then the realm is imported automatically and baseline settings are applied without manual intervention.

| Test Scenario | File | Priority | Skip Guard | Coverage |
|--------------|------|----------|------------|----------|
| `[TS-104j]` Dockerfile CMD includes `--import-realm` | `tests/unit/secret-hygiene.bats` | P0 | None (static) | Dockerfile wiring |
| `[TS-104k]` Dockerfile COPYs realm-export.json into image | `tests/unit/secret-hygiene.bats` | P0 | None (static) | File placement |
| `[TS-104-realm-a]` realm-export.json exists and is valid JSON | `tests/unit/secret-hygiene.bats` | P0 | None (static) | File presence |
| `[TS-104-realm-f]` realm-export.json declares realm name 'envocc' | `tests/unit/secret-hygiene.bats` | P1 | None (static) | Realm name |
| `[TS-104-realm-g]` realm-export.json has enabled=true | `tests/unit/secret-hygiene.bats` | P1 | None (static) | Realm enabled |
| `[TS-104-realm-h]` git tracks keycloak/realm-export.json | `tests/unit/secret-hygiene.bats` | P1 | None (static) | Config-as-code |
| `[TS-201a]` OIDC discovery returns HTTP 200 for 'envocc' | `tests/integration/realm-import.bats` | P0 | Integration skip | Runtime proof |
| `[TS-201b]` OIDC issuer matches expected realm URL | `tests/integration/realm-import.bats` | P0 | Integration skip | Runtime proof |
| `[TS-201c]` Admin REST API confirms realm exists and is enabled | `tests/integration/realm-import.bats` | P0 | Integration skip | Runtime proof |
| `[TS-201d]` Baseline settings match realm-export.json (x5) | `tests/integration/realm-import.bats` | P1 | Integration skip | Config fidelity |
| `[TS-201e]` Fresh stack imports realm automatically | `tests/integration/realm-import.bats` | P1 | Destructive skip | End-to-end AC1 |

### AC2 — Realm file is gitleaks-clean

> Given the exported realm file, when I inspect it (and run `gitleaks detect`), then it contains no client secrets, passwords, or signing-key material.

| Test Scenario | File | Priority | Skip Guard | Coverage |
|--------------|------|----------|------------|----------|
| `[TS-104-realm-b]` realm-export.json passes gitleaks scan | `tests/unit/secret-hygiene.bats` | P0 | None (static) | Full gitleaks gate |
| `[TS-104-realm-c]` No populated `privateKey` fields | `tests/unit/secret-hygiene.bats` | P0 | None (static) | Signing key |
| `[TS-104-realm-d]` No populated `certificate` fields ≥64 chars | `tests/unit/secret-hygiene.bats` | P0 | None (static) | X.509 cert |
| `[TS-104-realm-e]` No populated `clientSecret`/`secret` fields ≥8 chars | `tests/unit/secret-hygiene.bats` | P0 | None (static) | Client creds |

### AC3 — Realm change round-trip

> Given a realm change made through the Keycloak Admin UI, when it is exported back to the repo, then the resulting diff is reviewable and the updated file is re-importable on a fresh stack.

| Test Scenario | File | Priority | Skip Guard | Coverage |
|--------------|------|----------|------------|----------|
| `[TS-201f]` Round-trip: export → strip → reimport on fresh stack | `tests/integration/realm-import.bats` | P1 | Manual skip | Full AC3 |
| `[TS-201g]` IGNORE_EXISTING: runtime change survives KC restart | `tests/integration/realm-import.bats` | P2 | Integration skip | Import strategy |

---

## Test Priority Summary

| Priority | Count | Notes |
|----------|-------|-------|
| P0 | 12 | Critical — all must pass before story is done |
| P1 | 9 | Important — baseline settings and config-as-code |
| P2 | 2 | Nice-to-have — edge cases |

---

## Static vs Integration Split

| Category | Count | Requires Stack |
|----------|-------|----------------|
| Static (unit, no live stack) | 14 | No — run with `bats tests/unit/` |
| Integration (skip-guarded) | 12 | Yes — run after `docker compose up --build` |
| Destructive (skip-guarded) | 1 | Yes — `down -v` + `up` required |
| Manual (skip-guarded) | 1 | Yes — requires manual export procedure |

---

## Next Steps: Task-by-Task Activation

During Story 1.2 implementation, activate tests as each task completes:

### Task 1 (Extend Keycloak Dockerfile) → Activate:
```
Remove skip guard from: [TS-104j], [TS-104k]
Run: bats tests/unit/secret-hygiene.bats
Verify: TS-104j FAILS (--import-realm not in CMD yet) → add it → TS-104j PASSES
```

### Task 2 (Create realm-export.json) → Activate:
```
Remove skip guard from: [TS-104-realm-a], [TS-104-realm-f], [TS-104-realm-g], [TS-104-realm-h]
Run: bats tests/unit/secret-hygiene.bats
Verify: all FAIL first (file absent) → create file → all PASS
```

### Task 3 (Secret hygiene verification) → Activate:
```
Remove skip guard from: [TS-104-realm-b], [TS-104-realm-c], [TS-104-realm-d], [TS-104-realm-e]
Run: bats tests/unit/secret-hygiene.bats
Verify: FAIL if secrets present → strip → PASS
```

### Task 6 (End-to-end verification) → Activate:
```
After docker compose up --build:
Remove skip guard from: [TS-201a], [TS-201b], [TS-201c], [TS-201d], [TS-201e]
Run: bats tests/integration/realm-import.bats
Verify: FAIL before import wiring → stack up → PASS
```

---

## Implementation Notes

- **No new test framework:** Vitest/Playwright arrives in Story 4.1. This story uses BATS (established in Story 1.1).
- **Regression guard:** existing Story 1.1 tests (`version-pinning.bats`, `secret-hygiene.bats` original scenarios) must continue passing.
- **gitleaks required:** `gitleaks` binary must be in `$PATH` for `[TS-104-realm-b]` to run (not skip-guarded — expected to run as static check once file exists).
- **`bats-support` / `bats-assert`:** vendored in `tests/lib/` (gitignored). Set `BATS_LIB_PATH=$(pwd)/tests/lib` before running.

---

## ATDD Artifacts

- **Checklist:** `_bmad-output/test-artifacts/atdd-checklist-1-2-realm-config-as-code-baseline-secret-hygiene.md`
- **Unit tests (extended):** `tests/unit/secret-hygiene.bats` (Story 1.2 additions at bottom)
- **Integration tests (new):** `tests/integration/realm-import.bats`
