# BitChat Desktop — Linux discovery preview 0.1.0-preview.2

Installable **Debian/Ubuntu packages** for Intel/AMD 64-bit and ARM64, with an application-menu entry, icon, dependency installation, and package-manager removal. The native GTK4 app and terminal scanner remain **discovery-only**: no messaging, GATT connections, mesh participation, or verified peer identities.

## Install

Use Debian 12 or Ubuntu 24.04. Choose the package matching `dpkg --print-architecture`:

- `bitchat-desktop_0.1.0~preview.2-1_amd64.deb` — Intel/AMD 64-bit.
- `bitchat-desktop_0.1.0~preview.2-1_arm64.deb` — ARM64.

Download the `.deb` and its `.sha256` sidecar from this release. Verify and install (replace `amd64` with `arm64` when needed):

```sh
sha256sum -c 'bitchat-desktop_0.1.0~preview.2-1_amd64.deb.sha256'
sudo apt update
sudo apt install './bitchat-desktop_0.1.0~preview.2-1_amd64.deb'
```

APT installs the required GTK, D-Bus, and BlueZ libraries. Internet access is needed when those dependencies are missing. A graphical package installer that supports local `.deb` files can also open the package; the APT command works across both target distributions.

Open **BitChat Desktop** from your application menu, or run `bitchat-desktop` in a terminal. Run the app as your normal user. Enable Bluetooth in system settings, then choose **Scan for devices**. Mainnet is the default; the isolated testnet is opt-in.

```sh
bitchat-desktop --scan --seconds 15
bitchat-desktop --scan --adapter hci0
bitchat-desktop --help
```

To reinstall or upgrade, install the newer `.deb` with APT. To uninstall:

```sh
sudo apt remove bitchat-desktop
```

The package installs `/usr/bin/bitchat-desktop`, a desktop launcher and icon, and notices/provenance under `/usr/share/doc/bitchat-desktop`. It creates no application service and changes no Bluetooth policy. BlueZ is a distribution dependency; its service manages the radio and system device cache independently.

## Portable alternative and requirements

`.tar.gz` archives remain available for manual use. Extract one, install its system libraries, and run `./bitchat-desktop` from the extracted directory. These are alternatives to the primary `.deb` installers. Fedora/RPM and other distribution packages are not included.

The binaries require glibc 2.36+, GTK 4.8+, libdbus and a desktop session. A compatible Bluetooth LE adapter, a running BlueZ service, and normal-session access are needed for discovery. Runtime libraries are supplied by the distribution and are additional to the package download size. Packages and archives are unsigned; compare the published SHA-256 checksums.

## Validation and limitations

Native x86_64 and ARM64 builds run portable state tests, simulated BlueZ integration tests, and GTK smoke checks. The `.deb` payload is verified against the archive binary. Clean Debian 12 and Ubuntu 24.04 containers install dependencies, launch the installed GTK app as an unprivileged user under Xvfb, reinstall the package, and verify removal of its files. These checks do not qualify physical Bluetooth hardware or Wayland.

Results may include cached devices and are not authenticated identities or proof of reachability. At most 128 addresses are shown. Physical discovery/interoperability, advertising, bidirectional GATT, encryption, messaging, Nostr and complete platform parity remain unqualified or unimplemented. This packaging update does not add messaging.

Each asset has checksum and JSON provenance sidecars. The included manifest records the source commit; the release tag identifies the installer source, including its packaging scripts.
