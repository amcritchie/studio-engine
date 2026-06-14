# frozen_string_literal: true

module Studio
  module Email
    class << self
      # Shared email send entry point for Studio apps.
      #
      # Apps with an existing top-level EmailDelivery model keep using it through
      # this facade. Apps that have installed the engine outbox migration use the
      # namespaced Studio::EmailDelivery model. Apps without either still send via
      # ActionMailer's normal deliver_later path.
      def deliver(mailer, action, *args, to:, user: nil, **kwargs)
        if (adapter = app_delivery_adapter)
          return adapter.deliver(mailer, action, *args, to: to, user: user, **kwargs)
        end

        if (adapter = studio_delivery_adapter)
          return adapter.deliver(mailer, action, *args, to: to, user: user, **kwargs)
        end

        mailer.public_send(action, *args, **kwargs).deliver_later
      end

      private

      def app_delivery_adapter
        return unless Object.const_defined?(:EmailDelivery, false)

        adapter = Object.const_get(:EmailDelivery, false)
        adapter if adapter.respond_to?(:deliver)
      rescue NameError
        nil
      end

      def studio_delivery_adapter
        return unless Studio.const_defined?(:EmailDelivery, false)

        adapter = Studio.const_get(:EmailDelivery, false)
        adapter if adapter.respond_to?(:available?) && adapter.available?
      rescue NameError
        nil
      end
    end
  end
end
