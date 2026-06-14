# frozen_string_literal: true

require_relative "../../test_helper"

class EmailTest < Minitest::Test
  def test_deliver_uses_app_level_email_delivery_when_present
    adapter = Class.new do
      class << self
        attr_reader :received

        def deliver(mailer, action, *args, to:, user: nil, **kwargs)
          @received = { mailer: mailer, action: action, args: args, to: to, user: user, kwargs: kwargs }
          :recorded
        end
      end
    end
    Object.const_set(:EmailDelivery, adapter)

    assert_equal :recorded, Studio::Email.deliver(FakeMailer, :magic_link, "a@example.com", "tok", to: "a@example.com", purpose: "test")
    assert_equal({ purpose: "test" }, adapter.received.fetch(:kwargs))
  ensure
    Object.send(:remove_const, :EmailDelivery) if Object.const_defined?(:EmailDelivery, false)
  end

  def test_deliver_uses_studio_delivery_when_table_is_available
    adapter = Class.new do
      class << self
        attr_reader :received

        def available?
          true
        end

        def deliver(mailer, action, *args, to:, user: nil, **kwargs)
          @received = { mailer: mailer, action: action, args: args, to: to, user: user, kwargs: kwargs }
          :studio_recorded
        end
      end
    end
    Studio.const_set(:EmailDelivery, adapter)

    assert_equal :studio_recorded, Studio::Email.deliver(FakeMailer, :magic_link, "a@example.com", "tok", to: "a@example.com")
    assert_equal :magic_link, adapter.received.fetch(:action)
  ensure
    Studio.send(:remove_const, :EmailDelivery) if Studio.const_defined?(:EmailDelivery, false)
  end

  def test_deliver_falls_back_to_action_mailer_delivery
    FakeMailer.reset

    assert_equal :queued, Studio::Email.deliver(FakeMailer, :magic_link, "a@example.com", "tok", to: "a@example.com")
    assert_equal [:magic_link, ["a@example.com", "tok"], {}], FakeMailer.received
  end

  class FakeMailer
    class << self
      attr_reader :received

      def magic_link(*args, **kwargs)
        @received = [:magic_link, args, kwargs]
        FakeMessageDelivery.new
      end

      def reset
        @received = nil
      end
    end
  end

  class FakeMessageDelivery
    def deliver_later
      :queued
    end
  end
end
