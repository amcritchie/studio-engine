module Studio
  module ErrorHandling
    extend ActiveSupport::Concern

    included do
      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
      rescue_from StandardError, with: :handle_unexpected_error

      before_action :require_authentication

      helper_method :current_user, :logged_in?, :sso_user_available?, :sso_display_name, :sso_source_app, :sso_hub_logo, :admin?
    end

    private

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = User.find_by(id: session[Studio.session_key])
    end

    def set_app_session(user)
      # App-specific session (only this app reads this key)
      session[Studio.session_key] = user.id

      # Only update shared awareness fields if this app is the source
      # (don't overwrite the other app's sso_source when logging in via sso_continue)
      if session[:sso_source].blank? || session[:sso_source] == Studio.app_name
        session[:sso_email]    = user.email
        session[:sso_name]     = user.try(:name)
        session[:sso_provider] = user.provider
        session[:sso_uid]      = user.uid
        session[:sso_wallet]   = user.try(:wallet_address)
        session[:sso_source]   = Studio.app_name
        session[:sso_logo]     = Studio.sso_logo
      end
    end

    def clear_app_session
      session.delete(Studio.session_key)

      # Clear sso_* fields only if this app is the source
      # (preserve them if the other app set them — they're still logged in there)
      if session[:sso_source] == Studio.app_name
        session.delete(:sso_email)
        session.delete(:sso_name)
        session.delete(:sso_provider)
        session.delete(:sso_uid)
        session.delete(:sso_wallet)
        session.delete(:sso_source)
        session.delete(:sso_logo)
      end
    end

    # Cross-app awareness helpers for login page
    def sso_user_available?
      !logged_in? && session[:sso_email].present? && session[:sso_source] != Studio.app_name
    end

    def sso_display_name
      session[:sso_name].presence || session[:sso_email]&.split("@")&.first&.capitalize || "User"
    end

    def sso_source_app
      session[:sso_source]
    end

    def sso_hub_logo
      session[:sso_logo]
    end

    def logged_in?
      current_user.present?
    end

    def require_authentication
      unless logged_in?
        redirect_to login_path
      end
    end

    def require_admin
      return redirect_to root_path, alert: "Not authorized" unless logged_in? && current_user.admin?
    end

    def admin?
      logged_in? && current_user.admin?
    end

    # Central error logging method — all controller error logging flows through here.
    # Returns the ErrorLog record so callers can attach target/parent context.
    def create_error_log(exception)
      ErrorLog.capture!(exception)
    end

    # Layer 2: Opt-in per-action wrapper with target/parent context.
    # Sets @_error_logged flag so Layer 1 won't double-log.
    def rescue_and_log(target: nil, parent: nil)
      yield
    rescue ActiveRecord::RecordNotFound => e
      raise e
    rescue StandardError => e
      error_log = create_error_log(e)
      if target
        error_log.target = target
        error_log.target_name = target.slug
      end
      if parent
        error_log.parent = parent
        error_log.parent_name = parent.slug
      end
      error_log.save!
      @_error_logged = true
      raise e
    end

    # Layer 1: Catch-all for RecordNotFound — 404 redirect, no logging.
    def handle_not_found(exception)
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Not found" }
        format.json { render json: { error: "Not found" }, status: :not_found }
      end
    end

    # Layer 1: Catch-all for unexpected errors — log + friendly response.
    # Skips logging if rescue_and_log already captured it.
    def handle_unexpected_error(exception)
      create_error_log(exception) unless @_error_logged
      raise exception if Rails.env.development? || Rails.env.test?

      respond_to do |format|
        format.html { redirect_to root_path, alert: "Something went wrong." }
        format.json { render json: { error: "Internal server error" }, status: :internal_server_error }
      end
    end
  end
end
