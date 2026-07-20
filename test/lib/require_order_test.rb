# frozen_string_literal: true

require "test_helper"

# INVARIANT: every test file must set up bundler before it requires anything
# else — either via `test_helper` (which calls `require "bundler/setup"`) or by
# requiring `bundler/setup` directly, as the dummy-app integration tests do.
#
# Anything required BEFORE that resolves through plain RubyGems instead of the
# bundle, which fails two different ways on a clean machine:
#
#   * a bundled gem is not on the default gem path at all
#     -> "cannot load such file -- action_view (LoadError)"
#   * a DEFAULT gem (uri, erb, json, logger, stringio, timeout, psych, date...)
#     activates its built-in version, then bundler refuses the pinned one
#     -> "You have already activated uri 0.13.3, but your Gemfile requires uri 1.1.1"
#
# Both were live in this suite until the engine got its own CI lane; both were
# invisible on a dev Mac, where the consumer apps' gems are installed globally.
# "It's only stdlib" is NOT a safe exemption — `uri` is stdlib and still broke.
#
# Note this asserts the PROPERTY (bundler is set up first), not one spelling of
# it: an earlier draft demanded `test_helper` specifically and false-flagged the
# four integration tests that legitimately require `bundler/setup` themselves.
class RequireOrderTest < Minitest::Test
  ANY_REQUIRE = /^\s*(?:require|require_relative)\s+["'](.+?)["']/
  # `test_helper`, `../test_helper`, `../../test_helper`, or `bundler/setup`.
  BUNDLER_SETUP = %r{\A(?:[./]*test_helper|bundler/setup)\z}

  def test_every_test_file_sets_up_bundler_before_any_other_require
    offenders = test_files.filter_map do |file|
      requires = File.readlines(file).filter_map { |line| line[ANY_REQUIRE, 1] }
      next "#{rel(file)} (requires nothing at all)" if requires.empty?

      first = requires.first
      next if first.match?(BUNDLER_SETUP)

      "#{rel(file)} requires #{first.inspect} before bundler is set up"
    end

    assert_empty offenders,
                 "these test files require something before bundler/setup, so the require " \
                 "resolves outside the bundle:\n  " + offenders.join("\n  ")
  end

  # Guards the guard: if the glob ever stops matching, the assertion above
  # passes vacuously over an empty list — green while checking nothing.
  def test_the_scan_actually_finds_test_files
    assert_operator test_files.length, :>=, 20,
                    "expected to scan the engine's test files, found #{test_files.length} — " \
                    "the glob is broken and this guard is checking nothing"
  end

  private

  def test_root
    @test_root ||= File.expand_path("../..", __dir__)
  end

  def test_files
    @test_files ||= Dir.glob(File.join(test_root, "test", "**", "*_test.rb")).sort
  end

  def rel(file)
    file.sub("#{test_root}/", "")
  end
end
