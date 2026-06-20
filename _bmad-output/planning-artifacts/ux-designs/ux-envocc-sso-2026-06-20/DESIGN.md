---
name: EnvOcc SSO
description: Branded staff identity surfaces + one role-gated admin app for EnvOcc's single sign-on. Civic Register visual direction — institutional, calm, trustworthy government-health register. Custom design system, light mode only, WCAG 2.1 AA.
status: final
updated: 2026-06-20
colors:
  # ---- Ministry Bronze (LOCKED palette #2). Light mode only. ----
  # Brand
  primary: '#1B3354'            # navy · primary buttons, brand seal, headers, focus ring
  primary-hover: '#142744'      # darker step on hover/active
  primary-foreground: '#FFFFFF' # text/icon on navy (10.4:1)
  accent: '#A9711B'             # bronze · brand rule, sparing emphasis, seal border
  accent-link: '#7A4F0E'        # link/accent text on white (6.1:1 AA)
  # Neutrals (warm greige)
  background: '#FFFFFF'         # app/page ground
  surface: '#F7F5F1'            # warm-greige card / panel / auth card fill
  border: '#DED7CB'             # greige divider — decorative containers, table rules
  border-strong: '#9C907A'      # optional meaningful boundary (3.14:1 vs white)
  text-primary: '#1E2A3D'       # body / headings on white (12.6:1 AAA)
  text-muted: '#6A6356'         # secondary / helper text on white (5.0:1 AA)
  # Semantic — success
  success: '#2A6B3E'            # success icon / pill fill / border
  success-bg: '#E9F2EA'         # success alert + Active pill background
  success-text: '#1B4F2A'       # success text on success-bg (6.0:1)
  # Semantic — warning
  warning: '#97601A'            # warning icon / pill / border
  warning-bg: '#F7EEDD'         # warning alert + Pending pill background
  warning-text: '#6B440F'       # warning text on warning-bg (5.7:1)
  # Semantic — error
  error: '#AD2B1E'              # error icon / alert border / field-invalid border
  error-bg: '#FBEAE6'           # error alert background
  error-text: '#7E2018'         # error text on error-bg (6.1:1)
  # Semantic — info
  info: '#245B8C'               # info icon / anti-phishing banner border
  info-bg: '#E9F0F6'            # info / anti-phishing reassurance background
  info-text: '#143F66'         # info text on info-bg (6.3:1)
typography:
  # Serif = Noto Serif (+ Noto Serif Thai). Sans = Noto Sans (+ Noto Sans Thai).
  # English-first, structured for Thai; security-critical strings prioritized for Thai.
  wordmark:
    fontFamily: 'Noto Serif, Noto Serif Thai, Georgia, serif'
    fontSize: 18px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.01em
  display:
    fontFamily: 'Noto Serif, Noto Serif Thai, Georgia, serif'
    fontSize: 28px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  heading-lg:
    fontFamily: 'Noto Serif, Noto Serif Thai, Georgia, serif'
    fontSize: 22px
    fontWeight: '700'
    lineHeight: '1.25'
  heading-md:
    fontFamily: 'Noto Serif, Noto Serif Thai, Georgia, serif'
    fontSize: 18px
    fontWeight: '700'
    lineHeight: '1.3'
  body-lg:
    fontFamily: 'Noto Sans, Noto Sans Thai, system-ui, sans-serif'
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  body:
    fontFamily: 'Noto Sans, Noto Sans Thai, system-ui, sans-serif'
    fontSize: 14px
    fontWeight: '400'
    lineHeight: '1.55'
  label:
    fontFamily: 'Noto Sans, Noto Sans Thai, system-ui, sans-serif'
    fontSize: 13px
    fontWeight: '600'
    lineHeight: '1.4'
  caption:
    fontFamily: 'Noto Sans, Noto Sans Thai, system-ui, sans-serif'
    fontSize: 12px
    fontWeight: '400'
    lineHeight: '1.45'
  overline:
    fontFamily: 'Noto Sans, Noto Sans Thai, system-ui, sans-serif'
    fontSize: 11px
    fontWeight: '700'
    lineHeight: '1.4'
    letterSpacing: 0.13em
  code-input:
    fontFamily: 'Noto Sans Mono, ui-monospace, monospace'
    fontSize: 22px
    fontWeight: '600'
    lineHeight: '1'
    letterSpacing: 0.02em
  data:
    fontFamily: 'Noto Sans, Noto Sans Thai, system-ui, sans-serif'
    fontSize: 13px
    fontWeight: '400'
    lineHeight: '1.5'
