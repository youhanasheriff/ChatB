# BitChat Desktop: Vision and Mission

> Small native desktop apps. One compatible network. User-controlled communication.

## Vision

Make Bitchat-compatible communication a dependable part of everyday desktop computing: a small, accessible, open-source application for macOS, Windows, and Linux that helps people communicate nearby without internet access and reach compatible peers through internet relays when connectivity is available.

A person should be able to install BitChat Desktop, understand which transport is available, and communicate with compatible Bitchat users without needing a BitChat Desktop account, phone number, or company-operated messaging server.

“Small” means the complete usable installation, including any dependencies missing from the user's computer. It also means restrained memory use, background activity, and battery consumption. Size reductions must preserve correctness, accessibility, and the stated privacy behavior.

## Mission

Build and maintain three native desktop clients around a carefully tested shared protocol implementation. Follow Bitchat's wire behavior, verify interoperability with real clients, explain transport and privacy limits clearly, and publish source, build instructions, test evidence, and release measurements.

We will:

1. **Stay compatible.** Track a named upstream revision and supported feature set. Validate independently produced packets and real iOS/Android clients before claiming interoperability.
2. **Stay native.** Use SwiftUI/AppKit on macOS, lightweight Win32 on Windows, and GTK4 on Linux, with platform-specific Bluetooth and operating-system integration.
3. **Share the difficult logic.** Gradually port protocol codecs, cryptography integration, routing, and state machines into Rust. Keep a narrow, documented boundary for native callers.
4. **Keep the application small.** Measure complete Release packages and prerequisites per platform and architecture; justify additions with user value and measured cost.
5. **Respect user control.** Make public/private messaging, local/internet transport, retention, notifications, and Tor behavior understandable and controllable.
6. **Work in the open.** Maintain public source, reproducible build instructions, visible limitations, issue tracking, and a reviewable development roadmap.

## Who BitChat Desktop serves

- Bitchat users who want a desktop companion on a supported computer.
- People communicating nearby when internet access is absent or unreliable.
- Users who value native desktop interaction and a small installation.
- Developers and researchers who need inspectable compatibility tests and implementations.

Bluetooth capabilities vary by hardware and operating system. BitChat Desktop must identify unsupported configurations and explain their limitations rather than imply that every computer can participate identically.

## Product commitments

### Interoperability before new protocol invention

BitChat Desktop follows [Bitchat](https://github.com/permissionlesstech/bitchat) as an independent desktop project. Branding, application identifiers, and native interaction can differ; established wire identifiers and cryptographic formats must remain compatible with the declared upstream target.

A feature declaration or capability bit in source code is not proof that a feature ships or interoperates. Compatibility claims must identify the tested client versions, platforms, and supported operations.

### Privacy with accurate expectations

Private messages must use the compatible authenticated encryption path. Public mesh messages and public location channels are public communication, and the interface must make that distinction clear.

Encrypted content does not hide all metadata. Bluetooth announcements, radio activity, recipient addressing, relay behavior, and compromised endpoints have limits that the project must describe. Existing offline-envelope paths must not be described as providing forward secrecy when they do not.

Tor behavior is part of the privacy contract where internet transport uses it. Reducing size must not silently remove Tor or turn protected connections into direct connections.

No advertising, behavioral tracking, required BitChat Desktop cloud account, or default message-content telemetry is planned. Any future optional diagnostics must have explicit consent, narrow data collection, and a clear deletion policy.

### Reliable desktop behavior

Keyboard navigation, accessibility, clear permissions, honest delivery status, recoverable errors, and predictable sleep/resume behavior are core product work. A native interface should feel appropriate on its operating system while using the same underlying conversation semantics.

An application that looks complete but cannot reconnect, retain the intended state, or interoperate correctly is not complete.

### Open ownership and maintenance

BitChat Desktop is a personal open-source project maintained under [youhanasheriff/bitchat-desktop](https://github.com/youhanasheriff/bitchat-desktop). Original project contributions use the [MIT License](../LICENSE), except where otherwise stated. It retains Bitchat's history, attribution, and [upstream Unlicense](../LICENSES/Bitchat-Unlicense.txt); dependencies retain their own licenses.

The project must be buildable without this laptop's company-specific hooks, private infrastructure, or inherited signing identity. Release credentials remain outside source control.

## Technical direction

| Area | Direction |
|---|---|
| Repository | One monorepo, separate platform applications and release artifacts |
| Shared code | Rust protocol/core crates; staged adoption after conformance tests |
| macOS | Retain and evolve the inherited SwiftUI/CoreBluetooth application |
| Windows | Win32 interface and Windows Bluetooth/OS adapters |
| Linux | GTK4 interface and Linux Bluetooth/desktop adapters |
| Interoperability | Pinned upstream behavior, independent fixtures, physical-device tests |
| Distribution | Architecture-specific packages with documented dependencies |
| Size | Measure download, installed footprint, prerequisites, and working data separately |

GTK4 is an explicit Linux dependency. Linux does not provide one UI toolkit built into every desktop. Framework names alone do not establish installation size.

## Scope boundaries

The selected products are macOS, Windows, and Linux desktop applications. Inherited iOS code remains useful implementation material, and iOS/Android Bitchat clients are interoperability peers. New BitChat Desktop mobile apps and a browser client are outside the initial scope.

The initial plan does not include Electron, Flutter, Tauri, a custom messaging server, a new wallet, mandatory analytics, or a new incompatible network. Additional transports and experimental upstream protocols require separate evidence and prioritization.

## What success looks like

- A user on each supported desktop can exchange supported messages with the declared Bitchat client versions.
- Offline mesh operation works on documented Bluetooth hardware without requiring an internet connection.
- Internet transport, privacy settings, and failure states behave as documented.
- Complete packages have published size measurements, and growth is reviewed against agreed budgets.
- Native interaction and accessibility are verified on each operating system.
- Releases can be traced to source, dependencies, checksums, and a reproducible build procedure.
- Unsupported capabilities are visible; no unimplemented feature is advertised as available.

Numeric footprint, latency, reliability, and resource budgets will be set from feature-matched baselines and recorded in the roadmap. The small UI probes in the research report are not finished-product size promises.

## Current position

The public monorepo and native architecture are established. The Apple implementation is inherited and partially rebranded. Windows/Linux clients and the Rust protocol/core/FFI crates are scaffolds. The shared core is not yet connected to the macOS application.

The [roadmap](ROADMAP.md) is the implementation checklist. [Architecture](ARCHITECTURE.md), [upstream provenance](UPSTREAM.md), and [research](DESKTOP-RESEARCH.md) provide supporting detail.
