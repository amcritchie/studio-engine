module Studio
  # The unified short-token link entry point — GET/POST /l/<token>. Dispatches by
  # Studio::Link#kind:
  #
  #   magic_link → scanner-safe confirm interstitial (GET, inert) that auto-POSTs
  #                to #consume, the ONLY place the single-use token is burned +
  #                the recipient is signed in / signed up.
  #   referral   → idempotent: capture attribution into a cookie + redirect to
  #                the link's target (or root). Reusable + safe to prefetch, so
  #                GET does the work (no POST step).
  #
  # Namespaced (not top-level Links) because mcritchie-studio already owns a
  # public /links linktree (top-level LinksController). Apps needing richer
  # post-consume routing (contest landing, picks rehydration, age-gate) define
  # their own Studio::LinksController and reuse Studio::Link + the
  # Studio::LinkConsumption building blocks.
  class LinksController < ApplicationController
    include Studio::LinkConsumption

    skip_before_action :require_authentication
    layout false, only: :show

    # GET /l/:token
    def show
      response.set_header("Referrer-Policy", "strict-origin")
      @link = Studio::Link.find_by(token: params[:token])

      case @link&.kind
      when "magic_link"
        @token = params[:token]
        render :confirm
      when "referral"
        capture_referral(@link)
        redirect_to(@link.target || root_path)
      else
        redirect_to login_path, alert: "That link is invalid or has expired. Request a fresh one below."
      end
    end

    # POST /l/:token — authoritative magic-link consume. Only magic_link kinds are
    # consumable here; referral links are reusable and handled entirely on GET.
    def consume
      response.set_header("Referrer-Policy", "strict-origin")
      link = Studio::Link.find_by(token: params[:token])
      raise Studio::Link::InvalidToken, "not a magic link" unless link&.kind == "magic_link"

      link.consume! # burns the single-use token; raises if already used / expired
      user = User.find_by(email: link.email)
      user ? sign_in_existing(user, link) : sign_up_new(link)
    rescue Studio::Link::InvalidToken
      redirect_to login_path, alert: "That sign-in link is invalid or has expired. Request a fresh one below."
    end

    private

    # Attribution rides in a cookie the app reads at signup (same :reference
    # cookie the legacy ?ref= capture used). Value = the inviter's stable handle
    # (slug) when available, else the link token. Capped to 64 chars.
    def capture_referral(link)
      inviter = link.linkable
      ref = inviter.respond_to?(:slug) ? inviter.slug : link.token
      cookies[:reference] = { value: ref.to_s.first(64), expires: 30.days, same_site: :lax }
    end
  end
end
