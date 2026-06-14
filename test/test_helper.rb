# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"

# Load ActiveSupport for mattr_accessor, symbolize_keys, etc.
require "active_support"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/hash/keys"

# Load the Studio module and pure-Ruby lib classes.
# We skip requiring "studio/engine" since that needs a full Rails app.
require_relative "../lib/studio/version"
require_relative "../lib/studio/color_scale"
require_relative "../lib/studio/theme_resolver"
require_relative "../lib/studio/email"

# Define Studio module attributes without requiring the engine.
# This mirrors lib/studio.rb but avoids the Rails engine dependency.
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

  mattr_accessor :theme_primary,  default: "#8E82FE"
  mattr_accessor :theme_dark,     default: "#1A1535"
  mattr_accessor :theme_light,    default: "#f8fafc"
  mattr_accessor :theme_success,  default: "#4BAF50"
  mattr_accessor :theme_warning,  default: "#FF7C47"
  mattr_accessor :theme_danger,   default: "#EF4444"
  mattr_accessor :theme_accent,   default: "#F72585"
  mattr_accessor :local_email_capture, default: nil

  def self.configure
    yield self
  end

  def self.local_email_capture?
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

  def self.env_truthy?(value)
    %w[1 true yes on].include?(value.to_s.strip.downcase)
  end
end
