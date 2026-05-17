# Studio Engine

Shared Rails engine for McRitchie apps. Provides authentication, error handling, dynamic theming, and common concerns used by [McRitchie Studio](https://app.mcritchie.studio) and [Turf Monster](https://turf.mcritchie.studio).

> **Part of the McRitchie ecosystem** — see [`ECOSYSTEM.md`](https://github.com/amcritchie/mcritchie_studio/blob/main/docs/ECOSYSTEM.md) for the 5-repo map; [`house-burn-down.md`](https://github.com/amcritchie/mcritchie_studio/blob/main/docs/agents/system/house-burn-down.md) for fresh-Mac recovery.

## Installation

```ruby
# Gemfile
gem "studio", git: "https://github.com/amcritchie/studio.git"
```

Then `bundle install`.

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

## Updating

After making changes to this repo:

```bash
# Push changes to GitHub
git push origin main

# In each consuming app
bundle update studio
```

## Development Notes

See [CLAUDE.md](./CLAUDE.md) for detailed development context including the theme architecture, SSO protocol, color scale system, and code conventions.
