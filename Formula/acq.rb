class Acq < Formula
  desc "Run AI coding agents inside a federally-configured sandbox"
  homepage "https://github.com/GSA-TTS/agentic-coding-quickstart"

  url "https://github.com/GSA-TTS/agentic-coding-quickstart/archive/refs/tags/v4.2.1.tar.gz"
  sha256 "956c9591ff715077d5858349165b1fcfe6e5ca221b2c5b79cc0f4d48bf8666a2"

  license "CC0-1.0"

  depends_on "GSA-TTS/tap/microsandbox-acq"
  depends_on :macos
  depends_on "python@3.13"

  resource "provider-input-validator-wheelhouse-arm64" do
    url "https://github.com/GSA-TTS/agentic-coding-quickstart/releases/download/v4.2.1/provider-input-validator-wheelhouse-macos-arm64.tar.gz"
    sha256 "94dbaa2feac8b2adb46a94881b56396a9785ae80e8b4a1eb28abf1b6db4cb475"
  end

  resource "provider-input-validator-wheelhouse-x86-64" do
    url "https://github.com/GSA-TTS/agentic-coding-quickstart/releases/download/v4.2.1/provider-input-validator-wheelhouse-macos-x86_64.tar.gz"
    sha256 "6368a3ffce3b8f74808e3f0da0812e319005babf82749d02e245ae6e9108dc56"
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
