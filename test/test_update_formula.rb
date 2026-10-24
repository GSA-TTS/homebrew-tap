#!/usr/bin/env ruby
# frozen_string_literal: true

# test/test_update_formula.rb
#
# Deterministic unit tests for scripts/update-formula.rb.
# Run with:  ruby test/test_update_formula.rb
#
# All tests operate on in-memory copies of the committed fixtures so the
# working-tree formula is never mutated.
#
# The suite proves:
#   1. Full transformation matches the committed post fixture (golden-file test)
#   2. Transformation is idempotent (run twice -> same output)
#   3. Partial wheelhouse resource state fails closed
#   4. Partial scripts install state fails closed
#   5. Partial wheelhouse staging state fails closed
#   6. Partial wrapper state fails closed
#   7. Missing ONE asset (arm64 URL absent) -> no-op (asset-check gate; updater
#      not invoked - tested via the workflow shell guard, not the ruby script)
#      Note: the Ruby updater itself gets complete env or aborts on missing vars.
#      The "missing asset -> no-op" gate is the workflow-level assets_ready check
#      (tested here by verifying ENV.fetch raises on a missing key).
#   8. No trailing whitespace in the generated output

require "minitest/autorun"
require "tmpdir"
require "fileutils"

# ---------------------------------------------------------------------------
# Constants - all fixture inputs are synthetic and committed
# ---------------------------------------------------------------------------

SCRIPT = File.expand_path("../../scripts/update-formula.rb", __FILE__)
FIXTURE_PRE  = File.expand_path("../fixtures/acq.pre.rb",  __FILE__)
FIXTURE_POST = File.expand_path("../fixtures/acq.post.rb", __FILE__)

TAG                     = "v9.9.9-fixture"
TARBALL_URL             = "https://github.com/GSA-TTS/agentic-coding-quickstart/archive/refs/tags/#{TAG}.tar.gz"
SHA256                  = "a" * 64
WHEELHOUSE_ARM64_URL    = "https://github.com/GSA-TTS/agentic-coding-quickstart/releases/download/#{TAG}/provider-input-validator-wheelhouse-macos-arm64.tar.gz"
WHEELHOUSE_X86_64_URL   = "https://github.com/GSA-TTS/agentic-coding-quickstart/releases/download/#{TAG}/provider-input-validator-wheelhouse-macos-x86_64.tar.gz"
WHEELHOUSE_ARM64_SHA256  = "b" * 64
WHEELHOUSE_X86_64_SHA256 = "c" * 64

FULL_ENV = {
  "TARBALL_URL"             => TARBALL_URL,
  "SHA256"                  => SHA256,
  "WHEELHOUSE_ARM64_URL"    => WHEELHOUSE_ARM64_URL,
  "WHEELHOUSE_X86_64_URL"   => WHEELHOUSE_X86_64_URL,
  "WHEELHOUSE_ARM64_SHA256" => WHEELHOUSE_ARM64_SHA256,
  "WHEELHOUSE_X86_64_SHA256"=> WHEELHOUSE_X86_64_SHA256,
  "TAG"                     => TAG,
}.freeze

# ---------------------------------------------------------------------------
# Helper: run the updater script against a copy of a source string
# ---------------------------------------------------------------------------

def run_updater(source_content, env_overrides = {})
  Dir.mktmpdir("acq_test_") do |tmpdir|
    path = File.join(tmpdir, "acq.rb")
    File.write(path, source_content)

    env = FULL_ENV.merge("FORMULA_PATH" => path).merge(env_overrides)

    # Spawn a subprocess that loads the script in the env above.
    # Redirect stderr to a sink file to avoid cyclic fd redirection.
    sink_path = File.join(tmpdir, "sink.txt")
    pid = spawn(env, RbConfig.ruby, SCRIPT,
                out: sink_path,
                err: sink_path)
    _, status = Process.waitpid2(pid)

    output = File.read(path)
    [output, status.exitstatus]
  end
end

# run_updater for cases where we need separate stdout/stderr
def run_updater_with_output(source_content, env_overrides = {})
  Dir.mktmpdir("acq_test_") do |tmpdir|
    path = File.join(tmpdir, "acq.rb")
    File.write(path, source_content)

    env = FULL_ENV.merge("FORMULA_PATH" => path).merge(env_overrides)

    stdout_r, stdout_w = IO.pipe
    stderr_r, stderr_w = IO.pipe

    pid = spawn(env, RbConfig.ruby, SCRIPT, out: stdout_w, err: stderr_w)
    stdout_w.close
    stderr_w.close
    _, status = Process.waitpid2(pid)

    stdout = stdout_r.read; stdout_r.close
    stderr = stderr_r.read; stderr_r.close
    output = File.read(path)

    [output, status.exitstatus, stdout, stderr]
  end
