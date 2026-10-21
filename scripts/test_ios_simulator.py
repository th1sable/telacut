"""Select an actually installed simulator; fail if none is available."""
import json
import subprocess

data = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))
phones = [device for runtime, devices in data['devices'].items() if 'iOS' in runtime
          for device in devices if device.get('isAvailable') and device['name'].startswith('iPhone')]
if not phones: raise SystemExit('No available iPhone simulator: tests NOT run')
subprocess.run(['xcodebuild', '-project', 'ios/TelaCut.xcodeproj', '-scheme', 'TelaCut',
                '-destination', f"platform=iOS Simulator,id={phones[0]['udid']}",
                'CODE_SIGNING_ALLOWED=NO', 'test'], check=True)
