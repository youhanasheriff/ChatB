# ChatB for macOS

This directory retains Bitchat's SwiftUI/CoreBluetooth implementation, tests, Xcode project, and local Swift packages. The macOS product is named **ChatB.app**, using bundle identifier `io.github.youhanasheriff.chatb`.

Open `ChatB.xcodeproj` and select **ChatB (macOS)**. Build instructions are in the [root README](../../README.md). The Swift module and most source filenames retain `bitchat` to keep the upstream implementation and tests straightforward to track; the shared Rust core is not integrated yet.

The inherited iOS target and share extension remain alongside shared Apple code. They are not a supported ChatB product. Upstream artwork and some in-app wording remain pending a dedicated branding pass.

Keep signing credentials and `Configs/Local.xcconfig` out of version control. The upstream signing team has been removed.
