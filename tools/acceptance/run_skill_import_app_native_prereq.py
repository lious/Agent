#!/usr/bin/env python3
"""Increment 3.62 native prerequisite qualification. No N01-N02 profile run."""
import hashlib, json, os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path('/workspace/skill-import-app-362')
FLUTTER = Path('/workspace/toolchains/flutter/bin/flutter')
EVIDENCE = ROOT / 'docs/implementation/evidence/signed-import-app-native-prereq'
SENTINELS = [
    'ebVWLo/mVPlAeLES6KmLp5AfhTrmlb7X4OORC60ElmQ=',
    'sha256:65b60673d6ed884bf01c2c222d82ada0740f29ac3355d6a925c81f17f47a27b8',
    'studio-foundation-native-fixture',
]
SOURCES = [
    'apps/studio_demo/lib/import_fixture_composition.dart',
    'apps/studio_demo/lib/skill_import_host.dart',
    'apps/studio_demo/lib/skill_import_panel.dart',
    'apps/studio_demo/lib/main.dart',
    'apps/studio_demo/test/import_native_fixture_entrypoint.dart',
    'apps/studio_demo/test/import_native_reader.dart',
    'apps/studio_demo/test/import_native_reader_test.dart',
    'apps/studio_demo/test/import_native_lifetime_test.dart',
    'apps/studio_demo/test/keyboard_focus_canary.dart',
    'tools/acceptance/native_observation/watch_canary.dart',
    'tools/acceptance/native_observation/strace_canary.py',
    'tools/acceptance/native_observation/keyboard_canary.py',
    'tools/acceptance/run_skill_import_app_native_prereq.py',
    'pubspec.lock',
]

def sha256(path):
    with open(path, 'rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def scan_sentinels(root):
    found = {s: [] for s in SENTINELS}
    for path in Path(root).rglob('*'):
        if not path.is_file():
            continue
        data = path.read_bytes()
        for sentinel in SENTINELS:
            if sentinel.encode() in data or sentinel.encode('utf-16le') in data:
                found[sentinel].append(str(path.relative_to(root)))
    return found

def build(name, args):
    dest = OUT / f'{name}-app'
    if dest.exists():
        shutil.rmtree(dest)
    cmd = [str(FLUTTER), 'build', 'linux', '--release', *args]
    print('+', ' '.join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT / 'apps/studio_demo', check=True)
    bundle = ROOT / 'apps/studio_demo/build/linux/x64/release/bundle'
    shutil.copytree(bundle, dest)
    sentinels = scan_sentinels(dest)
    present = {s: bool(v) for s, v in sentinels.items()}
    return {
        'name': name,
        'command': cmd[2:],
        'dest': str(dest),
        'bundleSha256': {str(p.relative_to(dest)): sha256(p) for p in dest.rglob('*') if p.is_file()},
        'executableSha256': sha256(dest / 'studio_demo'),
        'appSha256': sha256(dest / 'lib' / 'libapp.so'),
        'sentinelsPresent': present,
        'sentinelHits': sentinels,
    }

def main():
    OUT.mkdir(exist_ok=True)
    lock = json.loads((ROOT / 'packages/studio_assets/third_party/sodium/backend-lock.json').read_text())
    source = {p: sha256(ROOT / p) for p in SOURCES}
    linux = ROOT / 'apps/studio_demo/build/linux'
    if linux.exists():
        shutil.rmtree(linux)
    default = build('default', [])
    optin = build('opt-in', ['--dart-define=STUDIO_SIGNED_IMPORT_PREVIEW=true'])
    fixture = build('fixture', [
        '-t', 'test/import_native_fixture_entrypoint.dart',
        '--dart-define=STUDIO_SIGNED_IMPORT_PREVIEW=true',
        f'--dart-define=STUDIO_SIGNED_IMPORT_SODIUM_PATH={lock["devBinary"]}',
        f'--dart-define=STUDIO_SIGNED_IMPORT_SODIUM_SHA256={lock["devBinarySha256"]}',
    ])
    # After builds, sources must be unchanged.
    for p, h in source.items():
        if sha256(ROOT / p) != h:
            raise SystemExit('source changed during build: ' + p)
    def expect(build, want):
        if any(build['sentinelsPresent'].values()) != want:
            raise SystemExit(f"sentinel scope failed for {build['name']}: {build['sentinelsPresent']}")
        if want and not all(build['sentinelsPresent'].values()):
            raise SystemExit(f"fixture missing sentinels: {build['sentinelsPresent']}")
    expect(default, False)
    expect(optin, False)
    expect(fixture, True)
    artifacts = {
        'passed': True,
        'builds': {'default': default, 'opt-in': optin, 'fixture': fixture},
        'sourceSha256': source,
        'sodiumLockSha256': sha256(ROOT / 'packages/studio_assets/third_party/sodium/backend-lock.json'),
        'licenseCoreSha256': sha256(ROOT / 'packages/studio_assets/third_party/sodium_web/LICENSE.core'),
    }
    (OUT / 'artifacts.json').write_text(json.dumps(artifacts, indent=2) + '\n')
    print(json.dumps({k: {n: {'executableSha256': b['executableSha256'], 'sentinelsPresent': b['sentinelsPresent']} for n, b in artifacts['builds'].items()} | {'passed': True}}, indent=2))

if __name__ == '__main__':
    main()
