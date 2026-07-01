/**
 * ATDD Scaffold — Story 2.5: Branded Deep Sea Login Theme (top-level, anti-phishing)
 *
 * AC Coverage:
 *   AC1 — Deep Sea tokens applied — all auth surfaces: CSS uses only var() references, no raw hex
 *   AC2 — Top-level only — realm-export.json does NOT set a conflicting contentSecurityPolicy
 *   AC3 — Pinned, non-dismissible anti-phishing banner in sign-in and TOTP surfaces
 *   AC4 — All strings externalized — messages_en.properties has all required keys; no hardcoded text in .ftl
 *   AC5 — WCAG 2.1 AA — persistent labels, focus rings, aria-associated errors
 *   AC6 — Theme wired: realm-export.json sets loginTheme; Dockerfile COPYs theme before kc.sh build
 *   AC7 — No-JS login path — form submits via standard POST without JavaScript
 *
 * Run:  node --test tests/theme/login-theme.test.mjs
 *
 * TDD Phase: RED — all tests use plain it() and will fail until story implementation files are created.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, '..', '..');

// Theme file paths (relative to PROJECT_ROOT)
const THEME_ROOT    = path.join(PROJECT_ROOT, 'keycloak', 'themes', 'envocc', 'login');
const LOGIN_CSS     = path.join(THEME_ROOT, 'resources', 'css', 'login.css');
const TOKEN_COPY    = path.join(THEME_ROOT, 'resources', 'design-tokens', 'deep-sea.css');
const THEME_PROPS   = path.join(THEME_ROOT, 'theme.properties');
const MESSAGES_EN   = path.join(THEME_ROOT, 'messages', 'messages_en.properties');
const LOGIN_FTL     = path.join(THEME_ROOT, 'login.ftl');
const LOGIN_OTP_FTL = path.join(THEME_ROOT, 'login-otp.ftl');

const REALM_EXPORT  = path.join(PROJECT_ROOT, 'keycloak', 'realm-export.json');
const DOCKERFILE    = path.join(PROJECT_ROOT, 'keycloak', 'Dockerfile');

// ---------------------------------------------------------------------------
// Read static content once before any test runs.
// READ-ONLY after before() — never mutate in tests.
// ---------------------------------------------------------------------------

let css         = '';
let themeProps  = '';
let msgProps    = '';
let loginFtl    = '';
let loginOtpFtl = '';
let realmJson   = '';
let dockerfile  = '';

// Pre-extracted snippets (computed in before() after files are loaded).
// Use these in tests rather than re-extracting inline.
let bannerBlock              = ''; // .anti-phishing-banner { ... } rule block from login.css
let loginFtlBannerSnippet    = ''; // ~800 chars from anti-phishing-banner in login.ftl
let loginOtpFtlBannerSnippet = ''; // ~800 chars from anti-phishing-banner in login-otp.ftl

before(() => {
  css         = fs.existsSync(LOGIN_CSS)     ? fs.readFileSync(LOGIN_CSS, 'utf-8')     : '';
  themeProps  = fs.existsSync(THEME_PROPS)   ? fs.readFileSync(THEME_PROPS, 'utf-8')   : '';
  msgProps    = fs.existsSync(MESSAGES_EN)   ? fs.readFileSync(MESSAGES_EN, 'utf-8')   : '';
  loginFtl    = fs.existsSync(LOGIN_FTL)     ? fs.readFileSync(LOGIN_FTL, 'utf-8')     : '';
  loginOtpFtl = fs.existsSync(LOGIN_OTP_FTL) ? fs.readFileSync(LOGIN_OTP_FTL, 'utf-8') : '';
  realmJson   = fs.existsSync(REALM_EXPORT)  ? fs.readFileSync(REALM_EXPORT, 'utf-8')  : '';
  dockerfile  = fs.existsSync(DOCKERFILE)    ? fs.readFileSync(DOCKERFILE, 'utf-8')    : '';

  // Pre-extract reusable snippets to avoid repeated inline regex/slice in tests.
  bannerBlock = css.match(/\.anti-phishing-banner\s*\{([^}]+)\}/s)?.[1] ?? '';

  const loginFtlBannerIdx = loginFtl.indexOf('anti-phishing-banner');
  loginFtlBannerSnippet    = loginFtlBannerIdx !== -1
    ? loginFtl.slice(loginFtlBannerIdx, loginFtlBannerIdx + 800)
    : '';

  const loginOtpFtlBannerIdx = loginOtpFtl.indexOf('anti-phishing-banner');
  loginOtpFtlBannerSnippet   = loginOtpFtlBannerIdx !== -1
    ? loginOtpFtl.slice(loginOtpFtlBannerIdx, loginOtpFtlBannerIdx + 800)
    : '';
});

// ---------------------------------------------------------------------------
// AC6 — Theme directory structure and wiring
// ---------------------------------------------------------------------------

describe('AC6 — Theme directory structure exists', () => {
  it('keycloak/themes/envocc/login/ directory exists', () => {
    assert.ok(
      fs.existsSync(THEME_ROOT) && fs.statSync(THEME_ROOT).isDirectory(),
      `Expected ${THEME_ROOT} to be a directory`,
    );
  });

  it('theme.properties exists', () => {
    assert.ok(
      fs.existsSync(THEME_PROPS),
      `Expected ${THEME_PROPS} to exist`,
    );
  });

  it('theme.properties declares parent=keycloak', () => {
    assert.match(themeProps, /^\s*parent\s*=\s*keycloak\s*$/m,
      'Expected theme.properties to contain: parent=keycloak');
  });

  it('theme.properties declares styles=css/login.css', () => {
    assert.match(themeProps, /^\s*styles\s*=\s*css\/login\.css\s*$/m,
      'Expected theme.properties to contain: styles=css/login.css');
  });

  it('keycloak/themes/envocc/login/resources/css/login.css exists', () => {
    assert.ok(fs.existsSync(LOGIN_CSS), `Expected ${LOGIN_CSS} to exist`);
  });

  it('keycloak/themes/envocc/login/resources/design-tokens/deep-sea.css exists (keycloak-internal copy)', () => {
    assert.ok(
      fs.existsSync(TOKEN_COPY),
      `Expected theme-internal token copy at ${TOKEN_COPY} to exist`,
    );
  });

  it('theme-internal deep-sea.css is not empty', () => {
    const stat = fs.statSync(TOKEN_COPY);
    assert.ok(stat.size > 0, 'Expected theme-internal deep-sea.css to be non-empty');
  });

  it('keycloak/themes/envocc/login/messages/messages_en.properties exists', () => {
    assert.ok(fs.existsSync(MESSAGES_EN), `Expected ${MESSAGES_EN} to exist`);
  });

  it('login.ftl exists', () => {
    assert.ok(fs.existsSync(LOGIN_FTL), `Expected ${LOGIN_FTL} to exist`);
  });

  it('login-otp.ftl exists', () => {
    assert.ok(fs.existsSync(LOGIN_OTP_FTL), `Expected ${LOGIN_OTP_FTL} to exist`);
  });
});

describe('AC6 — realm-export.json wires loginTheme', () => {
  it('realm-export.json exists', () => {
    assert.ok(fs.existsSync(REALM_EXPORT), `Expected ${REALM_EXPORT} to exist`);
  });

  it('realm-export.json sets "loginTheme": "envocc" at realm root', () => {
    const realm = JSON.parse(realmJson);
    assert.strictEqual(
      realm.loginTheme,
      'envocc',
      `Expected realm-export.json to have loginTheme: "envocc", got: ${realm.loginTheme}`,
    );
  });
});

describe('AC6 — Dockerfile COPYs theme before kc.sh build', () => {
  it('keycloak/Dockerfile exists', () => {
    assert.ok(fs.existsSync(DOCKERFILE), `Expected ${DOCKERFILE} to exist`);
  });

  it('Dockerfile contains COPY themes/envocc directive', () => {
    assert.match(
      dockerfile,
      /COPY\s+themes\/envocc\s+\/opt\/keycloak\/themes\/envocc/,
      'Expected Dockerfile to contain: COPY themes/envocc /opt/keycloak/themes/envocc',
    );
  });

  it('COPY themes/envocc appears BEFORE RUN kc.sh build in Dockerfile', () => {
    const copyIdx  = dockerfile.search(/COPY\s+themes\/envocc/);
    const buildIdx = dockerfile.search(/RUN\s+.*kc\.sh\s+build/);
    assert.ok(copyIdx !== -1, 'COPY themes/envocc directive not found in Dockerfile');
    assert.ok(buildIdx !== -1, 'RUN kc.sh build directive not found in Dockerfile');
    assert.ok(
      copyIdx < buildIdx,
      'Expected COPY themes/envocc to appear BEFORE RUN kc.sh build — Quarkus requires themes at build time',
    );
  });
});

// ---------------------------------------------------------------------------
// AC2 — Top-level only: no conflicting CSP in realm-export.json
// ---------------------------------------------------------------------------

describe('AC2 — realm-export.json does not set conflicting contentSecurityPolicy', () => {
  it('realm-export.json browserSecurityHeaders does not have a contentSecurityPolicy value', () => {
    const realm = JSON.parse(realmJson);
    const bsh = realm.browserSecurityHeaders;
    if (!bsh) {
      // browserSecurityHeaders absent entirely — acceptable
      return;
    }
    const csp = bsh.contentSecurityPolicy;
    assert.ok(
      !csp || csp.trim() === '',
      `Expected browserSecurityHeaders.contentSecurityPolicy to be absent/empty (nginx sets it); got: "${csp}"`,
    );
  });

  it('realm-export.json browserSecurityHeaders does not duplicate frame-ancestors', () => {
    const realm = JSON.parse(realmJson);
    const bsh = realm.browserSecurityHeaders;
    if (!bsh) return; // absent is fine
    const csp = bsh.contentSecurityPolicy || '';
    assert.ok(
      !csp.includes('frame-ancestors'),
      `Expected browserSecurityHeaders.contentSecurityPolicy NOT to contain frame-ancestors — nginx handles this. Got: "${csp}"`,
    );
  });
});

// ---------------------------------------------------------------------------
// ATDD Scaffold — Story 2.6 AC1/AC3: otpPolicy + browserFlow wired in
// realm-export.json (config-as-code, spot-checked here at the theme-test
// level; scripts/lint-realm-export.py + tests/unit/realm-otp-policy.bats own
// the authoritative, exhaustive lint coverage — see Task 2.4).
//
// TDD Phase: RED — realm-export.json currently has no otpPolicy,
// authenticationFlows, or browserFlow key (confirmed by reading the file
// before writing this scaffold). These assertions are expected to FAIL
// until Task 1 and Task 2 are implemented.
// ---------------------------------------------------------------------------

// NOTE (deliberate, reviewed correction of the ATDD scaffold — not a silent
// workaround): Keycloak's RealmRepresentation has no nested "otpPolicy"
// object — attempting to import a realm-export.json with a nested
// "otpPolicy" key fails with "Unrecognized field \"otpPolicy\"" (verified
// against a live Keycloak 26.6.3 import). The real schema is a set of FLAT
// top-level fields: otpPolicyType, otpPolicyAlgorithm, otpPolicyDigits,
// otpPolicyPeriod, otpPolicyLookAheadWindow, otpPolicyInitialCounter,
// otpPolicyCodeReusable (confirmed via a live realm's admin REST
// representation and by decompiling RealmRepresentation's Jackson-mapped
// field list). There is also no "lookBehindWindow" field at all — Keycloak's
// TimeBasedOTP validator uses a single otpPolicyLookAheadWindow count to
// define a symmetric ± drift-tolerance window (confirmed: PUTting
// otpPolicyLookBehindWindow via Admin REST returns HTTP 400 "Unrecognized
// field"), which is what actually delivers AC3's "bounded clock-drift
// window" — the assertions below were corrected to check the real flat
// fields instead of a nonexistent nested object / nonexistent field.
describe('Story 2.6 AC3 — realm-export.json declares an explicit otpPolicy (bounded clock-drift window)', () => {
  it('otpPolicyType is "totp" (not hotp — Decision 1, this realm uses TOTP only)', () => {
    const realm = JSON.parse(realmJson);
    assert.strictEqual(realm.otpPolicyType, 'totp',
      `Expected otpPolicyType to be "totp", got: ${realm.otpPolicyType}`);
  });

  it('otpPolicyDigits is 6', () => {
    const realm = JSON.parse(realmJson);
    assert.strictEqual(realm.otpPolicyDigits, 6,
      `Expected otpPolicyDigits to be 6, got: ${realm.otpPolicyDigits}`);
  });

  it('otpPolicyPeriod is explicitly 30', () => {
    const realm = JSON.parse(realmJson);
    assert.strictEqual(realm.otpPolicyPeriod, 30,
      `Expected otpPolicyPeriod to be 30, got: ${realm.otpPolicyPeriod}`);
  });

  it('otpPolicyLookAheadWindow is explicitly 1 (±30s bounded clock-drift window — Keycloak applies this symmetrically, there is no separate lookBehindWindow field)', () => {
    const realm = JSON.parse(realmJson);
    assert.strictEqual(realm.otpPolicyLookAheadWindow, 1,
      `Expected otpPolicyLookAheadWindow to be 1, got: ${realm.otpPolicyLookAheadWindow}`);
  });

  it('realm-export.json does NOT declare otpPolicyInitialCounter (HOTP-only field — Keycloak defaults it to 0 for TOTP, no need to set it explicitly, Subtask 1.2)', () => {
    const realm = JSON.parse(realmJson);
    assert.strictEqual(realm.otpPolicyInitialCounter, undefined,
      'Expected realm-export.json to NOT set otpPolicyInitialCounter — that field is HOTP-only (Subtask 1.2); ' +
      'Keycloak defaults it to 0 for a TOTP-only realm when absent from the import file');
  });

  it('otpPolicyCodeReusable is explicitly false (AC3 single-use-within-time-step / replay protection)', () => {
    const realm = JSON.parse(realmJson);
    assert.strictEqual(realm.otpPolicyCodeReusable, false,
      `Expected otpPolicyCodeReusable to be false, got: ${realm.otpPolicyCodeReusable}`);
  });

  it('realm-export.json does NOT declare a nonexistent nested "otpPolicy" object (must use flat otpPolicy* fields, or Keycloak import fails)', () => {
    const realm = JSON.parse(realmJson);
    assert.strictEqual(realm.otpPolicy, undefined,
      'Expected no top-level "otpPolicy" object — Keycloak\'s RealmRepresentation has no such field; ' +
      'importing one fails with "Unrecognized field \\"otpPolicy\\"" (verified against a live Keycloak 26.6.3 import)');
  });
});

describe('Story 2.6 AC1 — realm-export.json binds a browserFlow with a CONDITIONAL OTP execution', () => {
  it('realm-export.json sets "browserFlow" at the realm root', () => {
    const realm = JSON.parse(realmJson);
    assert.ok(
      typeof realm.browserFlow === 'string' && realm.browserFlow.length > 0,
      'Expected realm-export.json to set a non-empty "browserFlow" at the realm root (Subtask 2.2)',
    );
  });

  it('the flow referenced by browserFlow exists in authenticationFlows', () => {
    const realm = JSON.parse(realmJson);
    const flows = Array.isArray(realm.authenticationFlows) ? realm.authenticationFlows : [];
    const referenced = flows.find((f) => f.alias === realm.browserFlow);
    assert.ok(
      referenced,
      `Expected authenticationFlows to contain a flow aliased "${realm.browserFlow}" (matching browserFlow)`,
    );
  });

  it('the browser flow (or a nested sub-flow) contains an auth-otp-form execution set to CONDITIONAL', () => {
    const realm = JSON.parse(realmJson);
    const flows = Array.isArray(realm.authenticationFlows) ? realm.authenticationFlows : [];
    const allExecutions = flows.flatMap((f) => f.authenticationExecutions || []);

    const otpExecution = allExecutions.find((ex) => ex.authenticator === 'auth-otp-form');
    assert.ok(otpExecution, 'Expected to find an authenticationExecutions entry with authenticator: "auth-otp-form"');

    // NOTE (reviewed correction, not a silent workaround): Keycloak's CONDITIONAL
    // requirement type is a FLOW-level property — it is assigned to the flowAlias
    // execution (in a parent flow) that references a conditional sub-flow, not to a
    // plain non-flow authenticator execution such as auth-otp-form itself. This is
    // exactly the shape of Keycloak's own built-in "browser" flow (Browser Forms ->
    // "Browser - Conditional OTP" sub-flow marked CONDITIONAL, containing "Condition -
    // User Configured" REQUIRED + "OTP Form" REQUIRED) and matches this story's ATDD
    // lint fixture (tests/unit/realm-otp-policy.bats VALID_FIXTURE, TS-260a) and Dev
    // Notes instruction to mirror "Keycloak 26.6.3's own exported default realm." The
    // original assertion here required requirement === "CONDITIONAL" directly on the
    // auth-otp-form leaf, which is not a valid/functional Keycloak shape — corrected to
    // also accept the nested-conditional-subflow form.
    const flowContainingOtp = flows.find((f) =>
      (f.authenticationExecutions || []).some((ex) => ex.authenticator === 'auth-otp-form'),
    );
    const wrappingConditionalRef = flows
      .flatMap((f) => f.authenticationExecutions || [])
      .find((ex) => ex.flowAlias === flowContainingOtp?.alias && ex.requirement === 'CONDITIONAL');

    const isGatedConditional = otpExecution.requirement === 'CONDITIONAL' || Boolean(wrappingConditionalRef);

    assert.ok(
      isGatedConditional,
      `Expected the auth-otp-form execution to be gated CONDITIONAL (not bare REQUIRED, not DISABLED) — ` +
      `either directly (requirement: "CONDITIONAL" on the auth-otp-form execution itself) or via a wrapping ` +
      `conditional sub-flow (a flowAlias execution referencing the sub-flow that contains auth-otp-form, with ` +
      `requirement: "CONDITIONAL"). Locked Decision in Dev Notes: hard REQUIRED would strand accounts with no ` +
      `TOTP credential (no CONFIGURE_TOTP escape hatch in this story's scope). Got auth-otp-form.requirement=` +
      `"${otpExecution.requirement}", wrapping flow requirement=${wrappingConditionalRef?.requirement ?? '<none>'}.`,
    );
  });

  it('the OTP branch is gated by a condition-user-configured sub-flow (not an unconditional CONDITIONAL)', () => {
    const realm = JSON.parse(realmJson);
    const flows = Array.isArray(realm.authenticationFlows) ? realm.authenticationFlows : [];
    const allExecutions = flows.flatMap((f) => f.authenticationExecutions || []);
    const hasConditionUserConfigured = allExecutions.some(
      (ex) => ex.authenticator === 'conditional-user-configured',
    );
    assert.ok(
      hasConditionUserConfigured,
      'Expected an authenticationExecutions entry with authenticator: "conditional-user-configured" — ' +
      'this is what makes OTP non-skippable ONLY for users who already have a TOTP credential (AC1 scope boundary)',
    );
  });
});

// ---------------------------------------------------------------------------
// AC1 — Deep Sea tokens applied: CSS uses var() references, no raw hex
// ---------------------------------------------------------------------------

describe('AC1 — login.css imports design-tokens/deep-sea.css', () => {
  it('login.css contains @import for ../design-tokens/deep-sea.css', () => {
    assert.match(
      css,
      /@import\s+url\(["']?\.\.\/design-tokens\/deep-sea\.css["']?\)/,
      'Expected login.css to @import ../design-tokens/deep-sea.css',
    );
  });
});

describe('AC1 — login.css uses CSS variables for all colors (no raw hex)', () => {
  it('login.css contains no raw hex color values (raw hex not allowed outside rgba() shadows)', () => {
    // Allow rgba(r,g,b,a) and rgb() for shadows/overlays — those are intentional per dev notes.
    // Strip CSS comments and rgba/rgb() calls, then check for bare hex.
    const stripped = css
      .replace(/\/\*[\s\S]*?\*\//g, '')  // remove /* ... */ comments
      .replace(/rgba?\([^)]+\)/g, '')     // remove rgba/rgb() calls (shadows)
      .replace(/url\([^)]+\)/g, '');      // remove url() references

    const hexMatch = stripped.match(/#[0-9A-Fa-f]{3,6}(?=[;\s,){}])/);
    assert.ok(
      !hexMatch,
      `Expected login.css to have no raw hex values outside rgba(). Found: ${hexMatch?.[0]}`,
    );
  });

  it('login.css uses var(--color-primary) for buttons', () => {
    assert.match(css, /var\(--color-primary\)/,
      'Expected login.css to reference var(--color-primary)');
  });

  it('login.css uses var(--color-primary-hover) for button hover state', () => {
    assert.match(css, /var\(--color-primary-hover\)/,
      'Expected login.css to reference var(--color-primary-hover)');
  });

  it('login.css uses var(--color-primary-foreground) for button text color', () => {
    assert.match(css, /var\(--color-primary-foreground\)/,
      'Expected login.css to reference var(--color-primary-foreground) — NOT --color-primary-fg');
  });

  it('login.css uses var(--color-background) for page/body background', () => {
    assert.match(css, /var\(--color-background\)/,
      'Expected login.css to reference var(--color-background)');
  });

  it('login.css uses var(--color-surface) for auth card background', () => {
    assert.match(css, /var\(--color-surface\)/,
      'Expected login.css to reference var(--color-surface)');
  });

  it('login.css uses var(--color-border) for card/input border', () => {
    assert.match(css, /var\(--color-border\)/,
      'Expected login.css to reference var(--color-border)');
  });

  it('login.css uses var(--color-text-primary) for body text', () => {
    assert.match(css, /var\(--color-text-primary\)/,
      'Expected login.css to reference var(--color-text-primary)');
  });

  it('login.css uses var(--color-error-bg) and var(--color-error-fg) for error states', () => {
    assert.match(css, /var\(--color-error-bg\)/,
      'Expected login.css to reference var(--color-error-bg)');
    assert.match(css, /var\(--color-error-fg\)/,
      'Expected login.css to reference var(--color-error-fg)');
  });

  it('login.css uses var(--font-family) on body', () => {
    assert.match(css, /var\(--font-family\)/,
      'Expected login.css to reference var(--font-family)');
  });

  it('login.css uses var(--font-body-size) for base font size', () => {
    assert.match(css, /var\(--font-body-size\)/,
      'Expected login.css to reference var(--font-body-size)');
  });

  it('login.css uses var(--font-body-line-height) for body line height', () => {
    assert.match(css, /var\(--font-body-line-height\)/,
      'Expected login.css to reference var(--font-body-line-height)');
  });

  it('login.css uses var(--radius-md) for inputs and buttons', () => {
    assert.match(css, /var\(--radius-md\)/,
      'Expected login.css to reference var(--radius-md)');
  });

  it('login.css uses var(--radius-lg) for auth card', () => {
    assert.match(css, /var\(--radius-lg\)/,
      'Expected login.css to reference var(--radius-lg)');
  });

  it('login.css uses var(--spacing-auth-card-width) for auth card max-width', () => {
    assert.match(css, /var\(--spacing-auth-card-width\)/,
      'Expected login.css to reference var(--spacing-auth-card-width)');
  });
});

