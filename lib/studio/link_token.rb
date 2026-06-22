# frozen_string_literal: true

require "securerandom"

module Studio
  # Pure-Ruby helpers behind the Studio::Link model — token minting, the kind
  # rules, and the input sanitizers. Kept free of ActiveRecord so it loads (and
  # unit-tests) without a database, mirroring the other lib/studio/*.rb pure
  # classes. The AR model (app/models/studio/link.rb) delegates to this.
  module LinkToken
    # The kinds of link that share the studio_links table + the /l/<token>
    # entry point.
    #   magic_link — single-use, short-lived passwordless sign-in / sign-up
    #   referral   — reusable, non-expiring share link owned by a User
    KINDS = %w[magic_link referral].freeze

    # Kinds burned on first successful consume. Referral links are reusable, so
    # they are deliberately NOT single-use.
    SINGLE_USE_KINDS = %w[magic_link].freeze

    # 96 bits of entropy → ~16 URL-safe chars (e.g. "PP-PDbEj5V3-aNh4"). Short
    # enough to keep the URL clean, far too large to brute-force — especially
    # for single-use, expiring magic links. Matches turf-monster's proven format.
    TOKEN_BYTES = 12

    module_function

    # A fresh URL-safe token. urlsafe_base64 emits only [A-Za-z0-9_-], so the
    # token satisfies the %r{[^/]+} route constraint and survives URL generation
    # without extra encoding.
    def generate
      SecureRandom.urlsafe_base64(TOKEN_BYTES)
    end

    def kind?(kind)
      KINDS.include?(kind.to_s)
    end

    def single_use?(kind)
      SINGLE_USE_KINDS.include?(kind.to_s)
    end

    def normalize_email(email)
      email.to_s.strip.downcase
    end

    # Only same-origin absolute paths survive; protocol-relative ("//evil"),
    # absolute URLs, and blanks collapse to nil so callers fall back to a safe
    # default redirect. Mirrors the MagicLink service's sanitizer.
    def sanitize_path(path)
      p = path.to_s
      p.start_with?("/") && !p.start_with?("//") ? p : nil
    end
  end
end
