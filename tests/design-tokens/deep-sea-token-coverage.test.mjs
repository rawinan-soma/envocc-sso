/**
 * ATDD Scaffold — Story 1.4: Shared Deep Sea Design-Token Stylesheet
 *
 * AC Coverage:
 *   AC1 — File exists at canonical path (design-tokens/deep-sea.css)
 *   AC2 — Complete token coverage (all colors, typography, spacing, radius on :root)
 *   AC3 — WCAG AA comment block present and covers all documented pairings
 *   AC4 — Plain CSS only — no Sass/Less/PostCSS syntax, no external @import
 *   AC5 — Import path math: ../../design-tokens/deep-sea.css resolves from admin/src/app.css
 *   AC6 — Variable naming convention documented in file header
 *
 * Run:  node --test tests/design-tokens/deep-sea-token-coverage.test.mjs
 *
 * Review notes (2026-06-25):
 *   - CSS is read once at module level; per-test reads removed (perf / maintainability)
 *   - Added AC2 typography value spot-checks (was missing — presence only was checked)
 *   - Added AC4 no-external-@import check (AC4 says "no @import of external resources")
 *   - Added AC3 WCAG-block-before-:root ordering check
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MONOREPO_ROOT = path.resolve(__dirname, '..', '..');
const CSS_FILE = path.join(MONOREPO_ROOT, 'design-tokens', 'deep-sea.css');

// ---------------------------------------------------------------------------
// Read the CSS file once at module level — avoids ~100 redundant file reads.
// Individual tests that need the file reference this module-level constant.
// ---------------------------------------------------------------------------

let CSS = '';
let ROOT_PROPS = new Set();

/**
 * Parse all CSS custom property names declared on :root from a CSS string.
 * Returns a Set<string> of "--token-name" strings.
 */
function extractRootCustomProperties(css) {
  const props = new Set();
  // Match :root { ... } block(s)
  const rootBlocks = [...css.matchAll(/:root\s*\{([^}]+)\}/gs)];
  for (const block of rootBlocks) {
    const body = block[1];
    const matches = body.matchAll(/(--[\w-]+)\s*:/g);
    for (const m of matches) {
      props.add(m[1]);
    }
  }
  return props;
}

// Load once before any test runs (node:test guarantees before() runs first).
before(() => {
  CSS = fs.readFileSync(CSS_FILE, 'utf-8');
  ROOT_PROPS = extractRootCustomProperties(CSS);
});

// ---------------------------------------------------------------------------
// AC1: File exists at canonical path
// ---------------------------------------------------------------------------

describe('AC1 — File exists at canonical path', () => {
  it('design-tokens/deep-sea.css exists at monorepo root', () => {
    assert.ok(
      fs.existsSync(CSS_FILE),
      `Expected design-tokens/deep-sea.css to exist at ${CSS_FILE}`,
    );
  });

  it('file is not empty', () => {
    const stat = fs.statSync(CSS_FILE);
    assert.ok(stat.size > 0, 'Expected file to be non-empty');
  });
});

// ---------------------------------------------------------------------------
// AC2: Complete token coverage — colors
// ---------------------------------------------------------------------------

describe('AC2 — Color tokens declared on :root', () => {
  const REQUIRED_COLOR_TOKENS = [
    // Primary
    '--color-primary',
    '--color-primary-hover',
    '--color-accent',
    '--color-primary-foreground',
    // Neutral surface
    '--color-background',
    '--color-surface',
    '--color-surface-raised',
    '--color-border',
    // Text
    '--color-text-primary',
    '--color-text-muted',
    // Semantic: success
    '--color-success',
    '--color-success-bg',
    '--color-success-fg',
    // Semantic: warning
    '--color-warning',
    '--color-warning-bg',
    '--color-warning-fg',
    // Semantic: error
    '--color-error',
    '--color-error-bg',
    '--color-error-fg',
    // Semantic: info
    '--color-info',
    '--color-info-bg',
    '--color-info-border',
    '--color-info-fg',
    // Disabled/neutral status
    '--color-disabled-bg',
    '--color-disabled-fg',
    '--color-disabled-dot',
    // Interaction
    '--color-focus-ring',
  ];

  for (const token of REQUIRED_COLOR_TOKENS) {
    it(`${token} is declared on :root`, () => {
      assert.ok(ROOT_PROPS.has(token), `Expected ${token} to be declared on :root`);
    });
  }
});

