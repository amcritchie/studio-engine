# frozen_string_literal: true

require_relative "../../test_helper"
# The concern lives under app/ (Rails-autoloaded in a host app); load it directly
# for the pure-Ruby harness. It only needs ActiveSupport::Concern + Studio::Cable,
# both already required.
require_relative "../../../app/models/concerns/studio/broadcastable"

class Studio::BroadcastableTest < Minitest::Test
  BROADCASTS = %i[broadcast_replace_to broadcast_update_to broadcast_append_to
                  broadcast_prepend_to broadcast_remove_to].freeze
  WRAPPERS   = %i[safe_broadcast_replace_to safe_broadcast_update_to safe_broadcast_append_to
                  safe_broadcast_prepend_to safe_broadcast_remove_to].freeze

  # Stand-in for a Turbo-broadcasting model: it has the broadcast_*_to methods
  # turbo-rails would provide — here they RAISE, simulating a cable failure.
  class RaisingModel
    include Studio::Broadcastable
    attr_reader :calls
    def initialize = @calls = []
    BROADCASTS.each { |m| define_method(m) { |*_a, **_k| @calls << m; raise "cable down" } }
  end

  class RecordingModel
    include Studio::Broadcastable
    attr_reader :calls
    def initialize = @calls = []
    BROADCASTS.each { |m| define_method(m) { |*a, **k| @calls << [m, a, k]; :sent } }
  end

  def test_safe_wrappers_swallow_a_raising_broadcast
    model = RaisingModel.new
    WRAPPERS.each do |w|
      assert_nil model.public_send(w, [:board], target: "x"), "#{w} must swallow the cable failure"
    end
    assert_equal BROADCASTS.size, model.calls.size, "each wrapper still invoked its underlying broadcast"
  end

  def test_safe_wrappers_delegate_args_and_return_value_on_success
    model = RecordingModel.new
    assert_equal :sent, model.safe_broadcast_replace_to([:board], target: "card_1", partial: "tasks/card")
    method, args, kwargs = model.calls.first
    assert_equal :broadcast_replace_to, method
    assert_equal [[:board]], args
    assert_equal "card_1", kwargs[:target]
    assert_equal "tasks/card", kwargs[:partial]
  end
end
