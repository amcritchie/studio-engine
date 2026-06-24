# frozen_string_literal: true

require "openssl"

module Studio
  # Single source of Redis connection truth for EVERY Redis client in a host app —
  # ActionCable (config/cable.yml), the Rails cache_store, and Sidekiq. It bakes in
  # the Heroku gotcha so no app re-hits it:
  #
  #   Heroku Redis serves rediss:// (TLS) with a SELF-SIGNED cert. redis-client
  #   verifies peer certs by default, so the connection is silently REJECTED — and
  #   because ActionCable's pubsub failure is silent (the /cable socket still
  #   upgrades to 101), broadcasts simply never reach subscribers; the cache no-ops.
  #   The fix is ssl_params verify_mode VERIFY_NONE, applied automatically here for
  #   any rediss:// URL.
  #
  # Usage:
  #   cable.yml   ->  Studio::Redis.options                     (url + ssl_params)
  #   cache_store ->  Studio::Redis.options(namespace: "x", expires_in: 90.minutes)
  #   sidekiq     ->  Studio::Redis.options
  module Redis
    # The Redis URL from the environment, with a local-dev fallback.
    def self.url(default = "redis://localhost:6379/1")
      ENV.fetch("REDIS_URL", default)
    end

    # True when the endpoint is TLS (Heroku Redis), i.e. a rediss:// URL.
    def self.tls?(redis_url = url)
      redis_url.to_s.start_with?("rediss://")
    end

    # Connection options for a Redis client: the url, plus — for a TLS endpoint —
    # the self-signed-cert handling Heroku requires. Caller extras (namespace,
    # reconnect_attempts, error_handler, …) merge through untouched.
    def self.options(redis_url: url, **extra)
      opts = { url: redis_url }.merge(extra)
      opts[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE } if tls?(redis_url)
      opts
    end
  end
end