// ---------------------------------------------------------------------------
// AC2: Complete token coverage — typography
// ---------------------------------------------------------------------------

describe('AC2 — Typography tokens declared on :root', () => {
  const REQUIRED_TYPOGRAPHY_TOKENS = [
    '--font-family',
    '--font-family-mono',
    // Wordmark
    '--font-wordmark-weight',
    '--font-wordmark-size',
    '--font-wordmark-letter-spacing',
    // H1
    '--font-h1-size',
    '--font-h1-weight',
    '--font-h1-line-height',
    '--font-h1-letter-spacing',
    // H2
    '--font-h2-size',
    '--font-h2-weight',
    '--font-h2-line-height',
    // Body
    '--font-body-size',
    '--font-body-weight',
    '--font-body-line-height',
    // Label
    '--font-label-size',
    '--font-label-weight',
    '--font-label-line-height',
    // Caption
    '--font-caption-size',
    '--font-caption-weight',
    '--font-caption-line-height',
    // Code
    '--font-code-family',
    '--font-code-size',
    '--font-code-weight',
    '--font-code-letter-spacing',
  ];

  for (const token of REQUIRED_TYPOGRAPHY_TOKENS) {
    it(`${token} is declared on :root`, () => {
      assert.ok(ROOT_PROPS.has(token), `Expected ${token} to be declared on :root`);
    });
  }
});

// ---------------------------------------------------------------------------
// AC2: Complete token coverage — spacing
// ---------------------------------------------------------------------------

describe('AC2 — Spacing tokens declared on :root', () => {
  const REQUIRED_SPACING_TOKENS = [
    '--spacing-xs',
    '--spacing-sm',
    '--spacing-md',
    '--spacing-lg',
    '--spacing-xl',
    '--spacing-2xl',
    '--spacing-3xl',
    '--spacing-auth-card-width',
    '--spacing-admin-content-max',
  ];

  for (const token of REQUIRED_SPACING_TOKENS) {
    it(`${token} is declared on :root`, () => {
      assert.ok(ROOT_PROPS.has(token), `Expected ${token} to be declared on :root`);
    });
  }
});

// ---------------------------------------------------------------------------
// AC2: Complete token coverage — border-radius
// ---------------------------------------------------------------------------

describe('AC2 — Border-radius tokens declared on :root', () => {
  const REQUIRED_RADIUS_TOKENS = [
    '--radius-sm',
    '--radius-md',
    '--radius-lg',
    '--radius-full',
  ];

  for (const token of REQUIRED_RADIUS_TOKENS) {
    it(`${token} is declared on :root`, () => {
      assert.ok(ROOT_PROPS.has(token), `Expected ${token} to be declared on :root`);
    });
  }
});

// ---------------------------------------------------------------------------
// AC2: Specific value spot-checks (key hex values from DESIGN.md)
// ---------------------------------------------------------------------------

describe('AC2 — Key hex values match DESIGN.md exactly', () => {
  const VALUE_SPOT_CHECKS = [
    { token: '--color-primary', expected: '#0E5C53' },
    { token: '--color-primary-hover', expected: '#0A4842' },
    { token: '--color-accent', expected: '#137A6E' },
    { token: '--color-primary-foreground', expected: '#FFFFFF' },
    { token: '--color-background', expected: '#F6F4EF' },
    { token: '--color-surface', expected: '#FFFFFF' },
    { token: '--color-surface-raised', expected: '#F1EEE7' },
    { token: '--color-border', expected: '#DCD6CA' },
    { token: '--color-text-primary', expected: '#14211F' },
    { token: '--color-text-muted', expected: '#51605D' },
    { token: '--color-success', expected: '#1A6E50' },
    { token: '--color-success-bg', expected: '#E0F0E8' },
    { token: '--color-success-fg', expected: '#0E4A33' },
    { token: '--color-warning', expected: '#9C6A0F' },
    { token: '--color-warning-bg', expected: '#F4EAD2' },
    { token: '--color-warning-fg', expected: '#5E3F00' },
    { token: '--color-error', expected: '#AE2E21' },
    { token: '--color-error-bg', expected: '#F8E2DF' },
    { token: '--color-error-fg', expected: '#7A1A11' },
    { token: '--color-info', expected: '#1E6E8C' },
    { token: '--color-info-bg', expected: '#E4EFF4' },
    { token: '--color-info-border', expected: '#B8DAE6' },
    { token: '--color-info-fg', expected: '#0F4A60' },
    { token: '--color-disabled-bg', expected: '#E7E3DA' },
    { token: '--color-disabled-fg', expected: '#51605D' },
    { token: '--color-disabled-dot', expected: '#8B938F' },
    { token: '--color-focus-ring', expected: '#137A6E' },
  ];

  for (const { token, expected } of VALUE_SPOT_CHECKS) {
    it(`${token} has value ${expected}`, () => {
      // Match: --color-primary: #0E5C53  (with optional semicolon, whitespace)
      const re = new RegExp(`${token.replace('--', '--')}\\s*:\\s*(${expected})`, 'i');
      assert.match(
        CSS,
        re,
        `Expected ${token} to have value ${expected} in design-tokens/deep-sea.css`,
      );
    });
  }
});

