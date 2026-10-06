#!/bin/bash
# Capture real native UI with fictitious conversations through the test host.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
output_dir="${1:?Usage: capture-marketing.sh /absolute/path/to/screenshots}"
capture_dir=/tmp/bitchat-marketing-captures
mkdir -p "$capture_dir" "$output_dir"
touch "$capture_dir/.enabled"
trap 'rm -f "$capture_dir/.enabled"' EXIT
cd "$repo_root"
xcodebuild -project apps/macos/BitChatDesktop.xcodeproj \
  -scheme 'BitChat Desktop (macOS)' -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath apps/macos/.DerivedData \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES \
  -parallel-testing-enabled NO \
  -only-testing:bitchatTests_macOS/ViewSmokeTests/desktopMarketingScreenshots\(\) test
for screenshot in light-bubbles terminal graphite settings; do
  cp "$capture_dir/$screenshot.png" "$output_dir/$screenshot.png"
done
