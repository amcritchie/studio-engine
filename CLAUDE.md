# Studio Engine

Shared Rails engine gem for McRitchie apps. Provides auth, error handling, and common models so both apps stay in sync.

- **GitHub**: https://github.com/amcritchie/studio-engine
- **Gem name**: `studio-engine` (renamed from `studio` in v0.4.0 to free up the `studio` name on RubyGems and to make the role clearer)
- **Version**: 0.4.4
- **Consumed by**: McRitchie Studio (`mcritchie-studio/`), Turf Monster (`turf-monster/`), and Tax Studio (`tax-studio/`)
- **Docs**: `docs/` directory — `NAVBAR_SETUP.md`, `GOOGLE_AUTH_SETUP.md`, `ENV_SETUP.md`, `NEW_APP_SETUP.md`

## Architecture

**Non-isolated engine** — no `isolate_namespace`. All classes merge into the host app's namespace (`ErrorLog`, not `Studio::ErrorLog`). Host app files take precedence over engine files automatically (Rails view/controller lookup order).

**Concern, not base class** — `Studio::ErrorHandling` is included in each app's `ApplicationController`. Contains auth helpers + two-layer error handling.

**Routes via helper** — `Studio.routes(self)` draws routes into the host's router. No `mount`. Route helpers (`login_path`, `error_logs_path`) work identically in both apps.

**Config via procs** — `Studio.configure` block in each app's `config/initializers/studio.rb` sets app-specific behavior (registration params, welcome message, new user setup, session key).

## What's in the Engine

### Controllers
- `ErrorLogsController` — public index (ILIKE search) + show (slug lookup)
- `SessionsController` — email/password login, logout, `sso_login` (GET — redirects to login, OPSEC-016), `sso_continue` (POST — performs SSO login). SSO user creation lives in the private `authenticate_sso_user!` method, now called only from `sso_continue`.
- `OmniauthCallbacksController` — Google OAuth callback + failure (overridden in Turf Monster for merge support)
- `RegistrationsController` — signup with configurable params via `Studio.registration_params`
- `ThemeSettingsController` — admin-only theme editor (edit/update/regenerate). Auth via `require_admin_for_theme`.
- `NavbarController` — admin-only navbar preview page. Route NOT drawn by engine (apps must add `get "admin/navbar", to: "navbar#show"` to their own routes to avoid conflicts).

### Concern
- `Studio::ErrorHandling` — `current_user`, `logged_in?`, `require_authentication`, `set_app_session`, `clear_app_session`, `sso_user_available?`, `sso_display_name`, `sso_source_app`, `sso_hub_logo`, `rescue_and_log`, `create_error_log`, `handle_not_found`, `handle_unexpected_error`

### Models
- `ErrorLog` — polymorphic target/parent, `capture!(exception)`, cleaned backtrace
- `ThemeSetting` — single-row-per-app (keyed by `app_name`), 7 nullable color columns (DB: `accent1`/`accent2`, mapped to roles `success`/`accent` via `db_column_for`), `resolved_colors` merges DB + config defaults
- `ImageCache` — polymorphic owner, columns: `purpose`, `variant`, `s3_key`, `source_url`, `bytes`, `content_type`. Unique on `(owner_type, owner_id, purpose, variant)` and on `s3_key`. `#url` → `Studio::S3.url(key: s3_key)`. Per-app `image_caches` table (same pattern as `error_logs`).
- `Sluggable` concern — `before_save :set_slug`, `to_param` returns slug

