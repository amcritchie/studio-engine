module StudioEmailDeliveryHelper
  NON_DELIVERING_EMAIL_METHODS = %w[test file].freeze

  def email_delivery_banner_status
    delivery_method = studio_email_delivery_method
    capture_enabled = Studio.local_email_capture?
    sends_email = studio_email_perform_deliveries? && !capture_enabled &&
                  !NON_DELIVERING_EMAIL_METHODS.include?(delivery_method)

    "EMAIL SEND #{sends_email} · #{email_delivery_transport_label(delivery_method, capture_enabled)}"
  end

  def email_delivery_transport_label(delivery_method = studio_email_delivery_method,
                                     capture_enabled = Studio.local_email_capture?)
    return "capture" if capture_enabled
    return "ses" if Studio.ses_transport_ready?
    return "resend" if delivery_method == "resend"

    delivery_method.to_s.strip.empty? ? "unknown" : delivery_method
  end

  private

  def studio_email_delivery_method
    return "unknown" unless defined?(ActionMailer)

    ActionMailer::Base.delivery_method.to_s
  end

  def studio_email_perform_deliveries?
    return false unless defined?(ActionMailer)

    ActionMailer::Base.perform_deliveries
  end
end
