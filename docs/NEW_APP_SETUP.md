# New App Setup Guide

Step-by-step checklist for spinning up a new McRitchie app with the Studio engine.

Reference apps: Tax Studio (simplest), Turf Monster (full-featured with Solana).

---

## 1. Rails New

```bash
rails new x_app --database=postgresql
cd x_app
```

Pick the next available port (see port assignments in top-level CLAUDE.md):
- 3000 = McRitchie Studio
- 3001 = Turf Monster
- 3002 = Boodle Scraper
- 3003 = Tax Studio
- 3004 = next app

## 2. Gemfile

```ruby
# Studio engine
gem "studio-engine", git: "https://github.com/amcritchie/studio-engine.git"

# CSS
gem "tailwindcss-rails", "~> 2.7"

# Password hashing
gem "bcrypt", "~> 3.1.7"

# Environment variables
gem "dotenv-rails", groups: [:development, :test]

# Google OAuth
gem "omniauth"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection", "~> 1.0"
```

```bash
bundle install
bin/rails tailwindcss:install
```

## 3. Tailwind Config

Replace `config/tailwind.config.js`:

```js
const execSync = require('child_process').execSync
const studioPath = execSync('bundle show studio').toString().trim()

const studioColors = require(`${studioPath}/tailwind/studio.tailwind.config.js`)

const shades = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]
const utilities = ['bg', 'text', 'border']
const opacities = [5, 10, 20, 30, 40, 50]
const safelist = [
  ...utilities.map(util => `${util}-primary`),
  ...utilities.flatMap(util => opacities.map(op => `${util}-primary/${op}`)),
  ...shades.flatMap(shade =>
    utilities.map(util => `${util}-primary-${shade}`)
  ),
  ...shades.flatMap(shade =>
    utilities.flatMap(util => opacities.map(op => `${util}-primary-${shade}/${op}`))
  ),
]

module.exports = {
  darkMode: 'class',
  content: [
    './app/views/**/*.{erb,html}',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    `${studioPath}/app/views/**/*.{erb,html}`,
  ],
  safelist,
  theme: studioColors.theme,
}
```

## 4. Initializers

### `config/initializers/studio.rb`

```ruby
Studio.configure do |config|
  config.app_name = "X App"
  config.session_key = :x_app_user_id          # unique per app
  config.welcome_message = ->(user) { "Welcome to X App, #{user.display_name}!" }
  config.registration_params = [:name, :email, :password, :password_confirmation]
  config.configure_sso_user = ->(user) { user.role = "viewer" }
  config.theme_logos = [
    { file: "favicon.png", title: "Favicon" },
    { file: "logo.png",    title: "Navbar Logo" },
    { file: "logo.png",    title: "Auth Logo" },
  ]
  config.theme_primary = "#8E82FE"             # pick your brand color
end
```

### `config/initializers/session_store.rb`

```ruby
Rails.application.config.session_store :cookie_store,
  key: "_studio_session",
  domain: (Rails.env.production? ? ".mcritchie.studio" : :all)
```

**Critical**: Cookie key must be `_studio_session` and same `SECRET_KEY_BASE` across all apps for SSO.

### `config/initializers/omniauth.rb`

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

## 5. Database Migrations

### Users

```ruby
class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :password_digest
      t.string :provider
      t.string :uid
      t.string :role, default: "viewer"
      t.string :slug

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :slug, unique: true
    add_index :users, [:provider, :uid], unique: true
  end
end
```

### Error Logs

```ruby
class CreateErrorLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :error_logs do |t|
      t.string :slug
      t.text :message
      t.text :inspect
      t.text :backtrace
      t.string :target_type
      t.bigint :target_id
      t.string :target_name
      t.string :parent_type
      t.bigint :parent_id
      t.string :parent_name

      t.timestamps
    end

    add_index :error_logs, :slug, unique: true
  end
end
```

### Theme Settings

```ruby
class CreateThemeSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :theme_settings do |t|
      t.string :app_name
      t.string :primary
      t.string :dark
      t.string :light
      t.string :accent1
      t.string :accent2
      t.string :warning
      t.string :danger

      t.timestamps
    end

    add_index :theme_settings, :app_name, unique: true
  end
end
```

