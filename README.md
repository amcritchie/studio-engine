# Studio Engine

Shared Rails engine for McRitchie apps. Provides authentication, error handling, dynamic theming, and common concerns used by [McRitchie Studio](https://app.mcritchie.studio) and [Turf Monster](https://turf.mcritchie.studio).

> **Part of the McRitchie ecosystem** — see [`ECOSYSTEM.md`](https://github.com/amcritchie/mcritchie-studio/blob/main/docs/ECOSYSTEM.md) for the 5-repo map; [`house-burn-down.md`](https://github.com/amcritchie/mcritchie-studio/blob/main/docs/agents/system/house-burn-down.md) for fresh-Mac recovery.

## Installation

```ruby
# Gemfile — install from RubyGems (recommended)
gem "studio-engine", "~> 0.4.0"
```

Then `bundle install`. The current release is **v0.4.10**; see [`CHANGELOG.md`](./CHANGELOG.md) for the history.

> Published to RubyGems as of v0.4.0 (2026-05-17). Earlier consumers used a `git:` ref pinned to a tag; that pattern is preserved here for reference but new installs should use the RubyGems form, which the consumer Rails apps (`mcritchie-studio`, `turf-monster`, `tax-studio`) already use.

## What It Provides

- **Authentication**: Session-based login/signup controllers and views, Google OAuth via OmniAuth, one-way SSO (hub to satellite)
- **Error handling**: `Studio::ErrorHandling` concern with `rescue_and_log`, `ErrorLog` model with `capture!`, error log viewer at `/error_logs`
- **Theme system**: Dynamic CSS custom properties generated from 7 role colors (primary, dark, light, success, accent, warning, danger). Dark/light mode toggle. Admin theme editor at `/admin/theme`.
- **Sluggable concern**: `before_save :set_slug` with `to_param` for human-readable URLs
- **ThemeSetting model**: Per-app DB overrides with fallback to config defaults

## Configuration

Each consuming app configures the engine in `config/initializers/studio.rb`:

```ruby
Studio.configure do |config|
  config.app_name = "My App"
  config.session_key = :my_app_user_id
  config.sso_logo = "/logo.svg"
  config.welcome_message = ->(user) { "Welcome, #{user.display_name}!" }
  config.registration_params = [:name, :email, :password, :password_confirmation]
  config.theme_primary = "#4BAF50"   # Override default violet
  config.theme_logos = ["logo.svg"]
end
```

## Routes

In the consuming app's `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  Studio.routes(self)
  # ... app routes
end
```

This draws: `/login`, `/signup`, `/logout`, `/sso_continue`, `/sso_login`, `/auth/:provider/callback`, `/auth/failure`, `/error_logs`, `/admin/theme` (GET, PATCH), `/admin/theme/regenerate`.

## Overriding Views

This is a non-isolated engine -- app views at the same path automatically override engine views. For example, placing `app/views/sessions/new.html.erb` in the consuming app replaces the engine's login page.

## Releasing

Engine releases are git tags (semver: `MAJOR.MINOR.PATCH`). Both consumer apps pin to a tag in their Gemfile — bumping the tag is the release.

1. Make + commit changes on `main`.
2. Update [`CHANGELOG.md`](./CHANGELOG.md) with the new version + a `### Added` / `### Changed` / `### Removed` summary. Keep entries terse.
3. Bump `lib/studio/version.rb` to match.
4. Commit the version bump + CHANGELOG together (`v0.X.Y: <summary>`).
5. Tag: `git tag -a v0.X.Y -m "<one-line summary>"`.
6. Push: `git push origin main --tags`.
7. In each consumer app's Gemfile, update the `tag:` field. Commit + push.
8. On consumer prod: `bundle install` runs as part of the deploy buildpack.

**Semver guide**
- **PATCH**: bug fix; no API change. Consumers can bump tag with zero diff elsewhere.
- **MINOR**: backward-compatible feature add. Consumers may opt in to new APIs.
- **MAJOR**: breaking change. Consumers will need code changes alongside the tag bump.

## Local development (against an unreleased engine)

When iterating on engine code from a consumer app, point bundler at the local path so you don't need to push + tag for every edit:

```bash
# in the consumer app
bundle config set --local local.studio /Users/alex/projects/studio-engine
bundle install
# ... iterate in both repos ...
bundle config unset --local local.studio  # restore tag-pinned resolution
```

Note: `bundle config local.studio` requires `branch:` in the Gemfile entry. If you frequently develop locally, change the Gemfile to `gem "studio-engine", git: "...", branch: "main"` during dev and back to `tag:` before merging.

## Development Notes

See [CLAUDE.md](./CLAUDE.md) for detailed development context including the theme architecture, SSO protocol, color scale system, and code conventions.
