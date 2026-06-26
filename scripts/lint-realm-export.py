#!/usr/bin/env python3
"""lint-realm-export.py — Validate keycloak/realm-export.json for story 1.5.

Checks performed:
  1. JSON is parseable.
  2. Required baseline fields are present: realm, enabled, bruteForceProtected,
     accessTokenLifespan.
  3. No key material embedded: privateKey values > 64 chars, or clientSecret
     values > 8 chars anywhere in the document (mirrors .gitleaks.toml rules).

Exit codes:
  0 — all checks passed
  1 — one or more checks failed (error details printed to stderr)
"""

import json
import sys
from pathlib import Path

REALM_EXPORT_PATH = Path("keycloak/realm-export.json")

REQUIRED_FIELDS = [
    "realm",
    "enabled",
    "bruteForceProtected",
    "accessTokenLifespan",
]

# Key-material thresholds mirror gitleaks rules for defense-in-depth.
KEY_MATERIAL_RULES = [
    ("privateKey", 64),
    ("certificate", 64),
    ("clientSecret", 8),
]


def find_key_material(obj, path="$"):
    """Recursively scan a parsed JSON object for key-material fields.

    Yields (json_path, field_name, value_length) for each violation found.
    """
    if isinstance(obj, dict):
        for key, value in obj.items():
            child_path = f"{path}.{key}"
            if isinstance(value, str):
                for field_name, max_len in KEY_MATERIAL_RULES:
                    if key == field_name and len(value) > max_len:
                        yield (child_path, field_name, len(value))
            elif isinstance(value, (dict, list)):
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

    # ── Step 3: Assert required baseline fields ────────────────────────────────
    for field in REQUIRED_FIELDS:
        if field not in data:
            errors.append(
                f"Missing required field '{field}' in realm-export.json top-level object."
            )

    # ── Step 4: Scan for embedded key material ─────────────────────────────────
    for json_path, field_name, value_len in find_key_material(data):
        errors.append(
            f"Key material detected at {json_path}: "
            f"'{field_name}' value length {value_len} exceeds allowed maximum "
            f"({dict(KEY_MATERIAL_RULES)[field_name]} chars). "
            "Remove key material from realm-export.json before committing."
        )

    # ── Step 5: Report and exit ────────────────────────────────────────────────
    if errors:
        print("realm-export.json FAILED lint:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)

    print("realm-export.json passed lint.")
    sys.exit(0)


if __name__ == "__main__":
    main()
