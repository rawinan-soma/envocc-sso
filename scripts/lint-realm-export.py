#!/usr/bin/env python3
"""lint-realm-export.py — Validate keycloak/realm-export.json for story 1.5.

Checks performed:
  1. JSON is parseable.
  2. Required baseline fields are present: realm, enabled, bruteForceProtected,
     accessTokenLifespan.
  3. No key material embedded: privateKey/certificate values >= 64 chars,
     clientSecret/secret values >= 8 chars — in either the plain string form
     ("privateKey": "...") or the array form ("privateKey": ["..."]) that
     Keycloak actually emits for KeyProvider config — anywhere in the document
     (mirrors .gitleaks.toml rules).

Exit codes:
  0 — all checks passed
  1 — one or more checks failed (error details printed to stderr)
"""

import json
import sys
from pathlib import Path

# Default path (resolved relative to CWD, expected to be repo root).
# An explicit path argument overrides this — used by tests and ad-hoc invocations.
_DEFAULT_PATH = Path("keycloak/realm-export.json")
REALM_EXPORT_PATH = Path(sys.argv[1]) if len(sys.argv) > 1 else _DEFAULT_PATH

REQUIRED_FIELDS = [
    "realm",
    "enabled",
    "bruteForceProtected",
    "accessTokenLifespan",
]

# Key-material thresholds mirror gitleaks rules for defense-in-depth.
# Keycloak emits these both as plain strings ("privateKey": "...") and as
# single-element arrays ("privateKey": ["..."]) — the gitleaks rules match
# both forms, so this script must too. "secret" covers Keycloak client
# secrets and HMAC/AES key-provider secrets (gitleaks: clientSecret|secret).
# Values >= the threshold are flagged (mirrors gitleaks {N,} quantifier).
KEY_MATERIAL_THRESHOLDS = {
    "privateKey": 64,
    "certificate": 64,
    "clientSecret": 8,
    "secret": 8,
}


def _string_values(value):
    """Yield string values held directly by `value`.

    Handles both the plain string form and the single/multi-element array
    form Keycloak uses for key-provider config (e.g. "privateKey": ["..."]).
    """
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            if isinstance(item, str):
                yield item


def find_key_material(obj, path="$"):
    """Recursively scan a parsed JSON object for key-material fields.

    Yields (json_path, field_name, value_length) for each violation found.
    """
    if isinstance(obj, dict):
        for key, value in obj.items():
            child_path = f"{path}.{key}"
            if key in KEY_MATERIAL_THRESHOLDS:
                threshold = KEY_MATERIAL_THRESHOLDS[key]
                for sval in _string_values(value):
                    if len(sval) >= threshold:
                        yield (child_path, key, len(sval))
            if isinstance(value, (dict, list)):
                yield from find_key_material(value, child_path)
    elif isinstance(obj, list):
        for idx, item in enumerate(obj):
            yield from find_key_material(item, f"{path}[{idx}]")


def main():
    errors = []

    # ── Step 1: Verify the file exists ────────────────────────────────────────
    if not REALM_EXPORT_PATH.exists():
        print(
            f"ERROR: {REALM_EXPORT_PATH} not found. "
            "Run this script from the repository root.",
            file=sys.stderr,
        )
        sys.exit(1)

    # ── Step 2: Parse JSON ─────────────────────────────────────────────────────
    try:
        with REALM_EXPORT_PATH.open(encoding="utf-8") as fh:
            data = json.load(fh)
    except json.JSONDecodeError as exc:
        print(
            f"ERROR: {REALM_EXPORT_PATH} is not valid JSON: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)
    except OSError as exc:
        print(
            f"ERROR: Cannot read {REALM_EXPORT_PATH}: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)

    # ── Step 3: Assert the document is a JSON object ───────────────────────────
    if not isinstance(data, dict):
        print(
            f"ERROR: {REALM_EXPORT_PATH} must contain a JSON object at the top "
            f"level, got {type(data).__name__}.",
            file=sys.stderr,
        )
        sys.exit(1)

    # ── Step 4: Assert required baseline fields ────────────────────────────────
    for field in REQUIRED_FIELDS:
        if field not in data:
            errors.append(
                f"Missing required field '{field}' in realm-export.json top-level object."
            )

    # ── Step 5: Scan for embedded key material ─────────────────────────────────
    for json_path, field_name, value_len in find_key_material(data):
        errors.append(
            f"Key material detected at {json_path}: "
            f"'{field_name}' value length {value_len} meets or exceeds key-material threshold "
            f"({KEY_MATERIAL_THRESHOLDS[field_name]} chars). "
            "Remove key material from realm-export.json before committing."
        )

    # ── Step 6: Report and exit ────────────────────────────────────────────────
    if errors:
        print("realm-export.json FAILED lint:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)

    print("realm-export.json passed lint.")
    sys.exit(0)


if __name__ == "__main__":
    main()
