class Acq < Formula
  desc "Run AI coding agents inside a federally-configured sandbox"
  homepage "https://github.com/GSA-TTS/agentic-coding-quickstart"
  url "https://github.com/GSA-TTS/agentic-coding-quickstart/archive/refs/tags/v2.0.0.tar.gz"
  sha256 "d7ec5a99aa465949abf49d80adc31474c5172633e59385c2631ef0810e63dae5"
  license "CC0-1.0"

  depends_on "superradcompany/tap/microsandbox"

  def install
    libexec.install "acq", "acq.backends"
    bin.install_symlink libexec/"acq"
  end

  test do
    assert_match "agentic coding quickstart wrapper", shell_output("#{bin}/acq --help")
  end
end
