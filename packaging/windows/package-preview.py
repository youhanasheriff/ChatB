#!/usr/bin/env python3
"""Package and verify a native x64 Windows build; run on the Windows runner."""
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile

source = sys.argv[1]
repo = Path(__file__).resolve().parents[2]
if source != subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip():
    raise SystemExit('Source revision is not HEAD')
subprocess.run(['git', 'diff', '--exit-code', '--', 'Cargo.lock'], check=True)
out = repo / 'dist'
out.mkdir(exist_ok=True)
name = 'BitChat-Desktop-0.1.0-preview.1-windows-x86_64'
archive = out / (name + '.zip')
if archive.exists():
    raise SystemExit('Refusing to overwrite an archive')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
with tempfile.TemporaryDirectory() as temp:
    stage = Path(temp) / name
    stage.mkdir()
    binaries = {}
    for filename, subsystem in [('bitchat-desktop-windows.exe', 2), ('bitchat-scan.exe', 3)]:
        binary = repo / 'target/release' / filename
        data = binary.read_bytes()
        pe = struct.unpack_from('<I', data, 0x3c)[0]
        if data[:2] != b'MZ' or data[pe:pe+4] != b'PE\0\0' or struct.unpack_from('<H',data,pe+4)[0] != 0x8664:
            raise SystemExit('Expected an x86_64 Windows PE executable')
        if struct.unpack_from('<H',data,pe+24+68)[0] != subsystem:
            raise SystemExit('Incorrect GUI/console subsystem')
        shutil.copy2(binary, stage / filename)
        binaries[filename] = {'sha256': sha(binary), 'bytes': len(data)}
    for src, dest in [('LICENSE','LICENSE.txt'),('Cargo.lock','Cargo.lock'),('docs/releases/windows-v0.1.0-preview.1.md','README.md')]:
        shutil.copy2(repo / src, stage / dest)
    metadata = subprocess.check_output(['cargo','metadata','--locked','--format-version','1','--filter-platform','x86_64-pc-windows-msvc'], cwd=repo)
    metadata_path = Path(temp) / 'metadata.json'
    metadata_path.write_bytes(metadata)
    subprocess.run([sys.executable, str(repo/'packaging/linux/collect-notices.py'), str(metadata_path), str(stage/'THIRD-PARTY-NOTICES.txt'), 'bitchat-desktop-windows'], check=True)
    manifest = {'version':'0.1.0-preview.1','platform':'windows','architecture':'x86_64','source_commit':source,'scope':'Bluetooth discovery only; no messaging; physical hardware unqualified','minimum_os':'Windows 10 22H2 (API baseline); Windows 11 recommended; CI on Windows Server 2025','signing':'unsigned','binaries':binaries}
    (stage/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n', encoding='utf-8')
    with zipfile.ZipFile(archive,'x',zipfile.ZIP_DEFLATED,compresslevel=9) as zipped:
        for path in sorted(stage.rglob('*')):
            if path.is_file(): zipped.write(path,path.relative_to(stage.parent))
    unpacked = Path(temp)/'verify'
    with zipfile.ZipFile(archive) as zipped:
        if zipped.testzip(): raise SystemExit('Corrupt archive')
        zipped.extractall(unpacked)
    for binary, info in binaries.items():
        if sha(unpacked/name/binary) != info['sha256']: raise SystemExit('Packaged binary differs')
    subprocess.run([str(unpacked/name/'bitchat-scan.exe'),'--version'],check=True,timeout=10)
    subprocess.run([str(unpacked/name/'bitchat-desktop-windows.exe'),'--smoke-test'],check=True,timeout=15)
    manifest.update(archive=archive.name,sha256=sha(archive),bytes=archive.stat().st_size)
    archive.with_suffix('.zip.sha256').write_text(f"{sha(archive)}  {archive.name}\n",encoding='utf-8')
    archive.with_suffix('.zip.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps(manifest,indent=2))
