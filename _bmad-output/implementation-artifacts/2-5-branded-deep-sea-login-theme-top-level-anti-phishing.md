# Story 2.5: Branded Deep Sea login theme (top-level, anti-phishing)

Status: ready-for-dev

## Story

As a non-technical staff member,
I want an unmistakably legitimate login,
so that I can tell the real login from a phishing copy.

## Acceptance Criteria

1. **Deep Sea tokens applied — all auth surfaces:** All Keycloak login-theme surfaces (sign-in, MFA/TOTP verification, forgot-password, email-sent, reset-password, error) render using `design-tokens/deep-sea.css` CSS variables (`var(--color-primary)`, `var(--color-background)`, etc.). No raw hex values in theme CSS — all values reference CSS variables from the shared token file. (FR12, UX-DR2)

2. **Top-level only — CSP `frame-ancestors 'none'`:** Auth surfaces MUST NOT be embeddable in any frame or iframe. This is already enforced by nginx (`Content-Security-Policy: frame-ancestors 'none'` on `/realms/` paths — story 1.3). The theme itself must NOT add or override a conflicting CSP. Keycloak's `browserSecurityHeaders` in `realm-export.json` must NOT set a conflicting `contentSecurityPolicy` that duplicates or conflicts with the nginx header. Verify: the rendered login page receives exactly one `Content-Security-Policy: frame-ancestors 'none'` header (from nginx). (FR12, UX-DR2)

3. **Pinned, non-dismissible anti-phishing banner:** The sign-in surface and the MFA/verification-code surface each show a persistent, non-dismissible info banner styled with the `anti-phishing-banner` design spec (`--color-info-bg`, `--color-info-border`, `--color-info-fg`). Copy: `"We'll never ask for your verification code by phone, email, or chat."` The banner has no dismiss/close button. (UX-DR7, UX-DR9)

4. **All strings externalized — English-first, localization-ready:** Every piece of UI copy in the theme (labels, button text, placeholder attributes, banner text, error messages, page titles, help text) is sourced from `messages/messages_en.properties`. No hard-coded text strings in FreeMarker templates or CSS. This includes: sign-in page title, email label, password label, "Sign in" button, "Forgot password?" link, "Login with ThaiD" button (wire-frame placeholder only — not yet functional), verification-code page title, code input label, "Verify" button, anti-phishing banner text, and all generic error messages. (FR12, UX-DR2)

5. **WCAG 2.1 AA — keyboard-complete, persistent labels, aria-associated errors:**
   - Every interactive element reachable via `Tab` / `Shift+Tab` in reading order.
   - Focus ring always visible on focused elements (using `--color-focus-ring` / `--color-accent` tokens).
   - Labels are persistent and visible — never placeholder-only. Each `<input>` has a corresponding `<label>` with matching `for`/`id` attributes.
   - Field errors are associated via `aria-describedby` to their input, and conveyed in text (not color alone).
   - The auth card is single-column; no layout shift on error state; 200% zoom supported without loss of content. (UX-DR8)

6. **Theme wired into realm config:** `realm-export.json` sets `"loginTheme": "envocc"` (and optionally `"accountTheme": "envocc"`, `"emailTheme": "envocc"` if templates are created). The Keycloak Dockerfile COPYs the `keycloak/themes/envocc/` directory into the image at `/opt/keycloak/themes/envocc/`. Keycloak loads the custom theme on startup. (Architecture: Decision 2)

7. **No-JS login path:** The login theme must NOT require JavaScript to render or submit the login form. Core auth (email/password sign-in, TOTP code entry) must work with JavaScript disabled. JavaScript enhancements (e.g., reveal-toggle for password, TOTP auto-advance) are additive and must not break the no-JS path. (NFR8-aligned: no custom auth logic in login path)

## Tasks / Subtasks