// ---------------------------------------------------------------------------
// AC2: Typography value spot-checks (values from DESIGN.md)
// Previously missing — only token presence was verified; values were unchecked.
// ---------------------------------------------------------------------------

describe('AC2 — Typography values match DESIGN.md', () => {
  const TYPOGRAPHY_VALUE_CHECKS = [
    // Wordmark
    { token: '--font-wordmark-weight', expected: '700' },
    { token: '--font-wordmark-size', expected: '19px' },
    { token: '--font-wordmark-letter-spacing', expected: '0.2px' },
    // H1
    { token: '--font-h1-size', expected: '22px' },
    { token: '--font-h1-weight', expected: '700' },
    { token: '--font-h1-line-height', expected: '1.35' },
    { token: '--font-h1-letter-spacing', expected: '-0.01em' },
    // H2
    { token: '--font-h2-size', expected: '18px' },
    { token: '--font-h2-weight', expected: '700' },
    { token: '--font-h2-line-height', expected: '1.4' },
    // Body
    { token: '--font-body-size', expected: '14px' },
    { token: '--font-body-weight', expected: '400' },
    { token: '--font-body-line-height', expected: '1.6' },
    // Label
    { token: '--font-label-size', expected: '12px' },
    { token: '--font-label-weight', expected: '600' },
    { token: '--font-label-line-height', expected: '1.5' },
    // Caption
    { token: '--font-caption-size', expected: '11px' },
    { token: '--font-caption-weight', expected: '400' },
    { token: '--font-caption-line-height', expected: '1.5' },
    // Code
    { token: '--font-code-size', expected: '24px' },
    { token: '--font-code-weight', expected: '600' },
    { token: '--font-code-letter-spacing', expected: '0.04em' },
  ];

  for (const { token, expected } of TYPOGRAPHY_VALUE_CHECKS) {
    it(`${token} has value ${expected}`, () => {
      // Escape special regex chars in expected (e.g. "-0.01em")
      const escapedExpected = expected.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const re = new RegExp(`${token}\\s*:\\s*${escapedExpected}`, 'i');
      assert.match(CSS, re, `Expected ${token} to equal ${expected}`);
    });
  }

  it('--font-family contains Noto Sans and Noto Sans Thai', () => {
    const re = /--font-family\s*:.*Noto Sans.*Noto Sans Thai/;
    assert.match(CSS, re, 'Expected --font-family to contain "Noto Sans" and "Noto Sans Thai"');
  });

  it('--font-family-mono contains Noto Sans Mono', () => {
    const re = /--font-family-mono\s*:.*Noto Sans Mono/;
    assert.match(CSS, re, 'Expected --font-family-mono to contain "Noto Sans Mono"');
  });

  it('--font-code-family contains Noto Sans Mono', () => {
    const re = /--font-code-family\s*:.*Noto Sans Mono/;
    assert.match(CSS, re, 'Expected --font-code-family to contain "Noto Sans Mono"');
  });
});

// ---------------------------------------------------------------------------
// AC2: Spacing value spot-checks
// ---------------------------------------------------------------------------

