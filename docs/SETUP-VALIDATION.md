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

At the initial scaffold milestone, Windows and Linux app binaries had not been implemented, built, or tested; later discovery milestones are recorded below. The Rust CI matrix checks the workspace scaffolding on all three operating systems; it does not establish Bluetooth interoperability or finished-client support.

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

## Native desktop UI implementation

The macOS client now hosts a persistent desktop sidebar and inline direct/group conversations, with Terminal, Native Light and Graphite study palettes and the independent Bubble / Terminal preference. Existing Liquid Glass preferences remain supported. The [37-entry UI checklist](UI-IMPLEMENTATION.md) maps every gallery screen/state to its native presentation and records platform limits. Settings, identity, verification, image selection/preview and topology use shared desktop sheet styling; dense fingerprint/scanner content scrolls. Native system dialogs remain system controls.

Desktop **Review clipboard** offers bounded text for the current conversation and requires confirmation before replacing the composer. It never sends automatically. Destination changes require a second confirmation. Settings exposes the screenshot privacy notice; automatic macOS screenshot detection and a macOS Share extension are not implemented. Windows/Linux conversation UI remains pending.

The final arm64 Release build, ad-hoc signature and `codesign --verify --deep --strict` passed. Launch Services opened the new app. All **38 tests across 4 scoped suites** passed: `ViewSmokeTests`, `ComposerDraftStoreTests`, `ChatViewModelFormattingTests`, and `SharedContentHandoffTests`. They cover the three study palettes at a proposed 800 × 580 minimum window size, public/private selection, view branches, draft isolation, formatting and desktop import confirmation/rejection. Offscreen visual renders use a mock peer roster; hardware exchanges and destructive workflows were not exercised.

Measured on 2026-10-06: the arm64 Release bundle contains **23,180,818 bytes (23.18 MB / 22.11 MiB)** of logical file data; the executable is **20,003,936 bytes**. This is 741,522 bytes above the earlier local baseline, including both the chat-layout and desktop UI changes. It excludes build caches, external debug symbols, filesystem allocation overhead and compressed/universal distribution measurements. The bundle contains no gallery PNGs or Chromium/Electron runtime.

## Manual Android interoperability check — 2026-10-07

Tested the local Release app at `apps/macos/.DerivedData/Build/Products/Release/BitChat Desktop.app` on macOS 26.6.2 (25G83), with the user operating a nearby physical Android phone running Bitchat **v2.0.1**. The Mac nickname was `anon3351` and the Android nickname was `youha`. The phone model and Android OS version were not captured.

- Discovery: the Android phone showed `anon3351`; the Mac showed `youha` as connected and reported Bluetooth on.
- Public text: the Mac sent marker **M1** in `#mesh`. The user confirmed receipt on Android, and the Mac received the Android reply `Android received M1`.
- Private text, Android to Mac: the Mac received `hi` and `Android didn't receive M2` in the private conversation with `youha`.
- Private text, Mac to Android: the Mac sent **M2**, then **M3** after receiving the Android private message. The user reported that neither arrived. Both outgoing messages remained at `sent — no delivery confirmation yet` in the Mac UI.

During diagnosis, an ordinary Debug build initially could not discover the released Android client because Debug uses an isolated BLE service UUID. An explicit `BITCHAT_INTEROP` build condition now allows local Debug builds to join the release mesh (`INTEROP=1 CONFIGURATION=Debug bash apps/macos/scripts/build-local.sh --open`). With that corrected, a fresh session delivered the retained M2/M3 messages and returned delivery/read receipts. The Android user replied `Android received M3`. A new private **D1** received a read receipt and the reply `D1 received`; after restarting only the Mac, **D2** also received a read receipt and the reply `D2 received`. These recovery observations preceded the retry fix and do not establish the original packet-loss cause.

Code inspection found that retained private messages depended on reconnect/authentication events for retry, so a lost ciphertext or receipt could remain stuck on a continuously connected secure link. The router now checks every five seconds, retrying after 10, 20, 40, then 60 seconds, up to the existing eight-send limit. It preserves the message ID, scopes retry state to the recipient, and clears retries on an authenticated receipt, expiry, drop or wipe. Offline and pre-handshake delivery retain their existing paths. All **52 tests in `MessageRouterTests` and `BLENoiseReconnectPolicyTests` passed**, including six new tests covering timed recovery, backoff, delayed handshake draining, connectivity gating, recipient scoping, synchronous acknowledgements, and the attempt cap.

The updated arm64 Release build and `codesign --verify --deep --strict` passed. After replacing the diagnostic process with this build, the Mac rediscovered `youha` and sent private marker **F1** at 12:55:38; it immediately showed `read by youha`. The Mac received the Android reply `F1 received` at 12:55:51, confirming a private-message round trip on the updated build. Timed packet-loss recovery was verified with the injected-clock transport tests; this hardware exchange did not deliberately drop a packet.

Gateway/bridge mode was active during these checks, so an isolated Bluetooth-only exchange was not established. The private conversation's end-to-end encryption label is UI evidence, not an independent cryptographic audit. The original loss trigger, offline operation, media, other peer versions and the full application test suite remain unqualified.

