use std::collections::BTreeMap;

pub const MAX_DEVICES: usize = 128;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Network {
    Mainnet,
    Testnet,
}

impl Network {
    // Pinned Apple implementation: Services/BLE/BLEService.swift. Do not derive
    // the network from Rust's debug assertions: development should interoperate
    // with shipping clients unless the isolated testnet is explicitly selected.
    pub fn service_uuid(self) -> u128 {
        match self {
            Self::Mainnet => 0xf47b5e2d_4a9e_4c5a_9b3f_8e1d2c3a4b5c,
            Self::Testnet => 0xf47b5e2d_4a9e_4c5a_9b3f_8e1d2c3a4b5a,
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            Self::Mainnet => "Mainnet",
            Self::Testnet => "Testnet",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ScanStatus {
    Ready,
    Starting,
    Scanning(String),
    Finished,
    Failed(String),
}

impl ScanStatus {
    pub fn is_active(&self) -> bool {
        matches!(self, Self::Starting | Self::Scanning(_))
    }
}

/// A transport address is not a Bitchat peer ID or authenticated identity.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DiscoveredDevice {
    pub address: String,
    pub name: String,
    pub rssi: Option<i16>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScanSnapshot {
    pub status: ScanStatus,
    pub devices: BTreeMap<String, DiscoveredDevice>,
    pub at_capacity: bool,
}

impl Default for ScanSnapshot {
    fn default() -> Self {
        Self {
            status: ScanStatus::Ready,
            devices: BTreeMap::new(),
            at_capacity: false,
        }
    }
}

impl ScanSnapshot {
    pub fn observe(
        &mut self,
        address: String,
        name: Option<String>,
        rssi: Option<i16>,
        service_uuids: impl IntoIterator<Item = u128>,
        network: Network,
    ) {
        // BlueZ merges filters from all clients and includes cached devices.
        // Never trust a scan event alone as proof of a matching service.
        if !service_uuids
            .into_iter()
            .any(|uuid| uuid == network.service_uuid())
        {
            self.devices.remove(&address);
            return;
        }
        if self.devices.len() >= MAX_DEVICES && !self.devices.contains_key(&address) {
            self.at_capacity = true;
            return;
        }
        let name: String = name
            .unwrap_or_default()
            .chars()
            .filter(|c| {
                !c.is_control() && !matches!(*c, '\u{202a}'..='\u{202e}' | '\u{2066}'..='\u{2069}')
            })
            .take(64)
            .collect();
        let name = if name.trim().is_empty() {
            "Unnamed device".into()
        } else {
            name
        };
        self.devices.insert(
            address.clone(),
            DiscoveredDevice {
                address,
                name,
                rssi,
            },
        );
    }

    pub fn fail(&mut self, message: String) {
        self.status = ScanStatus::Failed(message);
        self.devices.clear();
        self.at_capacity = false;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn observe(state: &mut ScanSnapshot, address: &str, uuid: u128) {
        state.observe(
            address.into(),
            Some("Phone".into()),
            Some(-55),
            [uuid],
            Network::Mainnet,
        );
    }

    #[test]
    fn ignores_unrelated_and_debug_network_devices() {
        let mut state = ScanSnapshot::default();
        observe(&mut state, "testnet", Network::Testnet.service_uuid());
        observe(&mut state, "other", 0);
        observe(&mut state, "mainnet", Network::Mainnet.service_uuid());
        assert_eq!(state.devices.len(), 1);
        assert!(state.devices.contains_key("mainnet"));
        observe(&mut state, "mainnet", 0);
        assert!(state.devices.is_empty());
    }

    #[test]
    fn bounds_devices_but_allows_existing_device_updates() {
        let mut state = ScanSnapshot::default();
        for i in 0..MAX_DEVICES + 10 {
            observe(&mut state, &i.to_string(), Network::Mainnet.service_uuid());
        }
        assert_eq!(state.devices.len(), MAX_DEVICES);
        assert!(state.at_capacity);
        state.observe(
            "0".into(),
            Some("Updated".into()),
            None,
            [Network::Mainnet.service_uuid()],
            Network::Mainnet,
        );
        assert_eq!(state.devices["0"].name, "Updated");
        state.fail("Adapter removed".into());
        assert!(state.devices.is_empty());
        assert!(!state.status.is_active());
    }

    #[test]
    fn remote_names_cannot_inject_terminal_controls_or_grow_unbounded() {
        let mut state = ScanSnapshot::default();
        state.observe(
            "A".into(),
            Some(format!("\x1b\n\u{202e}{}", "é".repeat(200))),
            None,
            [Network::Mainnet.service_uuid()],
            Network::Mainnet,
        );
        assert_eq!(state.devices["A"].name, "é".repeat(64));
    }
}
