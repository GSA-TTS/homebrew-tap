class Acq < Formula
  desc "Run AI coding agents inside a federally-configured sandbox"
  homepage "https://github.com/GSA-TTS/agentic-coding-quickstart"
  url "https://github.com/GSA-TTS/agentic-coding-quickstart/archive/refs/tags/v3.1.0.tar.gz"
  sha256 "adaaabe719804c18d462d70a2637bef297402bbaf36a8a81df965a80d3f0474c"
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
