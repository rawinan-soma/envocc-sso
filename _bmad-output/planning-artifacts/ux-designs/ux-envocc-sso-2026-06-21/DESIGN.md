---
name: EnvOcc SSO
description: Visual identity for EnvOcc's single sign-on — staff-auth surfaces + one role-gated admin console. Calm Clinical direction, Deep Sea palette, light-mode only, WCAG 2.1 AA. Branded UX is the #1 anti-phishing signal.
status: final
created: 2026-06-21
updated: 2026-06-22
changeNote: "2026-06-22 — two login methods: email+password+TOTP (6-digit code-input) OR Login with ThaiD (a federation button on Sign in). See Components."
colors:
  # Deep Sea — light mode only. Every text/background pairing AA-verified
  # (ratios in the Colors section). No second brand hue, no dark mode.
  primary: '#0E5C53'          # teal — the trust signal. white on it = 6.4:1 (AA / large AAA)
  primary-hover: '#0A4842'    # darker teal step for hover/active
  accent: '#137A6E'           # brighter teal — sensitive-action rules (step-up), focus emphasis
  primary-foreground: '#FFFFFF'
  background: '#F6F4EF'        # warm-sand page
  surface: '#FFFFFF'          # card / panel fill
  surface-raised: '#F1EEE7'   # table head / inset fill (greige)
  border: '#DCD6CA'           # greige hairline
  text-primary: '#14211F'     # dark slate-teal. on background = 14.5:1 (AAA)
  text-muted: '#51605D'       # on background = 5.4:1 (AA). Never for security copy.
  # --- Semantic: fill (on white) · soft tint-bg · on-tint text ---
  success: '#1A6E50'
  success-bg: '#E0F0E8'
  success-fg: '#0E4A33'       # on success-bg (AA)
  warning: '#9C6A0F'
  warning-bg: '#F4EAD2'
  warning-fg: '#5E3F00'       # on warning-bg (AA)
  error: '#AE2E21'
  error-bg: '#F8E2DF'
  error-fg: '#7A1A11'         # on error-bg (AA)
  info: '#1E6E8C'             # info = the pinned anti-phishing banner
  info-bg: '#E4EFF4'
  info-border: '#B8DAE6'
  info-fg: '#0F4A60'          # on info-bg (AA)
  disabled-bg: '#E7E3DA'      # neutral status pill fill
  disabled-fg: '#51605D'      # uses text-muted; pairs with an icon, never color alone
  disabled-dot: '#8B938F'
  focus-ring: '#137A6E'       # accent, rendered as a 3px outer ring at ~20% alpha
typography:
  # Noto Sans + Noto Sans Thai for ALL roles (Thai-ready). All-sans, no serif.
  # Generous line-height throughout for Thai diacritics.
  fontFamily: '"Noto Sans", "Noto Sans Thai", system-ui, sans-serif'
  fontFamilyMono: '"Noto Sans Mono", ui-monospace, monospace'   # 6-digit code cells + code display (e.g. client secrets)
  wordmark:
    fontFamily: '"Noto Sans", "Noto Sans Thai", sans-serif'
    fontWeight: '700'
    fontSize: 19px
    letterSpacing: 0.2px
  h1:
    fontSize: 22px
    fontWeight: '700'
    lineHeight: '1.35'
    letterSpacing: -0.01em
  h2:
    fontSize: 18px
    fontWeight: '700'
    lineHeight: '1.4'
  body:
    fontSize: 14px
    fontWeight: '400'
    lineHeight: '1.6'        # generous — Thai diacritics
  label:
    fontSize: 12px
    fontWeight: '600'
    lineHeight: '1.5'
  caption:
    fontSize: 11px
    fontWeight: '400'
    lineHeight: '1.5'
  code:
    fontFamily: '"Noto Sans Mono", ui-monospace, monospace'
    fontSize: 24px
    fontWeight: '600'
    letterSpacing: 0.04em
rounded:
  # Calm institutional rounding.
  sm: 4px        # chips, dots
  md: 8px        # inputs, buttons, code cells
  lg: 12px       # cards, modals, table containers
  full: 999px    # status pills
spacing:
  # 4-based scale.
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  '2xl': 32px
  '3xl': 48px
  auth-card-width: 420px
  admin-content-max: 1280px
