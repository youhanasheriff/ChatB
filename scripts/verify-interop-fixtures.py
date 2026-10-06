#!/usr/bin/env python3
"""Verify imported interop fixtures against the pinned source manifest."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT / "tests/interop"
manifest = json.loads((BASE / "manifest.json").read_text())
for item in manifest["fixtures"]:
    copied = BASE / item["path"]
    source = ROOT / item["source"]
    for path in (copied, source):
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != item["sha256"]:
            raise SystemExit(f"Fixture hash mismatch: {path.relative_to(ROOT)}")
print(f"Verified {len(manifest['fixtures'])} fixtures against the pinned upstream manifest.")
