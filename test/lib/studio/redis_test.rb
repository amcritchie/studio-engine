# frozen_string_literal: true

require_relative "../../test_helper"

class Studio::RedisTest < Minitest::Test
  def with_redis_url(value)
    prev = ENV["REDIS_URL"]
    value.nil? ? ENV.delete("REDIS_URL") : ENV["REDIS_URL"] = value
    yield
  ensure
    prev.nil? ? ENV.delete("REDIS_URL") : ENV["REDIS_URL"] = prev
  end

  def test_url_falls_back_when_env_unset
    with_redis_url(nil) { assert_equal "redis://localhost:6379/1", Studio::Redis.url }
  end

  def test_url_reads_env
    with_redis_url("redis://example:6379/2") { assert_equal "redis://example:6379/2", Studio::Redis.url }
  end

  def test_tls_predicate
    refute Studio::Redis.tls?("redis://x")
    assert Studio::Redis.tls?("rediss://x")
  end

  def test_options_plain_redis_has_no_ssl_params
    opts = Studio::Redis.options(redis_url: "redis://x:6379/0")
    assert_equal "redis://x:6379/0", opts[:url]
    refute opts.key?(:ssl_params), "plain redis:// must not skip cert verification"
  end

  def test_options_tls_redis_skips_cert_verification
    opts = Studio::Redis.options(redis_url: "rediss://x:6379/0")
    assert_equal OpenSSL::SSL::VERIFY_NONE, opts.dig(:ssl_params, :verify_mode)
  end

  def test_options_merges_extras_through
    opts = Studio::Redis.options(redis_url: "rediss://x", namespace: "cache", expires_in: 90)
    assert_equal "cache", opts[:namespace]
    assert_equal 90, opts[:expires_in]
    assert_equal OpenSSL::SSL::VERIFY_NONE, opts.dig(:ssl_params, :verify_mode)
  end

  def test_options_defaults_url_from_env
    with_redis_url("rediss://fromenv") do
      assert_equal "rediss://fromenv", Studio::Redis.options[:url]
      assert Studio::Redis.options.key?(:ssl_params), "a rediss:// REDIS_URL gets TLS handling"
    end
  end
end
