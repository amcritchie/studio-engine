# frozen_string_literal: true

# Boots studio-engine inside the real dummy Rails app (test/dummy) and renders
# the flagship UI primitives — the canonical modal host and the slot-based
# user nav — through the full Rails view stack (engine view paths wired by the
# railtie, real partial resolution, real url helpers from Studio.routes). The
# unit view tests (test/views/*) pin the emitted contracts; this proves the
# same partials resolve and render inside a consuming app.

require "bundler/setup"

ENV["RAILS_ENV"] ||= "test"
require_relative "../dummy/config/environment"

require "minitest/autorun"
require "active_support/test_case"

# Renderer controller for the user-nav: supplies the auth helpers a host app's
# ApplicationController exposes (the partial reads them via helper methods).
class UserNavRenderHostController < ActionController::Base
  helper_method :logged_in?, :current_user

  class StubUser
    def display_name = "Dummy User"
    def avatar = @avatar ||= Class.new { def attached? = false }.new
    def avatar_color = "#0ea5e9"
    def avatar_initials = "DU"
  end

  def logged_in? = true

  def current_user = @current_user ||= StubUser.new
end

class UiPrimitivesRenderTest < ActiveSupport::TestCase
  test "modal host renders through the dummy app with a block registration" do
    html = ActionController::Base.render(inline: <<~ERB)
      <%= render "studio/modals/host" do %>
        <template x-if="$store.modals.current().id === 'demo'">
          <div>DUMMY-REGISTERED-MODAL</div>
        </template>
      <% end %>
    ERB

    assert_includes html, "DUMMY-REGISTERED-MODAL"
    assert_includes html, "Alpine.store('modals'"
    assert_includes html, "advance: function(propsPatch, opts)"
    assert_includes html, "@keyframes modal-card-in"
    assert_includes html, "window.ModalAnimations"
  end

  test "user nav renders the hub-style legacy call through the dummy app" do
    html = UserNavRenderHostController.render(
      inline: %(<%= render "components/user_nav", show_logout_link: true %>)
    )

    assert_includes html, "Dummy User"
    assert_includes html, "Log out"
    assert_includes html, "/logout", "expected the real logout route from Studio.routes"
  end

  test "user nav renders partial slots against real engine partials" do
    html = UserNavRenderHostController.render(inline: <<~ERB)
      <%= render "components/user_nav",
            balance_slot: { partial: "components/emoji_swap", locals: { base: "💰", hover: "✨" } },
            div2_slot: "components/theme_toggle" %>
    ERB

    assert_includes html, "studio-emoji-swap", "balance_slot should render the engine emoji_swap partial"
    assert_includes html, "$store.theme.toggle()", "div2_slot should render the engine theme_toggle partial"
    refute_includes html, "seedsNavbar", "div2_slot should replace the default level bar"
  end
end
