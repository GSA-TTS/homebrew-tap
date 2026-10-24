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

  url "https://github.com/GSA-TTS/agentic-coding-quickstart/archive/refs/tags/v0.0.0-fixture.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  license "CC0-1.0"

  depends_on "GSA-TTS/tap/microsandbox-acq"

  def install
    libexec.install "acq", "acq.backends"
    bin.install_symlink libexec/"acq"
  end

  test do
    assert_match "agentic coding quickstart wrapper", shell_output("#{bin}/acq --help")
  end
end
