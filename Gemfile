source "https://rubygems.org"

gemspec

# nokogiri 1.18.10 had 3 CVEs (1 HIGH regex-backtracking + 2 MEDIUM
# in XSLT / xmlC14NExecute). The active Rails apps now run Ruby 3.3.11,
# so the engine dev lockfile can resolve nokogiri >= 1.19.3.
#
# **Important**: this gem does NOT declare nokogiri as a runtime
# dependency in its gemspec — nokogiri comes into the consuming
# Rails app via Rails itself. Consumers running Rails on a Ruby
# version that supports nokogiri 1.19.x will resolve it.
