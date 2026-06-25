source "https://rubygems.org"

gemspec

# nokogiri: historically pinned to 1.18.10 here while the ecosystem was on
# Ruby 3.1.7 (nokogiri >= 1.19.x requires Ruby 3.2+). The ecosystem is now on
# Ruby 3.3.11, so a plain `bundle update` resolves the patched nokogiri
# (>= 1.19.3, the line that fixed 3 CVEs: 1 HIGH regex-backtracking + 2 MEDIUM
# XSLT / xmlC14NExecute). This gem still does NOT declare nokogiri as a runtime
# dependency — it arrives via Rails in the consuming app. Tracked in
# SECURITY-AUDIT-2026-05-17.md.

group :development, :test do
  # SQLite drives the test/dummy Rails app's in-memory database (see
  # test/integration/engine_rails_8_1_boot_test.rb), which boots the engine
  # against a real Rails app so we catch Rails-version incompatibilities in the
  # engine's ActiveRecord/Railtie surfaces. Not a runtime dependency — the
  # consuming apps bring their own database adapter. Rails 8.1 needs sqlite3 ~> 2.1.
  gem "sqlite3", ">= 2.1"
end
