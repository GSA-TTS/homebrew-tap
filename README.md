# GSA-TTS Homebrew Tap

Homebrew formulas for GSA-TTS developer tools.

## Usage

```sh
brew install GSA-TTS/tap/acq
```

That installs `acq` plus the version of the `msb` (microsandbox) sandbox runtime
that `acq` supports.

## Formulas

| Formula | Linked? | Description |
| --- | --- | --- |
| `acq` | yes | Run AI coding agents inside a federally-configured sandbox with USAi endpoints. |
| `microsandbox-acq` | yes | The `msb` sandbox runtime, pinned to the version `acq` supports. `acq` depends on this. |
| `microsandbox-acq@0.6.18` | no (keg-only) | msb 0.6.18, for reaching that version deliberately. |
| `microsandbox-acq@0.7.3` | no (keg-only) | msb 0.7.3, for reaching that version deliberately. |

## Why this tap carries microsandbox formulas

Upstream's tap ships a single `microsandbox.rb` that is rewritten in place on every
release, so a Homebrew user can only ever install the newest version — there is no
way to install or hold a specific one. `acq` needs to pin, because specific msb
releases have to be avoided during upstream compatibility windows.

`microsandbox-acq` is that pin, and it is what `acq` depends on. It
`conflicts_with` upstream's `microsandbox` because both own `bin/msb`.

The `@`-versioned formulas are **keg-only**: nothing is symlinked into the Homebrew
prefix, so any number of them can be installed side by side, alongside the linked
`microsandbox-acq`, without shadowing the `msb` on your PATH. Invoke one by path:

```sh
brew install GSA-TTS/tap/microsandbox-acq@0.7.3
"$(brew --prefix microsandbox-acq@0.7.3)/bin/msb" --version
```

Use those when you need a specific msb without disturbing your working one — for
example to run `msb self downgrade` with the binary that performed a migration
(only that binary can roll it back), or to reproduce a version-specific bug.

All of this is a stopgap. Versioned formulas have been requested upstream; when
upstream ships them, these can be dropped.
