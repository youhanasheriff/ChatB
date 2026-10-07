# Windows discovery preview · 0.1.0-preview.2

A Windows Setup installer for the native Win32 app and terminal scanner, with a Start menu shortcut and an Installed apps uninstall entry. **Discovery only:** no advertising, GATT connections, messaging, encryption, stored identities, Nostr, or mesh participation. Physical Bluetooth interoperability remains unqualified.

## Install

1. Download `BitChat-Desktop-0.1.0-preview.2-windows-x86_64-setup.exe` and its `.sha256` sidecar.
2. In PowerShell, run `Get-FileHash .\BitChat-Desktop-0.1.0-preview.2-windows-x86_64-setup.exe -Algorithm SHA256` and compare it with the published checksum.
3. Run Setup and follow the installation wizard. It installs for your current account; administrator rights are not required.
4. Open **BitChat Desktop** from the Start menu. Enable Bluetooth in Windows Settings, then select **Start scan**.

The default installation folder is `%LOCALAPPDATA%\Programs\BitChat Desktop`. Setup installs both executables, dependency notices, and source provenance. Running Setup again updates the same installation. Uninstall through **Settings → Apps → Installed apps → BitChat Desktop**, or the installation folder's uninstaller. The application writes no device/message history. Setup does not add a service, startup task, or PATH entry.

The installer and executables are **unsigned**. Windows may display a SmartScreen or publisher warning. Verify the source and checksum before deciding whether to run the installer; do not disable system-wide protection.

## Requirements and portable alternative

- Intel/AMD 64-bit Windows. Windows 11 recommended; Windows 10 22H2 is the API baseline. Automated execution uses Windows Server 2025. Physical Windows 10/11 qualification remains open.
- Bluetooth LE adapter and working Windows driver, with Bluetooth enabled in Settings.
- No separate browser, .NET, or Visual C++ runtime installation is required.
- Native ARM64 and emulated ARM64 installations are outside this installer’s target matrix.

A separate `.zip` remains available for portable use. Extract it and launch `bitchat-desktop-windows.exe` without installing.

For terminal discovery after installing to the default location:

```powershell
& "$env:LOCALAPPDATA\Programs\BitChat Desktop\bitchat-scan.exe" --scan --seconds 15
```

GUI scans stop after 30 seconds, or when you select Stop scan or close the app. Names and addresses are unverified advertisements, not peer identities. No scan results are persisted by the app.

## Validation and limitations

CI tests state/argument validation, native UI launch, network controls, no-radio errors, retry, resize and teardown. Packaging validates both PE binaries and portable archive contents, builds Setup with Inno Setup, installs it, compares installed binary hashes, checks the Start menu shortcut and uninstall registration, launches both installed executables, reinstalls in place, and verifies uninstall cleanup.

There is no qualified Bluetooth hardware in CI. Positive physical discovery, adapter changes, sleep/resume and screen-reader usability remain to be qualified. Source and dependencies are recorded in the installed manifest, Cargo.lock and THIRD-PARTY-NOTICES.txt; installer checksums and provenance are also published as sidecars.
