# Windows discovery preview · 0.1.0-preview.1

A native Win32 window and Windows Bluetooth LE advertisement scanner for Intel/AMD 64-bit PCs. **Discovery only:** no advertising, GATT connections, messaging, encryption, stored identities, Nostr, or mesh participation. Physical Bluetooth interoperability remains unqualified.

## Requirements

- Windows 11 x64 recommended. Windows 10 22H2 is the API baseline, not a qualified test environment. Automated execution uses Windows Server 2025 on GitHub-hosted x64 runners. ARM64-native builds are not included.
- Bluetooth LE adapter and a working Windows driver, with Bluetooth enabled in Settings. Adapter selection uses Windows' default controller.
- No bundled browser, .NET installation, or separate Visual C++ redistributable is required; the C runtime is statically linked.

## Install and run

1. Download `BitChat-Desktop-0.1.0-preview.1-windows-x86_64.zip` and its `.sha256` checksum from the release assets.
2. In PowerShell, run `Get-FileHash .\BitChat-Desktop-0.1.0-preview.1-windows-x86_64.zip -Algorithm SHA256` and compare it with the published checksum.
3. Extract the entire ZIP and open `bitchat-desktop-windows.exe` as your normal user. No administrator rights are needed.
4. Enable Bluetooth in Windows Settings, then select **Start scan**. Each scan lasts up to 30 seconds; **Stop scan** ends it early. The isolated testnet is opt-in and separate from shipping clients.

The executables are **unsigned**. Windows may display a SmartScreen or publisher warning. Verify the download and source before deciding whether to run it; do not disable system-wide security protection.

For a terminal scan from the extracted directory:

```powershell
.\bitchat-scan.exe --scan --seconds 15
.\bitchat-scan.exe --scan --testnet --seconds 15
.\bitchat-scan.exe --help
```

Names and transport addresses are unverified, can change or be spoofed, and are not Bitchat peer identities. Scanning is passive, so a device name may not be advertised. At most 128 matching addresses are shown; results represent observations during the last scan, not confirmed ongoing presence. No scan logs or device information are saved by the app. Closing the app releases its watcher. Windows may continue scanning for other applications.

## Evidence and limitations

The build workflow runs Rust state/argument tests, native window launch, network toggles, actual WinRT scan attempts and error/retry handling, resizing, teardown, PE architecture/subsystem checks, dependency notices, archive checksums, and launch of the extracted package. CI has no qualified Bluetooth hardware. Positive discovery, radio removal/toggling, sleep/resume, screen-reader usability, and physical Windows 10/11 compatibility require hardware testing before wider support claims.

Source and build provenance are in the archive's `manifest.json`; exact dependency versions and attribution are in `Cargo.lock` and `THIRD-PARTY-NOTICES.txt`.
