class Acq < Formula
  desc "Run AI coding agents inside a federally-configured sandbox"
  homepage "https://github.com/GSA-TTS/agentic-coding-quickstart"

  url "https://github.com/GSA-TTS/agentic-coding-quickstart/archive/refs/tags/v4.1.1.tar.gz"
  sha256 "5db290d1a1c2653b4ba3aedafeb32484ae6c7a417f70764075595e2b9bc5838a"

  license "CC0-1.0"

  depends_on "GSA-TTS/tap/microsandbox-acq"
  depends_on "python@3.13"

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
      export ACQ_PROVIDER_INPUT_BOOTSTRAP_PYTHON="#{Formula["python@3.13"].opt_bin}/python3.13"
      exec "#{libexec}/acq" "$@"
    SH
    (bin/"acq").chmod 0755
  end

  test do
    assert_match "agentic coding quickstart wrapper", shell_output("#{bin}/acq --help")

    # Verify scripts are under libexec/scripts/ (not at libexec/ root).
    assert_predicate libexec/"scripts/setup-provider-input-validator", :exist?,
                     "Expected libexec/scripts/setup-provider-input-validator"
    assert_predicate libexec/"scripts/provider-input-validator-requirements-macos.txt", :exist?,
                     "Expected libexec/scripts/provider-input-validator-requirements-macos.txt"

    # Verify wheelhouse staging directories exist under libexec/scripts/.
    assert_predicate libexec/"scripts/provider-input-validator-wheelhouse/macos-arm64", :directory?,
                     "Expected macos-arm64 wheelhouse dir"
    assert_predicate libexec/"scripts/provider-input-validator-wheelhouse/macos-x86_64", :directory?,
                     "Expected macos-x86_64 wheelhouse dir"

    # Verify wrapper sets ACQ_PROVIDER_INPUT_BOOTSTRAP_PYTHON and does not export PATH globally.
    wrapper = (bin/"acq").read
    assert_match "ACQ_PROVIDER_INPUT_BOOTSTRAP_PYTHON", wrapper,
                 "Wrapper must set ACQ_PROVIDER_INPUT_BOOTSTRAP_PYTHON"
    assert_match "python3.13", wrapper, "Wrapper must point to python3.13"
    refute_match(/export PATH/, wrapper, "Wrapper must not globally prepend PATH")

    # Note: depends_on "python@3.13" is statically present in the formula file and is
    # enforced by `brew audit`. Asserting it by reading the tap file from within brew test
    # is fragile (sandbox path may not exist) and is therefore omitted here.

    # Note: brew formula --strict syntax check requires a running Homebrew installation and
    # is skipped on Linux CI. Run 'brew formula --strict Formula/acq.rb' on macOS to verify.
  end
end
