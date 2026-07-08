# frozen_string_literal: true

require "bundler/setup"
ENV["RAILS_ENV"] ||= "test"
require_relative "../dummy/config/environment"
require "minitest/autorun"
require "active_support/test_case"

# Studio.routes draws the model-page protocol routes into every consuming host
# app. This asserts they resolve under the dummy app's router with host-level
# helpers (no engine prefix — this is a non-isolated engine), and that `random`
# is drawn BEFORE the `:id` catch-all so it is not swallowed as an identifier.
class ModelPageRoutesTest < ActiveSupport::TestCase
  def routes
    Rails.application.routes.url_helpers
  end

  test "studio_model_path draws /models/:model/:id under the host router" do
    assert_equal "/models/release/rel-x", routes.studio_model_path("release", "rel-x")
  end

  test "studio_model_random_path draws /models/:model/random" do
    assert_equal "/models/release/random", routes.studio_model_random_path("release")
  end

  # The `random` route must be DRAWN before the `:id` catch-all, otherwise
  # /models/release/random resolves as #show with id="random". Inspect the route
  # table's path specs directly (recognize_path would try to load the controller,
  # which the minimal dummy app can't).
  test "random is drawn before the :id catch-all" do
    specs = Rails.application.routes.routes.map { |r| r.path.spec.to_s }
    random_index = specs.index { |s| s.include?("/models/:model/random") }
    id_index     = specs.index { |s| s.include?("/models/:model/:id") }

    refute_nil random_index, "expected a /models/:model/random route to be drawn"
    refute_nil id_index, "expected a /models/:model/:id route to be drawn"
    assert random_index < id_index, "random route must precede the :id catch-all"
  end
end