### Views
- `layouts/studio/_flash.html.erb` — **toast notification system**. Self-contained partial (CSS + HTML + `toastManager` Alpine component). Supports notice/alert types, custom titles, images, action buttons, blur shadow glow, stacking with peek strips, configurable duration. Must be first child of `<body>` for `backdrop-filter: blur()`. Server-side flash auto-converts to toasts. JS API: `dispatchEvent(new CustomEvent('toast', { detail: { type, title, message, image, dismissible, buttons, duration, blurShadow } }))`. Note: `components/_flash.html.erb` (old horizontal bars) still exists but is no longer referenced.
- `error_logs/index.html.erb` — Alpine.js search with loading spinner
- `error_logs/show.html.erb` — backtrace, target/parent with copy-to-clipboard, JSON dump
- `layouts/_navbar.html.erb` — base navbar scaffold with scroll hysteresis, logo, brand title (last word in primary), user nav, mobile sub-navbar. Locals: `preview`, `show_logged_in`, `balance_html`, `extra_icons_html`, `show_logout_link`. Apps override by creating their own `layouts/_navbar.html.erb`.
- `navbar/show.html.erb` — admin navbar preview page with responsive breakpoint simulation (Tiny/Small/Tablet), scrolled state toggles, username override, logged-in/logged-out views
- `sessions/new.html.erb` — login with logo (`Studio.logo_for("Auth Logo")`), brand title (last word in primary), SSO blur overlay, Google OAuth. Apps can override.
- `sessions/_sso_continue.html.erb` — "Continue as" button partial for cross-app awareness
- `registrations/new.html.erb` — signup with logo, brand title, conditional name field, Google OAuth. Apps can override.
- `components/_theme_toggle.html.erb` — sun/moon toggle button for dark/light mode
- `components/_admin_dropdown.html.erb` — gear icon dropdown (Alpine.js) with links to Theme (`/admin/theme`), Navbar (`/admin/navbar`), and Error Logs (`/error_logs`). All three apps override locally with app-specific links.
- `components/_user_nav.html.erb` — shared right-side navbar user section. Locals: `balance_html`, `extra_icons_html`, `show_logout_link`, `div2_html`. Logged in: two-row layout (Div 1: balance/icons/username with `gap-2 items-center` alignment, Div 2: seeds progress bar with clip-path text color + wallet address/level or logout link) + avatar. Div 2 has Alpine-driven green progress bar reading `seedsNavbar` localStorage, level-up animation, and event listeners. Logged out: gear + theme toggle + Log in/Sign up links. Mobile sub-navbar skips gear+moon when logged in (user_nav already has them).
- `components/_google_logo.html.erb` — shared Google OAuth SVG logo, used by both apps' login/signup/account views
- `components/_badge.html.erb` — reusable badge with scheme parameter: success, danger, warning, info, violet, primary, orange, emerald, gray, neutral
- `components/_progress_bar.html.erb` — reusable progress bar with percent, height, color, label, animated locals
- `theme_settings/edit.html.erb` — combined theme page: color editor (7 pickers + live dark/light preview) at top, styleguide sections below (logos via `theme_logos` config, semantic tokens, typography, buttons, components)

### Class Methods
- `Studio.logo_for(title)` — resolves a logo from `theme_logos` by title. Fallback chain: exact title match → "Navbar Logo" → first logo. Returns path string like `"/logo.png"` or `nil`. Used by navbar (title: "Navbar Logo") and auth views (title: "Auth Logo").

### Helpers
- `StudioThemeHelper` — `studio_theme_css_tag` method: loads colors from `ThemeSetting.current` (DB) → falls back to `Studio.theme_config` → runs through `Studio::ThemeResolver` → renders as `<style>` tag. Cached via `Rails.cache` (1-hour TTL).

