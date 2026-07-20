# frozen_string_literal: true

require "test_helper"
require "action_view"
require "tempfile"

# Executes the modal host's Alpine store FOR REAL. The other host tests
# assert on the emitted source; review proved that is structurally blind to
# resolution bugs (cardClasses() clobbered the registry 'slide' classes while
# every string assertion stayed green). Here the rendered partial's <script>
# is extracted and run under node with minimal window/document/Alpine stubs,
# and the store's behavior — cardClasses() resolution, registry merge,
# animated close timing, swap races, late registry replacement — is asserted
# by CALLING it, not by grepping it.
class ModalHostStoreBehaviorTest < Minitest::Test
  # A missing node runtime FAILS here; it must never `skip`. This is the only
  # test that observes the store's real resolution behavior, so a skip would
  # read as a pass on exactly the host where the coverage is absent — the
  # "green by not running" shape this suite exists to catch. CI installs node
  # in the engine-suite lane (.github/workflows/engine-ci.yml); locally it
  # comes from mise (`mise install node@20`).
  def test_node_runtime_is_available
    refute_empty node_path,
                 "node runtime NOT FOUND on PATH. The modal-host store behavior suite " \
                 "executes the store for real and is the only coverage of cardClasses() " \
                 "resolution — skipping it would report green with zero coverage. " \
                 "Install node (mise install node@20) and re-run."
  end

  def test_store_behavior_under_node
    node = node_path

    html = ActionView::Base.with_empty_template_cache
                           .with_view_paths(["app/views"])
                           .render(partial: "studio/modals/host")
    script = html[%r{<script>(.*?)</script>}m, 1]
    refute_nil script, "expected the host to emit its store <script>"

    out = nil
    Tempfile.create(["modal_host_harness", ".js"]) do |f|
      f.write(HARNESS_PRELUDE, script, HARNESS_SCENARIOS)
      f.flush
      out = `#{node} #{f.path} 2>&1`
    end

    assert $?.success?, "node harness failed:\n#{out}"
    assert_includes out, "ALL-MODAL-STORE-SCENARIOS-PASS", out
  end

  def node_path
    @node_path ||= `which node 2>/dev/null`.strip
  end

  # Minimal browser stubs. The host script registers listeners on document
  # (alpine:init, turbo:before-cache) and window (pageshow), reads/writes
  # window.ModalAnimations / window.StudioModals / window.Alpine, and touches
  # document.body.classList in _sync(). A consumer registry entry is
  # PRE-registered (enter.wobble) to exercise the merge path.
  HARNESS_PRELUDE = <<~'JS'
    'use strict';
    const pendingEvents = {};
    const document = {
      addEventListener(ev, fn) { (pendingEvents[ev] = pendingEvents[ev] || []).push(fn); },
      body: { classList: { add() {}, remove() {} } }
    };
    const window = globalThis;
    globalThis.addEventListener = () => {};
    const alpineStores = {};
    const Alpine = {
      store(name, def) {
        if (def === undefined) return alpineStores[name];
        alpineStores[name] = def;
      }
    };
    globalThis.Alpine = Alpine;

    // Consumer pre-registration BEFORE the host script runs — must merge
    // over the defaults, not replace them.
    globalThis.ModalAnimations = { enter: { wobble: { cls: 'custom-wobble', ms: 90 } } };

    // ==== the host's <script>, verbatim, follows ====
  JS

  HARNESS_SCENARIOS = <<~'JS'
    // ==== scenarios ====
    function assert(cond, msg) {
      if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
    }
    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

    (async function () {
      (pendingEvents['alpine:init'] || []).forEach((fn) => fn());
      const store = alpineStores['modals'];
      assert(store, 'alpine:init must register the modals store');

      // 1. Registry merge: consumer wobble present AND defaults preserved.
      const reg = globalThis.ModalAnimations;
      assert(reg.enter.wobble && reg.enter.wobble.cls === 'custom-wobble', 'consumer enter.wobble kept');
      assert(reg.enter.pop && reg.enter.shake && reg.enter.slide, 'default enter keys preserved');
      assert(reg.exit.pop && reg.exit.slide, 'default exit keys preserved');

      // 2. Default mount resolves through the registry.
      store.open('plain');
      assert(store.cardClasses()['modal-card-mount'] === true, 'default mount class');
      assert(!store.cardClasses()['modal-card-swap-in'], 'no swap-in on plain mount');
      store.closeAll();

      // 3. BLOCKER: enterAnim slide resolves to a truthy class through
      // cardClasses() even though it names a fixed swap class.
      store.open('slide-in', { enterAnim: 'slide' });
      assert(store.cardClasses()['modal-card-swap-in'] === true,
             "enterAnim:'slide' must yield modal-card-swap-in (was clobbered to false)");
      store.closeAll();

      // 4. Consumer-registered animation resolves.
      store.open('wob', { enterAnim: 'wobble' });
      assert(store.cardClasses()['custom-wobble'] === true, 'custom registered enter animation resolves');
      store.closeAll();

      // 5. BLOCKER: exitAnim slide through close() — class present while
      // closing, splice waits the registry duration.
      store.open('slide-out', { exitAnim: 'slide' });
      store.close();
      assert(store.cardClasses()['modal-card-swap-out'] === true,
             "exitAnim:'slide' must yield modal-card-swap-out during close (was clobbered => frozen card)");
      assert(!store.cardClasses()['modal-card-unmount'], 'default exit class must not double up');
      assert(store.stack.length === 1, 'entry stays on stack while the exit plays');
      await sleep(320);
      assert(store.stack.length === 0, 'entry spliced after the exit duration');

      // 6. Default close animates then splices.
      store.open('bye');
      store.close();
      assert(store.cardClasses()['modal-card-unmount'] === true, 'default exit class while closing');
      await sleep(320);
      assert(store.stack.length === 0, 'default close splices');

      // 7. Two swap() calls within CLOSE_ANIM_MS: the stale phase-2
      // replacement is DROPPED, not resurrected.
      store.open('A');
      store.swap('B');
      store.swap('C');
      await sleep(700);
      assert(store.stack.length === 1, 'double swap leaves ONE entry, got ' + store.stack.length);
      assert(store.stack[0].id === 'C', 'the LAST swap wins, got ' + store.stack[0].id);
      store.closeAll();

      // 8. Documented behavioral delta: double close() inside the animation
      // window pops ONE stacked entry, not two.
      store.open('base');
      store.open('top');
      store.close();
      store.close();
      await sleep(400);
      assert(store.stack.length === 1 && store.stack[0].id === 'base',
             'double close pops one entry (documented delta)');
      store.closeAll();

      // 9. Late FULL replacement of the registry (importmap module case):
      // close() must not throw, falling back to the built-in pop.
      globalThis.ModalAnimations = {};
      store.open('late');
      assert(store.cardClasses()['modal-card-mount'] === true, 'gutted registry falls back to pop on enter');
      let threw = false;
      try { store.close(); } catch (e) { threw = true; }
      assert(!threw, 'close() must not throw when the registry was replaced');
      assert(store.cardClasses()['modal-card-unmount'] === true, 'gutted registry falls back to pop on exit');
      await sleep(320);
      assert(store.stack.length === 0, 'fallback close still splices');

      console.log('ALL-MODAL-STORE-SCENARIOS-PASS');
    })().catch((e) => { console.error('FAIL: ' + (e && e.stack || e)); process.exit(1); });
  JS
end
