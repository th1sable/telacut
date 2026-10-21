"""Select an actually installed simulator; fail if none is available."""
import json
import subprocess
import time
from pathlib import Path

data = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))
phones = [device for runtime, devices in data['devices'].items() if 'iOS' in runtime
          for device in devices if device.get('isAvailable') and device['name'].startswith('iPhone')]
if not phones: raise SystemExit('No available iPhone simulator: tests NOT run')
result = subprocess.run(['xcodebuild', '-project', 'ios/TelaCut.xcodeproj', '-scheme', 'TelaCut',
                '-destination', f"platform=iOS Simulator,id={phones[0]['udid']}",
                '-derivedDataPath', 'ios/TestDerivedData', '-resultBundlePath', 'ios/TestResults.xcresult',
                '-parallel-testing-enabled', 'NO', '-test-timeouts-enabled', 'YES',
                '-default-test-execution-time-allowance', '180', '-maximum-test-execution-time-allowance', '180',
                'CODE_SIGNING_ALLOWED=NO', 'test'])
if Path('ios/TestResults.xcresult').exists():
    subprocess.run(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', 'ios/TestResults.xcresult'])
    subprocess.run(['xcrun', 'xcresulttool', 'export', 'diagnostics', '--path', 'ios/TestResults.xcresult',
                    '--output-path', 'ios/TestDiagnostics'])
if result.returncode == 0:
    subprocess.run(['xcrun', 'simctl', 'launch', phones[0]['udid'], 'dev.telacut.mobile'], check=True)
    time.sleep(1)
    subprocess.run(['xcrun', 'simctl', 'io', phones[0]['udid'], 'screenshot', 'ios/TelaCut-iPhone.png'], check=True)
raise SystemExit(result.returncode)
