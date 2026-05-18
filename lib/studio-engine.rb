# Entry point for the `studio-engine` gem. The actual code lives in
# `lib/studio.rb` (which exports the `Studio` module). This shim exists so
# `gem "studio-engine"` in a Gemfile loads correctly without consumers
# needing to add `require: "studio"`.
require_relative "studio"
