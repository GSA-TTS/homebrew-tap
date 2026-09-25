# typed: false
# frozen_string_literal: true

# microsandbox 0.7.3, keg-only.
#
# WHY A VERSIONED FORMULA EXISTS
#
# Upstream's tap carries a single always-latest `microsandbox.rb` that is bumped
# in place on every release, so there is no way for a Homebrew user to install, or
# hold, any version but the newest. That is a problem whenever a specific release
# has to be reached deliberately: pinning a project, reproducing a version-specific
# bug, or recovering a host that landed on a release it cannot use.
#
# This is a stopgap. It exists until upstream publishes `@`-versioned formulae of
# its own (requested upstream); when that lands, these can be dropped in favour of
# theirs.
#
# WHY KEG-ONLY
#
# Version-specific formulae are for reaching a version deliberately, not for
# putting it on PATH. Keg-only means nothing is symlinked into the Homebrew prefix,
# so every version here coexists with every other AND with the linked
# `microsandbox-acq` default, with no `conflicts_with` needed and no chance of
# silently shadowing the msb a user actually runs.
#
# Invoke it by full path:
#
#   "$(brew --prefix microsandbox-acq@0.7.3)/bin/msb" --version
#
# NOTE: the install block is duplicated across the microsandbox-acq formulae rather
# than shared. Homebrew formulae are intentionally standalone files, and a shared
# helper in a tap is loaded through fragile relative requires; ~25 duplicated lines
# is the cheaper trade. Keep them in sync when changing the layout.
class MicrosandboxAcqAT073 < Formula
  desc "Spins up lightweight VMs in milliseconds from SDKs (0.7.3, keg-only)"
  homepage "https://microsandbox.dev"
  version "0.7.3"
  license "Apache-2.0"

  keg_only "it is a version-specific msb for pinning and recovery; " \
           "the linked default is microsandbox-acq"

  on_macos do
    on_arm do
      url "https://github.com/superradcompany/microsandbox/releases/download/v#{version}/microsandbox-darwin-aarch64.tar.gz"
      sha256 "4c1c4ec07bedb9eddbbdbfe93fe45d57c5fddc1ddcee87d00c17dace185a45c1"
    end

    on_intel do
      odie "microsandbox requires Apple Silicon (M1+). x86_64 macOS is not supported."
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/superradcompany/microsandbox/releases/download/v#{version}/microsandbox-linux-aarch64.tar.gz"
      sha256 "6c1bfde0a86919bdb04fa33bbe10e76b27d65f6afb25d17e6c5ffc9c53060c47"
    end

    on_intel do
      url "https://github.com/superradcompany/microsandbox/releases/download/v#{version}/microsandbox-linux-x86_64.tar.gz"
      sha256 "2d5da7de187246c804dce2a1a23f06626b6f7cb892d9a0c7c5c620784ba412ea"
    end
  end

  def install
    # Keep msb and its private libkrunfw together in libexec, then expose msb
    # through a wrapper script. The binary already carries an @executable_path
    # rpath, so it finds the library sitting beside it without any
    # install_name_tool edit. That matters on macOS: modifying the binary would
    # invalidate its code signature, and the release binary is signed with the
    # com.apple.security.hypervisor and disable-library-validation entitlements it
    # needs to boot VMs. Leaving it untouched preserves both.
    libexec.install "msb"

    if OS.mac?
      # macOS bundles ship the ABI-only name, which is stable across releases.
      libexec.install "libkrunfw.5.dylib"
      libexec.install_symlink libexec/"libkrunfw.5.dylib" => "libkrunfw.dylib"
    end

    if OS.linux?
      # Linux bundles ship a FULLY-versioned soname whose version tracks the
      # bundled kernel, not msb: 5.2.1 through v0.6.1, 5.5.0 at v0.6.3, 5.6.0 at
      # v0.6.7, 5.6.1 since v0.6.8. Discover it rather than hardcoding a version
      # that goes stale (upstream's formula still names 5.2.1 and fails on Linux).
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
