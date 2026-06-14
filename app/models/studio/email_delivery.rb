module Studio
  class EmailDelivery < ApplicationRecord
    self.table_name = "studio_email_deliveries"

    belongs_to :user, optional: true

    scope :unsent, -> { where(sent: false) }
    scope :recent, -> { order(created_at: :desc) }

    def self.available?
      connection.data_source_exists?(table_name)
    rescue ActiveRecord::ActiveRecordError, NoMethodError
      false
    end

    def self.deliver(mailer, action, *args, to:, user: nil, **kwargs)
      record = create!(
        mailer: mailer.to_s,
        action: action.to_s,
        email_key: "#{mailer}##{action}",
        to: to.to_s,
        user: user,
        args: ActiveJob::Arguments.serialize(args),
        kwargs: ActiveJob::Arguments.serialize([kwargs]).first
      )
      Studio::EmailDeliveryJob.perform_later(record.id)
      record
    end

    def deliver_now!
      return if sent?

      pos = ActiveJob::Arguments.deserialize(args)
      kw = ActiveJob::Arguments.deserialize([kwargs]).first.symbolize_keys
      mailer.constantize.public_send(action, *pos, **kw).deliver_now
      update!(sent: true, sent_at: Time.current, error: nil)
    rescue StandardError => e
      update(error: e.message.to_s.first(500))
      raise
    end

    def self.resend_unsent!
      unsent.find_each { |delivery| Studio::EmailDeliveryJob.perform_later(delivery.id) }
    end
  end
end
