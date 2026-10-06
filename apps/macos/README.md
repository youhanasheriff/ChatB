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
