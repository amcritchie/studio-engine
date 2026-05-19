# Changelog

The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) — `MAJOR.MINOR.PATCH`. Both consumer Rails apps pin to a tag in their `Gemfile`; bumping the tag is a release.

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
