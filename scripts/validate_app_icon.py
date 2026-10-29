#!/usr/bin/env python3
"""Validate every required macOS icon slot without imaging dependencies."""
import json
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[1]
folder = root / 'Sources/WebDock/Resources/Assets.xcassets/AppIcon.appiconset'
contents = json.loads((folder / 'Contents.json').read_text())
expected = {(size, scale) for size in [16, 32, 128, 256, 512] for scale in [1, 2]}
seen = set()
for slot in contents['images']:
    assert slot['idiom'] == 'mac'
    size = int(slot['size'].split('x')[0])
    scale = int(slot['scale'].removesuffix('x'))
    key = (size, scale)
    assert key not in seen
    seen.add(key)
    data = (folder / slot['filename']).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    width, height = struct.unpack('>II', data[16:24])
    assert (width, height) == (size * scale, size * scale), f'Incorrect dimensions: {slot}'
    assert data[25] in [4, 6], f'Alpha channel missing: {slot}'
assert seen == expected, 'Required macOS app icon slots are missing'
assert 'ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon' in (root / 'project.yml').read_text()
print('App icon contract OK: all 10 macOS slots (16–1024 px) present with alpha.')