describe('AC1 — login.css anti-phishing banner uses info color tokens', () => {
  it('login.css has .anti-phishing-banner rule', () => {
    assert.match(css, /\.anti-phishing-banner/,
      'Expected login.css to define .anti-phishing-banner rule');
  });

  it('.anti-phishing-banner uses var(--color-info-bg) for background', () => {
    // bannerBlock is pre-extracted in before() — .anti-phishing-banner { ... } rule block.
    assert.match(bannerBlock, /var\(--color-info-bg\)/,
      'Expected .anti-phishing-banner to use var(--color-info-bg) for background');
  });

  it('.anti-phishing-banner uses var(--color-info-border) for border', () => {
    assert.match(bannerBlock, /var\(--color-info-border\)/,
      'Expected .anti-phishing-banner to use var(--color-info-border) for border');
  });

  it('.anti-phishing-banner uses var(--color-info-fg) for text color', () => {
    assert.match(bannerBlock, /var\(--color-info-fg\)/,
      'Expected .anti-phishing-banner to use var(--color-info-fg) for text color');
  });
});

// ---------------------------------------------------------------------------
// AC5 — WCAG 2.1 AA: focus rings
// ---------------------------------------------------------------------------

describe('AC5 — login.css focus rings (WCAG AA)', () => {
  it('login.css defines :focus-visible rule (not :focus without ring replacement)', () => {
    assert.match(css, /:focus-visible/,
      'Expected login.css to define :focus-visible rule for keyboard focus ring');
  });

  it('login.css uses var(--color-focus-ring) or var(--color-accent) for focus ring color', () => {
    const hasFocusRing = /var\(--color-focus-ring\)/.test(css) || /var\(--color-accent\)/.test(css);
    assert.ok(hasFocusRing,
      'Expected login.css to reference var(--color-focus-ring) or var(--color-accent) for keyboard focus');
  });

  it('login.css does not suppress focus without a replacement (no bare outline: none or outline: 0 without :focus-visible override)', () => {
    // A bare "outline: none" or "outline: 0" on * or :focus (not :focus-visible) is a red flag.
    // We look for outline: none not inside a :focus-visible or comment block.
    // Simple heuristic: if outline: none appears, :focus-visible must also appear.
    const hasOutlineNone = /outline\s*:\s*none/.test(css) || /outline\s*:\s*0\b/.test(css);
    if (hasOutlineNone) {
      assert.match(css, /:focus-visible/,
        'Found "outline: none" in login.css but no :focus-visible rule. Must provide :focus-visible replacement ring.');
    }
    // If no outline: none — test passes vacuously (good: no suppression at all)
  });
});

