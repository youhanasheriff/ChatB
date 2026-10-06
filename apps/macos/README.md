# BitChat Desktop for macOS

This directory retains Bitchat's SwiftUI/CoreBluetooth implementation, tests, Xcode project, and local Swift packages. The macOS product is named **BitChat Desktop.app**, using bundle identifier `io.github.youhanasheriff.bitchatdesktop`.

Open `BitChatDesktop.xcodeproj` and select **BitChat Desktop (macOS)**. Build instructions are in the [root README](../../README.md). The Swift module and most source filenames retain `bitchat` to keep the upstream implementation and tests straightforward to track; the shared Rust core is not integrated yet.

The inherited iOS target and share extension remain alongside shared Apple code. They are not a supported BitChat Desktop product. Upstream artwork and some in-app wording remain pending a dedicated branding pass.

Keep signing credentials and `Configs/Local.xcconfig` out of version control. The upstream signing team has been removed.
