# BitChat Desktop for Windows

Native Win32 **discovery preview**, using Windows Bluetooth/WinRT. Finds advertisements for the pinned Bitchat mainnet UUID; the isolated debug service is explicitly opt-in. There is no advertising, GATT transport, messaging, shared protocol integration, persistence, or verified identity yet.

[Download and release notes](https://github.com/youhanasheriff/bitchat-desktop/releases/tag/windows-v0.1.0-preview.1) · [requirements and limitations](../../docs/releases/windows-v0.1.0-preview.1.md)

## Build on Windows x64

Install Rust 1.85.1+ with the MSVC toolchain and Visual Studio C++ Build Tools / Windows SDK. In PowerShell at the repository root:

```powershell
$env:RUSTFLAGS = '-C target-feature=+crt-static'
cargo build -p bitchat-desktop-windows --release --locked
.\target\release\bitchat-desktop-windows.exe
.\target\release\bitchat-scan.exe --scan --seconds 15
```

A GUI executable avoids a console window; the separate `bitchat-scan.exe` supports terminal output, `--help`, `--version`, `--scan`, `--seconds 1..300`, and `--testnet`. Ctrl+C terminates the CLI process and Windows releases its watcher. GUI scans have a 30-second deadline and stop/close cleanup. The application never switches on the radio or pairs/connects to a device.

## Verify

```powershell
cargo test -p bitchat-desktop-windows --locked
cargo clippy -p bitchat-desktop-windows --all-targets --locked -- -D warnings
.\apps\windows\scripts\check.ps1
python packaging/windows/package-preview.py (git rev-parse HEAD)
```

The UI script needs an interactive Windows desktop and emits real screenshots under `dist/validation`. The release workflow builds on Windows Server 2025 at the minimum Rust version. Portable tests also run on macOS/Linux; those do not execute Win32 or WinRT.

WinRT callbacks write bounded, per-session snapshots; only the main thread owns native controls. Stops mark the snapshot inactive before unregistering callbacks. Stale callbacks cannot add results after stop or affect a later scan. Names are bounded and stripped of terminal/control and directional override characters. WinRT filtering is supplemented by explicit UUID matching for each received advertisement. Nonmatching scan responses do not erase an earlier observation.

## Hardware acceptance remains open

Record Windows version, adapter/driver, Bitchat peer versions and logs for positive mainnet/testnet discovery, radio off/removal, permission/policy errors, restart, sleep/resume and cancellation. Qualify peripheral advertising, simultaneous roles and bidirectional GATT before claiming mesh compatibility. Use [Microsoft's watcher documentation](https://learn.microsoft.com/en-us/uwp/api/windows.devices.bluetooth.advertisement.bluetoothleadvertisementwatcher) for platform semantics.
