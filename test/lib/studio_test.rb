# frozen_string_literal: true

require_relative "../test_helper"

class StudioTest < Minitest::Test
  def setup
    # Reset all config to defaults before each test
    Studio.app_name            = "Studio"
    Studio.session_key         = :user_id
    Studio.registration_params = [:name, :email, :password, :password_confirmation]
    Studio.sso_logo            = nil
    Studio.theme_logos         = []
    Studio.theme_primary       = "#8E82FE"
    Studio.theme_dark          = "#1A1535"
    Studio.theme_light         = "#f8fafc"
    Studio.theme_success       = "#4BAF50"
    Studio.theme_warning       = "#FF7C47"
    Studio.theme_danger        = "#EF4444"
    Studio.theme_accent        = "#F72585"
    Studio.local_email_capture = nil
    ENV.delete("LOCAL_EMAIL_CAPTURE")
    ENV.delete("AGENT_WORKTREE")
  end

  # ── configure ───────────────────────────────────────────────

  def test_configure_yields_studio_module
    yielded = nil
    Studio.configure { |config| yielded = config }
    assert_equal Studio, yielded
  end

  def test_configure_sets_app_name
    Studio.configure { |config| config.app_name = "Turf Monster" }
    assert_equal "Turf Monster", Studio.app_name
  end

  def test_configure_sets_session_key
    Studio.configure { |config| config.session_key = :turf_user_id }
    assert_equal :turf_user_id, Studio.session_key
  end

  def test_configure_sets_theme_primary
    Studio.configure { |config| config.theme_primary = "#4BAF50" }
    assert_equal "#4BAF50", Studio.theme_primary
  end

  def test_configure_sets_sso_logo
    Studio.configure { |config| config.sso_logo = "/studio-logo.svg" }
    assert_equal "/studio-logo.svg", Studio.sso_logo
  end

  def test_configure_sets_theme_logos
    logos = [{ file: "favicon.png", title: "Favicon" }]
    Studio.configure { |config| config.theme_logos = logos }
    assert_equal logos, Studio.theme_logos
  end

  # ── default values ──────────────────────────────────────────

  def test_default_app_name
    assert_equal "Studio", Studio.app_name
  end

  def test_default_session_key
    assert_equal :user_id, Studio.session_key
  end

  def test_default_registration_params
    assert_equal [:name, :email, :password, :password_confirmation], Studio.registration_params
  end

  def test_default_sso_logo
    assert_nil Studio.sso_logo
  end

  def test_default_theme_logos
    assert_equal [], Studio.theme_logos
  end

  def test_default_theme_primary
    assert_equal "#8E82FE", Studio.theme_primary
  end

  def test_default_theme_dark
    assert_equal "#1A1535", Studio.theme_dark
  end

  def test_default_theme_light
    assert_equal "#f8fafc", Studio.theme_light
  end

  def test_default_theme_success
    assert_equal "#4BAF50", Studio.theme_success
  end

  def test_default_theme_warning
    assert_equal "#FF7C47", Studio.theme_warning
  end

  def test_default_theme_danger
    assert_equal "#EF4444", Studio.theme_danger
  end

  def test_default_theme_accent
    assert_equal "#F72585", Studio.theme_accent
  end

  def test_default_welcome_message_is_callable
    assert_respond_to Studio.welcome_message, :call
  end

  def test_default_configure_new_user_is_callable
    assert_respond_to Studio.configure_new_user, :call
  end

  def test_default_configure_sso_user_is_callable
    assert_respond_to Studio.configure_sso_user, :call
  end

  def test_local_email_capture_defaults_off
    refute Studio.local_email_capture?
  end

  def test_local_email_capture_turns_on_for_agent_worktree
    ENV["AGENT_WORKTREE"] = "1"
    assert Studio.local_email_capture?
  ensure
    ENV.delete("AGENT_WORKTREE")
  end

  def test_local_email_capture_env_overrides_auto
    ENV["LOCAL_EMAIL_CAPTURE"] = "true"
    assert Studio.local_email_capture?
  ensure
    ENV.delete("LOCAL_EMAIL_CAPTURE")
  end

  def test_local_email_capture_config_override_wins
    ENV["AGENT_WORKTREE"] = "1"
    Studio.local_email_capture = false
    refute Studio.local_email_capture?
  ensure
    ENV.delete("AGENT_WORKTREE")
    Studio.local_email_capture = nil
  end

  # ── theme_config ────────────────────────────────────────────

  def test_theme_config_returns_hash
    config = Studio.theme_config
    assert_kind_of Hash, config
  end

  def test_theme_config_has_all_role_keys
    config = Studio.theme_config
    %i[primary dark light success warning danger accent].each do |role|
      assert config.key?(role), "Missing role key: #{role}"
    end
  end

  def test_theme_config_returns_current_values
    config = Studio.theme_config
    assert_equal "#8E82FE", config[:primary]
    assert_equal "#1A1535", config[:dark]
    assert_equal "#f8fafc", config[:light]
    assert_equal "#4BAF50", config[:success]
    assert_equal "#FF7C47", config[:warning]
    assert_equal "#EF4444", config[:danger]
    assert_equal "#F72585", config[:accent]
  end

  def test_theme_config_reflects_configure_changes
    Studio.configure do |config|
      config.theme_primary = "#4BAF50"
      config.theme_accent  = "#8E82FE"
    end
    result = Studio.theme_config
    assert_equal "#4BAF50", result[:primary]
    assert_equal "#8E82FE", result[:accent]
  end

  def test_theme_config_compacts_nil_values
    Studio.theme_accent = nil
    config = Studio.theme_config
    refute config.key?(:accent), "nil accent should be compacted out"
  end

  def test_theme_config_keeps_non_nil_values
    Studio.theme_accent = "#F72585"
    config = Studio.theme_config
    assert_equal "#F72585", config[:accent]
  end

  # ── version ─────────────────────────────────────────────────

  def test_version_is_defined
    assert_kind_of String, Studio::VERSION
    refute Studio::VERSION.empty?
  end

  def test_version_format
    assert_match(/\A\d+\.\d+\.\d+\z/, Studio::VERSION, "Version should be semver format")
  end
end
