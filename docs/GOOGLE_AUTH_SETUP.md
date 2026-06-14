# Google OAuth Setup

How to add Google sign-in to a new McRitchie app.

## Prerequisites

- A Google Cloud project with OAuth 2.0 credentials
- The shared `/Users/alex/projects/.env` file (already has `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`)

## Shared Credentials

All local apps share one `.env` file at the project root (`/Users/alex/projects/.env`):

```env
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your-secret
```

Apps load this via `dotenv-rails` in development/test. In production (Heroku), set these as config vars.

## Steps for a New App

### 1. Add gems to Gemfile

```ruby
# Google OAuth
gem "omniauth"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection", "~> 1.0"

# Environment variables (if not already present)
gem "dotenv-rails", groups: [:development, :test]
```

Run `bundle install`.

### 2. Create OmniAuth initializer

Create `config/initializers/omniauth.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV["GOOGLE_CLIENT_ID"],
    ENV["GOOGLE_CLIENT_SECRET"],
    scope: "email,profile",
    prompt: "select_account"
end

OmniAuth.config.allowed_request_methods = [:post, :get]
```

### 3. Add `from_omniauth` to User model

```ruby
def self.from_omniauth(auth)
  user = find_by(provider: auth.provider, uid: auth.uid)
  return user if user

  user = find_by(email: auth.info.email)
  if user
    user.update!(provider: auth.provider, uid: auth.uid)
    return user
  end

  create!(
    email: auth.info.email,
    name: auth.info.name,
    provider: auth.provider,
    uid: auth.uid,
    password: SecureRandom.hex(16)
  )
rescue ActiveRecord::RecordNotUnique
  find_by(email: auth.info.email) || find_by(provider: auth.provider, uid: auth.uid)
end
```

### 4. Ensure User model has provider/uid columns

```ruby
# Migration
add_column :users, :provider, :string
add_column :users, :uid, :string
```

### 5. Add redirect URI in Google Cloud Console

Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → your OAuth 2.0 Client ID → Authorized redirect URIs.

Add the callback URL for your new app:

| Environment | URI |
|------------|-----|
| Development | `http://localhost:{PORT}/auth/google_oauth2/callback` |
| Production | `https://{subdomain}.mcritchie.studio/auth/google_oauth2/callback` |

**Current apps:**

| App | Port | Dev URI | Prod URI |
|-----|------|---------|----------|
| McRitchie Studio | 3000 | `http://localhost:3000/auth/google_oauth2/callback` | `https://app.mcritchie.studio/auth/google_oauth2/callback` |
| Turf Monster | 3100 | `http://localhost:3100/auth/google_oauth2/callback` | `https://app.turfmonster.media/auth/google_oauth2/callback` |
| Tax Studio | 3003 | `http://localhost:3003/auth/google_oauth2/callback` | `https://tax.mcritchie.studio/auth/google_oauth2/callback` |

### 6. Routes (already handled)

`Studio.routes(self)` draws the OAuth callback route automatically:

```ruby
get "auth/:provider/callback", to: "omniauth_callbacks#create"
get "auth/failure", to: "omniauth_callbacks#failure"
```

The engine's `OmniauthCallbacksController` handles the callback. Override it locally if you need custom logic (e.g. Turf Monster's account merge flow).

### 7. Restart the server

OmniAuth middleware is loaded at boot — restart required after adding the initializer.

## Production (Heroku)

```bash
heroku config:set GOOGLE_CLIENT_ID=your-client-id --app your-app
heroku config:set GOOGLE_CLIENT_SECRET=your-secret --app your-app
```

## Troubleshooting

- **"No route matches [POST] /auth/google_oauth2"** — missing OmniAuth gems or initializer. Run `bundle install` and restart.
- **"redirect_uri_mismatch"** — the callback URI isn't registered in Google Cloud Console. Add it (see step 5).
- **Credentials not loading** — ensure `dotenv-rails` is in Gemfile and `.env` file is at `/Users/alex/projects/.env`.