rounded:
  sm: 4px      # small chips
  md: 8px      # inputs, buttons, alerts, code-input cells
  lg: 12px     # auth card, modal, panels
  xl: 14px     # large outer shells
  full: 9999px # status pills
spacing:
  unit: 4px
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 20px
  '6': 24px
  '8': 32px
  '10': 40px
  '12': 48px
  '16': 64px
  gutter: 24px
  card-padding: 28px
  field-gap: 14px
  page-margin: 40px
  content-max-auth: 420px   # staff auth card max width
  content-max-app: 1280px   # admin app content max width
components:
  app-header:
    background: '{colors.primary}'
    foreground: '{colors.primary-foreground}'
    accent-rule: '{colors.accent}'   # bronze bottom rule, 3-4px
    height: 60px
  wordmark:
    font: '{typography.wordmark}'
    seal-background: '{colors.primary}'
    seal-foreground: '{colors.primary-foreground}'
    seal-border: '{colors.accent}'
    seal-radius: '{rounded.md}'
  auth-card:
    background: '{colors.surface}'
    border: '{colors.border}'
    radius: '{rounded.lg}'
    padding: '{spacing.card-padding}'
    max-width: '{spacing.content-max-auth}'
    top-rule: '{colors.primary}'     # navy rule under the lockup
  text-input:
    background: '{colors.background}'
    border: '{colors.border}'
    border-focus: '{colors.primary}'
    border-invalid: '{colors.error}'
    text: '{colors.text-primary}'
    placeholder: '{colors.text-muted}'
    label: '{typography.label}'
    radius: '{rounded.md}'
    focus-ring: '2px solid {colors.primary}'
  password-input:
    extends: text-input
    reveal-toggle-color: '{colors.text-muted}'   # show/hide affordance
  code-input:
    cell-count: 6
    cell-background: '{colors.background}'
    cell-border: '{colors.border}'
    cell-border-filled: '{colors.primary}'
    cell-background-filled: '#EEF3FA'
    cell-border-invalid: '{colors.error}'
    text: '{typography.code-input}'
    text-color: '{colors.text-primary}'
    radius: '{rounded.md}'
  button-primary:
    background: '{colors.primary}'
    background-hover: '{colors.primary-hover}'
    foreground: '{colors.primary-foreground}'
    radius: '{rounded.md}'
    font: '{typography.label}'
  button-secondary:
    background: '{colors.background}'
    foreground: '{colors.primary}'
    border: '{colors.border-strong}'
    radius: '{rounded.md}'
  button-link:
    foreground: '{colors.accent-link}'
    underline: true
  button-destructive:
    background: '{colors.error}'
    foreground: '{colors.primary-foreground}'
    radius: '{rounded.md}'
  status-pill-active:
    background: '{colors.success-bg}'
    foreground: '{colors.success-text}'
    radius: '{rounded.full}'
  status-pill-pending:
    background: '{colors.warning-bg}'
    foreground: '{colors.warning-text}'
    radius: '{rounded.full}'
  status-pill-disabled:
    background: '{colors.surface}'
    foreground: '{colors.text-muted}'
    border: '{colors.border}'
    radius: '{rounded.full}'
  data-table-row:
    background: '{colors.background}'
    background-hover: '{colors.surface}'
    border: '{colors.border}'
    text: '{typography.data}'
    text-color: '{colors.text-primary}'
    meta-color: '{colors.text-muted}'
  alert-info:
    background: '{colors.info-bg}'
    border: '{colors.info}'
    text: '{colors.info-text}'
    radius: '{rounded.md}'
  alert-success:
    background: '{colors.success-bg}'
    border: '{colors.success}'
    text: '{colors.success-text}'
    radius: '{rounded.md}'
  alert-warning:
    background: '{colors.warning-bg}'
    border: '{colors.warning}'
    text: '{colors.warning-text}'
    radius: '{rounded.md}'
  alert-error:
    background: '{colors.error-bg}'
    border: '{colors.error}'
    text: '{colors.error-text}'
    radius: '{rounded.md}'
  anti-phishing-banner:
    extends: alert-info
    icon-color: '{colors.info}'
  modal:
    background: '{colors.background}'
    border: '{colors.border}'
    radius: '{rounded.lg}'
    overlay: 'rgba(20, 39, 68, 0.45)'   # navy-tinted scrim
    padding: '{spacing.6}'
  step-up-dialog:
    extends: modal
    accent-rule: '{colors.accent}'
  file-upload:
    background: '{colors.surface}'
    border: '2px dashed {colors.border-strong}'
    border-active: '{colors.primary}'
    radius: '{rounded.lg}'
  csv-preview-table:
    extends: data-table-row
    row-error-background: '{colors.error-bg}'
    row-error-text: '{colors.error-text}'
    row-duplicate-background: '{colors.warning-bg}'
