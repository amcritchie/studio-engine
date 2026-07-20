# frozen_string_literal: true

require "test_helper"
require "open3"
require "tempfile"

# REGRESSION (task engine-ci-runs-own-suite, review round 2): the first attempt
# of the engine CI lane enumerated the suite as a curated 25-file list while
# the tree held 26 — test/lib/studio/ui_primitives_test.rb existed but never
# ran, and the old guard compared the log only against the files the runner
# ANNOUNCED, so it was structurally blind to the miss.
#
# The fix asserts the PROPERTY, not the spellings: the runner derives its file
# set from the tree glob (inclusion by construction — no list to curate), and
# bin/suite-guard independently re-globs the tree, so a test file that exists
# but never ran is a hard failure. These tests are the mutations: each one
# proves the guard actually trips on the failure shape it claims to catch.
class ReleaseCheckGuardTest < Minitest::Test
  ROOT  = File.expand_path("../..", __dir__)
  GUARD = File.join(ROOT, "bin", "suite-guard")
  RELEASE_CHECK = File.join(ROOT, "bin", "release-check")

  # The exact file the round-one curated list omitted.
  OMITTED_IN_ROUND_ONE = "test/lib/studio/ui_primitives_test.rb"

  CLEAN_SUMMARY = "2 runs, 6 assertions, 0 failures, 0 errors, 0 skips"

  # --- the manifest is the tree, not a list -------------------------------

  def test_manifest_equals_an_independent_tree_glob
    expected = Dir.glob("test/**/*_test.rb", base: ROOT)
                  .reject { |f| f.start_with?("test/dummy/") }
                  .sort
    assert_equal expected, guard_lines("--manifest"),
                 "bin/suite-guard --manifest must mirror the tree glob exactly"
    assert_includes expected, OMITTED_IN_ROUND_ONE
    assert_includes expected, "test/lib/release_check_guard_test.rb",
                    "the manifest must include this very file — new tests are in by construction"
  end

  def test_manifest_picks_up_a_newly_added_test_file_by_construction
    probe_rel = "test/lib/zz_manifest_inclusion_probe_test.rb"
    probe = File.join(ROOT, probe_rel)
    File.write(probe, <<~RUBY)
      require "test_helper"

      class ZzManifestInclusionProbeTest < Minitest::Test
        def test_probe
          assert true
        end
      end
    RUBY
    assert_includes guard_lines("--manifest"), probe_rel,
                    "a brand-new test file must appear in the manifest with no list edit"
  ensure
    File.delete(probe) if File.exist?(probe)
  end

  def test_release_check_list_is_the_same_manifest
    stdout, stderr, status = Open3.capture3(clean_env, RELEASE_CHECK, "--list", chdir: ROOT)
    assert status.success?, "bin/release-check --list failed: #{stderr}"
    assert_equal guard_lines("--manifest"), stdout.split("\n"),
                 "the runner must enumerate from the same manifest the guard checks"
  end

  def test_hide_hook_filters_the_run_list_but_never_the_manifest
    env = { "RELEASE_CHECK_HIDE" => OMITTED_IN_ROUND_ONE }
    refute_includes guard_lines("--run-list", env: env), OMITTED_IN_ROUND_ONE,
                    "RELEASE_CHECK_HIDE must remove the file from the run list"
    assert_includes guard_lines("--manifest", env: env), OMITTED_IN_ROUND_ONE,
                    "RELEASE_CHECK_HIDE must NEVER remove the file from the guard's manifest"
  end

  # --- the guard trips on every miss shape --------------------------------

  def test_guard_passes_a_log_covering_the_whole_manifest
    stdout, stderr, status = check_log(log_for(manifest))
    assert status.success?, "guard rejected a complete clean log: #{stderr}"
    assert_match(/tree fully covered/, stdout)
  end

  def test_guard_trips_when_a_tree_file_never_ran
    # THE round-2 blocker, reproduced: a log from a run that covered everything
    # except ui_primitives_test — 25 of 26 green files, all summaries clean.
    _stdout, stderr, status = check_log(log_for(manifest - [OMITTED_IN_ROUND_ONE]))
    refute status.success?, "guard passed a log missing #{OMITTED_IN_ROUND_ONE}"
    assert_match(/NEVER RAN/, stderr)
    assert_match(/#{Regexp.escape(OMITTED_IN_ROUND_ONE)}/, stderr,
                 "the guard must name the file that never ran")
  end

  def test_guard_trips_on_an_announced_file_missing_from_the_tree
    ghost = "test/lib/studio/deleted_long_ago_test.rb"
    _stdout, stderr, status = check_log(log_for(manifest + [ghost]))
    refute status.success?
    assert_match(/not in the tree/, stderr)
    assert_match(/#{Regexp.escape(ghost)}/, stderr)
  end

  def test_guard_trips_on_a_skip
    mutant = manifest.first
    log = log_for(manifest, mutate: { mutant => "2 runs, 6 assertions, 0 failures, 0 errors, 1 skips" })
    _stdout, stderr, status = check_log(log)
    refute status.success?
    assert_match(/SKIPPED/, stderr)
    assert_match(/#{Regexp.escape(mutant)}/, stderr)
  end

  def test_guard_trips_on_zero_runs
    mutant = manifest.first
    log = log_for(manifest, mutate: { mutant => "0 runs, 0 assertions, 0 failures, 0 errors, 0 skips" })
    _stdout, stderr, status = check_log(log)
    refute status.success?
    assert_match(/ZERO tests/, stderr)
  end

  def test_guard_trips_on_a_missing_summary
    log = log_for(manifest, mutate: { manifest.last => nil })
    _stdout, stderr, status = check_log(log)
    refute status.success?
    assert_match(/no summary/, stderr)
  end

  private

  # Neutralize the session's env in every subprocess: an inherited
  # RELEASE_CHECK_HIDE would make these assertions lie.
  def clean_env
    { "RELEASE_CHECK_HIDE" => nil }
  end

  def run_guard(*args, env: {})
    Open3.capture3(clean_env.merge(env), RbConfig.ruby, GUARD, *args, chdir: ROOT)
  end

  def guard_lines(*args, env: {})
    stdout, stderr, status = run_guard(*args, env: env)
    assert status.success?, "bin/suite-guard #{args.join(' ')} failed: #{stderr}"
    stdout.split("\n")
  end

  def manifest
    @manifest ||= guard_lines("--manifest")
  end

  # A synthetic suite log: every file announced the way bin/release-check
  # announces it, followed by a minitest summary (or none, for the
  # missing-summary mutation).
  def log_for(files, mutate: {})
    files.map do |file|
      summary = mutate.key?(file) ? mutate[file] : CLEAN_SUMMARY
      ["== #{file}", "Run options: --seed 1234", summary].compact.join("\n") << "\n"
    end.join
  end

  def check_log(contents)
    Tempfile.create("suite-guard-test") do |f|
      f.write(contents)
      f.flush
      return run_guard(f.path)
    end
  end
end