// ---------------------------------------------------------------------------
// AC3 — Anti-phishing banner in login.ftl
// ---------------------------------------------------------------------------

describe('AC3 — login.ftl has pinned non-dismissible anti-phishing banner', () => {
  it('login.ftl contains anti-phishing-banner class', () => {
    assert.match(loginFtl, /anti-phishing-banner/,
      'Expected login.ftl to contain anti-phishing-banner class');
  });

  it('login.ftl anti-phishing banner has role="alert"', () => {
    assert.match(loginFtl, /role="alert"/,
      'Expected login.ftl to have role="alert" on the anti-phishing banner');
  });

  it('login.ftl anti-phishing banner uses ${msg("antiphishingBanner")}', () => {
    assert.match(loginFtl, /\$\{msg\("antiphishingBanner"\)\}/,
      'Expected login.ftl to render the banner text via ${msg("antiphishingBanner")}');
  });

  it('login.ftl anti-phishing banner has no close/dismiss button', () => {
    // loginFtlBannerSnippet is pre-extracted in before() — ~800 chars from anti-phishing-banner.
    assert.ok(loginFtlBannerSnippet, 'anti-phishing-banner class not found in login.ftl');
    const hasDismiss = /dismiss|close|btn-close|type="button"/.test(loginFtlBannerSnippet);
    assert.ok(!hasDismiss,
      'Expected anti-phishing banner in login.ftl to have no dismiss/close button');
  });

  it('login.ftl anti-phishing banner has aria-live="polite"', () => {
    // Per dev notes: aria-live="polite" on the container
    assert.ok(loginFtlBannerSnippet, 'anti-phishing-banner class not found in login.ftl');
    assert.match(loginFtlBannerSnippet, /aria-live="polite"/,
      'Expected anti-phishing banner to have aria-live="polite"');
  });

  it('login.ftl anti-phishing banner includes an info SVG icon (not icon-only — paired with text)', () => {
    assert.ok(loginFtlBannerSnippet, 'anti-phishing-banner class not found in login.ftl');
    assert.match(loginFtlBannerSnippet, /<svg/,
      'Expected anti-phishing banner to include an SVG info icon');
    // Icon must be aria-hidden (decorative — text carries the content)
    assert.match(loginFtlBannerSnippet, /aria-hidden="true"/,
      'Expected SVG icon to be aria-hidden="true" (text carries the message)');
  });
});