```bash
bin/rails db:create db:migrate
```

## 6. User Model

```ruby
class User < ApplicationRecord
  has_secure_password
  include Sluggable

  def name_slug
    name.present? ? name.parameterize : "user-#{id}"
  end

  def display_name
    name.presence || email&.split("@")&.first || "User"
  end

  def admin?
    role == "admin"
  end

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
end
```

## 7. Application Controller

```ruby
class ApplicationController < ActionController::Base
  include Studio::ErrorHandling
end
```

## 8. Routes

```ruby
Rails.application.routes.draw do
  Studio.routes(self)

  root "pages#index"

  # Admin: Navbar review (engine controller)
  get "admin/navbar", to: "navbar#show", as: :admin_navbar

  # App-specific routes here...
end
```

## 9. Layout

### `app/views/layouts/application.html.erb`

```erb
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "X App" %></title>
    <%= render "layouts/studio/head" %>
  </head>

  <body x-data class="bg-page text-body min-h-screen" :class="{ 'dev-mode': $store.devMode }">
    <%% unless Rails.env.production? %>
      <div style="background:#eab308; color:#000; font-size:12px; font-weight:700; padding:2px 12px; position:relative;">
        <%%= Rails.env.capitalize %> Environment
        <span style="position:absolute; right:8px; top:50%; transform:translateY(-50%);">
          <button @click="$store.devMode = !$store.devMode; localStorage.setItem('devMode', $store.devMode)"
                  class="rounded cursor-pointer"
                  style="font-size:10px; font-weight:700; padding:1px 6px;"
                  :style="$store.devMode ? 'background:rgba(0,0,0,0.4); color:#fff;' : 'background:rgba(0,0,0,0.2); color:#000;'">DEV MODE</button>
        </span>
      </div>
    <%% end %>
    <%= render "layouts/navbar" %>

    <div class="max-w-7xl mx-auto px-4 py-6">
      <%= render "layouts/studio/flash" %>
      <%= yield %>
    </div>
  </body>
</html>
```

**Dev banner**: Yellow bar hidden in production, shows environment name + DEV MODE toggle. Uses inline styles (not Tailwind classes) to avoid compilation issues across apps. The `devMode` Alpine store is initialized by the engine's `_head.html.erb`. The `dev-mode` body class can be used for dev-only UI toggles.

### `app/views/layouts/_navbar.html.erb`

Copy from the engine base and add your nav links to the desktop `<nav>` and mobile sub-navbar sections. See [NAVBAR_SETUP.md](NAVBAR_SETUP.md).

## 10. Public Assets

Place in `public/`:
- `favicon.png` — browser tab icon
- `logo.png` — navbar + auth page logo
- `studio-logo.svg` — copy from McRitchie Studio for SSO button branding

## 11. Seeds

```ruby
# db/seeds.rb
admin = User.find_or_create_by!(email: "alex@mcritchie.studio") do |u|
  u.name = "Alex McRitchie"
  u.password = "password"
  u.role = "admin"
end
puts "Seeded admin: #{admin.email}"
```

```bash
bin/rails db:seed
```

## 12. Google Cloud Console

Add redirect URI for your app's port:
```
http://localhost:{PORT}/auth/google_oauth2/callback
```

See [GOOGLE_AUTH_SETUP.md](GOOGLE_AUTH_SETUP.md) for full instructions.

## 13. CSS Component Classes

