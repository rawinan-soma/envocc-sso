---
baseline_commit: 1b225df731c8ef88c3862b2bad5caf1d03908240
---

# Story 1.4: Shared Deep Sea design-token stylesheet

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want one canonical Deep Sea token stylesheet at `design-tokens/deep-sea.css`,
so that the Keycloak theme and the admin app render with identical, AA-verified visual identity using shared CSS variables.

## Acceptance Criteria

1. **File exists at canonical path:** `design-tokens/deep-sea.css` exists at the monorepo root.
2. **Complete token coverage:** The file exposes ALL tokens from DESIGN.md frontmatter as CSS custom properties on `:root` — colors (primary, primary-hover, accent, primary-foreground, background, surface, surface-raised, border, text-primary, text-muted, all semantic success/warning/error/info sets, disabled set, focus-ring), typography (font-family, font-family-mono, and the five type-scale entries: wordmark, h1, h2, body, label, caption, code), spacing scale (xs, sm, md, lg, xl, 2xl, 3xl, auth-card-width, admin-content-max), and border-radius scale (sm, md, lg, full). Light-mode only — no `@media (prefers-color-scheme: dark)` block. [UX-DR1]
3. **WCAG AA verified — text/background pairings:** Every text-on-background pairing documented in DESIGN.md passes WCAG 2.1 AA (≥ 4.5:1 for normal text, ≥ 3:1 for large text). The file must include a comment header block listing all verified pairings with their contrast ratios (sourced from DESIGN.md). These are: `text-primary` (#14211F) on `background` (#F6F4EF) = 14.5:1 (AAA); `text-muted` (#51605D) on `background` = 5.4:1 (AA); `primary-foreground` (#FFF) on `primary` (#0E5C53) = 6.4:1 (AA); `success-fg` on `success-bg` (AA); `warning-fg` on `warning-bg` (AA); `error-fg` on `error-bg` (AA); `info-fg` on `info-bg` (AA).
4. **Importable by Keycloak theme (no build step):** The file is plain CSS — no Sass/Less/PostCSS preprocessing required, no `@import` of external resources. A Keycloak FreeMarker template can reference it via a `<link>` tag pointing to the static resource path.
5. **Importable by admin app (SvelteKit):** `admin/src/app.css` can import it via a relative path (`../../design-tokens/deep-sea.css`) or the SvelteKit alias (`$lib` is `src/lib`, so this is done as a plain CSS `@import` in `app.css` — not a `$lib` path). Architecture confirms: `admin/src/app.css` imports `../../design-tokens/deep-sea.css`. [Source: architecture.md#Project Structure & Boundaries]
6. **No hard-coded values in consuming surfaces:** Downstream (theme, admin app) MUST reference only CSS variable names (e.g., `var(--color-primary)`), never raw hex. This story establishes the naming convention — document the variable naming scheme in the file header so future stories follow it.

## Tasks / Subtasks

- [x] Task 1: Create `design-tokens/` directory and `deep-sea.css` file (AC: 1)
  - [x] Subtask 1.1: Create `design-tokens/` at the monorepo root (same level as `compose.yaml`, `keycloak/`, `admin/`)
  - [x] Subtask 1.2: Create `design-tokens/deep-sea.css` with file header comment (naming convention, WCAG ratios, usage instructions)

- [x] Task 2: Declare all color tokens as CSS custom properties on `:root` (AC: 2, 3)
  - [x] Subtask 2.1: Primary/accent/foreground tokens: `--color-primary`, `--color-primary-hover`, `--color-accent`, `--color-primary-foreground`
  - [x] Subtask 2.2: Neutral surface tokens: `--color-background`, `--color-surface`, `--color-surface-raised`, `--color-border`
  - [x] Subtask 2.3: Text tokens: `--color-text-primary`, `--color-text-muted`
  - [x] Subtask 2.4: Semantic success group: `--color-success`, `--color-success-bg`, `--color-success-fg`
  - [x] Subtask 2.5: Semantic warning group: `--color-warning`, `--color-warning-bg`, `--color-warning-fg`
  - [x] Subtask 2.6: Semantic error group: `--color-error`, `--color-error-bg`, `--color-error-fg`
  - [x] Subtask 2.7: Semantic info group: `--color-info`, `--color-info-bg`, `--color-info-border`, `--color-info-fg`
  - [x] Subtask 2.8: Disabled/neutral status tokens: `--color-disabled-bg`, `--color-disabled-fg`, `--color-disabled-dot`
  - [x] Subtask 2.9: Focus ring token: `--color-focus-ring`

- [x] Task 3: Declare all typography tokens as CSS custom properties on `:root` (AC: 2)
  - [x] Subtask 3.1: Font-family stacks: `--font-family` (Noto Sans + Noto Sans Thai + system-ui), `--font-family-mono` (Noto Sans Mono + ui-monospace)
  - [x] Subtask 3.2: Wordmark scale: `--font-wordmark-weight`, `--font-wordmark-size`, `--font-wordmark-letter-spacing`
  - [x] Subtask 3.3: Heading scale: `--font-h1-size`, `--font-h1-weight`, `--font-h1-line-height`, `--font-h1-letter-spacing`, `--font-h2-size`, `--font-h2-weight`, `--font-h2-line-height`
  - [x] Subtask 3.4: Body/label/caption scale: `--font-body-size`, `--font-body-weight`, `--font-body-line-height`, `--font-label-size`, `--font-label-weight`, `--font-label-line-height`, `--font-caption-size`, `--font-caption-weight`, `--font-caption-line-height`
  - [x] Subtask 3.5: Code scale: `--font-code-family`, `--font-code-size`, `--font-code-weight`, `--font-code-letter-spacing`

- [x] Task 4: Declare all spacing tokens as CSS custom properties on `:root` (AC: 2)
  - [x] Subtask 4.1: Base scale: `--spacing-xs` (4px), `--spacing-sm` (8px), `--spacing-md` (12px), `--spacing-lg` (16px), `--spacing-xl` (24px), `--spacing-2xl` (32px), `--spacing-3xl` (48px)
  - [x] Subtask 4.2: Layout tokens: `--spacing-auth-card-width` (420px), `--spacing-admin-content-max` (1280px)

- [x] Task 5: Declare all border-radius tokens as CSS custom properties on `:root` (AC: 2)
  - [x] Subtask 5.1: `--radius-sm` (4px), `--radius-md` (8px), `--radius-lg` (12px), `--radius-full` (999px)

- [x] Task 6: Verify file is plain CSS and importable (AC: 4, 5)
  - [x] Subtask 6.1: Confirm no Sass/Less/PostCSS syntax (no `$var`, no `&nesting` that requires a preprocessor, no `@use`/`@forward`)
  - [x] Subtask 6.2: Verify the relative import path `../../design-tokens/deep-sea.css` resolves correctly from `admin/src/app.css`
  - [x] Subtask 6.3: Document the Keycloak static resource path convention in the file header (theme JAR/directory must include the file — handled in story 2.5; this story only creates the source file)

- [x] Task 7: Self-validation — cross-check all values against DESIGN.md (AC: 2, 3)
  - [x] Subtask 7.1: Count tokens declared vs. DESIGN.md frontmatter — zero gaps
  - [x] Subtask 7.2: Verify every hex value matches DESIGN.md exactly (copy from source, do not rekey from memory)
  - [x] Subtask 7.3: Confirm WCAG comment block covers all documented pairings

## Dev Notes

### What This Story Builds

A single static CSS file: `design-tokens/deep-sea.css` at the monorepo root. This is purely a CSS authoring task — no runtime, no server, no SvelteKit, no Keycloak config. The file establishes the shared visual contract between two consuming surfaces:
- **Keycloak theme** (`keycloak/themes/envocc/`) — imports via `<link>` in FreeMarker templates (story 2.5)
- **Admin app** (`admin/src/app.css`) — imports via CSS `@import '../../design-tokens/deep-sea.css'` (story 4.1)

Both consumers reference tokens as `var(--token-name)`. Neither consumer is built in this story — they exist as future targets.

### Canonical Token Source

ALL values MUST come from `_bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/DESIGN.md` frontmatter. That file is the single source of truth. Do not rekey hex values — copy exactly. Key values for reference (but always defer to DESIGN.md):

**Colors:**
- `primary: '#0E5C53'` — teal trust signal; white on it = 6.4:1 (AA, large AAA)
- `primary-hover: '#0A4842'` — darker teal for hover/active
- `accent: '#137A6E'` — brighter teal for focus/sensitive actions
- `primary-foreground: '#FFFFFF'`
- `background: '#F6F4EF'` — warm-sand page
- `surface: '#FFFFFF'` — card/panel fill
- `surface-raised: '#F1EEE7'` — table head/inset fill
- `border: '#DCD6CA'` — greige hairline
- `text-primary: '#14211F'` — on background = 14.5:1 (AAA)
- `text-muted: '#51605D'` — on background = 5.4:1 (AA)
- Semantic sets (all AA on their pairing):
  - `success: '#1A6E50'`, `success-bg: '#E0F0E8'`, `success-fg: '#0E4A33'`
  - `warning: '#9C6A0F'`, `warning-bg: '#F4EAD2'`, `warning-fg: '#5E3F00'`
  - `error: '#AE2E21'`, `error-bg: '#F8E2DF'`, `error-fg: '#7A1A11'`
  - `info: '#1E6E8C'`, `info-bg: '#E4EFF4'`, `info-border: '#B8DAE6'`, `info-fg: '#0F4A60'`
  - `disabled-bg: '#E7E3DA'`, `disabled-fg: '#51605D'`, `disabled-dot: '#8B938F'`
  - `focus-ring: '#137A6E'`

**Typography (from DESIGN.md frontmatter):**
- `fontFamily: '"Noto Sans", "Noto Sans Thai", system-ui, sans-serif'`
- `fontFamilyMono: '"Noto Sans Mono", ui-monospace, monospace'`
- Wordmark: weight 700, size 19px, letter-spacing 0.2px
- H1: 22px, 700, line-height 1.35, letter-spacing -0.01em
- H2: 18px, 700, line-height 1.4
- Body: 14px, 400, line-height 1.6
- Label: 12px, 600, line-height 1.5
- Caption: 11px, 400, line-height 1.5
- Code: Noto Sans Mono, 24px, 600, letter-spacing 0.04em

**Spacing (4-based scale):** xs=4px, sm=8px, md=12px, lg=16px, xl=24px, 2xl=32px, 3xl=48px, auth-card-width=420px, admin-content-max=1280px

**Border-radius:** sm=4px, md=8px, lg=12px, full=999px

### CSS Variable Naming Convention

Use the following prefix scheme (document in file header so all future stories follow it):

```
--color-*       colors (primary, background, text-primary, success, etc.)
--font-*        typography (--font-family, --font-h1-size, --font-body-line-height, etc.)
--spacing-*     spacing (--spacing-xs, --spacing-auth-card-width, etc.)
--radius-*      border-radius (--radius-sm, --radius-md, etc.)
```

For compound typography tokens: `--font-{role}-{property}` — e.g., `--font-h1-size`, `--font-body-line-height`, `--font-wordmark-weight`.

### File Structure Pattern

```css
/* ============================================================
 * EnvOcc SSO — Deep Sea Design Tokens
 * ============================================================
 *
 * Single source of truth for all visual design tokens.
 * Import this file into both consuming surfaces:
 *   - Keycloak theme: <link> in FreeMarker template (story 2.5)
 *   - Admin app:      @import '../../design-tokens/deep-sea.css' (admin/src/app.css, story 4.1)
 *
 * Naming convention:
 *   --color-*     colors
 *   --font-*      typography
 *   --spacing-*   spacing
 *   --radius-*    border-radius
 *
 * WCAG 2.1 AA verified pairings (contrast ratios):
 *   text-primary (#14211F) on background (#F6F4EF): 14.5:1 (AAA)
 *   text-muted   (#51605D) on background (#F6F4EF):  5.4:1 (AA)
 *   primary-fg   (#FFFFFF) on primary   (#0E5C53):   6.4:1 (AA)
 *   success-fg   (#0E4A33) on success-bg (#E0F0E8): [AA — from DESIGN.md]
 *   warning-fg   (#5E3F00) on warning-bg (#F4EAD2): [AA — from DESIGN.md]
 *   error-fg     (#7A1A11) on error-bg  (#F8E2DF): [AA — from DESIGN.md]
 *   info-fg      (#0F4A60) on info-bg   (#E4EFF4): [AA — from DESIGN.md]
 *
 * Light-mode only. No dark-mode block.
 * Source: _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/DESIGN.md
 * ============================================================ */

:root {
  /* Colors — primary */
  /* Colors — neutral */
  /* Colors — text */
  /* Colors — semantic: success */
  /* Colors — semantic: warning */
  /* Colors — semantic: error */
  /* Colors — semantic: info */
  /* Colors — disabled/neutral status */
  /* Colors — interaction */

  /* Typography — font families */
  /* Typography — wordmark */
  /* Typography — headings */
  /* Typography — body, label, caption */
  /* Typography — code */

  /* Spacing */
  /* Layout */

  /* Border radius */
}
```

### Project Structure Notes

- **New directory:** `design-tokens/` at monorepo root (same level as `compose.yaml`). Architecture tree explicitly shows: `design-tokens/` → `deep-sea.css`. [Source: architecture.md#Complete Project Tree]
- **No `admin/` files modified in this story.** The import statement (`@import '../../design-tokens/deep-sea.css'`) goes into `admin/src/app.css` — but that file does not exist yet (the admin scaffold is story 4.1). This story only creates the source CSS file.
- **No `keycloak/` files modified in this story.** The Keycloak theme FreeMarker templates will `<link>` to this file — that wiring happens in story 2.5.
- **No `.gitignore` changes needed** — the `design-tokens/` directory contains only versioned source.

### Story 1-1 Learnings (Previous Story in Epic 1)

Story 1-1 (Docker Compose stack) established the codebase baseline on `main`. Key learnings relevant to story 1-4:
- The monorepo root now contains `.env.example`, `.gitignore`, `.gitleaks.toml`, `compose.yaml`, `keycloak/Dockerfile`, `postgres/init/01-init-databases.sh`. Create `design-tokens/` alongside these.
- **Commit style:** descriptive commit message with story prefix `feat(story-1-4): ...`
- **Verification:** the code-review workflow (adversarial review) runs after dev-story. For this story, verification = manual inspection of CSS variable names, hex values against DESIGN.md, and the import path calculation.

### Downstream Stories That Depend on This File

- **Story 2.5** (Branded Deep Sea login theme) — Keycloak FreeMarker templates `<link>` to `design-tokens/deep-sea.css` from the theme's static resources.
- **Story 4.1** (Admin app scaffold) — `admin/src/app.css` imports `../../design-tokens/deep-sea.css`.
- All subsequent admin UI stories assume `var(--color-*)`, `var(--font-*)`, `var(--spacing-*)`, `var(--radius-*)` are available globally.

### No Dependencies

Story 1-4 has no dependencies (dependency-graph.md: "Ready to Work: Yes"). It can be built in parallel with story 1.1. The file is pure CSS — no Docker, no Keycloak, no SvelteKit needed to author or verify it.

### Testing / Verification Approach

No automated tests for a CSS custom-properties file. Verification is:
1. **Token completeness check:** diff the DESIGN.md frontmatter keys against the CSS custom properties declared — zero gaps.
2. **Value accuracy check:** every hex value cross-checked against DESIGN.md.
3. **WCAG comment block:** all documented pairings are listed with ratios.
4. **Import path math:** `admin/src/app.css` → `../../design-tokens/deep-sea.css` — count the `../` levels: `admin/src/` → `admin/` → monorepo root → `design-tokens/deep-sea.css`. Correct.
5. **Plain CSS lint:** no Sass/Less syntax, no unknown at-rules.

### References

- [Source: _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/DESIGN.md#frontmatter + Colors + Typography + Layout & Spacing + Shapes] — all token values
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.4] — story requirements
- [Source: _bmad-output/planning-artifacts/epics.md#UX Design Requirements — UX-DR1] — `design-tokens/deep-sea.css` requirement
- [Source: _bmad-output/planning-artifacts/architecture.md#Complete Project Tree] — `design-tokens/deep-sea.css` canonical location
- [Source: _bmad-output/planning-artifacts/architecture.md#Decision 2 — Custom-surface stack] — admin app imports same Deep Sea tokens; both consume via CSS variables, no shared framework
- [Source: _bmad-output/implementation-artifacts/dependency-graph.md] — story 1.4 has no dependencies; parallel to 1.1; required by 1.5, 2.5

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (Claude Code)

### Debug Log References

None.

### Completion Notes List

- Created `design-tokens/` directory at monorepo root alongside `compose.yaml`, `.gitignore`, etc.
- Created `design-tokens/deep-sea.css` — 89 lines, pure CSS, no preprocessor syntax.
- Declared 27 color tokens, 25 typography tokens, 9 spacing tokens, 4 border-radius tokens = 65 custom properties total on `:root`.
- All hex values copied verbatim from DESIGN.md frontmatter — no rekeying.
- File header includes: naming convention (`--color-*`, `--font-*`, `--spacing-*`, `--radius-*`), WCAG 2.1 AA comment block with all 7 documented pairings and contrast ratios (14.5:1, 5.4:1, 6.4:1, plus 4 semantic AA pairings), Keycloak `<link>` usage note, admin app `@import` usage note, and DESIGN.md source reference.
- Dark-mode block: absent (light-mode only, per AC2).
- Import path verified: `../../design-tokens/deep-sea.css` from `admin/src/` resolves to monorepo root `design-tokens/deep-sea.css` (path math confirmed by ATDD test).
- ATDD tests: activated (removed `.skip`). All 124 tests pass (0 fail, 0 skip).
- Note: one subtlety — initial CSS file header contained the prose phrase containing `prefers-color-scheme: dark` which caused the no-dark-mode ATDD test to match. Rephrased to "no dark-mode media query block" — all tests green.

### Change Log

- 2026-06-25: Initial implementation — created `design-tokens/deep-sea.css` with complete Deep Sea token set; all 124 ATDD tests passing; story moved to review.

### File List

- `design-tokens/deep-sea.css` — NEW: canonical Deep Sea CSS custom-properties stylesheet (65 custom properties on :root)
- `tests/design-tokens/deep-sea-token-coverage.test.mjs` — MODIFIED: activated tests (removed .skip); all 124 tests now live and passing