// ---------------------------------------------------------------------------
// AC3 — Anti-phishing banner in login-otp.ftl
// ---------------------------------------------------------------------------

describe('AC3 — login-otp.ftl has pinned non-dismissible anti-phishing banner', () => {
  it('login-otp.ftl contains anti-phishing-banner class', () => {
    assert.match(loginOtpFtl, /anti-phishing-banner/,
      'Expected login-otp.ftl to contain anti-phishing-banner class');
  });

  it('login-otp.ftl anti-phishing banner has role="alert"', () => {
    assert.match(loginOtpFtl, /role="alert"/,
      'Expected login-otp.ftl to have role="alert" on the anti-phishing banner');
  });

  it('login-otp.ftl anti-phishing banner uses ${msg("antiphishingBanner")}', () => {
    assert.match(loginOtpFtl, /\$\{msg\("antiphishingBanner"\)\}/,
      'Expected login-otp.ftl to render the banner text via ${msg("antiphishingBanner")}');
  });

  it('login-otp.ftl anti-phishing banner has no close/dismiss button', () => {
    // loginOtpFtlBannerSnippet is pre-extracted in before().
    assert.ok(loginOtpFtlBannerSnippet, 'anti-phishing-banner class not found in login-otp.ftl');
    const hasDismiss = /dismiss|close|btn-close|type="button"/.test(loginOtpFtlBannerSnippet);
    assert.ok(!hasDismiss,
      'Expected anti-phishing banner in login-otp.ftl to have no dismiss/close button');
  });
});

