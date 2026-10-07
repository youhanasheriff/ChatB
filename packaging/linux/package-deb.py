#!/usr/bin/env python3
"""Create an installable Debian package from the verified native archive."""
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

archive = Path(sys.argv[1]).resolve()
repo = Path(__file__).resolve().parents[2]
metadata = json.loads(Path(str(archive)+'.json').read_text())
if hashlib.sha256(archive.read_bytes()).hexdigest() != metadata['sha256']:
    raise SystemExit('Archive checksum mismatch')
architecture = {'x86_64': 'amd64', 'aarch64': 'arm64'}[metadata['architecture']]
if subprocess.check_output(['dpkg', '--print-architecture'], text=True).strip() != architecture:
    raise SystemExit('Build the Debian package on its native architecture')
version = metadata['version'].replace('-preview.', '~preview.') + '-1'
# GitHub release assets normalize '~'; keep it only in Debian's version field.
filename_version = metadata['version'] + '-1'
output = archive.parent / f'bitchat-desktop_{filename_version}_{architecture}.deb'
if output.exists(): raise SystemExit('Refusing to overwrite a package')
with tempfile.TemporaryDirectory() as temporary:
    temp = Path(temporary)
    with tarfile.open(archive) as tar:
        # Debian 12's Python predates extraction filters. Our archives contain
        # only regular files/directories: reject traversal and all link entries.
        for member in tar.getmembers():
            path = PurePosixPath(member.name)
            if path.is_absolute() or '..' in path.parts or not (member.isfile() or member.isdir()):
                raise SystemExit('Unsafe archive member: '+member.name)
        tar.extractall(temp/'payload')
    payload, = (temp/'payload').iterdir()
    root = temp/'debian/bitchat-desktop'
    docs = root/'usr/share/doc/bitchat-desktop'
    docs.mkdir(parents=True)
    (root/'usr/bin').mkdir(parents=True)
    binary = root/'usr/bin/bitchat-desktop'
    shutil.copy2(payload/'bitchat-desktop', binary)
    binary.chmod(0o755)
    if hashlib.sha256(binary.read_bytes()).hexdigest() != metadata['binarySha256']:
        raise SystemExit('Payload binary checksum mismatch')
    for filename in ['README.md', 'LICENSE.txt', 'THIRD-PARTY-NOTICES.txt', 'Cargo.lock', 'manifest.json', 'system-libraries.txt']:
        shutil.copy2(payload/filename, docs/filename)
    # Debian's standard copyright location contains the complete project license.
    shutil.copy2(payload/'LICENSE.txt', docs/'copyright')
    for source, destination in [
        ('com.bitchat.desktop.linux.desktop', 'usr/share/applications/com.bitchat.desktop.linux.desktop'),
        ('com.bitchat.desktop.linux.svg', 'usr/share/icons/hicolor/scalable/apps/com.bitchat.desktop.linux.svg'),
    ]:
        target = root/destination
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repo/'packaging/linux'/source, target)
    subprocess.run(['desktop-file-validate', str(root/'usr/share/applications/com.bitchat.desktop.linux.desktop')],check=True)
    # Let dpkg derive versioned direct ELF dependencies from the build baseline.
    (temp/'debian').mkdir(exist_ok=True)
    (temp/'debian/control').write_text('Source: bitchat-desktop\n\nPackage: bitchat-desktop\nArchitecture: any\nDescription: Bluetooth discovery preview\n')
    dependencies = subprocess.check_output(['dpkg-shlibdeps', '-O', '-e'+str(binary)],cwd=temp,text=True).strip().removeprefix('shlibs:Depends=')
    if not dependencies or '\n' in dependencies or 'libgtk-4-1' not in dependencies:
        raise SystemExit('Unexpected shared-library dependency result: '+dependencies)
    # Retain stronger detected versions; enforce the declared runtime floor.
    for library, floor in [('libgtk-4-1', '4.8'), ('libc6', '2.36')]:
        match = re.search(r'\b'+re.escape(library)+r' \(>= ([^)]+)\)', dependencies)
        if not match:
            raise SystemExit('Missing versioned dependency: '+library)
        if subprocess.run(['dpkg','--compare-versions',match.group(1),'lt',floor]).returncode == 0:
            dependencies = dependencies.replace(match.group(0),f'{library} (>= {floor})')
    dependencies += ', bluez'
    installed_size = math.ceil(sum(p.stat().st_size for p in root.rglob('*') if p.is_file())/1024)
    control = root/'DEBIAN'
    control.mkdir()
    (control/'control').write_text(f'''Package: bitchat-desktop
Version: {version}
Architecture: {architecture}
Section: net
Priority: optional
Maintainer: Youhana Sheriff <youhanasheriff@gmail.com>
Homepage: https://github.com/youhanasheriff/bitchat-desktop
Installed-Size: {installed_size}
Depends: {dependencies}
Description: Native Bluetooth discovery preview for Bitchat
 GTK4 desktop interface and terminal scanner for nearby service advertisements.
 Discovery only: messaging and verified identities are not implemented.
''')
    files = sorted(p for p in root.rglob('*') if p.is_file() and control not in p.parents)
    (control/'md5sums').write_text(''.join(f'{hashlib.md5(p.read_bytes()).hexdigest()}  {p.relative_to(root)}\n' for p in files))
    for path in root.rglob('*'):
        path.chmod(0o755 if path.is_dir() or path == binary else 0o644)
    subprocess.run(['dpkg-deb','--root-owner-group','--build',str(root),str(output)],check=True)
    subprocess.run(['dpkg-deb','--extract',str(output),str(temp/'verify')],check=True)
    assert hashlib.sha256((temp/'verify/usr/bin/bitchat-desktop').read_bytes()).hexdigest() == metadata['binarySha256']
    manifest = dict(metadata, packageType='deb', packageVersion=version, packageArchitecture=architecture,
                    package=output.name, dependencies=dependencies, downloadBytes=output.stat().st_size,
                    sha256=hashlib.sha256(output.read_bytes()).hexdigest())
    Path(str(output)+'.json').write_text(json.dumps(manifest,indent=2)+'\n')
    Path(str(output)+'.sha256').write_text(f"{manifest['sha256']}  {output.name}\n")
print(json.dumps(manifest,indent=2))
