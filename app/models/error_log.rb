class ErrorLog < ApplicationRecord
  belongs_to :target, polymorphic: true, optional: true
  belongs_to :parent, polymorphic: true, optional: true

  def to_param
    slug
  end

  def inspect_field
    read_attribute(:inspect)
  end

  def self.capture!(exception)
    cleaned = Rails.backtrace_cleaner.clean(exception.backtrace || [])

    log = create!(
      message: exception.message,
      inspect: exception.inspect,
      backtrace: cleaned.to_json
    )
    log.update_column(:slug, "error-log-#{log.id}")

    # Fan out to Sentry if the host app loaded sentry-ruby. Guard with
    # respond_to? so we don't blow up on old SDK versions. The DB ErrorLog
    # row remains the local triage view; Sentry is the paging layer.
    if defined?(::Sentry) && ::Sentry.respond_to?(:capture_exception)
      begin
        ::Sentry.capture_exception(exception) do |scope|
          scope.set_tags(error_log_slug: log.slug)
        end
      rescue => e
        Rails.logger.warn "[ErrorLog.capture!] Sentry delivery failed: #{e.class}: #{e.message}"
      end
    end

    log
  end
end
