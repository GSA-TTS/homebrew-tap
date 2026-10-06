class Acq < Formula
  desc "Run AI coding agents inside a federally-configured sandbox"
  homepage "https://github.com/GSA-TTS/agentic-coding-quickstart"
  url "https://github.com/GSA-TTS/agentic-coding-quickstart/archive/refs/tags/v4.0.1.tar.gz"
  sha256 "981870c760d1b517964dda6743e889c0a74218c25c9c58b64ed96b6bf1edf430"
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
