"""Prepare distribution metadata from built files, never from guessed sizes or versions."""
import argparse
import hashlib
import json
import plistlib
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('apk', type=Path)
parser.add_argument('ipa', type=Path)
parser.add_argument('--date', required=True, help='ISO 8601 release date')
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
for file in (args.apk, args.ipa):
    if not file.is_file(): raise SystemExit(f'Missing built artifact: {file}')
    with zipfile.ZipFile(file) as archive:
        if archive.testzip() is not None: raise SystemExit(f'Invalid archive: {file}')
with zipfile.ZipFile(args.ipa) as archive:
    candidates = [name for name in archive.namelist()
                  if name.startswith('Payload/') and name.count('/') == 2 and name.endswith('.app/Info.plist')]
    if len(candidates) != 1: raise SystemExit('IPA must contain exactly one app')
    info = plistlib.loads(archive.read(candidates[0]))
    if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
        raise SystemExit('Not an iPhone device build')
    if info['CFBundleIdentifier'] != 'dev.telacut.mobile': raise SystemExit('Unexpected app identifier')
    executable = candidates[0].rsplit('/', 1)[0] + '/' + info['CFBundleExecutable']
    if len(archive.read(executable)) < 4096: raise SystemExit('Missing native app executable')
version = info['CFBundleShortVersionString']
release = f'https://github.com/th1sable/telacut/releases/download/v{version}/'
icon = 'https://raw.githubusercontent.com/th1sable/telacut/main/ios/TelaCut/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
description = ('Monta video sul tuo iPhone: importa clip, taglia, dividi, cambia ordine, '
               'aggiungi un titolo e musica, salva i progetti ed esporta in MP4. '
               'Elaborazione sul dispositivo, senza account e senza filigrana. '
               'Questa versione non include IA, sottotitoli automatici o effetti avanzati.')
source = {
    'name': 'TelaCut', 'subtitle': 'Il tuo studio video mobile',
    'description': 'Distribuzione ufficiale di TelaCut tramite AltStore Classic.',
    'website': 'https://github.com/th1sable/telacut', 'iconURL': icon,
    'tintColor': '#B7ACFF', 'featuredApps': [info['CFBundleIdentifier']], 'news': [],
    'apps': [{
        'name': 'TelaCut', 'bundleIdentifier': info['CFBundleIdentifier'],
        'developerName': 'Luigi', 'subtitle': 'Taglia, monta, racconta.',
        'localizedDescription': description, 'iconURL': icon,
        'category': 'photo-video', 'tintColor': '#B7ACFF',
        'versions': [{
            'version': version, 'buildVersion': info['CFBundleVersion'], 'date': args.date,
            'localizedDescription': 'Montaggio locale, progetti salvati, taglio, testo, musica e MP4.',
            'downloadURL': release + args.ipa.name, 'size': args.ipa.stat().st_size,
            'minOSVersion': info['MinimumOSVersion']
        }],
        'appPermissions': {
            'entitlements': [],
            'privacy': {key: value for key, value in info.items() if key.endswith('UsageDescription')}
        }
    }]
}
args.output.mkdir(parents=True, exist_ok=True)
source_path = args.output / 'altstore.json'
checksum_path = args.output / 'SHA256SUMS.txt'
for path in (source_path, checksum_path):
    if path.exists(): raise SystemExit(f'Refusing to overwrite {path}')
source_path.write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
checksums = []
for file in (args.apk, args.ipa):
    with file.open('rb') as stream:
        checksums.append(hashlib.file_digest(stream, 'sha256').hexdigest() + '  ' + file.name)
checksum_path.write_text('\n'.join(checksums) + '\n', encoding='utf-8')
print(json.dumps({'version': version, 'ios_minimum': info['MinimumOSVersion'],
                  'apk_bytes': args.apk.stat().st_size, 'ipa_bytes': args.ipa.stat().st_size,
                  'source': str(source_path), 'checksums': str(checksum_path)}))
