# This fixture represents the "bare" formula state before the updater runs -
# i.e., what a newly-released formula looks like before any updater transformation.
# It mirrors the current Formula/acq.rb skeleton.
#
# Synthetic values are used for URLs and checksums; these are test-only and
# must never be treated as real release assets.
#
# NOTE: brew install / brew test are NOT run against this fixture because
# the asset URLs are synthetic.  Those gates are reserved for the real
# post-release formula PR where wheelhouse assets exist.  See #12.
class Acq < Formula
  desc "Run AI coding agents inside a federally-configured sandbox"
  homepage "https://github.com/GSA-TTS/agentic-coding-quickstart"

  url "https://github.com/GSA-TTS/agentic-coding-quickstart/archive/refs/tags/v9.9.9-fixture.tar.gz"
  sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  license "CC0-1.0"

  depends_on :macos
  depends_on "GSA-TTS/tap/microsandbox-acq"
  depends_on "python@3.13"

  resource "provider-input-validator-wheelhouse-arm64" do
    url "https://github.com/GSA-TTS/agentic-coding-quickstart/releases/download/v9.9.9-fixture/provider-input-validator-wheelhouse-macos-arm64.tar.gz"
    sha256 "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  end

  resource "provider-input-validator-wheelhouse-x86-64" do
    url "https://github.com/GSA-TTS/agentic-coding-quickstart/releases/download/v9.9.9-fixture/provider-input-validator-wheelhouse-macos-x86_64.tar.gz"
    sha256 "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  end

  def install
    libexec.install "acq", "acq.backends"
    (libexec/"scripts").install "scripts/setup-provider-input-validator",
                                "scripts/provider-input-validator-requirements-macos.txt"
    resource("provider-input-validator-wheelhouse-arm64").stage do
      (libexec/"scripts/provider-input-validator-wheelhouse/macos-arm64").install Dir["*"]
    end
    resource("provider-input-validator-wheelhouse-x86-64").stage do
      (libexec/"scripts/provider-input-validator-wheelhouse/macos-x86_64").install Dir["*"]
    end
    # Narrow wrapper: sets ACQ_PROVIDER_INPUT_BOOTSTRAP_PYTHON to the formula-pinned
    # Python 3.13 interpreter, then execs the real acq entry-point in libexec.
    # PATH is NOT modified globally; only the bootstrap variable is injected.
    (bin/"acq").write <<~SH
      #!/bin/bash
      export ACQ_PROVIDER_INPUT_BOOTSTRAP_PYTHON="#{formula_opt_bin("python@3.13")}/python3.13"
      exec "#{libexec}/acq" "$@"
    SH
    (bin/"acq").chmod 0755
  end

  test do
    assert_match "agentic coding quickstart wrapper", shell_output("#{bin}/acq --help")
  end
end
