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
