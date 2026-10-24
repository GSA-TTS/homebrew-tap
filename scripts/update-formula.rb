#!/usr/bin/env ruby
# frozen_string_literal: true

# update-formula.rb - Idempotent updater for Formula/acq.rb
#
# Called by .github/workflows/update-acq-formula.yml (Update formula step) and
# directly by tests.  All inputs are environment variables so the script can be
# exercised in isolation without touching the filesystem path used in production.
#
# Required environment variables:
#   FORMULA_PATH               - path to the formula file to update (default: Formula/acq.rb)
#   TARBALL_URL                - new source tarball URL
#   SHA256                     - sha256 of the source tarball
#   WHEELHOUSE_ARM64_URL       - URL for the arm64 wheelhouse archive
#   WHEELHOUSE_X86_64_URL      - URL for the x86_64 wheelhouse archive
#   WHEELHOUSE_ARM64_SHA256    - sha256 of the arm64 wheelhouse archive
#   WHEELHOUSE_X86_64_SHA256   - sha256 of the x86_64 wheelhouse archive
#   TAG                        - release tag, used in success message only

path                   = ENV.fetch("FORMULA_PATH",                "Formula/acq.rb")
tarball_url            = ENV.fetch("TARBALL_URL")
sha256                 = ENV.fetch("SHA256")
wheelhouse_arm64_url   = ENV.fetch("WHEELHOUSE_ARM64_URL")
wheelhouse_x86_64_url  = ENV.fetch("WHEELHOUSE_X86_64_URL")
wheelhouse_arm64_sha256  = ENV.fetch("WHEELHOUSE_ARM64_SHA256")
wheelhouse_x86_64_sha256 = ENV.fetch("WHEELHOUSE_X86_64_SHA256")
tag                    = ENV.fetch("TAG", "(unknown)")

formula = File.read(path)

# ---------------------------------------------------------------------------
# 1. Replace top-level url and sha256
# ---------------------------------------------------------------------------

