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
It emits a ZIP, SHA-256 sidecar, and JSON size/provenance manifest. Cargo resolves
the pinned dependency metadata to collect license files; an existing metadata
JSON can be supplied as a fourth argument. Python 3 and macOS build tools are
required. See [preview release notes](../docs/releases/v0.1.0-preview.1.md).

Planned outputs:
- macOS: separate arm64 and x86_64 app archives where supported; optional universal build.
- Windows: architecture-specific installer/archive containing required native dependencies.
- Linux: distribution packages with explicit dependencies; evaluate self-contained bundles separately.

Measure download bytes, installed files, missing runtime prerequisites, and working data independently. Count Tor and cryptography dependencies in complete-client measurements. A tiny UI probe is not the size of a full messenger.

Developer ID signing, notarization, update delivery, and automated release
qualification remain future work. The preview uses only ad-hoc signing and
explicitly documents its installation and compatibility limitations.
