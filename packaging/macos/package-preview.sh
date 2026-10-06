#!/bin/bash
# Package an existing native Release build; never signs with a machine identity.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
source_app="${1:?Usage: package-preview.sh APP_PATH OUTPUT_DIR SOURCE_COMMIT [ARTI_METADATA_JSON]}"
output_dir="${2:?Provide an output directory}"
source_commit="${3:?Provide the commit used to build the executable}"
version="0.1.0-preview.1"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
stage="$(mktemp -d -t bitchat-preview)"
trap 'rm -rf "$stage"' EXIT
app="$stage/BitChat Desktop.app"
ditto "$source_app" "$app"
codesign --verify --deep --strict "$app"
if find "$app" -name '*.xctest' -print -quit | /usr/bin/grep -q .; then
  echo 'Refusing to package an app containing a test bundle.' >&2; exit 1
fi
binary="$app/Contents/MacOS/BitChat Desktop"
[[ "$(lipo -archs "$binary")" == "arm64" ]] || { echo 'Expected arm64 preview.' >&2; exit 1; }
if otool -L "$binary" | tail -n +2 | awk '{print $1}' | /usr/bin/grep -Ev '^(/usr/lib/|/System/Library/)' ; then
  echo 'Unexpected non-system dynamic dependency; review before packaging.' >&2; exit 1
fi
metadata="${4:-$stage/arti-metadata.json}"
if [[ $# -lt 4 ]]; then
  cargo metadata --manifest-path "$repo/apps/macos/localPackages/Arti/Cargo.toml" \
    --locked --format-version 1 --filter-platform aarch64-apple-darwin > "$metadata"
fi
python3 "$repo/packaging/macos/collect-notices.py" "$repo" "$metadata" \
  "$app/Contents/Resources/THIRD-PARTY-NOTICES.txt"
if [[ $# -lt 4 ]]; then rm "$metadata"; fi
cp "$repo/LICENSE" "$app/Contents/Resources/LICENSE.txt"
cp "$repo/docs/releases/v0.1.0-preview.1.md" "$stage/README.md"
codesign -d --entitlements :- "$app" > "$stage/entitlements.plist" 2>/dev/null
python3 - "$app" "$source_commit" <<'PY'
import plistlib, sys
from pathlib import Path
app, commit = Path(sys.argv[1]), sys.argv[2]
path = app / 'Contents/Info.plist'
info = plistlib.loads(path.read_bytes())
info['CFBundleShortVersionString'] = '0.1.0'
info['CFBundleVersion'] = '1'
info['BitChatDesktopRelease'] = '0.1.0-preview.1'
info['BitChatDesktopSourceCommit'] = commit
path.write_bytes(plistlib.dumps(info))
PY
codesign --force --deep --sign - --entitlements "$stage/entitlements.plist" "$app"
codesign --verify --deep --strict "$app"
rm "$stage/entitlements.plist"
artifact="BitChat-Desktop-$version-macos-arm64.zip"
COPYFILE_DISABLE=1 ditto -c -k --norsrc "$stage" "$output_dir/$artifact"
(cd "$output_dir" && shasum -a 256 "$artifact" > "$artifact.sha256")
python3 - "$app" "$output_dir/$artifact" "$source_commit" <<'PY'
import hashlib, json, plistlib, sys
from pathlib import Path
app, archive, commit = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
result = dict(version='0.1.0-preview.1', sourceCommit=commit, architecture='arm64',
              minimumMacOS=info['LSMinimumSystemVersion'], signing='ad-hoc', notarized=False,
              downloadBytes=archive.stat().st_size,
              bundleBytes=sum(p.stat().st_size for p in app.rglob('*') if p.is_file()),
              sha256=hashlib.sha256(archive.read_bytes()).hexdigest())
archive.with_suffix('.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
PY
echo "Archive ready: $output_dir/$artifact"