- [ ] Task 1: Create theme directory structure (AC: 6)
  - [ ] Subtask 1.1: Create `keycloak/themes/envocc/login/` directory (inside the `keycloak/` folder — this is the Docker build context)
  - [ ] Subtask 1.2: Create `keycloak/themes/envocc/login/theme.properties` declaring `parent=keycloak`, `import=common/keycloak`, and `styles=css/login.css`
  - [ ] Subtask 1.3: Create `keycloak/themes/envocc/login/resources/css/` directory for theme stylesheets
  - [ ] Subtask 1.4: Create `keycloak/themes/envocc/login/resources/design-tokens/deep-sea.css` — **copy the content of `design-tokens/deep-sea.css`** (the monorepo root token file) into this path. This is a versioned copy inside the keycloak build context; the repo root `design-tokens/deep-sea.css` remains the canonical source. Both files must be kept in sync. Note in a comment at the top of this copy: `/* Keycloak theme copy of /design-tokens/deep-sea.css — keep in sync with repo root */`
  - [ ] Subtask 1.5: Create `keycloak/themes/envocc/login/messages/` directory for externalized strings

- [ ] Task 2: Create main theme CSS applying Deep Sea tokens (AC: 1, 5)
  - [ ] Subtask 2.1: Create `keycloak/themes/envocc/login/resources/css/login.css` — imports `design-tokens/deep-sea.css` via `@import` (relative URL) then applies CSS variable overrides
  - [ ] Subtask 2.2: Style `body` / page background using `var(--color-background)` (warm-sand `#F6F4EF`)
  - [ ] Subtask 2.3: Style the auth card (`#kc-form-login-wrapper`, `.login-pf-page`, `.card-pf`) with `var(--color-surface)` background, `var(--color-border)` border, `var(--radius-lg)` radius, `var(--spacing-auth-card-width)` max-width, auth-card shadow (`0 8px 26px rgba(14,92,83,0.10)`)
  - [ ] Subtask 2.4: Style text inputs with `var(--color-border)` border, `var(--radius-md)` radius; on `:focus` use `var(--color-accent)` border + 3px focus ring at 15% alpha
  - [ ] Subtask 2.5: Style primary button (Sign in / Verify) with `var(--color-primary)` background, `var(--color-primary-foreground)` text (the actual variable name — NOT `--color-primary-fg`), `var(--radius-md)` radius; hover = `var(--color-primary-hover)`
  - [ ] Subtask 2.6: Style link buttons (Forgot password) with `var(--color-primary)` color, text underline
  - [ ] Subtask 2.7: Style focus rings — `:focus-visible` outline using `var(--color-focus-ring)` / `var(--color-accent)` — never suppress `outline: none` without a replacement
  - [ ] Subtask 2.8: Style typography — `font-family: var(--font-family)` (Noto Sans + Noto Sans Thai) on body; heading sizes from `var(--font-h1-size)` / `var(--font-h2-size)`; body size `var(--font-body-size)` with `var(--font-body-line-height)` (1.6 for Thai diacritics)
  - [ ] Subtask 2.9: Style error messages — `var(--color-error-bg)` background, `var(--color-error-fg)` text, `var(--radius-md)` radius; include error icon (text+icon, not color alone)
  - [ ] Subtask 2.10: Add wordmark / seal in the auth card header — CSS-drawn teal rounded square (`var(--color-primary)`, `var(--radius-md)`) + text "EnvOcc SSO" in `var(--font-wordmark-weight)` / `var(--font-wordmark-size)` — no raster image

- [ ] Task 3: Override FreeMarker templates to add anti-phishing banner (AC: 3, 4, 5)
  - [ ] Subtask 3.1: Copy `login.ftl` from Keycloak 26.6.3 base theme into `keycloak/themes/envocc/login/` and add the anti-phishing banner block immediately inside the auth card, before the form
  - [ ] Subtask 3.2: Anti-phishing banner markup: `<div class="alert alert-info anti-phishing-banner" role="alert">` containing an SVG info icon + `<span>${msg("antiphishingBanner")}</span>` — no dismiss button, `aria-live="polite"` on the container
  - [ ] Subtask 3.3: Copy or override `login-otp.ftl` (TOTP verification surface) and add the same anti-phishing banner to the top of the auth card
  - [ ] Subtask 3.4: Ensure all other text in templates uses `${msg("...")}` calls, never hardcoded strings. Cross-check against messages_en.properties

