"""Embed ad-hoc entitlement metadata so a downstream signing tool can retain shared keychain groups.
These are not Apple device signatures. Sideloadly must replace LANKE00000 with the real prefix.
"""
import pathlib
import plistlib
import subprocess
import sys

app = pathlib.Path(sys.argv[1])
metadata = pathlib.Path('build/widget-entitlements')
metadata.mkdir(parents=True, exist_ok=True)
for bundle in [*app.glob('PlugIns/*.appex'), app]:
    info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    identity = info['CFBundleIdentifier']
    entitlements = {
        'application-identifier': 'LANKE00000.' + identity,
        'com.apple.developer.team-identifier': 'LANKE00000',
        'keychain-access-groups': ['LANKE00000.' + identity],
    }
    path = metadata / (identity + '.plist')
    path.write_bytes(plistlib.dumps(entitlements))
    subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements', str(path), '--generate-entitlement-der', str(bundle)], check=True)