### Lib Modules
- `Studio::ColorScale` — pure Ruby hex color math: `generate(hex)` returns 50-900 shade scale, `lighten`, `darken`, `hex_to_rgb`, `rgb_to_hex`, `with_opacity`
- `Studio::ThemeResolver` — takes 7 role colors, derives all ~22 CSS custom properties + primary palette (50-900 shades + RGB variants) for dark and light modes. `to_css` returns the full `:root, .dark { ... } html:not(.dark) { ... }` CSS string.
- `Studio::S3` — thin `aws-sdk-s3` wrapper. Bucket auto-resolves to `"#{Studio.s3_bucket_prefix}-#{Rails.env.production? ? "production" : "dev"}"`. Default prefix `"mcritchie-studio"`, default region `"us-east-2"`. API: `upload`, `download`, `url`, `signed_url`, `exists?`, `delete`, `list`, `bucket`. Lazy-loads `aws-sdk-s3`.
- `Studio::ImageCache` — `cache!(owner:, purpose:, source_url:, key_prefix:, widths:, content_type:)`. Downloads source once, generates resized variants via MiniMagick, uploads each to S3, persists `ImageCache` rows. Always stores the unmodified source as variant `"original"` alongside requested widths. Idempotent — variants already in `ImageCache` are skipped. Layout: `{key_prefix}/original.{ext}`, `{key_prefix}/{width}.{ext}`. Requires system ImageMagick (`brew install imagemagick`).

### Dynamic Theme System

**How it works**: `_head.html.erb` calls `studio_theme_css_tag` which injects a `<style>` tag with all CSS custom properties before the Tailwind stylesheet loads. Tailwind's semantic tokens (`bg-page`, `text-heading`, `border-subtle`) reference these CSS vars.

**7 role colors** → all derived automatically:
- `primary` → `--color-cta`, `--color-cta-hover`, `--color-primary-{50..900}` + `-rgb` variants
- `success` → `--color-success`
- `warning` → `--color-warning`
- `danger` → `--color-danger`
- `dark` → surface/inset/border colors for dark mode (lighten/darken percentages)
- `light` → surface/inset/border colors for light mode (includes `--color-cta`, `--color-cta-hover`, `--color-success`, `--color-warning`, `--color-danger`)

**Dynamic primary palette**: `primary_palette_vars` generates `--color-primary-{50..900}` shade scale + `--color-primary-{shade}-rgb` (space-separated RGB) for Tailwind `<alpha-value>` opacity support. Shared Tailwind config maps `primary-*` utilities to these CSS vars.

**Config**: `Studio.theme_*` accessors with defaults (violet primary). Apps override in `config/initializers/studio.rb`.
**DB override**: `ThemeSetting` model — nullable columns fall back to config defaults. Admin theme page at `/admin/theme`.
**Cache**: `Rails.cache.fetch("studio/theme/#{Studio.app_name}")` with 1-hour TTL. Regenerate button clears cache.
**Migration**: Each app creates `theme_settings` table manually (consistent with `create_error_logs` pattern).

**Tokens defined in shared Tailwind config**: `page`, `surface`, `surface-alt`, `inset` (colors); `heading`, `body`, `secondary`, `muted` (textColor); `subtle`, `strong` (borderColor).

**FOUC prevention**: `_head.html.erb` includes a synchronous `<script>` that sets `class="dark"` from `localStorage.getItem('theme')` before any paint. Alpine theme store initialized on `alpine:init`.

**Theme toggle store**: `Alpine.store('theme')` is an object with `toggle()` method and `isDark` getter (refactored from a plain string). Toggle icons use Heroicons v2 (matching the gear icon set in `_admin_dropdown.html.erb`).

**Views use semantic classes**: `bg-page`, `bg-surface`, `text-heading`, `text-body`, `border-subtle`, etc. Brand colors (`text-violet`, `bg-mint`) are static and don't use tokens.

See top-level `CLAUDE.md` for the full token reference table.

## Configuration

