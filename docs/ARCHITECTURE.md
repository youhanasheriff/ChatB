# BitChat Desktop desktop architecture

The [vision and mission](VISION-AND-MISSION.md) define the product commitments. The [roadmap](ROADMAP.md) tracks implementation and acceptance work across all three platforms.

## Targets and status

BitChat Desktop targets native macOS, Windows, and Linux interfaces with minimum practical installation size. The working source starting point is the inherited macOS Swift client. Windows has a Win32/WinRT discovery preview and Linux has a GTK4/BlueZ discovery preview. Neither is a messaging client. The shared Rust protocol/core/FFI crates remain scaffolds.

## Boundaries

- `crates/protocol`: wire codecs and cryptographic protocol formats.
- `crates/core`: protocol state machines, routing, deduplication, and shared application logic.
- `crates/ffi`: a narrow C-compatible bridge with explicit ownership and threading rules.
- `apps/macos`: SwiftUI/AppKit interface and Apple integration.
- `apps/windows`: Win32 interface and Windows integration.
- `apps/linux`: GTK4 interface and Linux integration.
- `platform`: adapter documentation and future platform support code.
- `tests/interop`: independent fixtures and future conformance checks.
- `packaging`: separate distribution and footprint measurements.

The Rust core is a planned port; it cannot import the existing Swift protocol implementation unchanged. Keep the existing Mac implementation while porting independently testable pieces.

## Implementation order

1. Maintain a buildable, independently branded macOS baseline.
2. Prove Windows and Linux discovery, advertising, bidirectional GATT communication, and reconnects on hardware.
3. Port codecs and cryptographic envelopes with independent upstream fixtures.
4. Add the shared state machine and connect each native client through adapters.
5. Verify cross-client mesh and Nostr behavior, including Tor privacy behavior.
6. Package architecture-specific builds and measure complete installation footprint.

## Compatibility and footprint

Preserve Bitchat wire semantics independently from BitChat Desktop branding. Generic BLE or Nostr libraries alone do not establish interoperability.

GTK/webview/shared runtime dependencies count when missing on the target machine. Preserve Tor behavior when claiming upstream privacy parity. Compare final releases with the same supported features rather than ranking incomplete UI probes.
