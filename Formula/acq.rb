class Acq < Formula
  desc "Run AI coding agents inside a federally-configured sandbox"
  homepage "https://github.com/GSA-TTS/agentic-coding-quickstart"
  url "https://github.com/GSA-TTS/agentic-coding-quickstart/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "dba9fdcb56ce9b1f18f9a368aa8897e08f938b1de43ad29d2336d991902697a4"
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
