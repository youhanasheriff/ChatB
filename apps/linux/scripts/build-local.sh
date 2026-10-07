#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Linux ]]; then
  echo "Build this target on Linux. See apps/linux/README.md for container validation." >&2
  exit 1
fi
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
pkg-config --atleast-version=4.8 gtk4 || { echo "GTK 4.8+ development files are required." >&2; exit 1; }
pkg-config --exists dbus-1 || { echo "libdbus development files are required." >&2; exit 1; }
cargo build -p bitchat-desktop-linux --release --locked
echo "Built ${CARGO_TARGET_DIR:-target}/release/bitchat-desktop"
