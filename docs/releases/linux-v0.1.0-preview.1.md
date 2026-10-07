# BitChat Desktop — Linux discovery preview 0.1.0-preview.1

This first Linux preview provides a native GTK4 window and a headless command for discovering devices that advertise the Bitchat Bluetooth service. **It does not send or receive messages, join the mesh, or verify peer identities.**

## Downloads and requirements

Choose the archive matching `uname -m`:

- `BitChat-Desktop-0.1.0-preview.1-linux-x86_64.tar.gz`: Intel/AMD 64-bit Linux.
- `BitChat-Desktop-0.1.0-preview.1-linux-aarch64.tar.gz`: ARM64 Linux.

Each archive has a SHA-256 sidecar and a JSON manifest with its source commit, architecture, executable hash, and compressed size. These are unsigned experimental archives, not distribution packages or self-contained bundles.

The binaries are built on Debian 12 with Rust 1.85. They require glibc 2.36+, GTK 4.8+, libdbus, and their distribution-provided shared libraries. Bluetooth discovery also needs a running BlueZ system service, a supported Low Energy adapter, and access from your normal desktop session. The GUI needs an X11 or Wayland session; the headless scan does not need a display. Wayland and physical hardware have not been qualified.

On Debian 12:

```sh
sudo apt-get update
sudo apt-get install libgtk-4-1 libdbus-1-3 bluez
```

On Ubuntu 24.04, the GTK runtime package is named `libgtk-4-1t64`:

```sh
sudo apt-get update
sudo apt-get install libgtk-4-1t64 libdbus-1-3 bluez
```

Ubuntu 24.04 is a development target; the preview's build and simulated integration checks use Debian 12. Runtime libraries are not included in the archive's download size.

## Install and run

Download the archive and its `.sha256` sidecar into the same directory. For x86_64 (substitute `aarch64` in all names for ARM64):

```sh
sha256sum -c BitChat-Desktop-0.1.0-preview.1-linux-x86_64.tar.gz.sha256
tar -xzf BitChat-Desktop-0.1.0-preview.1-linux-x86_64.tar.gz
cd BitChat-Desktop-0.1.0-preview.1-linux-x86_64
./bitchat-desktop
```

Enable Bluetooth in system settings, open Bitchat on a nearby device, and choose **Scan for devices**. The scan stops after 30 seconds or when cancelled. Mainnet is the default; use Testnet only with upstream isolated debug clients. Run the app as your normal user, not root.

For terminal discovery:

```sh
./bitchat-desktop --scan --seconds 15
./bitchat-desktop --scan --adapter hci0
./bitchat-desktop --scan --testnet
./bitchat-desktop --help
```

The app does not install a service or write message/device history. To remove it, delete the extracted directory. The system's Bluetooth service maintains its own device cache independently.

## Validation and limitations

The release workflow builds natively on x86_64 and ARM64, runs six portable Rust tests and six simulated BlueZ integration tests, and launches/closes GTK under Xvfb. Each packaged executable is extracted and smoke-tested before upload. The archive includes the project license, locked Rust dependency notices, and a record of the build environment's shared-library dependencies.

The scanner independently checks service UUIDs, handles missing/disabled adapters and access errors, and cancels discovery on shutdown. Results may include cached or out-of-range devices; device names, addresses, and RSSI do not prove authenticated identity or reachability. At most 128 matching devices are displayed.

**Not implemented or hardware-qualified:** peripheral advertising, bidirectional GATT communication, Noise encryption, messaging, Nostr, keyring storage, notifications, distro installers, and complete platform parity. This release invites development and hardware discovery feedback; it is not a secure messenger yet.

Source and issues: https://github.com/youhanasheriff/bitchat-desktop
