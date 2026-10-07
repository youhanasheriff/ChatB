use crate::state::{Network, ScanSnapshot, ScanStatus};
use std::sync::{Arc, Mutex};
use windows::{
    core::GUID,
    Devices::Bluetooth::{Advertisement::*, BluetoothError},
    Foundation::TypedEventHandler,
};

pub type SharedSnapshot = Arc<Mutex<ScanSnapshot>>;

/// Each session owns its watcher, event subscriptions and snapshot. Old callbacks
/// can never write into a new scan. No HWND or UI pointer crosses a callback.
pub struct Scanner {
    watcher: BluetoothLEAdvertisementWatcher,
    received: Option<i64>,
    stopped: Option<i64>,
    pub state: SharedSnapshot,
}

impl Scanner {
    pub fn start(network: Network) -> windows::core::Result<Self> {
        let watcher = BluetoothLEAdvertisementWatcher::new()?;
        // Passive scanning never sends scan requests; only advertised names are available.
        watcher.SetScanningMode(BluetoothLEScanningMode::Passive)?;
        watcher
            .AdvertisementFilter()?
            .Advertisement()?
            .ServiceUuids()?
            .Append(GUID::from_u128(network.service_uuid()))?;
        let state = Arc::new(Mutex::new(ScanSnapshot {
            status: ScanStatus::Starting,
            ..Default::default()
        }));
        let mut scanner = Self {
            watcher,
            received: None,
            stopped: None,
            state,
        };
        let observed = scanner.state.clone();
        scanner.received = Some(scanner.watcher.Received(&TypedEventHandler::<
            BluetoothLEAdvertisementWatcher,
            BluetoothLEAdvertisementReceivedEventArgs,
        >::new(move |_, args| {
            if let Some(args) = args.as_ref() {
                let advert = args.Advertisement()?;
                let uuids: Vec<u128> = advert
                    .ServiceUuids()?
                    .into_iter()
                    .map(|id| id.to_u128())
                    .collect();
                let address = args.BluetoothAddress()?;
                let address = (0..6)
                    .rev()
                    .map(|shift| format!("{:02X}", (address >> (shift * 8)) & 255))
                    .collect::<Vec<_>>()
                    .join(":");
                let name = advert.LocalName().ok().map(|s| s.to_string());
                let rssi = args.RawSignalStrengthInDBm().ok();
                if let Ok(mut snapshot) = observed.lock() {
                    snapshot.observe(address, name, rssi, uuids, network);
                }
            }
            Ok(())
        }))?);
        let stopped = scanner.state.clone();
        scanner.stopped = Some(scanner.watcher.Stopped(&TypedEventHandler::<
            BluetoothLEAdvertisementWatcher,
            BluetoothLEAdvertisementWatcherStoppedEventArgs,
        >::new(move |_, args| {
            let error = args.as_ref().and_then(|event| event.Error().ok());
            if let Ok(mut snapshot) = stopped.lock() {
                // Explicit stop wins over late OS events.
                if snapshot.status.is_active() {
                    match error {
                        Some(BluetoothError::Success) => snapshot.status = ScanStatus::Finished,
                        Some(error) => snapshot.fail(error_message(error)),
                        None => snapshot.fail(
                            "Windows stopped discovery without an error code. Try scanning again."
                                .into(),
                        ),
                    }
                }
            }
            Ok(())
        }))?);
        scanner.watcher.Start()?;
        if let Ok(mut snapshot) = scanner.state.lock() {
            if snapshot.status == ScanStatus::Starting {
                snapshot.status = ScanStatus::Scanning("Windows Bluetooth".into());
            }
        }
        Ok(scanner)
    }

    pub fn snapshot(&self) -> ScanSnapshot {
        self.state.lock().unwrap_or_else(|e| e.into_inner()).clone()
    }

    pub fn stop(&mut self) {
        if let Ok(mut state) = self.state.lock() {
            if state.status.is_active() {
                state.status = ScanStatus::Finished;
            }
        }
        let _ = self.watcher.Stop();
        if let Some(token) = self.received.take() {
            let _ = self.watcher.RemoveReceived(token);
        }
        if let Some(token) = self.stopped.take() {
            let _ = self.watcher.RemoveStopped(token);
        }
    }
}

impl Drop for Scanner {
    fn drop(&mut self) {
        self.stop();
    }
}

pub fn error_message(error: BluetoothError) -> String {
    let message = match error {
        BluetoothError::RadioNotAvailable => "Bluetooth is unavailable. Enable Bluetooth in Windows Settings and check your adapter.",
        BluetoothError::ResourceInUse => "Bluetooth is busy. Close other Bluetooth tools and try again.",
        BluetoothError::DeviceNotConnected => "The Bluetooth adapter disconnected. Reconnect it and scan again.",
        BluetoothError::DisabledByPolicy => "Bluetooth is disabled by system policy. Contact your administrator.",
        BluetoothError::DisabledByUser => "Bluetooth is turned off. Enable it in Windows Settings.",
        BluetoothError::NotSupported => "This adapter or driver does not support Bluetooth LE discovery.",
        BluetoothError::ConsentRequired => "Bluetooth access is denied. Review Windows privacy and Bluetooth settings.",
        _ => "Bluetooth discovery failed. Check your adapter and Windows Bluetooth settings, then retry.",
    };
    format!("{message} (Windows code {})", error.0)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn errors_give_actionable_radio_policy_and_support_guidance() {
        for (code, text) in [
            (BluetoothError::RadioNotAvailable, "Enable"),
            (BluetoothError::DisabledByPolicy, "policy"),
            (BluetoothError::NotSupported, "support"),
            (BluetoothError::ConsentRequired, "privacy"),
        ] {
            assert!(error_message(code).contains(text));
        }
    }
}
