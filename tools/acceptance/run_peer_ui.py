#!/usr/bin/env python3
"""Actual Linux Flutter/libsecret UI integration in a NEW isolated keyring bus.
Never reads or unlocks the owner's existing keyring. No mock storage channels.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def isolated():
    password = secrets.token_urlsafe(32)
    result = subprocess.run(['gnome-keyring-daemon', '--unlock', '--daemonize', '--components=secrets'], input=password, text=True, capture_output=True, timeout=30)
    if result.returncode:
        raise RuntimeError('Isolated test keyring startup failed')
    command = ['xvfb-run', '-a', 'flutter', 'test', 'integration_test/peer_identity_test.dart', '-d', 'linux', '--reporter', 'expanded']
    return subprocess.run(command, cwd=ROOT / 'apps/studio_demo', timeout=480).returncode


def main():
    if '--isolated' in sys.argv:
        return isolated()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='studio-isolated-keyring-') as directory:
        root = Path(directory)
        for name in ['home', 'run', 'config', 'data', 'cache']:
            (root / name).mkdir(mode=0o700)
        env = dict(os.environ, HOME=str(root / 'home'), XDG_RUNTIME_DIR=str(root / 'run'), XDG_CONFIG_HOME=str(root / 'config'), XDG_DATA_HOME=str(root / 'data'), XDG_CACHE_HOME=str(root / 'cache'), PUB_CACHE=str(Path.home() / '.pub-cache'), FLUTTER_SUPPRESS_ANALYTICS='true', CI='true')
        # Do not let a caller's desktop/keyring-control socket leak into this
        # synthetic fixture. dbus-run-session creates its own fresh session bus;
        # xvfb-run later creates its own display for the native test app.
        for inherited in ['GNOME_KEYRING_CONTROL', 'GNOME_KEYRING_PID',
                          'DBUS_SESSION_BUS_ADDRESS', 'DBUS_STARTER_ADDRESS',
                          'DBUS_STARTER_BUS_TYPE', 'SSH_AUTH_SOCK', 'GPG_AGENT_INFO',
                          'DISPLAY', 'WAYLAND_DISPLAY']:
            env.pop(inherited, None)
        command = ['dbus-run-session', '--', sys.executable, str(Path(__file__).resolve()), '--isolated']
        result = subprocess.run(command, env=env, cwd=ROOT, text=True, capture_output=True, timeout=540)
        print(result.stdout, end='')
        print(result.stderr, file=sys.stderr, end='')
        # Real libsecret keyring file must exist, without a plaintext PEM file.
        keyrings = list((root / 'data/keyrings').glob('*.keyring'))
        plaintext = any(b'PRIVATE KEY-----' in p.read_bytes() for p in root.rglob('*') if p.is_file() and p.stat().st_size < 2_000_000)
        passed = result.returncode == 0 and 'All tests passed!' in result.stdout and 'real native UI' in result.stdout and bool(keyrings) and not plaintext
        report = {'scopeStatus': 'passed' if passed else 'failed', 'command': command, 'exitCode': result.returncode,
                  'checkedAt': datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
                  'scope': 'Linux actual native Flutter UI + OS libsecret, fresh isolated encrypted test keyring, localhost TLS; NOT physical devices',
                  'testsExecuted': 1 if passed else 0, 'realKeyringFilePresent': bool(keyrings),
                  'plaintextPrivatePemFiles': plaintext, 'existingOwnerKeyringAccessed': False, 'physicalDeviceQualification': False,
                  'fullTaskComplete': False, 'output': result.stdout + result.stderr}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
