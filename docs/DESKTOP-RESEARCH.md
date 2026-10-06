# Bitchat desktop architecture and application size research

For a Bitchat compatible desktop app whose main priority is minimum size, the strongest direction is **system native UI on each operating system**: retain SwiftUI/AppKit on macOS and use lightweight Win32 controls on Windows. Share protocol code where it is useful, while keeping Bluetooth adapters specific to each OS.

Flutter is a good choice for reducing UI development work, but it adds a rendering engine to every installation. Tauri can make the application download small by using installed webviews, but its Windows dependency is Chromium based WebView2. These tradeoffs matter because the target is a small functioning installation, including dependencies.

Research date: October 6, 2026. The local Bitchat source snapshot is commit `5e9287fae1e5fea80ca741d4ea669829dc16f144`. Platform conclusions below are engineering judgments based on the cited documentation and local measurements, rather than guaranteed finished application sizes.

## What small means

Track four separate quantities:

1. **Download size:** the signed installer or archive, including any prerequisites downloaded during setup.

2. **Installed footprint:** application files plus additional runtimes required on a clean machine.

3. **Working data:** Tor state, chat archives, queued messages, and media accumulated after installation.

4. **Runtime resource use:** memory, CPU, and battery, measured separately from disk size.

Existing operating system frameworks need not be redistributed. A runtime that is absent on the target machine must be counted even when an installer downloads it separately. Report both a clean machine installation and installation on a machine where shared runtimes already exist. Compression can reduce download size without reducing installed bytes.

## Measured macOS baselines

Two small UI probes contain a title, twenty initial messages, a text field, and a Send button. They contain no Bluetooth, cryptography, Nostr, Tor, or Bitchat protocol implementation.

| Build | Application file bytes | ZIP bytes |
|---|---:|---:|
| SwiftUI arm64 | 79,258 | 15,246 |
| SwiftUI universal arm64 and x86_64 | 144,794 | 27,361 |
| Flutter arm64 Release | 19,941,587 | 8,013,573 |

Use decimal units: the arm64 samples are approximately **79 KB for SwiftUI** and **19.94 MB for Flutter**, or **15 KB and 8.01 MB compressed**. These are UI overhead examples, not predictions that a complete Bitchat client will be 79 KB or 20 MB.

Measurements use macOS 26.6.2, Xcode 27.0, Swift 6.4, and the installed Flutter 3.41.9. SwiftUI used `swiftc -Osize -whole-module-optimization` and a minimal unsigned app bundle. Flutter used a Release build with macOS deployment target 13.0 and arm64 architecture; its normal packaging includes assets and framework signatures. File totals sum regular files without following framework symlinks. ZIPs use `ditto -c -k --keepParent`. Both arm64 probes rely on existing OS libraries.

Flutter's largest measured components were its engine at 14,084,304 bytes, Dart application code at 4,582,688 bytes, and ICU data at 862,304 bytes. The full Flutter SDK cache and debug symbol files are not installed app size. The installed Flutter version is a snapshot; later releases require fresh measurements. [Flutter rendering architecture](https://docs.flutter.dev/resources/architectural-overview), [Flutter size analysis](https://docs.flutter.dev/perf/app-size).

No Windows release artifact was measured. Bitchat's full macOS Release build remained in dependency fetching and was stopped; a completed Bitchat application size is therefore not available from this run.

### Windows measurement on this laptop

The laptop runs macOS on Apple Silicon. UTM is installed, but this check did not establish an accessible Windows guest: `utmctl list` returned automation error `-1743`, and no VM bundles were found in the checked default UTM or Documents directories. This does not establish that no VM exists elsewhere. The Rust Windows GNU target is installed, but a Windows linker/toolchain was not found on PATH.

