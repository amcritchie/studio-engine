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
    #
    # The never-raise guarantee is ABSOLUTE: even logging the failure must not break
    # the caller. ErrorLog.capture! writes to the DB and can itself raise (e.g.
    # ActiveRecord::NoDatabaseError when the DB is down), so the logging is wrapped
    # in its own rescue — the guard cannot be defeated by its own error path.
    def self.safe_broadcast
      yield
    rescue StandardError, ScriptError => e
      begin
        if defined?(ErrorLog) && ErrorLog.respond_to?(:capture!)
          ErrorLog.capture!(e)
        elsif defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.warn("[studio-cable] broadcast failed (non-fatal): #{e.class}: #{e.message}")
        end
      rescue StandardError, ScriptError
        nil # logging is best-effort too — the never-raise guarantee is absolute
      end
      nil
    end
  end
end
