#!/usr/bin/env python3
"""Copy a Debug app into an isolated UI fixture, with its own bundle ID and library."""
import argparse
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app', required=True, type=Path, help='Debug WebDock.app')
parser.add_argument('--output-dir', required=True, type=Path, help='New fixture output directory')
args = parser.parse_args()
if not (args.app / 'Contents/MacOS/WebDock.debug.dylib').exists():
    parser.error('Use an Xcode Debug build with WebDock.debug.dylib, not a release app.')
if args.output_dir.exists():
    parser.error('Output directory already exists; choose a new directory to preserve previous results.')
args.output_dir.mkdir(parents=True)
root = (args.output_dir / 'ValidationLibrary').resolve()
root.mkdir()
group = str(uuid.uuid4())
now = '2026-10-29T16:00:00Z'
sites = [('ChatGPT', 'https://chatgpt.com/'), ('Claude', 'https://claude.ai/'),
         ('Google', 'https://www.google.com/'), ('DeepSeek', 'https://chat.deepseek.com/'),
         ('GitHub', 'https://github.com/')]
shortcuts = [dict(id=str(uuid.uuid4()), displayName=name, normalizedURLString=url,
                  sortIndex=index, groupID=group, createdAt=now, updatedAt=now)
             for index, (name, url) in enumerate(sites)]
(root / 'Canonical.json').write_text(json.dumps(dict(schemaVersion=1, shortcuts=shortcuts,
    groups=[dict(id=group, name='Websites', sortIndex=0, createdAt=now, updatedAt=now)]), indent=2))
app = args.output_dir / 'WebDock UI Validation.app'
shutil.copytree(args.app, app)
plist = app / 'Contents/Info.plist'
info = plistlib.loads(plist.read_bytes())
info['CFBundleIdentifier'] = 'io.github.codeaix.WebDock.validation'
info['CFBundleDisplayName'] = 'WebDock UI Validation'
info['WebDockValidationLibrary'] = str(root)
plist.write_bytes(plistlib.dumps(info))
subprocess.run(['codesign', '--force', '--deep', '--sign', '-', '--timestamp=none', str(app)], check=True)
print(app.resolve())
print('Fixture uses system-default browser rules; this does not test real browser accounts.')
print('Background sync, automatic backups and first-run onboarding are disabled in this fixture.')
