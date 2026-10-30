#!/usr/bin/env python3
"""Check the standalone ICNS and the modern/legacy icons in an optional built app."""
import argparse
import json
from pathlib import Path
import plistlib
import struct
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app', type=Path, help='Also verify the built WebDock.app')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
icon = root / 'Design/AppIcon/WebDock.icns'
data = icon.read_bytes()
assert data[:4] == b'icns'
assert struct.unpack('>I', data[4:8])[0] == len(data), 'Invalid ICNS length'
expected = {
    f'icon_{size}x{size}{"@2x" if scale == 2 else ""}.png': size * scale
    for size in [16, 32, 128, 256, 512] for scale in [1, 2]
}
with tempfile.TemporaryDirectory() as temporary:
    folder = Path(temporary) / 'WebDock.iconset'
    subprocess.run(['iconutil', '-c', 'iconset', str(icon), '-o', str(folder)], check=True)
    assert {p.name for p in folder.glob('*.png')} == set(expected), 'Missing ICNS representations'
    for filename, pixels in expected.items():
        png = (folder / filename).read_bytes()
        assert png[:8] == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack('>II', png[16:24]) == (pixels, pixels), filename
        assert png[25] in [4, 6], f'Alpha channel missing: {filename}'

info = plistlib.loads((root / 'Config/Info.plist').read_bytes())
assert info['CFBundleIconFile'] == icon.name
assert 'ASSETCATALOG_COMPILER_APPICON_NAME: WebDock' in (root / 'project.yml').read_text()
assert not (root / 'Sources/WebDock/Resources/Assets.xcassets').exists()
composer = root / 'Sources/WebDock/Resources/WebDock.icon'
design = json.loads((composer / 'icon.json').read_text())
assert design['supported-platforms']['squares'] == ['macOS']
for group in design['groups']:
    for layer in group['layers']:
        image = (composer / 'Assets' / layer['image-name']).read_bytes()
        assert image[:8] == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack('>II', image[16:24]) == (1024, 1024)
if args.app:
    info = plistlib.loads((args.app / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleIconFile'] in ['WebDock', icon.name]
    assert info['CFBundleIconName'] == 'WebDock'
    resources = args.app / 'Contents/Resources'
    assert (resources / icon.name).read_bytes()[:4] == b'icns'
    assert not (resources / 'AppIcon.icns').exists(), 'Stale icon in app bundle'
    assets = json.loads(subprocess.check_output([
        'xcrun', 'assetutil', '--info', str(resources / 'Assets.car')]))
    icons = [asset for asset in assets if asset.get('Name') == 'WebDock']
    assert any(asset.get('AssetType') == 'IconImageStack' for asset in icons)
    assert any(asset.get('AssetType') == 'MultiSized Image' for asset in icons)
    assert any(asset.get('PixelWidth') == 1024 for asset in icons)
print('Icon contract OK: standalone ICNS has 10 alpha representations (16–1024 px); modern source valid.')
if args.app:
    print('Built app: WebDock ICNS + modern icon stack + legacy multi-size images + 1024px artwork present.')