## Desktop diagnostics — 2026-10-07

Settings → debugging exposes Debug mode and a native Debug settings sheet in normal Release builds. Overview, Peers and Console provide live BLE manager/scan/advertising/link state, shortened peer IDs and Noise session state, mesh ping, temporary continuous scanning, discovery/announce refresh, existing outbox retry and topology. Capture is disabled by default, bounded to 300 typed events in memory, and excludes message bodies, nicknames, full keys, arbitrary errors, relay addresses and locations. Disabling it clears history/counters and restores adaptive scanning; panic wipe also resets the saved preference. Copy report is an explicit clipboard action; no diagnostic upload or file persistence is added.

All **73 tests across five scoped suites** passed: `DesktopDebugCaptureTests`, `DesktopDebugModelTests`, `MessageRouterTests`, `BLENoiseReconnectPolicyTests`, and `MeshDiagnosticsTests`. The eight new debug tests cover disabled/cleared capture, bounded history and concurrent counters, sanitized identifiers, saved-preference/panic reset, report omissions, gated retry using stable IDs, and stale ping callbacks after clearing. The final counter correction counts actual router handoffs, including retries, without counting restored or post-handshake retry-deadline initialization as another send.

The arm64 Release build, local ad-hoc signing and strict signature verification passed. Native UI checks confirmed the screen's Release/main-mesh label, powered-on central/peripheral managers, active scanning/advertising, live link counts, a connected peer with an established Noise session and signature-verified announce, discovery refresh, continuous-scan override, typed console events and Copy report's Copied state. Turning Debug mode off visibly disabled the actions, cleared the console and reset continuous scanning. A ping was started; its phone response was not qualified. No additional message round trip or destructive panic wipe was performed for this screen's UI verification.

This desktop implementation does not expose Android Wi-Fi Aware controls, custom GATT role/connection limits, packet-rate graphs or sync/Bloom tuning. Full translation coverage and the full application test suite remain pending.

## Linux discovery preview — October 7, 2026

The first Linux target now builds as a native Rust/GTK4 application with a BlueZ discovery backend and a headless `--scan` command. Validation ran on **Linux aarch64 in a Debian 12 Docker container**, hosted by the Apple Silicon Mac, with **Rust 1.85.1, GTK 4.8.3, and libdbus 1.14.10**.

Passed checks:

- Locked Debug and optimized Release builds of `bitchat-desktop-linux`.
- Six Rust tests covering CLI validation, default/isolated network selection, service filtering, bounded device state, failure cleanup, and remote-name sanitization.
- Six integration tests using an isolated mocked BlueZ system bus: missing adapter, disabled radio, mainnet/testnet filtering despite merged scan results, permission denial, cancellation with discovery release, and radio power loss.
- GTK launch/close under Xvfb without Bluetooth hardware, including an assertion that the empty-list placeholder is visible; an explicit missing-system-bus scan returns an actionable failure.
- Linux workspace Clippy with warnings denied; macOS workspace formatting, Clippy and tests; Git whitespace and shell syntax checks.
- Visual inspection of the actual GTK ready and unavailable-BlueZ states, plus scan-button interaction and Ctrl+Q shutdown. The visual check caught and fixed removal of the list's empty-state widget during refresh.
- The existing 20 Python tests and verification of six imported interoperability fixture hashes.

The Linux CI additions run the native workspace checks and a dedicated Rust 1.85 / Debian 12 build and simulated-BlueZ harness. These jobs have been added locally; a remote CI run has not been claimed. Windows/macOS compile only the portable Linux state/argument modules and an unsupported-platform entry point; they do not validate GTK or BlueZ.

The container does not expose a physical Bluetooth controller. **Real discovery, peripheral advertising, GATT exchange, Noise authentication, messaging, secure storage, Wayland behavior, and distribution packaging remain unverified or unimplemented.** The shared Rust protocol/core/FFI crates remain scaffolds. The scanner does not join or advertise on the mesh. See [Linux development instructions](../apps/linux/README.md) for the exact build/check commands and hardware acceptance requirements.

## Windows discovery preview — October 7, 2026

`apps/windows` now contains a native Win32 discovery window and WinRT passive advertisement watcher, plus a separate terminal scanner. Portable tests cover CLI validation, mainnet/testnet filtering, bounded/sanitized observations and late callbacks. Windows-only tests cover actionable error mapping. Cross-target Windows compilation and Clippy are checked locally; the Windows preview workflow executes native tests and UI automation before packaging.

The UI harness checks ready state, network toggles, real WinRT scan attempts (normally the no-radio path on hosted runners), retry, resizing and teardown. It records actual ready/error/minimum-size screenshots. Packaging verifies x64 PE headers and GUI/console subsystems, licenses, hashes, and launches executables extracted from the final ZIP. Passing these checks does not establish real-device interoperability. Windows 10/11 physical devices, radio power/removal, sleep/resume and accessibility still need qualification. See the Windows release notes and CI run attached to the release for actual publication evidence.
