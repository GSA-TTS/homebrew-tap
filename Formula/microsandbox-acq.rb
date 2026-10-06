# typed: false
# frozen_string_literal: true

# Version-pinned microsandbox for acq.
#
# Upstream's tap carries a single always-latest `microsandbox.rb` that is bumped
# in place on every release, so a dependent cannot pin or hold a version. acq
# needs to, because specific msb releases have to be avoided during upstream
# compatibility windows. This formula is that pin; `Formula/acq.rb` depends on it
# instead of upstream's.
#
# Keep this tracking the version acq's installer and version gate treat as the
# known-good default.
class MicrosandboxAcq < Formula
  desc "Spins up lightweight VMs in milliseconds from SDKs (version-pinned for acq)"
  homepage "https://microsandbox.dev"
  version "0.7.7"
  license "Apache-2.0"

  # Both formulae own bin/msb, so Homebrew cannot link both.
  conflicts_with "superradcompany/tap/microsandbox",
                 because: "both install the msb binary"

  on_macos do
    on_arm do
      url "https://github.com/superradcompany/microsandbox/releases/download/v#{version}/microsandbox-darwin-aarch64.tar.gz"
      sha256 "eed5faa16217ad375ad9a4eb5e819656baeab8ccde0d3ab7e79c4af49319d403"
    end

    on_intel do
      odie "microsandbox requires Apple Silicon (M1+). x86_64 macOS is not supported."
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/superradcompany/microsandbox/releases/download/v#{version}/microsandbox-linux-aarch64.tar.gz"
      sha256 "8997b1ea76de58689fb6d0fa7b32af6fbe8cbc24612da40b168a5b433c7d8318"
    end

    on_intel do
      url "https://github.com/superradcompany/microsandbox/releases/download/v#{version}/microsandbox-linux-x86_64.tar.gz"
      sha256 "b3cc4a5e3f52dfdd938a6f67ac4a9a959ddfe304bab56de4964044b8613f01bb"
    end
  end

  def install
    # Keep msb and its private libkrunfw together in libexec, then expose msb on
    # PATH through a wrapper script. The binary already carries an
    # @executable_path rpath, so it finds the library sitting beside it without
    # any install_name_tool edit. That matters on macOS: modifying the binary
    # would invalidate its code signature, and the release binary is signed with
    # the com.apple.security.hypervisor and disable-library-validation
    # entitlements it needs to boot VMs. Leaving the binary untouched preserves
    # the signature and those entitlements; a modified binary would be killed on
    # launch or lose the entitlements.
    libexec.install "msb"

    if OS.mac?
      # macOS bundles ship the ABI-only name, which is stable across releases.
      libexec.install "libkrunfw.5.dylib"
      libexec.install_symlink libexec/"libkrunfw.5.dylib" => "libkrunfw.dylib"
    end

    if OS.linux?
      # Linux bundles ship a FULLY-versioned soname whose version tracks the
      # bundled kernel, not msb: 5.2.1 through v0.6.1, 5.5.0 at v0.6.3, 5.6.0 at
      # v0.6.7, 5.6.1 since v0.6.8. Hardcoding it breaks the install on every
      # release that bumps it (upstream's formula still names 5.2.1 and so fails
      # on Linux), so discover the artifact and derive the ABI from its name.
      lib = Dir["libkrunfw.so.*.*.*"].first
      odie "release bundle contains no versioned libkrunfw shared library" if lib.nil?

      abi = lib[/\Alibkrunfw\.so\.(\d+)\./, 1]
      odie "cannot parse libkrunfw ABI from #{lib}" if abi.nil?

      libexec.install lib
      libexec.install_symlink libexec/lib => "libkrunfw.so.#{abi}"
      libexec.install_symlink libexec/lib => "libkrunfw.so"
    end

    bin.mkpath
    File.write(bin/"msb", <<~SH)
      #!/bin/bash
      exec "#{libexec}/msb" "$@"
    SH
    chmod 0755, bin/"msb"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/msb --version")
  end
end
