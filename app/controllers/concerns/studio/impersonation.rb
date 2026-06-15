require "time"

module Studio
  module Impersonation
    extend ActiveSupport::Concern

    included do
      if respond_to?(:helper_method)
        helper_method :true_user, :impersonated_user, :impersonating?, :impersonation_started_at
      end
    end

    private

    # The real session owner. While acting as another user, this remains the
    # admin/operator account whose session token should be verified.
    def true_user
      return @true_user if defined?(@true_user)

      @true_user = User.find_by(id: session[Studio.session_key])
    end

    # The currently visible user. Consumers with extra wallet or privilege state
    # can override this and still call true_user/impersonating? from the concern.
    def current_user
      return @current_user if defined?(@current_user)

      @current_user = impersonating? ? impersonated_user : true_user
    end

    def impersonated_user
      return @impersonated_user if defined?(@impersonated_user)

      @impersonated_user = User.find_by(id: session[Studio.impersonation_target_session_key])
    end

    def impersonating?
      return @impersonating if defined?(@impersonating)

      @impersonating = compute_impersonating?
    end

    def start_impersonation_session(target_user, actor: true_user)
      session[Studio.impersonation_actor_session_key] = actor.id
      session[Studio.impersonation_target_session_key] = target_user.id
      session[Studio.impersonation_started_at_session_key] = Time.current.iso8601
      reset_impersonation_memoization
    end

    def clear_impersonation_session
      session.delete(Studio.impersonation_actor_session_key)
      session.delete(Studio.impersonation_target_session_key)
      session.delete(Studio.impersonation_started_at_session_key)
      reset_impersonation_memoization
    end

    def impersonation_started_at
      raw = session[Studio.impersonation_started_at_session_key]
      return nil if raw.blank?

      return raw if raw.is_a?(Time)

      zone = Time.zone if Time.respond_to?(:zone)
      zone ? zone.parse(raw.to_s) : Time.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def compute_impersonating?
      return false if session[Studio.impersonation_target_session_key].blank?
      return false unless true_user&.respond_to?(:admin?) && true_user.admin?
      return false unless impersonation_started_at
      return false if impersonation_started_at < Studio.impersonation_max_minutes.to_i.minutes.ago

      target = impersonated_user
      target.present? &&
        (!target.respond_to?(:admin?) || !target.admin?) &&
        target.id != true_user.id
    rescue StandardError
      false
    end

    def reset_impersonation_memoization
      remove_instance_variable(:@current_user) if defined?(@current_user)
      remove_instance_variable(:@true_user) if defined?(@true_user)
      remove_instance_variable(:@impersonated_user) if defined?(@impersonated_user)
      remove_instance_variable(:@impersonating) if defined?(@impersonating)
    end
  end
end
