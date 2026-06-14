module Studio
  class EmailDeliveryJob < (defined?(::ApplicationJob) ? ::ApplicationJob : ActiveJob::Base)
    queue_as :mailers

    def perform(id)
      Studio::EmailDelivery.find_by(id: id)&.deliver_now!
    end
  end
end
