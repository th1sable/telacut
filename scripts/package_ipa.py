"""Package a real Xcode-built app. Does not sign or publish it."""
import argparse
from pathlib import Path
import plistlib
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('app', type=Path)
parser.add_argument('destination', type=Path)
args = parser.parse_args()
assert args.app.is_dir() and args.app.suffix == '.app', 'A real .app built by Xcode is required'
with (args.app / 'Info.plist').open('rb') as source:
    info = plistlib.load(source)
assert 'iPhoneOS' in info.get('CFBundleSupportedPlatforms', []), 'Cannot package a simulator build for an iPhone'
assert (args.app / info['CFBundleExecutable']).is_file(), 'Executable missing'
assert not args.destination.exists(), 'Refusing to overwrite an existing package'
args.destination.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(args.destination, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in args.app.rglob('*'):
        if path.is_file(): archive.write(path, Path('Payload') / args.app.name / path.relative_to(args.app))
print(f'Unsigned IPA created: {args.destination}. Signing and device validation still required.')
