#[cfg(windows)]
fn main() {
    use bitchat_desktop_windows::{
        bluetooth::Scanner,
        options::{Mode, Options, HELP},
        state::ScanStatus,
    };
    use std::time::{Duration, Instant};
    let run = || -> Result<(), String> {
        let options = Options::parse(std::env::args().skip(1))?;
        match options.mode {
            Mode::Help | Mode::Gui => {
                println!("{HELP}");
                return Ok(());
            }
            Mode::Version => {
                println!(
                    "BitChat Desktop Windows {} discovery preview",
                    env!("CARGO_PKG_VERSION")
                );
                return Ok(());
            }
            Mode::SmokeTest => {
                return Err("Run bitchat-desktop-windows.exe --smoke-test for the UI check.".into())
            }
            Mode::Scan => {}
        }
        let _apartment =
            bitchat_desktop_windows::ui::Apartment::new().map_err(|e| e.to_string())?;
        let mut scanner = Scanner::start(options.network)
            .map_err(|e| format!("Cannot start Bluetooth discovery: {e}"))?;
        println!(
            "{} discovery for {} seconds. Addresses and names are unverified; no messaging.",
            options.network.label(),
            options.seconds
        );
        let deadline = Instant::now() + Duration::from_secs(options.seconds);
        while Instant::now() < deadline && scanner.snapshot().status.is_active() {
            std::thread::sleep(Duration::from_millis(100));
        }
        scanner.stop();
        let snapshot = scanner.snapshot();
        if let ScanStatus::Failed(error) = snapshot.status {
            return Err(error);
        }
        for device in snapshot.devices.values() {
            println!(
                "{}  {} dBm  {}",
                device.address,
                device
                    .rssi
                    .map(|n| n.to_string())
                    .unwrap_or_else(|| "?".into()),
                device.name
            );
        }
        println!("{} matching device(s).", snapshot.devices.len());
        if snapshot.at_capacity {
            println!("Result limit reached (128 devices).");
        }
        Ok(())
    };
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
#[cfg(not(windows))]
fn main() {
    eprintln!("This scanner requires Windows.");
    std::process::exit(1);
}
