module Studio
  # Shared create-or-login building blocks for the magic-link / link consume
  # controllers (MagicLinksController + Studio::LinksController). `result` is
  # anything responding to #email and #return_to — the legacy MagicLink::Result
  # OR a Studio::Link — so both token schemes reuse this. Apps that override the
  # link controllers (e.g. turf-monster's contest landing) include it too.
  #
  # Relies on the host ApplicationController contract from Studio::ErrorHandling:
  # set_app_session, rescue_and_log, current_user, plus root_path / login_path.
  module LinkConsumption
    extend ActiveSupport::Concern

    private

    def sign_in_existing(user, result)
      set_app_session(user)
      # Clicking the link proves email ownership, so verify any account that
      # reached here without it (e.g. a Google/wallet-only signup).
      user.update!(email_verified_at: Time.current) if user.respond_to?(:email_verified_at) && user.email_verified_at.blank?
      redirect_to(safe_path(result.return_to) || root_path, notice: "Signed in. Welcome back!")
    end

    # Build → configure_new_user → save!. No password — email auth is link-only.
    def sign_up_new(result)
      user = User.new(email: result.email)
      Studio.configure_new_user.call(user)
      rescue_and_log(target: user) do
        user.save!
        user.update!(email_verified_at: Time.current) if user.respond_to?(:email_verified_at)
        set_app_session(user)
        redirect_to(safe_path(result.return_to) || root_path, notice: Studio.welcome_message.call(user))
      end
    rescue ActiveRecord::RecordNotUnique
      # Two valid tokens for the same brand-new email consumed near-simultaneously
      # both miss find_by and race to save!; the loser hits the unique index.
      # Benign — the account now exists, so just log the winner in.
      existing = User.find_by(email: result.email)
      return sign_in_existing(existing, result) if existing

      redirect_to login_path, alert: "We couldn't finish creating your account. Please try again."
    rescue StandardError => e
      Rails.logger.error("[Studio::LinkConsumption#sign_up_new] signup failed #{e.class}: #{e.message}")
      redirect_to login_path, alert: "We couldn't finish creating your account. Please try again."
    end

    # Only same-origin absolute paths survive; everything else collapses to nil.
    def safe_path(path)
      p = path.to_s
      p.start_with?("/") && !p.start_with?("//") ? p : nil
    end
  end
end
