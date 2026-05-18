source "https://rubygems.org"

gemspec

# nokogiri 1.18.10 has 3 CVEs (1 HIGH regex-backtracking + 2 MEDIUM
# in XSLT / xmlC14NExecute). Fix is `>= 1.19.3` but nokogiri 1.19.x
# requires Ruby 3.2+. The ecosystem currently runs on Ruby 3.1.7;
# bumping Ruby is a separate effort (across both Rails apps).
#
# **Important**: this gem does NOT declare nokogiri as a runtime
# dependency in its gemspec — nokogiri comes into the consuming
# Rails app via Rails itself. Consumers running Rails on a Ruby
# version that supports nokogiri 1.19.x will resolve it. The
# studio-engine gem's own Gemfile.lock (this repo's dev env) is the
# only place still on 1.18.10.
#
# Tracked in SECURITY-AUDIT-2026-05-17.md. When the ecosystem bumps
# to Ruby 3.2+, add: gem "nokogiri", ">= 1.19.3", group: :development