```ruby
# config/initializers/studio.rb (hub app — McRitchie Studio)
Studio.configure do |config|
  config.app_name = "McRitchie Studio"
  config.session_key = :studio_user_id
  config.sso_logo = "/studio-logo.svg"
  config.welcome_message = ->(user) { "Welcome, #{user.display_name}!" }
  config.registration_params = [:name, :email, :password, :password_confirmation]
  config.configure_sso_user = ->(user) { user.role = "viewer" }
  config.theme_logos = [
    { file: "favicon.png",      title: "Favicon" },
    { file: "logo-icon.svg",    title: "Navbar Logo" },
    { file: "studio-logo.svg",  title: "SSO Logo" },
  ]
  # Theme uses defaults (violet primary) — no theme_* config needed
end

# config/initializers/studio.rb (satellite app — Turf Monster)
Studio.configure do |config|
  config.app_name = "Turf Monster"
  config.session_key = :turf_user_id
  config.configure_sso_user = ->(user) { user.balance_cents = 0 }
  config.theme_logos = [
    { file: "favicon.png",   title: "Favicon" },
    { file: "logo.png",      title: "Navbar Logo" },
    { file: "logo.jpeg",     title: "Auth Logo" },
  ]
  config.theme_primary = "#4BAF50"  # green
  config.theme_accent = "#8E82FE"   # violet
end
```

### Theme Config Options
| Option | Default | Description |
|--------|---------|-------------|
| `theme_primary` | `#8E82FE` | CTAs, buttons, links, primary palette |
| `theme_success` | `#4BAF50` | Success accent |
| `theme_accent` | `nil` | Tertiary accent |
| `theme_warning` | `#FF7C47` | Warning states |
| `theme_danger` | `#EF4444` | Destructive actions |
| `theme_dark` | `#1A1535` | Dark mode base |
| `theme_light` | `#f8fafc` | Light mode base |
| `theme_logos` | `[]` | Array of `{ file:, title: }` hashes (or plain strings) for logo display on theme page |

### Theme Routes
- `GET /admin/theme` → `theme_settings#edit` (admin-only theme editor + styleguide)
- `PATCH /admin/theme` → `theme_settings#update` (save theme colors)
- `POST /admin/theme/regenerate` → `theme_settings#regenerate` (clear cache)

## One-Way SSO: Hub → Satellite

McRitchie Studio is the central auth hub. Satellite apps (Turf Monster, future apps) receive SSO from Studio — not the other way around. Each app has its own session key so login/logout is independent.

### Architecture

- **Hub app** (McRitchie Studio): Sets `sso_*` awareness fields in the shared session on login. Has a nav link to each satellite app's `/sso_login` for one-click SSO. Does NOT show "Continue as" on its own login page.
- **Satellite apps** (Turf Monster): Show "Continue as [name]" button on login page when hub session data exists. The button and branding come from the engine's `_sso_continue.html.erb` partial — no local override needed.
- **Shared cookie**: `_studio_session` spans `*.mcritchie.studio`. Each app reads/writes its own session key + shared `sso_*` fields.

### Session Methods

- **`set_app_session(user)`** — sets `session[Studio.session_key]` (app-specific). Only updates `sso_*` fields if this app is the source (prevents overwriting hub data when satellite logs in).
- **`set_sso_session(user)`** — alias for `set_app_session` (backwards compatibility)
- **`clear_app_session`** — deletes this app's session key. Clears `sso_*` fields only if this app is the source.
- **`current_user`** — looks up `session[Studio.session_key]`. (Legacy `session[:user_id]` fallback was removed in v0.4.2 per OPSEC-042 — cross-app fixation surface.)

### SSO Fields (stored in session by hub app)

`sso_email`, `sso_name`, `sso_provider`, `sso_uid`, `sso_wallet`, `sso_source`, `sso_logo`

### SSO Routes & Actions

- **`GET /sso_login`** — SSO entry point linked from hub app nav. OPSEC-016: redirects to the satellite login page (no longer mutates the session on a GET); the user completes login via the CSRF-protected `POST /sso_continue` button shown there.
- **`POST /sso_continue`** — form-based SSO from the "Continue as" button on login page.

### View Helpers

- **`sso_user_available?`** — true when not logged in, `sso_email` present, and `sso_source` is a different app
- **`sso_display_name`** — name or email prefix from sso fields
- **`sso_source_app`** — which app set the sso data
- **`sso_hub_logo`** — logo path from `session[:sso_logo]` (set via `Studio.sso_logo` config)