components:
  app-header:
    background: '{colors.surface}'
    borderBottom: '1px solid {colors.border}'
    accentRule: '2px solid {colors.accent}'   # bronze/accent rule under the header
    height: 56px
  wordmark-seal:
    sealBackground: '{colors.primary}'        # CSS-drawable teal rounded square + medical cross
    sealForeground: '{colors.primary-foreground}'
    sealRadius: '{rounded.md}'
    title: '{typography.wordmark}'
  auth-card:
    background: '{colors.surface}'
    border: '1px solid {colors.border}'
    radius: '{rounded.lg}'
    width: '{spacing.auth-card-width}'
    padding: '{spacing.2xl}'
    shadow: '0 8px 26px rgba(14,92,83,0.10)'  # soft teal-tinted lift
  text-input:
    background: '{colors.surface}'
    border: '1.5px solid {colors.border}'
    radius: '{rounded.md}'
    text: '{colors.text-primary}'
    focusBorder: '{colors.accent}'
    focusRing: '0 0 0 3px rgba(19,122,110,0.15)'
  password-input:
    extends: text-input
    revealToggle: '{colors.text-muted}'       # eye icon, switches to {colors.primary} on press
  code-input:
    cellFont: '{typography.code}'
    cells: 6
    cellBackground: '{colors.surface}'
    cellBorder: '1.5px solid {colors.border}'
    cellRadius: '{rounded.md}'
    cellFocusBorder: '{colors.accent}'
  button-primary:
    background: '{colors.primary}'
    foreground: '{colors.primary-foreground}'
    hover: '{colors.primary-hover}'
    radius: '{rounded.md}'
  button-secondary:
    background: '{colors.surface}'
    foreground: '{colors.primary}'
    border: '1.5px solid {colors.border}'
    radius: '{rounded.md}'
  button-link:
    foreground: '{colors.primary}'
    decoration: 'underline'
  button-destructive:
    background: '{colors.error}'
    foreground: '{colors.primary-foreground}'
    radius: '{rounded.md}'
  status-pill:
    radius: '{rounded.full}'
    active: { bg: '{colors.success-bg}', fg: '{colors.success-fg}', dot: '{colors.success}' }
    pending: { bg: '{colors.warning-bg}', fg: '{colors.warning-fg}', dot: '{colors.warning}' }
    disabled: { bg: '{colors.disabled-bg}', fg: '{colors.disabled-fg}', dot: '{colors.disabled-dot}' }
  data-table-row:
    text: '{colors.text-primary}'
    metaText: '{colors.text-muted}'
    borderBottom: '1px solid {colors.border}'
    headBackground: '{colors.surface-raised}'
  alert:
    radius: '{rounded.md}'
    info: { bg: '{colors.info-bg}', border: '{colors.info-border}', fg: '{colors.info-fg}', icon: '{colors.info}' }
    success: { bg: '{colors.success-bg}', fg: '{colors.success-fg}', icon: '{colors.success}' }
    warning: { bg: '{colors.warning-bg}', fg: '{colors.warning-fg}', icon: '{colors.warning}' }
    error: { bg: '{colors.error-bg}', fg: '{colors.error-fg}', icon: '{colors.error}' }
  anti-phishing-banner:
    extends: alert.info
    pinned: true
    fullContrast: true        # security copy never muted
  modal:
    background: '{colors.surface}'
    radius: '{rounded.lg}'
    overlay: 'rgba(20,33,31,0.45)'
    shadow: '0 16px 48px rgba(14,92,83,0.18)'
  step-up-dialog:
    extends: modal
    accentRule: '3px solid {colors.accent}'   # signals sensitive re-auth
  file-upload:
    border: '2px dashed {colors.border}'
    radius: '{rounded.lg}'
    activeBorder: '{colors.accent}'
  csv-preview-table:
    clean: { rowBg: '{colors.surface}', text: '{colors.text-primary}' }
    invalid: { rowBg: '{colors.error-bg}', text: '{colors.error-fg}', marker: '{colors.error}' }
    duplicate: { rowBg: '{colors.warning-bg}', text: '{colors.warning-fg}', marker: '{colors.warning}' }
---

<!-- DESIGN.md — visual identity (how it looks). Distilled from .decision-log.md at Finalize. -->

## Brand & Style

EnvOcc SSO is the single front door to a government occupational- and environmental-health system, used by non-technical staff. **The brand exists to do one job: make the login unmistakably legitimate.** Anti-phishing is the #1 requirement — if the surface looks generic or copyable, the security goal fails. So the identity is deliberately distinctive, consistent, and hard to fake convincingly.

