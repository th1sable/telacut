"""Create a source-only archive; exclude build output, caches and signing material."""
from pathlib import Path
import argparse
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('destination', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
excluded = {'.git', '.gradle', 'build', 'DerivedData', 'TestDerivedData', 'TestResults.xcresult',
            'TestDiagnostics', '__pycache__', '.swiftpm', '.signing', 'dist'}
secret_suffixes = {'.jks', '.keystore', '.p12', '.mobileprovision', '.apk', '.ipa'}
assert not args.destination.exists(), 'Refusing to overwrite an archive'
args.destination.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(args.destination, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root)
        if not path.is_file() or any(part in excluded for part in relative.parts): continue
        if path.suffix in secret_suffixes or path.name in {'local.properties', '.DS_Store'}: continue
        archive.write(path, Path('TelaCut') / relative)
print(args.destination)
