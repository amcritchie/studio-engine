# Changelog

The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) — `MAJOR.MINOR.PATCH`. Both consumer Rails apps pin to a tag in their `Gemfile`; bumping the tag is a release.

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
