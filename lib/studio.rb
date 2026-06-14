require "studio/version"
require "studio/engine"
require "studio/color_scale"
require "studio/theme_resolver"
require "studio/username_generator"
require "studio/s3"
require "studio/image_cache"
require "studio/email"
require "studio/mail_transport"

module Studio
  mattr_accessor :app_name,            default: "Studio"
  mattr_accessor :session_key,         default: :user_id
  mattr_accessor :welcome_message,     default: ->(user) { "Welcome, #{user.display_name}!" }
  mattr_accessor :registration_params, default: [:name, :email, :password, :password_confirmation]
  mattr_accessor :configure_new_user,  default: ->(user) {}
  mattr_accessor :configure_sso_user,  default: ->(user) {}
  mattr_accessor :sso_logo,            default: nil
  mattr_accessor :wallet_address_method, default: nil
  mattr_accessor :theme_logos,         default: []

  # ---- Authentication ------------------------------------------------------
  # Which sign-in methods this app offers. The shared login/signup views render
  # a button/field per enabled method (gate with Studio.auth_method?). Order is
  # display order. Both McRitchie Studio + Turf Monster are passwordless; legacy
  # email+password is opt-in via :password (which also re-arms the User#authenticate
  # contract check — see validate_user_contract!).
  mattr_accessor :auth_methods, default: %i[magic_link google wallet]

  # Magic-link (passwordless email) tuning. token_name keys the MessageVerifier
  # purpose; bump it to invalidate every outstanding link. See MagicLink service.
  mattr_accessor :magic_link_ttl,        default: 15.minutes
  mattr_accessor :magic_link_token_name, default: "magic_link_v1"

  # Whether Studio.routes draws the magic_link + solana wallet routes. An app that
  # already defines its own auth routes (e.g. turf-monster, which has battle-tested
  # magic_link/solana routes + extras) sets this false to avoid duplicate route
  # NAMES at boot, keeping its own routes intact. New consumers leave it true.
  mattr_accessor :draw_auth_routes, default: true

  # Default From: for engine-sent mail (magic links). Apps set this to their
  # verified sending address in config/initializers/studio.rb.
  mattr_accessor :mailer_from, default: nil

  # Local/worktree email capture. nil means "auto": enabled when AGENT_WORKTREE
  # is truthy, otherwise disabled. Production always disables capture.
  mattr_accessor :local_email_capture, default: nil

  # Theme role colors (7 roles)
  mattr_accessor :theme_primary,  default: "#8E82FE"
  mattr_accessor :theme_dark,     default: "#1A1535"
  mattr_accessor :theme_light,    default: "#f8fafc"
  mattr_accessor :theme_success,  default: "#4BAF50"
  mattr_accessor :theme_warning,  default: "#FF7C47"
  mattr_accessor :theme_danger,   default: "#EF4444"
  mattr_accessor :theme_accent,   default: "#F72585"

  # S3 / object storage — host apps MUST set s3_bucket_prefix explicitly in
  # config/initializers/studio.rb before any S3-touching code runs (ImageCache,
  # Studio::S3.upload, etc.). Default is nil so external users don't accidentally
  # target someone else's bucket if they forget to configure.
  #
  # Bucket name resolves to "#{s3_bucket_prefix}-#{Rails.env.production? ? 'production' : 'dev'}".
  mattr_accessor :s3_bucket_prefix, default: nil
  mattr_accessor :s3_region,        default: "us-east-2"

  class S3ConfigError < StandardError; end

  # Whether to validate the host app's User model at boot. See docs/USER_CONTRACT.md.
  # Set to false in config/initializers/studio.rb to bypass (e.g. during migrations
  # that intentionally break the contract).
  mattr_accessor :validate_user_contract, default: true

  # Only methods that consumers must explicitly define are checked here.
  # Column accessors (#email, #name, #role) are NOT validated because
  # ActiveRecord defines them lazily — they don't appear on `.instance_methods`
  # until the schema is introspected (typically first record access). Missing
  # columns are caught by the User table schema, not by this validator.
  REQUIRED_USER_INSTANCE_METHODS = %i[admin? display_name].freeze
  REQUIRED_USER_CLASS_METHODS    = %i[find_by].freeze
  # #authenticate is only required when email+password sign-in is enabled.
  # Passwordless apps (the default) never call it.
  PASSWORD_USER_INSTANCE_METHODS = %i[authenticate].freeze

  class UserContractError < StandardError; end

  def self.configure
    yield self
  end

  # True when the given sign-in method is enabled for this app.
  def self.auth_method?(method)
    auth_methods.include?(method.to_sym)
  end

  def self.local_email_capture?
    return false if defined?(Rails) && Rails.respond_to?(:env) && Rails.env.production?
    return !!local_email_capture unless local_email_capture.nil?

    env_truthy?(ENV["LOCAL_EMAIL_CAPTURE"]) || env_truthy?(ENV["AGENT_WORKTREE"])
  end

  def self.user_wallet_address(user)
    return nil unless user

    [wallet_address_method, :wallet_address, :solana_address].compact.each do |method|
      next unless user.respond_to?(method)

      value = user.public_send(method)
      return value if value && !(value.respond_to?(:empty?) && value.empty?)
    end

    nil
  end

  # Verifies that the host app's User model satisfies the engine's expected
  # contract. Raises Studio::UserContractError with a clear pointer to
  # docs/USER_CONTRACT.md if anything required is missing. Called from
  # Engine#after_initialize. Opt out via Studio.validate_user_contract = false.
  def self.validate_user_contract!(user_class)
    return unless validate_user_contract
    return unless user_class.is_a?(Class)

    missing = []
    REQUIRED_USER_CLASS_METHODS.each do |m|
      missing << "User.#{m}" unless user_class.respond_to?(m)
    end
    instance_methods = REQUIRED_USER_INSTANCE_METHODS.dup
    instance_methods.concat(PASSWORD_USER_INSTANCE_METHODS) if auth_method?(:password)
    instance_methods.each do |m|
      missing << "User##{m}" unless user_class.instance_methods.include?(m)
    end

    return if missing.empty?

    raise UserContractError, <<~MSG
      The studio-engine gem's expected User model contract is not satisfied.

      Missing: #{missing.join(", ")}

      See the USER_CONTRACT.md doc in the studio-engine repo for the full
      contract + a minimal compliant example:
        https://github.com/amcritchie/studio-engine/blob/main/docs/USER_CONTRACT.md

      To bypass this check temporarily, set Studio.validate_user_contract = false
      in config/initializers/studio.rb.
    MSG
  end

  def self.theme_config
    {
      primary: theme_primary,
      dark:    theme_dark,
      light:   theme_light,
      success: theme_success,
      warning: theme_warning,
      danger:  theme_danger,
      accent:  theme_accent
    }.compact
  end

  # Find a logo from theme_logos by title, with fallback chain:
  # 1. Exact title match
  # 2. "Navbar Logo" fallback
  # 3. First logo in the list
  def self.logo_for(title)
    logos = theme_logos.map { |l| l.is_a?(Hash) ? l : { file: l, title: l } }
    entry = logos.find { |l| l[:title] == title }
    entry ||= logos.find { |l| l[:title] == "Navbar Logo" }
    entry ||= logos.first
    entry ? "/#{entry[:file]}" : nil
  end

  def self.env_truthy?(value)
    %w[1 true yes on].include?(value.to_s.strip.downcase)
  end

  def self.routes(router)
    router.instance_exec do
      get  "login",  to: "sessions#new"
      post "login",  to: "sessions#create"
      post "sso_continue", to: "sessions#sso_continue"
      get  "sso_login",    to: "sessions#sso_login"
      get  "logout", to: "sessions#destroy"
      get  "signup", to: "registrations#new"
      post "signup", to: "registrations#create"
      get  "auth/:provider/callback", to: "omniauth_callbacks#create"
      get  "auth/failure", to: "omniauth_callbacks#failure"

      unless defined?(Rails) && Rails.env.production?
        get "_studio/local_emails", to: "studio/local_emails#index", as: :studio_local_emails
      end

      # Passwordless email (magic link). Helpers: magic_link_request_path (POST
      # to request a link), magic_link_path(token) / magic_link_url(token:)
      # for the emailed GET confirmation page, and magic_link_consume_path(token)
      # for the scanner-safe POST consume. The token is a URL-safe
      # MessageVerifier blob but the constraint guards against a stray "."
      # segment.
      if Studio.draw_auth_routes && Studio.auth_method?(:magic_link)
        post "magic_link",        to: "magic_links#create",   as: :magic_link_request
        get  "magic_link/:token", to: "magic_links#confirm",  as: :magic_link,
             constraints: { token: %r{[^/]+} }
        post "magic_link/:token", to: "magic_links#consume",  as: :magic_link_consume,
             constraints: { token: %r{[^/]+} }
      end

      # Solana / Phantom wallet sign-in (nonce challenge + signature verify).
      # The browser posts to these literal paths from the shared Connect-Wallet
      # flow; app-specific surfaces (mobile deep-link callback, account-linking,
      # OAuth popup) stay in the consuming app's routes.
      if Studio.draw_auth_routes && Studio.auth_method?(:wallet)
        get  "auth/solana/nonce",  to: "solana_sessions#nonce",  as: :solana_nonce
        post "auth/solana/verify", to: "solana_sessions#verify", as: :solana_verify
      end

      resources :error_logs, only: [:index, :show]

      # Admin
      get   "admin/theme",            to: "theme_settings#edit",       as: :admin_theme
      patch "admin/theme",            to: "theme_settings#update",     as: :admin_theme_update
      post  "admin/theme/regenerate", to: "theme_settings#regenerate", as: :admin_theme_regenerate
      get   "admin/schema",           to: "schema#index",              as: :admin_schema
    end
  end
end
