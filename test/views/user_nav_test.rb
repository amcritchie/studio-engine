# frozen_string_literal: true

require "action_view"
require "active_support/core_ext/object/try"
require "test_helper"

# Renders components/_user_nav.html.erb through ActionView and pins the slot
# contract: the new partial slots (balance_slot / extra_icons_slot /
# div2_slot — String path or { partial:, locals: } Hash), the deprecated
# legacy *_html string locals (still honored — hub and turf call sites must
# render unchanged), and the precedence rule (slot wins over legacy string).
class UserNavTest < Minitest::Test
  # --- legacy string locals (backward compatibility) --------------------

  def test_legacy_balance_html_string_still_renders
    html = render_nav(balance_html: %(<span data-legacy="balance">LEGACY-BAL</span>))

    assert_includes html, "LEGACY-BAL"
    assert_includes html, %(data-legacy="balance")
  end

  def test_legacy_extra_icons_html_string_still_renders
    html = render_nav(extra_icons_html: %(<span data-legacy="icons">LEGACY-ICONS</span>))

    assert_includes html, "LEGACY-ICONS"
  end

  def test_legacy_div2_html_string_replaces_the_default_second_row
    # div2_html was documented but silently ignored before the slot rework;
    # it now honors the documented contract.
    html = render_nav(div2_html: %(<div data-legacy="div2">LEGACY-DIV2</div>))

    assert_includes html, "LEGACY-DIV2"
    refute_includes html, "seedsNavbar", "default level bar should be replaced"
  end

  def test_hub_style_call_renders_unchanged
    # The hub's exact call: render "components/user_nav", show_logout_link: true
    html = render_nav(show_logout_link: true)

    assert_includes html, "Log out"
    assert_includes html, "/logout"
    assert_includes html, "seedsNavbar", "default level bar renders when no div2 slot given"
    assert_includes html, "Pat Studio"
  end

  # --- partial slots ----------------------------------------------------

  def test_balance_slot_renders_a_partial_by_name
    html = render_nav(balance_slot: "user_nav_fixtures/balance")

    assert_includes html, "SLOT-BALANCE"
  end

  def test_hash_slot_renders_with_locals
    html = render_nav(balance_slot: { partial: "user_nav_fixtures/balance_amount", locals: { amount: 112 } })

    assert_includes html, "$112"
  end

  def test_extra_icons_slot_renders_a_partial_by_name
    html = render_nav(extra_icons_slot: "user_nav_fixtures/icons")

    assert_includes html, "SLOT-ICONS"
  end

  def test_div2_slot_replaces_the_default_second_row
    html = render_nav(div2_slot: "user_nav_fixtures/div2")

    assert_includes html, "SLOT-DIV2"
    refute_includes html, "seedsNavbar", "default level bar should be replaced"
    refute_includes html, "navLevelPop", "default level bar styles should be replaced"
  end

  def test_slot_wins_over_legacy_string_when_both_are_passed
    html = render_nav(
      balance_slot: "user_nav_fixtures/balance",
      balance_html: %(<span>LEGACY-BAL</span>)
    )

    assert_includes html, "SLOT-BALANCE"
    refute_includes html, "LEGACY-BAL"
  end

  # --- logged-out path --------------------------------------------------

  def test_logged_out_renders_login_and_signup
    html = render_nav(logged_in: false)

    assert_includes html, "Log in"
    assert_includes html, "Sign up"
    refute_includes html, "Pat Studio"
  end

  private

  # Minimal user double covering everything the partial (and the nested
  # avatar partial) reads. No :level and no :truncated_solana, so the
  # default second row takes the show_logout_link branch like the hub.
  class StubUser
    def display_name = "Pat Studio"
    def avatar = @avatar ||= Class.new { def attached? = false }.new
    def avatar_color = "#6366f1"
    def avatar_initials = "PS"
  end

  def render_nav(logged_in: true, **locals)
    view = ActionView::Base.with_empty_template_cache.with_view_paths(
      ["app/views", "test/views/fixtures"]
    )
    user = StubUser.new
    view.define_singleton_method(:logged_in?) { logged_in }
    view.define_singleton_method(:current_user) { user }
    view.define_singleton_method(:logout_path) { "/logout" }
    view.define_singleton_method(:login_path) { "/login" }
    view.define_singleton_method(:signup_path) { "/signup" }

    view.render(partial: "components/user_nav", locals: locals)
  end
end