### SSO Button Partial

`sessions/_sso_continue.html.erb` — engine-provided, renders centered "Continue as [name]" button with hub logo (from `sso_hub_logo`). Styled to match Google/Wallet sign-in buttons. Satellite apps just add `<%= render "sessions/sso_continue" %>` to their login view — no local partial needed.

### Key Design Decisions

- **One-way flow** — Studio is the hub, satellite apps are targets. Studio's login page has no "Continue as" button.
- **No auto-provisioning** — removed `create_sso_user`. Cross-app login requires explicit user action (clicking "Continue as" or the nav link).
- **Independent logout** — `clear_app_session` only removes this app's key. Logging out of a satellite doesn't affect the hub.
- **sso_source preservation** — `set_app_session` doesn't overwrite `sso_*` fields if another app set them. `clear_app_session` only clears them if this app is the source.
- **Wallet-only guard** — users with no email have no `sso_email`, so "Continue as" never appears.
- **Logo via config** — hub sets `config.sso_logo`, stored in `session[:sso_logo]`, rendered by engine partial. Satellite apps need the logo file in their `public/` folder.

### Adding a New Satellite App

1. Set `config.session_key` to a unique symbol
2. Set `config.configure_sso_user` for app-specific defaults
3. Add `<%= render "sessions/sso_continue" %>` to login view
4. Copy hub's logo to `public/` (e.g. `public/studio-logo.svg`)
5. Add the app as a nav link in the hub

### Requirements
- All apps share `SECRET_KEY_BASE` and identical `session_store.rb` config
- Each app sets a unique `config.session_key`

## When to Add Code Here vs in the App

**Add to engine when:**
- Both apps need the same controller, model, or view
- It's auth, error handling, or shared infrastructure
- A view is identical between apps (error logs)

**Keep in the app when:**
- It's app-specific business logic (tasks, contests, picks)
- The view has app-specific branding (login/signup pages)
- It's a model that only exists in one app
- It's app-specific auth logic (wallet auth, account merging — Turf Monster only)

**Override pattern:** To customize an engine view or controller, create the same file path in the app. Rails loads app files before engine files.

## Updating the Engine

1. Make changes in `/Users/alex/projects/studio-engine/`
2. Commit and push to GitHub
3. Bump `lib/studio/version.rb` + CHANGELOG.md, tag `v0.X.Y`, push tag
4. In each consumer app: bump the `tag:` in Gemfile, `bundle update studio-engine`, test

See README.md "Releasing" section for the full flow.

## Testing

- `bin/rails test` — run from within a consuming app (engine has no standalone test harness)
- ~20 tests in Studio Engine (ColorScale, ThemeResolver, Config)
- Engine tests live in consuming apps' test suites (test engine models/helpers as part of app tests)
- **Critical test targets**: `Studio::ColorScale` (pure functions), `Studio::ThemeResolver` (CSS generation), `ErrorLog.capture!`, `Sluggable` concern

## View Override Example

To customize an engine view, create the same path in your app:

```
# Engine provides: studio/app/views/sessions/new.html.erb
# App overrides: myapp/app/views/sessions/new.html.erb (app wins)
```

Common overrides:
- `layouts/_navbar.html.erb` — app-specific navbar with custom nav links (most apps override this)
- `sessions/new.html.erb` — branded login page (engine now includes logo + SSO blur by default)
- `registrations/new.html.erb` — branded signup page (engine now includes logo by default)
- `sessions/_sso_continue.html.erb` — custom SSO button styling
- `components/_admin_dropdown.html.erb` — app-specific admin links

## Code Standards

Follow the same conventions as the top-level `CLAUDE.md`:
- `find_by` not `find`, nil guards after lookups
- Bang methods inside `rescue_and_log`
- Every model gets timestamps and a slug
- Sluggable concern for URL-facing models
