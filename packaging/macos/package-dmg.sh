#!/bin/bash
# Wrap an already signed release app without changing its contents or signature.
set -euo pipefail
source_app="${1:?Usage: package-dmg.sh RELEASE_APP_PATH OUTPUT_DIR}"
output_dir="${2:?Provide an output directory}"
codesign --verify --deep --strict "$source_app"
version="$(/usr/libexec/PlistBuddy -c 'Print :BitChatDesktopRelease' "$source_app/Contents/Info.plist")"
[[ "$version" =~ ^[0-9A-Za-z.-]+$ ]] || { echo 'Invalid release version.' >&2; exit 1; }
[[ "$(lipo -archs "$source_app/Contents/MacOS/BitChat Desktop")" == arm64 ]] || exit 1
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
artifact="$output_dir/BitChat-Desktop-$version-macos-arm64.dmg"
[[ ! -e "$artifact" ]] || { echo "Refusing to overwrite $artifact" >&2; exit 1; }
work="$(mktemp -d -t bitchat-dmg)"
mounted=0
cleanup() {
  if [[ "$mounted" == 1 ]]; then hdiutil detach "$work/mount" -quiet || return; fi
  rm -rf "$work"
}
trap cleanup EXIT
mkdir "$work/contents" "$work/mount"
ditto "$source_app" "$work/contents/BitChat Desktop.app"
ln -s /Applications "$work/contents/Applications"
cat > "$work/contents/Install BitChat Desktop.txt" <<'EOF'
BitChat Desktop — macOS early preview

1. Drag BitChat Desktop.app onto the Applications folder beside it.
2. Eject this disk image.
3. Open BitChat Desktop from Applications.

Apple silicon Mac required. Minimum declared macOS version: 13.0.
This early preview is ad-hoc signed and not notarized by Apple.
If macOS blocks it, first attempt to open the app. If you trust this
download, use System Settings > Privacy & Security > Open Anyway
for BitChat Desktop and follow the confirmation prompts.

Release notes and checksums:
https://github.com/youhanasheriff/bitchat-desktop/releases
Apple's first-open guidance:
https://support.apple.com/102445
EOF
hdiutil create -quiet -srcfolder "$work/contents" -volname 'BitChat Desktop' \
  -fs HFS+ -format UDZO -imagekey zlib-level=9 "$artifact"
hdiutil verify -quiet "$artifact"
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$work/mount" "$artifact"
mounted=1
[[ "$(readlink "$work/mount/Applications")" == /Applications ]]
codesign --verify --deep --strict "$work/mount/BitChat Desktop.app"
diff -rq "$source_app" "$work/mount/BitChat Desktop.app"
ditto "$work/mount/BitChat Desktop.app" "$work/installed/BitChat Desktop.app"
codesign --verify --deep --strict "$work/installed/BitChat Desktop.app"
hdiutil detach -quiet "$work/mount"
mounted=0
(cd "$output_dir" && shasum -a 256 "$(basename "$artifact")" > "$(basename "$artifact").sha256")
python3 - "$source_app" "$artifact" <<'PY'
import hashlib, json, plistlib, sys
from pathlib import Path
app, image = map(Path, sys.argv[1:])
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
manifest = dict(version=info['BitChatDesktopRelease'], format='dmg',
    sourceCommit=info['BitChatDesktopSourceCommit'], architecture='arm64',
    minimumMacOS=info['LSMinimumSystemVersion'], signing='ad-hoc',
    diskImageSigned=False, notarized=False, downloadBytes=image.stat().st_size,
    bundleBytes=sum(p.stat().st_size for p in app.rglob('*') if p.is_file()),
    sha256=hashlib.sha256(image.read_bytes()).hexdigest())
Path(str(image) + '.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest, indent=2))
PY
echo "Verified disk image ready: $artifact"
