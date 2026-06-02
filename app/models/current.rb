# Request- and job-scoped context. ActiveSupport::CurrentAttributes auto-resets
# between requests (Rack middleware) and between Sidekiq/ActiveJob jobs.
#
#   - `Current.user` — set by the engine's set_current_context before_action so
#     downstream code (loggers, audit) can attribute work to the viewer without
#     threading params through every layer.
#
# Baseline shipped by studio-engine. Apps that need more request-scoped state
# (e.g. turf-monster's `outbound_source` + admin vault-state memo) OVERRIDE this
# whole file — the non-isolated engine lets the host's app/models/current.rb win,
# and a subclass-style `attribute` list simply replaces this one.
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end
