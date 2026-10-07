# Packaging

The first macOS Apple Silicon early preview is packaged with:

```sh
bash packaging/macos/package-preview.sh \
  'apps/macos/.DerivedData/Build/Products/Release/BitChat Desktop.app' \
  /tmp/bitchat-desktop-release "$(git rev-parse HEAD)"
```

Pass the commit actually used for the application build; do not infer it from a
later tooling-only commit. This packages an already built app, collects the
locked third-party notices, sets preview version metadata, and signs a copy ad
hoc. It does not use this machine's signing identities or notarize the app.
It emits a drag-to-Applications DMG and an alternative ZIP, each with a SHA-256
sidecar and JSON size/provenance manifest. The DMG manifest ends in `.dmg.json`
to preserve the original ZIP manifest's filename. Cargo resolves
the pinned dependency metadata to collect license files; an existing metadata
JSON can be supplied as a fourth argument. Python 3 and macOS build tools are
required. See [preview release notes](../docs/releases/v0.1.0-preview.1.md).

To add a DMG to an existing release, extract its published ZIP and wrap that
already signed app without rebuilding or modifying it:

```sh
bash packaging/macos/package-dmg.sh '/path/to/BitChat Desktop.app' /tmp/bitchat-dmg
```

The helper uses macOS `hdiutil`, creates a compressed HFS+ disk image with an
Applications link, mounts it read-only, compares every app file with the input,
and verifies the app signature both on the mounted image and after copying out.
It refuses to overwrite an existing DMG. DMG packaging does not provide
Developer ID signing or notarization.

Planned outputs:
- macOS: separate arm64 and x86_64 app archives where supported; optional universal build.
- Windows: architecture-specific installer/archive containing required native dependencies.
- Linux: distribution packages with explicit dependencies; evaluate self-contained bundles separately.

Measure download bytes, installed files, missing runtime prerequisites, and working data independently. Count Tor and cryptography dependencies in complete-client measurements. A tiny UI probe is not the size of a full messenger.

Developer ID signing, notarization, update delivery, and automated release
qualification remain future work. The preview uses only ad-hoc signing and
explicitly documents its installation and compatibility limitations.

## Linux discovery preview

The `Build Linux preview archives` workflow builds and tests native x86_64 and ARM64 binaries in Debian 12 containers, then uploads archives for review. It does not automatically publish a release. To package an already built Linux Release binary locally:

```sh
bash packaging/linux/package-preview.sh target/release/bitchat-desktop dist "$(git rev-parse HEAD)"
```

The output includes a `.tar.gz`, SHA-256 sidecar, and JSON size/source manifest for each architecture. The archive carries the project license, locked Rust dependency notices, `Cargo.lock`, installation notes, and a record of linked system libraries. Packaging checks the ELF architecture and dependency resolution, then extracts and smoke-tests the packaged executable. GTK/GLib/libdbus and other system runtimes are dynamically linked and not bundled. See [Linux release notes](../docs/releases/linux-v0.1.0-preview.1.md).

## Windows discovery preview

Run `python packaging/windows/package-preview.py <source-commit>` on Windows after a native x64 release build with `RUSTFLAGS=-C target-feature=+crt-static`. The manual `windows-preview.yml` workflow runs at Rust 1.85.1, exercises the native UI, packages both GUI and console executables with notices and provenance, verifies PE headers, and smoke-tests the extracted archive. Assets are unsigned ZIP files with SHA-256 and JSON sidecars. See [release scope and installation](../docs/releases/windows-v0.1.0-preview.1.md). Only publish artifacts from a successful, reviewed run.