formula.sub!(/^  url\s+["'].+["']$/, %(  url "#{tarball_url}")) ||
  abort("FATAL: Could not find 'url' line to substitute in #{path}")

formula.sub!(/^  sha256\s+["'][0-9a-fA-F]{64}["']$/, %(  sha256 "#{sha256}")) ||
  abort("FATAL: Could not find top-level 'sha256' line to substitute in #{path}")

# ---------------------------------------------------------------------------
# 2. Wheelhouse resource blocks
# ---------------------------------------------------------------------------

resources = <<~RESOURCE
  resource "provider-input-validator-wheelhouse-arm64" do
    url "#{wheelhouse_arm64_url}"
    sha256 "#{wheelhouse_arm64_sha256}"
  end

  resource "provider-input-validator-wheelhouse-x86-64" do
    url "#{wheelhouse_x86_64_url}"
    sha256 "#{wheelhouse_x86_64_sha256}"
  end
RESOURCE

arm_resource = formula.include?('resource "provider-input-validator-wheelhouse-arm64"')
x86_resource = formula.include?('resource "provider-input-validator-wheelhouse-x86-64"')
abort("FATAL: partial wheelhouse resource state in #{path}") unless arm_resource == x86_resource

# Indent resource block: only prepend spaces on non-empty lines to avoid trailing whitespace.
indented_resources = resources.each_line.map { |l| l.chomp.empty? ? "\n" : "  #{l}" }.join.strip + "\n"

if arm_resource
  formula.sub!(
    /  resource "provider-input-validator-wheelhouse-arm64" do.*?^  end\s+  resource "provider-input-validator-wheelhouse-x86-64" do.*?^  end\n/m,
    "  #{indented_resources}"
  ) || abort("FATAL: Could not replace existing wheelhouse resource blocks in #{path}")
else
  formula.sub!(/\n  license .+\n/, "\n  license \"CC0-1.0\"\n\n  #{indented_resources}") ||
    abort("FATAL: Could not find 'license' line to inject resource blocks in #{path}")
end

# ---------------------------------------------------------------------------
# 3. Scripts install path
# ---------------------------------------------------------------------------

scripts_install       = formula.include?('(libexec/"scripts").install')
setup_mentioned       = formula.include?('scripts/setup-provider-input-validator')
requirements_mentioned = formula.include?('scripts/provider-input-validator-requirements-macos.txt')

if scripts_install || setup_mentioned || requirements_mentioned
  abort("FATAL: partial validator scripts install state in #{path}") unless scripts_install && setup_mentioned && requirements_mentioned
else
  formula.sub!(
    /    libexec\.install "acq", "acq\.backends"/,
    %(    libexec.install "acq", "acq.backends"\n) +
    %(    (libexec/"scripts").install "scripts/setup-provider-input-validator",\n) +
    %(                                "scripts/provider-input-validator-requirements-macos.txt")
  ) || abort("FATAL: Could not find libexec.install 'acq' line in #{path}")
end

# ---------------------------------------------------------------------------
# 4. Wheelhouse staging blocks
# ---------------------------------------------------------------------------

arm_stage = formula.include?('resource("provider-input-validator-wheelhouse-arm64").stage')
x86_stage = formula.include?('resource("provider-input-validator-wheelhouse-x86-64").stage')
abort("FATAL: partial wheelhouse staging state in #{path}") unless arm_stage == x86_stage

unless arm_stage
  formula.sub!(
    /("scripts\/provider-input-validator-requirements-macos\.txt"\n)/,
    "\\1" +
    %(    resource("provider-input-validator-wheelhouse-arm64").stage do\n) +
    %(      (libexec/"scripts/provider-input-validator-wheelhouse/macos-arm64").install Dir["*"]\n) +
    %(    end\n) +
    %(    resource("provider-input-validator-wheelhouse-x86-64").stage do\n) +
    %(      (libexec/"scripts/provider-input-validator-wheelhouse/macos-x86_64").install Dir["*"]\n) +
    %(    end\n)
  ) || abort("FATAL: Could not inject wheelhouse staging blocks in #{path}")
end

# ---------------------------------------------------------------------------
# 5. python@3.13 dependency
# ---------------------------------------------------------------------------

unless formula.include?('depends_on "python@3.13"')
  formula.sub!(
    /^  depends_on "GSA-TTS\/tap\/microsandbox-acq"\n/,
    %(  depends_on "GSA-TTS/tap/microsandbox-acq"\n  depends_on "python@3.13"\n)
  ) || abort("FATAL: Could not find microsandbox-acq depends_on line to inject python@3.13 in #{path}")
end

# ---------------------------------------------------------------------------
# 6. macOS-only constraint
# ---------------------------------------------------------------------------

unless formula.include?("depends_on :macos")
  formula.sub!(
    /^  depends_on "python@3\.13"\n/,
    %(  depends_on "python@3.13"\n  depends_on :macos\n)
  ) || abort("FATAL: Could not find python@3.13 depends_on line to inject depends_on :macos in #{path}")
end

# Homebrew orders the external tap dependency first, then the macOS constraint,
# then the versioned Python dependency. All dependencies precede resources.
# Normalize the complete group so fresh and transformed formulas converge.
formula.gsub!(/^  depends_on :macos\n/, "")
formula.gsub!(/^  depends_on "GSA-TTS\/tap\/microsandbox-acq"\n/, "")
formula.gsub!(/^  depends_on "python@3\.13"\n/, "")
formula.sub!(
  /^  license "CC0-1\.0"\n/,
  %(  license "CC0-1.0"\n\n) +
  %(  depends_on "GSA-TTS/tap/microsandbox-acq"\n) +
  %(  depends_on :macos\n) +
  %(  depends_on "python@3.13"\n)
) || abort("FATAL: Could not normalize dependency order in #{path}")

# ---------------------------------------------------------------------------
# 7. Narrow bin/acq wrapper
# ---------------------------------------------------------------------------

wrapper_write = formula.include?('(bin/"acq").write')
wrapper_env   = formula.include?("ACQ_PROVIDER_INPUT_BOOTSTRAP_PYTHON")
wrapper_exec  = formula.include?('exec "#{libexec}/acq" "$@"')

if wrapper_write || wrapper_env || wrapper_exec
  abort("FATAL: partial acq wrapper state in #{path}") unless wrapper_write && wrapper_env && wrapper_exec
else
  formula.sub!(
    /    bin\.install_symlink libexec\/"acq"\n/,
    %(    # Narrow wrapper: sets ACQ_PROVIDER_INPUT_BOOTSTRAP_PYTHON to the formula-pinned\n) +
    %(    # Python 3.13 interpreter, then execs the real acq entry-point in libexec.\n) +
    %(    # PATH is NOT modified globally; only the bootstrap variable is injected.\n) +
    %(    (bin/"acq").write <<~SH\n) +
    %(      #!/bin/bash\n) +
    %(      export ACQ_PROVIDER_INPUT_BOOTSTRAP_PYTHON="\#{formula_opt_bin("python@3.13")}/python3.13"\n) +
    %(      exec "\#{libexec}/acq" "$@"\n) +
    %(    SH\n) +
    %(    (bin/"acq").chmod 0755\n)
  ) || abort("FATAL: Could not inject bin/acq wrapper (expected bin.install_symlink or existing wrapper) in #{path}")
end

# ---------------------------------------------------------------------------
# Write result
# ---------------------------------------------------------------------------

formula.gsub!(/\n{3,}/, "\n\n")
File.write(path, formula)
$stdout.puts "Formula #{path} updated for #{tag}."
