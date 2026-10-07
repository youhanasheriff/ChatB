#!/usr/bin/env python3
"""Collect notices from the locked Arti graph and resolved Swift dependency.

The graph includes build/dev packages as a conservative superset of linked code.
Metadata must be generated with --locked --filter-platform aarch64-apple-darwin.
"""
import json
import hashlib
from pathlib import Path
import sys

repo, metadata_path, output = map(Path, sys.argv[1:])
metadata = json.loads(metadata_path.read_text())
resolved = {node["id"] for node in metadata["resolve"]["nodes"]}
texts = Path(__file__).parent / "license-texts"
parts = ["BitChat Desktop — third-party notices\n\n"
         "Original BitChat Desktop contributions use MIT unless otherwise stated.\n"
         "Inherited Bitchat code retains its Unlicense dedication.\n"
         "Dependencies retain their respective licenses. This inventory is a\n"
         "conservative superset of the macOS Arti dependency graph, including\n"
         "build/dev dependencies. Their presence here does not imply every\n"
         "package is linked into the executable.\n\n"
         "Where alternatives permit it, Apache-2.0 is selected for packages\n"
         "without shipped license files. priority-queue is used under MPL-2.0.\n"
         "MPL-covered source is available at the exact source archive URLs\n"
         "listed below, without charge; the dependencies are unmodified.\n"]
parts.append((repo / "LICENSE").read_text())
parts.append("\nInherited Bitchat source — Unlicense\n\n" +
             (repo / "LICENSES/Bitchat-Unlicense.txt").read_text())
seen_texts = set()


def append_notice(content):
    """Keep repeated standard grants once, retaining every package attribution."""
    identifier = hashlib.sha256(content.encode()).hexdigest()
    if identifier in seen_texts:
        parts.append(f"License text: see SHA-256 {identifier} above.\n")
    else:
        seen_texts.add(identifier)
        parts.append(f"License text SHA-256 {identifier}:\n" + content)


for package in sorted(metadata["packages"], key=lambda p: (p["name"], p["version"])):
    if package["id"] not in resolved or not package.get("source"):
        continue
    name, version = package["name"], package["version"]
    folder = Path(package["manifest_path"]).parent
    license_expression = package.get("license") or "See files below"
    parts.append(f"\n{'=' * 72}\n{name} {version}\nLicense: {license_expression}\n"
                 f"Repository: {package.get('repository') or 'Not declared'}\n"
                 f"Authors: {', '.join(package.get('authors', []))}\n"
                 f"Source: https://static.crates.io/crates/{name}/{name}-{version}.crate\n")
    notices = sorted(f for f in folder.rglob("*") if f.is_file() and
                     any(word in f.name.upper() for word in
                         ("LICENSE", "LICENCE", "COPYING", "NOTICE", "COPYRIGHT")))
    if package.get("license_file"):
        declared = folder / package["license_file"]
        if declared.is_file() and declared not in notices:
            notices.append(declared)
    if notices:
        for notice in notices:
            parts.append(f"\n--- {notice.relative_to(folder)} ---\n")
            append_notice(notice.read_text(errors="replace"))
    elif name == "cookie-factory":
        append_notice((texts / "cookie-factory-0.3.3-MIT.txt").read_text())
    elif "Apache-2.0" in license_expression:
        append_notice((texts / "Apache-2.0.txt").read_text())
    elif "MPL-2.0" in license_expression:
        append_notice((texts / "MPL-2.0.txt").read_text())
    elif license_expression == "MIT":
        # Keep copyright lines from the shipped sources and declared author
        # attribution above when the crate omitted its standalone license file.
        copyrights = set()
        for source in folder.rglob("*.rs"):
            for line in source.read_text(errors="replace").splitlines():
                if "copyright" in line.lower():
                    copyrights.add(line.strip().lstrip("/ *"))
        parts.extend(sorted(copyrights))
        append_notice((texts / "MIT.txt").read_text())
    else:
        raise SystemExit(f"Missing license text; review {name} {version}")

swift = repo / "apps/macos/.DerivedData/SourcePackages/checkouts/swift-secp256k1"
if not swift.is_dir():
    raise SystemExit("Resolve the pinned Swift packages before packaging")
parts.append("\n" + "=" * 72 + "\nswift-secp256k1 0.21.1 and bundled submodules\n"
             "https://github.com/21-DOT-DEV/swift-secp256k1/tree/8c62aba8a3011c9bcea232e5ee007fb0b34a15e2\n"
             "The compiler compatibility patch is documented in build-local.sh.\n")
for notice in sorted(f for f in swift.rglob("*") if f.is_file() and
                     any(word in f.name.upper() for word in ("LICENSE", "COPYING", "NOTICE"))):
    parts.append(f"\n--- {notice.relative_to(swift)} ---\n")
    append_notice(notice.read_text(errors="replace"))
output.write_text("\n".join(parts))
print(f"Collected {len(resolved)} Rust package records and Swift/submodule notices.")
