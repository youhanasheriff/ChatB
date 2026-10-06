#!/bin/bash
# Build and ad-hoc sign a native app for testing on this Mac.
set -euo pipefail
cd "$(dirname "$0")/.."

project="BitChatDesktop.xcodeproj"
scheme="BitChat Desktop (macOS)"
architecture="$(uname -m)"
configuration="${CONFIGURATION:-Release}"
derived_data=".DerivedData"

xcodebuild -resolvePackageDependencies -project "$project" -scheme "$scheme" \
  -derivedDataPath "$derived_data" -skipPackageUpdates

# Swift 6.4 finds two candidates for `words` in the pinned dependency.
# Spell out the exact expression used by its existing accessor. Keep the
# upstream version and all cryptographic operations unchanged; only patch
# the ignored package checkout, verifying its full source before writing.
python3 - "$derived_data" <<'PY'
import hashlib
from pathlib import Path
import stat
import sys

source = (Path(sys.argv[1]) / "SourcePackages/checkouts/swift-secp256k1/Sources/P256K/UInt256.swift").resolve()
original = b"        for word in words {"
replacement = b"        for word in SIMDWrapper<Vector>(wrappedValue: vector) {"
data = source.read_bytes()
if replacement in data:
    pristine = data.replace(replacement, original, 1)
else:
    pristine = data
expected = "8edf31e9c2adf649e93174db8044a2cdb04b8f5fc19b683464f17aab620191f0"
if hashlib.sha256(pristine).hexdigest() != expected:
    raise SystemExit("Dependency source changed; review the Swift compatibility patch before building.")
patched = pristine.replace(original, replacement, 1)
if data != patched:
    source.chmod(source.stat().st_mode | stat.S_IWUSR)
    source.write_bytes(patched)
print("Verified swift-secp256k1 0.21.1 compiler compatibility patch.")
PY

xcodebuild -project "$project" -scheme "$scheme" -configuration "$configuration" \
  -destination "platform=macOS,arch=$architecture" -derivedDataPath "$derived_data" \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  ARCHS="$architecture" ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build

app="$derived_data/Build/Products/$configuration/BitChat Desktop.app"
# Xcode test actions can leave an injected (or partially built) test bundle
# in the app. It is a build artifact, not part of the standalone local app.
if [[ -d "$app/Contents/PlugIns" ]]; then
  find "$app/Contents/PlugIns" -maxdepth 1 -name '*.xctest' -exec rm -rf -- {} +
fi
# Ad-hoc local testing cannot provision an Apple App Group. Retain the
# sandbox and device/network permissions, omitting only that entitlement.
entitlements="$(mktemp -t bitchat-desktop-entitlements)"
trap 'rm -f "$entitlements"' EXIT
python3 - "$entitlements" <<'PY'
import plistlib
import sys
from pathlib import Path
data = plistlib.loads(Path("bitchat/bitchat-macOS.entitlements").read_bytes())
data.pop("com.apple.security.application-groups", None)
Path(sys.argv[1]).write_bytes(plistlib.dumps(data))
PY
codesign --force --deep --sign - --entitlements "$entitlements" "$app"
codesign --verify --deep --strict "$app"
echo "Local app ready: $PWD/$app"
if [[ "${1:-}" == "--open" ]]; then
  open "$app"
fi