end

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestUpdateFormula < Minitest::Test
  def pre_formula
    File.read(FIXTURE_PRE)
  end

  def post_formula
    File.read(FIXTURE_POST)
  end

  # -------------------------------------------------------------------------
  # Test 1: Full transformation matches committed golden fixture
  # -------------------------------------------------------------------------
  def test_full_transform_matches_golden_fixture
    result, exit_status = run_updater(pre_formula)
    assert_equal 0, exit_status, "Updater exited non-zero"
    assert_equal post_formula, result,
      "Generated formula does not match committed fixture test/fixtures/acq.post.rb\n" \
      "Diff:\n#{unified_diff(post_formula, result)}"
  end

  # -------------------------------------------------------------------------
  # Test 2: Idempotency - running twice produces identical output
  # -------------------------------------------------------------------------
  def test_idempotent
    first,  s1 = run_updater(pre_formula)
    assert_equal 0, s1, "First run exited non-zero"

    second, s2 = run_updater(first)
    assert_equal 0, s2, "Second run exited non-zero"

    assert_equal first, second,
      "Second run produced different output - transformation is not idempotent"
  end

  # -------------------------------------------------------------------------
  # Test 3: Partial wheelhouse resource state fails closed
  # -------------------------------------------------------------------------
  def test_partial_wheelhouse_resource_aborts
    # Inject only the arm64 resource block, not the x86-64 one.
    partial = pre_formula.sub(
      /\n  license .+\n/,
      "\n  license \"CC0-1.0\"\n\n" \
      "  resource \"provider-input-validator-wheelhouse-arm64\" do\n" \
      "    url \"https://example.com/arm64.tar.gz\"\n" \
      "    sha256 \"#{"d" * 64}\"\n" \
      "  end\n"
    )
    _output, exit_status, _stdout, stderr = run_updater_with_output(partial)
    refute_equal 0, exit_status, "Expected non-zero exit on partial wheelhouse resource state"
    assert_match(/FATAL.*partial wheelhouse resource state/i, stderr,
      "Expected FATAL message about partial wheelhouse resource state")
  end

  # -------------------------------------------------------------------------
  # Test 4: Partial scripts install state fails closed
  # -------------------------------------------------------------------------
  def test_partial_scripts_install_aborts
    # Inject setup_mentioned but not scripts_install or requirements_mentioned.
    # We simulate this by adding a mention of the setup script path but not
    # the (libexec/"scripts").install call.
    partial = pre_formula.sub(
      /    libexec\.install "acq", "acq\.backends"\n/,
      "    libexec.install \"acq\", \"acq.backends\"\n" \
      "    # scripts/setup-provider-input-validator mentioned but not installed\n"
    )
    _output, exit_status, _stdout, stderr = run_updater_with_output(partial)
    refute_equal 0, exit_status, "Expected non-zero exit on partial scripts install state"
    assert_match(/FATAL.*partial validator scripts install state/i, stderr,
      "Expected FATAL message about partial scripts install state")
  end

  # -------------------------------------------------------------------------
  # Test 5: Partial wheelhouse staging state fails closed
  # -------------------------------------------------------------------------
  def test_partial_wheelhouse_staging_aborts
    # Start from the already-transformed formula so scripts are present.
    # Inject arm64 staging but not x86-64 staging.
    partial = post_formula.sub(
      /    resource\("provider-input-validator-wheelhouse-x86-64"\)\.stage do\n.*?    end\n/m,
      ""
    )
    _output, exit_status, _stdout, stderr = run_updater_with_output(partial)
    refute_equal 0, exit_status, "Expected non-zero exit on partial wheelhouse staging state"
    assert_match(/FATAL.*partial wheelhouse staging state/i, stderr,
      "Expected FATAL message about partial wheelhouse staging state")
  end

  # -------------------------------------------------------------------------
  # Test 6: Partial wrapper state fails closed
  # -------------------------------------------------------------------------
  def test_partial_wrapper_aborts
    # Inject only the wrapper write, not the env export or exec line.
    partial = pre_formula.sub(
      /    bin\.install_symlink libexec\/"acq"\n/,
      "    (bin/\"acq\").write \"#!/bin/bash\\n\"\n"
    )
    _output, exit_status, _stdout, stderr = run_updater_with_output(partial)
    refute_equal 0, exit_status, "Expected non-zero exit on partial wrapper state"
    assert_match(/FATAL.*partial acq wrapper state/i, stderr,
      "Expected FATAL message about partial wrapper state")
  end

  # -------------------------------------------------------------------------
  # Test 7: Missing required env var -> script fails closed (asset-check gate)
  #
  # The workflow-level asset check (assets_ready=false) prevents the Ruby
  # updater from running at all when a wheelhouse asset is absent.  We verify
  # here that if the env var is outright missing (e.g. due to a workflow bug),
  # ENV.fetch raises a KeyError so the script still fails closed rather than
  # silently succeeding with an empty URL.
  # -------------------------------------------------------------------------
  def test_missing_env_var_fails_closed
    _output, exit_status, _stdout, _stderr = run_updater_with_output(
      pre_formula,
      { "WHEELHOUSE_ARM64_URL" => nil }  # nil causes the key to be unset in spawn env
    )
    # Ruby's ENV.fetch raises KeyError -> exits non-zero
    refute_equal 0, exit_status,
      "Expected non-zero exit when a required env var is absent"
  end

  # -------------------------------------------------------------------------
  # Test 8: No trailing whitespace in generated output
  # -------------------------------------------------------------------------
  def test_no_trailing_whitespace
    result, exit_status = run_updater(pre_formula)
    assert_equal 0, exit_status, "Updater exited non-zero"

    violations = []
    result.each_line.with_index(1) do |line, lineno|
      violations << "  line #{lineno}: #{line.chomp.inspect}" if line.match?(/[ \t]+\n$/)
    end

    assert_empty violations,
      "Trailing whitespace found in generated formula:\n#{violations.join("\n")}"
  end

  # -------------------------------------------------------------------------
  # Helpers
  # -------------------------------------------------------------------------
  private

  def unified_diff(expected, actual)
    require "tempfile"
    a = Tempfile.new("expected")
    b = Tempfile.new("actual")
    a.write(expected); a.flush
    b.write(actual);   b.flush
    IO.popen(["diff", "-u", "--label", "expected", a.path, "--label", "actual", b.path]) do |io|
      io.read
    end
  ensure
    a&.close!
    b&.close!
  end
end
