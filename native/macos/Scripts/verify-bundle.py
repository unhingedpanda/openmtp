#!/usr/bin/env python3
"""Verify the actual local preview. Does not launch applications."""
import argparse
import json
import plistlib
import subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('app', type=Path)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
app = a.app.resolve()
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
paths = [path for path in app.rglob('*') if path.is_file()]
size = sum(path.stat().st_size for path in paths) / 1024**2
checks = {
    'bundle_identifier': info['CFBundleIdentifier'] == 'dev.yash.openmtp.native',
    'bundle_size_at_most_50_mib': size <= 50,
    'no_electron': not any('electron' in str(path.relative_to(app)).lower() for path in paths),
    'notices_present': (app / 'Contents/Resources/Licenses/THIRD_PARTY_NOTICES.md').is_file(),
}
for name in ['kalam-seg5.dylib', 'libusb-seg5.dylib']:
    path = app / 'Contents/Resources/Engine' / name
    checks[name + '_present'] = path.is_file()
    if path.is_file():
        checks[name + '_signed'] = subprocess.run(['codesign', '--verify', '--strict', str(path)], capture_output=True).returncode == 0
        checks[name + '_arm64'] = subprocess.check_output(['lipo', '-archs', str(path)], text=True).strip() == 'arm64'
        dependencies = subprocess.check_output(['otool', '-L', str(path)], text=True)
        if name.startswith('kalam'):
            checks['paired_relative_libusb'] = '@loader_path/libusb-seg5.dylib' in dependencies
checks['signature_valid'] = subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], capture_output=True).returncode == 0
attributes = subprocess.run(['xattr', '-lr', str(app)], capture_output=True, text=True).stdout
checks['no_quarantine'] = 'com.apple.quarantine' not in attributes
result = {'app': str(app), 'bundle_mib': size, 'checks': checks, 'passed': all(checks.values())}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
raise SystemExit(0 if result['passed'] else 1)