---

# EnvOcc SSO — Design Spec

> Visual contract for the EnvOcc single sign-on surfaces. Civic Register direction, Ministry Bronze palette, custom design system, **light mode only**, **WCAG 2.1 AA** (every text/background pairing AA-verified at the palette source). Behavioral and experience decisions live in `EXPERIENCE.md`; this file holds the visual identity only. Build/library choices are deliberately deferred.

## Brand & Style

EnvOcc SSO is the front door to a government-health division's systems — the place staff prove *who they are*. The brand has one job: look unmistakably **official, calm, and trustworthy** so that a non-technical staff member, redirected here from another app, immediately believes this is the real, sanctioned login and not a phishing imitation. Trust is the product; the visual register is the first line of that trust.

The aesthetic is **Civic Register** — the measured composure of government correspondence. A serif wordmark sits on a navy rule like a letterhead; the palette is a deep institutional navy with a single restrained bronze accent on a warm-greige ground. Structure is ruled and orderly; nothing shouts; bronze is used sparingly so authority never tips into decoration. The same brand carries across both halves of the product — the **staff auth surfaces** (login, MFA, activation, reset) and the **one role-gated admin app** (HR-lifecycle + System-administration sections in a single shell) — so the admin console reads as a co-equal, equally-sanctioned half, not an afterthought bolted onto a login page.

Two postures inside one brand: the **auth surfaces** are spacious, centered, and reassuring (responsive, rendered top-level only — never inside an iframe); the **admin app** is desktop-first, data-dense, and businesslike. They share tokens, type, and color; they differ only in density.

## Colors

Ministry Bronze. Every pairing below was AA-verified at the palette source; ratios are noted where load-bearing.

- **Primary Navy (`{colors.primary}` `#1B3354`)** is the brand and the trust signal. It fills primary buttons, the brand seal, the app header, and the focus ring. White on navy is 10.4:1. The hover step is **`{colors.primary-hover}` `#142744`**. Navy is also the input focus-ring color (≥9:1) — focus is always unmistakable.
- **Bronze (`{colors.accent}` `#A9711B`)** is the single accent. It appears as the thin rule under the header, the seal's edge, and sparing emphasis. As *text* (links) bronze must darken to **`{colors.accent-link}` `#7A4F0E`** (6.1:1 on white) — never use raw `#A9711B` for body-size text. Bronze is never a state color and never a large fill.
- **Background (`{colors.background}` `#FFFFFF`)** is the app ground. **Surface (`{colors.surface}` `#F7F5F1`)**, a warm greige, is the auth card and panel fill — it warms the institutional navy so the register reads calm rather than cold.
- **Border (`{colors.border}` `#DED7CB`)** is the decorative greige divider for cards, table rules, and dividers. **Border-strong (`{colors.border-strong}` `#9C907A`)** is reserved for meaningful boundaries (secondary-button outline, file-drop zone) where a 3:1 component contrast is wanted.
- **Text-primary (`{colors.text-primary}` `#1E2A3D`)** is all body and headings on white (12.6:1, AAA). **Text-muted (`{colors.text-muted}` `#6A6356`)** is helper text, placeholders, table metadata (5.0:1, AA) — never used for security-critical instructions, which must run at full text-primary contrast.
- **Semantic set** — each has a fill, a light background, and a darkened on-background text, all AA on their pairing:
  - **Success** `{colors.success}` `#2A6B3E` / bg `{colors.success-bg}` `#E9F2EA` / text `{colors.success-text}` `#1B4F2A` — "Active" pill; account-activated and password-changed confirmations.
  - **Warning** `{colors.warning}` `#97601A` / bg `{colors.warning-bg}` `#F7EEDD` / text `{colors.warning-text}` `#6B440F` — "Pending" pill; expiry warnings; throttle notices.
  - **Error** `{colors.error}` `#AD2B1E` / bg `{colors.error-bg}` `#FBEAE6` / text `{colors.error-text}` `#7E2018` — lockout, invalid-link, invalid-code, destructive confirms.
  - **Info** `{colors.info}` `#245B8C` / bg `{colors.info-bg}` `#E9F0F6` / text `{colors.info-text}` `#143F66` — the standing **anti-phishing reassurance banner** ("we'll never ask for your code"), email-sent confirmations, generic enumeration-resistant notices.

