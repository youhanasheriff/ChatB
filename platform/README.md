# Platform adapters

Native apps own OS-specific interfaces and capabilities. The planned adapter responsibilities are Bluetooth central/peripheral access, secure identity storage, notifications, permissions, media, and lifecycle handling.

- macOS: existing CoreBluetooth and Apple integrations remain in `apps/macos/bitchat`.
- Windows: Windows Bluetooth/WinRT passive discovery implemented in `apps/windows`; other OS services and GATT transport remain pending.
- Linux: `apps/linux/src/bluetooth.rs` implements cancellable BlueZ LE discovery for the selected Bitchat service. GATT central/peripheral transport and other desktop services remain pending.

The shared core should receive transport events and emit actions without importing an OS UI framework. Adapter contracts will be defined alongside a working transport proof.
