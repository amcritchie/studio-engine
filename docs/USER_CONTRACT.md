# User Model Contract

The Studio engine is a non-isolated Rails engine: it doesn't define `User`. Host apps must provide a `User` model that satisfies the contract below. If something is missing the engine will raise at boot via `Studio.validate_user_contract!` (see `lib/studio.rb`) with a clear message pointing back here.

## Required

These are the methods/attributes the engine actively calls. Missing one of these will block boot.

### Class methods
| Name | Used by | Notes |
|------|---------|-------|
| `User.find_by(id:)` | `Studio::ErrorHandling#current_user` | Standard ActiveRecord finder — automatic on any AR model. |
| `User.find_by(email:)` | `SessionsController#create` | Same. |

### Instance methods
| Name | Used by | Notes |
|------|---------|-------|
| `#authenticate(password)` | `SessionsController#create` | Provided by `has_secure_password`. Returns the user on success, falsy on failure. |
| `#admin?` | `require_admin`, several admin views | Boolean. Implement however your app wants (role enum, explicit column, etc.). |
| `#email` | `set_app_session`, SSO awareness | String. May be nil for wallet-only users — but then SSO is not available for them. |
| `#display_name` | `welcome_message` default proc, flash messages | String. Pure convenience helper — implement as `name.presence \|\| email.split('@').first`. |

### Class method — only if you enable Google OAuth
| Name | Used by | Notes |
|------|---------|-------|
| `User.from_omniauth(auth_hash)` | `OmniauthCallbacksController#create` | Should find-or-create by `(provider, uid)` and return the user. Wrap the find-or-create in `rescue ActiveRecord::RecordNotUnique` to handle concurrent OAuth callbacks for the same user. |

## Optional

The engine accesses these via `try:` or only inside config procs you write. They're soft contracts — implement them if your app exposes the concept, ignore them otherwise.

| Name | Used by | Notes |
|------|---------|-------|
| `#name` | `set_app_session` (via `try(:name)`) | If present, populates `session[:sso_name]`. |
| `#provider` | `set_app_session` | OAuth provider string (e.g. `"google"`). |
| `#uid` | `set_app_session` | OAuth provider UID. |
| `#wallet_address` | `set_app_session` (via `try(:wallet_address)`) | For wallet-auth apps (turf-monster). |
| `#role=` | `configure_sso_user` proc in host app | Only required if the host's `Studio.configure_sso_user` proc sets `user.role = ...`. |
| `#balance_cents=` | `configure_sso_user` proc | Same — only if the host proc uses it. |

## Recommended attributes (DB columns)

The engine doesn't care about DB shape directly, but in practice every consumer ships:
- `name:string`
- `email:string` (unique-indexed, nullable for wallet-only apps)
- `password_digest:string` (for `has_secure_password`)
- `provider:string`, `uid:string` (OmniAuth)
- `role:string` or `role:integer` (for `admin?`)
- `slug:string` (for `Sluggable`-friendly URLs)

## Example minimal compliant model

```ruby
class User < ApplicationRecord
  include Sluggable                  # from the engine
  has_secure_password validations: false
  has_many :error_logs, as: :target  # if you want to associate logged errors

  def admin?
    role == "admin"
  end

  def display_name
    name.presence || email&.split("@")&.first || "User"
  end

  def name_slug
    (name.presence || email.to_s.split("@").first).parameterize
  end

  def self.from_omniauth(auth)
    find_or_create_by(provider: auth["provider"], uid: auth["uid"]) do |user|
      user.email = auth.dig("info", "email")
      user.name  = auth.dig("info", "name")
    end
  rescue ActiveRecord::RecordNotUnique
    find_by(provider: auth["provider"], uid: auth["uid"])
  end
end
```

## Why this exists

Before 2026-05-17 (audit Tier 2 #16) the engine called these methods with no formal contract, so new apps onboarding to the engine would hit cryptic `NoMethodError` at runtime. The boot-time validator now catches missing methods early and points at this doc.

To temporarily skip the validator (e.g. during a migration that intentionally breaks the contract), set `Studio.validate_user_contract = false` in `config/initializers/studio.rb`.