// ---------------------------------------------------------------------------
// AC4 — All strings externalized: messages_en.properties keys
// ---------------------------------------------------------------------------

describe('AC4 — messages_en.properties has all required string keys', () => {
  const REQUIRED_KEYS = [
    'antiphishingBanner',
    'loginTitle',
    'doLogIn',
    'doForgotPassword',
    'loginTotpTitle',
    'loginTotpOneTime',
    'doSubmit',
    'loginWithThaiD',
    'backToLogin',
  ];

  for (const key of REQUIRED_KEYS) {
    it(`messages_en.properties defines "${key}"`, () => {
      assert.match(
        msgProps,
        new RegExp(`^\\s*${key}\\s*=`, 'm'),
        `Expected messages_en.properties to define key: ${key}`,
      );
    });
  }

  it('antiphishingBanner value matches the spec copy exactly', () => {
    // Stored with a doubled apostrophe (We''ll) because Keycloak runs the value
    // through java.text.MessageFormat, which treats a lone ' as a quote
    // metacharacter. The doubled '' renders as a single apostrophe ("We'll").
    const expected = "We''ll never ask for your verification code by phone, email, or chat.";
    assert.match(
      msgProps,
      new RegExp(`antiphishingBanner\\s*=\\s*${expected.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`),
      `Expected antiphishingBanner to equal: "${expected}"`,
    );
  });

  it('invalidUserMessage key is overridden to match UX voice', () => {
    assert.match(
      msgProps,
      /^invalidUserMessage\s*=\s*Incorrect email or password\./m,
      'Expected invalidUserMessage to be overridden to "Incorrect email or password."',
    );
  });

  it('accountDisabledMessage key is overridden to match UX voice', () => {
    assert.match(
      msgProps,
      /^accountDisabledMessage\s*=\s*This account is not available\./m,
      'Expected accountDisabledMessage to contain friendly HR-contact message',
    );
  });
});

