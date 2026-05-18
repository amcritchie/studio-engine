module Studio
  module ImageCache
    EXT_BY_TYPE = {
      "image/png"  => "png",
      "image/jpeg" => "jpg",
      "image/jpg"  => "jpg",
      "image/webp" => "webp",
      "image/gif"  => "gif"
    }.freeze

    ALLOWED_CONTENT_TYPES = EXT_BY_TYPE.keys.freeze

    # Per-call cap on the bytes we'll fetch from a remote source_url. 50MB
    # covers high-res photos comfortably; anything larger should be uploaded
    # via source_path (local file) to bypass this cap intentionally.
    MAX_REMOTE_BYTES = 50 * 1024 * 1024

    class InvalidSourceURL < ArgumentError; end
    class UnsupportedContentType < ArgumentError; end
    class SourceTooLarge < StandardError; end

    # Caches an image at S3 under a folder per owner. Every call stores the
    # unmodified source as variant "original", plus one resized variant per
    # entry in widths.
    #
    # Layout:
    #   {key_prefix}/original.{ext}
    #   {key_prefix}/{width}.{ext}
    #
    # Source: provide EITHER source_url (HTTP fetch) OR source_path (local
    # file). source_url is recorded on each ImageCache row regardless — for
    # source_path callers, pass the original URL too if you want it tracked.
    #
    # source_url is validated against SSRF: scheme must be http/https,
    # host must not be loopback/private/link-local/metadata-IP, and
    # well-known internal hostnames (localhost, *.local, *.internal) are
    # rejected. This does NOT defend against DNS rebinding — strong
    # protection there requires resolving DNS once then passing the
    # resolved IP to the HTTP client.
    #
    # Idempotent: variants already present in ImageCache are skipped. If
    # nothing is missing, the source is never read.
    def self.cache!(owner:, purpose:, key_prefix:, widths:, source_url: nil, source_path: nil, content_type: "image/png")
      raise ArgumentError, "either source_url or source_path is required" if source_url.nil? && source_path.nil?

      unless ALLOWED_CONTENT_TYPES.include?(content_type)
        raise UnsupportedContentType, "content_type #{content_type.inspect} not in allowlist (#{ALLOWED_CONTENT_TYPES.join(", ")})"
      end

      validate_source_url!(source_url) if source_url

      ext = EXT_BY_TYPE[content_type]
      requested = ["original", *widths.map(&:to_s)]

      existing = ::ImageCache.where(owner: owner, purpose: purpose).index_by(&:variant)
      missing  = requested - existing.keys
      return existing if missing.empty?

      require "mini_magick"

      body = if source_path
        File.binread(source_path)
      else
        fetch_remote(source_url)
      end

      missing.each do |variant|
        if variant == "original"
          payload = body
          s3_key  = "#{key_prefix}/original.#{ext}"
        else
          img = MiniMagick::Image.read(body)
          # Cap ImageMagick resources per-invocation to prevent decompression-bomb DoS.
          img.combine_options do |c|
            c.limit "memory", "256MB"
            c.limit "map", "512MB"
            c.limit "width", "16KP"   # 16k pixel max width
            c.limit "height", "16KP"
            c.resize "#{variant}x"
          end
          payload = img.to_blob
          s3_key  = "#{key_prefix}/#{variant}.#{ext}"
        end

        Studio::S3.upload(
          key: s3_key,
          body: payload,
          content_type: content_type,
          cache_control: "public, max-age=31536000, immutable"
        )

        existing[variant] = ::ImageCache.create!(
          owner: owner,
          purpose: purpose,
          variant: variant,
          s3_key: s3_key,
          source_url: source_url,
          bytes: payload.bytesize,
          content_type: content_type
        )
      end

      existing
    end

    # SSRF guard for remote source_url. Raises InvalidSourceURL on anything
    # that looks like an attempt to reach internal services.
    def self.validate_source_url!(url)
      require "uri"
      uri = URI.parse(url)
      unless %w[http https].include?(uri.scheme)
        raise InvalidSourceURL, "URL scheme must be http or https, got #{uri.scheme.inspect}"
      end

      host = uri.host.to_s.downcase
      raise InvalidSourceURL, "URL missing host: #{url.inspect}" if host.empty?

      # Hostname-based blocklist (catches common internal hostnames before any DNS).
      if host == "localhost" || host.end_with?(".local") || host.end_with?(".internal") || host.end_with?(".lan")
        raise InvalidSourceURL, "URL points to internal hostname: #{host.inspect}"
      end

      # If the host is a literal IP address, check ranges.
      bracketed = host.start_with?("[") && host.end_with?("]")
      ip_host = bracketed ? host[1..-2] : host
      ipv4_like = ip_host.match?(/\A\d{1,3}(\.\d{1,3}){3}\z/)
      ipv6_like = bracketed || ip_host.include?(":")
      if ipv4_like || ipv6_like
        require "ipaddr"
        begin
          ip = IPAddr.new(ip_host)
        rescue IPAddr::Error => e
          raise InvalidSourceURL, "Malformed IP host #{ip_host.inspect}: #{e.message}"
        end
        if ip.loopback? || ip.private? || ip.link_local? || ip_host == "169.254.169.254" || ip.to_s == "0.0.0.0" || ip.to_s == "::"
          raise InvalidSourceURL, "URL points to internal/private IP: #{ip_host}"
        end
      end

      uri
    end

    def self.fetch_remote(source_url)
      require "open-uri"
      body = URI.open(source_url, read_timeout: 30, redirect: true).read
      if body.bytesize > MAX_REMOTE_BYTES
        raise SourceTooLarge, "remote payload #{body.bytesize} bytes exceeds cap #{MAX_REMOTE_BYTES}"
      end
      body
    end
  end
end