Avoid: a second accent hue, gradients, raw bronze for text, semantic colors for chrome, dark-mode tokens (out of scope for v1).

## Typography

A harmonized bilingual Noto system carries English-now → Thai-later in one family, so the security-critical strings (activation, reset, MFA, "do not share this link") render correctly in Thai without a font swap.

- **Noto Serif (+ Noto Serif Thai)** is the voice of authority — the wordmark and every heading (`display`, `heading-lg`, `heading-md`). The serif is the letterhead; it appears at brand and page-title moments, never in body or data.
- **Noto Sans (+ Noto Sans Thai)** is the working voice — body, labels, captions, form fields, and all admin data (`body-lg`, `body`, `label`, `caption`, `overline`, `data`). Forms and tables are always sans for legibility at small sizes.
- **Noto Sans Mono** powers only the **6-digit code input** (`code-input`, 22px), where fixed-width digit cells aid scanning.

Type scale (sans unless serif noted): `display` 28 → `heading-lg` 22 → `heading-md` 18 → `body-lg` 16 → `body` 14 → `label` 13/600 → `caption` 12 → `overline` 11/700 tracked 0.13em. Bilingual rules: never bake text into images (FR12 — all copy is externalized strings); Thai sets taller, so line-heights stay generous (≥1.5 for body) to keep Thai diacritics legible. English leads; where a string appears in both languages, English is first and Thai follows beneath at the same role.

## Layout & Spacing

A 4px base unit (`{spacing.unit}`); the working scale is 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64. Named tokens: `{spacing.gutter}` 24, `{spacing.card-padding}` 28, `{spacing.field-gap}` 14, `{spacing.page-margin}` 40.

**Two layout postures:**

- **Staff auth surfaces** — single centered column, card max width `{spacing.content-max-auth}` 420px, vertically centered on the viewport. Fully **responsive**; on narrow screens the card goes near-full-width with `{spacing.page-margin}` honored as side gutter. These pages must render **top-level only** — the brand chrome, the URL, and the anti-phishing banner are part of the trust signal, so the surface is never embedded (CSP `frame-ancestors 'none'`).
- **Admin app** — **desktop-first**, data-dense. Persistent branded header; content max width `{spacing.content-max-app}` 1280px; tables run full content width. Responsive-tolerant (usable down to tablet) but optimized for desktop; tables may scroll horizontally rather than reflow on small screens.

Field gap inside forms is `{spacing.field-gap}` 14px; section gaps in the admin app are 24–32px. Generous vertical rhythm in auth (room to breathe = calm); tighter, regular rhythm in admin (scan-density).

## Elevation & Depth

Depth is restrained and institutional — paper on paper, not floating glass.

- **Auth card** rests on the page ground with a soft, navy-tinted shadow (`0 1px 2px rgba(15,39,66,.06), 0 8px 24px rgba(15,39,66,.05)`) — present enough to read as a distinct, deliberate object, never dramatic.
- **Admin app** is mostly flat: surfaces are distinguished by the warm-greige `{colors.surface}` fill and `{colors.border}` rules, not shadow. Hierarchy comes from tone and ruling.
- **Modals / step-up dialogs** lift on a navy-tinted scrim (`rgba(20,39,68,.45)`) with the same soft shadow family. One level of stacking only; never a modal over a modal.

Elevation is never the *only* signal for state — it always pairs with color, border, or copy.

## Shapes

Calm institutional rounding — softened, never playful, never sharp-tech.

- `{rounded.md}` 8px — inputs, buttons, alerts, code-input cells (the working radius).
- `{rounded.lg}` 12px — the auth card, modals, panels, file-drop zone.
- `{rounded.xl}` 14px — large outer shells.
- `{rounded.sm}` 4px — small chips.
- `{rounded.full}` — status pills only.

The brand seal uses `{rounded.md}` with a bronze edge. Imagery and avatars follow container radii. The shape logic: enough rounding to feel humane for non-technical staff, restrained enough to read official.

## Components

Per-component visual specs. Behavior lives in `EXPERIENCE.md.Component Patterns`.

