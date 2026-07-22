# frozen_string_literal: true

require_relative "../test_helper"

# Studio.password_login_available? gates the engine login's password field. The PROPERTY:
# a password field/form renders ONLY when passwords are enabled (:password in auth_methods)
# AND the host User model actually supports them (responds to `authenticate`). Asserted across
# the permutations, not a remembered example — so a passwordless app (the whole fleet has moved
# off passwords) never renders a password field, and the engine default stops 500ing on
# `user.authenticate` for a User that has no such method.
class StudioPasswordLoginTest < Minitest::Test
  def setup
    @orig_auth = Studio.auth_methods
    remove_user_const
  end

  def teardown
    Studio.auth_methods = @orig_auth
    remove_user_const
  end

  def test_no_password_login_when_passwords_are_not_enabled
    define_user(authenticate: true) # even a User WITH authenticate...
    Studio.auth_methods = %i[magic_link google] # ...but :password not enabled
    refute Studio.password_login_available?,
           "passwords off must never render a password login, regardless of the User model"
  end

  def test_no_password_login_when_the_user_lacks_authenticate
    define_user(authenticate: false) # has_secure_password ABSENT — the passwordless-app bug
    Studio.auth_methods = %i[password] # even with :password mis-enabled
    refute Studio.password_login_available?,
           "a User with no `authenticate` must not get a password field (it would 500 on submit)"
    refute Studio.user_supports_password?
  end

  def test_no_password_login_and_no_raise_when_no_user_model_is_defined
    remove_user_const
    Studio.auth_methods = %i[password]
    refute Studio.password_login_available?, "no User model -> false, never a raise"
    refute Studio.user_supports_password?
  end

  def test_password_login_when_enabled_and_the_user_authenticates
    define_user(authenticate: true)
    Studio.auth_methods = %i[password google]
    assert Studio.password_login_available?
    assert Studio.user_supports_password?
  end

  private

  def define_user(authenticate:)
    remove_user_const
    klass = Class.new
    klass.define_method(:authenticate) { |_password| true } if authenticate
    Object.const_set(:User, klass)
  end

  def remove_user_const
    Object.send(:remove_const, :User) if Object.const_defined?(:User, false)
  end
end
