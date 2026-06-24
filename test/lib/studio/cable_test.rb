# frozen_string_literal: true

require_relative "../../test_helper"

class Studio::CableTest < Minitest::Test
  def test_safe_broadcast_returns_block_value_on_success
    assert_equal :ok, Studio::Cable.safe_broadcast { :ok }
  end

  def test_safe_broadcast_swallows_a_standard_error
    # If it didn't swallow, the raise would propagate and ERROR this test.
    assert_nil(Studio::Cable.safe_broadcast { raise "boom" })
  end

  # The SEV-1 regression. A missing/misconfigured cable adapter raises
  # Gem::LoadError on the first broadcast — a ScriptError, NOT a StandardError —
  # which a plain `rescue StandardError` let escape an after_commit and 500 every
  # task write in prod. safe_broadcast MUST swallow the ScriptError hierarchy.
  def test_safe_broadcast_swallows_a_script_error_gem_load_error
    refute Gem::LoadError.ancestors.include?(StandardError), "premise: Gem::LoadError is not a StandardError"
    assert Gem::LoadError.ancestors.include?(ScriptError), "premise: Gem::LoadError is a ScriptError"
    assert_nil(Studio::Cable.safe_broadcast { raise Gem::LoadError, "redis is not part of the bundle" })
  end
end
