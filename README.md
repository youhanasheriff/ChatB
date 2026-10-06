# BitChat Desktop

An independent Bitchat-compatible client for macOS, Windows, and Linux.

BitChat Desktop is an independent, open-source desktop project following [Bitchat](https://github.com/permissionlesstech/bitchat), targeting **macOS, Windows, and Linux**. The priority is a small application with native interfaces and Bitchat protocol compatibility.

Read the [vision and mission](docs/VISION-AND-MISSION.md) and the [implementation roadmap](docs/ROADMAP.md) for the project's commitments, milestones, and detailed completion checklist.

## Current status

- **macOS:** the upstream SwiftUI/CoreBluetooth implementation is retained in `apps/macos`, with a BitChat Desktop application product and separate bundle identity. The native macOS app builds and launches locally with the desktop UI, three study palettes, and Bubble / Terminal chats. See the [UI checklist](docs/UI-IMPLEMENTATION.md) and [validation notes](docs/SETUP-VALIDATION.md). Hardware interoperability remains to be verified.
- **Windows:** native Win32 client planned; directory scaffold only.
- **Linux:** native GTK4 client planned; directory scaffold only.
- **Shared Rust core:** workspace scaffolding only. Packet codecs, cryptography, routing, and Nostr implementation have not yet been ported or connected to the macOS app.

No Windows/Linux release or complete cross-platform compatibility is claimed yet.

## Repository

```text
apps/
  macos/          Existing Apple project and supporting packages
  windows/        Native Windows client
  linux/          Native Linux client
crates/
  protocol/       Shared wire protocol (planned)
  core/           Shared application/mesh logic (planned)
  ffi/            C-compatible boundary for native callers (planned)
platform/         OS-specific adapters
tests/interop/    Frozen interoperability fixtures and their provenance
packaging/        Per-platform distribution and size measurement plans
docs/             Architecture, research, upstream provenance
```

## Develop

Check the Rust workspace scaffolding:

```sh
cargo check --workspace --locked
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
```

Open the macOS project:

```sh
open apps/macos/BitChatDesktop.xcodeproj
```

For a local build that handles Swift 6.4 compatibility, signs for testing, and opens the app:

```sh
bash apps/macos/scripts/build-local.sh --open
```

See the [macOS README](apps/macos/README.md) for local signing details.

Select **BitChat Desktop (macOS)**. To build an unsigned Release application:

```sh
xcodebuild -project apps/macos/BitChatDesktop.xcodeproj \
  -scheme "BitChat Desktop (macOS)" -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath apps/macos/.DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

The application should be produced at `apps/macos/.DerivedData/Build/Products/Release/BitChat Desktop.app`. Xcode must resolve the upstream Swift package dependencies first. For signed development, set your own team in ignored `apps/macos/Configs/Local.xcconfig` and use the Debug configuration.

Upstream Swift tests can be run with `swift test --package-path apps/macos`. iOS files and targets remain as inherited implementation support; iOS is outside BitChat Desktop's selected product scope.

## Compatibility and upstream

Start with the pinned upstream behavior and independent interoperability fixtures. Preserve wire identifiers and cryptographic formats while changing application branding. A shared Rust core will be adopted in stages only after interoperability checks pass. See [architecture](docs/ARCHITECTURE.md), [upstream provenance](docs/UPSTREAM.md), [interop fixtures](tests/interop/README.md), and [size research](docs/DESKTOP-RESEARCH.md).

## License

BitChat Desktop retains Bitchat's **Unlicense** dedication. See [LICENSE](LICENSE). Bundled dependencies retain their own licenses and attribution; the root license does not replace them.

BitChat Desktop is independently maintained by [Youhana Sheriff](https://github.com/youhanasheriff). It is not an official Bitchat release.
