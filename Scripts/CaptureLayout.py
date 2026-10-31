import json
import pathlib
import subprocess
import time

out = pathlib.Path('build/layout-preview')
out.mkdir(parents=True, exist_ok=True)
runtimes = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'runtimes', '-j']))['runtimes']
runtimes = [r for r in runtimes if r.get('isAvailable') and 'iOS-26' in r['identifier']]
runtimes.sort(key=lambda r: tuple(int(n) for n in r['version'].split('.')), reverse=True)
types = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devicetypes', '-j']))['devicetypes']
phones = [t for t in types if t['name'].startswith('iPhone')]
phones.sort(key=lambda t: ('Air' not in t['name'], t['name']))
chosen = []
if runtimes and phones:
    runtime, device_type = runtimes[0], phones[0]
    udid = subprocess.check_output(['xcrun', 'simctl', 'create', 'Lanke Fresh Layout', device_type['identifier'], runtime['identifier']], text=True).strip()
    chosen = [{'name': device_type['name'], 'udid': udid}]
    (out / 'DEVICE.txt').write_text('Fresh device: ' + udid + '\nRuntime: ' + runtime['identifier'])
    subprocess.run(['open', '-a', '/Applications/Xcode_26.3.app/Contents/Developer/Applications/Simulator.app', '--args', '-CurrentDeviceUDID', udid], check=False)
else:
    (out / 'NOT_CAPTURED.txt').write_text('No available iOS 26 simulator runtime; visual validation is pending.')
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
        run('terminate', udid, 'app.personal.fafucampus')
        run('launch', udid, 'app.personal.fafucampus', '--widget-preview', '--layout-preview')
        time.sleep(6)
        run('io', udid, 'screenshot', str(out / 'Home-widget-design.png'))
    finally:
        subprocess.run(['xcrun', 'simctl', 'shutdown', udid], check=False)

