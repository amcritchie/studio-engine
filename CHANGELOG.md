# Changelog

The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) — `MAJOR.MINOR.PATCH`. Both consumer Rails apps pin to a tag in their `Gemfile`; bumping the tag is a release.

## v0.4.5 (2026-05-23)

Modal infrastructure — same shape as the toast system from v0.4.0. Apps render `studio/modals/host` once, then open through `Alpine.store('modals')` and compose the shared content blocks. No migration required for v0.4.4 consumers.

### Added
- **`studio/modals/host` partial.** Single shared shell that bundles the scroll-lock CSS, bfcache/Turbo snapshot cleanup, `Alpine.store('modals')` registration (stack-based), `window.StudioModals.holdAtLeast(ms)` helper, and the modal markup (z-[120] backdrop, fade-and-scale transitions, escape/click-outside/ARIA dialog). Consumer renders once in `application.html.erb` with a block that registers their app-specific content partials by id:
  ```erb
  <%= render "studio/modals/host" do %>
    <template x-if="$store.modals.current().id === 'auth'">
      <%= render "modals/auth" %>
    </template>
  <% end %>
  ```
- **`Alpine.store('modals')` stack store.** API: `open(id, props, opts)` (with `opts.replace: true` for flicker-free transitions between steps in a wizard), `close()`, `closeAll()`, `isOpen(id)`, `current()`. Auto-syncs `body.modal-open` for scroll lock. Stack-based so modals can nest (e.g. confirm-on-top-of-form).
- **`window.StudioModals.holdAtLeast(ms)` helper.** Stamps the moment a loading view becomes visible, returns `{ then(callback) }` that delays the callback by the remaining time if the operation finished before the minimum. Replaces ad-hoc `Date.now() - startedAt` arithmetic at every async-success site. Mirrors `_navSpinnerMinMs` from `_head.html.erb`.
- **Four reusable content-block partials in `studio/modals/blocks/`.** Composable building blocks any modal can render to assemble its inner content:
  - `_success_card` — icon (default green check, or any emoji), title, optional sub-text, optional Solana tx-signature explorer link, primary CTA (href or dispatched event), secondary CTA, **self-driven auto-redirect countdown** (progress bar + "Xs…" text, fires `window.location.href` at zero), and **opt-in confetti** burst via `window.fireSuccessConfetti`.
  - `_error_card` — emoji icon (default ⏳, configurable for ⚠️ / 📍 / etc.), title, message (static string or Alpine-expression key for live updates), CTA that can reload the page, dispatch an event, or be omitted.
  - `_processing_card` — spinner (sm/md/lg, three color tokens) + title + optional message. Designed to pair with `holdAtLeast` on the caller side.
  - `_progress_countdown` — standalone progress bar + countdown text. Reads display values from caller-provided Alpine expressions so externally-driven countdowns (board's `setInterval` mutating `$store.modals` props) and internally-driven ones (success card's own timer) can share the same visualization.

### Architecture
- **Content vs. blocks.** Each consumer app owns its modal *content* partials (turf-monster's `modals/auth`, mcritchie-studio's account flows, etc.) because the flows are product-specific. The engine provides the *shell* (host) and the *building blocks* (cards) because those are universal UI vocabulary.
- **Single root requirement** on modal content partials — Alpine's `<template x-if>` clones only the first root element from its content. Top-level `<style>` blocks or stray siblings are silently dropped. Bake the style inside the partial's outer wrapping `<div>` if needed.

## v0.4.4 (2026-05-20)

Sticky-navbar scroll fixes — bounce-free for every consuming app, no migration required.

### Fixed
- **Navbar scroll-collapse bounce.** A `position: sticky` navbar that shrinks on scroll changes layout above the fold; Chrome/Firefox scroll-anchoring then compensates by moving `scrollY`, which re-crosses the collapse threshold and oscillates. `_head.html.erb` now ships `body { overflow-anchor: none }`, so the navbar resize no longer drags `scrollY`. Every app that renders `layouts/studio/head` gets this automatically.
- **Navbar unscroll threshold `20 → 5`** in `_navbar.html.erb` — widens the hysteresis dead zone (5/60) so a height change can't push `scrollY` back across the lower bound.

