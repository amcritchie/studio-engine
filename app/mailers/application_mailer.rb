class ApplicationMailer < ActionMailer::Base
  # Resolved per-message (proc default) so it picks up Studio.mailer_from set in
  # the host's config/initializers/studio.rb, with an ENV fallback. No layout is
  # forced — ActionMailer renders bare if the host ships no mailer layout, and a
  # host that defines its own ApplicationMailer (e.g. turf-monster) wins outright.
  default from: -> { Studio.mailer_from || ENV["MAILER_FROM"] || "McRitchie Studio <team@mcritchie.studio>" }
end