describe('AC2 — Spacing values match 4-based scale', () => {
  const SPACING_VALUE_CHECKS = [
    { token: '--spacing-xs', expected: '4px' },
    { token: '--spacing-sm', expected: '8px' },
    { token: '--spacing-md', expected: '12px' },
    { token: '--spacing-lg', expected: '16px' },
    { token: '--spacing-xl', expected: '24px' },
    { token: '--spacing-2xl', expected: '32px' },
    { token: '--spacing-3xl', expected: '48px' },
    { token: '--spacing-auth-card-width', expected: '420px' },
    { token: '--spacing-admin-content-max', expected: '1280px' },
  ];

  for (const { token, expected } of SPACING_VALUE_CHECKS) {
    it(`${token} has value ${expected}`, () => {
      const re = new RegExp(`${token}\\s*:\\s*${expected.replace('px', 'px')}`, 'i');
      assert.match(CSS, re, `Expected ${token} to equal ${expected}`);
    });
  }
});

// ---------------------------------------------------------------------------
// AC2: Border-radius value spot-checks
// ---------------------------------------------------------------------------

describe('AC2 — Border-radius values', () => {
  const RADIUS_VALUE_CHECKS = [
    { token: '--radius-sm', expected: '4px' },
    { token: '--radius-md', expected: '8px' },
    { token: '--radius-lg', expected: '12px' },
    { token: '--radius-full', expected: '999px' },
  ];

  for (const { token, expected } of RADIUS_VALUE_CHECKS) {
    it(`${token} has value ${expected}`, () => {
      const re = new RegExp(`${token}\\s*:\\s*${expected}`, 'i');
      assert.match(CSS, re, `Expected ${token} to equal ${expected}`);
    });
  }
});

// ---------------------------------------------------------------------------
// AC2: No dark-mode block
// ---------------------------------------------------------------------------

describe('AC2 — Light-mode only (no dark-mode block)', () => {
  it('file contains no @media (prefers-color-scheme: dark) block', () => {
    assert.doesNotMatch(
      CSS,
      /prefers-color-scheme\s*:\s*dark/i,
      'Expected no dark-mode media query in design-tokens/deep-sea.css',
    );
  });
});

// ---------------------------------------------------------------------------
// AC3: WCAG AA comment block
// ---------------------------------------------------------------------------

