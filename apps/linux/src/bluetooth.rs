//! BlueZ discovery only. All I/O runs on Tokio; no GTK objects cross threads.
use crate::{
    options::Options,
    state::{ScanSnapshot, ScanStatus},
};
use bluer::{AdapterEvent, DiscoveryFilter, DiscoveryTransport, ErrorKind, Session, Uuid};
use futures_util::{pin_mut, StreamExt};
use std::time::Duration;
use tokio::sync::{oneshot, watch};

pub struct Scan {
    pub updates: watch::Receiver<ScanSnapshot>,
    stop: Option<oneshot::Sender<()>>,
}

impl Scan {
    pub fn start(runtime: &tokio::runtime::Handle, options: Options) -> Self {
        let initial = ScanSnapshot {
            status: ScanStatus::Starting,
            ..Default::default()
        };
        let (updates, receiver) = watch::channel(initial);
        let (stop, cancelled) = oneshot::channel();
        runtime.spawn(async move {
            let result = tokio::select! {
                biased;
                _ = cancelled => Ok(()),
                result = discover(&options, &updates) => result,
                _ = tokio::time::sleep(Duration::from_secs(options.seconds)) => {
                    if matches!(updates.borrow().status, ScanStatus::Starting) {
                        Err("Bluetooth did not become ready in time. Check the Bluetooth service and try again.".into())
                    } else { Ok(()) }
                }
            };
            // Cancelling the future drops the BlueZ discovery stream/session.
            // A coalescing watch channel never queues a backlog of UI events.
            updates.send_modify(|state| match result {
                Ok(()) => state.status = ScanStatus::Finished,
                Err(message) => state.fail(message),
            });
        });
        Self {
            updates: receiver,
            stop: Some(stop),
        }
    }

    pub fn stop(&mut self) {
        if let Some(stop) = self.stop.take() {
            let _ = stop.send(());
        }
    }
}

impl Drop for Scan {
    fn drop(&mut self) {
        self.stop();
    }
}

fn bluez_error(error: bluer::Error) -> String {
    match error.kind {
        ErrorKind::NotAuthorized | ErrorKind::NotPermitted =>
            "Bluetooth access was denied. Check your desktop session's BlueZ permissions; run the app as your normal user.",
        ErrorKind::NotReady =>
            "Bluetooth is turned off or blocked. Enable it in system settings, then scan again.",
        ErrorKind::NotFound | ErrorKind::DoesNotExist =>
            "The Bluetooth adapter is unavailable or was removed. Connect an adapter and scan again.",
        ErrorKind::NotSupported =>
            "This Bluetooth adapter does not support the requested Low Energy discovery.",
        _ => "Cannot communicate with BlueZ. Check that the Bluetooth service is running, then scan again.",
    }.into()
}

async fn discover(options: &Options, updates: &watch::Sender<ScanSnapshot>) -> Result<(), String> {
    let session = Session::new().await.map_err(bluez_error)?;
    let adapter = if let Some(name) = &options.adapter {
        session.adapter(name).map_err(bluez_error)?
    } else {
        let mut names = session.adapter_names().await.map_err(bluez_error)?;
        names.sort();
        if names.is_empty() {
            return Err(
                "No Bluetooth adapter found. Connect a Low Energy adapter and scan again.".into(),
            );
        }
        let mut selected = None;
        for name in names {
            let candidate = session.adapter(&name).map_err(bluez_error)?;
            if candidate.is_powered().await.map_err(bluez_error)? {
                selected = Some(candidate);
                break;
            }
        }
        selected.ok_or(
            "Bluetooth is turned off. Enable an adapter in system settings, then scan again.",
        )?
    };
    if !adapter.is_powered().await.map_err(bluez_error)? {
        return Err("Bluetooth is turned off. Enable the selected adapter in system settings, then scan again.".into());
    }
    // Respect the user's radio setting. Never power on or make the adapter
    // discoverable, pair, connect, or advertise as a functional mesh peer.
    adapter
        .set_discovery_filter(DiscoveryFilter {
            uuids: [Uuid::from_u128(options.network.service_uuid())]
                .into_iter()
                .collect(),
            transport: DiscoveryTransport::Le,
            duplicate_data: false,
            ..Default::default()
        })
        .await
        .map_err(bluez_error)?;
    let events = adapter
        .discover_devices_with_changes()
        .await
        .map_err(bluez_error)?;
    pin_mut!(events);
    updates.send_modify(|s| s.status = ScanStatus::Scanning(adapter.name().into()));
    let mut health = tokio::time::interval(Duration::from_secs(2));
    loop {
        tokio::select! {
            event = events.next() => match event {
                Some(AdapterEvent::DeviceAdded(address)) => {
                    let device = adapter.device(address).map_err(bluez_error)?;
                    // Devices can disappear between a signal and a property
                    // read. Bound the read and ignore that transient failure.
                    let details = tokio::time::timeout(Duration::from_secs(2), async {
                        let uuids = device.uuids().await?.unwrap_or_default();
                        let name = device.name().await?;
                        let rssi = device.rssi().await?;
                        Ok::<_, bluer::Error>((uuids, name, rssi))
                    }).await;
                    if let Ok(Ok((uuids, name, rssi))) = details {
                        updates.send_modify(|state| state.observe(address.to_string(), name, rssi,
                            uuids.into_iter().map(|u| u.as_u128()), options.network));
                    }
                }
                Some(AdapterEvent::DeviceRemoved(address)) => {
                    updates.send_modify(|s| { s.devices.remove(&address.to_string()); });
                }
                Some(_) => (),
                None => return Err("Bluetooth discovery ended unexpectedly. Check the adapter and scan again.".into()),
            },
            _ = health.tick() => {
                // Also catches daemon restarts/removal even without device events.
                if !adapter.is_powered().await.map_err(bluez_error)? {
                    return Err("Bluetooth was turned off. Enable it in system settings and scan again.".into());
                }
            }
        }
    }
}
