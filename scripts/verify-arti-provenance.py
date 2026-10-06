#!/usr/bin/env python3
"""Check vendored Arti artifacts against the preserved provenance manifest."""
import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
doc = (ROOT / "docs/ARTI-BINARY-PROVENANCE.md").read_text()
entries = re.findall(r"^([0-9a-f]{64})  (apps/macos/localPackages/Arti/Frameworks/arti\.xcframework/[^\n]+)$", doc, re.MULTILINE)
if not entries:
    raise SystemExit("Arti provenance manifest is missing.")
for expected, relative in entries:
    actual = hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"Arti artifact hash mismatch: {relative}")
base = ROOT / "apps/macos/localPackages/Arti/Frameworks/arti.xcframework"
actual_paths = {str(path.relative_to(ROOT)) for path in base.rglob("*") if path.is_file()}
if actual_paths != {relative for _, relative in entries}:
    raise SystemExit("Arti artifact file set differs from the provenance manifest.")
print(f"Verified {len(entries)} Arti artifact hashes.")
