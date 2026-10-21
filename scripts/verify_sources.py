"""Structural checks only; these do not replace Xcode or on-device testing."""
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET
import json

root = Path(__file__).resolve().parents[1]
checks = []
for path in (root / 'android/app/src/main').rglob('*.xml'):
    ET.parse(path)
    checks.append(str(path.relative_to(root)))
with (root / 'ios/TelaCut/Info.plist').open('rb') as source:
    info = plistlib.load(source)
assert info['CFBundleDisplayName'] == 'TelaCut'
assert 'NSPhotoLibraryAddUsageDescription' in info
manifest = (root / 'android/app/src/main/AndroidManifest.xml').read_text()
assert 'android.permission.INTERNET' not in manifest
assert 'android.permission.MANAGE_EXTERNAL_STORAGE' not in manifest
assert 'android:allowBackup="false"' in manifest
try:
    from tree_sitter import Language, Parser
    import tree_sitter_swift
except ImportError:
    print('Swift parser unavailable: install tree-sitter and tree-sitter-swift for syntax checking.')
else:
    parser = Parser(Language(tree_sitter_swift.language()))
    errors = []
    for path in (root / 'ios').rglob('*.swift'):
        tree = parser.parse(path.read_bytes())
        stack = [tree.root_node]
        while stack:
            node = stack.pop()
            if node.type == 'ERROR' or node.is_missing:
                errors.append(f'{path.name}:{node.start_point}: {node.type}')
            stack.extend(node.children)
        checks.append(str(path.relative_to(root)))
    assert not errors, '\n'.join(errors)
print(json.dumps({'structural_checks': 'passed', 'files': checks, 'ios_typecheck': 'not_run', 'device_tests': 'not_run'}, indent=2))
