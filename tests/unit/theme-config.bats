#!/usr/bin/env bats
# tests/unit/theme-config.bats
# ATDD tests — Story 2.5: Branded Deep Sea login theme (top-level, anti-phishing)
#
# Static-file assertions that do NOT require a running Docker stack.
# All file checks are against the committed source tree.
#
# AC Coverage:
#   AC1 — Deep Sea tokens applied: login.css references only CSS variables (no raw hex outside rgba)
#   AC2 — Top-level only: realm-export.json does NOT set conflicting contentSecurityPolicy
#   AC3 — Anti-phishing banner: login.ftl + login-otp.ftl include the banner markup
#   AC4 — All strings externalized: messages_en.properties has required keys; no hardcoded text in .ftl
#   AC5 — WCAG AA: login.css has :focus-visible rule; login.ftl has label elements
#   AC6 — Theme wired: realm-export.json sets loginTheme=envocc; Dockerfile COPYs theme before kc.sh build
#   AC7 — No-JS: login.ftl uses <form method="post">
#
# Test IDs:
#   TS-251a–i  AC6: Theme structure and wiring
#   TS-252a–b  AC2: No conflicting CSP in realm config
#   TS-253a–d  AC1: CSS variable usage in login.css
#   TS-254a–d  AC3: Anti-phishing banner in login.ftl (TS-254d: aria-live)
#   TS-255a–b  AC3: Anti-phishing banner in login-otp.ftl
#   TS-256a–c  AC4: messages_en.properties required keys
#   TS-257a–b  AC4: No hardcoded strings in .ftl templates
#   TS-258a,b1,b2  AC5: WCAG focus ring and persistent labels (b1: username, b2: password)
#   TS-259a–b  AC7: No-JS POST form
#
# TDD Phase: RED — tests will fail until story implementation files are created.
#
# Run (no stack required):
#   BATS_LIB_PATH="$(pwd)/tests/lib" bats tests/unit/theme-config.bats

bats_load_library 'bats-support'
bats_load_library 'bats-assert'

load '../helpers/common'

setup() {
  : # per-test setup (noop for static file checks)
}

teardown() {
  : # per-test teardown
}

# ---------------------------------------------------------------------------
# TS-251 [P0] — AC6: Theme directory structure
# ---------------------------------------------------------------------------

@test "[P0][TS-251a] keycloak/themes/envocc/login/theme.properties exists" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/theme.properties" ]
}

@test "[P0][TS-251b] theme.properties declares parent=keycloak" {
  run grep -E "^parent\s*=\s*keycloak" "${PROJECT_ROOT}/keycloak/themes/envocc/login/theme.properties"
  assert_success
}

@test "[P0][TS-251c] theme.properties declares styles=css/login.css" {
  run grep -E "^styles\s*=\s*css/login\.css" "${PROJECT_ROOT}/keycloak/themes/envocc/login/theme.properties"
  assert_success
}

@test "[P0][TS-251d] keycloak/themes/envocc/login/resources/css/login.css exists" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/css/login.css" ]
}

@test "[P0][TS-251e] keycloak/themes/envocc/login/resources/design-tokens/deep-sea.css exists (keycloak-internal token copy)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/design-tokens/deep-sea.css" ]
}

@test "[P0][TS-251f] keycloak/themes/envocc/login/messages/messages_en.properties exists" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties" ]
}

# ---------------------------------------------------------------------------
# TS-251g/h [P0] — AC6: realm-export.json and Dockerfile wiring
# ---------------------------------------------------------------------------

@test "[P0][TS-251g] keycloak/realm-export.json sets loginTheme: envocc" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run grep '"loginTheme"[[:space:]]*:[[:space:]]*"envocc"' "${PROJECT_ROOT}/keycloak/realm-export.json"
  assert_success
}

@test "[P0][TS-251h] keycloak/Dockerfile contains COPY themes/envocc directive" {
  assert [ -f "${PROJECT_ROOT}/keycloak/Dockerfile" ]

  run grep -E "COPY\s+themes/envocc\s+/opt/keycloak/themes/envocc" "${PROJECT_ROOT}/keycloak/Dockerfile"
  assert_success
}

@test "[P0][TS-251i] COPY themes/envocc appears BEFORE RUN kc.sh build in Dockerfile (Quarkus build-time theme requirement)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/Dockerfile" ]

  local copy_line build_line
  copy_line=$(grep -n "COPY themes/envocc" "${PROJECT_ROOT}/keycloak/Dockerfile" | head -1 | cut -d: -f1)
  build_line=$(grep -n "kc\.sh build" "${PROJECT_ROOT}/keycloak/Dockerfile" | head -1 | cut -d: -f1)

  assert [ -n "${copy_line}" ]
  assert [ -n "${build_line}" ]
  assert [ "${copy_line}" -lt "${build_line}" ]
}

