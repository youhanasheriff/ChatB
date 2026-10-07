# BitChat Desktop for macOS

This directory retains Bitchat's SwiftUI/CoreBluetooth implementation, tests, Xcode project, and local Swift packages. The macOS product is named **BitChat Desktop.app**, using bundle identifier `io.github.youhanasheriff.bitchatdesktop`.

Open `BitChatDesktop.xcodeproj` and select **BitChat Desktop (macOS)**. Build instructions are in the [root README](../../README.md). The Swift module and most source filenames retain `bitchat` to keep the upstream implementation and tests straightforward to track; the shared Rust core is not integrated yet.

The inherited iOS target and share extension remain alongside shared Apple code. They are not a supported BitChat Desktop product. Upstream artwork and some in-app wording remain pending a dedicated branding pass.

Keep signing credentials and `Configs/Local.xcconfig` out of version control. The upstream signing team has been removed.

For a fast local Release build on this Mac, run from the repository root:

```sh
bash apps/macos/scripts/build-local.sh --open
```

This builds for the host processor, verifies and applies a compiler compatibility patch to the ignored `swift-secp256k1` 0.21.1 checkout, and ad-hoc signs the app for local testing. The patch spells out the same SIMD word wrapper already returned by the dependency's accessor, avoiding a Swift 6.4 ambiguity. The sandbox and Bluetooth/network permissions are retained; the provisioned App Group entitlement is omitted for this local build. Release distribution still needs proper signing and qualification.

The app is generated at `.DerivedData/Build/Products/Release/BitChat Desktop.app`. Use `CONFIGURATION=Debug` for a Debug build, or run `just run` in this directory.

Ordinary Debug builds use a separate Bluetooth test network and cannot discover released phone clients. For physical-device diagnostics against those clients, opt into the normal service UUID:

```sh
INTEROP=1 CONFIGURATION=Debug bash apps/macos/scripts/build-local.sh --open
```

This enables the `BITCHAT_INTEROP` compilation condition only for that Debug build. Release builds always use the normal mesh network.

## Desktop diagnostics

Open **Settings → debugging → Debug settings**. The screen is available in Release builds; its persistent **Debug mode** toggle enables local event capture and diagnostic actions. Overview shows the build/network, Bluetooth central/peripheral state, scan/advertising state, link/candidate counts and retained private deliveries. Peers shows short IDs, connectivity, Noise session state and mesh ping results. Console retains the latest 300 typed connection/delivery events, with counters covering the session since the last clear.

Tools include continuous scanning, discovery/announce refresh, retrying the existing private outbox, and the mesh topology map. Continuous scanning is temporary and returns to the normal adaptive policy when debug mode is disabled or the app restarts. Disabling capture clears its in-memory events and counters; panic wipe also removes the saved toggle. Closing the screen leaves capture enabled if its toggle is on.

**Copy report** copies the current diagnostic snapshot to the Mac clipboard. Reports omit message bodies, nicknames, full peer keys, relay addresses and location. Events are never written to a diagnostic file or uploaded automatically. The screen refreshes every two seconds while open. Android-specific Wi-Fi Aware controls, connection-budget overrides, packet graphs and sync/Bloom tuning are not implemented in this desktop screen.
