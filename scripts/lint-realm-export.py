#!/usr/bin/env python3
"""lint-realm-export.py — Validate keycloak/realm-export.json.

Checks performed:
  1. JSON is parseable.
  2. Required baseline fields are present: realm, enabled, bruteForceProtected,
     accessTokenLifespan, revokeRefreshToken, refreshTokenMaxReuse.
  3. Value validation (Story 2.4 — AC6/AR8), type-strict so a string/float/bool
     cannot fail the check open:
     - accessTokenLifespan: integer <= 900 s (NFR2a: 15-minute hard ceiling)
     - revokeRefreshToken == true (FR9: family revocation on replay)
     - refreshTokenMaxReuse == integer 0 (FR9: rotate on every use)
  4. No key material embedded: privateKey/certificate values >= 64 chars,
     clientSecret/secret values >= 8 chars — in either the plain string form
     ("privateKey": "...") or the array form ("privateKey": ["..."]) that
     Keycloak actually emits for KeyProvider config — anywhere in the document
     (mirrors .gitleaks.toml rules).
  4. Value-level checks (Story 2.1 — closes deferred gap from Story 1.5 review):
     - duplicateEmailsAllowed must be boolean false (not merely present)
     - registrationAllowed must be boolean false (not merely present)
     - loginWithEmailAllowed must be boolean true (email reconciliation key, FR22)
     - bruteForceProtected must be boolean true (brute-force protection cannot be disabled)
     - enabled must be boolean true (realm must be enabled)
     Each value must be the exact boolean type — a JSON integer 0/1 does not pass.
  5. (Story 2.2) accessCodeLifespan is present AND its value is <= 60 seconds.
  6. (Story 2.2) Per-client: implicitFlowEnabled is not true (must be false or absent).
  7. (Story 2.2) Per-client: directAccessGrantsEnabled is not true (Keycloak default
     is true — must be explicitly false).
  8. (Story 2.2) Per public client: attributes.pkce.code.challenge.method must be "S256".
  9. (Story 2.2) Per public client: standardFlowEnabled must be true (Authorization Code
     flow must be explicitly enabled — it is the only permitted flow for PKCE clients).

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
    "revokeRefreshToken",
    "refreshTokenMaxReuse",
]

# Value-level boolean checks (Story 2.1 — closes deferred gap from Story 1.5 review).
# Each entry is (field_name, expected_value).  The field must exist AND hold the
# exact expected value — presence-only checks are insufficient for security-critical
# settings like duplicateEmailsAllowed and registrationAllowed.
# bruteForceProtected and enabled are also checked here (not just in REQUIRED_FIELDS)
# so that a wrong value (e.g. bruteForceProtected: false) is caught, not just absence.
REQUIRED_VALUES: list[tuple[str, object]] = [
    ("duplicateEmailsAllowed", False),
    ("registrationAllowed", False),
    ("loginWithEmailAllowed", True),
    ("bruteForceProtected", True),
    ("enabled", True),
]

# NFR2a: access/ID tokens must not exceed 15 minutes (900 seconds).
MAX_ACCESS_TOKEN_LIFESPAN = 900

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

# Maximum allowed authorization code lifetime (Story 2.2, AC4, FR47).
ACCESS_CODE_LIFESPAN_MAX = 60


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


def lint_clients(clients):
    """Check per-client Story 2.2 security constraints.

    Returns a list of error message strings.
    Each message embeds the clientId for debuggability (Task 3.5).
    """
    client_errors = []

    if not isinstance(clients, list):
        return client_errors  # malformed — top-level JSON check covers this

    for idx, client in enumerate(clients):
        if not isinstance(client, dict):
            # Skip non-dict entries with a warning (not an error)
            print(
                f"WARNING: clients[{idx}] is not a JSON object — skipping per-client checks.",
                file=sys.stderr,
            )
            continue

        client_id = client.get("clientId", f"<unknown client at index {idx}>")

        # ── Check 5: implicitFlowEnabled must not be true ────────────────────
        # Anything other than an explicit `false` (or absence, which Keycloak
        # defaults to false) is a violation — this also catches non-canonical
        # truthy values such as `1` or `"true"` that identity checks would miss.
        implicit = client.get("implicitFlowEnabled", False)
        if implicit is not False:
            client_errors.append(
                f"[{client_id}] implicitFlowEnabled is {implicit!r} — "
                "Implicit grant must be disabled (set to false or omit)."
            )

        # ── Check 6: directAccessGrantsEnabled must not be true ─────────────
        # Keycloak default is true — absence is NOT safe; it must be explicitly
        # false. Flag absence and any non-false value (including truthy non-bool
        # values like `1` or `"true"`).
        ropc = client.get("directAccessGrantsEnabled", "<absent>")
        if ropc is not False:
            client_errors.append(
                f"[{client_id}] directAccessGrantsEnabled is {ropc!r} — "
                "ROPC must be explicitly disabled (set to false). "
                "Keycloak default is true."
            )

        # ── Check 7 + 8: public clients must have PKCE S256 and standard flow ─
        if client.get("publicClient") is True:
            attrs = client.get("attributes")
            pkce_method = None
            if isinstance(attrs, dict):
                pkce_method = attrs.get("pkce.code.challenge.method")
            if pkce_method != "S256":
                client_errors.append(
                    f"[{client_id}] publicClient is true but "
                    "attributes.pkce.code.challenge.method is not 'S256' "
                    f"(got: {pkce_method!r}). "
                    "PKCE S256 must be enforced on all public clients."
                )

            # ── Check 8: standardFlowEnabled must be true on public PKCE clients ─
            # Authorization Code flow is the only flow permitted for PKCE clients.
            # Without standardFlowEnabled: true the client cannot initiate any
            # auth request, making the PKCE constraint moot.
            if client.get("standardFlowEnabled") is not True:
                client_errors.append(
                    f"[{client_id}] publicClient is true but "
                    f"standardFlowEnabled is {client.get('standardFlowEnabled', '<absent>')!r} — "
                    "Authorization Code flow must be explicitly enabled "
                    "(set to true) on all public PKCE clients."
                )

    return client_errors


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

    # ── Step 4b: Assert value-level security settings (Story 2.1) ─────────────
    # Presence-only checks are insufficient — a field set to the wrong value is
    # as dangerous as a missing field.  These checks mirror the realm AC requirements:
    #   - duplicateEmailsAllowed: false  → enforces email uniqueness (FR22, AC1)
    #   - registrationAllowed: false     → disables public self-registration (scope boundary)
    #   - loginWithEmailAllowed: true    → email is the reconciliation key (FR22, AC1)
    #   - bruteForceProtected: true      → brute-force protection must not be disabled
    #   - enabled: true                  → realm must be enabled
    # The type check rejects JSON integers (0/1) and strings ("false") that would
    # otherwise satisfy a loose `!=` comparison because Python treats 0 == False.
    for field, expected in REQUIRED_VALUES:
        if field not in data:
            errors.append(
                f"Missing required field '{field}' in realm-export.json top-level object "
                f"(expected value: {expected!r})."
            )
        elif not isinstance(data[field], bool) or data[field] != expected:
            errors.append(
                f"Security misconfiguration: '{field}' must be boolean {expected!r} but got "
                f"{data[field]!r} ({type(data[field]).__name__}) in realm-export.json. "
                f"This is a value-level check — presence alone is not sufficient."
            )

    # ── Step 5: Value-validate security-critical lifetime fields (Story 2.4) ────
    # Each check runs only when the field is present — a missing field is already
    # reported by Step 4, so guarding here avoids a redundant second error.
    # Type handling is strict: these fields must hold the JSON type Keycloak
    # expects (integer seconds / boolean), so a string, float, or boolean where
    # an integer is required is rejected rather than silently coerced. Note that
    # `bool` subclasses `int` in Python, so `isinstance(x, bool)` is excluded
    # explicitly to stop `true`/`false` slipping through the integer checks.
    if "accessTokenLifespan" in data:
        atl = data["accessTokenLifespan"]
        if not isinstance(atl, int) or isinstance(atl, bool):
            errors.append(
                "accessTokenLifespan must be an integer number of seconds, "
                f"got {atl!r}."
            )
        elif atl > MAX_ACCESS_TOKEN_LIFESPAN:
            errors.append(
                f"accessTokenLifespan {atl}s exceeds NFR2a 15-minute ceiling "
                f"({MAX_ACCESS_TOKEN_LIFESPAN}s max)."
            )

    # `is not True` correctly rejects null, 0, 1, and false — only the boolean
    # `true` singleton passes (JSON null → Python None).
    if "revokeRefreshToken" in data and data["revokeRefreshToken"] is not True:
        errors.append(
            "revokeRefreshToken must be true (FR9: family revocation on replay)."
        )

    if "refreshTokenMaxReuse" in data:
        rtmr = data["refreshTokenMaxReuse"]
        if not isinstance(rtmr, int) or isinstance(rtmr, bool) or rtmr != 0:
            errors.append(
                "refreshTokenMaxReuse must be 0 (FR9: rotate on every use)."
            )

    # ── Step 6: Scan for embedded key material (defense-in-depth vs gitleaks) ──
    for json_path, field_name, value_len in find_key_material(data):
        errors.append(
            f"Key material detected at {json_path}: "
            f"'{field_name}' value length {value_len} meets or exceeds key-material threshold "
            f"({KEY_MATERIAL_THRESHOLDS[field_name]} chars). "
            "Remove key material from realm-export.json before committing."
        )

    # ── Step 6 (Story 2.2): Assert accessCodeLifespan present and <= 60 ───────
    if "accessCodeLifespan" not in data:
        errors.append(
            "Missing required field 'accessCodeLifespan' — "
            "authorization code lifetime must be explicitly set "
            f"(<= {ACCESS_CODE_LIFESPAN_MAX}s, AC4/FR47)."
        )
    else:
        lifespan = data["accessCodeLifespan"]
        # bool is a subclass of int in Python — reject it explicitly so a JSON
        # `true`/`false` is not silently treated as a 1/0-second lifespan.
        # Require a positive integer in [1, ACCESS_CODE_LIFESPAN_MAX]; a zero,
        # negative, float, NaN, or boolean value is a misconfiguration.
        if (
            not isinstance(lifespan, int)
            or isinstance(lifespan, bool)
            or lifespan < 1
            or lifespan > ACCESS_CODE_LIFESPAN_MAX
        ):
            errors.append(
                f"accessCodeLifespan is {lifespan!r} — "
                f"value must be an integer between 1 and {ACCESS_CODE_LIFESPAN_MAX} "
                "seconds (AC4/FR47)."
            )

    # ── Step 7 (Story 2.2): Per-client security checks ────────────────────────
    clients = data.get("clients")
    if clients is not None:
        if not isinstance(clients, list):
            errors.append(
                f"'clients' must be a JSON array, got {type(clients).__name__} — "
                "per-client security checks cannot be performed."
            )
        else:
            for msg in lint_clients(clients):
                errors.append(msg)

    # ── Step 8 (Story 2.3): Assert RSA key provider component present (AC9) ────
    components = data.get("components")
    if not isinstance(components, dict):
        errors.append(
            "Missing 'components' key in realm-export.json. "
            "An RSA key provider component is required for config-as-code compliance (AC7, AC9). "
            "Add a 'components' section with an 'org.keycloak.keys.KeyProvider' entry."
        )
    else:
        key_providers = components.get("org.keycloak.keys.KeyProvider")
        if not isinstance(key_providers, list) or len(key_providers) == 0:
            errors.append(
                "No 'org.keycloak.keys.KeyProvider' entries found under 'components' in realm-export.json. "
                "At least one RSA key provider is required for deterministic token signing (AC7, AC9). "
                "Add an 'rsa-generated' provider with keySize=2048, active=true, enabled=true."
            )
        else:
            has_active_rsa = False
            for idx, entry in enumerate(key_providers):
                entry_path = f"$.components.org.keycloak.keys.KeyProvider[{idx}]"
                # Guard: a malformed export may contain a non-object entry
                # (e.g. a bare string/number). Skip it gracefully instead of
                # raising an AttributeError traceback.
                if not isinstance(entry, dict):
                    continue

                config = entry.get("config", {})
                if not isinstance(config, dict):
                    config = {}

                # Identify an RSA signing provider that is both active and enabled.
                # Config values in a Keycloak export are arrays of strings.
                provider_id = entry.get("providerId", "")
                is_rsa = isinstance(provider_id, str) and provider_id.startswith("rsa")
                active = "true" in [str(v).lower() for v in config.get("active", [])]
                enabled = "true" in [str(v).lower() for v in config.get("enabled", [])]
                if is_rsa and active and enabled:
                    has_active_rsa = True
                # Note: key-material scanning (clientSecret, privateKey, etc.) inside
                # components config is already handled recursively by find_key_material()
                # in Step 5 above; no duplicate check needed here.

            if not has_active_rsa:
                errors.append(
                    "No active RSA key provider found under 'components.org.keycloak.keys.KeyProvider'. "
                    "At least one provider with providerId starting 'rsa', active=true and enabled=true "
                    "is required so the realm publishes an RS256 signing key (AC2, AC7, AC9)."
                )

    # ── Step 9 (Story 2.6): otpPolicy* + browserFlow / CONDITIONAL OTP checks ──
    # AC3: the realm's OTP policy must be present and fully explicit
    # (config-as-code — do not rely on Keycloak's implicit defaults). AC1:
    # browserFlow must be bound to a flow whose OTP Form execution is
    # CONDITIONAL, gated by a condition-user-configured sub-flow (the "Locked
    # Decision" in the story's Dev Notes — bare REQUIRED with no escape hatch
    # is explicitly forbidden).
    #
    # NOTE (deliberate, reviewed correction — not a silent workaround):
    # Keycloak's RealmRepresentation has no nested "otpPolicy" object — a
    # realm-export.json with one fails to import ("Unrecognized field
    # \"otpPolicy\"", verified against a live Keycloak 26.6.3 import). The
    # real schema is flat top-level fields: otpPolicyType, otpPolicyDigits,
    # otpPolicyPeriod, otpPolicyLookAheadWindow, otpPolicyCodeReusable,
    # otpPolicyInitialCounter (HOTP-only). There is also no
    # "otpPolicyLookBehindWindow" field at all (PUTting one via Admin REST
    # returns HTTP 400 "Unrecognized field") — Keycloak's TimeBasedOTP
    # validator applies otpPolicyLookAheadWindow symmetrically to deliver the
    # "bounded clock-drift window" AC3 asks for.
    if data.get("otpPolicyType") != "totp":
        errors.append(
            f"otpPolicyType must be 'totp' (this realm uses TOTP only, not HOTP), "
            f"got {data.get('otpPolicyType')!r}."
        )

    digits = data.get("otpPolicyDigits")
    if not isinstance(digits, int) or isinstance(digits, bool) or digits != 6:
        errors.append(
            f"otpPolicyDigits must be the integer 6, got {digits!r}."
        )

    # bool is a subclass of int in Python — exclude it explicitly so a JSON
    # `true` (which equals 1) cannot slip past a loose `!= 1` comparison
    # (TS-260j type-confusion guard).
    look_ahead = data.get("otpPolicyLookAheadWindow")
    if not isinstance(look_ahead, int) or isinstance(look_ahead, bool) or look_ahead != 1:
        errors.append(
            f"otpPolicyLookAheadWindow must be the integer 1 (bounded clock-drift "
            f"window, AC3 — Keycloak applies this symmetrically; there is no separate "
            f"lookBehindWindow field), got {look_ahead!r}."
        )

    period = data.get("otpPolicyPeriod")
    if not isinstance(period, int) or isinstance(period, bool) or period != 30:
        errors.append(
            f"otpPolicyPeriod must be the integer 30, got {period!r}."
        )

    # `is not False` correctly rejects null/0/1/true — only the boolean
    # `false` singleton passes. Explicit-false is what enables Keycloak's
    # single-use-per-time-step replay cache (AC3).
    if data.get("otpPolicyCodeReusable") is not False:
        errors.append(
            f"otpPolicyCodeReusable must be boolean false (AC3: a verified code must be "
            f"single-use within its time step — Keycloak's replay-protection cache is "
            f"active only when this is false), got {data.get('otpPolicyCodeReusable')!r}."
        )

    if "otpPolicyInitialCounter" in data:
        errors.append(
            "realm-export.json must NOT declare 'otpPolicyInitialCounter' — that field "
            "is HOTP-only and this realm uses TOTP exclusively (Subtask 1.2); Keycloak "
            "defaults it to 0 when absent."
        )

    if "otpPolicy" in data:
        errors.append(
            "realm-export.json must NOT declare a top-level 'otpPolicy' object — "
            "Keycloak's RealmRepresentation has no such field; use the flat otpPolicy* "
            "fields instead (otpPolicyType, otpPolicyDigits, etc.), or realm import fails."
        )

    browser_flow = data.get("browserFlow")
    if not isinstance(browser_flow, str) or not browser_flow:
        errors.append(
            "Missing or empty 'browserFlow' in realm-export.json — the realm's active "
            "browser flow must be explicitly bound (Subtask 2.2, AC1)."
        )
    else:
        flows = data.get("authenticationFlows")
        flows = flows if isinstance(flows, list) else []
        flows_by_alias = {
            f.get("alias"): f for f in flows if isinstance(f, dict)
        }

        if browser_flow not in flows_by_alias:
            errors.append(
                f"'browserFlow' references '{browser_flow}', but no flow with that alias "
                "exists in 'authenticationFlows'."
            )

        # Code-review finding (edge-case hunter): every execution that points at a
        # sub-flow (autheticatorFlow=true / has a flowAlias) must resolve to a flow
        # that actually exists in 'authenticationFlows' — a dangling reference passes
        # a naive check but makes the whole realm import fail at Keycloak startup.
        for f in flows:
            if not isinstance(f, dict):
                continue
            for ex in f.get("authenticationExecutions") or []:
                if not isinstance(ex, dict):
                    continue
                flow_alias_ref = ex.get("flowAlias")
                if flow_alias_ref is not None and flow_alias_ref not in flows_by_alias:
                    errors.append(
                        f"Flow '{f.get('alias')!r}' has an execution referencing "
                        f"flowAlias {flow_alias_ref!r}, which does not exist in "
                        "'authenticationFlows' — this dangling reference would fail "
                        "at Keycloak import time."
                    )

        # AC1 ("Locked Decision"): the CONDITIONAL-OTP gate must live in the flow
        # that is ACTUALLY ACTIVE (i.e. reachable from 'browserFlow' by following
        # flowAlias references), not merely present *somewhere* in
        # 'authenticationFlows'. A leftover/unused flow containing a correctly
        # shaped OTP step must not make an unrelated, unprotected active browser
        # flow pass lint (code-review finding: edge-case hunter).
        reachable_aliases = set()
        frontier = [browser_flow] if browser_flow in flows_by_alias else []
        while frontier:
            alias = frontier.pop()
            if alias in reachable_aliases:
                continue
            reachable_aliases.add(alias)
            flow = flows_by_alias.get(alias)
            if not isinstance(flow, dict):
                continue
            for ex in flow.get("authenticationExecutions") or []:
                if not isinstance(ex, dict):
                    continue
                nested_alias = ex.get("flowAlias")
                if nested_alias in flows_by_alias and nested_alias not in reachable_aliases:
                    frontier.append(nested_alias)

        reachable_executions = [
            ex
            for alias in reachable_aliases
            for ex in (flows_by_alias[alias].get("authenticationExecutions") or [])
            if isinstance(ex, dict)
        ]

        otp_executions = [
            ex for ex in reachable_executions if ex.get("authenticator") == "auth-otp-form"
        ]
        has_condition_user_configured = any(
            ex.get("authenticator") == "conditional-user-configured"
            for ex in reachable_executions
        )

        if not otp_executions:
            errors.append(
                "No 'auth-otp-form' execution found reachable from 'browserFlow' "
                f"({browser_flow!r}) — the ACTIVE browser flow must include an OTP "
                "step (AC1); an OTP execution existing only in an unreferenced flow "
                "does not satisfy this."
            )
        else:
            # Keycloak's CONDITIONAL requirement type is assigned to the flow-alias
            # execution that references a conditional sub-flow — CONDITIONAL is a
            # flow-level property, never valid directly on a non-flow (leaf)
            # execution (confirmed live against Keycloak 26.6.3 — see this story's
            # Dev Agent Record). Reject that shape outright rather than silently
            # accepting it only for it to fail at Keycloak import time.
            for ex in otp_executions:
                if ex.get("requirement") == "CONDITIONAL" and not ex.get("autheticatorFlow"):
                    errors.append(
                        "The 'auth-otp-form' execution has requirement=CONDITIONAL set "
                        "directly on the leaf execution — CONDITIONAL is only valid on a "
                        "flow-alias execution (autheticatorFlow=true) referencing a "
                        "conditional sub-flow, not on a non-flow authenticator execution; "
                        "this shape is rejected by Keycloak at import time."
                    )

            # Only the sub-flow(s) that actually contain 'auth-otp-form' are eligible
            # to satisfy the CONDITIONAL-wrapper requirement — this correlates the
            # two checks instead of testing each token's existence independently and
            # globally (code-review finding: edge-case hunter).
            flow_alias_by_authenticator_flow = {
                alias
                for alias in reachable_aliases
                if any(
                    isinstance(ex, dict) and ex.get("authenticator") == "auth-otp-form"
                    for ex in (flows_by_alias[alias].get("authenticationExecutions") or [])
                )
            }
            has_conditional_wrapper = any(
                ex.get("flowAlias") in flow_alias_by_authenticator_flow
                and ex.get("requirement") == "CONDITIONAL"
                for ex in reachable_executions
            )

            for ex in otp_executions:
                requirement = ex.get("requirement")
                if requirement == "DISABLED":
                    errors.append(
                        "The 'auth-otp-form' execution requirement is DISABLED — OTP "
                        "verification must be gated CONDITIONAL (on itself or its wrapping "
                        "sub-flow), never turned off entirely (AC1)."
                    )
                elif requirement != "CONDITIONAL" and not has_conditional_wrapper:
                    errors.append(
                        "The 'auth-otp-form' execution requirement is "
                        f"{requirement!r}, and it is not wrapped by a CONDITIONAL "
                        "flowAlias execution either — OTP must be gated CONDITIONAL, not "
                        "bare REQUIRED with no condition-user-configured escape hatch "
                        "(Locked Decision — see Dev Notes 'Flow Requirement Level')."
                    )

        if not has_condition_user_configured:
            errors.append(
                "No 'conditional-user-configured' execution found reachable from "
                "'browserFlow' — the OTP branch must be gated by a "
                "condition-user-configured sub-flow so OTP is only non-skippable for "
                "accounts that already have a TOTP credential (Locked Decision — bare "
                "REQUIRED with no escape hatch would strand unenrolled accounts)."
            )

    # ── Step 10: Report and exit ────────────────────────────────────────────────
    if errors:
        print("realm-export.json FAILED lint:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)

    print("realm-export.json passed lint.")
    sys.exit(0)


if __name__ == "__main__":
    main()
