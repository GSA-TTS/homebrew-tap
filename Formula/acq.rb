class Acq < Formula
  desc "Run AI coding agents inside a federally-configured sandbox"
  homepage "https://github.com/GSA-TTS/agentic-coding-quickstart"

  url "https://github.com/GSA-TTS/agentic-coding-quickstart/archive/refs/tags/v4.1.0.tar.gz"
  sha256 "ac8075a94d0b2be9b8b3c4aaecbb5026764613b7883419d36c80ea498d72b912"

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
