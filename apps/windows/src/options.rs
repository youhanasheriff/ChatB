use crate::state::Network;

pub const HELP: &str = "BitChat Desktop — Windows discovery preview

Usage: bitchat-desktop-windows [--testnet]
       bitchat-scan --scan [--seconds 1..300] [--testnet]
       bitchat-desktop-windows --smoke-test

  --scan         Discover matching Bluetooth devices without opening a window
  --seconds N    Scan duration (default: 30 seconds; requires --scan)
  --testnet      Use the upstream isolated debug service instead of mainnet
  --smoke-test   Open the UI briefly without using Bluetooth, then exit
  --help         Show this help
  --version      Show the version

Discovery only. No advertising, connections, messaging, or verified identities.";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Options {
    pub network: Network,
    pub mode: Mode,
    pub seconds: u64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mode {
    Gui,
    Scan,
    SmokeTest,
    Help,
    Version,
}

impl Options {
    pub fn parse(args: impl IntoIterator<Item = String>) -> Result<Self, String> {
        let mut options = Self {
            network: Network::Mainnet,
            mode: Mode::Gui,
            seconds: 30,
        };
        let mut args = args.into_iter();
        let mut duration_set = false;
        let mut mode_set = false;
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--help" | "-h" => {
                    return Ok(Self {
                        mode: Mode::Help,
                        ..options
                    })
                }
                "--version" | "-V" => {
                    return Ok(Self {
                        mode: Mode::Version,
                        ..options
                    })
                }
                "--scan" | "--smoke-test" => {
                    if mode_set {
                        return Err("Choose only one of --scan and --smoke-test.".into());
                    }
                    mode_set = true;
                    options.mode = if arg == "--scan" {
                        Mode::Scan
                    } else {
                        Mode::SmokeTest
                    };
                }
                "--testnet" => options.network = Network::Testnet,
                "--seconds" => {
                    options.seconds = args
                        .next()
                        .and_then(|s| s.parse().ok())
                        .filter(|n| (1..=300).contains(n))
                        .ok_or("--seconds requires a whole number from 1 to 300.")?;
                    duration_set = true;
                }
                _ => return Err(format!("Unknown argument: {arg}. Use --help for usage.")),
            }
        }
        if duration_set && options.mode != Mode::Scan {
            return Err("--seconds requires --scan.".into());
        }
        Ok(options)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(args: &[&str]) -> Result<Options, String> {
        Options::parse(args.iter().map(|s| s.to_string()))
    }

    #[test]
    fn production_network_is_default_even_in_debug_builds() {
        let options = parse(&[]).unwrap();
        assert_eq!(options.network, Network::Mainnet);
        assert_eq!(options.mode, Mode::Gui);
        assert_eq!(options.seconds, 30);
    }

    #[test]
    fn accepts_headless_scan_with_explicit_testnet() {
        let options = parse(&["--testnet", "--scan", "--seconds", "5"]).unwrap();
        assert_eq!(options.network, Network::Testnet);
        assert_eq!(options.mode, Mode::Scan);
        assert_eq!(options.seconds, 5);
    }

    #[test]
    fn rejects_invalid_or_ambiguous_options() {
        for args in [
            vec!["--seconds", "3"],
            vec!["--scan", "--seconds", "0"],
            vec!["--scan", "--seconds", "301"],
            vec!["--scan", "--seconds", "-1"],
            vec!["--scan", "--seconds"],
            vec!["--adapter"],
            vec!["--adapter", "hci"],
            vec!["--adapter", "../hci0"],
            vec!["--scan", "--smoke-test"],
            vec!["--unknown"],
        ] {
            assert!(parse(&args).is_err(), "accepted {args:?}");
        }
    }
}