The chosen direction is **Calm Clinical**: soft, airy, reassuring, modern-government health. Generous whitespace, a humanist all-sans voice, and a single teal trust-color put a rushed or anxious staff member at ease. The register is *official and trustworthy*, never bureaucratic or intimidating — reassurance, not fear, is what builds the trust that defeats phishing.

One identity, **two postures**: staff-auth is spacious and centered (a single ~420px card on a warm-sand field, rendered top-level only); admin is desktop-first and data-dense (content capped at ~1280px, real tables, flat tone). They share every token — color, type, shape — so a staff member who recognizes the login also recognizes the console.

## Colors

The palette is **Deep Sea** — deeper, cooler, authoritative teal over warm-sand neutrals. **Light mode only.** Teal is the single brand hue and the trust signal; there is no second brand color and no gradient.

- **Primary `#0E5C53`** — teal. Primary buttons, the seal, active nav, links. White on it = **6.4:1** (AA; AAA at large). Hover/active steps down to **`#0A4842`**.
- **Accent `#137A6E`** — brighter teal. Reserved for emphasis on sensitive moments: the header rule, the step-up re-auth rule, and focus rings. Same family as primary — it is *not* a second brand hue.
- **Background `#F6F4EF`** (warm sand) · **Surface `#FFFFFF`** (card fill) · **Surface-raised `#F1EEE7`** (table heads) · **Border `#DCD6CA`** (greige hairline).
- **Text-primary `#14211F`** (dark slate-teal) on background = **14.5:1** (AAA). **Text-muted `#51605D`** on background = **5.4:1** (AA) — for secondary meta only, never for security-critical copy.
- **Semantic sets** — each is `fill` (on white) · `tint-bg` · `on-tint text`, all AA on their pairing:
  - **Success** `#1A6E50` · bg `#E0F0E8` · text `#0E4A33`
  - **Warning** `#9C6A0F` · bg `#F4EAD2` · text `#5E3F00`
  - **Error** `#AE2E21` · bg `#F8E2DF` · text `#7A1A11`
  - **Info** `#1E6E8C` · bg `#E4EFF4` · border `#B8DAE6` · text `#0F4A60` — **info is the pinned anti-phishing banner.**

**Values lifted vs chosen:** all core tokens, the four semantic trios, and the three status-pill treatments are lifted exactly from `color-themes-1.html` variation 2 ("Deep Sea"), with AA ratios from that file's contrast notes. **Chosen (AA-safe, not in the source):** `surface-raised #F1EEE7` (file's `--head-bg`, promoted to a named token); `primary-foreground #FFFFFF`; `focus-ring`/`focus-border` set to accent `#137A6E` (rendered as a 3px ring at ~15–20% alpha, so contrast is non-text); `disabled` pill `bg #E7E3DA` / `fg #51605D` / `dot #8B938F` (lifted from the variation-2 pill row).

## Typography

**Noto Sans + Noto Sans Thai for every role** — the system is Thai-ready for the owner's later translation, so both faces are stacked everywhere. **All-sans, no serif.** **Noto Sans Mono** is used for the 6-digit verification-code cells and code-style display (e.g., client secrets/IDs in the System console). The wordmark is **bold Noto Sans**.

Line-height runs **generous** (body `1.6`, headings `1.35–1.4`) so Thai diacritics above and below the baseline never collide. Ramp: H1 22px / H2 18px / body 14px / label 12px (600) / caption 11px / code 24px mono. Labels are the only role set in semibold; everything else is regular weight with bold reserved for the wordmark and headings.

## Layout & Spacing

A **4-based spacing scale** (4 / 8 / 12 / 16 / 24 / 32 / 48). Two layout postures share it:

- **Staff-auth** — responsive, centered. One **~420px** auth card on the warm-sand page, vertically and horizontally centered, generous internal padding (`2xl`/32px). Mobile-friendly; the card stays single-column and never exceeds the viewport.
- **Admin** — desktop-first, data-dense. Content max **~1280px**, left-aligned within the role-gated shell (HR section and System section are never shown together). Tables are the primary surface; spacing tightens relative to auth.

## Elevation & Depth