### Added
- **`--nav-h` CSS variable.** `_head.html.erb` ships a `ResizeObserver` that publishes the page header's live height to `--nav-h` on `:root` — updated on every resize (including the collapse animation) and re-attached after Turbo navigations. Fixed/sticky elements below the navbar can position off `var(--nav-h)` instead of hardcoded px (e.g. `style="top: var(--nav-h)"`). Auto-detects the page `<header>`; no markup changes needed.

## v0.4.3 (2026-05-19)

Tier-3 fix from the turf-monster pre-prod opsec audit (OPSEC-016).

### Fixed (security)
- **`GET /sso_login` no longer mutates the session (OPSEC-016).** The action previously called `authenticate_sso_user!` directly — starting a session on a GET. GETs are not CSRF-covered and are prefetchable (`<img>`, `<link rel=prefetch>`, browser prefetch), so an XSS on any `*.mcritchie.studio` subdomain that wrote `session[:sso_email]` could have a forged `/sso_login` hit silently start a session as that user. `sso_login` now only redirects to the login page; the session mutation happens exclusively through the CSRF-protected `POST /sso_continue` ("Continue as …" button).

### Changed
- The hub's one-click SSO link to a satellite's `/sso_login` now lands the user on the satellite login page with the "Continue as …" button instead of logging them in directly — one extra click, and the GET endpoint is no longer a session-mutation vector.

## v0.4.2 (2026-05-19)

Security follow-up to v0.4.1 — closes a cross-app session-fixation surface.

### Fixed (security)
- **Removed legacy `session[:user_id]` fallback in `Studio::ErrorHandling#current_user`** (OPSEC-042). Previously, if `session[Studio.session_key]` was empty but `session[:user_id]` was present, the engine would look up the user by that ID and silently call `set_app_session(user)` — promoting an arbitrary user ID to logged-in status. Combined with the shared `*.mcritchie.studio` cookie scope, any XSS on any subdomain that wrote `session[:user_id]` became cross-app login-as-anyone. The legacy key was a Devise-era migration carrier; consumer apps no longer write to it. Removing the fallback closes the fixation surface.

### Breaking
- Any user with a stale session that still has `session[:user_id]` set but NOT `session[Studio.session_key]` will be logged out on next request. Practically: nobody, since the engine has been writing `session[Studio.session_key]` since v0.2.x.

## v0.4.1 (2026-05-17)

Pre-public-release security hardening per `SECURITY-AUDIT-2026-05-17.md`.

### Fixed (security)
- **SSRF guard in `Studio::ImageCache.cache!`** — `source_url` is now validated: rejects schemes other than http/https, blocks loopback / private / link-local IPs (incl. AWS metadata 169.254.169.254), and blocks `localhost` / `*.local` / `*.internal` / `*.lan` hostnames. Raises `Studio::ImageCache::InvalidSourceURL`. Does not defend against DNS rebinding.
- **MIME-type allowlist in `Studio::ImageCache.cache!`** — `content_type` must be one of `ALLOWED_CONTENT_TYPES` (image/png|jpeg|jpg|webp|gif). Raises `Studio::ImageCache::UnsupportedContentType`.
- **MiniMagick resource caps per invocation** — every resize runs with `-limit memory 256MB -limit map 512MB -limit width/height 16KP` to prevent decompression-bomb DoS.
- **Remote source size cap** — `MAX_REMOTE_BYTES = 50MB`. Raises `Studio::ImageCache::SourceTooLarge` on overage.
- **`ErrorLog.capture!` no longer stores `exception.inspect`** — Ruby's default inspect for many error subclasses includes ivar dumps that can carry secrets (API keys read into locals, request bodies). Now stores a sanitized `"#<{class}: {message[0,1000]}>"` instead.

### Changed (breaking for misconfigured users only)
- **`Studio.s3_bucket_prefix` no longer defaults to `"mcritchie-studio"`.** Default is `nil`; host apps MUST set explicitly in `config/initializers/studio.rb`. Both current consumer apps already do this — no impact in practice.
- **`Studio.UserContractError` message** now points at the correct repo URL (`amcritchie/studio-engine`, not `amcritchie/studio`).

