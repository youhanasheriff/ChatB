#!/usr/bin/env python3
"""Collect license files from the selected Rust dependency graph."""
import hashlib
import json
from pathlib import Path
import sys

metadata_path, output = map(Path, sys.argv[1:3])
package_name = sys.argv[3] if len(sys.argv) > 3 else "bitchat-desktop-linux"
platform_name = "Windows" if package_name == "bitchat-desktop-windows" else "Linux"
metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
packages = {p['id']: p for p in metadata['packages']}
nodes = {n['id']: n for n in metadata['resolve']['nodes']}
root = next(p['id'] for p in packages.values() if p['name'] == package_name)
resolved = set()
pending = [root]
while pending:
    identifier = pending.pop()
    if identifier not in resolved:
        resolved.add(identifier)
        pending.extend(nodes[identifier]['dependencies'])

system_notice = (
    'Windows system libraries are supplied by the operating system.\n'
    if platform_name == 'Windows' else
    'GTK, GLib, libdbus and other system shared libraries are not bundled;\n'
    'install them through your distribution, which supplies their notices.\n'
)
parts = [f'BitChat Desktop for {platform_name} — third-party notices\n\n'
         'Original project code uses MIT. The following inventory includes the\n'
         f'locked {platform_name} dependency graph, conservatively including build dependencies.\n'
         'Dependencies are unmodified. Exact source archives are linked below.\n'
         + system_notice]
seen = set()
count = 0
fallback = Path(__file__).resolve().parents[1] / 'macos/license-texts'
for identifier in sorted(resolved, key=lambda i: (packages[i]['name'], packages[i]['version'])):
    package = packages[identifier]
    if not package.get('source'):
        continue
    count += 1
    name, version = package['name'], package['version']
    folder = Path(package['manifest_path']).parent
    license_expression = package.get('license', '')
    parts.append(f"\n{'=' * 72}\n{name} {version}\nLicense: {license_expression}\n"
                 f"Authors: {', '.join(package.get('authors', []))}\n"
                 f"Repository: {package.get('repository') or 'Not declared'}\n"
                 f"Source: https://static.crates.io/crates/{name}/{name}-{version}.crate\n")
    notices = sorted(p for p in folder.rglob('*') if p.is_file() and any(
        marker in p.name.upper() for marker in ('LICENSE', 'LICENCE', 'COPYING', 'NOTICE', 'COPYRIGHT')))
    if package.get('license_file'):
        declared = folder / package['license_file']
        if declared.is_file() and declared not in notices:
            notices.append(declared)
    if not notices:
        if 'Apache-2.0' in license_expression:
            parts.append('Selecting the Apache-2.0 alternative.\n')
            notices = [fallback / 'Apache-2.0.txt']
        elif license_expression == 'MIT':
            copyrights = set()
            for source in folder.rglob('*.rs'):
                for line in source.read_text(encoding='utf-8', errors='replace').splitlines():
                    if 'copyright' in line.lower():
                        copyrights.add(line.strip().lstrip('/ *'))
            parts.extend(sorted(copyrights))
            notices = [fallback / 'MIT.txt']
        else:
            raise SystemExit(f'Missing license text: {name} {version}; review before release')
    for notice in notices:
        content = notice.read_text(encoding='utf-8', errors='replace')
        digest = hashlib.sha256(content.encode()).hexdigest()
        parts.append(f'\n--- {notice.name} (SHA-256 {digest}) ---\n')
        if digest in seen:
            parts.append('Identical license text is reproduced above.\n')
        else:
            parts.append(content)
            seen.add(digest)
output.write_text('\n'.join(parts), encoding='utf-8')
print(f'Collected notices for {count} Rust dependencies.')
