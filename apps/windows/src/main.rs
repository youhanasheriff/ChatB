#![cfg_attr(windows, windows_subsystem = "windows")]
#[cfg(windows)]
fn main() {
    use bitchat_desktop_windows::{
        options::{Mode, Options},
        ui,
    };
    let result = Options::parse(std::env::args().skip(1)).and_then(|options| match options.mode {
        Mode::Gui | Mode::SmokeTest => ui::run(options).map_err(|e| e.to_string()),
        _ => Err("Use bitchat-scan.exe for --scan, --help and --version.".into()),
    });
    if let Err(error) = result {
        ui::show_error(&error);
        std::process::exit(1);
    }
}
#[cfg(not(windows))]
fn main() {
    eprintln!("This application requires Windows. See apps/windows/README.md.");
    std::process::exit(1);
}
