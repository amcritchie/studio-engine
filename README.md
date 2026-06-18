# Studio Engine

Shared Rails engine for McRitchie apps. Provides authentication, error handling, dynamic theming, and common concerns used by [McRitchie Studio](https://app.mcritchie.studio) and [Turf Monster](https://app.turfmonster.media).

> **Part of the McRitchie ecosystem** — see [`ECOSYSTEM.md`](https://github.com/amcritchie/mcritchie-studio/blob/main/docs/ECOSYSTEM.md) for the 5-repo map; [`house-burn-down.md`](https://github.com/amcritchie/mcritchie-studio/blob/main/docs/agents/system/house-burn-down.md) for fresh-Mac recovery.

## Installation

```ruby
# Gemfile — install from RubyGems (recommended)
gem "studio-engine", "~> 0.6"
```

Then `bundle install`. The current release is **v0.6.1**; see [`CHANGELOG.md`](./CHANGELOG.md) for the history.

> Published to RubyGems as of v0.4.0 (2026-05-17). New installs should use the RubyGems form, which the consumer Rails apps (`mcritchie-studio`, `turf-monster`) already use.

## What It Provides

- **Authentication**: Passwordless magic-link auth, optional password auth, Google OAuth via OmniAuth, Solana wallet sign-in, and optional one-way SSO patterns
- **Error handling**: `Studio::ErrorHandling` concern with `rescue_and_log`, `ErrorLog` model with `capture!`, error log viewer at `/error_logs`
- **Theme system**: Dynamic CSS custom properties generated from 7 role colors (primary, dark, light, success, accent, warning, danger). Dark/light mode toggle. Admin theme editor at `/admin/theme`.
- **UI primitives**: Shared component partials and CSS primitives such as `components/emoji_swap` for nav/sidebar emoji hover transitions.
- **Operator tooling**: Shared `studio/banners/environment` banner with Dev Mode + email connector controls, `studio/banners/impersonation`, and an opt-in `Studio::Impersonation` concern for Act As session conventions.
- **Sluggable concern**: `before_save :set_slug` with `to_param` for human-readable URLs
- **ThemeSetting model**: Per-app DB overrides with fallback to config defaults

## Configuration

Each consuming app configures the engine in `config/initializers/studio.rb`:

```ruby
Studio.configure do |config|
  config.app_name = "My App"
  config.session_key = :my_app_user_id
  config.welcome_message = ->(user) { "Welcome, #{user.display_name}!" }
  config.auth_methods = %i[magic_link google]
  config.registration_params = [:name, :email]
  config.magic_link_token_name = "magic_link_my_app_v1"
  config.mailer_from = Studio.mailer_from_for_transport(
    ses_from: "My App <team@example.com>"
  )
  config.theme_primary = "#4BAF50"   # Override default violet
  config.theme_logos = ["logo.svg"]
end
```

Transactional mail transport is shared through `Studio::MailTransport`:

```ruby
# config/initializers/studio_mail_transport.rb
Studio::MailTransport.configure!
```

It selects SES SMTP when `MAIL_TRANSPORT=ses` and SES SMTP credentials are
present, otherwise falls back to Resend when `RESEND_API_KEY` is present.

## Routes

In the consuming app's `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  Studio.routes(self)
  # ... app routes
end
```

This draws the enabled auth routes (`/login`, `/signup`, `/logout`, magic-link request/confirm/consume routes, Solana routes), OAuth callbacks, optional SSO routes, `/error_logs`, and `/admin/theme`. Magic-link emails point at the inert GET confirmation route; the single-use token is consumed only by the CSRF-protected POST to `magic_link_consume_path`.

In non-production local requests, this also draws `/_studio/local_emails`, a local email inbox for agent/worktree proof flows. Set `LOCAL_EMAIL_CAPTURE=1` or run with `AGENT_WORKTREE=1` to record outbox rows without sending real email.

## Non-Production Banners

Consumer layouts can render the shared environment banner inside their sticky
header:

```erb
<%= render "studio/banners/environment", devnet: false %>
```

The environment banner includes:

- a Dev Mode toggle button backed by `Alpine.store("devMode")`
- an Email status button that links to `/_studio/local_emails`
- a send/capture signal plus SES/Resend/unknown connector icon

Apps with admin Act As / impersonation state can render the matching banner
with their own users and return route:

```erb
<%= render "studio/banners/impersonation",
           impersonated_user: current_user,
           admin_user: true_user,
           stop_path: admin_stop_impersonating_path %>
```

The engine also provides an optional `Studio::Impersonation` concern for the
session convention:

```ruby
class ApplicationController < ActionController::Base
  include Studio::ErrorHandling
  include Studio::Impersonation
end
```

The concern adds `true_user`, `impersonated_user`, `impersonating?`,
`start_impersonation_session(target_user, actor:)`, and
`clear_impersonation_session`. Consumer apps still own the authorization rule,
audit log, enter/exit controller actions, and any app-specific safeguards such
as binding session-token checks to `true_user` or disabling wallet-only
privileges while impersonating.

## UI Primitives

Render `components/emoji_swap` inside a link or button with the `group` class to
slide between two emoji on hover and keyboard focus. The CSS ships through
`studio_theme_css_tag`, including a reduced-motion fade fallback.

```erb
<%= link_to root_path, class: "group inline-flex items-center gap-2" do %>
  <%= render "components/emoji_swap", base: "📊", hover: "✨" %>
  <span>Dashboard</span>
<% end %>
```

## Overriding Views

This is a non-isolated engine -- app views at the same path automatically override engine views. For example, placing `app/views/sessions/new.html.erb` in the consuming app replaces the engine's login page.

## Releasing

Engine releases use semantic versions and are published to RubyGems. The full
operator checklist lives in [`docs/RELEASE.md`](./docs/RELEASE.md).

Short form:

1. Update [`CHANGELOG.md`](./CHANGELOG.md) and `lib/studio/version.rb`.
2. Run `bin/release-check --build`.
3. Publish the gem only after explicit approval.
4. Tag the release after RubyGems accepts the gem.
5. In each consumer app, run `bundle update studio-engine`, verify the lockfile,
   and run app smoke checks.

**Semver guide**
- **PATCH**: bug fix; no API change. Consumers can update the gem with zero diff elsewhere.
- **MINOR**: backward-compatible feature add. Consumers may opt in to new APIs.
- **MAJOR**: breaking change. Consumers will need code changes alongside the tag bump.

## Local development (against an unreleased engine)

When iterating on engine code from a consumer app, point bundler at the local path so you don't need to push + tag for every edit:

```bash
# in the consumer app
bundle config set --local local.studio /Users/alex/projects/studio-engine
bundle install
# ... iterate in both repos ...
bundle config unset --local local.studio  # restore RubyGems resolution
```

For short local experiments, temporarily point a consumer Gemfile at `path: "../studio-engine"` and restore the RubyGems dependency before merging.

## Development Notes

Use the docs in [`docs/`](./docs) for engine setup, release, email transport,
and host-app contracts. Current cross-repo setup, ports, credentials, and
workflow guidance live in McRitchie Studio's
[`docs/agents/`](https://github.com/amcritchie/mcritchie-studio/tree/main/docs/agents).
