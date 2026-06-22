module Studio
  # Admin-managed banner images for transactional emails. One image per "variant"
  # (the email type), uploaded to S3 with a stable PUBLIC url via Studio::S3 and
  # tracked by an owner-less ImageCache row (purpose "email_banner"). The branded
  # mailer resolves the current banner with .url; the admin email-image page
  # writes it with .store.
  #
  # VARIANTS is the registry — magic_link now; adding an entry is all it takes to
  # admin-manage another email's header image (the "extensible" part of the
  # magic-link-now-extensible scope).
  module EmailImage
    PURPOSE = "email_banner".freeze

    # variant => human label, in admin display order.
    VARIANTS = {
      "magic_link" => "Magic-link sign-in"
    }.freeze

    module_function

    def variants
      VARIANTS
    end

    def label(variant)
      VARIANTS[variant.to_s] || variant.to_s.humanize
    end

    def known?(variant)
      VARIANTS.key?(variant.to_s)
    end

    # The ImageCache row for this variant, or nil (no banner uploaded / table not
    # installed yet). Nil-safe so the mailer renders bannerless before any upload.
    def record(variant)
      return nil unless table_ready?

      ::ImageCache.find_by(owner: nil, purpose: PURPOSE, variant: variant.to_s)
    end

    # Permanent public S3 url for the current banner, or nil.
    def url(variant)
      record(variant)&.url
    end

    # Upload bytes to S3 + upsert the ImageCache row (replacing any prior object).
    # Returns the ::ImageCache. Raises on failure after cleaning up the new object.
    def store(variant, io:, content_type: nil)
      key = "email_banners/#{variant}-#{SecureRandom.hex(4)}#{ext_for(content_type)}"
      Studio::S3.upload(key: key, body: io.read, content_type: content_type,
                        cache_control: "public, max-age=300")
      record = ::ImageCache.find_or_initialize_by(owner: nil, purpose: PURPOSE, variant: variant.to_s)
      previous = record.s3_key
      record.update!(s3_key: key)
      delete_object(previous) if previous.present? && previous != key
      record
    rescue StandardError
      delete_object(key)
      raise
    end

    # Reference ImageCache directly so Zeitwerk autoloads it — defined?() does NOT
    # trigger autoload, so it would read "undefined" for a not-yet-loaded const.
    def table_ready?
      ::ImageCache.table_exists?
    rescue NameError, ActiveRecord::ActiveRecordError
      false
    end

    def ext_for(content_type)
      case content_type.to_s
      when %r{png}    then ".png"
      when %r{jpe?g}  then ".jpg"
      when %r{webp}   then ".webp"
      else ".png"
      end
    end

    def delete_object(key)
      Studio::S3.delete(key: key)
    rescue StandardError
      nil
    end
  end
end