- [ ] Task 4: Externalize all strings into messages_en.properties (AC: 4)
  - [ ] Subtask 4.1: Create `keycloak/themes/envocc/login/messages/messages_en.properties`
  - [ ] Subtask 4.2: Inherit parent theme messages by NOT duplicating keys that are already fine in the `keycloak` base theme (parent keys are inherited automatically) — only override or add keys
  - [ ] Subtask 4.3: Add required override / new keys:
    - `antiphishingBanner=We’ll never ask for your verification code by phone, email, or chat.`
    - `loginTitle=Sign in to EnvOcc SSO`
    - `usernameOrEmail=Work email`
    - `password=Password`
    - `doLogIn=Sign in`
    - `doForgotPassword=Forgot password?`
    - `loginTotpTitle=Enter your verification code`
    - `loginTotpOneTime=Verification code`
    - `doSubmit=Verify`
    - `loginWithThaiD=Login with ThaiD` (placeholder — button is not yet functional in this story)
    - `backToLogin=← Back to sign in`
    - Generic error overrides to match UX voice: `invalidUserMessage=Incorrect email or password.`, `invalidPasswordMessage=Incorrect email or password.`, `accountDisabledMessage=This account is not available. Contact HR if you need help.`
  - [ ] Subtask 4.4: Verify no hard-coded Thai or English strings remain in any `.ftl` template

- [ ] Task 5: Wire theme into Keycloak image and realm config (AC: 6)
  - [ ] Subtask 5.1: Update `keycloak/Dockerfile` — add `COPY themes/envocc /opt/keycloak/themes/envocc` BEFORE the `RUN /opt/keycloak/bin/kc.sh build` step (themes must be present at build time for the optimized build)
    - **CRITICAL — build context is `./keycloak`:** Per `compose.yaml`, the Keycloak service sets `context: ./keycloak`. ALL `COPY` source paths in the Dockerfile are relative to the `keycloak/` directory, NOT the repo root. Use `COPY themes/envocc /opt/keycloak/themes/envocc` (sources the theme from `keycloak/themes/envocc/`).
    - The design tokens file is already inside the theme directory (`keycloak/themes/envocc/login/resources/design-tokens/deep-sea.css`) and will be included by the above COPY — NO separate COPY for tokens is needed.
  - [ ] Subtask 5.2: Update `keycloak/realm-export.json` — add `"loginTheme": "envocc"` at the realm root level (alongside existing `"realm"`, `"enabled"`, etc. keys)
  - [ ] Subtask 5.3: Verify `realm-export.json` does NOT set `"browserSecurityHeaders"` with a `"contentSecurityPolicy"` that duplicates or conflicts with the nginx `frame-ancestors 'none'` header set in story 1.3. The current `browserSecurityHeaders: {}` is correct — leave it empty.

- [ ] Task 6: Anti-phishing banner CSS (AC: 3, 5)
  - [ ] Subtask 6.1: In `login.css`, add `.anti-phishing-banner` styles using info color tokens: `background: var(--color-info-bg)`, `border: 1px solid var(--color-info-border)`, `color: var(--color-info-fg)`, `border-radius: var(--radius-md)`, `padding: var(--spacing-md) var(--spacing-lg)`, `margin-bottom: var(--spacing-lg)`, `display: flex`, `align-items: flex-start`, `gap: var(--spacing-sm)`
  - [ ] Subtask 6.2: Ensure `.anti-phishing-banner` has no close/dismiss button in HTML
  - [ ] Subtask 6.3: Info icon — inline SVG or CSS-only approach; paired with text (never icon-only)

