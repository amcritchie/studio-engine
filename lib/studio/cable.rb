# frozen_string_literal: true

require_relative "redis"

module Studio
  # Shared ActionCable / Turbo-Streams helpers for host apps.
  module Cable
    # Run a broadcast best-effort: a cable failure must NEVER break the caller (the
    # model save / task write that triggered it). ScriptError is caught ON PURPOSE —
    # a missing or misconfigured cable adapter raises Gem::LoadError, which is a
    # ScriptError, NOT a StandardError. A plain `rescue StandardError` let exactly
    # that escape an after_commit and 500 every task write in production (the SEV-1
    # this primitive exists to prevent). Failures are captured to ErrorLog when the
    # host defines it, else logged. Returns nil on failure.
    def self.safe_broadcast
      yield
    rescue StandardError, ScriptError => e
      if defined?(ErrorLog) && ErrorLog.respond_to?(:capture!)
        ErrorLog.capture!(e)
      elsif defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.warn("[studio-cable] broadcast failed (non-fatal): #{e.class}: #{e.message}")
      end
      nil
    end
  end
end
