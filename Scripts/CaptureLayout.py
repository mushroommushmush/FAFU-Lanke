import json
import pathlib
import subprocess
import time

out = pathlib.Path('build/layout-preview')
out.mkdir(parents=True, exist_ok=True)
devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices']
candidates = [d for runtime, rows in devices.items() if 'iOS-26' in runtime for d in rows if d.get('isAvailable')]
chosen = []
for family in ['iPhone']:
    rows = [d for d in candidates if d['name'].startswith(family)]
    rows.sort(key=lambda d: ('Air' not in d['name'], d['name']))
    if rows:
        chosen.append(rows[0])
if not chosen:
    (out / 'NOT_CAPTURED.txt').write_text('No available iOS 26 simulator runtime; device visual validation is pending.')
for d in chosen:
    udid = d['udid']
    def run(*args, timeout=180):
        return subprocess.run(['xcrun', 'simctl', *args], check=True, timeout=timeout)
    subprocess.run(['xcrun', 'simctl', 'boot', udid], check=False)
    run('bootstatus', udid, '-b', timeout=300)
    try:
        run('install', udid, 'build/Simulator/Build/Products/Debug-iphonesimulator/FAFUCampus.app')
        run('launch', udid, 'app.personal.fafucampus', '--layout-preview')
        time.sleep(10)
        run('io', udid, 'screenshot', str(out / (d['name'].replace(' ', '_') + '.png')))
    finally:
        subprocess.run(['xcrun', 'simctl', 'shutdown', udid], check=False)