# ---------------------------------------------------------------------------
# TS-252 [P0] — AC2: No conflicting CSP in realm-export.json
# ---------------------------------------------------------------------------

@test "[P0][TS-252a] realm-export.json browserSecurityHeaders does not contain contentSecurityPolicy with frame-ancestors" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  # If browserSecurityHeaders.contentSecurityPolicy is set with frame-ancestors, it would
  # duplicate the nginx header (story 1.3). It must be absent or empty.
  run bash -c "python3 -c \"
import json, sys
with open('${PROJECT_ROOT}/keycloak/realm-export.json') as f:
    realm = json.load(f)
bsh = realm.get('browserSecurityHeaders', {})
csp = bsh.get('contentSecurityPolicy', '')
if 'frame-ancestors' in csp:
    sys.exit(1)
print('OK: no conflicting frame-ancestors in browserSecurityHeaders')
\""
  assert_success
}

@test "[P0][TS-252b] realm-export.json browserSecurityHeaders contentSecurityPolicy is absent or empty" {
  assert [ -f "${PROJECT_ROOT}/keycloak/realm-export.json" ]

  run bash -c "python3 -c \"
import json, sys
with open('${PROJECT_ROOT}/keycloak/realm-export.json') as f:
    realm = json.load(f)
bsh = realm.get('browserSecurityHeaders', {})
csp = bsh.get('contentSecurityPolicy', '').strip()
if csp:
    print(f'WARN: contentSecurityPolicy is set: {csp}', file=sys.stderr)
    sys.exit(1)
print('OK: contentSecurityPolicy is absent or empty')
\""
  assert_success
}

# ---------------------------------------------------------------------------
# TS-253 [P0] — AC1: login.css uses CSS variables (no raw hex)
# ---------------------------------------------------------------------------

@test "[P0][TS-253a] login.css has no raw hex color values (raw hex outside rgba() not allowed)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/css/login.css" ]

  # Strip CSS comments and rgba/rgb() calls, then grep for bare hex.
  # Allow rgba() for shadows. Fail if any #rrggbb or #rgb appears.
  run bash -c "
    sed 's|/\*[^*]*\*\+([^/][^*]*\*\+)*/||g' \
        '${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/css/login.css' \
    | grep -v 'rgba\?(' \
    | grep -v '^\s*//' \
    | grep -oE '#[0-9A-Fa-f]{3,6}' \
    | head -3
  "
  # Any match means there's a raw hex — test should produce no output.
  assert_output ""
}

@test "[P0][TS-253b] login.css @imports design-tokens/deep-sea.css" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/css/login.css" ]

  run grep -E "@import\s+url\(['\"]?\.\./design-tokens/deep-sea\.css" \
      "${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/css/login.css"
  assert_success
}

@test "[P0][TS-253c] login.css defines .anti-phishing-banner rule with info color tokens" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/css/login.css" ]

  run grep "\.anti-phishing-banner" \
      "${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/css/login.css"
  assert_success
}

@test "[P1][TS-253d] login.css uses var(--color-primary-foreground) for button text (NOT --color-primary-fg)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/css/login.css" ]

  run grep "var(--color-primary-foreground)" \
      "${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/css/login.css"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-254 [P0] — AC3: Anti-phishing banner in login.ftl
# ---------------------------------------------------------------------------

@test "[P0][TS-254a] login.ftl contains anti-phishing-banner element" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl" ]

  run grep "anti-phishing-banner" "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl"
  assert_success
}

@test "[P0][TS-254b] login.ftl anti-phishing banner uses \${msg(\"antiphishingBanner\")}" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl" ]

  run grep 'msg("antiphishingBanner")' "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl"
  assert_success
}

@test "[P0][TS-254c] login.ftl anti-phishing banner has role=\"alert\"" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl" ]

  run grep 'role="alert"' "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl"
  assert_success
}

@test "[P0][TS-254d] login.ftl anti-phishing banner has aria-live=\"polite\"" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl" ]

  run grep 'aria-live="polite"' "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-255 [P0] — AC3: Anti-phishing banner in login-otp.ftl
# ---------------------------------------------------------------------------

@test "[P0][TS-255a] login-otp.ftl contains anti-phishing-banner element" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login-otp.ftl" ]

  run grep "anti-phishing-banner" "${PROJECT_ROOT}/keycloak/themes/envocc/login/login-otp.ftl"
  assert_success
}

