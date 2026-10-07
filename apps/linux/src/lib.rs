//! Linux discovery state and arguments, kept independent of GTK and BlueZ so
//! input validation and resource limits can be tested on every workspace host.
#![forbid(unsafe_code)]

pub mod options;
pub mod state;

#[cfg(target_os = "linux")]
pub mod bluetooth;
