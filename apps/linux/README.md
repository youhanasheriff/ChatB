# BitChat Desktop for Linux

The first Linux implementation is a **native GTK4 discovery preview**, written in Rust. It scans through BlueZ for the Bitchat Bluetooth service and shows matching devices. A headless command uses the same discovery backend.

This is not yet a messenger: advertising, GATT connections, packet codecs, Noise authentication, shared-core integration, secure storage, Nostr, notifications, and packaging remain to be implemented. A discovered device is not a verified Bitchat identity. Bluetooth hardware interoperability has not been qualified.

## Build and run

The development baseline is **Debian 12 / GTK 4.8 / BlueZ 5.66**, with Rust **1.85 or newer**. Ubuntu 24.04 is also a development target. The locked dependency graph is checked with Rust 1.85 in CI; this does not establish a supported distro/hardware matrix. Use the native architecture's toolchain (x86_64 or aarch64).

On Debian 12 or Ubuntu 24.04, install Rust and these dependencies:

```sh
sudo apt-get update
sudo apt-get install build-essential pkg-config libgtk-4-dev libdbus-1-dev bluez
bash apps/linux/scripts/build-local.sh
./target/release/bitchat-desktop
```

GTK4, GLib, libdbus, their shared-library dependencies, a desktop session, and the BlueZ system service must be installed at runtime. The executable is dynamically linked; its file size does not represent the complete installation footprint. The build script checks GTK >= 4.8. No system-wide installation is performed.

Enable Bluetooth in your desktop's system settings and choose **Scan for devices**. Scanning stops after 30 seconds; **Stop scan** cancels early. The app does not turn on the radio, change adapter discoverability, connect to devices, or advertise as a functioning mesh node. Closing the window cancels discovery. Scan again after changing radio settings or reconnecting an adapter.

### Headless discovery

```sh
./target/release/bitchat-desktop --scan --seconds 15
./target/release/bitchat-desktop --scan --adapter hci1
./target/release/bitchat-desktop --scan --testnet
./target/release/bitchat-desktop --help
```

`--seconds` accepts 1–300 and applies only to `--scan`. Without `--adapter`, the first powered adapter in sorted BlueZ name order is used. Ctrl+C stops a headless scan and prints the results collected so far. Exit codes are 0 for a completed/cancelled scan, 1 for runtime failure, and 2 for invalid arguments. Device names/addresses appear only in the requested terminal output or UI, with no application persistence.

The default network uses service `F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C`, including in Rust debug builds. `--testnet` (or the UI picker) selects `F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5A`. These match the pinned [Apple BLE implementation](../macos/bitchat/Services/BLE/BLEService.swift). For a macOS Debug interoperability build, use its `BITCHAT_INTEROP` setting or select testnet consistently on both sides.

BlueZ merges filters across applications and reports cached devices. The app independently checks the selected service UUID, but a result does **not** prove current reachability, an authenticated peer identity, or message delivery. RSSI may be absent or stale. At most 128 matching devices are retained; remote names are stripped of control/directional formatting characters and limited to 64 characters.

## Architecture

- `src/state.rs`: bounded discovery snapshots and network identifiers; portable unit tests.
- `src/options.rs`: command-line validation; portable unit tests.
- `src/bluetooth.rs`: [BlueR](https://github.com/bluez/bluer) discovery on a two-thread Tokio runtime. It uses the BlueZ system D-Bus service, checks radio health, and drops the discovery stream/session on cancellation, timeout, or failure.
- `src/ui.rs`: native GTK widgets owned only by the GTK main thread. A coalescing watch channel holds only the latest snapshot; the GTK loop polls it every 100 ms. Closing the window cancels the worker and releases the UI polling callback.
- `src/main.rs`: chooses GUI or headless mode and owns runtime shutdown.

The shared protocol/core crates remain separate scaffolds. GTK/BlueZ dependencies are Linux-only; macOS and Windows workspace checks test the portable state/argument code and compile a binary that reports the unsupported platform rather than simulating a Linux client.

## Validation

On Linux:

```sh
sudo apt-get install xvfb xauth dbus-x11 python3-dbusmock
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
bash apps/linux/scripts/check.sh
```

The check script runs unit tests, builds the app, launches/closes GTK under Xvfb without touching Bluetooth, verifies an actionable missing-system-bus failure, and exercises service filtering, cancellation, disabled/missing adapters, radio power loss, and permission denial against an isolated mocked BlueZ service. These are simulated D-Bus checks, not hardware tests. The dedicated Linux CI job also builds with the minimum Rust version.

From macOS or another Docker host, validate the native Linux target without mixing platform build caches:

```sh
docker build -t bitchat-linux-check -f apps/linux/Dockerfile apps/linux
docker run --rm --init -v "$PWD:/workspace:ro" \
  -v bitchat-linux-target:/linux-target \
  -v bitchat-linux-registry:/usr/local/cargo/registry \
  bitchat-linux-check
```

Docker on macOS does not expose the Mac's Bluetooth controller. Container checks do not qualify physical discovery, GATT behavior, Wayland, or production packaging. Hardware acceptance must record distro/desktop, CPU, adapter/chipset, BlueZ version, selected network, peer app/version, scan results, radio toggles, adapter removal, and cancellation. See [the roadmap](../../docs/ROADMAP.md#2-prove-desktop-bluetooth-feasibility-early).

## Troubleshooting

- **Cannot open a graphical display:** run inside a desktop session, or use `--scan` for discovery without a display.
- **Cannot communicate with BlueZ:** check `systemctl status bluetooth` and the system D-Bus service. Containers ordinarily have neither a host adapter nor access to that bus.
- **No adapter / Bluetooth turned off:** connect an LE adapter and enable it in system settings. Check `rfkill list` for a radio block.
- **Access denied:** check the distribution's BlueZ/Polkit rules and log in to a normal active desktop session. Do not run the GUI as root or add broad D-Bus permissions.
- **No matching devices:** open Bitchat on a nearby device, confirm mainnet/testnet selection, and scan again. The preview does not broadcast its own presence.