- **Branded shell / header** (`app-header` + `wordmark`) — navy (`{colors.primary}`) bar with a 3–4px bronze (`{colors.accent}`) bottom rule. Left: the **wordmark** — a navy seal (rounded square, bronze edge, white serif initial) + "EnvOcc" in `{typography.wordmark}` (serif) with an uppercase `{typography.overline}` subline ("Occupational & Environmental Diseases"). The same lockup heads both the auth card and the admin app, scaled per posture.
- **Auth card** (`auth-card`) — `{colors.surface}` fill, `{colors.border}`, `{rounded.lg}`, `{spacing.card-padding}` padding, max 420px. Lockup sits above a thin navy top rule; serif `{typography.display}`/`heading-lg` title; muted `{typography.body}` subtitle; fields; primary button; then the standing anti-phishing banner.
- **Text input** (`text-input`) — white fill, `{colors.border}`, `{rounded.md}`, `{typography.body}` text, muted placeholder. Label above in `{typography.label}`. Focus: 2px navy ring, 1px offset. Invalid: `{colors.error}` border + error helper text below, programmatically associated.
- **Password input** (`password-input`) — text-input plus a show/hide reveal affordance (`{colors.text-muted}` icon, toggles type). New-password fields show inline policy hints (≥12 chars, breached-list rejection) as `{typography.caption}` helper — guidance, not composition-rule nagging.
- **6-digit code input** (`code-input`) — six monospace cells (`{typography.code-input}`), `{colors.border}`, `{rounded.md}`. Filled cell: navy border + `#EEF3FA` tint. Invalid: `{colors.error}` border across the group. Accepts paste of a full code; auto-advances; exposed as one labeled group (not six unlabeled boxes) for screen readers.
- **Buttons** — **Primary** (`button-primary`): navy fill, white text, `{rounded.md}`, full-width in auth, hover → `{colors.primary-hover}`. **Secondary** (`button-secondary`): white fill, navy text, `{colors.border-strong}` outline. **Link** (`button-link`): `{colors.accent-link}` bronze, underlined. **Destructive** (`button-destructive`): error fill, white text — disable / force-logout confirmations only.
- **Status pill** — **Active** (`status-pill-active`): success-bg / success-text. **Pending** (`status-pill-pending`): warning-bg / warning-text. **Disabled** (`status-pill-disabled`): surface fill, muted text, `{colors.border}` outline. `{typography.overline}` weight, `{rounded.full}`. State is carried by text + tone, never color alone (a leading dot or the label reinforces).
- **Data table row** (`data-table-row`) — white row, `{colors.surface}` hover, `{colors.border}` rules. Primary cell (name) in `{colors.text-primary}`; secondary (email/meta) in `{colors.text-muted}`. Trailing status pill. `{typography.data}` 13px for density. Used across the HR user list and System client/admin lists.
- **Alert / banner — four states** — `alert-info` / `alert-success` / `alert-warning` / `alert-error`, each its semantic bg + a semantic border + matching text, `{rounded.md}`, leading icon. The **anti-phishing banner** (`anti-phishing-banner`) is the info variant pinned into auth surfaces as a first-class, always-visible element.
- **Modal / step-up dialog** (`modal` / `step-up-dialog`) — white panel, `{rounded.lg}`, on a navy-tinted scrim; the step-up variant adds a bronze accent rule to mark a sensitive re-auth (reset MFA, register client, manage admins). Focus is trapped; `Esc` closes (except a required step-up, which must be completed or cancelled).
- **File-upload / CSV preview** (`file-upload` + `csv-preview-table`) — a `{colors.surface}` drop zone with a 2px dashed `{colors.border-strong}` border (navy when active). After parse, a **preview table** lists rows before commit: clean rows normal; invalid rows on `error-bg` with the reason; duplicate rows on `warning-bg`. A confirm step gates account creation; nothing is created from the drop alone.

## Do's and Don'ts

| Do | Don't |
|---|---|
| Keep navy as the trust signal — header, primary buttons, focus ring | Introduce a second brand color or any gradient |
| Use bronze sparingly: rules, seal edge, link text (`{colors.accent-link}`) | Use raw bronze `#A9711B` for body-size text (fails AA) |
| Run security-critical copy at full `{colors.text-primary}` contrast | Demote anti-phishing / "don't share this link" copy to muted text |
| Pin the anti-phishing banner as a first-class element on auth surfaces | Treat anti-phishing guidance as an optional tooltip |
| Set the serif (`{typography.display}`) only at wordmark + page titles | Set body, forms, or table data in serif |
| Carry status with text + tone (pill label, dot) | Rely on color alone to distinguish Active / Pending / Disabled |
| Render auth surfaces top-level only (`frame-ancestors 'none'`) | Embed any auth surface in an iframe — it breaks the trust signal |
| Use generous line-height for Thai diacritic legibility | Bake any UI text into an image (all copy is externalized strings) |
| Keep one modal layer; navy-tinted scrim | Stack a modal over a modal |
| Pair elevation/state with color + copy | Use shadow or color as the sole carrier of meaning |