@test "[P0][TS-255b] login-otp.ftl anti-phishing banner uses \${msg(\"antiphishingBanner\")}" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login-otp.ftl" ]

  run grep 'msg("antiphishingBanner")' "${PROJECT_ROOT}/keycloak/themes/envocc/login/login-otp.ftl"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-256 [P0] — AC4: messages_en.properties required keys
# ---------------------------------------------------------------------------

@test "[P0][TS-256a] messages_en.properties defines antiphishingBanner key with correct copy" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties" ]

  # Doubled apostrophe (We''ll) is required: Keycloak resolves the value via
  # java.text.MessageFormat, which would otherwise consume a lone apostrophe.
  run grep -F "antiphishingBanner=We''ll never ask for your verification code by phone, email, or chat." \
      "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties"
  assert_success
}

@test "[P0][TS-256b1] messages_en.properties defines loginTitle" {
  run grep -E "^loginTitle\s*=" "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties"
  assert_success
}

@test "[P0][TS-256b2] messages_en.properties defines doLogIn" {
  run grep -E "^doLogIn\s*=" "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties"
  assert_success
}

@test "[P0][TS-256b3] messages_en.properties defines doForgotPassword" {
  run grep -E "^doForgotPassword\s*=" "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties"
  assert_success
}

@test "[P0][TS-256b4] messages_en.properties defines loginTotpTitle" {
  run grep -E "^loginTotpTitle\s*=" "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties"
  assert_success
}

@test "[P0][TS-256b5] messages_en.properties defines loginTotpOneTime" {
  run grep -E "^loginTotpOneTime\s*=" "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties"
  assert_success
}

@test "[P0][TS-256b6] messages_en.properties defines doSubmit" {
  run grep -E "^doSubmit\s*=" "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties"
  assert_success
}

@test "[P0][TS-256b7] messages_en.properties defines loginWithThaiD" {
  run grep -E "^loginWithThaiD\s*=" "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties"
  assert_success
}

@test "[P0][TS-256b8] messages_en.properties defines backToLogin" {
  run grep -E "^backToLogin\s*=" "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties"
  assert_success
}

@test "[P1][TS-256c] messages_en.properties overrides error messages to UX-voice copy" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties" ]

  run grep -F "invalidUserMessage=Incorrect email or password." \
      "${PROJECT_ROOT}/keycloak/themes/envocc/login/messages/messages_en.properties"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-257 [P0] — AC4: No hardcoded strings in .ftl templates
# ---------------------------------------------------------------------------

@test "[P0][TS-257a] login.ftl contains no hardcoded literal 'Sign in' text node (must use \${msg(...)})" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl" ]

  # Check for ">Sign in<" text node (not inside an attribute or msg() call)
  run grep ">Sign in<" "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl"
  # Should NOT be found — any match is a failure
  assert_failure
}

@test "[P0][TS-257b] login.ftl contains no hardcoded literal \"We'll never ask\" text (must use \${msg(...)})" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl" ]

  # The exact copy must come from messages, not be inline.
  run grep "We'll never ask" "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl"
  assert_failure
}

# ---------------------------------------------------------------------------
# TS-258 [P1] — AC5: WCAG AA focus rings
# ---------------------------------------------------------------------------

@test "[P1][TS-258a] login.css defines :focus-visible rule (keyboard focus ring)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/css/login.css" ]

  run grep ":focus-visible" "${PROJECT_ROOT}/keycloak/themes/envocc/login/resources/css/login.css"
  assert_success
}

@test "[P1][TS-258b1] login.ftl has <label for=\"username\"> (no placeholder-only label)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl" ]

  run grep 'for="username"' "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl"
  assert_success
}

@test "[P1][TS-258b2] login.ftl has <label for=\"password\"> (no placeholder-only label)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl" ]

  run grep 'for="password"' "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl"
  assert_success
}

# ---------------------------------------------------------------------------
# TS-259 [P0] — AC7: No-JS standard POST form
# ---------------------------------------------------------------------------

@test "[P0][TS-259a] login.ftl has <form method=\"post\"> (standard POST — no JS required)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl" ]

  run grep -i 'method="post"' "${PROJECT_ROOT}/keycloak/themes/envocc/login/login.ftl"
  assert_success
}

@test "[P0][TS-259b] login-otp.ftl has <form method=\"post\"> (standard POST — no JS required)" {
  assert [ -f "${PROJECT_ROOT}/keycloak/themes/envocc/login/login-otp.ftl" ]

  run grep -i 'method="post"' "${PROJECT_ROOT}/keycloak/themes/envocc/login/login-otp.ftl"
  assert_success
}
