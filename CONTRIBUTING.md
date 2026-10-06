# Contributing to BitChat Desktop

BitChat Desktop is early-stage desktop work following Bitchat. Check the platform status in the README before assuming a client or shared-core feature exists.

Keep protocol changes backed by independent fixtures and real-client interoperability. Avoid mixing wire-format changes into branding or source moves. Preserve upstream and dependency notices.

For Rust changes, run the workspace checks in the README. For Apple changes, build the BitChat Desktop macOS scheme and run the relevant Swift tests. New platform code needs verification on its target operating system, including actual Bluetooth hardware for transport changes.

Describe behavior, validation, and remaining limitations in pull requests. Application size includes required dependencies, not just the main executable.