// ---------------------------------------------------------------------------
// AC4 — No hardcoded English strings in FreeMarker templates
// ---------------------------------------------------------------------------

// Context window for forbidden-literal detection in FTL templates.
const CONTEXT_LOOKBACK  = 20; // chars before the literal to check for msg( or ${ prefix
const CONTEXT_LOOKAHEAD = 5;  // chars after the literal end for surrounding context

describe('AC4 — login.ftl has no hardcoded English UI strings (uses ${msg(...)})', () => {
  // Hard-coded strings to check for: key phrases that MUST come from messages, not literals.
  const FORBIDDEN_LITERALS = [
    'Sign in',
    'Forgot password',
    'Work email',
    'Verification code',
    'Login with ThaiD',
    "We'll never ask",
    'Back to sign in',
    'Sign in to EnvOcc',
  ];

  for (const literal of FORBIDDEN_LITERALS) {
    it(`login.ftl does not contain hardcoded literal: "${literal}"`, () => {
      // Allow the literal if it appears ONLY inside a ${msg(...)} call or FTL comment.
      // We strip FTL comments <#-- ... -->, then check for bare literal.
      const stripped = loginFtl.replace(/<#--[\s\S]*?-->/g, '');
      // The literal should not appear outside a ${msg("...")} context.
      // Simple check: literal must NOT appear as a free text node (not preceded by ${msg or msg( or =").
      const idx = stripped.indexOf(literal);
      if (idx === -1) return; // not present — good
      // Check surrounding context for msg( or ${ prefix indicating a template expression.
      const ctx = stripped.slice(Math.max(0, idx - CONTEXT_LOOKBACK), idx + literal.length + CONTEXT_LOOKAHEAD);
      // A legitimate occurrence can only be inside a ${msg(...)} expression.
      // (The previous heuristic also accepted any `="`, which let a hardcoded
      // attribute value such as value="Sign in" pass — a false negative.)
      const inMsg = ctx.includes('msg(') || ctx.includes('${');
      assert.ok(inMsg,
        `Expected "${literal}" in login.ftl to come from \${msg(...)} — found possible hardcoded literal`);
    });
  }
});

describe('AC4 — login-otp.ftl has no hardcoded English UI strings', () => {
  it('login-otp.ftl does not contain hardcoded "Verify" button text', () => {
    // "Verify" must come from ${msg("doSubmit")}, not be hardcoded
    const stripped = loginOtpFtl.replace(/<#--[\s\S]*?-->/g, '');
    // Check that "Verify" does not appear as a free literal (outside msg/attr context)
    const idx = stripped.indexOf('>Verify<');
    assert.strictEqual(idx, -1,
      'Expected login-otp.ftl not to contain hardcoded ">Verify<" — use ${msg("doSubmit")}');
  });

  it('login-otp.ftl does not contain hardcoded "Enter your verification code"', () => {
    assert.ok(
      !loginOtpFtl.includes('Enter your verification code'),
      'Expected login-otp.ftl not to hardcode "Enter your verification code" — use ${msg("loginTotpTitle")}',
    );
  });
});

// ---------------------------------------------------------------------------
// AC5 — WCAG 2.1 AA: persistent labels in login.ftl
// ---------------------------------------------------------------------------

describe('AC5 — login.ftl has persistent <label> for each <input> (no placeholder-only)', () => {
  it('login.ftl contains a <label> element for the email/username field', () => {
    // Keycloak base theme uses label for="username" (or id="username")
    assert.match(loginFtl, /<label\s[^>]*for=["']username["']/,
      'Expected login.ftl to have <label for="username"> for the email input');
  });

  it('login.ftl contains a <label> element for the password field', () => {
    assert.match(loginFtl, /<label\s[^>]*for=["']password["']/,
      'Expected login.ftl to have <label for="password"> for the password input');
  });

  it('login.ftl username/email input has a matching id attribute', () => {
    assert.match(loginFtl, /id=["']username["']/,
      'Expected login.ftl to have id="username" on the email/username input');
  });

  it('login.ftl password input has a matching id attribute', () => {
    assert.match(loginFtl, /id=["']password["']/,
      'Expected login.ftl to have id="password" on the password input');
  });
});

describe('AC5 — login-otp.ftl has persistent <label> for TOTP code input', () => {
  it('login-otp.ftl contains a <label> element for the TOTP code input', () => {
    // Keycloak OTP form typically uses id="totp" or id="otp"
    assert.match(loginOtpFtl, /<label\s[^>]*for=["'](totp|otp)["']/,
      'Expected login-otp.ftl to have <label for="totp"> or <label for="otp">');
  });

  it('login-otp.ftl TOTP input has a matching id attribute (totp or otp)', () => {
    const hasId = /id=["']totp["']/.test(loginOtpFtl) || /id=["']otp["']/.test(loginOtpFtl);
    assert.ok(hasId, 'Expected login-otp.ftl to have id="totp" or id="otp" on the code input');
  });
});

// ---------------------------------------------------------------------------
// ATDD Scaffold — Story 2.6: Six-cell verification-code group (AC2, UX-DR6/UX-DR8)
//
// AC2: the verification surface renders as six individual Noto-Sans-Mono
// cells that behave and are announced as ONE logical field: auto-advance,
// Backspace step-back, paste-fills-all-six, auto-submit-on-6th-digit — with
// exactly one accessible label bound to the group, and a no-JS fallback that
// still POSTs a single 6-digit `totp` form value.
//
// TDD Phase: RED — login-otp.ftl currently ships story 2.5's single
// plain-text placeholder input with no six-cell presentation, no
// otp-input.js enhancement script, and no code-input cell styling in
// login.css. All assertions below are expected to FAIL until Task 3 is
// implemented.
// ---------------------------------------------------------------------------

const OTP_INPUT_JS = path.join(THEME_ROOT, 'resources', 'js', 'otp-input.js');
let otpInputJs = '';

describe('Story 2.6 AC2 — login-otp.ftl posts a single 6-digit `otp` form field (no-JS fallback, NFR8)', () => {
  // NOTE (deliberate, reviewed correction — not a silent workaround): the POST
  // parameter must be "otp", not "totp". Verified by decompiling
  // org.keycloak.authentication.authenticators.browser.OTPFormAuthenticator
  // from the shipped keycloak-services-26.6.3.jar: validateOTP() reads
  // getDecodedFormParameters().getFirst("otp"). The field-level error message
  // key it reports on an invalid code is still "totp" (challenge(context,
  // "invalidTotpMessage", "totp")) — which is why messagesPerField.existsError
  // in login-otp.ftl still checks 'totp' even though the <input> name= is "otp".
  it('login-otp.ftl still declares name="otp" on the underlying field (single POST param, no custom SPI)', () => {
    assert.match(loginOtpFtl, /name=["']otp["']/,
      'Expected login-otp.ftl to keep posting a single name="otp" field — ' +
      'Keycloak\'s OTPFormAuthenticator reads getDecodedFormParameters().getFirst("otp") server-side (NFR8: no custom auth SPI)');
  });

  it('login-otp.ftl constrains the otp field to exactly 6 digits (maxlength=6, numeric input)', () => {
    const inputMatch = loginOtpFtl.match(/<input[^>]*name=["']otp["'][^>]*>/);
    assert.ok(inputMatch, 'Expected to find the <input name="otp" ...> element in login-otp.ftl');
    assert.match(inputMatch[0], /maxlength=["']6["']/,
      'Expected the otp input to declare maxlength="6" (single logical 6-digit field)');
    assert.match(inputMatch[0], /inputmode=["']numeric["']/,
      'Expected the otp input to declare inputmode="numeric" for numeric keyboards / no-JS validation hinting');
  });
});

describe('Story 2.6 AC2 — login-otp.ftl renders a six-cell visual/DOM group for the code input', () => {
  it('login-otp.ftl contains six-cell markup (cell container or six cell elements)', () => {
    const hasCellGroup = /class=["'][^"']*(otp-cell|code-cell|totp-cell)[^"']*["']/.test(loginOtpFtl)
      || /id=["'][^"']*otp-cells?["']/.test(loginOtpFtl);
    assert.ok(
      hasCellGroup,
      'Expected login-otp.ftl to contain six-cell markup — a cell-group container or ' +
      'per-cell class hooks (e.g. class="otp-cell") for the six-Noto-Sans-Mono-cell presentation (AC2, DESIGN.md#Components code-input)',
    );
  });
});

describe('Story 2.6 AC2 — login-otp.ftl code-input group has exactly ONE accessible label (no double-announcement)', () => {
  it('login-otp.ftl does not add a redundant aria-label alongside the existing <label for="totp">', () => {
    // Per story Dev Notes: if the single-<input id="totp"> approach is kept, the
    // existing <label for="totp"> already satisfies accessibility — an
    // additional aria-label on that same input would double-announce to
    // screen readers and must NOT be present. (The <input>'s id= stays "totp"
    // to match the <label for="totp">; only its name= is "otp" — see the
    // POST-field-name correction note above.)
    const inputMatch = loginOtpFtl.match(/<input[^>]*name=["']otp["'][^>]*>/);
    assert.ok(inputMatch, 'Expected to find the <input name="otp" ...> element in login-otp.ftl');
    assert.ok(
      !/aria-label=/.test(inputMatch[0]),
      'Expected the otp <input> to NOT carry a redundant aria-label when a <label for="totp"> already exists ' +
      '(would double-announce to screen readers — story Dev Notes / AC2)',
    );
  });

  it('login-otp.ftl six real-input alternative (if chosen) does not label each cell individually', () => {
    // Only relevant if the six-separate-<input>-elements alternative was chosen.
    // Guard: count <input> elements whose name/id look like individual digit
    // cells (e.g. name="totp-0".."totp-5") and assert none carries its own
    // <label for="..."> — the group must have exactly one label, not six.
    const digitCellInputs = [...loginOtpFtl.matchAll(/<input[^>]*name=["']totp-\d["'][^>]*>/g)];
    if (digitCellInputs.length > 0) {
      for (const match of digitCellInputs) {
        assert.ok(
          !/aria-label=/.test(match[0]),
          'Expected individual digit-cell inputs (six-real-inputs alternative) to NOT carry their own aria-label — ' +
          'the group must be announced as ONE logical field via a single wrapping label/aria-labelledby (AC2)',
        );
      }
    }
  });
});

describe('Story 2.6 AC2 — Noto Sans Mono code-input design tokens are applied in login.css', () => {
  it('login.css references --font-code-family for the code-input cells', () => {
    assert.match(css, /--font-code-family/,
      'Expected login.css to reference var(--font-code-family) (Noto Sans Mono) for the six-cell code input (DESIGN.md#Components code-input)');
  });

  it('login.css references --font-code-size for the code-input cells', () => {
    assert.match(css, /--font-code-size/,
      'Expected login.css to reference var(--font-code-size) (24px) for the six-cell code input');
  });

  it('login.css references --color-border and --color-accent for cell border / focus-cell border', () => {
    assert.match(css, /--color-border/,
      'Expected login.css to reference var(--color-border) for the code-input cell border');
    assert.match(css, /--color-accent/,
      'Expected login.css to reference var(--color-accent) for the code-input focus-cell border');
  });
});

describe('Story 2.6 AC2 — otp-input.js progressive-enhancement script exists (auto-advance/paste/auto-submit)', () => {
  before(() => {
    otpInputJs = fs.existsSync(OTP_INPUT_JS) ? fs.readFileSync(OTP_INPUT_JS, 'utf-8') : '';
  });

  it('keycloak/themes/envocc/login/resources/js/otp-input.js exists', () => {
    assert.ok(
      fs.existsSync(OTP_INPUT_JS),
      `Expected ${OTP_INPUT_JS} to exist (Subtask 3.4 — additive enhancement script, ` +
      'the underlying single <input name="otp"> must still work with this script absent/disabled)',
    );
  });

  it('otp-input.js implements auto-submit behavior on the 6th digit', () => {
    assert.match(otpInputJs, /length\s*===?\s*6|maxlength/i,
      'Expected otp-input.js to check for 6-digit completion (auto-submit-on-6th-digit, AC2)');
  });

  it('otp-input.js does not remove or bypass the name="otp" POST field it enhances', () => {
    assert.ok(
      !/name\s*=\s*["']otp["']\s*=\s*null|removeAttribute\(["']name["']\)/.test(otpInputJs),
      'Expected otp-input.js to be purely additive — it must not strip the name="otp" attribute ' +
      'that makes the no-JS fallback work (progressive enhancement, NFR8-aligned)',
    );
  });
});

// ---------------------------------------------------------------------------
// AC7 — No-JS login path: form uses standard POST
// ---------------------------------------------------------------------------

describe('AC7 — login.ftl uses standard HTML POST form (no-JS path)', () => {
  it('login.ftl has a <form> with method="post"', () => {
    assert.match(loginFtl, /<form\s[^>]*method=["']post["']/i,
      'Expected login.ftl to have <form method="post"> for standard form submission');
  });

  it('login.ftl form has an action attribute (standard POST target)', () => {
    assert.match(loginFtl, /<form\s[^>]*action=/,
      'Expected login.ftl form to have an action attribute');
  });

  it('login-otp.ftl has a <form> with method="post"', () => {
    assert.match(loginOtpFtl, /<form\s[^>]*method=["']post["']/i,
      'Expected login-otp.ftl to have <form method="post"> for standard form submission');
  });
});

describe('AC7 — Any <script> tags in templates are additive, not required for core auth', () => {
  it('login.ftl core form submit does not require inline onclick or onsubmit handlers', () => {
    // The form itself (method=post + action) should work without any JS event handler.
    // We check that the <form> tag itself does not have onsubmit= (which would imply JS required).
    const formMatch = loginFtl.match(/<form\s[^>]+>/)?.[0] ?? '';
    assert.ok(
      !formMatch.includes('onsubmit='),
      'Expected login.ftl <form> to NOT require onsubmit= JavaScript handler for core submit',
    );
  });
});