describe('AC3 — WCAG AA comment block in file header', () => {
  it('file header contains WCAG 2.1 AA mention', () => {
    assert.match(CSS, /WCAG/i, 'Expected WCAG mention in file header comment');
  });

  it('WCAG comment block appears before :root (it is in the file header, not inline)', () => {
    const wcagIndex = CSS.search(/WCAG/i);
    const rootIndex = CSS.search(/:root\s*\{/);
    assert.ok(
      wcagIndex !== -1 && rootIndex !== -1 && wcagIndex < rootIndex,
      'Expected the WCAG comment block to appear before the :root rule (i.e. in the file header)',
    );
  });

  it('comment block lists text-primary on background pairing with 14.5:1 ratio', () => {
    assert.match(
      CSS,
      /14\.5\s*:\s*1|14\.5:1/,
      'Expected contrast ratio 14.5:1 for text-primary on background',
    );
  });

  it('comment block lists text-muted on background pairing with 5.4:1 ratio', () => {
    assert.match(
      CSS,
      /5\.4\s*:\s*1|5\.4:1/,
      'Expected contrast ratio 5.4:1 for text-muted on background',
    );
  });

  it('comment block lists primary-foreground on primary pairing with 6.4:1 ratio', () => {
    assert.match(
      CSS,
      /6\.4\s*:\s*1|6\.4:1/,
      'Expected contrast ratio 6.4:1 for primary-foreground on primary',
    );
  });

  it('comment block mentions all semantic pairings (success, warning, error, info)', () => {
    for (const semantic of ['success', 'warning', 'error', 'info']) {
      assert.match(
        CSS,
        new RegExp(semantic, 'i'),
        `Expected semantic pairing "${semantic}" in WCAG comment block`,
      );
    }
  });
});

// ---------------------------------------------------------------------------
// AC4: Plain CSS — no Sass/Less/PostCSS syntax
// ---------------------------------------------------------------------------

describe('AC4 — Plain CSS only (no preprocessor syntax)', () => {
  it('file contains no Sass variable syntax ($variable)', () => {
    assert.doesNotMatch(
      CSS,
      /\$[a-zA-Z_-]+\s*:/,
      'Expected no Sass $variable declarations in design-tokens/deep-sea.css',
    );
  });

  it('file contains no Less variable syntax (@variable)', () => {
    // Exclude valid CSS @rules like @media, @import, @charset, @layer, @keyframes
    const lessVarPattern = /@(?!media|import|charset|layer|keyframes|font-face|supports|namespace|page)[a-zA-Z_-]+\s*:/;
    assert.doesNotMatch(CSS, lessVarPattern, 'Expected no Less @variable declarations');
  });

  it('file contains no @use or @forward (Sass module syntax)', () => {
    assert.doesNotMatch(CSS, /@use\s+|@forward\s+/, 'Expected no Sass @use/@forward syntax');
  });

  it('file contains no nesting operator (&) that requires a preprocessor', () => {
    // Simple check: & used as Sass/Less parent selector (inside a rule body followed by identifier)
    assert.doesNotMatch(CSS, /&[.:#\w]/, 'Expected no preprocessor nesting (&.class) syntax');
  });

  it('file contains no @import of external resources (AC4: no external dependencies)', () => {
    // AC4 requires no @import of external resources.
    // Strip CSS comments first so the @import example in the header comment
    // (documenting how *consumers* import this file) does not trigger a false positive.
    const cssWithoutComments = CSS.replace(/\/\*[\s\S]*?\*\//g, '');
    assert.doesNotMatch(
      cssWithoutComments,
      /@import\s/,
      'Expected no @import in design-tokens/deep-sea.css outside of comments — file must be self-contained plain CSS',
    );
  });
});

// ---------------------------------------------------------------------------
// AC5: Import path resolves correctly from admin/src/app.css
// ---------------------------------------------------------------------------

describe('AC5 — Import path math from admin/src/app.css', () => {
  it('../../design-tokens/deep-sea.css resolves to the canonical file from admin/src/', () => {
    // admin/src/ → admin/ → monorepo root → design-tokens/deep-sea.css
    // Two levels up from admin/src/ lands at the monorepo root
    const adminSrcDir = path.join(MONOREPO_ROOT, 'admin', 'src');
    const resolvedPath = path.resolve(adminSrcDir, '../../design-tokens/deep-sea.css');
    assert.equal(
      resolvedPath,
      CSS_FILE,
      `Expected ../../design-tokens/deep-sea.css from admin/src/ to resolve to ${CSS_FILE}`,
    );
  });

  it('the file referenced by the import path exists', () => {
    const adminSrcDir = path.join(MONOREPO_ROOT, 'admin', 'src');
    const resolvedPath = path.resolve(adminSrcDir, '../../design-tokens/deep-sea.css');
    assert.ok(
      fs.existsSync(resolvedPath),
      `Import path ../../design-tokens/deep-sea.css from admin/src/ does not resolve to an existing file`,
    );
  });
});

// ---------------------------------------------------------------------------
// AC6: Variable naming convention documented in file header
// ---------------------------------------------------------------------------

describe('AC6 — Naming convention documented in file header', () => {
  it('file header documents --color-* prefix convention', () => {
    assert.match(CSS, /--color-\*/, 'Expected --color-* prefix documented in file header');
  });

  it('file header documents --font-* prefix convention', () => {
    assert.match(CSS, /--font-\*/, 'Expected --font-* prefix documented in file header');
  });

  it('file header documents --spacing-* prefix convention', () => {
    assert.match(CSS, /--spacing-\*/, 'Expected --spacing-* prefix documented in file header');
  });

  it('file header documents --radius-* prefix convention', () => {
    assert.match(CSS, /--radius-\*/, 'Expected --radius-* prefix documented in file header');
  });

  it('file header references the source of truth (DESIGN.md)', () => {
    assert.match(CSS, /DESIGN\.md/, 'Expected DESIGN.md source reference in file header');
  });

  it('file header documents the no-raw-hex rule for downstream consumers', () => {
    // AC6 requires the naming convention to be documented so future stories follow it.
    // The header must communicate that consumers use var(--...) not raw hex.
    assert.match(
      CSS,
      /var\(--/,
      'Expected file header to show var(--...) usage example for downstream consumers',
    );
  });
});
