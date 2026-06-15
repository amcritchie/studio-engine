# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../app/controllers/concerns/studio/impersonation"

class StudioImpersonationTest < Minitest::Test
  FakeUser = Struct.new(:id, :name, :admin_flag, keyword_init: true) do
    def admin?
      admin_flag
    end

    def display_name
      name
    end
  end

  class FakeController
    def self.helper_method(*); end

    include Studio::Impersonation

    attr_reader :session

    def initialize(session)
      @session = session
    end

    def exposed_current_user
      current_user
    end

    def exposed_true_user
      true_user
    end

    def exposed_impersonated_user
      impersonated_user
    end

    def exposed_impersonating?
      impersonating?
    end

    def exposed_start_impersonation_session(target_user, actor:)
      start_impersonation_session(target_user, actor: actor)
    end

    def exposed_clear_impersonation_session
      clear_impersonation_session
    end
  end

  def setup
    @original_user = Object.const_get(:User) if Object.const_defined?(:User)
    Object.send(:remove_const, :User) if Object.const_defined?(:User)
    Object.const_set(:User, fake_user_class)

    @original_session_key = Studio.session_key
    @original_max_minutes = Studio.impersonation_max_minutes
    Studio.session_key = :user_id
    Studio.impersonation_max_minutes = 30

    @admin = FakeUser.new(id: 1, name: "Admin", admin_flag: true)
    @target = FakeUser.new(id: 2, name: "Target", admin_flag: false)
    @other_admin = FakeUser.new(id: 3, name: "Other Admin", admin_flag: true)
    User.records = {
      1 => @admin,
      2 => @target,
      3 => @other_admin
    }
  end

  def teardown
    Object.send(:remove_const, :User) if Object.const_defined?(:User)
    Object.const_set(:User, @original_user) if @original_user
    Studio.session_key = @original_session_key
    Studio.impersonation_max_minutes = @original_max_minutes
  end

  def test_current_user_is_true_user_without_impersonation
    controller = FakeController.new(user_id: @admin.id)

    assert_equal @admin, controller.exposed_true_user
    assert_equal @admin, controller.exposed_current_user
    refute controller.exposed_impersonating?
  end

  def test_valid_admin_impersonation_layers_current_user_over_true_user
    session = { user_id: @admin.id }
    controller = FakeController.new(session)

    controller.exposed_start_impersonation_session(@target, actor: @admin)

    assert_equal @admin.id, session.fetch(:true_admin_id)
    assert_equal @target.id, session.fetch(:impersonated_user_id)
    assert_equal @admin, controller.exposed_true_user
    assert_equal @target, controller.exposed_impersonated_user
    assert_equal @target, controller.exposed_current_user
    assert controller.exposed_impersonating?
  end

  def test_impersonation_rejects_admin_targets
    controller = FakeController.new(
      user_id: @admin.id,
      impersonated_user_id: @other_admin.id,
      impersonation_started_at: Time.current.iso8601
    )

    refute controller.exposed_impersonating?
    assert_equal @admin, controller.exposed_current_user
  end

  def test_impersonation_expires_closed
    controller = FakeController.new(
      user_id: @admin.id,
      impersonated_user_id: @target.id,
      impersonation_started_at: 31.minutes.ago.iso8601
    )

    refute controller.exposed_impersonating?
    assert_equal @admin, controller.exposed_current_user
  end

  def test_clear_impersonation_session_removes_keys_and_memoization
    session = {
      user_id: @admin.id,
      true_admin_id: @admin.id,
      impersonated_user_id: @target.id,
      impersonation_started_at: Time.current.iso8601
    }
    controller = FakeController.new(session)

    assert_equal @target, controller.exposed_current_user
    controller.exposed_clear_impersonation_session

    refute session.key?(:true_admin_id)
    refute session.key?(:impersonated_user_id)
    refute session.key?(:impersonation_started_at)
    refute controller.exposed_impersonating?
    assert_equal @admin, controller.exposed_current_user
  end

  private

  def fake_user_class
    Class.new do
      class << self
        attr_accessor :records

        def find_by(id:)
          records[id]
        end
      end
    end
  end
end
