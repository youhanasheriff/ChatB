#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
cargo test -p bitchat-desktop-linux --locked
cargo build -p bitchat-desktop-linux --locked
binary="${CARGO_TARGET_DIR:-target}/debug/bitchat-desktop"
"$binary" --help
timeout 20s dbus-run-session -- xvfb-run -a env GSK_RENDERER=cairo GTK_A11Y=none "$binary" --smoke-test

# A missing system bus must be an actionable error, never a successful empty scan.
set +e
output=$(DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent-bitchat-bus timeout 10s "$binary" --scan --seconds 2 2>&1)
status=$?
set -e
if [[ "$status" != 1 || "$output" != *"Cannot communicate with BlueZ"* ]]; then
  echo "Missing-bus check failed ($status): $output" >&2
  exit 1
fi
BITCHAT_LINUX_BINARY="$binary" /usr/bin/python3 apps/linux/tests/test_bluez.py
echo "Linux UI and simulated BlueZ checks passed. Hardware interoperability is not tested here."