Restrained, paper-on-paper. The **auth card** is the one place that lifts — a soft, teal-tinted shadow (`0 8px 26px rgba(14,92,83,0.10)`) that reads as a single sheet floating just above the sand, reinforcing it as *the* thing to act on. **Admin is mostly flat:** hierarchy comes from tone (surface vs surface-raised) and 1px greige rules, not shadow. Modals and the step-up dialog get a deeper but still soft teal-tinted shadow; everything else sits at zero elevation.

## Shapes

Calm institutional rounding:

- **md / 8px** — inputs, buttons, code cells (the working controls).
- **lg / 12px** — cards, modals, table containers (the surfaces).
- **full** — status pills only.
- **sm / 4px** — small chips and dots.

Corners are soft enough to feel approachable and clinical, never so round as to feel consumer-playful.

## Components

All components reference tokens by name (see frontmatter).

- **app-header** — surface fill, 1px greige bottom border, and a 2px **accent (`#137A6E`) rule** beneath it as the bronze/accent signature line. 56px tall.
- **wordmark / seal** — CSS-drawable: a primary-teal rounded square (`rounded.md`) holding a white medical-cross mark, beside the bold "EnvOcc SSO" wordmark and a muted subtitle. No raster image; the mark is drawn in CSS so it can't be lifted as a flat asset.
- **auth-card** — surface fill, greige border, `rounded.lg`, ~420px, the soft teal-tinted shadow. The signature staff-auth container.
- **text-input** — surface fill, 1.5px greige border, `rounded.md`; on focus the border becomes accent with a 3px accent ring.
- **password-input** — text-input plus a muted reveal (eye) toggle that switches to primary while pressed.
- **code-input** — six **Noto Sans Mono** cells, `rounded.md`, greige border, accent border on the focused cell. The TOTP verification-code surface; the only monospace input in the system.
- **thaid-login-button** — a secondary-styled **"Login with ThaiD"** button on the Sign in surface, below the email/password form and a clear "or" divider. Carries the ThaiD mark; full-width within the auth-card; same `rounded.md`, keyboard-focusable with the standard focus ring. It is an *alternative* path, visually subordinate to the primary email/password sign-in.
- **button-primary / secondary / link / destructive** — primary = teal fill / white text / `rounded.md`, hover steps to `primary-hover`; secondary = surface fill / teal text / greige border; link = teal underlined text; destructive = error fill / white text.
- **status-pill** — `rounded.full`, **always pill + dot + label** (never color alone): **Active** = success tint, **Pending** = warning tint, **Disabled** = muted/neutral tint.
- **data-table-row** — primary text, muted meta, 1px greige bottom rule, surface-raised head. Flat, dense, admin-first.
- **alert** — `rounded.md`, four variants (info / success / warning / error), each a tint bg + matching icon + full-contrast on-tint text.
- **anti-phishing-banner** — the **pinned info** alert variant, persistent on auth screens. Carries security-critical copy ("we'll never ask for your code…") and is **always rendered at full contrast** — never muted.
- **modal + step-up-dialog** — modal = surface, `rounded.lg`, dim teal-tinted overlay, soft deep shadow. The **step-up-dialog** (sensitive re-auth) adds a 3px **accent rule** at the top to mark the moment as elevated-trust.
- **file-upload + csv-preview-table** — dashed greige dropzone (`rounded.lg`) turning accent when active; the preview table marks rows three ways, color **plus** a marker/label: **clean** (surface), **invalid** (error tint + error marker), **duplicate** (warning tint + warning marker).

## Do's and Don'ts

| Do | Don't |
|---|---|
| Keep teal (`primary` / `accent`) as the single trust signal | Introduce a second brand hue or any gradient |
| Pair every status with an icon, dot, and/or label | Rely on color alone to convey status or row state |
| Run security-critical copy at full `text-primary` contrast | Set anti-phishing or warning copy in `text-muted` |
| Render staff-auth **top-level only** (`frame-ancestors none`) | Allow any auth surface to be iframed or embedded |
| Ship light mode, AA-verified on every pairing | Add a dark mode or ship an un-checked color pairing |
| Externalize all text (Noto Sans + Noto Sans Thai, translatable) | Bake text into images — it can't translate or be read by AT |
| Use `accent` for sensitive-action emphasis (step-up, focus) | Treat `accent` as decorative or a general-purpose color |
| Let the auth card be the one element that lifts | Add shadows to admin tables; keep admin flat (tone + rules) |
