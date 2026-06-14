# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../lib/studio/mail_transport"

class MailTransportTest < Minitest::Test
  FakeMailer = Struct.new(:delivery_method, :smtp_settings)

  def test_configures_ses_when_selected_and_credentials_present
    mailer = FakeMailer.new(:smtp, {})
    env = {
      "MAIL_TRANSPORT" => "ses",
      "SES_REGION" => "us-east-2",
      "SES_SMTP_USERNAME" => "user",
      "SES_SMTP_PASSWORD" => "pass"
    }

    result = Studio::MailTransport.configure!(env: env, rails_env: "development", action_mailer: mailer, logger: nil)

    assert_equal :ses, result.transport
    assert_equal :smtp, mailer.delivery_method
    assert_equal "email-smtp.us-east-2.amazonaws.com", mailer.smtp_settings.fetch(:address)
    assert_equal "user", mailer.smtp_settings.fetch(:user_name)
  end

  def test_uses_resend_when_api_key_present_and_ses_not_ready
    mailer = FakeMailer.new(:smtp, {})
    configured_key = nil
    loaded = false

    result = Studio::MailTransport.configure!(
      env: { "RESEND_API_KEY" => "rk_test" },
      rails_env: "development",
      action_mailer: mailer,
      logger: nil,
      resend_loader: -> { loaded = true },
      resend_configurer: ->(key) { configured_key = key }
    )

    assert_equal :resend, result.transport
    assert_equal :resend, mailer.delivery_method
    assert_equal "rk_test", configured_key
    assert loaded
  end

  def test_test_environment_does_not_change_delivery_method
    mailer = FakeMailer.new(:test, {})

    result = Studio::MailTransport.configure!(
      env: {
        "MAIL_TRANSPORT" => "ses",
        "SES_SMTP_USERNAME" => "user",
        "SES_SMTP_PASSWORD" => "pass"
      },
      rails_env: "test",
      action_mailer: mailer,
      logger: nil
    )

    assert_equal :test, result.transport
    assert_equal :test, mailer.delivery_method
    assert_equal({}, mailer.smtp_settings)
  end

  def test_default_when_no_transport_configured
    mailer = FakeMailer.new(:smtp, {})

    result = Studio::MailTransport.configure!(env: {}, rails_env: "development", action_mailer: mailer, logger: nil)

    assert_equal :default, result.transport
    assert_equal :smtp, mailer.delivery_method
  end
end
