# frozen_string_literal: true

require "action_view"
require "test_helper"

# Renders the canonical modal host (studio/modals/_host.html.erb) through
# ActionView and pins its contract: the Alpine.store('modals') API surface,
# the animation registry + inline keyframes (upstreamed from Turf Monster's
# shadow copy), dismissal guards, and block-based modal registration. These
# are string assertions on the emitted HTML/JS — the store logic itself runs
# in the browser, but the contract a consumer codes against is all here.
class ModalHostTest < Minitest::Test
  # --- registration -----------------------------------------------------

  def test_block_registered_modal_renders_inside_the_card
    html = render_host_with_block

    assert_includes html, "REGISTERED-MODAL-MARKER"
    # The registration must land inside the card div (after its opening tag)
    # and before the template closes.
    card_index = html.index("cardClasses()\"")
    marker_index = html.index("REGISTERED-MODAL-MARKER")
    close_index = html.rindex("</template>")
    refute_nil card_index
    assert_operator card_index, :<, marker_index
    assert_operator marker_index, :<, close_index
  end

  def test_renders_without_a_block
    html = render_host

    assert_includes html, "Alpine.store('modals'"
  end

  # --- store API surface ------------------------------------------------

  def test_store_exposes_the_full_stack_api
    html = render_host

    %w[open: swap: advance: close: closeAll: closeAllDismissible: isOpen: current: cardClasses: _sync:].each do |method|
      assert_includes html, method, "expected Alpine store to define #{method}"
    end
  end

  def test_open_supports_replace_swap_with_direction
    html = render_host

    assert_includes html, "opts.replace"
    assert_includes html, "(opts.direction === 'back') ? 'back' : 'forward'"
    assert_includes html, "_swappingOut"
    assert_includes html, "_swappingIn"
    assert_includes html, "_settled"
  end

  def test_close_delays_splice_by_the_exit_animation_duration
    html = render_host

    assert_includes html, "modalAnim('exit', entry.props && entry.props.exitAnim).ms"
    assert_includes html, "self.stack.splice(idx, 1)"
  end

  def test_close_all_dismissible_keeps_non_dismissible_modals
    html = render_host

    assert_includes html, "modal.props.dismissible === false"
  end

  def test_hold_at_least_helper_ships
    html = render_host

    assert_includes html, "window.StudioModals.holdAtLeast"
  end

  # --- animation registry -----------------------------------------------

  def test_animation_registry_ships_pop_shake_slide_defaults
    html = render_host

    assert_includes html, "pop:   { cls: 'modal-card-mount',    ms: 320 }"
    assert_includes html, "shake: { cls: 'modal-card-shake-in', ms: 600 }"
    assert_includes html, "slide: { cls: 'modal-card-swap-in',  ms: 220 }"
    assert_includes html, "pop:   { cls: 'modal-card-unmount',  ms: 220 }"
    assert_includes html, "slide: { cls: 'modal-card-swap-out', ms: 220 }"
  end

  def test_animation_registry_merges_consumer_overrides_over_defaults
    html = render_host

    # A consumer that predefines window.ModalAnimations before this script
    # keeps its entries (they win per-channel) without losing the defaults.
    assert_includes html, "var animOverrides = window.ModalAnimations || {};"
    assert_includes html, "Object.assign({}, animDefaults.enter, animOverrides.enter || {})"
    assert_includes html, "Object.assign({}, animDefaults.exit,  animOverrides.exit  || {})"
  end

  def test_card_binds_registry_driven_classes
    html = render_host

    assert_includes html, ':class="$store.modals.cardClasses()"'
    # Directional swap classes stay fixed names regardless of registry keys.
    %w[modal-card-swap-in modal-card-swap-out modal-card-swap-in-back modal-card-swap-out-back].each do |cls|
      assert_includes html, "'#{cls}'"
    end
  end

  # --- inline keyframe CSS ----------------------------------------------

  def test_keyframes_ship_inline_so_consumers_need_no_extra_css
    html = render_host

    %w[
      modal-card-in modal-card-out modal-backdrop-in modal-backdrop-out
      modal-card-shake-in modal-card-slide-out-right modal-card-slide-in-left
      modal-card-slide-out-left modal-card-slide-in-right
    ].each do |keyframe|
      assert_includes html, "@keyframes #{keyframe}", "expected inline keyframe #{keyframe}"
    end

    %w[
      modal-card-mount modal-card-unmount modal-backdrop-mount modal-backdrop-unmount
    ].each do |cls|
      assert_includes html, ".#{cls} ", "expected inline class .#{cls}"
    end
  end

  def test_reduced_motion_fallback_ships
    html = render_host

    assert_includes html, "@media (prefers-reduced-motion: reduce)"
  end

  def test_legacy_scroll_lock_and_drain_keyframe_survive
    html = render_host

    assert_includes html, "body.modal-open { overflow: hidden; }"
    assert_includes html, "@keyframes studio-modal-drain"
  end

  # --- dismissal + cleanup ----------------------------------------------

  def test_escape_and_click_outside_respect_dismissible_false
    html = render_host

    assert_includes html, "@keydown.escape.window=\"$store.modals.current() && $store.modals.current().props.dismissible !== false && $store.modals.close()\""
    assert_includes html, "@click.self=\"$store.modals.current() && $store.modals.current().props.dismissible !== false && $store.modals.close()\""
  end

  def test_bfcache_and_turbo_cleanup_registered
    html = render_host

    assert_includes html, "window.addEventListener('pageshow'"
    assert_includes html, "document.addEventListener('turbo:before-cache'"
  end

  # --- structure --------------------------------------------------------

  def test_template_x_if_has_a_single_root_element
    html = render_host

    template_body = html[/<template x-if="\$store\.modals\.current\(\)">(.*)<\/template>/m, 1]
    refute_nil template_body, "expected the x-if template wrapper"
    # Exactly one top-level element: the backdrop div opens immediately and
    # every other tag nests inside it (Alpine silently no-ops multi-root
    # x-if templates).
    assert_equal 1, top_level_element_count(template_body),
                 "template x-if must have exactly ONE root element"
  end

  def test_no_turf_specific_modals_leak_into_the_engine
    html = render_host

    refute_includes html, "cosign"
  end

  private

  def render_host
    view.render(partial: "studio/modals/host")
  end

  def render_host_with_block
    view.render(inline: <<~ERB)
      <%= render "studio/modals/host" do %>
        <template x-if="$store.modals.current().id === 'demo'">
          <div>REGISTERED-MODAL-MARKER</div>
        </template>
      <% end %>
    ERB
  end

  def view
    ActionView::Base.with_empty_template_cache.with_view_paths(["app/views"])
  end

  # Counts elements sitting directly inside the fragment by walking tag
  # open/close depth. Void/self-closing tags don't appear at the template's
  # top level here, so a plain depth walk is enough.
  def top_level_element_count(fragment)
    depth = 0
    count = 0
    fragment.scan(%r{<(/?)([a-zA-Z][a-zA-Z0-9-]*)[^>]*?(/?)>}) do |closing, _tag, self_closing|
      if closing == "/"
        depth -= 1
      elsif self_closing == "/"
        count += 1 if depth.zero?
      else
        count += 1 if depth.zero?
        depth += 1
      end
    end
    count
  end
end
