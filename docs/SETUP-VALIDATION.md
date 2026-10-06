# Initial monorepo validation

The initial BitChat Desktop setup was checked locally on macOS with Xcode 27.0, Swift 6.4, and Rust 1.94.1.

Passed checks:

- Rust workspace formatting, Clippy with warnings denied, and a Release build. The crates contain scaffolding, not a working protocol port.
- 184 BitFoundation tests and 13 BitLogger tests. Courier vector lookup was updated for the relocated Apple package.
- 20 inherited Python tests, including checks of archived upstream workflow snapshots.
- SHA-256 verification of six imported interop fixtures against their unchanged upstream source copies.
- SHA-256 and file-set verification of seven vendored Arti artifacts against the preserved provenance document.
- Xcode project/plist syntax, scheme XML, local package paths, source-group paths, BitChat Desktop product naming, and retained Swift module identity.
- Swift package manifest evaluation, artifact-only clean recipe validation, CI YAML parsing, and Git whitespace checks.

The complete macOS Release build did not finish: Xcode remained fetching `swift-secp256k1`, and the local attempt was stopped. The full application test suite was not executed. CI includes a separate macOS Release build so unresolved build issues remain visible.

Windows and Linux app binaries have not been implemented, built, or tested. The Rust CI matrix checks the workspace scaffolding on all three operating systems; it does not establish Bluetooth interoperability or finished-client support.

## Subsequent CI verification

After correcting the relocated relay CSV reference in commit `922e0ee`, [CI run 37473910185](https://github.com/youhanasheriff/bitchat-desktop/actions/runs/37473910185) passed every job, including the complete unsigned macOS Release build. This verifies the monorepo build before the BitChat Desktop branding rename; it does not establish application launch or hardware interoperability.

## BitChat Desktop rename validation

The rename updates repository links, the macOS product/project/scheme, bundle and app-group identifiers, visible app names, and Rust package names. The internal Swift module and Bitchat wire identifiers remain unchanged. Rust formatting, Clippy (warnings denied), Release compilation, all 20 Python tests, project/plist syntax, scheme paths, localization keys/placeholders, and the clean-command guard passed.

The local full Release build with Xcode 27.0 resolved its packages but failed compiling the pinned `swift-secp256k1` 0.21.1 dependency: `UInt256.swift:215:21: ambiguous use of words`. The renamed application has not been launched or measured locally. [Rename CI run](https://github.com/youhanasheriff/bitchat-desktop/actions/runs/37475808687) tracks the corresponding GitHub build; its result must be checked separately from the earlier successful baseline.

## Local macOS build available

The local Apple Silicon Release build now succeeds with Xcode 27.0 after the compatibility patch implemented by `apps/macos/scripts/build-local.sh`. The script verifies the original dependency source SHA-256 before replacing the ambiguous `words` lookup with the identical `SIMDWrapper<Vector>(wrappedValue: vector)` expression used by its accessor. The upstream dependency remains pinned to 0.21.1. Only the ignored dependency checkout is patched.

The repeat build command passed, the app was ad-hoc signed, `codesign --verify --deep --strict` passed, and Launch Services opened the app with its process running. The local signature retains the sandbox and device/network entitlements and omits the provisioned App Group entitlement. This is a local testing build, not a distribution signature. Bluetooth exchanges, the full application test suite, and long-running behavior remain unverified.

Measured on 2026-10-06: the arm64 Release app bundle contains **22,439,296 bytes (22.4 MB / 21.4 MiB)** of logical file data, including its **19,267,648-byte** executable. This excludes build caches, debug symbols outside the bundle, and filesystem allocation overhead; it is not a compressed-download or universal-build measurement.

## Chat message layout preference

Settings now includes a persistent **Bubble / Terminal** chat-style picker, independent of the appearance theme. Terminal remains the default. Bubble separates incoming and outgoing rows, including media, while preserving rich message links, verification/delivery indicators, and archived-history dimming. System messages retain their log presentation. The local UI gallery includes the same setting under Appearance & language.

The arm64 local Release build passed. All **5 ChatViewModelFormattingTests** passed in a Debug Xcode test run with `ENABLE_TESTABILITY=YES`, including two new regressions covering Unicode/link preservation, cache separation across layout changes, and content that resembles sender/timestamp metadata. Gallery switching, persistence across reloads, and all 111 screen/theme combinations with Bubble selected passed browser checks. This scoped test run does not qualify the entire application suite or hardware interoperability.

The local build script now removes injected `.xctest` bundles from its generated app before standalone signing; Xcode test actions can otherwise leave a partial test plug-in that prevents signature verification. No tracked sources or distributed application extensions are removed.