Add to `app/assets/stylesheets/application.tailwind.css`:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer components {
  .card { @apply bg-surface border border-subtle rounded-lg; }
  .card-hover { @apply card hover:border-strong transition; }
  .input-field { @apply w-full px-4 py-2.5 bg-inset border border-subtle rounded-lg text-body placeholder-muted focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition; }
  .empty-state { @apply text-center py-12 text-muted; }
  .label-upper { @apply block text-xs font-semibold text-secondary uppercase tracking-wider mb-1; }
  .json-debug { @apply mt-8 p-4 bg-inset border border-subtle rounded-lg text-xs font-mono text-muted overflow-x-auto whitespace-pre-wrap; }
}
```

Add button classes (`.btn`, `.btn-primary`, etc.) — copy from Tax Studio or Turf Monster's `application.tailwind.css`.

## 14. Hub Link (McRitchie Studio)

Add a nav link in McRitchie Studio pointing to your app's `/sso_login` for one-click SSO.

## 15. Verify

```bash
bin/rails server -p {PORT}
```

- [ ] Homepage loads with navbar, logo, brand title
- [ ] Dev banner shows yellow "Development Environment" bar with DEV MODE toggle
- [ ] Dark/light mode toggle works
- [ ] `/login` shows logo + SSO + email/password + Google
- [ ] `/signup` shows logo + form + Google
- [ ] Login with email/password works
- [ ] Google OAuth works (after adding redirect URI)
- [ ] `/admin/theme` loads (logged in as admin)
- [ ] `/admin/navbar` loads (admin preview page)
- [ ] `/error_logs` loads
- [ ] SSO from McRitchie Studio works

---

## Optional: Solana Integration

If the app needs Solana wallet auth and/or on-chain operations, add this on top of the base setup. Reference: Turf Monster (`docs/SOLANA.md`).

### Additional Gems

```ruby
gem "solana-studio", git: "https://github.com/amcritchie/solana-studio.git"
gem "ed25519"           # Signature verification
gem "sidekiq"           # Background jobs (ATA creation, balance sync)
```

### Additional User Columns

```ruby
add_column :users, :web2_solana_address, :string             # Managed wallet (server-signed)
add_column :users, :web3_solana_address, :string             # Phantom wallet (user-signed)
add_column :users, :encrypted_web2_solana_private_key, :text  # Encrypted keypair
add_column :users, :balance_cents, :integer, default: 0, null: false
add_column :users, :promotional_cents, :integer, default: 0, null: false
add_column :users, :level, :integer, default: 1, null: false
add_column :users, :username, :string
```

### Solana Initializer

```ruby
# config/initializers/solana.rb
require Rails.root.join("app/services/solana/keypair")
```

### Solana Routes

```ruby
# Place BEFORE Studio.routes to avoid wildcard conflict
get "auth/phantom/callback", to: "solana_sessions#phantom_callback"

Studio.routes(self)

# Solana wallet auth
get  "auth/solana/nonce",  to: "solana_sessions#nonce"
post "auth/solana/verify", to: "solana_sessions#verify"

# Wallet
resource :wallet, only: [:show] do
  post :deposit
  post :withdraw
  get  :sync
end
```

### Services to Copy

From `turf-monster/app/services/solana/`:
- `config.rb` — env var accessors
- `keypair.rb` — Rails extensions (admin keypair, encryption)
- `auth_verifier.rb` — Phantom signature verification
- `client.rb` — JSON-RPC wrapper

### JS Modules to Copy

From `turf-monster/app/javascript/`:
- `solana_utils.js` — Base58, balance refresh, shared utilities
- `phantom_deeplink.js` — Mobile Phantom deep linking

Pin in `config/importmap.rb` and import in `application.js`.

### Environment Variables

Add to `.env` (see [ENV_SETUP.md](ENV_SETUP.md)):
```env
SOLANA_ADMIN_KEY=base58-encoded-keypair
SOLANA_RPC_URL=https://api.devnet.solana.com
```

### Wallet Types

| Type | Column | Who Signs | Use Case |
|------|--------|-----------|----------|
| Managed | `web2_solana_address` | Server (keypair in DB) | Users who don't have Phantom |
| Phantom | `web3_solana_address` | User's browser extension | Web3 native users |

### Key Concepts

- **Nonce-based auth**: Server generates nonce → client signs with Phantom → server verifies Ed25519 signature
- **Managed wallets**: Server generates keypair on user creation, encrypts private key with `Rails.master_key`
- **Balance**: `balance_cents` (real, withdrawable) + `promotional_cents` (bonus, used first)
- **Seeds/Level**: On-chain progression system, 60 seeds per entry

See `turf-monster/docs/SOLANA.md` and `turf-monster/docs/AUTH.md` for full architecture.