### Added
- `LICENSE` file (MIT) — gemspec already declared MIT but the file was missing. Required for RubyGems listing.
- Gemspec author email changed from `alex@mcritchie.studio` (personal) to `studio-engine@mcritchie.studio` (project alias).

## v0.4.0 (2026-05-17)

### Changed (breaking)
- **Gem renamed from `studio` to `studio-engine`.** Repo URL is now `github.com/amcritchie/studio-engine` (was `.../studio`). Consumers must update their `Gemfile`:
  ```ruby
  # Before:
  gem "studio", git: "https://github.com/amcritchie/studio.git", tag: "v0.3.1"
  # After:
  gem "studio-engine", git: "https://github.com/amcritchie/studio-engine.git", tag: "v0.4.0"
  ```
- The Ruby `Studio` module name is **unchanged** — all call sites (`Studio.configure`, `Studio::ErrorHandling`, `Studio::ImageCache`, etc.) keep working without code changes.
- Gem entry point at `lib/studio-engine.rb` (a thin `require_relative "studio"` shim) ensures `gem "studio-engine"` auto-requires correctly without a `require:` option in the Gemfile.

### Added
- `LICENSE`, gemspec `metadata` (homepage / source / bugs / changelog URIs), `spec.description`, `spec.required_ruby_version` — getting ready for RubyGems publishing.

## v0.3.1 (2026-05-17)

### Fixed
- `Studio.validate_user_contract!` no longer checks for `User#email` (or any column-style attribute). ActiveRecord defines column accessors lazily, so they don't appear on `.instance_methods` until first record access — leading to false-positive `Studio::UserContractError` raises at boot. Only explicitly-defined methods (`authenticate`, `admin?`, `display_name`, class `find_by`) are validated. DB columns are out of scope; missing columns fail the User table migration instead.

## v0.3.0 (2026-05-17)

### Added
- **Shared stage-* badge palette.** New scheme aliases on `app/views/components/_badge.html.erb`: `stage-fresh` (blue), `stage-shaping` (yellow), `stage-structured` (mint), `stage-refined` (emerald), `stage-cohered` (violet), `stage-shipped` (emerald), `stage-closed` (gray). Consumer apps' News + Content stage helpers can now resolve to a unified palette instead of each picking ad-hoc scheme names per stage. Closes ecosystem-audit Tier 1 #2.
- **`Studio.validate_user_contract!`** + boot-time validator hook in `Engine#after_initialize`. Verifies host's `User` class responds to required methods (`authenticate`, `admin?`, `email`, `display_name`, plus class `find_by`). Raises `Studio::UserContractError` with a clear pointer to `docs/USER_CONTRACT.md` when something's missing — replaces the previous cryptic `NoMethodError` at first request. Opt out per-app with `Studio.validate_user_contract = false`. Closes ecosystem-audit Tier 2 #16.
- **`docs/USER_CONTRACT.md`** — full reference for required + optional User methods, recommended DB columns, and a minimal compliant model example.
- **Sentry fan-out from `ErrorLog.capture!`.** When the host app has loaded `sentry-ruby` (and Sentry is initialized via DSN), every `ErrorLog.capture!` call also sends the exception to Sentry with `error_log_slug` as a tag for cross-reference. Apps without `sentry-ruby` are unaffected — the call is guarded with `defined?(::Sentry)`. Closes ecosystem-audit Tier 2 #15.

### Changed
- Stage badge color schemes are additive — existing `success/danger/warning/info/violet/primary/orange/emerald/gray/neutral` schemes unchanged.

### Notes
- Both current consumer apps (mcritchie-studio, turf-monster) already satisfy the new User contract — validator is a no-op for them.

## v0.2.4 (pre-2026-05-17)

Last release before formal versioning. Consumer apps tracked `git: main` until this point. v0.2.4 is the snapshot at the previous commit `ef738ff` ("Studio::ImageCache.cache! accepts source_path for local files"). Anything before that is in `git log`.
