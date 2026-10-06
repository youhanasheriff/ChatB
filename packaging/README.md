# Packaging

There are no ChatB release artifacts yet.

Planned outputs:
- macOS: separate arm64 and x86_64 app archives where supported; optional universal build.
- Windows: architecture-specific installer/archive containing required native dependencies.
- Linux: distribution packages with explicit dependencies; evaluate self-contained bundles separately.

Measure download bytes, installed files, missing runtime prerequisites, and working data independently. Count Tor and cryptography dependencies in complete-client measurements. A tiny UI probe is not the size of a full messenger.

Signing, notarization, update delivery, and release automation will be added after the clients build and interoperate.
