#![forbid(unsafe_code)]

use bitchat_desktop_linux::options::{Mode, Options, HELP};
use std::process::ExitCode;

#[cfg(target_os = "linux")]
mod ui;

fn main() -> ExitCode {
    let options = match Options::parse(std::env::args().skip(1)) {
        Ok(options) => options,
        Err(error) => {
            eprintln!("{error}");
            return ExitCode::from(2);
        }
    };
    match options.mode {
        Mode::Help => {
            println!("{HELP}");
            ExitCode::SUCCESS
        }
        Mode::Version => {
            println!(
                "BitChat Desktop {} (Linux discovery preview)",
                env!("CARGO_PKG_VERSION")
            );
            ExitCode::SUCCESS
        }
        _ => run(options),
    }
}

#[cfg(not(target_os = "linux"))]
fn run(_: Options) -> ExitCode {
    eprintln!("The Linux app requires Linux with GTK4 and BlueZ. See apps/linux/README.md.");
    ExitCode::FAILURE
}

#[cfg(target_os = "linux")]
fn run(options: Options) -> ExitCode {
    let runtime = match tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(_) => {
            eprintln!("Could not start the Bluetooth worker.");
            return ExitCode::FAILURE;
        }
    };
    let result = if options.mode == Mode::Scan {
        runtime.block_on(scan(options))
    } else {
        ui::run(options, runtime.handle().clone())
    };
    // Let BlueZ process discovery-stream drops before stopping its runtime.
    runtime.block_on(async {
        tokio::time::sleep(std::time::Duration::from_millis(200)).await;
    });
    runtime.shutdown_timeout(std::time::Duration::from_secs(2));
    result
}

#[cfg(target_os = "linux")]
async fn scan(options: Options) -> ExitCode {
    use bitchat_desktop_linux::{bluetooth::Scan, state::ScanStatus};
    println!(
        "{} discovery ({} seconds). Device addresses are not verified peer identities.",
        options.network.label(),
        options.seconds
    );
    let mut scan = Scan::start(&tokio::runtime::Handle::current(), options);
    let interrupted = tokio::signal::ctrl_c();
    tokio::pin!(interrupted);
    let mut stopping = false;
    loop {
        tokio::select! {
            result = &mut interrupted, if !stopping => {
                if result.is_err() { eprintln!("Could not install the interrupt handler; stopping discovery."); }
                stopping = true;
                scan.stop();
            }
            result = scan.updates.changed() => {
                if result.is_err() { eprintln!("Bluetooth worker stopped unexpectedly."); return ExitCode::FAILURE; }
                let state = scan.updates.borrow_and_update().clone();
                match state.status {
                    ScanStatus::Failed(error) => { eprintln!("{error}"); return ExitCode::FAILURE; }
                    ScanStatus::Finished => {
                        println!("{} matching device(s) reported by BlueZ (may include cached results).", state.devices.len());
                        for device in state.devices.values() {
                            let signal = device.rssi.map(|r| format!("{r} dBm")).unwrap_or_else(|| "signal unavailable".into());
                            println!("{}  {}  {}", device.address, signal, device.name);
                        }
                        if state.at_capacity { println!("Showing the first 128 matching devices."); }
                        return ExitCode::SUCCESS;
                    }
                    _ => (),
                }
            }
        }
    }
}