- [ ] Task 7: Verify WCAG AA and no-JS requirements (AC: 5, 7)
  - [ ] Subtask 7.1: Inspect rendered HTML — every `<input>` has a `<label for="...">` with matching `id`, never placeholder-only
  - [ ] Subtask 7.2: Error messages are wrapped in elements with `aria-describedby` back to the field that errored (Keycloak base theme does this for most fields — verify it's preserved in overrides)
  - [ ] Subtask 7.3: Tab through the sign-in form in order: [email input] → [password input] → [reveal toggle if JS] → [forgot password link] → [Sign in button] — all reachable in reading order
  - [ ] Subtask 7.4: Focus ring: override any `outline: none` that Keycloak's base CSS might add; use `outline: 3px solid var(--color-focus-ring); outline-offset: 2px` on `:focus-visible`
  - [ ] Subtask 7.5: Disable JS in the browser — sign-in form still renders and submits via standard POST; TOTP form still renders and submits

- [ ] Task 8: Manual smoke test (AC: all)
  - [ ] Subtask 8.1: `docker compose up --build -d` — rebuild Keycloak image with theme baked in
  - [ ] Subtask 8.2: Visit `https://localhost/realms/envocc/protocol/openid-connect/auth?client_id=...&redirect_uri=...&response_type=code` — confirm Deep Sea styling renders (teal auth card, warm-sand background, no raw hex colors, correct typography)
  - [ ] Subtask 8.3: Confirm anti-phishing banner appears above the form, is not dismissible
  - [ ] Subtask 8.4: `curl -sI https://localhost/realms/envocc/protocol/openid-connect/auth?...` — confirm response has `Content-Security-Policy: frame-ancestors 'none'` header exactly once (from nginx, NOT duplicated by Keycloak)
  - [ ] Subtask 8.5: Attempt to load the login page inside an iframe — browser blocks it; `frame-ancestors 'none'` enforced

## Dev Notes

### What This Story Builds

A native Keycloak FreeMarker login theme that:
1. Applies the shared Deep Sea CSS tokens to all auth surfaces
2. Adds a pinned, non-dismissible anti-phishing banner to sign-in and TOTP surfaces
3. Externalizes all UI strings to `messages_en.properties` (English-first, Thai-later)
4. Wires the theme into the Keycloak Dockerfile and `realm-export.json`

**What this story does NOT build:**
- The TOTP MFA flow logic (story 2.6) — only the visual styling of the TOTP code-input surface
- "Login with ThaiD" button behavior (story 2.9) — only a placeholder string in messages, no button in the template yet
- The admin app (story 4.1) — that consumes the same tokens separately via `admin/src/app.css`
- OIDC flow configuration (stories 2.1–2.4)

### Critical Architectural Context

**Token file location:** `design-tokens/deep-sea.css` exists at the monorepo root (story 1.4 — done). All 66 CSS custom properties are declared on `:root`. **Do NOT redefine tokens — consume them.** The theme makes them available to Keycloak by COPYing the file into the theme's static resources directory.

**frame-ancestors 'none' is already handled by nginx (story 1.3).** The nginx config at `/Users/rawinan/Full-Stack-Projects/envocc-sso/nginx/nginx.conf` adds `Content-Security-Policy: frame-ancestors 'none'` on the `~ ^/realms(/|$)` and `~ ^/auth(/|$)` location blocks. Do NOT configure `browserSecurityHeaders.contentSecurityPolicy` in `realm-export.json` — it would create a duplicate header. The current `realm-export.json` has `"browserSecurityHeaders": {}` (empty) — leave it as-is.

**Keycloak theme placement:** Keycloak 26.x looks for themes in `/opt/keycloak/themes/<theme-name>/`. Themes must be present at `kc.sh build` time for the optimized (Quarkus) build. The Dockerfile must COPY the theme BEFORE the `RUN kc.sh build` line.

**Docker build context — CRITICAL:** Per `compose.yaml` (`context: ./keycloak`), the build context for the Keycloak image is the `keycloak/` directory, NOT the repo root. ALL COPY source paths in the Dockerfile are relative to `keycloak/`. This means:
- `COPY themes/envocc /opt/keycloak/themes/envocc` — sources `keycloak/themes/envocc/` ✅
- `COPY realm-export.json /opt/keycloak/data/import/realm-export.json` — sources `keycloak/realm-export.json` ✅ (existing, works)
- `COPY design-tokens/deep-sea.css ...` would FAIL — that file is NOT inside `keycloak/` ❌

**Solution for design tokens:** Store the design tokens file inside the theme directory itself: `keycloak/themes/envocc/login/resources/design-tokens/deep-sea.css` (a versioned copy of the repo-root token file). The theme CSS then imports via `@import url("../design-tokens/deep-sea.css")`. Document the sync requirement clearly.

**Keycloak 26.6.3 theme parent:** Use `parent=keycloak` in `theme.properties`. This inherits all base Keycloak login templates, CSS, and messages. Only override what changes. The base keycloak theme already has `messages_en.properties` — our theme's messages file extends it (same keys override, new keys are added).

**FreeMarker template override:** To add the anti-phishing banner without touching every template, the cleanest approach is to override only `login.ftl` (sign-in page) and `login-otp.ftl` (TOTP page). Copy the original from the Keycloak 26.6.3 source (`/opt/keycloak/lib/lib/main/org.keycloak.keycloak-themes-*.jar!/theme/keycloak/login/`) and insert the banner markup.

**Keycloak static resource serving:** FreeMarker templates access theme static files via `${url.resourcesPath}/path/to/file`. So `design-tokens/deep-sea.css` placed in `resources/design-tokens/deep-sea.css` is served as `${url.resourcesPath}/design-tokens/deep-sea.css`. Link it in templates (or import via CSS `@import url("${url.resourcesPath}/design-tokens/deep-sea.css")`).

**`internationalizationEnabled`:** Currently `false` in `realm-export.json`. Do NOT set to `true` unless needed — that activates the Keycloak language picker UI. For English-only v1, leave `false` and simply provide `messages_en.properties`. The theme's messages file is loaded regardless of this setting when the locale is English (the default).

### Project Structure — Files to Create / Update

**Create (new):**
```
keycloak/themes/envocc/
└── login/
    ├── theme.properties
    ├── resources/
    │   ├── css/
    │   │   └── login.css
    │   └── design-tokens/
    │       └── deep-sea.css  ← copy of /design-tokens/deep-sea.css (see build context note)
    └── messages/
        └── messages_en.properties
```
Note: `keycloak/themes/envocc/login/resources/design-tokens/deep-sea.css` is a versioned copy of the repo-root `design-tokens/deep-sea.css`. Keep in sync when tokens change. The copy is necessary because the Docker build context is `./keycloak/` and files outside that directory are inaccessible.

**Update (modify):**
- `keycloak/Dockerfile` — add `COPY themes/envocc /opt/keycloak/themes/envocc` BEFORE `RUN kc.sh build`
- `keycloak/realm-export.json` — add `"loginTheme": "envocc"`

**No change:**
- `nginx/nginx.conf` — CSP already correct (story 1.3)
- `design-tokens/deep-sea.css` — already exists, no modifications
- Any admin app files — separate story (4.1+)

### Keycloak Theme File: `theme.properties`

```properties
parent=keycloak
import=common/keycloak
styles=css/login.css
```

The `styles` key registers the custom CSS file (path relative to `resources/css/`). Keycloak will inject it as a `<link>` in the theme HTML. The base `keycloak` parent's CSS is still loaded first; `login.css` overrides it.

### Keycloak Theme: CSS Import Strategy

`login.css` imports the design tokens, then applies overrides:

```css
@import url("../design-tokens/deep-sea.css");

/* Page background */
body, .login-pf {
  background: var(--color-background) !important;
  font-family: var(--font-family);
  font-size: var(--font-body-size);
  line-height: var(--font-body-line-height);
  color: var(--color-text-primary);
}

/* Auth card */
.card-pf, .login-pf-page .card-pf {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  max-width: var(--spacing-auth-card-width);
  box-shadow: 0 8px 26px rgba(14, 92, 83, 0.10);
}
/* ... more selectors ... */
```

Use `!important` sparingly — only where Keycloak base theme inline styles or high-specificity rules need to be overridden.

### Anti-Phishing Banner: FreeMarker Markup

Insert immediately after the `<div id="kc-header">` (or inside the auth card, before the form), in both `login.ftl` and `login-otp.ftl`:

```html
<div class="alert alert-info anti-phishing-banner" role="alert" aria-live="polite">
  <svg aria-hidden="true" focusable="false" width="16" height="16" viewBox="0 0 16 16" fill="none">
    <circle cx="8" cy="8" r="7" stroke="currentColor" stroke-width="1.5"/>
    <path d="M8 5v1m0 2v4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
  </svg>
  <span>${msg("antiphishingBanner")}</span>
</div>
```

No close/dismiss button. `role="alert"` is appropriate since this is persistent security information.

### FreeMarker Template Override: How to Obtain Base Templates

For Keycloak 26.6.3, the base `login.ftl` and `login-otp.ftl` can be obtained by:
1. Running the Keycloak image and extracting: `docker run --rm quay.io/keycloak/keycloak:26.6.3 cat /opt/keycloak/lib/lib/main/org.keycloak.keycloak-themes-26.6.3.jar` (requires `jar` tool)
2. Or cloning the Keycloak source at tag `26.6.3` from https://github.com/keycloak/keycloak and copying `themes/src/main/resources/theme/keycloak/login/login.ftl` and `login-otp.ftl`

The templates are standard FreeMarker — modify minimally. Insert the banner, ensure all text uses `${msg("key")}` calls.

### Keycloak `realm-export.json` Change

Add `"loginTheme": "envocc"` at the top level of the realm object (alongside `"realm": "envocc-sso"`, `"enabled": true`, etc.):

```json
{
  "realm": "envocc-sso",
  "enabled": true,
  "loginTheme": "envocc",
  ...
}
```

### Keycloak `Dockerfile` Change

Insert BEFORE the `RUN /opt/keycloak/bin/kc.sh build ...` line:

```dockerfile
# Story 2.5: Bake the Deep Sea login theme into the image.
# Build context = ./keycloak/ — all COPY sources are relative to keycloak/.
# Themes must be present BEFORE kc.sh build (Quarkus compiles them in).
# design-tokens/deep-sea.css is inside the theme directory (keycloak/themes/envocc/login/resources/design-tokens/)
# — it is included automatically by the COPY below.
COPY themes/envocc /opt/keycloak/themes/envocc
```

### CSS Variable Naming — Reference

All variables are declared in `design-tokens/deep-sea.css`. Use exactly:
```
--color-primary              #0E5C53   teal — buttons, links, seal
--color-primary-hover        #0A4842   button hover
--color-accent               #137A6E   focus ring, accent rule
--color-primary-foreground   #FFFFFF   text on primary (NOTE: NOT --color-primary-fg)
--color-background           #F6F4EF   warm-sand page bg
--color-surface          #FFFFFF   auth card bg
--color-border           #DCD6CA   greige hairline
--color-text-primary     #14211F   body text (14.5:1 on bg)
--color-text-muted       #51605D   secondary text (never for security copy)
--color-info-bg          #E4EFF4   anti-phishing banner bg
--color-info-border      #B8DAE6   anti-phishing banner border
--color-info-fg          #0F4A60   anti-phishing banner text
--color-error-bg         #F8E2DF   error state bg
--color-error-fg         #7A1A11   error state text
--color-focus-ring       #137A6E   focus ring color (= accent)
--font-family            "Noto Sans", "Noto Sans Thai", system-ui, sans-serif
--font-body-size         14px
--font-body-line-height  1.6       generous for Thai diacritics
--font-h1-size           22px
--spacing-auth-card-width 420px
--radius-md              8px        inputs, buttons
--radius-lg              12px       auth card
```

### Previous Story Learnings

**From story 1.4 (design-token stylesheet — done):**
- `design-tokens/deep-sea.css` is at the monorepo root, has 66 custom properties on `:root`.
- The file uses `--color-primary-foreground` (not `--color-primary-fg` — note the spelling: it IS `--color-primary-foreground`, check the actual file before referencing).
- Confirmed: file is plain CSS, no preprocessor required.
- The file header documents: story 2.5 will `<link>` to it via `${url.resourcesPath}/design-tokens/deep-sea.css`.

**From story 1.3 (nginx security edge — done):**
- `Content-Security-Policy: frame-ancestors 'none'` is set in nginx for `/realms/` paths — DO NOT duplicate in Keycloak realm config.
- Nginx uses `add_header` in separate location blocks; all headers must be repeated in each block (nginx inheritance rule).

**From story 1.2 (realm config-as-code — done):**
- `realm-export.json` is the config-as-code file, committed to git with secrets stripped.
- It is imported by Keycloak at startup via `--import-realm` (IGNORE_EXISTING strategy).
- Adding `"loginTheme": "envocc"` here is the correct way to activate a custom theme.

**From story 1.1 (Docker Compose foundation — done):**
- `compose.yaml` is at the repo root. The Keycloak service sets `context: ./keycloak` and `dockerfile: Dockerfile` — the build context is `keycloak/`, NOT the repo root. COPY paths in the Dockerfile are relative to `keycloak/`. This is why the design-tokens file must be committed inside `keycloak/themes/envocc/login/resources/design-tokens/` rather than copied from the repo root at build time.

### git Commit Style

Follow established pattern: `feat(story-2-5): <description>`

### Project Structure Notes

- **Architecture location:** `keycloak/themes/envocc/` [Source: architecture.md#Complete Project Tree]
- **token file path:** `design-tokens/deep-sea.css` (monorepo root) [Source: architecture.md#Complete Project Tree]
- **FG-2 staff experience** maps to `keycloak/themes/envocc/` + realm flows [Source: architecture.md#Requirements → Structure Mapping]
- No admin app files are touched in this story. Admin app imports tokens separately (story 4.1).
- No SvelteKit, no Bun, no TypeScript, no Drizzle — this story is purely Keycloak theming (CSS + FreeMarker + `.properties` files).

### Testing / Verification Approach

No automated unit tests for a CSS/FreeMarker theme. Verification is:
1. **Docker rebuild:** `docker compose down && docker compose up --build -d` — Keycloak boots with theme.
2. **Visual check:** Navigate to the login URL — correct Deep Sea styling, anti-phishing banner visible.
3. **Header check:** `curl -sI <login-url>` — `Content-Security-Policy: frame-ancestors 'none'` appears exactly once.
4. **No-JS check:** Disable JavaScript in browser — login form still submits, TOTP form still submits.
5. **Keyboard check:** Tab through all interactive elements — visible focus ring at each step.
6. **Label check:** Inspect DOM — every input has a `<label>` with `for`/`id` pairing; no placeholder-only labels.
7. **String check:** `grep -r 'hardcoded text\|Sign in\|Password' keycloak/themes/envocc/login/*.ftl` should find only `${msg("...")}` calls, not literal strings.
8. **Token check:** `grep -r '#[0-9A-Fa-f]\{3,6\}' keycloak/themes/envocc/login/resources/css/login.css` — no raw hex values (only `rgba(...)` for shadows is acceptable).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.5] — story requirements and ACs
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 2] — epic context and FR12, UX-DR2, UX-DR7, UX-DR8, UX-DR9
- [Source: _bmad-output/planning-artifacts/architecture.md#Decision 2 — Custom-surface stack] — native Keycloak theme, no JS in login path, Deep Sea tokens, top-level-only
- [Source: _bmad-output/planning-artifacts/architecture.md#Complete Project Tree] — `keycloak/themes/envocc/` location
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/DESIGN.md#Components — anti-phishing-banner] — info variant, pinned, full-contrast, no dismiss
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/EXPERIENCE.md#Voice and Tone] — "We'll never ask for your verification code by phone, email, or chat."
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-envocc-sso-2026-06-21/EXPERIENCE.md#Accessibility Floor] — WCAG AA requirements
- [Source: _bmad-output/implementation-artifacts/1-4-shared-deep-sea-design-token-stylesheet.md] — token file already exists; story 2.5 consumes it
- [Source: _bmad-output/implementation-artifacts/dependency-graph.md] — story 2.5 depends on epic 1 complete and story 1.4; ready to work
- [Source: nginx/nginx.conf#Auth surfaces — Keycloak realms / auth paths] — frame-ancestors 'none' already set
- [Source: keycloak/realm-export.json] — loginTheme not yet set; browserSecurityHeaders empty (correct)
- [Source: keycloak/Dockerfile] — COPY must be before `kc.sh build`; build context is `./keycloak/` (NOT repo root)
- [Source: compose.yaml] — Keycloak service `context: ./keycloak` confirms build context scope

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (Claude Code)

### Debug Log References

### Completion Notes List

### File List
