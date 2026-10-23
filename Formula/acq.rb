class Acq < Formula
  desc "Run AI coding agents inside a federally-configured sandbox"
  homepage "https://github.com/GSA-TTS/agentic-coding-quickstart"

  url "https://github.com/GSA-TTS/agentic-coding-quickstart/archive/refs/tags/v4.1.1.tar.gz"
  sha256 "5db290d1a1c2653b4ba3aedafeb32484ae6c7a417f70764075595e2b9bc5838a"

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
