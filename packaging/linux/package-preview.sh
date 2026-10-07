#!/usr/bin/env bash
# Package a native Linux Release executable and its locked dependency notices.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_binary="${1:?Usage: package-preview.sh BINARY OUTPUT_DIR SOURCE_COMMIT}"
output="${2:?Provide an output directory}"
source_commit="${3:?Provide the source commit used for the binary}"
version=0.1.0-preview.1
[[ "$(uname -s)" == Linux ]] || { echo 'Package this target on Linux.' >&2; exit 1; }
case "$(uname -m)" in
  x86_64) architecture=x86_64; target=x86_64-unknown-linux-gnu ;;
  aarch64) architecture=aarch64; target=aarch64-unknown-linux-gnu ;;
  *) echo 'Unsupported Linux architecture.' >&2; exit 1 ;;
esac
[[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] || { echo 'Provide a full source commit hash.' >&2; exit 1; }
git -C "$repo" cat-file -e "$source_commit^{commit}"
git -C "$repo" show "$source_commit:Cargo.lock" | cmp - "$repo/Cargo.lock"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
name="BitChat-Desktop-$version-linux-$architecture"
archive="$output/$name.tar.gz"
[[ ! -e "$archive" ]] || { echo "Refusing to overwrite $archive" >&2; exit 1; }
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/$name"
install -m 755 "$source_binary" "$stage/$name/bitchat-desktop"
cargo metadata --manifest-path "$repo/Cargo.toml" --locked --format-version 1 \
  --filter-platform "$target" > "$stage/metadata.json"
python3 "$repo/packaging/linux/collect-notices.py" "$stage/metadata.json" "$stage/$name/THIRD-PARTY-NOTICES.txt"
cp "$repo/LICENSE" "$stage/$name/LICENSE.txt"
cp "$repo/docs/releases/linux-v0.1.0-preview.1.md" "$stage/$name/README.md"
cp "$repo/Cargo.lock" "$stage/$name/Cargo.lock"
ldd "$stage/$name/bitchat-desktop" > "$stage/$name/system-libraries.txt"
if grep -q 'not found' "$stage/$name/system-libraries.txt"; then
  echo 'Unresolved runtime libraries; refusing to package.' >&2
  exit 1
fi
python3 - "$stage/$name" "$architecture" "$source_commit" "$version" <<'PY'
import hashlib, json, struct, sys
from pathlib import Path
folder, arch, commit, version = Path(sys.argv[1]), *sys.argv[2:]
binary = folder / 'bitchat-desktop'
header = binary.read_bytes()[:20]
assert header[:6] == b'\x7fELF\x02\x01', 'Expected a little-endian 64-bit ELF binary'
assert struct.unpack('<H', header[18:20])[0] == {'x86_64': 62, 'aarch64': 183}[arch], 'Wrong architecture'
manifest = dict(version=version, releaseTag='linux-v' + version, sourceCommit=commit,
                architecture=arch, scope='Bluetooth discovery only; messaging unavailable',
                buildBaseline='Debian 12; Rust 1.85; GTK 4.8; glibc 2.36',
                binaryBytes=binary.stat().st_size,
                binarySha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                runtimeLibrariesBundled=False)
(folder / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
PY
COPYFILE_DISABLE=1 tar -czf "$archive" -C "$stage" "$name"
(cd "$output" && sha256sum "$name.tar.gz" > "$name.tar.gz.sha256")
python3 - "$archive" "$stage/$name/manifest.json" <<'PY'
import hashlib, json, sys
from pathlib import Path
archive, manifest_path = map(Path, sys.argv[1:])
manifest = json.loads(manifest_path.read_text())
manifest.update(downloadBytes=archive.stat().st_size, sha256=hashlib.sha256(archive.read_bytes()).hexdigest())
Path(str(archive) + '.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest, indent=2))
PY
# Exercise the bytes actually distributed, after extraction.
mkdir "$stage/verify"
tar -xzf "$archive" -C "$stage/verify"
packaged="$stage/verify/$name/bitchat-desktop"
cmp "$source_binary" "$packaged"
"$packaged" --version
timeout 20s dbus-run-session -- xvfb-run -a env GSK_RENDERER=cairo GTK_A11Y=none "$packaged" --smoke-test
echo "Verified Linux preview: $archive"