Windows release artifacts can be built and measured in a Windows VM on this laptop. Flutter's supported Windows build workflow requires Windows and Visual Studio's desktop C++ tools; it cannot directly produce the comparison build through `flutter build windows` on macOS. Alternatively, a Windows CI runner can build the artifacts, which can then be downloaded and measured locally. Certain native C/C++ or Rust projects can cross-compile from macOS with an appropriate Windows toolchain, but this is not a general replacement for the Flutter Windows build environment. [Flutter platform build requirements](https://docs.flutter.dev/platform-integration), [Windows development setup](https://docs.flutter.dev/platform-integration/windows/setup), [UTM Windows setup](https://docs.getutm.app/guides/windows/), [GitHub-hosted Windows runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

There is no Windows Bitchat client implemented in this checkout to measure. A framework comparison must first build equivalent Windows UI probes; a finished-client measurement must wait for a Windows implementation. File and archive sizes can be measured from a VM or downloaded artifacts, while Bluetooth compatibility still requires testing with a usable Windows Bluetooth adapter.

## Framework comparison

| Approach | Distribution implications | Fit for this project |
|---|---|---|
| SwiftUI/AppKit plus Win32 | Uses OS UI libraries; avoids a bundled browser or cross platform rendering engine | Best candidate for minimum footprint; two interfaces to maintain |
| SwiftUI plus WinUI 3 | Windows App SDK runtime must be shared or bundled | More convenient modern Windows controls, but a runtime dependency must be counted |
| Tauri | WebKit on macOS; WebView2 on Windows | Good compromise for a shared HTML UI when installed webviews are acceptable |
| Slint | Compiled declarative UI with selected rendering backends | Worth a size prototype if one shared UI is required; final footprint depends on backend and features |
| Flutter | Bundles Flutter engine and compiled Dart application | Strong UI reuse; measured additional baseline makes it a weaker choice for absolute minimum size |
| Qt Widgets or Qt Quick | Ships selected Qt libraries and plugins unless supplied elsewhere | Mature desktop toolkit; does not remove custom Windows peripheral Bluetooth work |
| Electron | Distributes Chromium and Node based application infrastructure | Poor fit for the stated minimum size priority |

“Native” alone is not a size guarantee. Win32, WinUI 3, and managed Windows applications have different dependency profiles. Microsoft's minimal Win32 example uses the operating system windowing APIs directly. Windows App SDK applications can deploy using a shared runtime or carry their dependencies; self contained deployment increases download and installed footprint. [Win32 desktop programming](https://learn.microsoft.com/en-us/windows/win32/learnwin32/your-first-windows-program), [Windows App SDK deployment](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/deploy-overview).

Slint supports compiled UI for Rust and C++, but backend and dependency choices need an actual release measurement. Its licensing offers royalty free, GPL, and commercial options; the chosen terms apply to distribution. [Slint project](https://github.com/slint-ui/slint), [Slint licenses](https://github.com/slint-ui/slint/blob/master/LICENSE.md). Electron's device API still uses browser device access; native modules are needed where that interface is insufficient. [Electron devices](https://www.electronjs.org/docs/latest/tutorial/devices).

## Tauri and the Windows runtime

Tauri uses the system WebKit on macOS and Chromium based WebView2 on Windows. Tauri's published sub 600 KB minimum is a framework demonstration, not the size of a Bitchat client with networking and Tor. [Tauri introduction](https://v2.tauri.app/start/), [Tauri webviews](https://v2.tauri.app/reference/webview-versions/).

The Tauri installer guide lists approximate additional installer sizes of **1.8 MB** for an embedded WebView2 bootstrapper, **127 MB** for an offline runtime installer, and **180 MB** for a bundled fixed runtime. These are documentation examples, not current measurements of every WebView2 release. A bootstrapper downloads the runtime; its small size does not represent the total prerequisite download.

Tauri is attractive when WebView2 is already installed. An offline first installation on a machine missing that runtime is a different size scenario. Simply skipping runtime installation leaves the app unable to run when the dependency is absent. [Tauri Windows installation options](https://v2.tauri.app/distribute/windows-installer/), [Microsoft WebView2 distribution](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution).

## Bitchat compatibility requirements

The desktop client must implement Bitchat's application protocol, not just obtain Bluetooth access:

- Binary packet framing, signatures, version handling, payload limits, fragmentation, and reassembly.

- Signed announcements, peer identity, connection state, deduplication, and mesh forwarding.

- Noise encrypted sessions and the associated private message, delivery, and read receipt formats.

- Public geohash events and Bitchat's proprietary encrypted Nostr envelopes.

- Store and forward, groups, media, and bridge features appropriate to the supported feature set.

- Local identity storage, retention rules, and panic wipe behavior.

Bitchat's Nostr private envelopes reuse familiar event kind numbers but are not NIP 17, NIP 44, or NIP 59 compatible. A general Nostr library is useful for transport and signatures, but its standard DM functions are insufficient. Match the embedded `bitchat1:` packet content and validate signatures and nested sender binding. [Bitchat protocol](https://github.com/permissionlesstech/bitchat/blob/main/bitchat/Nostr/NostrProtocol.swift), [embedded packet adapter](https://github.com/permissionlesstech/bitchat/blob/main/bitchat/Nostr/NostrEmbeddedBitChat.swift).

Documentation describes the system; pinned code, test vectors, and real iOS/Android interoperability determine acceptance for a selected release. Existing frozen Nostr fixtures are valuable independent inputs for a port. [Fixture configuration](https://github.com/permissionlesstech/bitchat/blob/main/Package.swift), [Bitchat whitepaper](https://github.com/permissionlesstech/bitchat/blob/main/WHITEPAPER.md).

## Bluetooth constraints

For equivalent mesh behavior, support **central and peripheral roles**, including scanning, advertising, GATT writes, notifications, MTU handling, and reconnect/backpressure behavior. Bitchat currently owns separate central and peripheral link layers. [Bitchat peripheral implementation](https://github.com/permissionlesstech/bitchat/blob/main/bitchat/Services/BLE/BLEService%2BLinkLayerPeripheralRole.swift).

On macOS, keep CoreBluetooth integration in native code. On Windows, use the OS Bluetooth/WinRT APIs. Windows provides GATT server advertising, but peripheral support depends on the adapter; check `BluetoothAdapter.IsPeripheralRoleSupported` and test simultaneous scanning and advertising on real hardware. Package identity and Bluetooth capability requirements must be tested with the actual distribution format. [Windows GATT server](https://learn.microsoft.com/en-us/windows/apps/develop/devices-sensors/gatt-server), [adapter peripheral support](https://learn.microsoft.com/en-us/uwp/api/windows.devices.bluetooth.bluetoothadapter.isperipheralrolesupported?view=winrt-26100), [desktop WinRT restrictions](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/winrt-api-desktop-app-support).

Two library limitations affect the architecture: **btleplug supports central mode only**, and **Qt Bluetooth's published support matrix lacks Windows BLE peripheral support**. Neither is a complete replacement for Bitchat's radio layer. [btleplug](https://github.com/deviceplug/btleplug), [Qt Bluetooth support matrix](https://doc.qt.io/qt-6/qtbluetooth-index.html).

Flutter can call native adapters through platform channels or FFI. Its framework is not itself an obstacle to Bluetooth, but it adds a bridge layer and does not eliminate platform implementation work. [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels).

## Tor and other size contributors

Bitchat embeds the Rust Arti Tor client as a static library and normally routes internet transport through Tor. Tor is part of the privacy behavior, rather than a protocol requirement for communicating with a relay. Removing it changes the internet privacy properties, so a compact implementation should preserve it when claiming equivalent behavior. [Bitchat Tor integration](https://github.com/permissionlesstech/bitchat/blob/main/docs/TOR-INTEGRATION.md).

The local macOS universal Arti static archive measures **15,146,088 bytes** for arm64 and x86_64 together. This is a build input, **not** the amount necessarily added to a shipped app: selected architecture, linker elimination, optimization, and compression change the final contribution. The full XCFramework also contains iOS and simulator slices that a macOS application does not need to ship.

Arti's existing build already uses size optimization, LTO, one code generation unit, stripped symbols, and aborting panics. Switching languages alone is not a guaranteed large saving here. Windows requires a supported build of the Tor wrapper; the checked in binary is Apple specific. [Arti provenance](https://github.com/permissionlesstech/bitchat/blob/main/docs/ARTI-BINARY-PROVENANCE.md), [Arti build settings](https://github.com/permissionlesstech/bitchat/blob/main/localPackages/Arti/build-ios.sh).

Other controllable contributors are duplicate CPU architectures, fonts, images, localization assets, debug symbols, codec stacks, and multiple TLS/cryptography implementations. Reuse system media and networking facilities where they support the required wire behavior. OS cryptography does not automatically supply every algorithm Bitchat needs.

## Recommended architecture

### Accepted scope: native macOS, Windows, and Linux in one repository

The selected targets are macOS, Windows, and Linux, with native interfaces and minimum application size as the main priority. One monorepo can contain all three interfaces, shared protocol code, interoperability fixtures, packaging, and CI. Each platform still produces a separate application and installer.

Proposed organization (a plan, not an implemented source migration):

```text
apps/
  macos/       # SwiftUI/AppKit, retaining existing working code
  windows/     # Lightweight Win32 interface
  linux/       # GTK4 interface
crates/
  protocol/    # Shared Rust codecs and protocol state machines
  core/        # Shared routing and application logic
  ffi/         # Narrow C-compatible interface for Swift and other callers
platform/      # OS-specific Bluetooth, secure storage, notifications
tests/interop/ # Shared packet/crypto fixtures and compatibility checks
packaging/     # Separate installers/packages per OS and architecture
docs/
```

A shared Rust implementation requires porting the existing Swift protocol code; it is not already present. Keep the working macOS implementation while bringing the shared core into conformance in stages. A monorepo enables reuse and coordinated releases, but does not imply one UI implementation or one build environment.

GTK4 is a practical Linux toolkit with Rust bindings. Its libraries are dependencies rather than universal built-in OS components: distribution packages can reuse installed libraries, whereas self-contained packaging must account for additional dependencies and runtimes. Linux has no single UI toolkit native to every desktop. [GTK4 overview](https://docs.gtk.org/gtk4/overview.html), [GTK Rust bindings](https://www.gtk.org/docs/language-bindings/rust/).

If choosing a shared UI framework instead, Tauri is the preferred candidate for the size priority because it uses platform webviews. Flutter is preferable when a consistent custom-rendered UI matters more than minimum size. Electron is preferable when its bundled browser consistency and JavaScript/Node ecosystem outweigh footprint. These are engineering recommendations, not measured Windows/Linux size rankings. Tauri uses WebView2 on Windows, WKWebView on macOS, and WebKitGTK on Linux; its prerequisites must be included in clean-machine measurements. Flutter bundles its renderer, while Electron bundles Chromium and Node.js. [Tauri webviews](https://v2.tauri.app/reference/webview-versions/), [Flutter architecture](https://docs.flutter.dev/resources/architectural-overview), [Electron process model](https://www.electronjs.org/docs/latest/tutorial/process-model).

**First implementation:** retain the existing SwiftUI/CoreBluetooth macOS client and build a Windows client with system Win32 controls and Windows BLE APIs. Use a shared conformance suite immediately. This preserves the largest amount of already functioning Mac code while giving Windows a small distribution baseline.

**Long term shared core:** if both clients will evolve together, extract or port packet codecs, protocol state machines, cryptography, routing, and Nostr logic into a Rust library with a narrow C compatible boundary. Link it into both applications. Retain OS specific UI, radio access, secure storage, permissions, notifications, and media adapters.

A shared core reduces duplicated protocol maintenance but requires a careful port; the existing Swift engine cannot simply be imported into Windows unchanged. Rust is an implementation choice, not a proven size advantage for every component. Microsoft's Rust bindings can expose Windows APIs without requiring WinUI for the interface. [Rust for Windows](https://github.com/microsoft/windows-rs).

If a single shared interface becomes a stronger requirement, prototype a minimal Slint build against the same protocol core before choosing Flutter. Tauri remains an option when dependency on installed webviews is acceptable. For the present priority, system native UI is the recommended starting point.

## Size strategy and validation

Build separate arm64 and x86_64 macOS downloads, and separate Windows x64 and ARM64 downloads if those targets are supported. A universal Mac bundle remains convenient, but duplicated machine code raises its footprint. Keep debug symbols in developer artifacts, use system fonts, limit image assets, and link only the supported features and needed dependencies.

For Rust, compare size optimized release profiles using `opt-level="s"` and `"z"`, LTO, stripped symbols, and one code generation unit. The Cargo documentation explicitly notes that size options must be measured: `"z"` is not always the smallest result. Panic behavior and bounds checks are correctness decisions as well as build settings. [Cargo profiles](https://doc.rust-lang.org/cargo/reference/profiles.html). Swift's current Release configuration already uses whole module optimization and dead code stripping.

Before promising a final size:

1. Prove Windows discovery, advertising, encrypted handshake, bidirectional messages, and reconnects with real Bitchat iOS and Android devices.

2. Run packet and crypto fixtures across implementations, including malformed packets, limits, receipt semantics, and wipe/retention behavior.

3. Package signed Release builds with Tor and the agreed features.

4. Measure compressed downloads, installed app bytes, clean machine prerequisites, and working data separately.

5. Measure idle, connected mesh, active relay, media transfer, and Tor startup resource use.

Do not promise a sub 1 MB complete app based on the UI sample or framework marketing. A concrete final size requires a complete feature matched release build; Windows BLE hardware interoperability is the first feasibility gate.
