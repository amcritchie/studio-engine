require "studio/version"
require "studio/engine"
require "studio/color_scale"
require "studio/theme_resolver"
require "studio/username_generator"
require "studio/s3"
require "studio/image_cache"

module Studio
  mattr_accessor :app_name,            default: "Studio"
  mattr_accessor :session_key,         default: :user_id
  mattr_accessor :welcome_message,     default: ->(user) { "Welcome, #{user.display_name}!" }
  mattr_accessor :registration_params, default: [:name, :email, :password, :password_confirmation]
  mattr_accessor :configure_new_user,  default: ->(user) {}
  mattr_accessor :configure_sso_user,  default: ->(user) {}
  mattr_accessor :sso_logo,            default: nil
  mattr_accessor :theme_logos,         default: []

  # Theme role colors (7 roles)
  mattr_accessor :theme_primary,  default: "#8E82FE"
  mattr_accessor :theme_dark,     default: "#1A1535"
  mattr_accessor :theme_light,    default: "#f8fafc"
  mattr_accessor :theme_success,  default: "#4BAF50"
  mattr_accessor :theme_warning,  default: "#FF7C47"
  mattr_accessor :theme_danger,   default: "#EF4444"
  mattr_accessor :theme_accent,   default: "#F72585"

  # S3 / object storage — default bucket prefix is the shared "mcritchie-studio"
  # bucket. Apps with their own bucket override this in config/initializers/studio.rb.
  mattr_accessor :s3_bucket_prefix, default: "mcritchie-studio"
  mattr_accessor :s3_region,        default: "us-east-2"

  # Whether to validate the host app's User model at boot. See docs/USER_CONTRACT.md.
  # Set to false in config/initializers/studio.rb to bypass (e.g. during migrations
  # that intentionally break the contract).
  mattr_accessor :validate_user_contract, default: true

  # Only methods that consumers must explicitly define are checked here.
  # Column accessors (#email, #name, #role) are NOT validated because
  # ActiveRecord defines them lazily — they don't appear on `.instance_methods`
  # until the schema is introspected (typically first record access). Missing
  # columns are caught by the User table schema, not by this validator.
  REQUIRED_USER_INSTANCE_METHODS = %i[authenticate admin? display_name].freeze
  REQUIRED_USER_CLASS_METHODS    = %i[find_by].freeze

  class UserContractError < StandardError; end

  def self.configure
    yield self
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
    REQUIRED_USER_INSTANCE_METHODS.each do |m|
      missing << "User##{m}" unless user_class.instance_methods.include?(m)
    end

    return if missing.empty?

    raise UserContractError, <<~MSG
      The Studio engine's expected User model contract is not satisfied.

      Missing: #{missing.join(", ")}

      See https://github.com/amcritchie/studio/blob/main/docs/USER_CONTRACT.md
      for the full contract + a minimal compliant example.

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
      resources :error_logs, only: [:index, :show]

      # Admin
      get   "admin/theme",            to: "theme_settings#edit",       as: :admin_theme
      patch "admin/theme",            to: "theme_settings#update",     as: :admin_theme_update
      post  "admin/theme/regenerate", to: "theme_settings#regenerate", as: :admin_theme_regenerate
      get   "admin/schema",           to: "schema#index",              as: :admin_schema
    end
  end
end
